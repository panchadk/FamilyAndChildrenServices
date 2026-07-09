<?php
require_once __DIR__ . '/includes/auth.php';

// Already signed in? Straight to the dashboard.
if (current_user()) {
    header('Location: dashboard.php');
    exit;
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf();
    $email = strtolower(trim($_POST['email'] ?? ''));
    $pass  = $_POST['password'] ?? '';

    $stmt = db()->prepare('SELECT * FROM users WHERE email = ? AND is_active = 1');
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user && password_verify($pass, $user['password_hash'])) {
        session_regenerate_id(true);
        $_SESSION['user'] = [
            'id'    => (int)$user['id'],
            'email' => $user['email'],
            'name'  => $user['full_name'],
            'role'  => $user['role'],
        ];
        db()->prepare('UPDATE users SET last_login = NOW() WHERE id = ?')->execute([$user['id']]);
        log_activity((int)$user['id'], 'login');
        header('Location: dashboard.php');
        exit;
    }
    // Same message for wrong email or wrong password (don't leak which)
    $error = "That email or password wasn't recognized. Check your details and try again.";
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sign in — FCS DocHub</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bitter:wght@500;600;700&family=Public+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/style.css?v=4">
</head>
<body>
<div class="login-shell">
  <div class="login-brand">
    <span class="leaf" style="width:26px;height:26px;background:#63A93C;top:12%;left:64%;"></span>
    <span class="leaf" style="width:16px;height:16px;background:#A8D97F;top:22%;left:80%;animation-delay:-3s"></span>
    <span class="leaf" style="width:20px;height:20px;background:#E8B84B;top:38%;left:72%;animation-delay:-6s"></span>
    <span class="leaf" style="width:14px;height:14px;background:#7FB8E8;top:55%;left:84%;animation-delay:-2s"></span>
    <span class="leaf" style="width:22px;height:22px;background:#C0503C;top:66%;left:70%;animation-delay:-8s;opacity:.6"></span>
    <span class="leaf" style="width:18px;height:18px;background:#A8D97F;top:78%;left:82%;animation-delay:-5s"></span>

    <div class="brand-top">
      <div class="brand-mark">
        <svg width="40" height="40" viewBox="0 0 40 40" fill="none" aria-hidden="true">
          <circle cx="20" cy="20" r="19" fill="#fff" opacity=".14"/>
          <path d="M20 8c-4 5-9 7-9 13a9 9 0 0 0 18 0c0-6-5-8-9-13z" fill="#A8D97F"/>
          <path d="M20 15c-2 2.6-4.5 3.7-4.5 6.7a4.5 4.5 0 0 0 9 0c0-3-2.5-4.1-4.5-6.7z" fill="#1E4A8C"/>
        </svg>
        <div class="brand-name">FCS DocHub
          <span>Family &amp; Children's Services of Guelph and Wellington County</span>
        </div>
      </div>
    </div>

    <div class="brand-hero">
      <h1>One secure place for every agency <em>document</em>.</h1>
      <p>Policies, forms, board records and images — organized, versioned, and shared with exactly the right people.</p>
      <div class="brand-points">
        <div class="brand-point"><span class="dot"><svg viewBox="0 0 16 16" fill="none"><path d="M2 8.5 6 12l8-9" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg></span>Role-based access — editors manage, viewers read</div>
        <div class="brand-point"><span class="dot"><svg viewBox="0 0 16 16" fill="none"><path d="M2 8.5 6 12l8-9" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg></span>Upload documents and images with drag &amp; drop</div>
        <div class="brand-point"><span class="dot"><svg viewBox="0 0 16 16" fill="none"><path d="M2 8.5 6 12l8-9" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg></span>Every change tracked to a named account</div>
      </div>
    </div>

    <div class="brand-foot">Internal staff portal · Authorized users only</div>
  </div>

  <div class="login-panel">
    <form class="login-card" method="post" action="index.php">
      <h2>Sign in</h2>
      <p>Use your agency account to continue.</p>
      <?php if ($error): ?>
        <div class="login-error show"><?= e($error) ?></div>
      <?php endif; ?>
      <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
      <div class="field">
        <label for="email">Email</label>
        <input type="email" id="email" name="email" autocomplete="username"
               placeholder="you@fcsgw.org" required
               value="<?= e($_POST['email'] ?? '') ?>">
      </div>
      <div class="field">
        <label for="password">Password</label>
        <input type="password" id="password" name="password" autocomplete="current-password"
               placeholder="••••••••" required>
      </div>
      <button type="submit" class="btn btn-primary">Sign in</button>
      <p class="login-help">Need an account or a password reset? Contact your IT administrator.</p>
    </form>
  </div>
</div>
</body>
</html>
