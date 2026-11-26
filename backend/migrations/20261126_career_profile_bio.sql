-- Additive migration for optional professional profile details.
-- Take a database backup before running this file in phpMyAdmin.
-- Safe to run more than once: it adds the column only when it is missing.

SET @career_bio_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'career_profiles'
    AND column_name = 'bio'
);

SET @career_bio_sql := IF(
  @career_bio_exists = 0,
  'ALTER TABLE career_profiles ADD COLUMN bio TEXT NULL AFTER city',
  'SELECT ''career_profiles.bio already exists'' AS migration_status'
);

PREPARE career_bio_stmt FROM @career_bio_sql;
EXECUTE career_bio_stmt;
DEALLOCATE PREPARE career_bio_stmt;
