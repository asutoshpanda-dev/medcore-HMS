package com.medcore.hms.repository;

import com.medcore.hms.entity.Prescription;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PrescriptionRepository extends JpaRepository<Prescription, Long>, JpaSpecificationExecutor<Prescription> {

    // Every staff lookup is limited to one hospital
    Optional<Prescription> findByIdAndHospitalId(Long id, Long hospitalId);

    // Used by /api/me (the patient id comes from the logged-in account)
    Page<Prescription> findByPatientId(Long patientId, Pageable pageable);

    // Soft delete that only sets the flag. A normal delete would also remove the medicine rows,
    // because the medicine list cascades deletes, and the history of a prescription must stay.
    @Modifying(clearAutomatically = true)
    @Query("update Prescription p set p.deleted = true where p.id = :id and p.hospitalId = :hospitalId")
    int markDeleted(@Param("id") Long id, @Param("hospitalId") Long hospitalId);
}
