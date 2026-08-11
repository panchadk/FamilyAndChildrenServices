/* =====================================================================
   ScanDoc - Document Scanning Portal schema
   Server : SQL5
   Pattern: mirrors VaultArchive / LANFAM (pointer table, staged ETL,
            Windows Auth, field-level audit)
   Share  : \\manage-srv\scanned_files\Children
   Folder : {caseref}_{firstname}_{lastname}
   File   : {caseref}_{firstname}_{lastname}_{doctype}.pdf
   ===================================================================== */

IF DB_ID('ScanArchive') IS NULL
BEGIN
    CREATE DATABASE ScanArchive;
END
GO

USE ScanArchive;
GO

IF SCHEMA_ID('scan') IS NULL EXEC('CREATE SCHEMA scan;');
GO

/* ---------------------------------------------------------------------
   Config - single row holding the share root so the tables store only
   relative paths (archive stays portable if the share moves).
   --------------------------------------------------------------------- */
IF OBJECT_ID('scan.ScanConfig') IS NULL
BEGIN
    CREATE TABLE scan.ScanConfig (
        ConfigID   INT IDENTITY(1,1) PRIMARY KEY,
        ShareRoot  NVARCHAR(400) NOT NULL,   -- \\manage-srv\scanned_files\Children
        UpdatedUtc DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
    );
    INSERT INTO scan.ScanConfig (ShareRoot)
    VALUES (N'\\manage-srv\scanned_files\Children');
END
GO

/* ---------------------------------------------------------------------
   Case - one row per folder (one person). Base ref + suffix preserved.
   --------------------------------------------------------------------- */
IF OBJECT_ID('scan.ScanCase') IS NULL
BEGIN
    CREATE TABLE scan.ScanCase (
        CaseID       INT IDENTITY(1,1) PRIMARY KEY,
        CaseRef      NVARCHAR(40)  NOT NULL,   -- full ref incl. suffix, e.g. 12043a
        CaseRefBase  NVARCHAR(40)  NOT NULL,   -- numeric portion, e.g. 12043
        CaseRefSuffix NVARCHAR(8)  NULL,       -- alpha suffix, e.g. a
        FirstName    NVARCHAR(120) NULL,
        LastName     NVARCHAR(160) NULL,
        FolderName   NVARCHAR(300) NOT NULL,   -- raw folder name as on disk
        RelativePath NVARCHAR(400) NOT NULL,   -- relative to ShareRoot
        DocCount     INT           NOT NULL DEFAULT 0,
        FolderDate   DATETIME2     NULL,       -- folder LastWriteTime
        CreatedUtc   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_ScanCase_Folder UNIQUE (RelativePath)
    );
    CREATE INDEX IX_ScanCase_CaseRef   ON scan.ScanCase (CaseRef);
    CREATE INDEX IX_ScanCase_RefBase   ON scan.ScanCase (CaseRefBase);
    CREATE INDEX IX_ScanCase_LastName  ON scan.ScanCase (LastName);
    CREATE INDEX IX_ScanCase_FirstName ON scan.ScanCase (FirstName);
END
GO

/* ---------------------------------------------------------------------
   Document - one row per PDF inside a folder.
   --------------------------------------------------------------------- */
IF OBJECT_ID('scan.ScanDocument') IS NULL
BEGIN
    CREATE TABLE scan.ScanDocument (
        DocID        INT IDENTITY(1,1) PRIMARY KEY,
        CaseID       INT           NOT NULL
            CONSTRAINT FK_ScanDocument_Case REFERENCES scan.ScanCase(CaseID),
        FileName     NVARCHAR(300) NOT NULL,
        RelativePath NVARCHAR(500) NOT NULL,   -- relative to ShareRoot
        DocType      NVARCHAR(120) NULL,       -- parsed doctype token; 'master' if none
        FileSizeBytes BIGINT       NULL,
        FileDate     DATETIME2     NULL,       -- file LastWriteTime
        CreatedUtc   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_ScanDocument_Path UNIQUE (RelativePath)
    );
    CREATE INDEX IX_ScanDocument_CaseID  ON scan.ScanDocument (CaseID);
    CREATE INDEX IX_ScanDocument_DocType ON scan.ScanDocument (DocType);
END
GO

/* ---------------------------------------------------------------------
   Audit - field-level access log (who opened / searched what).
   --------------------------------------------------------------------- */
IF OBJECT_ID('scan.ScanAudit') IS NULL
BEGIN
    CREATE TABLE scan.ScanAudit (
        AuditID    BIGINT IDENTITY(1,1) PRIMARY KEY,
        UserName   NVARCHAR(200) NOT NULL,   -- domain user (Windows Auth)
        Action     NVARCHAR(40)  NOT NULL,   -- SEARCH | VIEW | STREAM
        CaseID     INT           NULL,
        DocID      INT           NULL,
        Detail     NVARCHAR(500) NULL,       -- search term or filename
        ClientIP   NVARCHAR(60)  NULL,
        CreatedUtc DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_ScanAudit_User ON scan.ScanAudit (UserName);
    CREATE INDEX IX_ScanAudit_Date ON scan.ScanAudit (CreatedUtc);
END
GO

/* ---------------------------------------------------------------------
   Staging - PowerShell bulk loads here; merge proc upserts into live.
   --------------------------------------------------------------------- */
IF OBJECT_ID('scan.ScanStaging') IS NULL
BEGIN
    CREATE TABLE scan.ScanStaging (
        FolderName    NVARCHAR(300) NOT NULL,
        FolderRelPath NVARCHAR(400) NOT NULL,
        FolderDate    DATETIME2     NULL,
        CaseRef       NVARCHAR(40)  NULL,
        CaseRefBase   NVARCHAR(40)  NULL,
        CaseRefSuffix NVARCHAR(8)   NULL,
        FirstName     NVARCHAR(120) NULL,
        LastName      NVARCHAR(160) NULL,
        FileName      NVARCHAR(300) NULL,
        FileRelPath   NVARCHAR(500) NULL,
        DocType       NVARCHAR(120) NULL,
        FileSizeBytes BIGINT        NULL,
        FileDate      DATETIME2     NULL
    );
END
GO

/* =====================================================================
   usp_MergeScanStaging - upsert cases then documents, recompute counts.
   Idempotent: safe to re-run after every bulk load.
   ===================================================================== */
IF OBJECT_ID('scan.usp_MergeScanStaging') IS NOT NULL
    DROP PROCEDURE scan.usp_MergeScanStaging;
GO

CREATE PROCEDURE scan.usp_MergeScanStaging
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    /* ---- 1. Upsert cases (one distinct folder per row) ---- */
    ;WITH src AS (
        SELECT DISTINCT
               FolderName, FolderRelPath, FolderDate,
               CaseRef, CaseRefBase, CaseRefSuffix, FirstName, LastName
        FROM scan.ScanStaging
    )
    MERGE scan.ScanCase AS tgt
    USING src
       ON tgt.RelativePath = src.FolderRelPath
    WHEN MATCHED THEN
        UPDATE SET tgt.CaseRef       = src.CaseRef,
                   tgt.CaseRefBase   = src.CaseRefBase,
                   tgt.CaseRefSuffix = src.CaseRefSuffix,
                   tgt.FirstName     = src.FirstName,
                   tgt.LastName      = src.LastName,
                   tgt.FolderName    = src.FolderName,
                   tgt.FolderDate    = src.FolderDate
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CaseRef, CaseRefBase, CaseRefSuffix, FirstName, LastName,
                FolderName, RelativePath, FolderDate)
        VALUES (src.CaseRef, src.CaseRefBase, src.CaseRefSuffix,
                src.FirstName, src.LastName, src.FolderName,
                src.FolderRelPath, src.FolderDate);

    /* ---- 2. Upsert documents (join back to case) ---- */
    ;WITH srcDoc AS (
        SELECT s.FileRelPath, s.FileName, s.DocType,
               s.FileSizeBytes, s.FileDate, c.CaseID
        FROM scan.ScanStaging s
        JOIN scan.ScanCase   c ON c.RelativePath = s.FolderRelPath
        WHERE s.FileName IS NOT NULL
    )
    MERGE scan.ScanDocument AS tgt
    USING srcDoc AS src
       ON tgt.RelativePath = src.FileRelPath
    WHEN MATCHED THEN
        UPDATE SET tgt.FileName      = src.FileName,
                   tgt.DocType       = src.DocType,
                   tgt.FileSizeBytes = src.FileSizeBytes,
                   tgt.FileDate      = src.FileDate,
                   tgt.CaseID        = src.CaseID
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CaseID, FileName, RelativePath, DocType, FileSizeBytes, FileDate)
        VALUES (src.CaseID, src.FileName, src.FileRelPath,
                src.DocType, src.FileSizeBytes, src.FileDate);

    /* ---- 3. Recompute doc counts ---- */
    UPDATE c
       SET c.DocCount = x.Cnt
    FROM scan.ScanCase c
    JOIN (SELECT CaseID, COUNT(*) AS Cnt
          FROM scan.ScanDocument GROUP BY CaseID) x
      ON x.CaseID = c.CaseID;

    COMMIT TRAN;

    SELECT
        (SELECT COUNT(*) FROM scan.ScanCase)     AS TotalCases,
        (SELECT COUNT(*) FROM scan.ScanDocument) AS TotalDocuments;
END
GO
