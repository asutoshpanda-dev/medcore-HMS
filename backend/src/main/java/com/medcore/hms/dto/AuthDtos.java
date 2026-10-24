package com.medcore.hms.dto;

import com.medcore.hms.entity.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class AuthDtos {

    private AuthDtos() {
    }

    public record LoginRequest(
            @NotBlank(message = "Username is required") String username,
            @NotBlank(message = "Password is required") String password) {
    }

    public record RegisterRequest(
            @NotBlank(message = "Username is required")
            @Size(min = 3, max = 50, message = "Username must be 3 to 50 characters")
            String username,

            @NotBlank(message = "Password is required")
            @Size(min = 8, max = 72, message = "Password must be 8 to 72 characters")
            String password,

            @NotNull(message = "Role is required") Role role,

            Long hospitalId,  // only a SUPER_ADMIN sends this (to create a HOSPITAL_ADMIN)
            Long patientId,   // required for PATIENT accounts
            Long doctorId,    // required for DOCTOR accounts

            @Email(message = "Please provide a valid email address")
            @Size(max = 160, message = "Email must be at most 160 characters")
            String email) {   // optional; needed for password reset by email code
    }

    // accessToken: short-lived, sent with every request. refreshToken: long-lived, used only at /refresh.
    public record TokenResponse(String token, String tokenType,
                                long expiresInSeconds, String role,
                                Long hospitalId, String refreshToken) {
    }

    public record RefreshRequest(
            @NotBlank(message = "Refresh token is required") String refreshToken) {
    }

    public record ChangePasswordRequest(
            @NotBlank(message = "Current password is required") String currentPassword,
            @NotBlank(message = "New password is required")
            @Size(min = 8, max = 72, message = "New password must be 8 to 72 characters")
            String newPassword) {
    }

    public record PasswordResetRequest(
            @NotBlank(message = "Username is required") String username) {
    }

    public record PasswordResetConfirm(
            @NotBlank(message = "Username is required") String username,

            @NotBlank(message = "Code is required")
            @Pattern(regexp = "[0-9]{6}", message = "Code must be 6 digits")
            String code,

            @NotBlank(message = "New password is required")
            @Size(min = 8, max = 72, message = "New password must be 8 to 72 characters")
            String newPassword) {
    }

    public record UserResponse(Long id, String username, Role role,
                               Long hospitalId, Long patientId, Long doctorId) {
    }
}
