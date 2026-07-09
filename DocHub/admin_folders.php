<?php
require_once __DIR__ . '/includes/auth.php';
$admin = require_admin();

$flash = $_SESSION['flash'] ?? '';
$error = '';
unset($_SESSION['flash']);

// ============ handle actions ============
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf();
    $action = $_POST['action'] ?? '';

    if ($action === 'add_folder') {
        $name = trim($_POST['name'] ?? '');
        $name = preg_replace('/[\\x00-\\x1F\\/\\\\]/u', '', $name);
        $name = mb_substr($name, 0, 120);
        if ($name === '') {
            $error = 'Enter a folder name.';
        } else {
            $dupe = db()->prepare('SELECT id FROM folders WHERE name = ?');
            $dupe->execute([$name]);
            if ($dupe->fetch()) {
                $error = 'A folder with that name already exists.';
            } else {
                $max = (int)db()->query('SELECT COALESCE(MAX(sort_order),0) FROM folders')->fetchColumn();
                db()->prepare('INSERT INTO folders (name, sort_order, restricted) VALUES (?,?,?)')
                    ->execute([$name, $max + 1, isset($_POST['restricted']) ? 1 : 0]);
                log_activity($admin['id'], 'folder_add', $name);
                $_SESSION['flash'] = 'Folder "' . $name . '" created.';
                header('Location: admin_folders.php');
                exit;
            }
        }
    }

    if ($action === 'toggle_restricted') {
        $fid = (int)($_POST['folder_id'] ?? 0);
        $f = folder_meta($fid);
        if ($f) {
            $new = (int)$f['restricted'] ? 0 : 1;
            db()->prepare('UPDATE folders SET restricted = ? WHERE id = ?')->execute([$new, $fid]);
            log_activity($admin['id'], 'folder_restrict', $f['name'] . ' → ' . ($new ? 'restricted' : 'open'));
            $_SESSION['flash'] = '"' . $f['name'] . '" is now ' . ($new
                ? 'restricted — only admins and permitted users can see it.'
                : 'open to all signed-in users.');
            header('Location: admin_folders.php?folder=' . $fid);
            exit;
        }
    }

    if ($action === 'delete_folder') {
        $fid = (int)($_POST['folder_id'] ?? 0);
        $f = folder_meta($fid);
        if ($f) {
            $count = db()->prepare('SELECT COUNT(*) FROM documents WHERE folder_id = ?');
            $count->execute([$fid]);
            if ((int)$count->fetchColumn() > 0) {
                $error = '"' . $f['name'] . '" still contains documents — move or delete them first.';
            } else {
                db()->prepare('DELETE FROM folders WHERE id = ?')->execute([$fid]);
                log_activity($admin['id'], 'folder_delete', $f['name']);
                $_SESSION['flash'] = 'Folder "' . $f['name'] . '" deleted.';
                header('Location: admin_folders.php');
                exit;
            }
        }
    }

    if ($action === 'save_perms') {
        $fid = (int)($_POST['folder_id'] ?? 0);
        $f = folder_meta($fid);
        if ($f) {
            $levels = (array)($_POST['level'] ?? []); // user_id => none|view|edit
            $pdo = db();
            $pdo->beginTransaction();
            try {
                $pdo->prepare('DELETE FROM folder_permissions WHERE folder_id = ?')->execute([$fid]);
                $ins = $pdo->prepare('INSERT INTO folder_permissions (folder_id, user_id, can_edit) VALUES (?,?,?)');
                foreach ($levels as $uid => $level) {
                    $uid = (int)$uid;
                    if ($level === 'view') $ins->execute([$fid, $uid, 0]);
                    if ($level === 'edit') $ins->execute([$fid, $uid, 1]);
                }
                $pdo->commit();
                log_activity($admin['id'], 'folder_perms', $f['name']);
                $_SESSION['flash'] = 'Permissions for "' . $f['name'] . '" saved.';
            } catch (Throwable $e) {
                $pdo->rollBack();
                $_SESSION['flash'] = 'Saving permissions failed — try again.';
            }
            header('Location: admin_folders.php?folder=' . $fid);
            exit;
        }
    }
}

// ============ load data ============
$folders = db()->query(
    'SELECT f.*, COUNT(d.id) AS doc_count
       FROM folders f LEFT JOIN documents d ON d.folder_id = f.id
   GROUP BY f.id ORDER BY f.sort_order, f.name'
)->fetchAll();

$selId = isset($_GET['folder']) ? (int)$_GET['folder'] : (int)($folders[0]['id'] ?? 0);
$sel   = null;
foreach ($folders as $f) {
    if ((int)$f['id'] === $selId) { $sel = $f; break; }
}
if (!$sel && $folders) { $sel = $folders[0]; $selId = (int)$sel['id']; }

$allUsers = db()->query(
    "SELECT id, full_name, email, role FROM users WHERE is_active = 1 AND role <> 'admin' ORDER BY full_name"
)->fetchAll();

$perms = [];
if ($sel) {
    $ps = db()->prepare('SELECT user_id, can_edit FROM folder_permissions WHERE folder_id = ?');
    $ps->execute([$selId]);
    foreach ($ps->fetchAll() as $p) {
        $perms[(int)$p['user_id']] = (int)$p['can_edit'];
    }
}

$initials = strtoupper(mb_substr($admin['name'], 0, 1) .
            (strpos($admin['name'], ' ') !== false
              ? mb_substr($admin['name'], strpos($admin['name'], ' ') + 1, 1) : ''));
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Folders — FCS DocHub</title>
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
    <a href="admin_users.php">Users</a>
    <a href="admin_folders.php" class="active">Folders</a>
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
        <h2>Folders &amp; access</h2>
        <div class="sub">Open folders follow global roles. Restricted folders are visible only to admins and the people you grant below — including per-folder edit rights.</div>
      </div>
    </div>

    <?php if ($flash): ?><div class="perm-note editor" role="status"><?= e($flash) ?></div><?php endif; ?>
    <?php if ($error): ?><div class="perm-note danger" role="alert"><?= e($error) ?></div><?php endif; ?>

    <section class="card">
      <h3 class="card-title">Add a folder</h3>
      <form method="post" action="admin_folders.php" class="add-inline">
        <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
        <input type="hidden" name="action" value="add_folder">
        <input type="text" name="name" required maxlength="120" placeholder="Folder name, e.g. Finance">
        <label class="chk-inline"><input type="checkbox" name="restricted" value="1"> Restricted</label>
        <button type="submit" class="btn btn-blue btn-sm">Create folder</button>
      </form>
    </section>

    <div class="split">
      <section class="card split-list">
        <h3 class="card-title">Folders</h3>
        <?php foreach ($folders as $f): ?>
          <a class="folder-btn<?= (int)$f['id'] === $selId ? ' active' : '' ?>" href="admin_folders.php?folder=<?= (int)$f['id'] ?>">
            <span><?= e($f['name']) ?></span>
            <?php if ((int)$f['restricted']): ?>
              <svg class="lock" width="11" height="11" viewBox="0 0 16 16" fill="none" aria-label="Restricted"><rect x="3" y="7" width="10" height="7" rx="1.5" fill="var(--slate)"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2" stroke="var(--slate)" stroke-width="1.8"/></svg>
            <?php endif; ?>
            <span class="count"><?= (int)$f['doc_count'] ?></span>
          </a>
        <?php endforeach; ?>
      </section>

      <?php if ($sel): ?>
      <section class="card split-detail">
        <h3 class="card-title"><?= e($sel['name']) ?>
          <?php if ((int)$sel['restricted']): ?><span class="badge badge-off">Restricted</span><?php else: ?><span class="badge badge-editor">Open</span><?php endif; ?>
        </h3>

        <div class="row-actions" style="justify-content:flex-start;margin-bottom:16px;gap:10px">
          <form method="post" action="admin_folders.php" class="inline-form">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <input type="hidden" name="action" value="toggle_restricted">
            <input type="hidden" name="folder_id" value="<?= $selId ?>">
            <button class="mini-btn" type="submit"><?= (int)$sel['restricted'] ? 'Make open to everyone' : 'Make restricted' ?></button>
          </form>
          <form method="post" action="admin_folders.php" class="inline-form"
                onsubmit="return confirm('Delete folder <?= e($sel['name']) ?>? Only possible when empty.');">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <input type="hidden" name="action" value="delete_folder">
            <input type="hidden" name="folder_id" value="<?= $selId ?>">
            <button class="mini-btn mini-danger" type="submit" <?= (int)$sel['doc_count'] > 0 ? 'disabled title="Folder is not empty"' : '' ?>>Delete folder</button>
          </form>
        </div>

        <?php if ((int)$sel['restricted']): ?>
          <form method="post" action="admin_folders.php">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <input type="hidden" name="action" value="save_perms">
            <input type="hidden" name="folder_id" value="<?= $selId ?>">
            <table class="doc-table" aria-label="Folder permissions">
              <thead>
                <tr><th>Person</th><th>No access</th><th>View</th><th>Edit</th></tr>
              </thead>
              <tbody>
              <?php if (!$allUsers): ?>
                <tr><td colspan="4" class="empty">No non-admin users yet — add them under Users.</td></tr>
              <?php endif; ?>
              <?php foreach ($allUsers as $u):
                  $lvl = array_key_exists((int)$u['id'], $perms) ? ($perms[(int)$u['id']] ? 'edit' : 'view') : 'none';
              ?>
                <tr>
                  <td>
                    <?= e($u['full_name']) ?>
                    <div class="meta"><?= e($u['email']) ?> · global <?= e($u['role']) ?></div>
                  </td>
                  <td><input type="radio" name="level[<?= (int)$u['id'] ?>]" value="none" <?= $lvl==='none'?'checked':'' ?> aria-label="No access for <?= e($u['full_name']) ?>"></td>
                  <td><input type="radio" name="level[<?= (int)$u['id'] ?>]" value="view" <?= $lvl==='view'?'checked':'' ?> aria-label="View for <?= e($u['full_name']) ?>"></td>
                  <td><input type="radio" name="level[<?= (int)$u['id'] ?>]" value="edit" <?= $lvl==='edit'?'checked':'' ?> aria-label="Edit for <?= e($u['full_name']) ?>"></td>
                </tr>
              <?php endforeach; ?>
              </tbody>
            </table>
            <?php if ($allUsers): ?>
              <button type="submit" class="btn btn-blue" style="margin-top:14px">Save permissions</button>
            <?php endif; ?>
          </form>
          <p class="foot-hint">Admins always have full access. "Edit" here grants upload/rename/delete in this folder even to people whose global role is Viewer.</p>
        <?php else: ?>
          <p class="foot-hint">This folder is open: every signed-in user can view it, and global Editors/Admins can edit. Make it restricted to choose people individually.</p>
        <?php endif; ?>
      </section>
      <?php endif; ?>
    </div>
  </main>
</div>
</body>
</html>
