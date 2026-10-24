package com.medcore.hms.service;

import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.Doctor;
import com.medcore.hms.exception.DoctorNotFoundException;
import com.medcore.hms.repository.DoctorRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class DoctorService {

    private final DoctorRepository doctorRepository;
    private final CurrentUserService currentUserService;
    private final AuditService auditService;

    public DoctorService(DoctorRepository doctorRepository,
                         CurrentUserService currentUserService,
                         AuditService auditService) {
        this.doctorRepository = doctorRepository;
        this.currentUserService = currentUserService;
        this.auditService = auditService;
    }

    @Transactional
    public Doctor saveDoctor(Doctor doctor) {

        // Email is unique across all hospitals for live doctors
        if (doctorRepository.existsByEmailIgnoreCase(doctor.getEmail())) {
            throw duplicateEmail();
        }

        doctor.setId(null);                                                 // always create a new record
        doctor.setHospitalId(currentUserService.hospitalId());              // never from the request
        Doctor saved = doctorRepository.save(doctor);
        auditService.recordChange(AuditAction.CREATE, "Doctor", saved.getId());
        return saved;
    }

    // ?q= matches the name or the specialization
    @Transactional(readOnly = true)
    public Page<Doctor> getAllDoctors(String q, Pageable pageable) {
        Specification<Doctor> spec = ListFilters.and(
                ListFilters.<Doctor>inHospital(currentUserService.hospitalId()),
                ListFilters.<Doctor>containsAny(q, "fullName", "specialization"));
        return doctorRepository.findAll(spec, pageable);
    }

    @Transactional
    public Doctor updateDoctor(Long id, Doctor updatedDoctor) {

        Doctor doctor = findOrThrow(id);

        if (doctorRepository.existsByEmailIgnoreCaseAndIdNot(updatedDoctor.getEmail(), id)) {
            throw duplicateEmail();
        }

        doctor.setFullName(updatedDoctor.getFullName());
        doctor.setSpecialization(updatedDoctor.getSpecialization());
        doctor.setPhone(updatedDoctor.getPhone());
        doctor.setEmail(updatedDoctor.getEmail());

        Doctor saved = doctorRepository.save(doctor);
        auditService.recordChange(AuditAction.UPDATE, "Doctor", id);
        return saved;
    }

    // Soft delete: the row stays in the database, hidden from every query. Its email is renamed
    // so a new doctor can use the address.
    @Transactional
    public void deleteDoctor(Long id) {
        doctorRepository.delete(findOrThrow(id));
        auditService.recordChange(AuditAction.DELETE, "Doctor", id);
    }

    private Doctor findOrThrow(Long id) {
        return doctorRepository.findByIdAndHospitalId(id, currentUserService.hospitalId())
                .orElseThrow(() ->
                        new DoctorNotFoundException("Doctor not found with id: " + id));
    }

    private ResponseStatusException duplicateEmail() {
        return new ResponseStatusException(HttpStatus.CONFLICT,
                "A doctor with this email already exists");
    }
}
