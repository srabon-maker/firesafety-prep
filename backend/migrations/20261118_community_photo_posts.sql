-- Fire Safety BD community photo posting.
-- Existing community_posts and community_comments tables are retained.
-- Back up the live database before importing this migration.
ALTER TABLE community_posts
  ADD COLUMN image_path VARCHAR(255) DEFAULT NULL AFTER body;

CREATE TABLE IF NOT EXISTS community_post_likes (
  post_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id),
  KEY idx_community_likes_user (user_id),
  CONSTRAINT fk_community_like_post FOREIGN KEY (post_id)
    REFERENCES community_posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_community_like_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
