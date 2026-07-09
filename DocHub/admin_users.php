<?php
require_once __DIR__ . '/includes/auth.php';
$admin = require_admin();

$flash = $_SESSION['flash'] ?? '';
$error = '';
unset($_SESSION['flash']);

/** Count of active admins (guard: never lock out the last one). */
function active_admin_count(): int
{
    return (int)db()->query(
        "SELECT COUNT(*) FROM users WHERE role='admin' AND is_active=1"
    )->fetchColumn();
}

/** Generate a readable temporary password like Maple-4821-Trees */
function temp_password(): string
{
    $words = ['Maple','River','Cedar','Bright','Grand','Willow','Summer','Stone','Harbor','Meadow'];
    return $words[random_int(0, 9)] . '-' . random_int(1000, 9999) . '-' . $words[random_int(0, 9)];
}

// ============ handle actions ============
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf();
    $action = $_POST['action'] ?? '';

    // ---- add a new user ----
    if ($action === 'add') {
        $email = strtolower(trim($_POST['email'] ?? ''));
        $name  = trim($_POST['full_name'] ?? '');
        $role  = $_POST['role'] ?? 'viewer';
        $pass  = $_POST['password'] ?? '';

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $error = 'Enter a valid email address.';
        } elseif ($name === '') {
            $error = 'Enter the person\'s full name.';
        } elseif (!in_array($role, ['admin', 'editor', 'viewer'], true)) {
            $error = 'Choose a valid role.';
        } elseif (strlen($pass) < 10) {
            $error = 'Password must be at least 10 characters.';
        } else {
            $dupe = db()->prepare('SELECT id FROM users WHERE email = ?');
            $dupe->execute([$email]);
            if ($dupe->fetch()) {
                $error = 'An account with that email already exists.';
            } else {
                db()->prepare(
                    'INSERT INTO users (email, password_hash, full_name, role) VALUES (?,?,?,?)'
                )->execute([$email, password_hash($pass, PASSWORD_DEFAULT), $name, $role]);
                log_activity($admin['id'], 'user_add', "$email ($role)");
                $_SESSION['flash'] = "Account created for $name ($email) as $role.";
                header('Location: admin_users.php');
                exit;
            }
        }
    }

    // ---- actions on an existing user ----
    if (in_array($action, ['role', 'toggle', 'resetpw'], true)) {
        $id = (int)($_POST['id'] ?? 0);
        $stmt = db()->prepare('SELECT * FROM users WHERE id = ?');
        $stmt->execute([$id]);
        $target = $stmt->fetch();

        if (!$target) {
            $error = 'That account no longer exists.';
        } elseif ($action === 'role') {
            $newRole = $_POST['role'] ?? '';
            if (!in_array($newRole, ['admin', 'editor', 'viewer'], true)) {
                $error = 'Choose a valid role.';
            } elseif ($target['role'] === 'admin' && $newRole !== 'admin'
                      && $target['is_active'] && active_admin_count() <= 1) {
                $error = 'You can\'t demote the last active administrator.';
            } else {
                db()->prepare('UPDATE users SET role = ? WHERE id = ?')->execute([$newRole, $id]);
                log_activity($admin['id'], 'user_role', $target['email'] . ' → ' . $newRole);
                // If the admin changed their own role, update the session too
                if ($id === (int)$admin['id']) {
                    $_SESSION['user']['role'] = $newRole;
                }
                $_SESSION['flash'] = $target['full_name'] . ' is now a ' . $newRole . '.';
                header('Location: admin_users.php');
                exit;
            }
        } elseif ($action === 'toggle') {
            $newState = $target['is_active'] ? 0 : 1;
            if ($newState === 0 && $target['role'] === 'admin' && active_admin_count() <= 1) {
                $error = 'You can\'t deactivate the last active administrator.';
            } elseif ($newState === 0 && $id === (int)$admin['id']) {
                $error = 'You can\'t deactivate your own account while signed in.';
            } else {
                db()->prepare('UPDATE users SET is_active = ? WHERE id = ?')->execute([$newState, $id]);
                log_activity($admin['id'], $newState ? 'user_activate' : 'user_deactivate', $target['email']);
                $_SESSION['flash'] = $target['full_name'] . ($newState ? ' reactivated.' : ' deactivated — they can no longer sign in.');
                header('Location: admin_users.php');
                exit;
            }
        } elseif ($action === 'resetpw') {
            $temp = temp_password();
            db()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
                ->execute([password_hash($temp, PASSWORD_DEFAULT), $id]);
            log_activity($admin['id'], 'user_resetpw', $target['email']);
            $_SESSION['flash'] = 'Temporary password for ' . $target['email'] . ':  ' . $temp
                               . '  — share it securely and ask them to change it under My account.';
            header('Location: admin_users.php');
            exit;
        }
    }
}

// ============ load users ============
$users = db()->query(
    'SELECT u.*, (SELECT COUNT(*) FROM documents d WHERE d.uploaded_by = u.id) AS doc_count
       FROM users u ORDER BY u.is_active DESC, u.full_name'
)->fetchAll();

$initials = strtoupper(mb_substr($admin['name'], 0, 1) .
            (strpos($admin['name'], ' ') !== false
              ? mb_substr($admin['name'], strpos($admin['name'], ' ') + 1, 1) : ''));
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Users — FCS DocHub</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bitter:wght@500;600;700&family=Public+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/style.css?v=4">
</head>
<body class="app-body">

<header class="topbar">
  <a class="brand-mini" href="dashboard.php">
    <svg width="26" height="26" viewBox="0 0 40 40" fill="none" aria-hidden="true">
      <path d="M20 8c-4 5-9 7-9 13a9 9 0 0 0 18 0c0-6-5-8-9-13z" fill="#63A93C"/>
      <path d="M20 15c-2 2.6-4.5 3.7-4.5 6.7a4.5 4.5 0 0 0 9 0c0-3-2.5-4.1-4.5-6.7z" fill="#1E4A8C"/>
    </svg>
    FCS DocHub
  </a>
  <nav class="topnav">
    <a href="dashboard.php">Documents</a>
    <a href="admin_users.php" class="active">Users</a>
    <a href="admin_folders.php">Folders</a>
    <a href="profile.php">My account</a>
  </nav>
  <div class="spacer"></div>
  <div class="userchip">
    <div class="who">
      <div class="nm"><?= e($admin['name']) ?></div>
      <span class="badge badge-admin">Admin</span>
    </div>
    <div class="avatar"><?= e($initials) ?></div>
  </div>
  <a class="logout" href="logout.php">Sign out</a>
</header>

<div class="body-grid">
  <main class="main main-narrow">
    <div class="main-head">
      <div>
        <h2>User accounts</h2>
        <div class="sub"><?= count($users) ?> account<?= count($users) === 1 ? '' : 's' ?> · roles control what people can do everywhere in DocHub</div>
      </div>
    </div>

    <?php if ($flash): ?><div class="perm-note editor" role="status"><?= e($flash) ?></div><?php endif; ?>
    <?php if ($error): ?><div class="perm-note danger" role="alert"><?= e($error) ?></div><?php endif; ?>

    <section class="card">
      <h3 class="card-title">Add a user</h3>
      <form method="post" action="admin_users.php" class="add-grid">
        <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
        <input type="hidden" name="action" value="add">
        <div class="field">
          <label for="full_name">Full name</label>
          <input type="text" id="full_name" name="full_name" required maxlength="120"
                 value="<?= e($_POST['full_name'] ?? '') ?>" placeholder="Jane Doe">
        </div>
        <div class="field">
          <label for="email">Email</label>
          <input type="email" id="email" name="email" required maxlength="190"
                 value="<?= e($_POST['email'] ?? '') ?>" placeholder="jdoe@fcsgw.org">
        </div>
        <div class="field">
          <label for="role">Role</label>
          <select id="role" name="role">
            <option value="viewer">Viewer — read &amp; download only</option>
            <option value="editor">Editor — upload, rename, delete</option>
            <option value="admin">Admin — everything, incl. users</option>
          </select>
        </div>
        <div class="field">
          <label for="password">Initial password <span class="lbl-hint">(min 10 chars — they should change it)</span></label>
          <input type="text" id="password" name="password" required minlength="10"
                 autocomplete="new-password" placeholder="e.g. Willow-2481-Stone">
        </div>
        <div class="field field-submit">
          <button type="submit" class="btn btn-blue">Create account</button>
        </div>
      </form>
    </section>

    <table class="doc-table" aria-label="User accounts">
      <thead>
        <tr>
          <th>Person</th>
          <th>Role</th>
          <th>Uploads</th>
          <th>Last sign-in</th>
          <th style="text-align:right">Actions</th>
        </tr>
      </thead>
      <tbody>
      <?php foreach ($users as $u): $me = ((int)$u['id'] === (int)$admin['id']); ?>
        <tr class="<?= $u['is_active'] ? '' : 'row-inactive' ?>">
          <td>
            <div class="doc-name">
              <span class="avatar avatar-sm"><?= e(strtoupper(mb_substr($u['full_name'],0,1))) ?></span>
              <div>
                <?= e($u['full_name']) ?><?= $me ? ' <span class="you-tag">you</span>' : '' ?>
                <?= $u['is_active'] ? '' : ' <span class="badge badge-off">Deactivated</span>' ?>
                <div class="meta"><?= e($u['email']) ?></div>
              </div>
            </div>
          </td>
          <td>
            <form method="post" action="admin_users.php" class="inline-form">
              <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
              <input type="hidden" name="action" value="role">
              <input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
              <select name="role" class="role-select" onchange="this.form.submit()" <?= $u['is_active'] ? '' : 'disabled' ?>>
                <option value="viewer" <?= $u['role']==='viewer'?'selected':'' ?>>Viewer</option>
                <option value="editor" <?= $u['role']==='editor'?'selected':'' ?>>Editor</option>
                <option value="admin"  <?= $u['role']==='admin' ?'selected':'' ?>>Admin</option>
              </select>
            </form>
          </td>
          <td class="meta"><?= (int)$u['doc_count'] ?></td>
          <td class="meta"><?= $u['last_login'] ? date('M d, Y H:i', strtotime($u['last_login'])) : 'Never' ?></td>
          <td>
            <div class="row-actions">
              <form method="post" action="admin_users.php" class="inline-form"
                    onsubmit="return confirm('Reset password for <?= e($u['email']) ?>? A temporary password will be shown on screen.');">
                <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
                <input type="hidden" name="action" value="resetpw">
                <input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
                <button class="mini-btn" type="submit" <?= $u['is_active'] ? '' : 'disabled' ?>>Reset password</button>
              </form>
              <form method="post" action="admin_users.php" class="inline-form"
                    <?php if ($u['is_active']): ?>onsubmit="return confirm('Deactivate <?= e($u['full_name']) ?>? They will no longer be able to sign in.');"<?php endif; ?>>
                <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
                <input type="hidden" name="action" value="toggle">
                <input type="hidden" name="id" value="<?= (int)$u['id'] ?>">
                <button class="mini-btn <?= $u['is_active'] ? 'mini-danger' : 'mini-green' ?>" type="submit" <?= $me && $u['is_active'] ? 'disabled title="You can\'t deactivate yourself"' : '' ?>>
                  <?= $u['is_active'] ? 'Deactivate' : 'Reactivate' ?>
                </button>
              </form>
            </div>
          </td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>

    <p class="foot-hint">Deactivating keeps the person's uploads and audit history intact — it only blocks sign-in. Accounts are never hard-deleted so the activity log stays complete.</p>
  </main>
</div>
</body>
</html>
