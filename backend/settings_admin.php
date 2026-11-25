<?php
declare(strict_types=1);
// Fixed module entry point; shared controller enforces admin login and CSRF.
define('FSBD_OPS_TAB','settings');
require __DIR__.'/admin_operations.php';
