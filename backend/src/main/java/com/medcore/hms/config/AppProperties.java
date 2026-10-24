package com.medcore.hms.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

// The settings the application cannot start without. They are all checked together at startup,
// so one run lists every missing key instead of stopping at the first one.
@Validated
@ConfigurationProperties(prefix = "app")
public record AppProperties(
        @Valid @NotNull(message = "app.jwt settings are missing") Jwt jwt,
        @Valid @NotNull(message = "app.superadmin settings are missing") SuperAdmin superadmin) {

    public record Jwt(
            @NotBlank(message = "app.jwt.secret is required (set the environment variable JWT_SECRET)")
            @Size(min = 32, message = "app.jwt.secret must be at least 32 characters (256 bits) for HS256")
            String secret,

            @NotNull(message = "app.jwt.expiration-minutes is required (set JWT_EXPIRATION_MINUTES)")
            @Min(value = 1, message = "app.jwt.expiration-minutes must be at least 1")
            Long expirationMinutes) {
    }

    public record SuperAdmin(
            @NotBlank(message = "app.superadmin.username is required (set SUPER_ADMIN_USERNAME)")
            String username,

            @NotBlank(message = "app.superadmin.password is required (set SUPER_ADMIN_PASSWORD)")
            @Size(min = 8, max = 72, message = "app.superadmin.password must be 8 to 72 characters")
            String password) {
    }
}
