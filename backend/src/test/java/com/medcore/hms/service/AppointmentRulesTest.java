package com.medcore.hms.service;

import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

// No Spring context and no database: the clock is fixed, so "now" is always the same.
class AppointmentRulesTest {

    // The fixed "now" for every test: 22 December 2026, 10:15 UTC
    private static final Instant NOW = Instant.parse("2026-12-22T10:15:00Z");
    private static final LocalDate TODAY = LocalDate.of(2026, 12, 22);

    private final AppointmentRules rules = new AppointmentRules(
            "09:00", "17:00", 15, Clock.fixed(NOW, ZoneId.of("UTC")));

    @Test
    void todayAtATimeThatHasPassedIsRefused() {
        assertThrows(ResponseStatusException.class,
                () -> rules.validateSlot(TODAY, LocalTime.of(10, 0)));
    }

    @Test
    void todayAtTheCurrentTimeIsRefused() {
        assertThrows(ResponseStatusException.class,
                () -> rules.validateSlot(TODAY, LocalTime.of(10, 15)));
    }

    @Test
    void todayLaterThanNowIsAccepted() {
        assertDoesNotThrow(() -> rules.validateSlot(TODAY, LocalTime.of(10, 30)));
    }

    @Test
    void yesterdayIsRefused() {
        assertThrows(ResponseStatusException.class,
                () -> rules.validateSlot(LocalDate.of(2026, 12, 21), LocalTime.of(11, 0)));
    }

    @Test
    void tomorrowAtAnOpeningSlotIsAccepted() {
        assertDoesNotThrow(() -> rules.validateSlot(LocalDate.of(2026, 12, 23), LocalTime.of(9, 0)));
    }

    @Test
    void closingTimeIsRefused() {
        assertThrows(ResponseStatusException.class,
                () -> rules.validateSlot(LocalDate.of(2026, 12, 23), LocalTime.of(17, 0)));
    }

    @Test
    void timeOffTheSlotGridIsRefused() {
        assertThrows(ResponseStatusException.class,
                () -> rules.validateSlot(LocalDate.of(2026, 12, 23), LocalTime.of(10, 20)));
    }
}
