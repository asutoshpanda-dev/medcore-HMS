package com.medcore.hms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

// Failed logins for one username. The key is a SHA-256 hash of the username, so unknown
// usernames are counted too, without storing the names themselves.
@Entity
@Table(name = "login_attempt")
public class LoginAttempt {

    @Id
    @Column(name = "attempt_key", length = 64)
    private String attemptKey;

    @Column(nullable = false)
    private int failures;

    @Column(name = "last_failure", nullable = false)
    private Instant lastFailure;

    @Column(name = "locked_until")
    private Instant lockedUntil;

    protected LoginAttempt() {
    }

    public LoginAttempt(String attemptKey) {
        this.attemptKey = attemptKey;
    }

    public String getAttemptKey() { return attemptKey; }
    public int getFailures() { return failures; }
    public Instant getLastFailure() { return lastFailure; }
    public Instant getLockedUntil() { return lockedUntil; }

    public void setFailures(int failures) { this.failures = failures; }
    public void setLastFailure(Instant lastFailure) { this.lastFailure = lastFailure; }
    public void setLockedUntil(Instant lockedUntil) { this.lockedUntil = lockedUntil; }
}
