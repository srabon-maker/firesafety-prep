-- Fire Safety BD job circulars (MySQL 8 / MariaDB).
-- Apply once in the same database used by /db.php. No sample/fake jobs.
CREATE TABLE IF NOT EXISTS job_circulars (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization VARCHAR(200) NOT NULL,
  title VARCHAR(250) NOT NULL,
  job_type ENUM('government', 'private') NOT NULL DEFAULT 'private',
  employment_type VARCHAR(100) NOT NULL DEFAULT '',
  location VARCHAR(200) NOT NULL DEFAULT '',
  salary VARCHAR(150) NOT NULL DEFAULT '',
  description TEXT NULL,
  requirements TEXT NULL,
  application_deadline DATE NULL,
  published_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  apply_url VARCHAR(2048) NULL,
  circular_url VARCHAR(2048) NULL,
  status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'draft',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_job_status_published (status, published_at),
  INDEX idx_job_deadline (application_deadline)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
