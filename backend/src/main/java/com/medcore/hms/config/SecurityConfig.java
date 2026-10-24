package com.medcore.hms.config;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    private final SecretKey secretKey;

    public SecurityConfig(@Value("${app.jwt.secret}") String secret) {
        if (secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException(
                    "JWT_SECRET must be at least 32 characters long");
        }
        this.secretKey = new SecretKeySpec(
                secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {

        http
                .csrf(csrf -> csrf.disable()) // safe: stateless API, no cookies/sessions
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/api/auth/login", "/api/auth/refresh", "/api/auth/logout",
                                "/api/auth/password-reset/request", "/api/auth/password-reset/confirm").permitAll()
                        .requestMatchers("/api/auth/me", "/api/auth/logout-all", "/api/auth/change-password")
                                .authenticated()
                        .requestMatchers("/error").permitAll()

                        // API documentation: Swagger UI and the OpenAPI document
                        .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()

                        // Platform level: only the super admin creates and verifies hospitals
                        .requestMatchers("/api/hospitals/**").hasRole("SUPER_ADMIN")

                        // Audit trail: hospital admin only
                        .requestMatchers(HttpMethod.GET, "/api/audit-logs/**").hasRole("HOSPITAL_ADMIN")

                        // Clinical notes: doctor and hospital admin. Patients read their own via /api/me.
                        .requestMatchers(HttpMethod.GET, "/api/medical-records/**")
                        .hasAnyRole("HOSPITAL_ADMIN", "DOCTOR")
                        .requestMatchers(HttpMethod.POST, "/api/medical-records")
                        .hasRole("DOCTOR")
                        .requestMatchers(HttpMethod.PUT, "/api/medical-records/**")
                        .hasAnyRole("HOSPITAL_ADMIN", "DOCTOR")

                        // Creating accounts: super admin creates hospital admins,
                        // hospital admins create staff and patients (rules in AuthService)
                        .requestMatchers(HttpMethod.POST, "/api/auth/register")
                        .hasAnyRole("SUPER_ADMIN", "HOSPITAL_ADMIN")

                        // Deleting anything inside a hospital: hospital admin only
                        .requestMatchers(HttpMethod.DELETE, "/api/**").hasRole("HOSPITAL_ADMIN")

                        // Status changes (must come before the general write rules)
                        .requestMatchers(HttpMethod.PATCH, "/api/appointments/*/status")
                        .hasAnyRole("HOSPITAL_ADMIN", "DOCTOR", "RECEPTIONIST")
                        .requestMatchers(HttpMethod.PATCH, "/api/prescriptions/*/status")
                        .hasRole("DOCTOR")

                        // Bills: hospital admin, receptionist, accountant
                        .requestMatchers("/api/bills/**")
                        .hasAnyRole("HOSPITAL_ADMIN", "RECEPTIONIST", "ACCOUNTANT")

                        // Prescriptions: hospital admin and doctors read, only doctors write
                        .requestMatchers(HttpMethod.GET, "/api/prescriptions/**")
                        .hasAnyRole("HOSPITAL_ADMIN", "DOCTOR")
                        .requestMatchers("/api/prescriptions/**").hasRole("DOCTOR")

                        // Doctors: staff read, only hospital admin writes
                        .requestMatchers(HttpMethod.GET, "/api/doctors/**")
                        .hasAnyRole("HOSPITAL_ADMIN", "DOCTOR", "RECEPTIONIST")
                        .requestMatchers("/api/doctors/**").hasRole("HOSPITAL_ADMIN")

                        // Patients and appointments: staff read, reception and hospital admin write
                        .requestMatchers(HttpMethod.GET, "/api/patients/**", "/api/appointments/**")
                        .hasAnyRole("HOSPITAL_ADMIN", "DOCTOR", "RECEPTIONIST")
                        .requestMatchers("/api/patients/**", "/api/appointments/**")
                        .hasAnyRole("HOSPITAL_ADMIN", "RECEPTIONIST")

                        // Patients see only their own data
                        .requestMatchers("/api/me/**").hasRole("PATIENT")

                        // Anything not listed is denied
                        .anyRequest().denyAll())
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter())));

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public JwtEncoder jwtEncoder() {
        return new NimbusJwtEncoder(new ImmutableSecret<>(secretKey));
    }

    @Bean
    public JwtDecoder jwtDecoder() {
        return NimbusJwtDecoder.withSecretKey(secretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
    }

    // Turns the "role" claim (e.g. HOSPITAL_ADMIN) into the authority ROLE_HOSPITAL_ADMIN
    private JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter authorities = new JwtGrantedAuthoritiesConverter();
        authorities.setAuthoritiesClaimName("role");
        authorities.setAuthorityPrefix("ROLE_");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authorities);
        return converter;
    }
}
