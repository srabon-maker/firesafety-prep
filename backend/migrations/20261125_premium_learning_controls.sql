-- Run after the premium foundation migration. All existing content remains free.
CREATE TABLE IF NOT EXISTS premium_question_items (
 question_id INT UNSIGNED PRIMARY KEY,
 CONSTRAINT fk_pqi_question FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS premium_note_items (
 note_id BIGINT UNSIGNED PRIMARY KEY,
 CONSTRAINT fk_pni_note FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS premium_test_items (
 test_id BIGINT UNSIGNED PRIMARY KEY,
 CONSTRAINT fk_pti_test FOREIGN KEY(test_id) REFERENCES model_tests(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS premium_integration_config (
 id TINYINT UNSIGNED PRIMARY KEY,
 admob_app_id VARCHAR(100) NOT NULL DEFAULT '',
 home_native_id VARCHAR(100) NOT NULL DEFAULT '',
 question_native_id VARCHAR(100) NOT NULL DEFAULT '',
 interstitial_id VARCHAR(100) NOT NULL DEFAULT '',
 rewarded_id VARCHAR(100) NOT NULL DEFAULT '',
 monthly_product_id VARCHAR(150) NOT NULL DEFAULT '',
 quarterly_product_id VARCHAR(150) NOT NULL DEFAULT '',
 annual_product_id VARCHAR(150) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO premium_integration_config(id) VALUES (1);

-- Private PDF metadata. File bytes are stored outside the web document root.
CREATE TABLE IF NOT EXISTS premium_note_pdfs (
 note_id BIGINT UNSIGNED PRIMARY KEY,
 storage_name CHAR(68) NOT NULL UNIQUE,
 size_bytes INT UNSIGNED NOT NULL,
 updated_at DATETIME NOT NULL,
 CONSTRAINT fk_pnp_note FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS premium_pdf_downloads (
 token_hash CHAR(64) PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 note_id BIGINT UNSIGNED NOT NULL,
 expires_at DATETIME NOT NULL,
 KEY idx_ppd_expiry(expires_at),
 KEY idx_ppd_user(user_id),
 CONSTRAINT fk_ppd_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 CONSTRAINT fk_ppd_note FOREIGN KEY(note_id) REFERENCES premium_note_pdfs(note_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Master policy. Existing item selections are retained while free mode is active.
CREATE TABLE IF NOT EXISTS premium_access_policy (
 id TINYINT UNSIGNED PRIMARY KEY,
 mode ENUM('free','selected','all') NOT NULL DEFAULT 'free',
 starts_at DATETIME NULL COMMENT 'UTC',
 updated_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO premium_access_policy(id,mode,starts_at,updated_at) VALUES (1,'free',NULL,UTC_TIMESTAMP());
