package com.medcore.hms.service;

// Delivers a password reset code. Step 9 has one implementation (LogOtpSender, for development).
// A real email sender implements this same interface.
public interface OtpSender {

    void send(String toEmail, String code);
}
