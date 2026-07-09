<?php
/**
 * FCS DocHub — configuration
 * Edit the four DB_* values to match the database you create in
 * cPanel → MySQL Database Wizard.
 */

// ---------- Database ----------
define('DB_HOST', 'localhost');
define('DB_NAME', 'irankalc_dochub');      // e.g. fcsgw_dochub
define('DB_USER', 'irankalc_dochubusr');   // cPanel-created MySQL user
define('DB_PASS', 'Manithan12#$');

// ---------- Uploads ----------
// Files are stored OUTSIDE the web-accessible docroot when possible.
// On GreenGeeks, if this app lives at public_html/dochub, this path
// resolves to a "storage" folder next to the app that is protected
// by the included .htaccess (deny all). Downloads are streamed
// through download.php after a permission check.
define('STORAGE_DIR', __DIR__ . '/../storage');

define('MAX_UPLOAD_BYTES', 50 * 1024 * 1024); // 50 MB


// ---------- Email notifications ----------
define('APP_URL',     'https://fcsgw.irankal.com');   // no trailing slash
define('NOTIFY_FROM', 'dochub@irankal.com');         // must be a domain your host allows
define('NOTIFY_ENABLED', true);											
// Allowed file types: extension => accepted MIME prefixes
const ALLOWED_TYPES = [
    'pdf'  => ['application/pdf'],
    'doc'  => ['application/msword'],
    'docx' => ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    'xls'  => ['application/vnd.ms-excel'],
    'xlsx' => ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    'ppt'  => ['application/vnd.ms-powerpoint'],
    'pptx' => ['application/vnd.openxmlformats-officedocument.presentationml.presentation'],
    'csv'  => ['text/csv', 'text/plain', 'application/csv'],
    'txt'  => ['text/plain'],
    'png'  => ['image/png'],
    'jpg'  => ['image/jpeg'],
    'jpeg' => ['image/jpeg'],
    'gif'  => ['image/gif'],
    'webp' => ['image/webp'],
];

// ---------- Sessions ----------
ini_set('session.cookie_httponly', '1');
ini_set('session.use_strict_mode', '1');
if (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') {
    ini_set('session.cookie_secure', '1');
}
session_name('FCSDOCHUB');
session_start();

// ---------- PDO connection ----------
function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]
        );
    }
    return $pdo;
}
