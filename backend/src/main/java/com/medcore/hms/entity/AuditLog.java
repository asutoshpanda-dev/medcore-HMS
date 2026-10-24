package com.medcore.hms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;

// Append-only trail of changes to clinical and admin records. It stores who made the change,
// what kind of change it was, which record it was, and when. It does not store field values,
// so no medical data is copied into the log.
@Entity
@Table(name = "audit_log", indexes = {
        @Index(name = "idx_audit_hospital_entity", columnList = "hospital_id, entity_type, entity_id")})
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "hospital_id", nullable = false)
    private Long hospitalId;

    @Column(nullable = false, length = 50)
    private String username;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 20)
    private AuditAction action;

    @Column(name = "entity_type", nullable = false, length = 40)
    private String entityType;

    @Column(name = "entity_id", nullable = false)
    private Long entityId;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    protected AuditLog() {
    }

    public AuditLog(Long hospitalId, String username, AuditAction action,
                    String entityType, Long entityId, Instant occurredAt) {
        this.hospitalId = hospitalId;
        this.username = username;
        this.action = action;
        this.entityType = entityType;
        this.entityId = entityId;
        this.occurredAt = occurredAt;
    }

    public Long getId() {
        return id;
    }

    public Long getHospitalId() {
        return hospitalId;
    }

    public String getUsername() {
        return username;
    }

    public AuditAction getAction() {
        return action;
    }

    public String getEntityType() {
        return entityType;
    }

    public Long getEntityId() {
        return entityId;
    }

    public Instant getOccurredAt() {
        return occurredAt;
    }
}
