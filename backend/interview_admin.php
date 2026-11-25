<?php
declare(strict_types=1);
// Fixed, server-side mode. Shared controller applies admin authentication,
// CSRF protection, and interview-only read/write predicates.
define('FSBD_INTERVIEW_ADMIN',true);
require __DIR__.'/homepage_admin.php';
