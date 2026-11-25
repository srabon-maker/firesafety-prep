-- Check the live market_orders.id type and match the FK before applying.
-- Back up and test on staging first.
CREATE TABLE IF NOT EXISTS market_delivery_settings (
  id TINYINT UNSIGNED PRIMARY KEY,
  flat_fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO market_delivery_settings (id,flat_fee) VALUES (1,0.00)
ON DUPLICATE KEY UPDATE id=id;
CREATE TABLE IF NOT EXISTS market_order_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  order_status ENUM('pending','confirmed','processing','shipped','delivered','cancelled') NOT NULL,
  source ENUM('checkout','customer','admin') NOT NULL,
  courier_name VARCHAR(100) DEFAULT NULL,
  tracking_number VARCHAR(150) DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_market_order_events_order (order_id,id),
  CONSTRAINT fk_market_order_events_order FOREIGN KEY (order_id)
    REFERENCES market_orders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
