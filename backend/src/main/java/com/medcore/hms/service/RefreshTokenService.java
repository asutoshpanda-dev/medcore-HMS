package com.medcore.hms.service;

import com.medcore.hms.entity.RefreshToken;
import com.medcore.hms.repository.RefreshTokenRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

// Refresh tokens are random strings stored only as hashes. Each use replaces the token with a new one.
// Using an old token again means it was copied, so every session of that user is ended.
@Service
public class RefreshTokenService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final RefreshTokenRepository tokens;
    private final Clock clock;
    private final long lifetimeDays;

    public RefreshTokenService(RefreshTokenRepository tokens,
                               Clock clock,
                               @Value("${app.jwt.refresh-days:14}") long lifetimeDays) {
        this.tokens = tokens;
        this.clock = clock;
        this.lifetimeDays = lifetimeDays;
    }

    // Returns the token text. It is shown to the client once and never stored in clear.
    @Transactional
    public String issue(Long userId) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);

        Instant now = Instant.now(clock);
        tokens.save(new RefreshToken(userId, Sha256.hex(raw),
                now.plus(Duration.ofDays(lifetimeDays)), now));
        return raw;
    }

    // Spends the token and returns the id of its user. Reuse also ends the user's other sessions.
    @Transactional(noRollbackFor = ResponseStatusException.class)
    public Long rotate(String rawToken) {
        RefreshToken stored = tokens.lockByTokenHash(Sha256.hex(rawToken))
                .orElseThrow(() -> invalid());

        if (stored.isRevoked()) {
            tokens.revokeAllForUser(stored.getUserId());
            throw invalid();
        }
        if (!Instant.now(clock).isBefore(stored.getExpiresAt())) {
            throw invalid();
        }

        stored.setRevoked(true);
        return stored.getUserId();
    }

    // Logout. An unknown token is ignored, so logging out twice is harmless.
    @Transactional
    public void revoke(String rawToken) {
        tokens.findByTokenHash(Sha256.hex(rawToken)).ifPresent(t -> t.setRevoked(true));
    }

    // Ends every session of one user (logout everywhere, password change, password reset)
    @Transactional
    public void revokeAll(Long userId) {
        tokens.revokeAllForUser(userId);
    }

    private static ResponseStatusException invalid() {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED,
                "Refresh token is not valid. Log in again.");
    }
}
