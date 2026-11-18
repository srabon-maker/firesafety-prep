-- Run once in phpMyAdmin after backing up the database.
-- A user submission is NEVER public until an admin approves it.
CREATE TABLE IF NOT EXISTS job_submissions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  published_job_id BIGINT UNSIGNED DEFAULT NULL,
  title VARCHAR(255) NOT NULL,
  organization VARCHAR(200) NOT NULL,
  location VARCHAR(200) DEFAULT NULL,
  employment_type VARCHAR(100) DEFAULT NULL,
  salary VARCHAR(120) DEFAULT NULL,
  vacancies VARCHAR(80) DEFAULT NULL,
  description LONGTEXT NOT NULL,
  requirements LONGTEXT DEFAULT NULL,
  application_url TEXT DEFAULT NULL,
  application_deadline DATE DEFAULT NULL,
  mobile_number VARCHAR(20) NOT NULL,
  whatsapp_number VARCHAR(20) NOT NULL,
  public_contact TINYINT(1) NOT NULL DEFAULT 0,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  admin_note VARCHAR(1000) DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_submission_published_job (published_job_id),
  KEY idx_submission_user_created (user_id, created_at),
  KEY idx_submission_status_created (status, created_at),
  CONSTRAINT fk_job_submission_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_job_submission_published FOREIGN KEY (published_job_id)
    REFERENCES job_circulars(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
