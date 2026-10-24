-- V2: make the temperature column name match the code and the rest of the schema (weight_kg, pulse_bpm).
-- The column is renamed, not recreated, so the stored values are kept.
-- Existing database: this runs once, on the first start after the baseline.
-- New, empty database: V1 creates temperaturec, then this renames it.
ALTER TABLE medical_record RENAME COLUMN temperaturec TO temperature_c;
