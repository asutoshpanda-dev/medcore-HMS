package com.medcore.hms.service;

import com.medcore.hms.entity.AppUser;
import com.medcore.hms.entity.Appointment;
import com.medcore.hms.entity.AppointmentStatus;
import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.Prescription;
import com.medcore.hms.entity.PrescriptionItem;
import com.medcore.hms.entity.PrescriptionStatus;
import com.medcore.hms.entity.Role;
import com.medcore.hms.exception.AppointmentNotFoundException;
import com.medcore.hms.exception.DoctorNotFoundException;
import com.medcore.hms.exception.PatientNotFoundException;
import com.medcore.hms.exception.PrescriptionNotFoundException;
import com.medcore.hms.repository.AppointmentRepository;
import com.medcore.hms.repository.DoctorRepository;
import com.medcore.hms.repository.PatientRepository;
import com.medcore.hms.repository.PrescriptionRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PrescriptionService {

    private final PrescriptionRepository prescriptionRepository;
    private final PatientRepository patientRepository;
    private final DoctorRepository doctorRepository;
    private final AppointmentRepository appointmentRepository;
    private final CurrentUserService currentUserService;
    private final AuditService auditService;

    public PrescriptionService(
            PrescriptionRepository prescriptionRepository,
            PatientRepository patientRepository,
            DoctorRepository doctorRepository,
            AppointmentRepository appointmentRepository,
            CurrentUserService currentUserService,
            AuditService auditService) {

        this.prescriptionRepository = prescriptionRepository;
        this.patientRepository = patientRepository;
        this.doctorRepository = doctorRepository;
        this.appointmentRepository = appointmentRepository;
        this.currentUserService = currentUserService;
        this.auditService = auditService;
    }

    @Transactional
    public Prescription savePrescription(Prescription prescription) {

        Long hospitalId = currentUserService.hospitalId();
        requireOwnDoctor(prescription.getDoctorId());               // permission first: a doctor writes only in their own name
        validateReferences(prescription, hospitalId);

        prescription.setId(null);                                   // always create a new record
        prescription.setHospitalId(hospitalId);                     // never from the request
        prescription.setStatus(PrescriptionStatus.ACTIVE.name());   // new prescriptions start ACTIVE
        for (PrescriptionItem item : prescription.getItems()) {
            item.setId(null);                                       // every medicine is a new row
        }
        Prescription saved = prescriptionRepository.save(prescription);
        auditService.recordChange(AuditAction.CREATE, "Prescription", saved.getId());
        return saved;
    }

    // ?status=ACTIVE|COMPLETED|CANCELLED is an optional filter
    @Transactional(readOnly = true)
    public Page<Prescription> getAllPrescriptions(PrescriptionStatus status, Pageable pageable) {
        Specification<Prescription> spec = ListFilters.and(
                ListFilters.<Prescription>inHospital(currentUserService.hospitalId()),
                ListFilters.<Prescription>equal("status", status == null ? null : status.name()));
        return prescriptionRepository.findAll(spec, pageable);
    }

    // Only an ACTIVE prescription can be changed
    @Transactional
    public Prescription updatePrescription(Long id, Prescription updatedPrescription) {

        Prescription prescription = findOrThrow(id);
        requireOwnDoctor(prescription.getDoctorId());
        requireActive(prescription);

        Long hospitalId = currentUserService.hospitalId();
        validateReferences(updatedPrescription, hospitalId);
        requireOwnDoctor(updatedPrescription.getDoctorId());

        prescription.setPatientId(updatedPrescription.getPatientId());
        prescription.setDoctorId(updatedPrescription.getDoctorId());
        prescription.setAppointmentId(updatedPrescription.getAppointmentId());
        prescription.setInstructions(updatedPrescription.getInstructions());

        // The medicine list is replaced as a whole: old items are deleted (orphanRemoval)
        prescription.getItems().clear();
        for (PrescriptionItem item : updatedPrescription.getItems()) {
            item.setId(null);
            prescription.getItems().add(item);
        }
        // status is NOT copied here; it changes only through updateStatus

        Prescription saved = prescriptionRepository.save(prescription);
        auditService.recordChange(AuditAction.UPDATE, "Prescription", id);
        return saved;
    }

    // ACTIVE -> COMPLETED or CANCELLED, nothing else
    @Transactional
    public Prescription updateStatus(Long id, PrescriptionStatus status) {

        Prescription prescription = findOrThrow(id);
        requireOwnDoctor(prescription.getDoctorId());
        validateTransition(prescription.getStatus(), status);

        prescription.setStatus(status.name());
        Prescription saved = prescriptionRepository.save(prescription);
        auditService.recordChange(AuditAction.STATUS_CHANGE, "Prescription", id);
        return saved;
    }

    // Only an ACTIVE prescription can be deleted. Soft delete: the row and its medicines stay in
    // the database, hidden from every query.
    @Transactional
    public void deletePrescription(Long id) {

        Prescription prescription = findOrThrow(id);
        requireActive(prescription);
        prescriptionRepository.markDeleted(prescription.getId(), currentUserService.hospitalId());
        auditService.recordChange(AuditAction.DELETE, "Prescription", id);
    }

    private Prescription findOrThrow(Long id) {
        return prescriptionRepository.findByIdAndHospitalId(id, currentUserService.hospitalId())
                .orElseThrow(() ->
                        new PrescriptionNotFoundException(
                                "Prescription not found with id: " + id));
    }

    // The patient and doctor must exist in this hospital. The appointment must be the visit of
    // this same patient and this same doctor, and must not be cancelled or a no-show.
    private void validateReferences(Prescription prescription, Long hospitalId) {

        if (!patientRepository.existsByIdAndHospitalId(prescription.getPatientId(), hospitalId)) {
            throw new PatientNotFoundException(
                    "Patient not found with id: " + prescription.getPatientId());
        }

        if (!doctorRepository.existsByIdAndHospitalId(prescription.getDoctorId(), hospitalId)) {
            throw new DoctorNotFoundException(
                    "Doctor not found with id: " + prescription.getDoctorId());
        }

        Appointment appointment = appointmentRepository
                .findByIdAndHospitalId(prescription.getAppointmentId(), hospitalId)
                .orElseThrow(() -> new AppointmentNotFoundException(
                        "Appointment not found with id: " + prescription.getAppointmentId()));

        if (!prescription.getPatientId().equals(appointment.getPatientId())) {
            throw badRequest("This prescription's patient is not the patient of appointment "
                    + appointment.getId());
        }

        if (!prescription.getDoctorId().equals(appointment.getDoctorId())) {
            throw badRequest("This prescription's doctor is not the doctor of appointment "
                    + appointment.getId());
        }

        if (appointment.getStatus() == AppointmentStatus.CANCELLED
                || appointment.getStatus() == AppointmentStatus.NO_SHOW) {
            throw conflict("No prescription can be written for a cancelled or no-show appointment");
        }
    }

    // ACTIVE is the only starting point. COMPLETED and CANCELLED are final.
    private void validateTransition(String from, PrescriptionStatus to) {

        boolean allowed = PrescriptionStatus.ACTIVE.name().equals(from)
                && (to == PrescriptionStatus.COMPLETED || to == PrescriptionStatus.CANCELLED);

        if (!allowed) {
            throw conflict("A prescription cannot change from " + from + " to " + to);
        }
    }

    // Used by edit and delete: a finished prescription is part of the history
    private void requireActive(Prescription prescription) {

        if (!PrescriptionStatus.ACTIVE.name().equals(prescription.getStatus())) {
            throw conflict("This prescription is " + prescription.getStatus()
                    + " and can no longer be changed");
        }
    }

    // A doctor may only work on prescriptions written in their own name
    private void requireOwnDoctor(Long prescriptionDoctorId) {
        AppUser user = currentUserService.get();
        if (user.getRole() == Role.DOCTOR
                && !prescriptionDoctorId.equals(user.getDoctorId())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "You can only manage your own prescriptions");
        }
    }

    private ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
