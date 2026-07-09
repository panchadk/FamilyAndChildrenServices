<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

$id = (int)($_GET['id'] ?? ($_POST['id'] ?? 0));
$stmt = db()->prepare(
    'SELECT d.*, f.name AS folder_name, u.full_name AS owner_name
       FROM documents d
       JOIN folders f ON f.id = d.folder_id
       JOIN users u   ON u.id = d.uploaded_by
      WHERE d.id = ?'
);
$stmt->execute([$id]);
$doc = $stmt->fetch();

if (!$doc) {
    http_response_code(404);
    exit('Document not found.');
}
$acc = folder_access((int)$doc['folder_id'], $user);
if (!$acc['view']) {
    http_response_code(403);
    exit('You don\'t have access to this document.');
}

$flash = $_SESSION['flash'] ?? '';
unset($_SESSION['flash']);

// ---------- restore an old version (edit access required) ----------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'restore') {
    require_csrf();
    if (!$acc['edit']) {
        http_response_code(403);
        exit('You don\'t have edit access to this folder.');
    }
    $verId = (int)($_POST['ver'] ?? 0);
    $vs = db()->prepare('SELECT * FROM document_versions WHERE id = ? AND document_id = ?');
    $vs->execute([$verId, $id]);
    $version = $vs->fetch();
    if ($version) {
        $pdo = db();
        $pdo->beginTransaction();
        try {
            // current file becomes a version…
            $pdo->prepare(
                'INSERT INTO document_versions (document_id, stored_name, mime_type, file_ext, size_bytes, uploaded_by, created_at)
                 VALUES (?,?,?,?,?,?,?)'
            )->execute([
                $id, $doc['stored_name'], $doc['mime_type'], $doc['file_ext'],
                $doc['size_bytes'], $doc['uploaded_by'], $doc['updated_at'],
            ]);
            // …and the chosen version becomes current
            $pdo->prepare(
                'UPDATE documents SET stored_name=?, mime_type=?, file_ext=?, size_bytes=?, uploaded_by=? WHERE id=?'
            )->execute([
                $version['stored_name'], $version['mime_type'], $version['file_ext'],
                $version['size_bytes'], $version['uploaded_by'], $id,
            ]);
            $pdo->prepare('DELETE FROM document_versions WHERE id = ?')->execute([$verId]);
            $pdo->commit();
            log_activity($user['id'], 'restore_version', $doc['display_name']);
            $_SESSION['flash'] = 'Version from ' . date('M d, Y H:i', strtotime($version['created_at'])) . ' restored.';
        } catch (Throwable $e) {
            $pdo->rollBack();
            $_SESSION['flash'] = 'Restore failed — please try again.';
        }
    }
    header('Location: versions.php?id=' . $id);
    exit;
}

// ---------- load versions ----------
$versions = db()->prepare(
    'SELECT v.*, u.full_name AS uploader_name
       FROM document_versions v
       JOIN users u ON u.id = v.uploaded_by
      WHERE v.document_id = ?
      ORDER BY v.created_at DESC'
);
$versions->execute([$id]);
$versions = $versions->fetchAll();

$bucket   = ext_bucket($doc['file_ext']);
$initials = strtoupper(mb_substr($user['name'], 0, 1) .
            (strpos($user['name'], ' ') !== false
              ? mb_substr($user['name'], strpos($user['name'], ' ') + 1, 1) : ''));
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>History — <?= e($doc['display_name']) ?> — FCS DocHub</title>
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
    <a href="profile.php">My account</a>
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
    <p class="crumb"><a href="dashboard.php?folder=<?= (int)$doc['folder_id'] ?>">← <?= e($doc['folder_name']) ?></a></p>
    <div class="main-head">
      <div>
        <h2 class="doc-name"><span class="ficon f-<?= $bucket ?>"><?= e(strtoupper($doc['file_ext'])) ?></span> <?= e($doc['display_name']) ?></h2>
        <div class="sub">Version history · <?= count($versions) + 1 ?> version<?= count($versions) ? 's' : '' ?></div>
      </div>
    </div>

    <?php if ($flash): ?><div class="perm-note editor" role="status"><?= e($flash) ?></div><?php endif; ?>

    <table class="doc-table" aria-label="Versions">
      <thead>
        <tr>
          <th>Version</th>
          <th>Uploaded by</th>
          <th>Date</th>
          <th>Size</th>
          <th style="text-align:right">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Current</strong></td>
          <td class="meta"><?= e($doc['owner_name']) ?></td>
          <td class="meta"><?= date('M d, Y H:i', strtotime($doc['updated_at'])) ?></td>
          <td><span class="mono"><?= human_size((int)$doc['size_bytes']) ?></span></td>
          <td>
            <div class="row-actions">
              <a class="mini-btn" href="download.php?id=<?= (int)$doc['id'] ?>">Download</a>
            </div>
          </td>
        </tr>
        <?php $n = count($versions); foreach ($versions as $v): ?>
        <tr>
          <td class="meta">Version <?= $n-- ?></td>
          <td class="meta"><?= e($v['uploader_name']) ?></td>
          <td class="meta"><?= date('M d, Y H:i', strtotime($v['created_at'])) ?></td>
          <td><span class="mono"><?= human_size((int)$v['size_bytes']) ?></span></td>
          <td>
            <div class="row-actions">
              <a class="mini-btn" href="download.php?id=<?= (int)$doc['id'] ?>&ver=<?= (int)$v['id'] ?>">Download</a>
              <?php if ($acc['edit']): ?>
              <form method="post" action="versions.php" class="inline-form"
                    onsubmit="return confirm('Restore this version? The current file will be kept in history.');">
                <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
                <input type="hidden" name="action" value="restore">
                <input type="hidden" name="id" value="<?= (int)$doc['id'] ?>">
                <input type="hidden" name="ver" value="<?= (int)$v['id'] ?>">
                <button class="mini-btn mini-green" type="submit">Restore</button>
              </form>
              <?php endif; ?>
            </div>
          </td>
        </tr>
        <?php endforeach; ?>
        <?php if (!$versions): ?>
          <tr><td colspan="5" class="empty">No earlier versions. Uploading a file named "<?= e($doc['display_name']) ?>" into <?= e($doc['folder_name']) ?> will create one.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>

    <?php if ($acc['edit']): ?>
      <div class="row-actions" style="justify-content:flex-start;margin-top:16px;gap:10px">
        <form method="post" action="rename.php" class="inline-form"
              onsubmit="var nm=prompt('Rename document:', this.dataset.name); if(!nm||!nm.trim())return false; this.new_name.value=nm.trim(); return true;"
              data-name="<?= e($doc['display_name']) ?>">
          <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
          <input type="hidden" name="id" value="<?= (int)$doc['id'] ?>">
          <input type="hidden" name="new_name" value="">
          <button class="btn btn-ghost btn-sm" type="submit">Rename</button>
        </form>
        <form method="post" action="delete.php" class="inline-form"
              onsubmit="return confirm('Delete this document and ALL its versions? This can\'t be undone.');">
          <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
          <input type="hidden" name="id" value="<?= (int)$doc['id'] ?>">
          <button class="btn btn-ghost btn-sm btn-danger-ghost" type="submit">Delete document</button>
        </form>
      </div>
    <?php endif; ?>
  </main>
</div>
</body>
</html>
