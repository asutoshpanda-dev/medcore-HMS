package com.medcore.hms.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;

// Clinical notes of one visit. One record per appointment.
@Entity
@Table(name = "medical_record")
public class MedicalRecord extends TenantOwned {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "appointment_id", nullable = false, unique = true)
    private Long appointmentId;

    @Column(name = "patient_id", nullable = false)
    private Long patientId;

    @Column(name = "doctor_id", nullable = false)
    private Long doctorId;

    @Column(length = 1000)
    private String diagnosis;

    @Column(length = 5000)
    private String clinicalNotes;

    @Column(length = 10)
    private String bloodPressure;         // e.g. "120/80"

    private Integer pulseBpm;

    // Column name is set explicitly; Spring's default would be temperaturec. V2 renamed it to temperature_c.
    @Column(name = "temperature_c", precision = 4, scale = 1)
    private BigDecimal temperatureC;

    @Column(precision = 5, scale = 1)
    private BigDecimal weightKg;

    public MedicalRecord() {
    }

    public Long getId() {
        return id;
    }

    public Long getAppointmentId() {
        return appointmentId;
    }

    public void setAppointmentId(Long appointmentId) {
        this.appointmentId = appointmentId;
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

    public String getDiagnosis() {
        return diagnosis;
    }

    public void setDiagnosis(String diagnosis) {
        this.diagnosis = diagnosis;
    }

    public String getClinicalNotes() {
        return clinicalNotes;
    }

    public void setClinicalNotes(String clinicalNotes) {
        this.clinicalNotes = clinicalNotes;
    }

    public String getBloodPressure() {
        return bloodPressure;
    }

    public void setBloodPressure(String bloodPressure) {
        this.bloodPressure = bloodPressure;
    }

    public Integer getPulseBpm() {
        return pulseBpm;
    }

    public void setPulseBpm(Integer pulseBpm) {
        this.pulseBpm = pulseBpm;
    }

    public BigDecimal getTemperatureC() {
        return temperatureC;
    }

    public void setTemperatureC(BigDecimal temperatureC) {
        this.temperatureC = temperatureC;
    }

    public BigDecimal getWeightKg() {
        return weightKg;
    }

    public void setWeightKg(BigDecimal weightKg) {
        this.weightKg = weightKg;
    }

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "appointment_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_medical_record_appointment"))
    private Appointment appointment;
}
