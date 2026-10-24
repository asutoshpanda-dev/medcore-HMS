package com.medcore.hms.service;

import com.medcore.hms.entity.AppUser;
import com.medcore.hms.entity.PasswordResetCode;
import com.medcore.hms.repository.PasswordResetCodeRepository;
import com.medcore.hms.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

// Password reset: a six-digit code is sent to the account's email and must be entered with the new password.
@Service
public class PasswordResetService {

    static final Duration CODE_LIFETIME = Duration.ofMinutes(10);
    static final Duration RESEND_WAIT = Duration.ofSeconds(60);
    static final int MAX_ATTEMPTS = 5;

    private final UserRepository userRepository;
    private final PasswordResetCodeRepository codes;
    private final PasswordEncoder passwordEncoder;
    private final OtpSender otpSender;
    private final RefreshTokenService refreshTokens;
    private final LoginAttemptService loginAttempts;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public PasswordResetService(UserRepository userRepository,
                                PasswordResetCodeRepository codes,
                                PasswordEncoder passwordEncoder,
                                OtpSender otpSender,
                                RefreshTokenService refreshTokens,
                                LoginAttemptService loginAttempts,
                                Clock clock) {
        this.userRepository = userRepository;
        this.codes = codes;
        this.passwordEncoder = passwordEncoder;
        this.otpSender = otpSender;
        this.refreshTokens = refreshTokens;
        this.loginAttempts = loginAttempts;
        this.clock = clock;
    }

    // Always answers the same way, so the answer does not reveal which usernames exist
    @Transactional
    public void requestCode(String username) {
        Instant now = Instant.now(clock);
        AppUser user = userRepository.findByUsername(username).orElse(null);

        if (user == null || user.getEmail() == null) {
            passwordEncoder.encode("timing-filler");   // roughly the same work as the real path
            return;
        }

        Optional<PasswordResetCode> latest =
                codes.findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(user.getId());
        if (latest.isPresent() && latest.get().getCreatedAt().plus(RESEND_WAIT).isAfter(now)) {
            return;   // a code was sent a moment ago and is still valid
        }

        codes.invalidateAllForUser(user.getId());
        String code = String.format("%06d", random.nextInt(1_000_000));
        codes.save(new PasswordResetCode(user.getId(), passwordEncoder.encode(code),
                now.plus(CODE_LIFETIME), now));
        otpSender.send(user.getEmail(), code);
    }

    // noRollbackFor: wrong guesses are saved even though the request is refused
    @Transactional(noRollbackFor = ResponseStatusException.class)
    public void confirm(String username, String code, String newPassword) {
        Instant now = Instant.now(clock);

        AppUser user = userRepository.findByUsername(username)
                .orElseThrow(() -> invalidCode());
        PasswordResetCode entry = codes.findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(user.getId())
                .orElseThrow(() -> invalidCode());

        if (!now.isBefore(entry.getExpiresAt()) || entry.getAttempts() >= MAX_ATTEMPTS) {
            entry.setUsed(true);
            throw invalidCode();
        }
        if (!passwordEncoder.matches(code, entry.getCodeHash())) {
            entry.setAttempts(entry.getAttempts() + 1);
            if (entry.getAttempts() >= MAX_ATTEMPTS) {
                entry.setUsed(true);
            }
            throw invalidCode();
        }

        entry.setUsed(true);
        user.setPassword(passwordEncoder.encode(newPassword));
        refreshTokens.revokeAll(user.getId());
        loginAttempts.reset(username);   // the email proves ownership, so a lock ends
    }

    private static ResponseStatusException invalidCode() {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "The code is wrong or has expired. Ask for a new code.");
    }
}
