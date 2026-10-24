package com.medcore.hms.entity;

public enum Role {
    SUPER_ADMIN,      // platform level: creates and verifies hospitals, no access to patient data
    HOSPITAL_ADMIN,   // runs one hospital
    DOCTOR,
    NURSE,
    RECEPTIONIST,
    LAB_TECHNICIAN,
    PHARMACIST,
    ACCOUNTANT,
    PATIENT
}
