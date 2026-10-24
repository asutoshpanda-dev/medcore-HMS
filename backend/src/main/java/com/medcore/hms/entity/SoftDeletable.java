package com.medcore.hms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;

// Records are hidden, not removed. DELETE sets this flag (the @SQLDelete on each entity does it),
// and @SQLRestriction hides flagged rows from every query. There is no getter on purpose:
// the API never returns the flag.
@MappedSuperclass
public abstract class SoftDeletable extends TenantOwned {

    @Column(name = "deleted", nullable = false)
    private boolean deleted;
}
