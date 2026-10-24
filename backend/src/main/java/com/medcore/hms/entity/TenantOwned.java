package com.medcore.hms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.MappedSuperclass;

/**
 * Base class for every record that belongs to exactly one hospital (a "tenant").
 *
 * The hospital id is always set by the server from the logged-in user,
 * never taken from the request body.
 */
@MappedSuperclass
public abstract class TenantOwned {

    @Column(name = "hospital_id", nullable = false)
    private Long hospitalId;

    // Read-only link: it exists only so the database enforces the foreign key
    // (same pattern as the patient/doctor links). Do not add a getter or setter.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hospital_id", insertable = false, updatable = false)
    private Hospital hospital;

    public Long getHospitalId() {
        return hospitalId;
    }

    public void setHospitalId(Long hospitalId) {
        this.hospitalId = hospitalId;
    }
}
