package com.medcore.hms.dto;

import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.AuditLog;

import java.time.Instant;

public final class AuditDtos {

    private AuditDtos() {
    }

    public record AuditLogResponse(Long id, Long hospitalId, String username, AuditAction action,
                                   String entityType, Long entityId, Instant occurredAt) {

        public static AuditLogResponse from(AuditLog log) {
            return new AuditLogResponse(log.getId(), log.getHospitalId(), log.getUsername(),
                    log.getAction(), log.getEntityType(), log.getEntityId(), log.getOccurredAt());
        }
    }
}
