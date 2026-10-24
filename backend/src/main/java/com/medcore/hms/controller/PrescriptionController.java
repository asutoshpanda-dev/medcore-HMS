package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.PrescriptionDtos.PrescriptionRequest;
import com.medcore.hms.dto.PrescriptionDtos.PrescriptionResponse;
import com.medcore.hms.dto.StatusDtos.PrescriptionStatusRequest;
import com.medcore.hms.entity.PrescriptionStatus;
import com.medcore.hms.service.PrescriptionService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/prescriptions")
public class PrescriptionController {

    private final PrescriptionService prescriptionService;

    public PrescriptionController(PrescriptionService prescriptionService) {
        this.prescriptionService = prescriptionService;
    }

    @PostMapping
    public ApiResponse<PrescriptionResponse> savePrescription(@Valid @RequestBody PrescriptionRequest request) {
        return ApiResponse.of(PrescriptionResponse.from(
                prescriptionService.savePrescription(request.toEntity())));
    }

    // Optional filter: ?status=ACTIVE, COMPLETED or CANCELLED
    @GetMapping
    public PageResponse<PrescriptionResponse> getAllPrescriptions(
            @RequestParam(required = false) PrescriptionStatus status,
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {

        return PageResponse.of(prescriptionService.getAllPrescriptions(status, pageable),
                PrescriptionResponse::from);
    }

    @PutMapping("/{id}")
    public ApiResponse<PrescriptionResponse> updatePrescription(
            @PathVariable Long id,
            @Valid @RequestBody PrescriptionRequest request) {

        return ApiResponse.of(PrescriptionResponse.from(
                prescriptionService.updatePrescription(id, request.toEntity())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePrescription(@PathVariable Long id) {

        prescriptionService.deletePrescription(id);

        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/status")
    public ApiResponse<PrescriptionResponse> updateStatus(
            @PathVariable Long id,
            @Valid @RequestBody PrescriptionStatusRequest request) {

        return ApiResponse.of(PrescriptionResponse.from(
                prescriptionService.updateStatus(id, request.status())));
    }
}
