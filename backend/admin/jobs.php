<?php
declare(strict_types=1);

// Legacy route retained for links created during the initial Jobs PR.
// Use the existing dashboard login instead of creating a second admin account.
require_once __DIR__ . '/../admin_helpers.php';
start_secure_session();
require_admin();
header('Cache-Control: no-store');
header('Location: ../job_circulars.php', true, 302);
exit;
