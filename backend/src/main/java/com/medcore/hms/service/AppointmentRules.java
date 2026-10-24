package com.medcore.hms.service;

import com.medcore.hms.entity.AppointmentStatus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

// Scheduling rules for appointments, kept in one place
@Component
public class AppointmentRules {

    // Statuses that hold a doctor's or a patient's time
    public static final Set<AppointmentStatus> ACTIVE = EnumSet.of(
            AppointmentStatus.PENDING,
            AppointmentStatus.CONFIRMED,
            AppointmentStatus.IN_PROGRESS);

    // Allowed status changes. Statuses not listed here (COMPLETED, CANCELLED, NO_SHOW) are final.
    private static final Map<AppointmentStatus, Set<AppointmentStatus>> NEXT = Map.of(
            AppointmentStatus.PENDING, EnumSet.of(
                    AppointmentStatus.CONFIRMED, AppointmentStatus.CANCELLED),
            AppointmentStatus.CONFIRMED, EnumSet.of(
                    AppointmentStatus.IN_PROGRESS, AppointmentStatus.CANCELLED, AppointmentStatus.NO_SHOW),
            AppointmentStatus.IN_PROGRESS, EnumSet.of(
                    AppointmentStatus.COMPLETED));

    private final LocalTime opening;
    private final LocalTime closing;
    private final int slotMinutes;
    private final Clock clock;   // the application clock; tests pass a fixed one

    public AppointmentRules(@Value("${app.schedule.open:09:00}") String opening,
                            @Value("${app.schedule.close:17:00}") String closing,
                            @Value("${app.schedule.slot-minutes:15}") int slotMinutes,
                            Clock clock) {
        this.opening = LocalTime.parse(opening);
        this.closing = LocalTime.parse(closing);
        this.slotMinutes = slotMinutes;
        this.clock = clock;
    }

    // The date is not in the past. For today, the time must be later than the current time.
    // The start time is on the slot grid and inside opening hours.
    public void validateSlot(LocalDate date, LocalTime time) {

        LocalDateTime now = LocalDateTime.now(clock);

        if (date.isBefore(now.toLocalDate())) {
            throw badRequest("Appointment date cannot be in the past");
        }

        if (date.equals(now.toLocalDate()) && !time.isAfter(now.toLocalTime())) {
            throw badRequest("Today's appointment time must be later than the current time");
        }

        if (time.isBefore(opening) || !time.isBefore(closing)) {
            throw badRequest("Appointments are booked between " + opening + " and " + closing);
        }

        if (time.getSecond() != 0 || time.getNano() != 0 || time.getMinute() % slotMinutes != 0) {
            throw badRequest("Appointment times must be a multiple of " + slotMinutes
                    + " minutes past the hour, for example 10:00 or 10:" + slotMinutes);
        }
    }

    public void validateTransition(AppointmentStatus from, AppointmentStatus to) {
        if (!NEXT.getOrDefault(from, Set.of()).contains(to)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "An appointment cannot change from " + from + " to " + to);
        }
    }

    private ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
