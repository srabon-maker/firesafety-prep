CREATE TABLE IF NOT EXISTS student_question_bookmarks (
 user_id BIGINT UNSIGNED NOT NULL,
 question_id INT UNSIGNED NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(user_id,question_id),
 KEY idx_bookmarks_question(question_id),
 CONSTRAINT fk_student_qb_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 CONSTRAINT fk_student_qb_question FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
