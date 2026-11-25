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
