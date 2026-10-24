package com.medcore.hms.repository;

import com.medcore.hms.entity.Appointment;
import com.medcore.hms.entity.AppointmentStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface AppointmentRepository extends JpaRepository<Appointment, Long>, JpaSpecificationExecutor<Appointment> {

    // Every staff lookup is limited to one hospital
    Optional<Appointment> findByIdAndHospitalId(Long id, Long hospitalId);

    boolean existsByIdAndHospitalId(Long id, Long hospitalId);

    // Appointments that hold a doctor's time at this date and time
    List<Appointment> findByHospitalIdAndDoctorIdAndAppointmentDateAndAppointmentTimeAndStatusIn(
            Long hospitalId, Long doctorId, LocalDate appointmentDate,
            LocalTime appointmentTime, Collection<AppointmentStatus> statuses);

    // Appointments that hold a patient's time at this date and time
    List<Appointment> findByHospitalIdAndPatientIdAndAppointmentDateAndAppointmentTimeAndStatusIn(
            Long hospitalId, Long patientId, LocalDate appointmentDate,
            LocalTime appointmentTime, Collection<AppointmentStatus> statuses);

    // Used by /api/me (the patient id comes from the logged-in account)
    Page<Appointment> findByPatientId(Long patientId, Pageable pageable);
}
