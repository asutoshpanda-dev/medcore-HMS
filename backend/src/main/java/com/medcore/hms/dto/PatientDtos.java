package com.medcore.hms.dto;

import com.medcore.hms.entity.Patient;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public final class PatientDtos {

    private PatientDtos() {
    }

    // What staff or a patient send to create or change a patient. The id and hospital are never sent.
    public record PatientRequest(
            @NotBlank(message = "Full name is required")
            String fullName,

            @Min(value = 1, message = "Age must be at least 1")
            @Max(value = 120, message = "Age must not exceed 120")
            int age,

            @NotBlank(message = "Gender is required")
            String gender,

            @NotBlank(message = "Phone number is required")
            @Pattern(regexp = "^[0-9]{10}$", message = "Phone number must contain exactly 10 digits")
            String phone) {

        public Patient toEntity() {
            Patient patient = new Patient();
            patient.setFullName(fullName);
            patient.setAge(age);
            patient.setGender(gender);
            patient.setPhone(phone);
            return patient;
        }
    }

    public record PatientResponse(Long id, Long hospitalId, String fullName,
                                  int age, String gender, String phone) {

        public static PatientResponse from(Patient patient) {
            return new PatientResponse(patient.getId(), patient.getHospitalId(), patient.getFullName(),
                    patient.getAge(), patient.getGender(), patient.getPhone());
        }
    }
}
