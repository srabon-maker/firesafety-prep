-- Back up DB; apply after marketplace/order migrations. users.id is BIGINT UNSIGNED
-- (verify against live SHOW CREATE TABLE users). No invented ratings or banners.
CREATE TABLE IF NOT EXISTS market_product_reviews (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  review_text VARCHAR(1000) NOT NULL DEFAULT '',
  status ENUM('pending','approved','hidden') NOT NULL DEFAULT 'pending',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_market_review (product_id,user_id),
  KEY idx_market_review_public (product_id,status,id),
  CONSTRAINT fk_market_review_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS market_product_banners (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(150) NOT NULL,
  subtitle VARCHAR(250) NOT NULL DEFAULT '',
  image_url VARCHAR(2048) DEFAULT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  KEY idx_market_banner_active (is_active,sort_order,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
