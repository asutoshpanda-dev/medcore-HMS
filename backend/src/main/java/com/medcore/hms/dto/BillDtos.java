package com.medcore.hms.dto;

import com.medcore.hms.entity.Bill;
import com.medcore.hms.entity.PaymentStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.LocalDate;

public final class BillDtos {

    private BillDtos() {
    }

    // The total is calculated by the server, so it is not sent.
    public record BillRequest(
            @NotNull(message = "Patient ID is required") Long patientId,
            @NotNull(message = "Appointment ID is required") Long appointmentId,

            @NotNull(message = "Consultation fee is required")
            @PositiveOrZero(message = "Consultation fee cannot be negative")
            BigDecimal consultationFee,

            @NotNull(message = "Medicine fee is required")
            @PositiveOrZero(message = "Medicine fee cannot be negative")
            BigDecimal medicineFee,

            @NotNull(message = "Payment status is required") PaymentStatus paymentStatus,

            LocalDate paymentDate) {   // optional: only a paid bill has one

        public Bill toEntity() {
            Bill bill = new Bill();
            bill.setPatientId(patientId);
            bill.setAppointmentId(appointmentId);
            bill.setConsultationFee(consultationFee);
            bill.setMedicineFee(medicineFee);
            bill.setPaymentStatus(paymentStatus);
            bill.setPaymentDate(paymentDate);
            return bill;
        }
    }

    public record BillResponse(Long id, Long hospitalId, Long patientId, Long appointmentId,
                               BigDecimal consultationFee, BigDecimal medicineFee, BigDecimal totalAmount,
                               PaymentStatus paymentStatus, LocalDate paymentDate) {

        public static BillResponse from(Bill bill) {
            return new BillResponse(bill.getId(), bill.getHospitalId(), bill.getPatientId(),
                    bill.getAppointmentId(), bill.getConsultationFee(), bill.getMedicineFee(),
                    bill.getTotalAmount(), bill.getPaymentStatus(), bill.getPaymentDate());
        }
    }
}
