package com.medcore.hms.repository;

import com.medcore.hms.entity.MedicalRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MedicalRecordRepository extends JpaRepository<MedicalRecord, Long> {

    // Every lookup is limited to one hospital
    Optional<MedicalRecord> findByIdAndHospitalId(Long id, Long hospitalId);

    // One record per visit
    boolean existsByAppointmentId(Long appointmentId);

    // Used by /api/me (the patient id comes from the logged-in account)
    Page<MedicalRecord> findByHospitalIdAndPatientId(Long hospitalId, Long patientId, Pageable pageable);
}
