package com.medcore.hms.service;

import com.medcore.hms.entity.LoginAttempt;
import com.medcore.hms.repository.LoginAttemptRepository;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;

// Slows down password guessing. Five wrong passwords for a username, with no pause of 15 minutes
// or more between them, lock that username for 15 minutes. Failures are counted for every username
// sent, including ones that do not exist, so a locked answer never shows whether an account exists.
// The counts live in the database, so they survive a restart and work with several server instances.
@Service
public class LoginAttemptService {

    static final int MAX_FAILURES = 5;
    static final Duration WINDOW = Duration.ofMinutes(15);
    static final Duration LOCK_FOR = Duration.ofMinutes(15);

    private final LoginAttemptRepository attempts;
    private final Clock clock;

    public LoginAttemptService(LoginAttemptRepository attempts, Clock clock) {
        this.attempts = attempts;
        this.clock = clock;
    }

    // Refuses with 429 while the username is locked
    public void assertNotLocked(String username) {
        Instant now = Instant.now(clock);
        boolean locked = attempts.findById(key(username))
                .map(LoginAttempt::getLockedUntil)
                .map(until -> now.isBefore(until))
                .orElse(false);

        if (locked) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Too many failed login attempts. Try again in a few minutes.");
        }
    }

    @Transactional
    public void recordFailure(String username) {
        Instant now = Instant.now(clock);
        LoginAttempt a = attempts.findById(key(username))
                .orElseGet(() -> new LoginAttempt(key(username)));

        int failures = isStale(a, now) ? 1 : a.getFailures() + 1;
        a.setFailures(failures);
        a.setLastFailure(now);
        a.setLockedUntil(failures >= MAX_FAILURES ? now.plus(LOCK_FOR) : null);
        attempts.save(a);
    }

    // A successful login clears the count
    @Transactional
    public void reset(String username) {
        attempts.findById(key(username)).ifPresent(attempts::delete);
    }

    // Removes counts that can no longer affect anyone. Runs every 15 minutes.
    @Scheduled(fixedDelay = 900_000)
    @Transactional
    public void purgeStale() {
        attempts.deleteOlderThan(Instant.now(clock).minus(WINDOW));
    }

    // A count is stale once 15 minutes have passed since its last failure and any lock has ended
    private boolean isStale(LoginAttempt a, Instant now) {
        if (a.getLastFailure() == null) {
            return true;
        }
        boolean quietLongEnough = !now.isBefore(a.getLastFailure().plus(WINDOW));
        boolean lockEnded = a.getLockedUntil() == null || !now.isBefore(a.getLockedUntil());
        return quietLongEnough && lockEnded;
    }

    // Case and surrounding spaces do not give a new set of tries
    private String key(String username) {
        return Sha256.hex(username == null ? "" : username.trim().toLowerCase(Locale.ROOT));
    }
}
