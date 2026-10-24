package com.medcore.hms.exception;

public class PrescriptionNotFoundException extends RuntimeException {

    public PrescriptionNotFoundException(String message) {
        super(message);
    }
}