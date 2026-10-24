package com.medcore.hms.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

// DEVELOPMENT ONLY. Prints the reset code in the console instead of emailing it.
// Active only when app.otp.mode=log is set. Never use it on a server.
@Component
@ConditionalOnProperty(name = "app.otp.mode", havingValue = "log")
public class LogOtpSender implements OtpSender {

    private static final Logger log = LoggerFactory.getLogger(LogOtpSender.class);

    @Override
    public void send(String toEmail, String code) {
        log.warn("DEV ONLY - password reset code for {}: {}", toEmail, code);
    }
}
