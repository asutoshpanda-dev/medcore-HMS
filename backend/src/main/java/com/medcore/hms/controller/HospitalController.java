package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.HospitalDtos.HospitalRequest;
import com.medcore.hms.dto.HospitalDtos.HospitalResponse;
import com.medcore.hms.service.HospitalService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

// Super admin only (see SecurityConfig)
@RestController
@RequestMapping("/api/hospitals")
public class HospitalController {

    private final HospitalService hospitalService;

    public HospitalController(HospitalService hospitalService) {
        this.hospitalService = hospitalService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<HospitalResponse>> createHospital(@Valid @RequestBody HospitalRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.of(HospitalResponse.from(hospitalService.createHospital(request))));
    }

    @GetMapping
    public PageResponse<HospitalResponse> getAllHospitals(
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {

        return PageResponse.of(hospitalService.getAllHospitals(pageable), HospitalResponse::from);
    }

    @PatchMapping("/{id}/verify")
    public ApiResponse<HospitalResponse> verifyHospital(@PathVariable Long id) {
        return ApiResponse.of(HospitalResponse.from(hospitalService.verifyHospital(id)));
    }
}
