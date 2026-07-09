# FCS DocHub — PHP/MySQL Document Manager

Role-based document management portal for Family & Children's Services of
Guelph and Wellington County. Plain PHP 8 + MySQL — no framework, no
Composer dependencies — built to run on GreenGeeks shared hosting.

## Features

- Login with bcrypt-hashed passwords, session hardening, CSRF protection
- Three roles enforced **server-side**:
  - **Admin** — everything (user management is the natural next build)
  - **Editor** — upload, rename, delete, view, download
  - **Viewer** — view and download only
- Folder organization (Policies, Forms, HR, Board documents, Images)
- Drag-and-drop multi-file upload with extension **and** real MIME-type
  validation (finfo), 50 MB per-file limit
- Files stored under random names in a folder blocked by `.htaccess`;
  all downloads stream through `download.php` after a permission check
- Search by document name
- `activity_log` audit trail (login, upload, download, rename, delete)

## File map

```
dochub/
├── index.php            Login page (home)
├── dashboard.php        Document manager UI
├── upload.php           Upload handler (editors only)
├── download.php         Secure view/download (all signed-in users)
├── rename.php           Rename handler (editors only)
├── delete.php           Delete handler (editors only)
├── logout.php
├── setup.php            One-time account creation — DELETE after use
├── database.sql         Schema — import in phpMyAdmin
├── assets/style.css
├── includes/
│   ├── config.php       DB credentials — EDIT THIS
│   ├── auth.php         Session/role/CSRF helpers
│   └── .htaccess        Blocks direct access
└── storage/
    └── .htaccess        Blocks direct access to uploaded files
```

## Deploying on GreenGeeks

1. **Subdomain** — cPanel → Domains → Create a New Domain →
   `docs.fcsgw.org`, document root e.g. `public_html/dochub`.

2. **Database** — cPanel → MySQL Database Wizard:
   create database (e.g. `youruser_dochub`), a user, and grant
   **ALL PRIVILEGES**. Note all three values.

3. **Import schema** — cPanel → phpMyAdmin → select the new database →
   Import → `database.sql`.

4. **Upload files** — File Manager or FTP: put everything in this folder
   into the subdomain's document root.

5. **Configure** — edit `includes/config.php` with the DB name, user,
   and password from step 2.

6. **Initialize accounts** — browse to `https://docs.fcsgw.org/setup.php`
   once. It creates:
   | Account | Role | Password |
   |---|---|---|
   | admin@fcsgw.org | admin | ChangeMe!2026 |
   | editor@fcsgw.org | editor | ChangeMe!2026 |
   | viewer@fcsgw.org | viewer | ChangeMe!2026 |

7. **Delete `setup.php`** from the server. Sign in and change the
   passwords (until a password-change UI exists, update via phpMyAdmin:
   generate a hash with `password_hash('NewPass', PASSWORD_DEFAULT)`).

8. **SSL** — AutoSSL usually covers the new subdomain within the hour;
   if not, cPanel → SSL/TLS Status → Run AutoSSL.

9. **PHP version** — cPanel → Select PHP Version → PHP 8.1+
   (code uses `str_starts_with` / `str_ends_with`).

10. **Upload limits** — cPanel → Select PHP Version → Options: set
    `upload_max_filesize` and `post_max_size` to at least `50M`
    (post_max_size should be larger, e.g. `64M`, for multi-file uploads).

## Managing users

Sign in as an admin → **Users** in the top navigation:

- Add accounts (name, email, role, initial password)
- Change roles with the inline dropdown
- Reset passwords — a readable temporary password is generated and
  shown once on screen (share it securely; user changes it under
  **My account**)
- Deactivate / reactivate — blocks sign-in but keeps the person's
  uploads and audit history; accounts are never hard-deleted
- Safety rails: you can't deactivate yourself or demote/deactivate
  the last active admin

Every user can change their own password under **My account**
(`profile.php`).

## Sensible next steps
- Per-folder permissions (folder_permissions join table)
- Document version history (keep replaced files, show revisions)
- "My uploads" filter and bulk download (zip)
- Email notification on upload to a folder
