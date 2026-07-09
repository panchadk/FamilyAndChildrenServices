<?php
require_once __DIR__ . '/includes/auth.php';
$u = current_user();
if ($u) {
    log_activity((int)$u['id'], 'logout');
}
$_SESSION = [];
if (ini_get('session.use_cookies')) {
    $p = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
}
session_destroy();
header('Location: index.php');
exit;
