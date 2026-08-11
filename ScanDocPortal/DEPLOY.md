# ScanDoc — Deployment

Read-only portal indexing scanned PDFs on `\\manage-srv\scanned_files\Children`.
Same pattern as VaultPortal / LANFAM (SQL5, IIS, Windows Auth, staged ETL).

## Run order

1. **SQL** — run `sql/01_ScanDoc_Schema.sql` on SQL5. Creates the
   `ScanArchive` DB, `scan` schema, tables, and `usp_MergeScanStaging`.
   The `ScanConfig` row is seeded with the share root — edit it there if
   the share ever moves (portal reads it at runtime, no redeploy needed).

2. **Bulk load** — run `powershell/Load-ScanDocs.ps1` from a box whose
   account can both read the share and reach SQL5:
   ```powershell
   .\Load-ScanDocs.ps1
   ```
   It stages every folder + PDF, then calls the merge proc. Re-run any
   time to pick up new scans — it's an idempotent upsert. Schedule it as
   a nightly task if you want it hands-off.

3. **Portal** — copy the four portal files + `Web.config` into a new IIS
   app folder (e.g. `C:\inetpub\scandoc`). CodeFile model, so **no build
   step** — just drop the files.

## pdf.js

Download the pdf.js "prebuilt" release and drop it so the path is:
```
<portal>\pdfjs\web\viewer.html
```
`Viewer.aspx` points the iframe at `pdfjs/web/viewer.html?file=Stream.ashx?doc=<id>`.
The PDF is delivered through `Stream.ashx` server-side — the client never
receives a raw UNC path, and the app-pool identity is the only account
that touches the share.

## IIS

- App pool identity must have **read** on `\\manage-srv\scanned_files\Children`.
  Use a domain service account (same approach as `GUELPH\svc-lanfamportal`).
- Windows Authentication **on**, Anonymous **off** (already set in `Web.config`).
- If pdf.js `.mjs`/`.wasm` files 404, add the MIME mappings in IIS.

## Files

| Path | Purpose |
|------|---------|
| `sql/01_ScanDoc_Schema.sql` | DB, tables, merge proc |
| `powershell/Load-ScanDocs.ps1` | Walk share → staging → merge |
| `portal/Default.aspx(.cs)` | Search + stat tiles + doc links |
| `portal/Viewer.aspx(.cs)` | pdf.js viewer window |
| `portal/Stream.ashx` | Secure server-side PDF streaming |
| `portal/Web.config` | Conn string + Windows Auth |

## Name parsing notes

Folder pattern `{caseref}_{firstname}_{lastname}`. Parser splits on the
first two underscores, so hyphenated first names (`gerri-gail`) and
apostrophe surnames (`d'allaire`) survive intact. Case ref keeps its
alpha suffix (`12043a`) as-is; the numeric base (`12043`) is stored
separately so a search on `12043` finds all of `12043a/b/c/d`.
