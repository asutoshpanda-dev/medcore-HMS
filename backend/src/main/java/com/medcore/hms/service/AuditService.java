package com.medcore.hms.service;

import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.AuditLog;
import com.medcore.hms.repository.AuditLogRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;

// The audit trail. recordChange runs inside the caller's transaction, so a change and its
// audit entry are saved together, or not at all.
@Service
public class AuditService {

    private final AuditLogRepository auditLogRepository;
    private final CurrentUserService currentUserService;
    private final Clock clock;

    public AuditService(AuditLogRepository auditLogRepository,
                        CurrentUserService currentUserService,
                        Clock clock) {
        this.auditLogRepository = auditLogRepository;
        this.currentUserService = currentUserService;
        this.clock = clock;
    }

    public void recordChange(AuditAction action, String entityType, Long entityId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String username = auth == null ? "unknown" : auth.getName();
        auditLogRepository.save(new AuditLog(
                currentUserService.hospitalId(), username, action,
                entityType, entityId, Instant.now(clock)));
    }

    @Transactional(readOnly = true)
    public Page<AuditLog> list(String entityType, Long entityId, Pageable pageable) {
        Specification<AuditLog> spec = ListFilters.<AuditLog>inHospital(currentUserService.hospitalId());
        spec = ListFilters.and(spec, ListFilters.<AuditLog>equal("entityType", entityType));
        spec = ListFilters.and(spec, ListFilters.<AuditLog>equal("entityId", entityId));
        return auditLogRepository.findAll(spec, pageable);
    }
}
