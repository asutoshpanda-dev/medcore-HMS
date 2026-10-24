package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.DoctorDtos.DoctorRequest;
import com.medcore.hms.dto.DoctorDtos.DoctorResponse;
import com.medcore.hms.service.DoctorService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/doctors")
public class DoctorController {

    private final DoctorService doctorService;

    public DoctorController(DoctorService doctorService) {
        this.doctorService = doctorService;
    }

    @PostMapping
    public ApiResponse<DoctorResponse> saveDoctor(@Valid @RequestBody DoctorRequest request) {
        return ApiResponse.of(DoctorResponse.from(doctorService.saveDoctor(request.toEntity())));
    }

    // ?q= searches name and specialization
    @GetMapping
    public PageResponse<DoctorResponse> getAllDoctors(
            @RequestParam(required = false) String q,
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {

        return PageResponse.of(doctorService.getAllDoctors(q, pageable), DoctorResponse::from);
    }

    @PutMapping("/{id}")
    public ApiResponse<DoctorResponse> updateDoctor(
            @PathVariable Long id,
            @Valid @RequestBody DoctorRequest request) {

        return ApiResponse.of(DoctorResponse.from(doctorService.updateDoctor(id, request.toEntity())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteDoctor(@PathVariable Long id) {

        doctorService.deleteDoctor(id);

        return ResponseEntity.noContent().build();
    }
}
