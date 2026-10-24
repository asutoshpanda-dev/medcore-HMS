package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.BillDtos.BillRequest;
import com.medcore.hms.dto.BillDtos.BillResponse;
import com.medcore.hms.entity.PaymentStatus;
import com.medcore.hms.service.BillService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/bills")
public class BillController {

    private final BillService billService;

    public BillController(BillService billService) {
        this.billService = billService;
    }

    @PostMapping
    public ApiResponse<BillResponse> saveBill(@Valid @RequestBody BillRequest request) {
        return ApiResponse.of(BillResponse.from(billService.saveBill(request.toEntity())));
    }

    // Optional filter: ?status=PAID or ?status=PENDING
    @GetMapping
    public PageResponse<BillResponse> getAllBills(
            @RequestParam(required = false) PaymentStatus status,
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {

        return PageResponse.of(billService.getAllBills(status, pageable), BillResponse::from);
    }

    @PutMapping("/{id}")
    public ApiResponse<BillResponse> updateBill(
            @PathVariable Long id,
            @Valid @RequestBody BillRequest request) {

        return ApiResponse.of(BillResponse.from(billService.updateBill(id, request.toEntity())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBill(@PathVariable Long id) {

        billService.deleteBill(id);

        return ResponseEntity.noContent().build();
    }
}
