package com.medcore.hms.service;

import com.medcore.hms.dto.AppointmentDtos.PatientBookingRequest;
import com.medcore.hms.entity.AppUser;
import com.medcore.hms.entity.Appointment;
import com.medcore.hms.entity.AppointmentPriority;
import com.medcore.hms.entity.AppointmentStatus;
import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.Role;
import com.medcore.hms.exception.AppointmentNotFoundException;
import com.medcore.hms.exception.DoctorNotFoundException;
import com.medcore.hms.exception.PatientNotFoundException;
import com.medcore.hms.repository.AppointmentRepository;
import com.medcore.hms.repository.DoctorRepository;
import com.medcore.hms.repository.MedicalRecordRepository;
import com.medcore.hms.repository.PatientRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.Objects;

@Service
public class AppointmentService {

    private final AppointmentRepository appointmentRepository;
    private final PatientRepository patientRepository;
    private final DoctorRepository doctorRepository;
    private final MedicalRecordRepository medicalRecordRepository;
    private final CurrentUserService currentUserService;
    private final AppointmentRules rules;
    private final AuditService auditService;

    public AppointmentService(
            AppointmentRepository appointmentRepository,
            PatientRepository patientRepository,
            DoctorRepository doctorRepository,
            MedicalRecordRepository medicalRecordRepository,
            CurrentUserService currentUserService,
            AppointmentRules rules,
            AuditService auditService) {

        this.appointmentRepository = appointmentRepository;
        this.patientRepository = patientRepository;
        this.doctorRepository = doctorRepository;
        this.medicalRecordRepository = medicalRecordRepository;
        this.currentUserService = currentUserService;
        this.rules = rules;
        this.auditService = auditService;
    }

    // Staff book an appointment. EMERGENCY appointments skip the slot checks.
    // READ_COMMITTED: each read sees the bookings committed while this one waited for a lock.
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Appointment saveAppointment(Appointment appointment) {

        Long hospitalId = currentUserService.hospitalId();
        validateReferences(appointment, hospitalId);
        rules.validateSlot(appointment.getAppointmentDate(), appointment.getAppointmentTime());

        if (appointment.getPriority() == null) {
            appointment.setPriority(AppointmentPriority.NORMAL);
        }
        if (appointment.getPriority() == AppointmentPriority.NORMAL) {
            checkFreeSlot(hospitalId, appointment, null);
        }

        appointment.setId(null);                      // always create a new record
        appointment.setHospitalId(hospitalId);        // never from the request
        appointment.setStatus(AppointmentStatus.PENDING);
        Appointment saved = appointmentRepository.save(appointment);
        auditService.recordChange(AuditAction.CREATE, "Appointment", saved.getId());
        return saved;
    }

    // ?date=yyyy-MM-dd and ?status= are optional filters
    @Transactional(readOnly = true)
    public Page<Appointment> getAllAppointments(LocalDate date, AppointmentStatus status, Pageable pageable) {
        Specification<Appointment> spec = ListFilters.and(
                ListFilters.<Appointment>inHospital(currentUserService.hospitalId()),
                ListFilters.<Appointment>equal("appointmentDate", date));
        spec = ListFilters.and(spec, ListFilters.<Appointment>equal("status", status));
        return appointmentRepository.findAll(spec, pageable);
    }

    // Only pending or confirmed appointments can be moved or changed.
    // Once a medical record exists, the doctor and patient cannot change: the record holds them.
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Appointment updateAppointment(Long id, Appointment updated) {

        Appointment appointment = findOrThrow(id);
        if (appointment.getStatus() != AppointmentStatus.PENDING
                && appointment.getStatus() != AppointmentStatus.CONFIRMED) {
            throw conflict("Only pending or confirmed appointments can be changed");
        }

        Long hospitalId = currentUserService.hospitalId();
        validateReferences(updated, hospitalId);

        boolean ownerChanged = !Objects.equals(appointment.getDoctorId(), updated.getDoctorId())
                || !Objects.equals(appointment.getPatientId(), updated.getPatientId());
        boolean slotChanged = !Objects.equals(appointment.getAppointmentDate(), updated.getAppointmentDate())
                || !Objects.equals(appointment.getAppointmentTime(), updated.getAppointmentTime());

        if (ownerChanged && medicalRecordRepository.existsByAppointmentId(id)) {
            throw conflict("This visit already has a medical record, so its doctor and patient cannot be changed");
        }

        // Only a new doctor, patient or time has to pass the slot rules. Changing just the reason
        // or priority still works after the start time, so a booking whose time has passed
        // can still be corrected.
        if (ownerChanged || slotChanged) {
            rules.validateSlot(updated.getAppointmentDate(), updated.getAppointmentTime());
        }

        AppointmentPriority priority = updated.getPriority() == null
                ? AppointmentPriority.NORMAL
                : updated.getPriority();
        if (priority == AppointmentPriority.NORMAL) {
            checkFreeSlot(hospitalId, updated, id);   // this appointment itself is not a conflict
        }

        appointment.setPatientId(updated.getPatientId());
        appointment.setDoctorId(updated.getDoctorId());
        appointment.setAppointmentDate(updated.getAppointmentDate());
        appointment.setAppointmentTime(updated.getAppointmentTime());
        appointment.setReason(updated.getReason());
        appointment.setPriority(priority);

        Appointment saved = appointmentRepository.save(appointment);
        auditService.recordChange(AuditAction.UPDATE, "Appointment", id);
        return saved;
    }

    // Status changes must follow the lifecycle in AppointmentRules
    @Transactional
    public Appointment updateStatus(Long id, AppointmentStatus status) {

        Appointment appointment = findOrThrow(id);

        AppUser user = currentUserService.get();
        if (user.getRole() == Role.DOCTOR
                && !appointment.getDoctorId().equals(user.getDoctorId())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "You can only change your own appointments");
        }

        rules.validateTransition(appointment.getStatus(), status);
        appointment.setStatus(status);
        Appointment saved = appointmentRepository.save(appointment);
        auditService.recordChange(AuditAction.STATUS_CHANGE, "Appointment", id);
        return saved;
    }

    // Soft delete: the appointment stays in the database and stops holding its slot
    @Transactional
    public void deleteAppointment(Long id) {
        appointmentRepository.delete(findOrThrow(id));
        auditService.recordChange(AuditAction.DELETE, "Appointment", id);
    }

    // A patient books for themselves. The slot is PENDING until reception confirms it.
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Appointment bookByPatient(Long patientId, PatientBookingRequest request) {

        Long hospitalId = currentUserService.hospitalId();

        Appointment appointment = new Appointment();
        appointment.setPatientId(patientId);                  // from the account, never from the request
        appointment.setDoctorId(request.doctorId());
        appointment.setAppointmentDate(request.appointmentDate());
        appointment.setAppointmentTime(request.appointmentTime());
        appointment.setReason(request.reason());
        appointment.setPriority(AppointmentPriority.NORMAL);  // patients cannot flag an emergency

        validateReferences(appointment, hospitalId);
        rules.validateSlot(appointment.getAppointmentDate(), appointment.getAppointmentTime());
        checkFreeSlot(hospitalId, appointment, null);

        appointment.setHospitalId(hospitalId);
        appointment.setStatus(AppointmentStatus.PENDING);
        Appointment saved = appointmentRepository.save(appointment);
        auditService.recordChange(AuditAction.CREATE, "Appointment", saved.getId());
        return saved;
    }

    // A patient cancels their own appointment (the lifecycle decides if it is still allowed)
    @Transactional
    public Appointment cancelByPatient(Long id, Long patientId) {

        Appointment appointment = appointmentRepository
                .findByIdAndHospitalId(id, currentUserService.hospitalId())
                .filter(a -> patientId.equals(a.getPatientId()))
                .orElseThrow(() ->
                        new AppointmentNotFoundException("Appointment not found with id: " + id));

        rules.validateTransition(appointment.getStatus(), AppointmentStatus.CANCELLED);
        appointment.setStatus(AppointmentStatus.CANCELLED);
        Appointment saved = appointmentRepository.save(appointment);
        auditService.recordChange(AuditAction.STATUS_CHANGE, "Appointment", id);
        return saved;
    }

    private Appointment findOrThrow(Long id) {
        return appointmentRepository.findByIdAndHospitalId(id, currentUserService.hospitalId())
                .orElseThrow(() ->
                        new AppointmentNotFoundException(
                                "Appointment not found with id: " + id));
    }

    // Locks the doctor's row, then the patient's row (always in this order, so two bookings
    // can never wait on each other). Then checks that neither the doctor nor the patient is busy.
    // ignoreId is the appointment being changed, so it does not count as a conflict with itself.
    private void checkFreeSlot(Long hospitalId, Appointment appointment, Long ignoreId) {

        doctorRepository.lockByIdAndHospitalId(appointment.getDoctorId(), hospitalId)
                .orElseThrow(() -> new DoctorNotFoundException(
                        "Doctor not found with id: " + appointment.getDoctorId()));

        patientRepository.lockByIdAndHospitalId(appointment.getPatientId(), hospitalId)
                .orElseThrow(() -> new PatientNotFoundException(
                        "Patient not found with id: " + appointment.getPatientId()));

        boolean doctorBusy = appointmentRepository
                .findByHospitalIdAndDoctorIdAndAppointmentDateAndAppointmentTimeAndStatusIn(
                        hospitalId, appointment.getDoctorId(),
                        appointment.getAppointmentDate(), appointment.getAppointmentTime(),
                        AppointmentRules.ACTIVE)
                .stream()
                .anyMatch(a -> !Objects.equals(a.getId(), ignoreId));

        if (doctorBusy) {
            throw conflict("This doctor already has an appointment at this time");
        }

        boolean patientBusy = appointmentRepository
                .findByHospitalIdAndPatientIdAndAppointmentDateAndAppointmentTimeAndStatusIn(
                        hospitalId, appointment.getPatientId(),
                        appointment.getAppointmentDate(), appointment.getAppointmentTime(),
                        AppointmentRules.ACTIVE)
                .stream()
                .anyMatch(a -> !Objects.equals(a.getId(), ignoreId));

        if (patientBusy) {
            throw conflict("This patient already has an appointment at this time");
        }
    }

    // The patient and the doctor must both belong to the same hospital as the appointment
    private void validateReferences(Appointment appointment, Long hospitalId) {

        if (!patientRepository.existsByIdAndHospitalId(appointment.getPatientId(), hospitalId)) {
            throw new PatientNotFoundException(
                    "Patient not found with id: " + appointment.getPatientId());
        }

        if (!doctorRepository.existsByIdAndHospitalId(appointment.getDoctorId(), hospitalId)) {
            throw new DoctorNotFoundException(
                    "Doctor not found with id: " + appointment.getDoctorId());
        }
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
