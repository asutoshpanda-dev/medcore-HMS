package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.AppointmentDtos.AppointmentRequest;
import com.medcore.hms.dto.AppointmentDtos.AppointmentResponse;
import com.medcore.hms.entity.AppointmentStatus;
import com.medcore.hms.service.AppointmentService;
import com.medcore.hms.dto.StatusDtos.AppointmentStatusRequest;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/appointments")
public class AppointmentController {

    private final AppointmentService appointmentService;

    public AppointmentController(AppointmentService appointmentService) {
        this.appointmentService = appointmentService;
    }

    @PostMapping
    public ApiResponse<AppointmentResponse> saveAppointment(@Valid @RequestBody AppointmentRequest request) {
        return ApiResponse.of(AppointmentResponse.from(
                appointmentService.saveAppointment(request.toEntity())));
    }

    // Optional filters: ?date=2027-02-10 and ?status=CONFIRMED
    @GetMapping
    public PageResponse<AppointmentResponse> getAllAppointments(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) AppointmentStatus status,
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {

        return PageResponse.of(appointmentService.getAllAppointments(date, status, pageable),
                AppointmentResponse::from);
    }

    @PutMapping("/{id}")
    public ApiResponse<AppointmentResponse> updateAppointment(
            @PathVariable Long id,
            @Valid @RequestBody AppointmentRequest request) {

        return ApiResponse.of(AppointmentResponse.from(
                appointmentService.updateAppointment(id, request.toEntity())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAppointment(@PathVariable Long id) {

        appointmentService.deleteAppointment(id);

        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/status")
    public ApiResponse<AppointmentResponse> updateStatus(
            @PathVariable Long id,
            @Valid @RequestBody AppointmentStatusRequest request) {

        return ApiResponse.of(AppointmentResponse.from(
                appointmentService.updateStatus(id, request.status())));
    }
}
