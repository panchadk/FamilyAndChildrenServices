<?php
require_once __DIR__ . '/includes/auth.php';
$user = require_login();

$id = (int)($_GET['id'] ?? 0);
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
$canEdit = $acc['edit'];
$flash   = $_SESSION['flash'] ?? '';
unset($_SESSION['flash']);

$ext    = strtolower($doc['file_ext']);
$bucket = ext_bucket($ext);
$fileUrl = 'download.php?id=' . (int)$doc['id'] . '&view=1';
$rawUrl  = 'download.php?id=' . (int)$doc['id'] . '&raw=1';

// which rendering mode?
$mode = 'none';
if ($ext === 'pdf')                                    $mode = 'pdf';
elseif (in_array($ext, ['png','jpg','jpeg','gif','webp'])) $mode = 'image';
elseif ($ext === 'docx')                               $mode = 'docx';
elseif (in_array($ext, ['xlsx','csv']))                $mode = 'sheet';
elseif ($ext === 'txt')                                $mode = 'text';

log_activity($user['id'], 'view', $doc['display_name']);

$initials = strtoupper(mb_substr($user['name'], 0, 1) .
            (strpos($user['name'], ' ') !== false
              ? mb_substr($user['name'], strpos($user['name'], ' ') + 1, 1) : ''));
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= e($doc['display_name']) ?> — FCS DocHub</title>
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
    <div class="viewer-head">
      <div>
        <p class="crumb"><a href="dashboard.php?folder=<?= (int)$doc['folder_id'] ?>">← <?= e($doc['folder_name']) ?></a></p>
        <h2 class="doc-name">
          <span class="ficon f-<?= $bucket ?>"><?= e(strtoupper($ext)) ?></span>
          <?= e($doc['display_name']) ?>
        </h2>
        <div class="sub"><?= e($doc['owner_name']) ?> · <?= date('M d, Y H:i', strtotime($doc['updated_at'])) ?> · <?= human_size((int)$doc['size_bytes']) ?></div>
      </div>
      <div class="row-actions" style="align-items:center;flex-wrap:wrap">
        <?php if ($canEdit && in_array($ext, ['txt','csv'], true)): ?>
          <a class="btn btn-blue btn-sm" href="edit.php?id=<?= (int)$doc['id'] ?>">Edit</a>
        <?php endif; ?>
        <?php if ($canEdit): ?>
          <form method="post" action="replace.php" enctype="multipart/form-data" class="inline-form" id="replaceForm">
            <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
            <input type="hidden" name="id" value="<?= (int)$doc['id'] ?>">
            <label class="btn btn-ghost btn-sm replace-label">Upload new version
              <input type="file" name="file" accept=".<?= e($ext) ?>" id="replaceInput" hidden>
            </label>
          </form>
        <?php endif; ?>
        <a class="btn btn-ghost btn-sm" href="versions.php?id=<?= (int)$doc['id'] ?>">History</a>
        <a class="btn btn-blue btn-sm" href="download.php?id=<?= (int)$doc['id'] ?>">Download</a>
      </div>
    </div>

    <?php if ($flash): ?>
      <div class="perm-note editor" role="status"><?= e($flash) ?></div>
    <?php endif; ?>

    <div class="viewer-stage" id="stage">
      <?php if ($mode === 'pdf'): ?>
        <iframe class="viewer-frame" src="<?= e($fileUrl) ?>" title="<?= e($doc['display_name']) ?>"></iframe>

      <?php elseif ($mode === 'image'): ?>
        <div class="viewer-pad viewer-center">
          <img class="viewer-img" src="<?= e($fileUrl) ?>" alt="<?= e($doc['display_name']) ?>">
        </div>

      <?php elseif ($mode === 'docx'): ?>
        <div class="viewer-pad" id="docxContainer"><p class="viewer-loading">Loading document…</p></div>

      <?php elseif ($mode === 'sheet'): ?>
        <div class="sheet-tabs" id="sheetTabs"></div>
        <div class="viewer-pad sheet-wrap" id="sheetContainer"><p class="viewer-loading">Loading spreadsheet…</p></div>

      <?php elseif ($mode === 'text'): ?>
        <div class="viewer-pad"><pre class="viewer-pre" id="textContainer">Loading…</pre></div>

      <?php else: ?>
        <div class="viewer-pad viewer-center">
          <div class="viewer-fallback">
            <span class="ficon f-<?= $bucket ?>" style="width:52px;height:52px;font-size:.85rem;margin:0 auto 14px"><?= e(strtoupper($ext)) ?></span>
            <p><strong>.<?= e($ext) ?></strong> files can't be previewed in the browser.</p>
            <p class="meta">Download it to open in the matching application.</p>
            <a class="btn btn-blue" style="margin-top:14px" href="download.php?id=<?= (int)$doc['id'] ?>">Download <?= e($doc['display_name']) ?></a>
          </div>
        </div>
      <?php endif; ?>
    </div>
  </main>
</div>

<?php if ($canEdit): ?>
<script>
(function(){
  var inp = document.getElementById('replaceInput');
  if (inp) inp.addEventListener('change', function(){
    if (this.files.length && confirm('Replace the current file with "' + this.files[0].name + '"? The current copy will be kept in history.')){
      document.getElementById('replaceForm').submit();
    } else {
      this.value = '';
    }
  });
})();
</script>
<?php endif; ?>
<?php if ($mode === 'docx'): ?>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/docx-preview/0.3.2/docx-preview.min.js"></script>
<script>
fetch('<?= e($rawUrl) ?>', {credentials:'same-origin'})
  .then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.blob(); })
  .then(function(blob){
    var c = document.getElementById('docxContainer');
    c.innerHTML = '';
    return docx.renderAsync(blob, c, null, {inWrapper:true, ignoreWidth:false});
  })
  .catch(function(err){
    document.getElementById('docxContainer').innerHTML =
      '<div class="viewer-fallback"><p>Preview couldn\'t be generated ('+err.message+').</p>' +
      '<a class="btn btn-blue" style="margin-top:12px" href="download.php?id=<?= (int)$doc['id'] ?>">Download instead</a></div>';
  });
</script>
<?php elseif ($mode === 'sheet'): ?>
<script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>
<script>
fetch('<?= e($rawUrl) ?>', {credentials:'same-origin'})
  .then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.arrayBuffer(); })
  .then(function(buf){
    var wb = XLSX.read(buf, {type:'array'});
    var tabs = document.getElementById('sheetTabs');
    var wrap = document.getElementById('sheetContainer');
    function show(name){
      wrap.innerHTML = XLSX.utils.sheet_to_html(wb.Sheets[name], {header:'', footer:''});
      var t = wrap.querySelector('table'); if (t) t.className = 'sheet-table';
      Array.prototype.forEach.call(tabs.children, function(b){
        b.classList.toggle('active', b.textContent === name);
      });
    }
    if (wb.SheetNames.length > 1){
      wb.SheetNames.forEach(function(name){
        var b = document.createElement('button');
        b.type = 'button'; b.className = 'sheet-tab'; b.textContent = name;
        b.onclick = function(){ show(name); };
        tabs.appendChild(b);
      });
    }
    show(wb.SheetNames[0]);
  })
  .catch(function(err){
    document.getElementById('sheetContainer').innerHTML =
      '<div class="viewer-fallback"><p>Preview couldn\'t be generated ('+err.message+').</p>' +
      '<a class="btn btn-blue" style="margin-top:12px" href="download.php?id=<?= (int)$doc['id'] ?>">Download instead</a></div>';
  });
</script>
<?php elseif ($mode === 'text'): ?>
<script>
fetch('<?= e($rawUrl) ?>', {credentials:'same-origin'})
  .then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.text(); })
  .then(function(t){ document.getElementById('textContainer').textContent = t.slice(0, 500000); })
  .catch(function(){ document.getElementById('textContainer').textContent = 'Preview unavailable — use Download.'; });
</script>
<?php endif; ?>
</body>
</html>
