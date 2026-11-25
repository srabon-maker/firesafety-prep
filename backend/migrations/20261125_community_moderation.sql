-- Run after the community photo migration; back up the DB first.
-- Verify community_posts.status accepts hidden and community_comments.status accepts hidden.
-- No changes to existing post/comment records.
CREATE TABLE IF NOT EXISTS community_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  reporter_id BIGINT UNSIGNED NOT NULL,
  post_id BIGINT UNSIGNED NOT NULL,
  target_type ENUM('post','comment') NOT NULL,
  target_id BIGINT UNSIGNED NOT NULL,
  reason ENUM('spam','harassment','misinformation','inappropriate','other') NOT NULL,
  details VARCHAR(500) NOT NULL DEFAULT '',
  status ENUM('open','resolved','dismissed') NOT NULL DEFAULT 'open',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_reporter_target (reporter_id,target_type,target_id),
  KEY idx_report_queue (status,created_at),
  KEY idx_report_post (post_id),
  KEY idx_reporter_date (reporter_id,created_at),
  CONSTRAINT fk_community_report_user FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_community_report_post FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
