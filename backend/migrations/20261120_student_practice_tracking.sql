-- Fire Safety BD: persistent student practice targets and history.
-- Back up the database and run once in the same database used by backend/api/tests.php.

CREATE TABLE IF NOT EXISTS student_practice_settings (
  user_id INT NOT NULL,
  daily_target TINYINT UNSIGNED NOT NULL DEFAULT 10,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS student_practice_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  category VARCHAR(100) NOT NULL,
  difficulty ENUM('all','easy','medium','hard') NOT NULL DEFAULT 'all',
  total_questions TINYINT UNSIGNED NOT NULL,
  correct_count TINYINT UNSIGNED NOT NULL,
  completed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_practice_user_completed (user_id, completed_at),
  KEY idx_practice_user_category (user_id, category, completed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
