package com.medcore.hms.dto;

import com.medcore.hms.entity.Appointment;
import com.medcore.hms.entity.AppointmentPriority;
import com.medcore.hms.entity.AppointmentStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.time.LocalTime;

public final class AppointmentDtos {

    private AppointmentDtos() {
    }

    // What staff send to book or change an appointment. The status and hospital are set by the server.
    public record AppointmentRequest(
            @NotNull(message = "Patient ID is required") Long patientId,
            @NotNull(message = "Doctor ID is required") Long doctorId,
            @NotNull(message = "Appointment date is required") LocalDate appointmentDate,
            @NotNull(message = "Appointment time is required") LocalTime appointmentTime,
            @NotBlank(message = "Reason is required")
            @Size(max = 255, message = "Reason must be at most 255 characters")
            String reason,
            AppointmentPriority priority) {   // optional: NORMAL when it is missing

        public Appointment toEntity() {
            Appointment appointment = new Appointment();
            appointment.setPatientId(patientId);
            appointment.setDoctorId(doctorId);
            appointment.setAppointmentDate(appointmentDate);
            appointment.setAppointmentTime(appointmentTime);
            appointment.setReason(reason);
            if (priority != null) {
                appointment.setPriority(priority);
            }
            return appointment;
        }
    }

    // What a patient sends to book. The patient id, status and priority are set by the server.
    public record PatientBookingRequest(
            @NotNull(message = "Doctor ID is required") Long doctorId,
            @NotNull(message = "Appointment date is required") LocalDate appointmentDate,
            @NotNull(message = "Appointment time is required") LocalTime appointmentTime,
            @NotBlank(message = "Reason is required")
            @Size(max = 255, message = "Reason must be at most 255 characters")
            String reason) {
    }

    public record AppointmentResponse(Long id, Long hospitalId, Long patientId, Long doctorId,
                                      LocalDate appointmentDate, LocalTime appointmentTime,
                                      String reason, AppointmentStatus status, AppointmentPriority priority) {

        public static AppointmentResponse from(Appointment appointment) {
            return new AppointmentResponse(appointment.getId(), appointment.getHospitalId(),
                    appointment.getPatientId(), appointment.getDoctorId(),
                    appointment.getAppointmentDate(), appointment.getAppointmentTime(),
                    appointment.getReason(), appointment.getStatus(), appointment.getPriority());
        }
    }
}
