<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

$id = (int)($_GET['id'] ?? ($_POST['id'] ?? 0));
$stmt = db()->prepare(
    'SELECT d.*, f.name AS folder_name FROM documents d
       JOIN folders f ON f.id = d.folder_id WHERE d.id = ?'
);
$stmt->execute([$id]);
$doc = $stmt->fetch();

if (!$doc) {
    http_response_code(404);
    exit('Document not found.');
}
if (!folder_access((int)$doc['folder_id'], $user)['edit']) {
    http_response_code(403);
    exit('You don\'t have edit access to this document.');
}

$ext = strtolower($doc['file_ext']);
if (!in_array($ext, ['txt', 'csv'], true)) {
    http_response_code(400);
    exit('Only .txt and .csv files can be edited in the browser. Use "Upload new version" for other types.');
}

$path = rtrim(STORAGE_DIR, '/') . '/' . $doc['stored_name'];
if (basename($doc['stored_name']) !== $doc['stored_name'] || !is_file($path)) {
    http_response_code(404);
    exit('File is missing from storage.');
}

$maxEdit = 2 * 1024 * 1024; // 2 MB in-browser edit cap
if (filesize($path) > $maxEdit) {
    exit('This file is too large to edit in the browser (2 MB limit). Download it, edit locally, then use "Upload new version".');
}

$msg = '';

// ---------- save ----------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf();
    $content = $_POST['content'] ?? '';
    // normalize line endings, cap size
    $content = str_replace("\r\n", "\n", $content);
    if (strlen($content) > $maxEdit) {
        $msg = 'Content exceeds the 2 MB editing limit — changes were not saved.';
    } else {
        $newStored = bin2hex(random_bytes(20)) . '.' . $ext;
        $newPath   = rtrim(STORAGE_DIR, '/') . '/' . $newStored;
        if (file_put_contents($newPath, $content) === false) {
            $msg = 'Could not write the file — changes were not saved.';
        } else {
            $pdo = db();
            $pdo->beginTransaction();
            try {
                // current file becomes a version
                $pdo->prepare(
                    'INSERT INTO document_versions (document_id, stored_name, mime_type, file_ext, size_bytes, uploaded_by, created_at)
                     VALUES (?,?,?,?,?,?,?)'
                )->execute([
                    $doc['id'], $doc['stored_name'], $doc['mime_type'], $doc['file_ext'],
                    $doc['size_bytes'], $doc['uploaded_by'], $doc['updated_at'],
                ]);
                $pdo->prepare(
                    'UPDATE documents SET stored_name=?, size_bytes=?, uploaded_by=? WHERE id=?'
                )->execute([$newStored, strlen($content), $user['id'], $doc['id']]);
                $pdo->commit();
                log_activity($user['id'], 'edit', $doc['display_name']);
                $_SESSION['flash'] = '"' . $doc['display_name'] . '" saved — previous copy kept in history.';
                header('Location: view.php?id=' . (int)$doc['id']);
                exit;
            } catch (Throwable $e) {
                $pdo->rollBack();
                @unlink($newPath);
                $msg = 'Saving failed — please try again.';
            }
        }
    }
    // fall through to re-render editor with attempted content
    $current = $content;
} else {
    $current = (string)file_get_contents($path);
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
<title>Edit — <?= e($doc['display_name']) ?> — FCS DocHub</title>
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
  <main class="main viewer-main">
    <form method="post" action="edit.php" class="editor-form" id="editorForm">
      <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
      <input type="hidden" name="id" value="<?= (int)$doc['id'] ?>">
      <div class="viewer-head">
        <div>
          <p class="crumb"><a href="view.php?id=<?= (int)$doc['id'] ?>">← Back to viewer</a></p>
          <h2 class="doc-name">
            <span class="ficon f-doc"><?= e(strtoupper($ext)) ?></span>
            Editing: <?= e($doc['display_name']) ?>
          </h2>
          <div class="sub"><?= e($doc['folder_name']) ?> · saving creates a new version, the current copy is kept in history</div>
        </div>
        <div class="row-actions" style="align-items:center">
          <a class="btn btn-ghost btn-sm" href="view.php?id=<?= (int)$doc['id'] ?>">Cancel</a>
          <button type="submit" class="btn btn-blue btn-sm">Save changes</button>
        </div>
      </div>

      <?php if ($msg): ?><div class="perm-note danger" role="alert"><?= e($msg) ?></div><?php endif; ?>

      <div class="viewer-stage">
        <textarea class="editor-area" name="content" id="editorArea"
                  spellcheck="<?= $ext === 'csv' ? 'false' : 'true' ?>"
                  aria-label="File content"><?= e($current) ?></textarea>
      </div>
      <p class="foot-hint">Tip: Ctrl+S (Cmd+S on Mac) saves. Unsaved changes are warned about before leaving.</p>
    </form>
  </main>
</div>

<script>
(function(){
  var dirty = false;
  var area = document.getElementById('editorArea');
  var form = document.getElementById('editorForm');
  area.addEventListener('input', function(){ dirty = true; });
  form.addEventListener('submit', function(){ dirty = false; });
  window.addEventListener('beforeunload', function(e){
    if (dirty){ e.preventDefault(); e.returnValue = ''; }
  });
  document.addEventListener('keydown', function(e){
    if ((e.ctrlKey || e.metaKey) && e.key === 's'){
      e.preventDefault();
      form.submit();
    }
  });
})();
</script>
</body>
</html>
