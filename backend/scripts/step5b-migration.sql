-- Step 5b: hospital isolation (multi-tenancy)
-- Run ONCE on medcore_hms, as a whole script (Workbench: Execute all, Ctrl+Shift+Enter).
-- Back up the database first (Workbench: Server > Data Export).
-- Stop the Spring Boot app before running this.

USE medcore_hms;

-- 1. Hospital table (the app would create it too, but the backfill below needs it now)
CREATE TABLE IF NOT EXISTS hospital (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100) NOT NULL,
    contact_email VARCHAR(150) NOT NULL,
    verified BIT(1) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_hospital_name (name)
);

-- 2. All existing data goes into one default hospital.
--    It is verified, so your current accounts can keep logging in.
INSERT INTO hospital (name, city, contact_email, verified)
SELECT 'Default Hospital', 'Unknown', 'hospital@example.com', b'1'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM hospital WHERE name = 'Default Hospital');

SET @default_hospital = (SELECT id FROM hospital WHERE name = 'Default Hospital');

-- 3. hospital_id on every tenant table: add, fill with the default hospital, then NOT NULL
ALTER TABLE patient ADD COLUMN hospital_id BIGINT NULL;
UPDATE patient SET hospital_id = @default_hospital WHERE id > 0;
ALTER TABLE patient MODIFY hospital_id BIGINT NOT NULL;

ALTER TABLE doctor ADD COLUMN hospital_id BIGINT NULL;
UPDATE doctor SET hospital_id = @default_hospital WHERE id > 0;
ALTER TABLE doctor MODIFY hospital_id BIGINT NOT NULL;

ALTER TABLE appointment ADD COLUMN hospital_id BIGINT NULL;
UPDATE appointment SET hospital_id = @default_hospital WHERE id > 0;
ALTER TABLE appointment MODIFY hospital_id BIGINT NOT NULL;

ALTER TABLE prescription ADD COLUMN hospital_id BIGINT NULL;
UPDATE prescription SET hospital_id = @default_hospital WHERE id > 0;
ALTER TABLE prescription MODIFY hospital_id BIGINT NOT NULL;

ALTER TABLE bill ADD COLUMN hospital_id BIGINT NULL;
UPDATE bill SET hospital_id = @default_hospital WHERE id > 0;
ALTER TABLE bill MODIFY hospital_id BIGINT NOT NULL;

-- 4. Accounts: hospital_id stays NULL for SUPER_ADMIN (added later by the app, no hospital)
ALTER TABLE app_user ADD COLUMN hospital_id BIGINT NULL;
UPDATE app_user SET hospital_id = @default_hospital WHERE id > 0;

-- 5. Roles: the old ADMIN becomes HOSPITAL_ADMIN; the role column must hold the new names
ALTER TABLE app_user MODIFY role VARCHAR(30) NOT NULL;
UPDATE app_user SET role = 'HOSPITAL_ADMIN' WHERE id > 0 AND role = 'ADMIN';

-- 6. Foreign keys for hospital_id are created by Hibernate when the app starts (ddl-auto=update).

-- ---------------------------------------------------------------
-- VERIFY (run after the app has started once)
-- ---------------------------------------------------------------
SELECT * FROM hospital;
SELECT username, role, hospital_id FROM app_user;

-- Expect 15 (9 before Step 5b + 6 new hospital links)
SELECT COUNT(*) AS foreign_keys
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'medcore_hms' AND REFERENCED_TABLE_NAME IS NOT NULL;
