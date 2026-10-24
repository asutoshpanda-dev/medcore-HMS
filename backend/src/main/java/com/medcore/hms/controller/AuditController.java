package com.medcore.hms.controller;

import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.AuditDtos.AuditLogResponse;
import com.medcore.hms.service.AuditService;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// Hospital admin only (see SecurityConfig). Newest entries first.
// Example: /api/audit-logs?entityType=Patient&entityId=12
@RestController
@RequestMapping("/api/audit-logs")
public class AuditController {

    private final AuditService auditService;

    public AuditController(AuditService auditService) {
        this.auditService = auditService;
    }

    @GetMapping
    public PageResponse<AuditLogResponse> list(
            @RequestParam(required = false) String entityType,
            @RequestParam(required = false) Long entityId,
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {

        return PageResponse.of(auditService.list(entityType, entityId, pageable), AuditLogResponse::from);
    }
}
