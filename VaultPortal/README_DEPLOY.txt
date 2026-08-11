VAULT REGISTER PORTAL - DEPLOYMENT
===================================
ASP.NET Web Forms, .NET Framework 4.8, CodeFile model - NO BUILD STEP.
Copy the folder; IIS compiles pages on first request. Same model as the
LANFAM and IFRS portals: later fixes deploy by copying .aspx/.cs files,
no IIS restart needed.

WHAT'S IN THIS FOLDER
  web.config          auth, connection string, editors group setting
  Styles.css          portal styling
  Site.master(.cs)    shared layout (top bar, nav, footer)
  Default.aspx(.cs)   search front door: stats, quick search + autocomplete,
                      multi-field search, A-Z browse, sortable results
  Record.aspx(.cs)    full record detail; edit gated by AD group; every
                      save audited with a field-level before/after diff
  Suggest.ashx        autocomplete endpoint (file numbers + surnames)
  App_Code/Db.cs      shared helpers (connection, audit, role check)
  setup.sql           audit table + SQL permissions (run once in SSMS)

DEPLOY - 6 STEPS
  1. Copy this folder to the web server, e.g. C:\inetpub\VaultPortal

  2. IIS Manager:
     - Application Pools > Add: name "VaultPortal", .NET CLR v4.0,
       Integrated pipeline.
     - Identity: a domain service account (e.g. GUELPH\svc-vaultportal),
       because SQL Server is on a different machine (SQL5) - same pattern
       as svc-lanfamportal.
     - Add Website (host header vault.fcsgw.org, HTTPS with the *.fcsgw.org
       wildcard cert) OR Add Application under an existing site, alias
       "vault", pool "VaultPortal", physical path from step 1.
     - Select the site/app > Authentication:
       ENABLE Windows Authentication, DISABLE Anonymous.

  3. Run setup.sql in SSMS on SQL5 (edit the @acct name first).
     Creates dbo.VaultAccessLog and grants the service account
     SELECT+UPDATE on ArchiveHoldings and INSERT on the log.

  4. Edit web.config:
     - EditorsGroup: the AD group allowed to edit (create e.g.
       "Vault-Editors" in AD and add the vault staff).
     - AllowAllAuthenticatedEdit: leave "true" while testing;
       set "false" for go-live so only the group can edit.

  5. Smoke test from a workstation (not from the server itself -
     loopback check will block the host header there):
     - Page loads with your DOMAIN\name in the top bar.
     - Stats tiles show live counts.
     - Quick search "282" suggests file numbers; pick one, open the
       record, check the IN VAULT / SIGNED OUT stamp.
     - Edit a harmless field, save, then in SSMS:
       SELECT TOP 5 * FROM dbo.VaultAccessLog ORDER BY 1 DESC
       - confirm the Edit row shows the before -> after diff.

  6. Go-live: set AllowAllAuthenticatedEdit=false, optionally enable the
     commented role-based <authorization> block to restrict all access
     to a Vault-Users group.

TESTING IN VISUAL STUDIO (before the server)
  This folder is a Web Site (CodeFile), not a Web Application project:
  - File > Open > Web Site > File System > select this folder. Run it.
  - IIS Express: select the project, press F4, set
    Windows Authentication = Enabled, Anonymous = Disabled
    (same fix as before - the 401.2 you hit was exactly this).
  - Under VS, the SQL connection runs as YOU, so it works with your own
    SQL5 access. On the server it runs as the app pool account - that is
    what setup.sql provisions.

NOTES
  - The old single-page Archive.aspx is superseded by Default.aspx +
    Record.aspx; don't copy it to the server.
  - Holdings column letters: P paper, A audio, V video, C cd/dvd,
    M microfiche, W working file.
  - StartDate/EndDate are only reliable from the March 2022 SharePoint
    bulk load onward; ModifiedOldVdb (Provenance section) is the
    historically accurate activity date back to 2009.
