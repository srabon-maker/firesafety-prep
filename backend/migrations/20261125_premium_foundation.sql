-- Apply after backup and the dynamic homepage migration. Existing users/content remain free.
CREATE TABLE IF NOT EXISTS premium_memberships (
 user_id BIGINT UNSIGNED PRIMARY KEY,
 expires_at DATETIME NOT NULL COMMENT 'UTC',
 updated_at DATETIME NOT NULL,
 CONSTRAINT fk_pm_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS premium_membership_events (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 action ENUM('grant','revoke') NOT NULL,
 expires_at DATETIME NULL COMMENT 'UTC',
 reason VARCHAR(240) NOT NULL,
 created_at DATETIME NOT NULL,
 KEY idx_pme_user(user_id,id),
 CONSTRAINT fk_pme_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS premium_interview_items (
 content_id BIGINT UNSIGNED PRIMARY KEY,
 CONSTRAINT fk_pii_content FOREIGN KEY(content_id) REFERENCES homepage_content(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS premium_plans (
 code VARCHAR(24) PRIMARY KEY,
 months TINYINT UNSIGNED NOT NULL,
 proposed_price_bdt INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO premium_plans(code,months,proposed_price_bdt) VALUES ('monthly',1,99),('quarterly',3,249),('annual',12,799);
CREATE TABLE IF NOT EXISTS premium_ads_settings (
 id TINYINT UNSIGNED PRIMARY KEY,
 ads_requested TINYINT(1) NOT NULL DEFAULT 0,
 home_native TINYINT(1) NOT NULL DEFAULT 0,
 question_native TINYINT(1) NOT NULL DEFAULT 0,
 results_interstitial TINYINT(1) NOT NULL DEFAULT 0,
 rewarded TINYINT(1) NOT NULL DEFAULT 0,
 daily_fullscreen_limit TINYINT UNSIGNED NOT NULL DEFAULT 2
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO premium_ads_settings(id) VALUES (1);
