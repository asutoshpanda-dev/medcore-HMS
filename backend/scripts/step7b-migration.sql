-- Step 7b: one bill per appointment (database guard)
-- Run ONCE on medcore_hms, as a whole script. Stop the Spring Boot app first.
-- Back up the database first (Workbench: Server > Data Export).

USE medcore_hms;

-- 1. Check existing data first. BOTH queries must return NO rows.
--    If they return rows, fix those bills by hand (see the notes below) and run step 1 again.
SELECT appointment_id, COUNT(*) AS bills
FROM bill
GROUP BY appointment_id
HAVING COUNT(*) > 1;

SELECT b.id AS bill_id, b.patient_id AS bill_patient, a.patient_id AS appointment_patient
FROM bill b
JOIN appointment a ON a.id = b.appointment_id
WHERE b.patient_id <> a.patient_id;

-- 2. The guard: the database itself refuses a second bill for the same appointment.
--    If step 1 returned rows, MySQL refuses this line too, so nothing changes.
ALTER TABLE bill ADD CONSTRAINT uk_bill_appointment UNIQUE (appointment_id);

-- VERIFY: one row, with NON_UNIQUE = 0
SELECT INDEX_NAME, NON_UNIQUE
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'medcore_hms' AND TABLE_NAME = 'bill' AND INDEX_NAME = 'uk_bill_appointment';

-- NOTES FOR FIXING OLD DATA (only if step 1 returned rows)
--  - Mismatched patient: decide which patient is right, then
--      UPDATE bill SET patient_id = <correct patient id> WHERE id = <bill_id>;
--  - Duplicate bills: decide which bill to keep, check with the clinic before deleting
--    anything that is PAID, then
--      DELETE FROM bill WHERE id = <bill_id>;
