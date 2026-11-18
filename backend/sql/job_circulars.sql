-- IMPORTANT: NO MIGRATION REQUIRED.
-- The user-supplied database dump manobiki_firesafetyjobprep.sql already
-- contains job_circulars with a different, established schema.
-- Do NOT import the old CREATE TABLE script from PR #22: it is incompatible.
-- These statements are READ-ONLY checks for cPanel/phpMyAdmin.

SHOW COLUMNS FROM job_circulars;
SHOW INDEX FROM job_circulars;
SELECT COUNT(*) AS total_jobs FROM job_circulars;
SELECT COUNT(*) AS published_jobs FROM job_circulars WHERE status = 'published';
SELECT id, title, status, application_deadline, is_pinned
FROM job_circulars ORDER BY id DESC LIMIT 20;
