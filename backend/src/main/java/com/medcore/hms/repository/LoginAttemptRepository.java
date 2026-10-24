package com.medcore.hms.repository;

import com.medcore.hms.entity.LoginAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;

public interface LoginAttemptRepository extends JpaRepository<LoginAttempt, String> {

    // Only rows whose count has gone stale (no lock is still running for them)
    @Modifying
    @Query("delete from LoginAttempt a where a.lastFailure < :before")
    int deleteOlderThan(@Param("before") Instant before);
}
