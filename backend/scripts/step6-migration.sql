-- Step 6: appointment priority (NORMAL / EMERGENCY) and faster slot lookups
-- Run ONCE on medcore_hms, as a whole script. Stop the Spring Boot app first.
-- Back up the database first (Workbench: Server > Data Export).

USE medcore_hms;

-- Existing appointments become NORMAL
ALTER TABLE appointment ADD COLUMN priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL';

-- Speeds up the doctor and patient conflict checks
CREATE INDEX idx_appointment_doctor_slot ON appointment (hospital_id, doctor_id, appointment_date, appointment_time);
CREATE INDEX idx_appointment_patient_slot ON appointment (hospital_id, patient_id, appointment_date, appointment_time);

-- ---------------------------------------------------------------
-- VERIFY (after the migration; the app can start afterwards)
-- ---------------------------------------------------------------
SELECT priority, COUNT(*) AS appointments FROM appointment GROUP BY priority;
