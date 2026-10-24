-- V1: baseline of the medcore_hms schema as it was on 2026-10-20.
-- It was written from a structure-only dump of the live database.
-- On the existing database, Flyway only records this version and does NOT run this file.
-- On a new, empty database (a new server), this file creates every table.

CREATE TABLE `audit_log` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `action` varchar(20) NOT NULL,
  `entity_id` bigint NOT NULL,
  `entity_type` varchar(40) NOT NULL,
  `hospital_id` bigint NOT NULL,
  `occurred_at` datetime(6) NOT NULL,
  `username` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_audit_hospital_entity` (`hospital_id`,`entity_type`,`entity_id`),
  CONSTRAINT `audit_log_chk_1` CHECK ((`action` in (_utf8mb4'CREATE',_utf8mb4'UPDATE',_utf8mb4'STATUS_CHANGE',_utf8mb4'DELETE')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `hospital` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `city` varchar(100) NOT NULL,
  `contact_email` varchar(150) NOT NULL,
  `verified` bit(1) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_hospital_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `login_attempt` (
  `attempt_key` varchar(64) NOT NULL,
  `failures` int NOT NULL,
  `last_failure` datetime(6) NOT NULL,
  `locked_until` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`attempt_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `doctor` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `phone` varchar(255) NOT NULL,
  `specialization` varchar(255) NOT NULL,
  `hospital_id` bigint NOT NULL,
  `deleted` bit(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKds7ws3yyj4c5wj35fpefpeny0` (`hospital_id`),
  CONSTRAINT `FKds7ws3yyj4c5wj35fpefpeny0` FOREIGN KEY (`hospital_id`) REFERENCES `hospital` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `patient` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `age` int NOT NULL,
  `full_name` varchar(255) DEFAULT NULL,
  `gender` varchar(255) DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  `hospital_id` bigint NOT NULL,
  `deleted` bit(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKfrtkp1fawf55kilsxb1uxpio0` (`hospital_id`),
  CONSTRAINT `FKfrtkp1fawf55kilsxb1uxpio0` FOREIGN KEY (`hospital_id`) REFERENCES `hospital` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `app_user` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `password` varchar(255) NOT NULL,
  `role` varchar(255) NOT NULL,
  `username` varchar(255) NOT NULL,
  `doctor_id` bigint DEFAULT NULL,
  `patient_id` bigint DEFAULT NULL,
  `hospital_id` bigint DEFAULT NULL,
  `email` varchar(160) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK3k4cplvh82srueuttfkwnylq0` (`username`),
  KEY `fk_app_user_doctor` (`doctor_id`),
  KEY `fk_app_user_patient` (`patient_id`),
  KEY `fk_app_user_hospital` (`hospital_id`),
  CONSTRAINT `fk_app_user_doctor` FOREIGN KEY (`doctor_id`) REFERENCES `doctor` (`id`),
  CONSTRAINT `fk_app_user_hospital` FOREIGN KEY (`hospital_id`) REFERENCES `hospital` (`id`),
  CONSTRAINT `fk_app_user_patient` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `appointment` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appointment_date` date NOT NULL,
  `appointment_time` time NOT NULL,
  `doctor_id` bigint NOT NULL,
  `patient_id` bigint NOT NULL,
  `reason` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL,
  `hospital_id` bigint NOT NULL,
  `priority` varchar(255) NOT NULL,
  `deleted` bit(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_appointment_doctor` (`doctor_id`),
  KEY `fk_appointment_patient` (`patient_id`),
  KEY `idx_appointment_doctor_slot` (`hospital_id`,`doctor_id`,`appointment_date`,`appointment_time`),
  KEY `idx_appointment_patient_slot` (`hospital_id`,`patient_id`,`appointment_date`,`appointment_time`),
  CONSTRAINT `FK23s5j4xcvbphvjxu702ij1thb` FOREIGN KEY (`hospital_id`) REFERENCES `hospital` (`id`),
  CONSTRAINT `fk_appointment_doctor` FOREIGN KEY (`doctor_id`) REFERENCES `doctor` (`id`),
  CONSTRAINT `fk_appointment_patient` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `bill` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appointment_id` bigint NOT NULL,
  `consultation_fee` decimal(10,2) NOT NULL,
  `medicine_fee` decimal(10,2) NOT NULL,
  `patient_id` bigint NOT NULL,
  `payment_date` date DEFAULT NULL,
  `payment_status` varchar(255) NOT NULL,
  `total_amount` decimal(10,2) DEFAULT NULL,
  `hospital_id` bigint NOT NULL,
  `deleted` bit(1) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_bill_appointment` (`appointment_id`),
  KEY `fk_bill_patient` (`patient_id`),
  KEY `FKehjsqedey5nqjsa7rh4rm376e` (`hospital_id`),
  CONSTRAINT `fk_bill_appointment` FOREIGN KEY (`appointment_id`) REFERENCES `appointment` (`id`),
  CONSTRAINT `fk_bill_patient` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`id`),
  CONSTRAINT `FKehjsqedey5nqjsa7rh4rm376e` FOREIGN KEY (`hospital_id`) REFERENCES `hospital` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `medical_record` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `hospital_id` bigint NOT NULL,
  `appointment_id` bigint NOT NULL,
  `blood_pressure` varchar(10) DEFAULT NULL,
  `clinical_notes` varchar(5000) DEFAULT NULL,
  `diagnosis` varchar(1000) DEFAULT NULL,
  `doctor_id` bigint NOT NULL,
  `patient_id` bigint NOT NULL,
  `pulse_bpm` int DEFAULT NULL,
  `temperaturec` decimal(4,1) DEFAULT NULL,
  `weight_kg` decimal(5,1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKfgwuht5sue0osb12hy00g8fv` (`appointment_id`),
  KEY `FK1dwbc0qn49qgbejvc1663kk8h` (`hospital_id`),
  CONSTRAINT `FK1dwbc0qn49qgbejvc1663kk8h` FOREIGN KEY (`hospital_id`) REFERENCES `hospital` (`id`),
  CONSTRAINT `fk_medical_record_appointment` FOREIGN KEY (`appointment_id`) REFERENCES `appointment` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `password_reset_code` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `attempts` int NOT NULL,
  `code_hash` varchar(100) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `code_used` bit(1) NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_password_reset_user` (`user_id`),
  CONSTRAINT `fk_password_reset_user` FOREIGN KEY (`user_id`) REFERENCES `app_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `prescription` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appointment_id` bigint NOT NULL,
  `doctor_id` bigint NOT NULL,
  `instructions` varchar(255) NOT NULL,
  `patient_id` bigint NOT NULL,
  `status` varchar(255) DEFAULT NULL,
  `hospital_id` bigint NOT NULL,
  `deleted` bit(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_prescription_appointment` (`appointment_id`),
  KEY `fk_prescription_doctor` (`doctor_id`),
  KEY `fk_prescription_patient` (`patient_id`),
  KEY `FKqmoh3ato0o0ak36bv7wkftrfn` (`hospital_id`),
  CONSTRAINT `fk_prescription_appointment` FOREIGN KEY (`appointment_id`) REFERENCES `appointment` (`id`),
  CONSTRAINT `fk_prescription_doctor` FOREIGN KEY (`doctor_id`) REFERENCES `doctor` (`id`),
  CONSTRAINT `fk_prescription_patient` FOREIGN KEY (`patient_id`) REFERENCES `patient` (`id`),
  CONSTRAINT `FKqmoh3ato0o0ak36bv7wkftrfn` FOREIGN KEY (`hospital_id`) REFERENCES `hospital` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `refresh_token` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `revoked` bit(1) NOT NULL,
  `token_hash` varchar(64) NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKkdj16cltjxdksuyiosdhliveg` (`token_hash`),
  KEY `fk_refresh_token_user` (`user_id`),
  CONSTRAINT `fk_refresh_token_user` FOREIGN KEY (`user_id`) REFERENCES `app_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `prescription_item` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `prescription_id` bigint NOT NULL,
  `medicine_name` varchar(255) NOT NULL,
  `dosage` varchar(255) NOT NULL,
  `frequency` varchar(255) NOT NULL,
  `duration` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKeykn9e2g6nbmvwhqbrdm3jb2p` (`prescription_id`),
  CONSTRAINT `FKeykn9e2g6nbmvwhqbrdm3jb2p` FOREIGN KEY (`prescription_id`) REFERENCES `prescription` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
