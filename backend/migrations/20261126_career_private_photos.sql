-- Apply after 20261126_career_profile_photo.sql. Back up first.
CREATE TABLE IF NOT EXISTS career_profile_photos (
 user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
 photo_key CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
 photo_data MEDIUMBLOB NOT NULL,
 FOREIGN KEY (user_id) REFERENCES career_profiles(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
