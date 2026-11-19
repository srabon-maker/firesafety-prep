-- Fire Safety BD Question Bank feature migration.
-- BACK UP the database before running this script.
-- Run ONCE in phpMyAdmin against the same database used by backend/questions.php.

ALTER TABLE questions
  ADD COLUMN image_path VARCHAR(500) NULL,
  ADD COLUMN is_archived TINYINT(1) NOT NULL DEFAULT 0,
  ADD KEY idx_questions_archived_status (is_archived, status);

CREATE TABLE IF NOT EXISTS question_revisions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  question_id BIGINT UNSIGNED NOT NULL,
  event_type VARCHAR(40) NOT NULL,
  before_data LONGTEXT NULL,
  after_data LONGTEXT NULL,
  changed_by VARCHAR(120) NOT NULL DEFAULT 'admin',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_question_revisions_question_created (question_id, created_at),
  KEY idx_question_revisions_event (event_type, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
