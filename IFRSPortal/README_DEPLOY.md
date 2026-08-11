# IFRS Archive Portal - Deployment

## 1. Database (run once, SSMS on IFRSArchive)
Run `portal_db_setup.sql`:
- creates dbo.PortalAudit
- builds dbo.vw_CaseSpine dynamically over every vw_All_* view that has CaseNumber

NOTE: PortalAudit requires the database to be WRITABLE. Keep IFRSArchive
READ_WRITE (the app account only gets INSERT on PortalAudit + SELECT elsewhere),
or place PortalAudit in a small separate database and adjust Portal.Audit's
connection - decide before setting the archive READ_ONLY.

## 2. IIS site
- Copy this folder to e.g. D:\Sites\IFRSPortal on the web server.
- IIS: New website (or app under Default Web Site), physical path above,
  .NET CLR v4.0 integrated app pool.
- Authentication: enable Windows Authentication, disable Anonymous.
- App pool identity: a domain account (e.g. GUELPH\svc-ifrsportal).

## 3. Permissions
- SQL (IFRSArchive): create a login for the app pool account, grant
  db_datareader + INSERT on dbo.PortalAudit.
- Attachments share: grant the app pool account READ on
  \\...\notes\attachments (users get NO direct access).

## 4. web.config
- Verify the connection string (Server=SQL5, remove ApplicationIntent if
  not using availability groups).
- Set AttachmentsBase to the share UNC.
- Set AdminGroup to the AD group for Audit.aspx.
- Optional: uncomment the role-based <authorization> to restrict all
  access to an IFRS-Archive-Users group.

## 5. Smoke test
- Browse the site as yourself: search a known case (e.g. 13997), open the
  case page, open a document, check the provenance footer.
- Audit.aspx (as an admin-group member): confirm your own accesses logged.

## Pages
Default.aspx (case search) / Case.aspx / Doc.aspx / Person.aspx /
Attachment.ashx (streaming, audited) / Audit.aspx (admin only)
