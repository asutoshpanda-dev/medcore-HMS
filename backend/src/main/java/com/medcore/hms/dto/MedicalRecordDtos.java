package com.medcore.hms.dto;

import com.medcore.hms.entity.MedicalRecord;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public final class MedicalRecordDtos {

    private MedicalRecordDtos() {
    }

    public record CreateRecordRequest(
            @NotNull(message = "Appointment ID is required") Long appointmentId,

            @Size(max = 1000, message = "Diagnosis must be at most 1000 characters")
            String diagnosis,

            @Size(max = 5000, message = "Clinical notes must be at most 5000 characters")
            String clinicalNotes,

            @Pattern(regexp = "^[0-9]{2,3}/[0-9]{2,3}$", message = "Blood pressure must look like 120/80")
            String bloodPressure,

            @Min(value = 20, message = "Pulse must be between 20 and 250")
            @Max(value = 250, message = "Pulse must be between 20 and 250")
            Integer pulseBpm,

            @DecimalMin(value = "30.0", message = "Temperature must be between 30 and 45 degrees C")
            @DecimalMax(value = "45.0", message = "Temperature must be between 30 and 45 degrees C")
            BigDecimal temperatureC,

            @DecimalMin(value = "0.5", message = "Weight must be between 0.5 and 400 kg")
            @DecimalMax(value = "400", message = "Weight must be between 0.5 and 400 kg")
            BigDecimal weightKg) {
    }

    // Same clinical fields as CREATE; the visit (appointment) cannot be changed
    public record UpdateRecordRequest(
            @Size(max = 1000, message = "Diagnosis must be at most 1000 characters")
            String diagnosis,

            @Size(max = 5000, message = "Clinical notes must be at most 5000 characters")
            String clinicalNotes,

            @Pattern(regexp = "^[0-9]{2,3}/[0-9]{2,3}$", message = "Blood pressure must look like 120/80")
            String bloodPressure,

            @Min(value = 20, message = "Pulse must be between 20 and 250")
            @Max(value = 250, message = "Pulse must be between 20 and 250")
            Integer pulseBpm,

            @DecimalMin(value = "30.0", message = "Temperature must be between 30 and 45 degrees C")
            @DecimalMax(value = "45.0", message = "Temperature must be between 30 and 45 degrees C")
            BigDecimal temperatureC,

            @DecimalMin(value = "0.5", message = "Weight must be between 0.5 and 400 kg")
            @DecimalMax(value = "400", message = "Weight must be between 0.5 and 400 kg")
            BigDecimal weightKg) {
    }

    public record MedicalRecordResponse(Long id, Long hospitalId, Long appointmentId, Long patientId,
                                        Long doctorId, String diagnosis, String clinicalNotes,
                                        String bloodPressure, Integer pulseBpm,
                                        BigDecimal temperatureC, BigDecimal weightKg) {

        public static MedicalRecordResponse from(MedicalRecord record) {
            return new MedicalRecordResponse(record.getId(), record.getHospitalId(),
                    record.getAppointmentId(), record.getPatientId(), record.getDoctorId(),
                    record.getDiagnosis(), record.getClinicalNotes(), record.getBloodPressure(),
                    record.getPulseBpm(), record.getTemperatureC(), record.getWeightKg());
        }
    }
}
