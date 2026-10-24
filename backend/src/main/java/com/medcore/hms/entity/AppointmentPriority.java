package com.medcore.hms.entity;

public enum AppointmentPriority {
    NORMAL,       // regular slot: checked for doctor and patient conflicts
    EMERGENCY     // accepted even when the doctor's slot is taken; the doctor sees it first
}
