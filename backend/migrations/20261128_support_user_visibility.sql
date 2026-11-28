-- Additive, idempotent migration. Back up the database before applying.
-- These markers only hide records in the owner's app; original records remain.
CREATE TABLE IF NOT EXISTS support_user_hidden_tickets (
 ticket_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
 CONSTRAINT fk_support_hidden_ticket FOREIGN KEY(ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS support_user_hidden_messages (
 message_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
 CONSTRAINT fk_support_hidden_message FOREIGN KEY(message_id) REFERENCES support_messages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
