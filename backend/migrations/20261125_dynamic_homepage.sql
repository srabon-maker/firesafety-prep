CREATE TABLE IF NOT EXISTS homepage_settings (
 id TINYINT UNSIGNED PRIMARY KEY,
 section_order VARCHAR(180) NOT NULL DEFAULT 'banners,progress,jobs,topics,notes,marketplace,community,tips'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO homepage_settings (id) VALUES (1);
CREATE TABLE IF NOT EXISTS homepage_content (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 kind ENUM('banner','tip','interview') NOT NULL,
 title VARCHAR(240) NOT NULL,
 body TEXT NOT NULL,
 title_en VARCHAR(240) NOT NULL DEFAULT '',
 body_en TEXT NOT NULL,
 role_name VARCHAR(100) NOT NULL DEFAULT '',
 industry VARCHAR(100) NOT NULL DEFAULT '',
 difficulty ENUM('basic','intermediate','advanced') NOT NULL DEFAULT 'basic',
 target ENUM('none','jobs','notes','questions','tests','interview','progress','shop','community') NOT NULL DEFAULT 'none',
 image_url VARCHAR(500) NOT NULL DEFAULT '',
 sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 100,
 is_published TINYINT(1) NOT NULL DEFAULT 0,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 INDEX homepage_public (kind,is_published,sort_order,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
