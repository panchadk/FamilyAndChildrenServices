LANFAM ARCHIVE PORTAL - DEPLOYMENT
===================================
ASP.NET Web Forms, .NET Framework 4.8, no build step.
IIS compiles the pages on first request (like PHP: copy files, run).

WHAT'S IN THIS FOLDER
  web.config       auth, authorization groups, connection string
  App_Code/Db.cs   shared helpers (DB, audit, code decode)
  Site.master      page layout
  Styles.css       styling
  Default.aspx     search (name / case no / family no)
  Child.aspx       child master + placement history + costs
  Family.aspx      family history + referrals with narratives
  setup.sql        audit table + SQL permissions (run once in SSMS)

DEPLOY - 6 STEPS
  1. Copy this folder to the web server, e.g. C:\inetpub\LanfamPortal

  2. IIS features (Server Manager > Add Roles if missing):
     Web Server > Security > Windows Authentication
     Web Server > Application Development > ASP.NET 4.8

  3. IIS Manager:
     - Application Pools > Add: name "LanfamPortal",
       .NET CLR v4.0, Integrated pipeline.
     - Right-click a site (or Default Web Site) > Add Application:
       alias "lanfam", pool "LanfamPortal",
       physical path C:\inetpub\LanfamPortal.
     - Select the app > Authentication:
       DISABLE Anonymous, ENABLE Windows Authentication.

  4. Edit web.config:
     - connectionStrings: set Server= to your SQL Server instance.
     - appSettings ReadersGroup / AdoptionGroup: your AD group names.
     - AllowAllAuthenticated=true lets any signed-in domain user
       test the portal; set to false once the AD groups exist.

  5. Run setup.sql in SSMS (creates lanfam.AccessLog and grants the
     app pool SELECT-only access + INSERT on the audit table).
     If SQL Server is on a different machine than IIS, run the app
     pool as a domain service account and grant that account
     instead - see the comments in setup.sql.

  6. Browse to http://server/lanfam - your domain login appears top
     right, search something, then check:
     SELECT TOP 20 * FROM lanfam.AccessLog ORDER BY 1 DESC;

HTTPS: bind the *.fcsgw.org wildcard cert on the site's 443 binding
(IIS Manager > site > Bindings > Add https) and browse via a name
covered by the cert, e.g. https://lanfam.fcsgw.org.

NOTES
  - The portal is strictly read-only by construction: the SQL
    principal can only SELECT (plus INSERT to the audit log).
  - Every search and record view is written to lanfam.AccessLog
    with AD username, IP, and timestamp.
  - Edits to .aspx/.cs files take effect on next request -
    no compilation or app restart needed.

V2 UPGRADE (drop-in file replacement, no IIS changes needed)
  New: Browse.aspx (A-Z paged), Resource.aspx (homes + placements),
  Worker.aspx (roster + caseloads), Codes.aspx (code book),
  tables.js (click headers to sort, filter boxes above tables),
  quick search bar in the header on every page, stat tiles,
  placement timeline on the child page, drill-down links everywhere.
  To apply: overwrite the folder contents; next page request picks
  it up automatically.
