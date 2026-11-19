-- Fire Safety BD: additional exam policies.
-- Run after 20261119_student_model_test_attempts.sql.
-- Back up the database first.
ALTER TABLE model_tests
  ADD COLUMN max_attempts INT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN results_released TINYINT(1) NOT NULL DEFAULT 1;
