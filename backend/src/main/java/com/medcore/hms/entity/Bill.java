package com.medcore.hms.entity;

import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.SQLRestriction;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@SQLRestriction("deleted = false")
@SQLDelete(sql = "UPDATE bill SET deleted = true WHERE id = ?")
public class Bill extends SoftDeletable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull(message = "Patient ID is required")
    @Column(name = "patient_id")
    private Long patientId;

    @NotNull(message = "Appointment ID is required")
    @Column(name = "appointment_id")
    private Long appointmentId;

    @NotNull(message = "Consultation fee is required")
    @PositiveOrZero(message = "Consultation fee cannot be negative")
    @Column(precision = 10, scale = 2)
    private BigDecimal consultationFee;

    @NotNull(message = "Medicine fee is required")
    @PositiveOrZero(message = "Medicine fee cannot be negative")
    @Column(precision = 10, scale = 2)
    private BigDecimal medicineFee;

    // Calculated by the server, so the client does not send it
    @Column(precision = 10, scale = 2)
    private BigDecimal totalAmount;

    @NotNull(message = "Payment status is required")
    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    private PaymentStatus paymentStatus;

    // Optional: empty while the bill is unpaid
    private LocalDate paymentDate;

    public Bill() {
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getPatientId() { return patientId; }
    public void setPatientId(Long patientId) { this.patientId = patientId; }

    public Long getAppointmentId() { return appointmentId; }
    public void setAppointmentId(Long appointmentId) { this.appointmentId = appointmentId; }

    public BigDecimal getConsultationFee() { return consultationFee; }
    public void setConsultationFee(BigDecimal consultationFee) { this.consultationFee = consultationFee; }

    public BigDecimal getMedicineFee() { return medicineFee; }
    public void setMedicineFee(BigDecimal medicineFee) { this.medicineFee = medicineFee; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public PaymentStatus getPaymentStatus() { return paymentStatus; }
    public void setPaymentStatus(PaymentStatus paymentStatus) { this.paymentStatus = paymentStatus; }

    public LocalDate getPaymentDate() { return paymentDate; }
    public void setPaymentDate(LocalDate paymentDate) { this.paymentDate = paymentDate; }

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "patient_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_bill_patient"))
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "appointment_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_bill_appointment"))
    private Appointment appointment;
}