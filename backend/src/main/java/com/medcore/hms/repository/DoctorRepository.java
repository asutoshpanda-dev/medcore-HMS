package com.medcore.hms.repository;

import com.medcore.hms.entity.Doctor;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface DoctorRepository extends JpaRepository<Doctor, Long>, JpaSpecificationExecutor<Doctor> {

    // Every lookup is limited to one hospital
    Optional<Doctor> findByIdAndHospitalId(Long id, Long hospitalId);

    boolean existsByIdAndHospitalId(Long id, Long hospitalId);

    // Locks the doctor's row until the transaction ends, so two bookings for the
    // same doctor cannot both pass the slot check at the same moment
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from Doctor d where d.id = :id and d.hospitalId = :hospitalId")
    Optional<Doctor> lockByIdAndHospitalId(@Param("id") Long id, @Param("hospitalId") Long hospitalId);

    // Email is unique across the platform for live doctors. A deleted doctor's email is renamed
    // by the @SQLDelete on Doctor, so the address can be used again.
    boolean existsByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCaseAndIdNot(String email, Long id);
}
