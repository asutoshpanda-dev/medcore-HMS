package com.medcore.hms.config;

import com.medcore.hms.entity.AppUser;
import com.medcore.hms.entity.Role;
import com.medcore.hms.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

// Creates the platform super admin on first start (if none exists yet)
@Component
public class AdminSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminSeeder.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final String superAdminUsername;
    private final String superAdminPassword;

    public AdminSeeder(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       @Value("${app.superadmin.username}") String superAdminUsername,
                       @Value("${app.superadmin.password}") String superAdminPassword) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.superAdminUsername = superAdminUsername;
        this.superAdminPassword = superAdminPassword;
    }

    @Override
    public void run(String... args) {
        if (userRepository.existsByRole(Role.SUPER_ADMIN)) {
            return;
        }
        if (superAdminPassword == null || superAdminPassword.length() < 8) {
            throw new IllegalStateException(
                    "SUPER_ADMIN_PASSWORD must be set and at least 8 characters long");
        }
        userRepository.save(new AppUser(
                superAdminUsername, passwordEncoder.encode(superAdminPassword), Role.SUPER_ADMIN));
        log.info("Created super admin user: {}", superAdminUsername);
    }
}
