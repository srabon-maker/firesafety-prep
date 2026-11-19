-- Fire Safety BD: Student Model Test attempts and immutable question snapshots.
-- Back up the database before running. Run once in the application database.
-- No foreign keys are declared because the existing users/model_tests ID definitions
-- are managed by the production database and must not be guessed here.

CREATE TABLE IF NOT EXISTS model_test_attempts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  test_id INT NOT NULL,
  user_id INT NOT NULL,
  status ENUM('in_progress','submitted','expired') NOT NULL DEFAULT 'in_progress',
  started_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  submitted_at DATETIME NULL,
  question_count INT NOT NULL DEFAULT 0,
  total_marks DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  pass_marks DECIMAL(10,2) NULL,
  negative_marks_per_question DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  score DECIMAL(10,2) NULL,
  correct_count INT NOT NULL DEFAULT 0,
  incorrect_count INT NOT NULL DEFAULT 0,
  unanswered_count INT NOT NULL DEFAULT 0,
  passed TINYINT(1) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mta_user_created (user_id, created_at),
  KEY idx_mta_test_status (test_id, status),
  KEY idx_mta_expiry (status, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS model_test_attempt_questions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  attempt_id BIGINT UNSIGNED NOT NULL,
  question_id INT NOT NULL,
  question_order INT NOT NULL,
  question_text TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_answer CHAR(1) NOT NULL,
  explanation TEXT NULL,
  marks DECIMAL(10,2) NOT NULL DEFAULT 1.00,
  selected_answer CHAR(1) NULL,
  answered_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mtaq_attempt_order (attempt_id, question_order),
  UNIQUE KEY uq_mtaq_attempt_question (attempt_id, question_id),
  KEY idx_mtaq_attempt (attempt_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
