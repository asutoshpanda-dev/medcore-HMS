package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.dto.MedicalRecordDtos.CreateRecordRequest;
import com.medcore.hms.dto.MedicalRecordDtos.MedicalRecordResponse;
import com.medcore.hms.dto.MedicalRecordDtos.UpdateRecordRequest;
import com.medcore.hms.service.MedicalRecordService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

// Doctor and hospital admin only (see SecurityConfig). Patients read their own records via /api/me.
@RestController
@RequestMapping("/api/medical-records")
public class MedicalRecordController {

    private final MedicalRecordService medicalRecordService;

    public MedicalRecordController(MedicalRecordService medicalRecordService) {
        this.medicalRecordService = medicalRecordService;
    }

    @PostMapping
    public ApiResponse<MedicalRecordResponse> createRecord(@Valid @RequestBody CreateRecordRequest request) {
        return ApiResponse.of(MedicalRecordResponse.from(medicalRecordService.createRecord(request)));
    }

    @GetMapping("/{id}")
    public ApiResponse<MedicalRecordResponse> getRecord(@PathVariable Long id) {
        return ApiResponse.of(MedicalRecordResponse.from(medicalRecordService.getRecord(id)));
    }

    @PutMapping("/{id}")
    public ApiResponse<MedicalRecordResponse> updateRecord(@PathVariable Long id,
                                                           @Valid @RequestBody UpdateRecordRequest request) {
        return ApiResponse.of(MedicalRecordResponse.from(medicalRecordService.updateRecord(id, request)));
    }
}
