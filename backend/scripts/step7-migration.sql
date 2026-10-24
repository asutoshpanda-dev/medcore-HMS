-- Step 7: several medicines per prescription, and medical records
-- Run ONCE on medcore_hms, as a whole script. Stop the Spring Boot app first.
-- Back up the database first (Workbench: Server > Data Export).

USE medcore_hms;

-- 1. Items table. The copy below needs it now; Hibernate adds its foreign key on start.
CREATE TABLE IF NOT EXISTS prescription_item (
    id BIGINT NOT NULL AUTO_INCREMENT,
    prescription_id BIGINT NOT NULL,
    medicine_name VARCHAR(255) NOT NULL,
    dosage VARCHAR(255) NOT NULL,
    frequency VARCHAR(255) NOT NULL,
    duration VARCHAR(255) NOT NULL,
    PRIMARY KEY (id)
);

-- 2. Every existing prescription keeps its medicine as one item.
--    Frequency did not exist before, so old rows get "As directed".
INSERT INTO prescription_item (prescription_id, medicine_name, dosage, frequency, duration)
SELECT id,
       COALESCE(medicine_name, 'Unknown medicine'),
       COALESCE(dosage, 'As directed'),
       'As directed',
       COALESCE(duration, 'As directed')
FROM prescription
WHERE id > 0;

-- 3. The medicine columns leave the prescription table (their data is now in prescription_item)
ALTER TABLE prescription DROP COLUMN medicine_name;
ALTER TABLE prescription DROP COLUMN dosage;
ALTER TABLE prescription DROP COLUMN duration;

-- 4. medical_record is a new, empty table. Hibernate creates it when the app starts.

-- ---------------------------------------------------------------
-- VERIFY (run after the app has started once)
-- ---------------------------------------------------------------

-- Expect 18: the 15 from Step 5b, plus medical_record -> hospital and -> appointment,
-- plus prescription_item -> prescription
SELECT COUNT(*) AS foreign_keys
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'medcore_hms' AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Every prescription should show at least one medicine
SELECT p.id, COUNT(i.id) AS medicines
FROM prescription p
LEFT JOIN prescription_item i ON i.prescription_id = p.id
GROUP BY p.id;
