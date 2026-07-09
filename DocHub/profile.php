<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

$msg = '';
$error = '';

// current notify setting
$ns = db()->prepare('SELECT notify_uploads FROM users WHERE id = ?');
$ns->execute([$user['id']]);
$notifyOn = (bool)$ns->fetchColumn();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'notify') {
    require_csrf();
    $notifyOn = isset($_POST['notify_uploads']);
    db()->prepare('UPDATE users SET notify_uploads = ? WHERE id = ?')
        ->execute([$notifyOn ? 1 : 0, $user['id']]);
    $msg = $notifyOn
        ? 'Upload notifications turned on — you\'ll get an email when documents are added to folders you can see.'
        : 'Upload notifications turned off.';
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf();
    $current = $_POST['current_password'] ?? '';
    $new     = $_POST['new_password'] ?? '';
    $confirm = $_POST['confirm_password'] ?? '';

    $stmt = db()->prepare('SELECT password_hash FROM users WHERE id = ? AND is_active = 1');
    $stmt->execute([$user['id']]);
    $row = $stmt->fetch();

    if (!$row || !password_verify($current, $row['password_hash'])) {
        $error = 'Your current password wasn\'t correct.';
    } elseif (strlen($new) < 10) {
        $error = 'New password must be at least 10 characters.';
    } elseif ($new !== $confirm) {
        $error = 'The two new passwords don\'t match.';
    } elseif ($new === $current) {
        $error = 'The new password must be different from the current one.';
    } else {
        db()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
            ->execute([password_hash($new, PASSWORD_DEFAULT), $user['id']]);
        log_activity($user['id'], 'password_change');
        session_regenerate_id(true);
        $msg = 'Password changed. Use the new one next time you sign in.';
    }
}

$initials = strtoupper(mb_substr($user['name'], 0, 1) .
            (strpos($user['name'], ' ') !== false
              ? mb_substr($user['name'], strpos($user['name'], ' ') + 1, 1) : ''));
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>My account — FCS DocHub</title>
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
    <?php if (is_admin($user)): ?>
      <a href="admin_users.php">Users</a>
      <a href="admin_folders.php">Folders</a>
    <?php endif; ?>
    <a href="profile.php" class="active">My account</a>
  </nav>
  <div class="spacer"></div>
  <div class="userchip">
    <div class="who">
      <div class="nm"><?= e($user['name']) ?></div>
      <span class="badge badge-<?= e($user['role']) ?>"><?= e(ucfirst($user['role'])) ?></span>
    </div>
    <div class="avatar"><?= e($initials) ?></div>
  </div>
  <a class="logout" href="logout.php">Sign out</a>
</header>

<div class="body-grid">
  <main class="main main-narrow">
    <div class="main-head">
      <div>
        <h2>My account</h2>
        <div class="sub">Signed in as <?= e($user['email']) ?> · <?= e(ucfirst($user['role'])) ?> access</div>
      </div>
    </div>

    <?php if ($msg): ?><div class="perm-note editor" role="status"><?= e($msg) ?></div><?php endif; ?>
    <?php if ($error): ?><div class="perm-note danger" role="alert"><?= e($error) ?></div><?php endif; ?>

    <section class="card card-slim">
      <h3 class="card-title">Change password</h3>
      <form method="post" action="profile.php">
        <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
        <div class="field">
          <label for="current_password">Current password</label>
          <input type="password" id="current_password" name="current_password"
                 autocomplete="current-password" required>
        </div>
        <div class="field">
          <label for="new_password">New password <span class="lbl-hint">(min 10 characters)</span></label>
          <input type="password" id="new_password" name="new_password"
                 autocomplete="new-password" minlength="10" required>
        </div>
        <div class="field">
          <label for="confirm_password">Confirm new password</label>
          <input type="password" id="confirm_password" name="confirm_password"
                 autocomplete="new-password" minlength="10" required>
        </div>
        <button type="submit" class="btn btn-blue">Change password</button>
      </form>
    </section>

    <section class="card card-slim">
      <h3 class="card-title">Notifications</h3>
      <form method="post" action="profile.php">
        <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
        <input type="hidden" name="action" value="notify">
        <label class="chk-inline chk-block">
          <input type="checkbox" name="notify_uploads" value="1" <?= $notifyOn ? 'checked' : '' ?>>
          Email me when documents are uploaded to folders I can access
        </label>
        <button type="submit" class="btn btn-ghost btn-sm" style="margin-top:12px">Save preference</button>
      </form>
    </section>
  </main>
</div>
</body>
</html>
