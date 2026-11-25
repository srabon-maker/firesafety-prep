-- Additive only. Confirm existing notifications/users schema and back up first.
CREATE TABLE IF NOT EXISTS admin_operation_settings (
 id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
 broadcast_enabled TINYINT(1) NOT NULL DEFAULT 0,
 broadcast_limit INT UNSIGNED NOT NULL DEFAULT 500,
 analytics_days SMALLINT UNSIGNED NOT NULL DEFAULT 30,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO admin_operation_settings (id) VALUES (1) ON DUPLICATE KEY UPDATE id=id;
CREATE TABLE IF NOT EXISTS admin_notification_campaigns (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 request_key CHAR(64) NOT NULL,
 title VARCHAR(200) NOT NULL,
 message TEXT NOT NULL,
 notification_type VARCHAR(60) NOT NULL,
 audience VARCHAR(40) NOT NULL,
 target_user_id BIGINT UNSIGNED DEFAULT NULL,
 recipient_count INT UNSIGNED NOT NULL DEFAULT 0,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_admin_campaign_request (request_key),
 KEY idx_admin_campaign_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
