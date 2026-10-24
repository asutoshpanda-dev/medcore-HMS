package com.medcore.hms.service;

import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.Patient;
import com.medcore.hms.exception.PatientNotFoundException;
import com.medcore.hms.repository.PatientRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PatientService {

    private final PatientRepository patientRepository;
    private final CurrentUserService currentUserService;
    private final AuditService auditService;

    public PatientService(PatientRepository patientRepository,
                          CurrentUserService currentUserService,
                          AuditService auditService) {
        this.patientRepository = patientRepository;
        this.currentUserService = currentUserService;
        this.auditService = auditService;
    }

    @Transactional
    public Patient savePatient(Patient patient) {

        Long hospitalId = currentUserService.hospitalId();

        if (patientRepository.existsByFullNameIgnoreCaseAndPhoneAndHospitalId(
                patient.getFullName(), patient.getPhone(), hospitalId)) {
            throw duplicatePatient();
        }

        patient.setId(null);                 // always create a new record
        patient.setHospitalId(hospitalId);   // always the caller's hospital, never from the request
        Patient saved = patientRepository.save(patient);
        auditService.recordChange(AuditAction.CREATE, "Patient", saved.getId());
        return saved;
    }

    // ?q= matches the name or the phone. Only this hospital's patients are ever listed.
    @Transactional(readOnly = true)
    public Page<Patient> getAllPatients(String q, Pageable pageable) {
        Specification<Patient> spec = ListFilters.and(
                ListFilters.<Patient>inHospital(currentUserService.hospitalId()),
                ListFilters.<Patient>containsAny(q, "fullName", "phone"));
        return patientRepository.findAll(spec, pageable);
    }

    public Patient getPatient(Long id) {
        return findOrThrow(id);
    }

    @Transactional
    public Patient updatePatient(Long id, Patient updatedPatient) {

        Patient existingPatient = findOrThrow(id);
        Long hospitalId = currentUserService.hospitalId();

        if (patientRepository.existsByFullNameIgnoreCaseAndPhoneAndIdNotAndHospitalId(
                updatedPatient.getFullName(), updatedPatient.getPhone(), id, hospitalId)) {
            throw duplicatePatient();
        }

        existingPatient.setFullName(updatedPatient.getFullName());
        existingPatient.setAge(updatedPatient.getAge());
        existingPatient.setGender(updatedPatient.getGender());
        existingPatient.setPhone(updatedPatient.getPhone());

        Patient saved = patientRepository.save(existingPatient);
        auditService.recordChange(AuditAction.UPDATE, "Patient", id);
        return saved;
    }

    // Soft delete: the row stays in the database and disappears from every query
    @Transactional
    public void deletePatient(Long id) {
        patientRepository.delete(findOrThrow(id));
        auditService.recordChange(AuditAction.DELETE, "Patient", id);
    }

    // Another hospital's patient is reported as "not found", so ids do not leak
    private Patient findOrThrow(Long id) {
        return patientRepository.findByIdAndHospitalId(id, currentUserService.hospitalId())
                .orElseThrow(() ->
                        new PatientNotFoundException("Patient not found with id: " + id));
    }

    private ResponseStatusException duplicatePatient() {
        return new ResponseStatusException(HttpStatus.CONFLICT,
                "Patient already exists with the same name and phone");
    }
}
