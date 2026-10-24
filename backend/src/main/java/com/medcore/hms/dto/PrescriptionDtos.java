package com.medcore.hms.dto;

import com.medcore.hms.entity.Prescription;
import com.medcore.hms.entity.PrescriptionItem;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.ArrayList;
import java.util.List;

public final class PrescriptionDtos {

    private PrescriptionDtos() {
    }

    public record PrescriptionRequest(
            @NotNull(message = "Patient ID is required") Long patientId,
            @NotNull(message = "Doctor ID is required") Long doctorId,
            @NotNull(message = "Appointment ID is required") Long appointmentId,
            @NotBlank(message = "Instructions are required") String instructions,
            @NotEmpty(message = "At least one medicine is required") List<@Valid MedicineRequest> items) {

        public Prescription toEntity() {
            Prescription prescription = new Prescription();
            prescription.setPatientId(patientId);
            prescription.setDoctorId(doctorId);
            prescription.setAppointmentId(appointmentId);
            prescription.setInstructions(instructions);
            List<PrescriptionItem> rows = new ArrayList<>();
            for (MedicineRequest item : items) {
                rows.add(item.toEntity());
            }
            prescription.setItems(rows);
            return prescription;
        }
    }

    // One medicine. Its id is never sent; each save creates new rows.
    public record MedicineRequest(
            @NotBlank(message = "Medicine name is required")
            @Size(max = 255, message = "Medicine name must be at most 255 characters")
            String medicineName,

            @NotBlank(message = "Dosage is required")
            @Size(max = 255, message = "Dosage must be at most 255 characters")
            String dosage,

            @NotBlank(message = "Frequency is required")
            @Size(max = 255, message = "Frequency must be at most 255 characters")
            String frequency,

            @NotBlank(message = "Duration is required")
            @Size(max = 255, message = "Duration must be at most 255 characters")
            String duration) {

        public PrescriptionItem toEntity() {
            return new PrescriptionItem(medicineName, dosage, frequency, duration);
        }
    }

    public record PrescriptionResponse(Long id, Long hospitalId, Long patientId, Long doctorId,
                                       Long appointmentId, String instructions, String status,
                                       List<MedicineResponse> items) {

        public static PrescriptionResponse from(Prescription prescription) {
            List<MedicineResponse> rows = new ArrayList<>();
            for (PrescriptionItem item : prescription.getItems()) {
                rows.add(MedicineResponse.from(item));
            }
            return new PrescriptionResponse(prescription.getId(), prescription.getHospitalId(),
                    prescription.getPatientId(), prescription.getDoctorId(), prescription.getAppointmentId(),
                    prescription.getInstructions(), prescription.getStatus(), rows);
        }
    }

    public record MedicineResponse(Long id, String medicineName, String dosage,
                                   String frequency, String duration) {

        public static MedicineResponse from(PrescriptionItem item) {
            return new MedicineResponse(item.getId(), item.getMedicineName(), item.getDosage(),
                    item.getFrequency(), item.getDuration());
        }
    }
}