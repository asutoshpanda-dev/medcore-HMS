package com.medcore.hms.repository;

import com.medcore.hms.entity.PasswordResetCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PasswordResetCodeRepository extends JpaRepository<PasswordResetCode, Long> {

    Optional<PasswordResetCode> findFirstByUserIdAndUsedFalseOrderByCreatedAtDesc(Long userId);

    @Modifying
    @Query("update PasswordResetCode c set c.used = true where c.userId = :userId and c.used = false")
    int invalidateAllForUser(@Param("userId") Long userId);
}
