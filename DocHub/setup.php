<?php
/**
 * FCS DocHub — one-time setup
 * ---------------------------------------------------------
 * 1. Create the database + user in cPanel (MySQL Database Wizard)
 * 2. Import database.sql via phpMyAdmin
 * 3. Edit includes/config.php with your DB credentials
 * 4. Browse to this file ONCE:  https://docs.fcsgw.org/setup.php
 * 5. DELETE this file from the server immediately afterwards
 * ---------------------------------------------------------
 */
require_once __DIR__ . '/includes/config.php';

header('Content-Type: text/plain; charset=utf-8');

// Refuse to run if users already exist
$count = (int)db()->query('SELECT COUNT(*) FROM users')->fetchColumn();
if ($count > 0) {
    exit("Setup already completed ($count user(s) exist). Delete setup.php now.\n");
}

$defaultPass = 'ChangeMe!2026';
$hash = password_hash($defaultPass, PASSWORD_DEFAULT);

$accounts = [
    ['admin@fcsgw.org',  'System Administrator', 'admin'],
    ['editor@fcsgw.org', 'Sample Editor',        'editor'],
    ['viewer@fcsgw.org', 'Sample Viewer',        'viewer'],
];

$ins = db()->prepare('INSERT INTO users (email, password_hash, full_name, role) VALUES (?,?,?,?)');
foreach ($accounts as [$email, $name, $role]) {
    $ins->execute([$email, $hash, $name, $role]);
    echo "Created $role account: $email\n";
}

// Make sure the storage folder exists
if (!is_dir(STORAGE_DIR)) {
    mkdir(STORAGE_DIR, 0755, true);
    echo "Created storage directory.\n";
}

echo "\nAll three accounts use the password: $defaultPass\n";
echo "1) Sign in as admin@fcsgw.org and change every password.\n";
echo "2) DELETE setup.php from the server NOW.\n";
