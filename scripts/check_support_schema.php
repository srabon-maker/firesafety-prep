<?php
declare(strict_types=1);
// Run from the checkout, not from a public web directory. Never modifies data.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit(1); }
if ($argc !== 2 || !is_file($argv[1] . '/db.php')) {
    fwrite(STDERR, "Usage: php scripts/check_support_schema.php LIVE_ROOT\n");
    exit(1);
}
ob_start();
try {
    require $argv[1] . '/db.php';
    if (!isset($pdo) || !$pdo instanceof PDO) {
        throw new RuntimeException('Database unavailable');
    }
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    // LIMIT 0 verifies all columns without retrieving user data.
    $pdo->query('SELECT id,user_id,plan_code,subject,status,created_at,updated_at FROM support_tickets LIMIT 0');
    $pdo->query('SELECT id,ticket_id,sender,body,created_at FROM support_messages LIMIT 0');
    $pdo->query('SELECT id,is_registered,full_name FROM users LIMIT 0');
    $pdo->query('SELECT user_id,token_hash,expires_at FROM auth_sessions LIMIT 0');
    $q = $pdo->query("SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('support_tickets','support_messages')");
    $engines = $q->fetchAll(PDO::FETCH_KEY_PAIR);
    foreach (['support_tickets','support_messages'] as $table) {
        if (strcasecmp((string)($engines[$table] ?? ''), 'InnoDB') !== 0) {
            throw new RuntimeException('Support requires InnoDB');
        }
    }
    $q = $pdo->query("SELECT k.TABLE_NAME,k.COLUMN_NAME,k.REFERENCED_TABLE_NAME,
        k.REFERENCED_COLUMN_NAME,r.DELETE_RULE
        FROM information_schema.KEY_COLUMN_USAGE k
        JOIN information_schema.REFERENTIAL_CONSTRAINTS r
          ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME
          AND r.TABLE_NAME=k.TABLE_NAME
        WHERE k.TABLE_SCHEMA=DATABASE() AND k.REFERENCED_TABLE_SCHEMA=DATABASE()
          AND k.TABLE_NAME IN ('support_tickets','support_messages')");
    $found = [];
    foreach ($q->fetchAll(PDO::FETCH_NUM) as $row) {
        $found[] = implode(':', $row);
    }
    foreach (['support_tickets:user_id:users:id:CASCADE',
              'support_messages:ticket_id:support_tickets:id:CASCADE'] as $required) {
        if (!in_array($required, $found, true)) {
            throw new RuntimeException('Required foreign key is missing');
        }
    }
    ob_end_clean();
    echo "SUPPORT_SCHEMA_OK\n";
} catch (Throwable $e) {
    ob_end_clean();
    // Never print database credentials, raw SQL errors or user data.
    fwrite(STDERR, "Support schema preflight failed; verify connection, schema and migration.\n");
    exit(1);
}
