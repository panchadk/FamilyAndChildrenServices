<?php
require_once __DIR__ . '/config.php';

/** Currently signed-in user (or null). */
function current_user(): ?array
{
    return $_SESSION['user'] ?? null;
}

/** Redirect to login if not signed in. */
function require_login(): array
{
    $u = current_user();
    if (!$u) {
        header('Location: index.php');
        exit;
    }
    return $u;
}

/** True when the user may upload / rename / delete. */
function can_edit(?array $u = null): bool
{
    $u = $u ?? current_user();
    return $u && in_array($u['role'], ['admin', 'editor'], true);
}

/** True for admins (user management). */
function is_admin(?array $u = null): bool
{
    $u = $u ?? current_user();
    return $u && $u['role'] === 'admin';
}

/** Abort with 403 unless the user is an admin. */
function require_admin(): array
{
    $u = require_login();
    if (!is_admin($u)) {
        http_response_code(403);
        exit('Forbidden: administrator access required.');
    }
    return $u;
}

/** Abort with 403 unless the user can edit. */
function require_editor(): array
{
    $u = require_login();
    if (!can_edit($u)) {
        http_response_code(403);
        exit('Forbidden: editor access required.');
    }
    return $u;
}

/** CSRF token for forms. */
function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

/** Validate CSRF on POST requests; abort on mismatch. */
function require_csrf(): void
{
    $sent = $_POST['csrf'] ?? '';
    if (empty($_SESSION['csrf']) || !hash_equals($_SESSION['csrf'], $sent)) {
        http_response_code(419);
        exit('Session expired — go back and try again.');
    }
}

/** Write to the audit trail (best effort). */
function log_activity(int $userId, string $action, string $detail = ''): void
{
    try {
        db()->prepare('INSERT INTO activity_log (user_id, action, detail) VALUES (?,?,?)')
            ->execute([$userId, $action, mb_substr($detail, 0, 255)]);
    } catch (Throwable $e) {
        // never let logging break the request
    }
}

/** HTML-escape helper. */
function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

/** Human-readable file size. */
function human_size(int $bytes): string
{
    if ($bytes >= 1048576) return round($bytes / 1048576, 1) . ' MB';
    if ($bytes >= 1024)    return round($bytes / 1024) . ' KB';
    return $bytes . ' B';
}

/** Icon class bucket for a file extension. */
function ext_bucket(string $ext): string
{
    $ext = strtolower($ext);
    if (in_array($ext, ['png','jpg','jpeg','gif','webp'])) return 'img';
    if (in_array($ext, ['xls','xlsx','csv']))              return 'xls';
    if (in_array($ext, ['doc','docx','txt']))              return 'doc';
    if (in_array($ext, ['ppt','pptx']))                    return 'ppt';
    return 'pdf';
}

/* ==================== per-folder permissions ==================== */

/** Folder row by id (cached per request). */
function folder_meta(int $folderId): ?array
{
    static $folders = null;
    if ($folders === null) {
        $folders = [];
        foreach (db()->query('SELECT * FROM folders') as $f) {
            $folders[(int)$f['id']] = $f;
        }
    }
    return $folders[$folderId] ?? null;
}

/**
 * What may this user do in this folder?
 * Returns ['view' => bool, 'edit' => bool].
 *
 * Rules:
 *  - Admins: everything, everywhere.
 *  - Unrestricted folder: everyone views; global editors/admins edit.
 *  - Restricted folder: only users with a folder_permissions row view;
 *    the row's can_edit flag grants edit (even to a global "viewer").
 */
function folder_access(int $folderId, ?array $u = null): array
{
    $u = $u ?? current_user();
    if (!$u) return ['view' => false, 'edit' => false];

    $f = folder_meta($folderId);
    if (!$f) return ['view' => false, 'edit' => false];

    if ($u['role'] === 'admin') return ['view' => true, 'edit' => true];

    if (!(int)$f['restricted']) {
        return ['view' => true, 'edit' => in_array($u['role'], ['admin','editor'], true)];
    }

    static $perm = [];
    $key = $folderId . '-' . $u['id'];
    if (!array_key_exists($key, $perm)) {
        $s = db()->prepare('SELECT can_edit FROM folder_permissions WHERE folder_id = ? AND user_id = ?');
        $s->execute([$folderId, $u['id']]);
        $perm[$key] = $s->fetch();
    }
    $row = $perm[$key];
    return ['view' => (bool)$row, 'edit' => $row ? (bool)$row['can_edit'] : false];
}

/** Folders (with doc counts) this user may view, in sidebar order. */
function accessible_folders(?array $u = null): array
{
    $u = $u ?? current_user();
    $rows = db()->query(
        'SELECT f.*, COUNT(d.id) AS doc_count
           FROM folders f
      LEFT JOIN documents d ON d.folder_id = f.id
       GROUP BY f.id
       ORDER BY f.sort_order, f.name'
    )->fetchAll();
    return array_values(array_filter(
        $rows,
        fn($f) => folder_access((int)$f['id'], $u)['view']
    ));
}

/* ==================== email notifications ==================== */

/**
 * Notify opted-in users that files landed in a folder.
 * Best effort — never breaks the upload if mail fails.
 */
function notify_upload(int $folderId, string $folderName, array $docNames, array $uploader): void
{
    if (!NOTIFY_ENABLED || !$docNames) return;
    try {
        $users = db()->query(
            "SELECT id, email, full_name, role FROM users
              WHERE is_active = 1 AND notify_uploads = 1"
        )->fetchAll();

        $recipients = [];
        foreach ($users as $u) {
            if ((int)$u['id'] === (int)$uploader['id']) continue;
            if (folder_access($folderId, $u)['view']) {
                $recipients[] = $u['email'];
            }
        }
        if (!$recipients) return;

        $count   = count($docNames);
        $subject = '[DocHub] ' . $count . ($count === 1 ? ' new document' : ' new documents')
                 . ' in ' . $folderName;
        $list    = implode("\n", array_map(fn($n) => '  • ' . $n, array_slice($docNames, 0, 10)));
        if ($count > 10) $list .= "\n  … and " . ($count - 10) . ' more';

        $body = $uploader['name'] . " uploaded to \"$folderName\":\n\n$list\n\n"
              . "View: " . APP_URL . "/dashboard.php?folder=$folderId\n\n"
              . "—\nYou receive these because upload notifications are turned on "
              . "under My account in FCS DocHub.";

        $headers = 'From: FCS DocHub <' . NOTIFY_FROM . ">\r\n"
                 . 'Bcc: ' . implode(', ', $recipients) . "\r\n"
                 . "Content-Type: text/plain; charset=UTF-8\r\n";

        // Send one message BCC'd to everyone
        @mail(NOTIFY_FROM, $subject, $body, $headers);
    } catch (Throwable $e) {
        // notifications must never break uploads
    }
}
