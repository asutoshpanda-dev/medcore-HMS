package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.PatientDtos.PatientRequest;
import com.medcore.hms.dto.PatientDtos.PatientResponse;
import com.medcore.hms.service.PatientService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/patients")
public class PatientController {

    private final PatientService patientService;

    public PatientController(PatientService patientService) {
        this.patientService = patientService;
    }

    @PostMapping
    public ApiResponse<PatientResponse> savePatient(@Valid @RequestBody PatientRequest request) {
        return ApiResponse.of(PatientResponse.from(patientService.savePatient(request.toEntity())));
    }

    // ?q= searches name and phone. Paging: ?page=0&size=20&sort=fullName,asc
    @GetMapping
    public PageResponse<PatientResponse> getAllPatients(
            @RequestParam(required = false) String q,
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {

        return PageResponse.of(patientService.getAllPatients(q, pageable), PatientResponse::from);
    }

    @PutMapping("/{id}")
    public ApiResponse<PatientResponse> updatePatient(
            @PathVariable Long id,
            @Valid @RequestBody PatientRequest request) {

        return ApiResponse.of(PatientResponse.from(patientService.updatePatient(id, request.toEntity())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePatient(@PathVariable Long id) {

        patientService.deletePatient(id);

        return ResponseEntity.noContent().build();
    }
}
