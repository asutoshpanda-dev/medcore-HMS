package com.medcore.hms.dto;

import com.medcore.hms.entity.Doctor;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public final class DoctorDtos {

    private DoctorDtos() {
    }

    public record DoctorRequest(
            @NotBlank(message = "Doctor name is required")
            String fullName,

            @NotBlank(message = "Specialization is required")
            String specialization,

            @NotBlank(message = "Phone number is required")
            @Pattern(regexp = "^[0-9]{10}$", message = "Phone number must contain exactly 10 digits")
            String phone,

            @NotBlank(message = "Email is required")
            @Email(message = "Please provide a valid email address")
            String email) {

        public Doctor toEntity() {
            return new Doctor(null, fullName, specialization, phone, email);
        }
    }

    public record DoctorResponse(Long id, Long hospitalId, String fullName,
                                 String specialization, String phone, String email) {

        public static DoctorResponse from(Doctor doctor) {
            return new DoctorResponse(doctor.getId(), doctor.getHospitalId(), doctor.getFullName(),
                    doctor.getSpecialization(), doctor.getPhone(), doctor.getEmail());
        }
    }
}
