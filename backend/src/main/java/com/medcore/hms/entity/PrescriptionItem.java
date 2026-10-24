package com.medcore.hms.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// One medicine inside a prescription
@Entity
@Table(name = "prescription_item")
public class PrescriptionItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank(message = "Medicine name is required")
    @Size(max = 255, message = "Medicine name must be at most 255 characters")
    private String medicineName;

    @NotBlank(message = "Dosage is required")
    @Size(max = 255, message = "Dosage must be at most 255 characters")
    private String dosage;            // e.g. "500 mg"

    @NotBlank(message = "Frequency is required")
    @Size(max = 255, message = "Frequency must be at most 255 characters")
    private String frequency;         // e.g. "twice a day"

    @NotBlank(message = "Duration is required")
    @Size(max = 255, message = "Duration must be at most 255 characters")
    private String duration;          // e.g. "5 days"

    public PrescriptionItem() {
    }

    public PrescriptionItem(String medicineName, String dosage, String frequency, String duration) {
        this.medicineName = medicineName;
        this.dosage = dosage;
        this.frequency = frequency;
        this.duration = duration;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getMedicineName() {
        return medicineName;
    }

    public void setMedicineName(String medicineName) {
        this.medicineName = medicineName;
    }

    public String getDosage() {
        return dosage;
    }

    public void setDosage(String dosage) {
        this.dosage = dosage;
    }

    public String getFrequency() {
        return frequency;
    }

    public void setFrequency(String frequency) {
        this.frequency = frequency;
    }

    public String getDuration() {
        return duration;
    }

    public void setDuration(String duration) {
        this.duration = duration;
    }
}
