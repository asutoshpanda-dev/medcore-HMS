package com.medcore.hms.service;

import com.medcore.hms.dto.MedicalRecordDtos.CreateRecordRequest;
import com.medcore.hms.dto.MedicalRecordDtos.UpdateRecordRequest;
import com.medcore.hms.entity.AppUser;
import com.medcore.hms.entity.Appointment;
import com.medcore.hms.entity.AppointmentStatus;
import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.MedicalRecord;
import com.medcore.hms.entity.Role;
import com.medcore.hms.exception.AppointmentNotFoundException;
import com.medcore.hms.repository.AppointmentRepository;
import com.medcore.hms.repository.MedicalRecordRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.Set;

// Clinical notes. A doctor writes them while the visit is open (CONFIRMED or IN_PROGRESS).
// Once the visit is COMPLETED, only a hospital admin can correct the record.
// Every create and every change is written to the audit log.
@Service
public class MedicalRecordService {

    private static final Set<AppointmentStatus> OPEN_VISIT = EnumSet.of(
            AppointmentStatus.CONFIRMED,
            AppointmentStatus.IN_PROGRESS);

    private final MedicalRecordRepository medicalRecordRepository;
    private final AppointmentRepository appointmentRepository;
    private final CurrentUserService currentUserService;
    private final AuditService auditService;

    public MedicalRecordService(MedicalRecordRepository medicalRecordRepository,
                                AppointmentRepository appointmentRepository,
                                CurrentUserService currentUserService,
                                AuditService auditService) {
        this.medicalRecordRepository = medicalRecordRepository;
        this.appointmentRepository = appointmentRepository;
        this.currentUserService = currentUserService;
        this.auditService = auditService;
    }

    @Transactional
    public MedicalRecord createRecord(CreateRecordRequest request) {

        AppUser user = currentUserService.get();
        Long hospitalId = currentUserService.hospitalId();

        Appointment appointment = appointmentRepository
                .findByIdAndHospitalId(request.appointmentId(), hospitalId)
                .orElseThrow(() -> new AppointmentNotFoundException(
                        "Appointment not found with id: " + request.appointmentId()));

        if (!appointment.getDoctorId().equals(user.getDoctorId())) {
            throw forbidden("You can only write notes for your own appointments");
        }

        if (!OPEN_VISIT.contains(appointment.getStatus())) {
            throw conflict("Notes can be written only while the visit is confirmed or in progress");
        }

        if (medicalRecordRepository.existsByAppointmentId(appointment.getId())) {
            throw conflict("A medical record already exists for this appointment");
        }

        MedicalRecord record = new MedicalRecord();
        record.setHospitalId(hospitalId);                       // never from the request
        record.setAppointmentId(appointment.getId());
        record.setPatientId(appointment.getPatientId());
        record.setDoctorId(appointment.getDoctorId());
        copyClinicalFields(record, request.diagnosis(), request.clinicalNotes(),
                request.bloodPressure(), request.pulseBpm(),
                request.temperatureC(), request.weightKg());

        MedicalRecord saved = medicalRecordRepository.save(record);
        auditService.recordChange(AuditAction.CREATE, "MedicalRecord", saved.getId());
        return saved;
    }

    public MedicalRecord getRecord(Long id) {
        return findOrThrow(id);
    }

    @Transactional
    public MedicalRecord updateRecord(Long id, UpdateRecordRequest request) {

        MedicalRecord record = findOrThrow(id);
        AppUser user = currentUserService.get();

        if (user.getRole() == Role.DOCTOR) {

            if (!record.getDoctorId().equals(user.getDoctorId())) {
                throw forbidden("You can only change your own records");
            }

            Appointment appointment = appointmentRepository
                    .findByIdAndHospitalId(record.getAppointmentId(), currentUserService.hospitalId())
                    .orElseThrow(() -> new AppointmentNotFoundException(
                            "Appointment not found with id: " + record.getAppointmentId()));

            if (!OPEN_VISIT.contains(appointment.getStatus())) {
                throw conflict("This visit is locked. Ask a hospital admin to correct the record.");
            }
        }
        // A hospital admin may correct a record at any time

        copyClinicalFields(record, request.diagnosis(), request.clinicalNotes(),
                request.bloodPressure(), request.pulseBpm(),
                request.temperatureC(), request.weightKg());

        MedicalRecord saved = medicalRecordRepository.save(record);
        auditService.recordChange(AuditAction.UPDATE, "MedicalRecord", id);
        return saved;
    }

    // The patient's own records, read-only, newest first
    @Transactional(readOnly = true)
    public Page<MedicalRecord> myRecords(Long patientId, Pageable pageable) {
        return medicalRecordRepository.findByHospitalIdAndPatientId(
                currentUserService.hospitalId(), patientId, pageable);
    }

    private MedicalRecord findOrThrow(Long id) {
        return medicalRecordRepository.findByIdAndHospitalId(id, currentUserService.hospitalId())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Medical record not found with id: " + id));
    }

    private void copyClinicalFields(MedicalRecord record, String diagnosis, String clinicalNotes,
                                    String bloodPressure, Integer pulseBpm,
                                    BigDecimal temperatureC, BigDecimal weightKg) {
        record.setDiagnosis(diagnosis);
        record.setClinicalNotes(clinicalNotes);
        record.setBloodPressure(bloodPressure);
        record.setPulseBpm(pulseBpm);
        record.setTemperatureC(temperatureC);
        record.setWeightKg(weightKg);
    }

    private ResponseStatusException forbidden(String message) {
        return new ResponseStatusException(HttpStatus.FORBIDDEN, message);
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
