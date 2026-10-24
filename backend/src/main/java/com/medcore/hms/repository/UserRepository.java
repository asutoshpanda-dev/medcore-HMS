package com.medcore.hms.repository;

import com.medcore.hms.entity.AppUser;
import com.medcore.hms.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<AppUser, Long> {

    Optional<AppUser> findByUsername(String username);

    boolean existsByUsername(String username);

    boolean existsByPatientId(Long patientId);

    boolean existsByDoctorId(Long doctorId);

    boolean existsByRole(Role role);
}
