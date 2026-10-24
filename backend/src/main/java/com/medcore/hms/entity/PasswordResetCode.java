package com.medcore.hms.entity;

import jakarta.persistence.*;

import java.time.Instant;

// A six-digit code emailed for a password reset. Only its BCrypt hash is stored.
@Entity
@Table(name = "password_reset_code")
public class PasswordResetCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "code_hash", nullable = false, length = 100)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    // Wrong guesses so far. The code stops working at the limit.
    @Column(nullable = false)
    private int attempts;

    // Set when the code is used, after too many wrong guesses, or when a newer code replaces it
    @Column(name = "code_used", nullable = false)
    private boolean used;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PasswordResetCode() {
    }

    public PasswordResetCode(Long userId, String codeHash, Instant expiresAt, Instant createdAt) {
        this.userId = userId;
        this.codeHash = codeHash;
        this.expiresAt = expiresAt;
        this.createdAt = createdAt;
        this.attempts = 0;
        this.used = false;
    }

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public String getCodeHash() { return codeHash; }
    public Instant getExpiresAt() { return expiresAt; }
    public Instant getCreatedAt() { return createdAt; }
    public int getAttempts() { return attempts; }
    public boolean isUsed() { return used; }

    public void setAttempts(int attempts) { this.attempts = attempts; }
    public void setUsed(boolean used) { this.used = used; }

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_password_reset_user"))
    private AppUser user;
}
