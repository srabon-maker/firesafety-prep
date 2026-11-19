-- Fire Safety BD: Advanced Model Test Settings
-- Back up the database before running. Run once in the same database used by backend/model_tests.php.
ALTER TABLE model_tests
  ADD COLUMN negative_marks_per_question DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN exam_instructions TEXT NULL;
