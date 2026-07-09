<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

// ---------- inputs ----------
$folderId = isset($_GET['folder']) ? (int)$_GET['folder'] : 0; // 0 = all
$q        = trim($_GET['q'] ?? '');
$mine     = isset($_GET['mine']) && $_GET['mine'] === '1';
$flash    = $_SESSION['flash'] ?? '';
unset($_SESSION['flash']);

// ---------- folders this user may see ----------
$folders   = accessible_folders($user);
$folderIds = array_map(fn($f) => (int)$f['id'], $folders);
$totalDocs = array_sum(array_column($folders, 'doc_count'));

// A specific folder was requested — verify access
$canEditHere = can_edit($user); // default for "All" view: global role
$folderName  = 'All documents';
if ($folderId > 0) {
    $acc = folder_access($folderId, $user);
    if (!$acc['view']) {
        http_response_code(403);
        exit('You don\'t have access to that folder.');
    }
    $canEditHere = $acc['edit'];
    foreach ($folders as $f) {
        if ((int)$f['id'] === $folderId) { $folderName = $f['name']; break; }
    }
}
if ($mine) $folderName .= ' — my uploads';

// Folders where this user may upload (for the dropzone dropdown)
$editableFolders = array_values(array_filter(
    $folders,
    fn($f) => folder_access((int)$f['id'], $user)['edit']
));
$showUpload = count($editableFolders) > 0;

// ---------- documents ----------
$docs = [];
if ($folderIds) {
    $in   = implode(',', array_fill(0, count($folderIds), '?'));
    $sql  = "SELECT d.*, u.full_name AS owner_name, f.name AS folder_name,
                    (SELECT COUNT(*) FROM document_versions v WHERE v.document_id = d.id) AS version_count
               FROM documents d
               JOIN users u   ON u.id = d.uploaded_by
               JOIN folders f ON f.id = d.folder_id
              WHERE d.folder_id IN ($in)";
    $args = $folderIds;
    if ($folderId > 0) { $sql .= ' AND d.folder_id = ?'; $args[] = $folderId; }
    if ($q !== '')     { $sql .= ' AND d.display_name LIKE ?'; $args[] = '%' . $q . '%'; }
    if ($mine)         { $sql .= ' AND d.uploaded_by = ?'; $args[] = $user['id']; }
    $sql .= ' ORDER BY d.uploaded_at DESC';
    $stmt = db()->prepare($sql);
    $stmt->execute($args);
    $docs = $stmt->fetchAll();
}

$initials = strtoupper(mb_substr($user['name'], 0, 1) .
            (strpos($user['name'], ' ') !== false
              ? mb_substr($user['name'], strpos($user['name'], ' ') + 1, 1) : ''));

// helper to rebuild query strings for links
function qs(array $overrides): string
{
    $params = array_merge($_GET, $overrides);
    $params = array_filter($params, fn($v) => $v !== '' && $v !== null && $v !== 0 && $v !== '0');
    return $params ? '?' . http_build_query($params) : '';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= e($folderName) ?> — FCS DocHub</title>
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
    <a href="dashboard.php" class="active">Documents</a>
    <?php if (is_admin($user)): ?>
      <a href="admin_users.php">Users</a>
      <a href="admin_folders.php">Folders</a>
    <?php endif; ?>
    <a href="profile.php">My account</a>
  </nav>
  <form class="search" method="get" action="dashboard.php">
    <?php if ($folderId): ?><input type="hidden" name="folder" value="<?= $folderId ?>"><?php endif; ?>
    <?php if ($mine): ?><input type="hidden" name="mine" value="1"><?php endif; ?>
    <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><circle cx="7" cy="7" r="5" stroke="currentColor" stroke-width="1.8"/><path d="m11 11 3.5 3.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
    <input type="search" name="q" placeholder="Search documents…" value="<?= e($q) ?>">
  </form>
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
  <nav class="sidebar" aria-label="Folders">
    <div class="side-label">Folders</div>
    <a class="folder-btn<?= $folderId === 0 && !$mine ? ' active' : '' ?>" href="dashboard.php">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M1.5 4.5A1.5 1.5 0 0 1 3 3h3l1.5 1.8H13A1.5 1.5 0 0 1 14.5 6.3v5.2A1.5 1.5 0 0 1 13 13H3a1.5 1.5 0 0 1-1.5-1.5v-7z" fill="var(--blue)" opacity=".85"/></svg>
      <span>All documents</span><span class="count"><?= $totalDocs ?></span>
    </a>
    <?php foreach ($folders as $f): ?>
      <a class="folder-btn<?= $folderId === (int)$f['id'] ? ' active' : '' ?>"
         href="dashboard.php?folder=<?= (int)$f['id'] ?>">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M1.5 4.5A1.5 1.5 0 0 1 3 3h3l1.5 1.8H13A1.5 1.5 0 0 1 14.5 6.3v5.2A1.5 1.5 0 0 1 13 13H3a1.5 1.5 0 0 1-1.5-1.5v-7z" fill="<?= $f['name'] === 'Images' ? '#8A5FB0' : 'var(--blue)' ?>" opacity=".85"/></svg>
        <span><?= e($f['name']) ?></span>
        <?php if ((int)$f['restricted']): ?>
          <svg class="lock" width="11" height="11" viewBox="0 0 16 16" fill="none" aria-label="Restricted"><rect x="3" y="7" width="10" height="7" rx="1.5" fill="var(--slate)"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2" stroke="var(--slate)" stroke-width="1.8"/></svg>
        <?php endif; ?>
        <span class="count"><?= (int)$f['doc_count'] ?></span>
      </a>
    <?php endforeach; ?>
    <div class="side-label">Filters</div>
    <a class="folder-btn<?= $mine ? ' active' : '' ?>" href="dashboard.php<?= qs(['mine' => $mine ? null : '1']) ?>">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="5" r="3" fill="var(--green)"/><path d="M2.5 14c.8-3 3-4.5 5.5-4.5s4.7 1.5 5.5 4.5" stroke="var(--green)" stroke-width="1.8" stroke-linecap="round"/></svg>
      <span>My uploads</span>
    </a>
  </nav>

  <main class="main">
    <div class="main-head">
      <div>
        <h2><?= e($folderName) ?></h2>
        <div class="sub"><?= count($docs) ?> <?= count($docs) === 1 ? 'item' : 'items' ?><?= $q !== '' ? ' matching "' . e($q) . '"' : '' ?></div>
      </div>
    </div>

    <?php if ($flash): ?>
      <div class="perm-note editor" role="status"><?= e($flash) ?></div>
    <?php endif; ?>

    <?php if ($showUpload): ?>
      <form class="upload-form" method="post" action="upload.php" enctype="multipart/form-data" id="uploadForm">
        <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
        <div class="dropzone" id="dropzone">
          <strong>Drag files here to upload</strong> — or
          <label class="filepick">choose files<input type="file" name="files[]" id="fileInput" multiple
                 accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.csv,.txt,.png,.jpg,.jpeg,.gif,.webp"></label>
          <div class="hint">PDF, Word, Excel, PowerPoint and images up to 50 MB each · uploading a file with the same name creates a new version</div>
          <div class="upload-controls">
            <label>Upload into:
              <select name="folder_id" required>
                <?php foreach ($editableFolders as $f): ?>
                  <option value="<?= (int)$f['id'] ?>" <?= $folderId === (int)$f['id'] ? 'selected' : '' ?>><?= e($f['name']) ?></option>
                <?php endforeach; ?>
              </select>
            </label>
            <button type="submit" class="btn btn-blue">Upload selected files</button>
          </div>
          <div class="hint" id="pickedNote"></div>
        </div>
      </form>
    <?php else: ?>
      <div class="perm-note"><strong>View-only access</strong>&nbsp;— you can open and download documents. Contact an administrator to request edit access.</div>
    <?php endif; ?>

    <form method="post" action="bulk_download.php" id="bulkForm">
      <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
      <div class="bulk-bar" id="bulkBar">
        <span id="selCount">0 selected</span>
        <button type="submit" class="btn btn-blue btn-sm">Download selected as ZIP</button>
        <button type="button" class="btn btn-ghost btn-sm" onclick="clearSel()">Clear</button>
      </div>

      <table class="doc-table" aria-label="Documents">
        <thead>
          <tr>
            <th class="chk-col"><input type="checkbox" id="chkAll" aria-label="Select all" onclick="toggleAll(this)"></th>
            <th style="width:40%">Name</th>
            <th>Folder</th>
            <th>Owner</th>
            <th>Modified</th>
            <th>Size</th>
            <th style="text-align:right">Actions</th>
          </tr>
        </thead>
        <tbody>
        <?php if (!$docs): ?>
          <tr><td colspan="7" class="empty">No documents here yet.<?= $showUpload ? ' Upload the first one to get started.' : '' ?></td></tr>
        <?php endif; ?>
        <?php foreach ($docs as $d):
            $bucket  = ext_bucket($d['file_ext']);
            $rowEdit = folder_access((int)$d['folder_id'], $user)['edit'];
        ?>
          <tr>
            <td class="chk-col"><input type="checkbox" class="rowchk" name="ids[]" value="<?= (int)$d['id'] ?>" onclick="updateSel()" aria-label="Select <?= e($d['display_name']) ?>"></td>
            <td>
              <div class="doc-name">
                <span class="ficon f-<?= $bucket ?>"><?= e(strtoupper($d['file_ext'])) ?></span>
                <span><a class="doc-link" href="view.php?id=<?= (int)$d['id'] ?>"><?= e($d['display_name']) ?></a>
                  <?php if ((int)$d['version_count'] > 0): ?>
                    <a class="ver-tag" href="versions.php?id=<?= (int)$d['id'] ?>" title="Version history">v<?= (int)$d['version_count'] + 1 ?></a>
                  <?php endif; ?>
                </span>
              </div>
            </td>
            <td class="meta"><?= e($d['folder_name']) ?></td>
            <td class="meta"><?= e($d['owner_name']) ?></td>
            <td class="meta"><?= date('M d, Y', strtotime($d['updated_at'])) ?></td>
            <td><span class="mono"><?= human_size((int)$d['size_bytes']) ?></span></td>
            <td>
              <div class="row-actions">
                <a class="icon-btn" href="view.php?id=<?= (int)$d['id'] ?>" title="Open in viewer">
                  <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M8 3C4.5 3 2 6 1.2 8 2 10 4.5 13 8 13s6-3 6.8-5C14 6 11.5 3 8 3zm0 8a3 3 0 1 1 0-6 3 3 0 0 1 0 6z" stroke="currentColor" stroke-width="1.4"/></svg>
                </a>
                <a class="icon-btn" href="download.php?id=<?= (int)$d['id'] ?>" title="Download">
                  <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M8 2v8m0 0L4.8 6.8M8 10l3.2-3.2M2.5 13.5h11" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
                </a>
                <a class="icon-btn" href="versions.php?id=<?= (int)$d['id'] ?>" title="Version history">
                  <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.5"/><path d="M8 5v3l2 2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
                </a>
              </div>
            </td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    </form>
  </main>
</div>

<script>
function updateSel(){
  var n = document.querySelectorAll('.rowchk:checked').length;
  document.getElementById('selCount').textContent = n + ' selected';
  document.getElementById('bulkBar').classList.toggle('show', n > 0);
}
function toggleAll(box){
  document.querySelectorAll('.rowchk').forEach(function(c){ c.checked = box.checked; });
  updateSel();
}
function clearSel(){
  document.querySelectorAll('.rowchk, #chkAll').forEach(function(c){ c.checked = false; });
  updateSel();
}
</script>
<?php if ($showUpload): ?>
<script>
(function(){
  var dz = document.getElementById('dropzone'),
      input = document.getElementById('fileInput'),
      note = document.getElementById('pickedNote');
  ['dragenter','dragover'].forEach(function(ev){
    dz.addEventListener(ev, function(e){ e.preventDefault(); dz.classList.add('drag'); });
  });
  ['dragleave','drop'].forEach(function(ev){
    dz.addEventListener(ev, function(e){ e.preventDefault(); dz.classList.remove('drag'); });
  });
  dz.addEventListener('drop', function(e){
    if (e.dataTransfer && e.dataTransfer.files.length){
      input.files = e.dataTransfer.files;
      showPicked();
    }
  });
  input.addEventListener('change', showPicked);
  function showPicked(){
    var n = input.files.length;
    note.textContent = n ? n + (n===1?' file':' files') + ' ready — click "Upload selected files"' : '';
  }
})();
</script>
<?php endif; ?>
</body>
</html>
