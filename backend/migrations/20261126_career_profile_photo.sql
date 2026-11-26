-- Additive migration for optional professional directory profile photos.
-- Back up the database before applying.
ALTER TABLE career_profiles
 ADD COLUMN photo_path VARCHAR(255) NOT NULL DEFAULT '' AFTER city;
