package com.medcore.hms.repository;

import com.medcore.hms.entity.Patient;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

// Soft-deleted patients are hidden by @SQLRestriction on the entity, so these lookups skip them too
public interface PatientRepository extends JpaRepository<Patient, Long>, JpaSpecificationExecutor<Patient> {

    // Every lookup is limited to one hospital
    Optional<Patient> findByIdAndHospitalId(Long id, Long hospitalId);

    boolean existsByIdAndHospitalId(Long id, Long hospitalId);

    boolean existsByFullNameIgnoreCaseAndPhoneAndHospitalId(
            String fullName,
            String phone,
            Long hospitalId
    );

    boolean existsByFullNameIgnoreCaseAndPhoneAndIdNotAndHospitalId(
            String fullName,
            String phone,
            Long id,
            Long hospitalId
    );

    // Locks the patient's row until the transaction ends, so two bookings for the same
    // patient cannot both pass the busy check at the same moment
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Patient p where p.id = :id and p.hospitalId = :hospitalId")
    Optional<Patient> lockByIdAndHospitalId(@Param("id") Long id, @Param("hospitalId") Long hospitalId);
}
