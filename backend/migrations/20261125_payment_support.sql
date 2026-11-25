-- Back up first. No payment or entitlement changes.
CREATE TABLE IF NOT EXISTS support_tickets (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 plan_code ENUM('none','monthly','quarterly','annual') NOT NULL DEFAULT 'none',
 subject VARCHAR(160) NOT NULL,
 status ENUM('open','answered','closed') NOT NULL DEFAULT 'open',
 created_at DATETIME NOT NULL,
 updated_at DATETIME NOT NULL,
 KEY idx_support_user(user_id,updated_at,id),
 KEY idx_support_queue(status,updated_at,id),
 CONSTRAINT fk_support_ticket_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS support_messages (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 ticket_id BIGINT UNSIGNED NOT NULL,
 sender ENUM('user','admin') NOT NULL,
 body TEXT NOT NULL,
 created_at DATETIME NOT NULL,
 KEY idx_support_thread(ticket_id,id),
 CONSTRAINT fk_support_message_ticket FOREIGN KEY(ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
