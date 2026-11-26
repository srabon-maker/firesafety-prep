-- Additive migration; back up first.
CREATE TABLE IF NOT EXISTS career_job_preferences (
 user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
 enabled TINYINT(1) NOT NULL DEFAULT 0,
 keyword VARCHAR(120) NOT NULL DEFAULT '',
 location VARCHAR(120) NOT NULL DEFAULT '',
 updated_at DATETIME NOT NULL,
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS career_job_deliveries (
 user_id BIGINT UNSIGNED NOT NULL,
 job_id BIGINT UNSIGNED NOT NULL,
 created_at DATETIME NOT NULL,
 PRIMARY KEY(user_id,job_id),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS career_courses (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 title VARCHAR(180) NOT NULL,
 provider VARCHAR(180) NOT NULL,
 description TEXT NOT NULL,
 location VARCHAR(120) NOT NULL DEFAULT '',
 course_url VARCHAR(500) NOT NULL DEFAULT '',
 start_date DATE DEFAULT NULL,
 published TINYINT(1) NOT NULL DEFAULT 0,
 updated_at DATETIME NOT NULL,
 KEY idx_career_courses(published,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS career_profiles (
 user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
 display_name VARCHAR(100) NOT NULL,
 role_name VARCHAR(120) NOT NULL,
 organization VARCHAR(120) NOT NULL DEFAULT '',
 city VARCHAR(100) NOT NULL DEFAULT '',
 bio TEXT NULL,
 status ENUM('pending','approved','hidden') NOT NULL DEFAULT 'pending',
 revision INT UNSIGNED NOT NULL DEFAULT 1,
 updated_at DATETIME NOT NULL,
 KEY idx_career_directory(status,user_id),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
