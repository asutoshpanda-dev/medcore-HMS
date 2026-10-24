package com.medcore.hms.entity;

import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.SQLRestriction;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import jakarta.persistence.*;

import java.util.ArrayList;
import java.util.List;

@Entity
@SQLRestriction("deleted = false")
@SQLDelete(sql = "UPDATE prescription SET deleted = true WHERE id = ?")
public class Prescription extends SoftDeletable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull(message = "Patient ID is required")
    @Column(name = "patient_id")
    private Long patientId;

    @NotNull(message = "Doctor ID is required")
    @Column(name = "doctor_id")
    private Long doctorId;

    @NotNull(message = "Appointment ID is required")
    @Column(name = "appointment_id")
    private Long appointmentId;

    @NotBlank(message = "Instructions are required")
    private String instructions;

    // The medicines of this prescription, one row each. Removing an item from the list deletes it.
    @NotEmpty(message = "At least one medicine is required")
    @Valid
    @OneToMany(cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @JoinColumn(name = "prescription_id", nullable = false)
    private List<PrescriptionItem> items = new ArrayList<>();

    private String status = PrescriptionStatus.ACTIVE.name();

    public Prescription() {
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getPatientId() {
        return patientId;
    }

    public void setPatientId(Long patientId) {
        this.patientId = patientId;
    }

    public Long getDoctorId() {
        return doctorId;
    }

    public void setDoctorId(Long doctorId) {
        this.doctorId = doctorId;
    }

    public Long getAppointmentId() {
        return appointmentId;
    }

    public void setAppointmentId(Long appointmentId) {
        this.appointmentId = appointmentId;
    }

    public String getInstructions() {
        return instructions;
    }

    public void setInstructions(String instructions) {
        this.instructions = instructions;
    }

    public List<PrescriptionItem> getItems() {
        return items;
    }

    public void setItems(List<PrescriptionItem> items) {
        this.items = items;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "patient_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_prescription_patient"))
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doctor_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_prescription_doctor"))
    private Doctor doctor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "appointment_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_prescription_appointment"))
    private Appointment appointment;
}
