package com.medcore.hms.service;

import com.medcore.hms.dto.AuthDtos.*;
import com.medcore.hms.entity.AppUser;
import com.medcore.hms.entity.Hospital;
import com.medcore.hms.entity.Role;
import com.medcore.hms.repository.DoctorRepository;
import com.medcore.hms.repository.HospitalRepository;
import com.medcore.hms.repository.PatientRepository;
import com.medcore.hms.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.util.Locale;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PatientRepository patientRepository;
    private final DoctorRepository doctorRepository;
    private final HospitalRepository hospitalRepository;
    private final CurrentUserService currentUserService;
    private final PasswordEncoder passwordEncoder;
    private final JwtEncoder jwtEncoder;
    private final LoginAttemptService loginAttempts;
    private final RefreshTokenService refreshTokens;
    private final long expirationMinutes;

    public AuthService(UserRepository userRepository,
                       PatientRepository patientRepository,
                       DoctorRepository doctorRepository,
                       HospitalRepository hospitalRepository,
                       CurrentUserService currentUserService,
                       PasswordEncoder passwordEncoder,
                       JwtEncoder jwtEncoder,
                       LoginAttemptService loginAttempts,
                       RefreshTokenService refreshTokens,
                       @Value("${app.jwt.expiration-minutes}") long expirationMinutes) {
        this.userRepository = userRepository;
        this.patientRepository = patientRepository;
        this.doctorRepository = doctorRepository;
        this.hospitalRepository = hospitalRepository;
        this.currentUserService = currentUserService;
        this.passwordEncoder = passwordEncoder;
        this.jwtEncoder = jwtEncoder;
        this.loginAttempts = loginAttempts;
        this.refreshTokens = refreshTokens;
        this.expirationMinutes = expirationMinutes;
    }

    public TokenResponse login(LoginRequest request) {

        // Refused before the password is checked, so a locked username cannot be guessed further
        loginAttempts.assertNotLocked(request.username());

        AppUser user = userRepository.findByUsername(request.username())
                .filter(u -> passwordEncoder.matches(request.password(), u.getPassword()))
                .orElse(null);

        if (user == null) {
            loginAttempts.recordFailure(request.username());
            throw unauthorized("Invalid username or password");
        }
        loginAttempts.reset(request.username());

        assertHospitalVerified(user);
        return issueTokens(user);
    }

    // Trades a valid refresh token for a new access token and a new refresh token
    public TokenResponse refresh(RefreshRequest request) {
        Long userId = refreshTokens.rotate(request.refreshToken());

        AppUser user = userRepository.findById(userId)
                .orElseThrow(() -> unauthorized("This session no longer exists. Log in again."));
        assertHospitalVerified(user);
        return issueTokens(user);
    }

    // Ends one session. The access token it issued stays valid until it expires (see the notes).
    public void logout(RefreshRequest request) {
        refreshTokens.revoke(request.refreshToken());
    }

    // Ends every session of the logged-in user, on every device
    @Transactional
    public void logoutAll() {
        AppUser caller = currentUserService.get();
        refreshTokens.revokeAll(caller.getId());
    }

    // Needs the current password. Ends every other session of the account.
    @Transactional(noRollbackFor = ResponseStatusException.class)
    public void changePassword(ChangePasswordRequest request) {
        AppUser user = currentUserService.get();

        loginAttempts.assertNotLocked(user.getUsername());
        if (!passwordEncoder.matches(request.currentPassword(), user.getPassword())) {
            loginAttempts.recordFailure(user.getUsername());
            throw badRequest("The current password is wrong");
        }
        loginAttempts.reset(user.getUsername());

        user.setPassword(passwordEncoder.encode(request.newPassword()));
        refreshTokens.revokeAll(user.getId());
    }

    public UserResponse me() {
        return toResponse(currentUserService.get());
    }

    @Transactional
    public UserResponse register(RegisterRequest request) {

        AppUser caller = currentUserService.get();
        Long hospitalId = resolveHospitalId(caller, request);

        if (userRepository.existsByUsername(request.username())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Username already exists");
        }

        AppUser user = new AppUser(
                request.username(),
                passwordEncoder.encode(request.password()),
                request.role());

        user.setHospitalId(hospitalId);
        user.setEmail(normalizeEmail(request.email()));
        linkProfile(user, request, hospitalId);

        AppUser saved = userRepository.save(user);

        return toResponse(saved);
    }

    private TokenResponse issueTokens(AppUser user) {
        Instant now = Instant.now();
        Duration lifetime = Duration.ofMinutes(expirationMinutes);

        JwtClaimsSet.Builder claims = JwtClaimsSet.builder()
                .issuer("medcore-hms")
                .issuedAt(now)
                .expiresAt(now.plus(lifetime))
                .subject(user.getUsername())
                .claim("role", user.getRole().name());

        if (user.getHospitalId() != null) {
            claims.claim("hospitalId", user.getHospitalId());
        }

        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = jwtEncoder.encode(JwtEncoderParameters.from(header, claims.build()))
                .getTokenValue();

        String refreshToken = refreshTokens.issue(user.getId());

        return new TokenResponse(token, "Bearer", lifetime.toSeconds(),
                user.getRole().name(), user.getHospitalId(), refreshToken);
    }

    // Staff can log in only when their hospital has been verified by a super admin
    private void assertHospitalVerified(AppUser user) {
        if (user.getHospitalId() == null) {
            return;
        }
        boolean verified = hospitalRepository.findById(user.getHospitalId())
                .map(Hospital::isVerified)
                .orElse(false);
        if (!verified) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "This hospital is not verified yet");
        }
    }

    // Who may create which accounts, and in which hospital
    private Long resolveHospitalId(AppUser caller, RegisterRequest request) {

        if (caller.getRole() == Role.SUPER_ADMIN) {
            if (request.role() != Role.HOSPITAL_ADMIN) {
                throw forbidden("A super admin creates hospital admin accounts only");
            }
            if (request.hospitalId() == null || !hospitalRepository.existsById(request.hospitalId())) {
                throw badRequest("A HOSPITAL_ADMIN account needs the id of an existing hospital (hospitalId)");
            }
            return request.hospitalId();
        }

        if (caller.getRole() == Role.HOSPITAL_ADMIN) {
            if (caller.getHospitalId() == null) {
                throw forbidden("Your account is not linked to a hospital");
            }
            if (request.role() == Role.SUPER_ADMIN || request.role() == Role.HOSPITAL_ADMIN) {
                throw forbidden("A hospital admin can create staff and patient accounts only");
            }
            if (request.hospitalId() != null && !request.hospitalId().equals(caller.getHospitalId())) {
                throw forbidden("You can only create accounts for your own hospital");
            }
            return caller.getHospitalId();   // always the caller's hospital
        }

        throw forbidden("You are not allowed to create accounts");
    }

    // PATIENT accounts need a patient of the same hospital, DOCTOR accounts a doctor of that hospital
    private void linkProfile(AppUser user, RegisterRequest request, Long hospitalId) {

        switch (request.role()) {
            case PATIENT -> {
                if (request.doctorId() != null) {
                    throw badRequest("doctorId is only for DOCTOR accounts");
                }
                if (request.patientId() == null
                        || !patientRepository.existsByIdAndHospitalId(request.patientId(), hospitalId)) {
                    throw badRequest("A PATIENT account needs the id of an existing patient in this hospital (patientId)");
                }
                if (userRepository.existsByPatientId(request.patientId())) {
                    throw new ResponseStatusException(
                            HttpStatus.CONFLICT, "This patient already has an account");
                }
                user.setPatientId(request.patientId());
            }
            case DOCTOR -> {
                if (request.patientId() != null) {
                    throw badRequest("patientId is only for PATIENT accounts");
                }
                if (request.doctorId() == null
                        || !doctorRepository.existsByIdAndHospitalId(request.doctorId(), hospitalId)) {
                    throw badRequest("A DOCTOR account needs the id of an existing doctor in this hospital (doctorId)");
                }
                if (userRepository.existsByDoctorId(request.doctorId())) {
                    throw new ResponseStatusException(
                            HttpStatus.CONFLICT, "This doctor already has an account");
                }
                user.setDoctorId(request.doctorId());
            }
            default -> {
                if (request.patientId() != null || request.doctorId() != null) {
                    throw badRequest("patientId and doctorId are only for PATIENT and DOCTOR accounts");
                }
            }
        }
    }

    // Blank means "no email", so the field is stored as null
    private static String normalizeEmail(String email) {
        if (email == null || email.isBlank()) {
            return null;
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private UserResponse toResponse(AppUser user) {
        return new UserResponse(user.getId(), user.getUsername(), user.getRole(),
                user.getHospitalId(), user.getPatientId(), user.getDoctorId());
    }

    private ResponseStatusException unauthorized(String message) {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED, message);
    }

    private ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }

    private ResponseStatusException forbidden(String message) {
        return new ResponseStatusException(HttpStatus.FORBIDDEN, message);
    }
}
