<?php
declare(strict_types=1);

require_once __DIR__ . '/profile_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    profileRespond(405, ['success' => false, 'message' => 'POST required.']);
}

$data = profileInput();
if (($data['confirmation'] ?? null) !== 'DELETE_MY_ACCOUNT') {
    profileRespond(422, ['success' => false, 'message' => 'Explicit deletion confirmation required.']);
}

try {
    $userId = authenticatedProfileUserId($pdo);
    $pdo->beginTransaction();

    // Lock the account while its dependent records are removed.
    $lock = $pdo->prepare('SELECT id FROM users WHERE id = ? FOR UPDATE');
    $lock->execute([$userId]);
    if (!$lock->fetchColumn()) {
        $pdo->rollBack();
        profileRespond(404, ['success' => false, 'message' => 'Account not found.']);
    }

    // Do not erase transactions that staff may still be fulfilling.
    $activeOrders = $pdo->prepare(
        "SELECT COUNT(*) FROM market_orders WHERE user_id = ?
         AND order_status IN ('pending', 'confirmed', 'processing', 'shipped')"
    );
    $activeOrders->execute([$userId]);
    $activeRequests = $pdo->prepare(
        "SELECT COUNT(*) FROM market_service_requests WHERE user_id = ?
         AND status IN ('pending', 'reviewing', 'approved')"
    );
    $activeRequests->execute([$userId]);
    if ((int) $activeOrders->fetchColumn() > 0 ||
        (int) $activeRequests->fetchColumn() > 0) {
        $pdo->rollBack();
        profileRespond(409, [
            'success' => false,
            'message' => 'Complete or cancel active orders and service requests before deleting your account.'
        ]);
    }

    // The existing database schema restricts deletion while orders and
    // service requests reference the user. Remove these explicitly.
    // Order items cascade from market_orders. Other user-owned records
    // (sessions, cart, posts/comments, test attempts, notifications) cascade
    // through the existing foreign keys.
    foreach (['market_orders', 'market_service_requests'] as $table) {
        $stmt = $pdo->prepare('DELETE FROM ' . $table . ' WHERE user_id = ?');
        $stmt->execute([$userId]);
    }

    $stmt = $pdo->prepare('DELETE FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    if ($stmt->rowCount() !== 1) {
        throw new RuntimeException('Account deletion did not affect exactly one user.');
    }

    $pdo->commit();
    profileRespond(200, [
        'success' => true,
        'deleted' => true,
        'message' => 'Account permanently deleted.'
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Account deletion error: ' . $e->getMessage());
    profileRespond(500, [
        'success' => false,
        'message' => 'Account deletion failed. No changes were committed.'
    ]);
}
