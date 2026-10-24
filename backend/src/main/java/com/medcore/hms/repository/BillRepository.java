package com.medcore.hms.repository;

import com.medcore.hms.entity.Bill;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.Optional;

public interface BillRepository extends JpaRepository<Bill, Long>, JpaSpecificationExecutor<Bill> {

    // Every staff lookup is limited to one hospital
    Optional<Bill> findByIdAndHospitalId(Long id, Long hospitalId);

    // Used by /api/me (the patient id comes from the logged-in account)
    Page<Bill> findByPatientId(Long patientId, Pageable pageable);

    // One bill per appointment
    boolean existsByAppointmentIdAndHospitalId(Long appointmentId, Long hospitalId);

    // The same check when a bill is moved to another appointment; the bill itself is excluded
    boolean existsByAppointmentIdAndHospitalIdAndIdNot(Long appointmentId, Long hospitalId, Long id);
}
