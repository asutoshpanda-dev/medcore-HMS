package com.medcore.hms.dto;

import com.medcore.hms.entity.Hospital;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class HospitalDtos {

    private HospitalDtos() {
    }

    public record HospitalRequest(
            @NotBlank(message = "Hospital name is required")
            @Size(max = 150, message = "Hospital name must be at most 150 characters")
            String name,

            @NotBlank(message = "City is required")
            @Size(max = 100, message = "City must be at most 100 characters")
            String city,

            @NotBlank(message = "Contact email is required")
            @Email(message = "Please provide a valid email address")
            @Size(max = 150, message = "Contact email must be at most 150 characters")
            String contactEmail) {
    }

    public record HospitalResponse(Long id, String name, String city,
                                   String contactEmail, boolean verified) {

        public static HospitalResponse from(Hospital hospital) {
            return new HospitalResponse(hospital.getId(), hospital.getName(), hospital.getCity(),
                    hospital.getContactEmail(), hospital.isVerified());
        }
    }
}
