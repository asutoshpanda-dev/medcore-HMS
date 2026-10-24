package com.medcore.hms.dto;

import com.medcore.hms.entity.AppointmentStatus;
import com.medcore.hms.entity.PrescriptionStatus;
import jakarta.validation.constraints.NotNull;

public final class StatusDtos {

    private StatusDtos() {
    }

    public record AppointmentStatusRequest(
            @NotNull(message = "Status is required") AppointmentStatus status) {
    }

    public record PrescriptionStatusRequest(
            @NotNull(message = "Status is required") PrescriptionStatus status) {
    }
}