/* =====================================================================
   VAULT REGISTER PORTAL - one-time database setup (run in SSMS on SQL5)
   Database: VaultArchive     Table: dbo.ArchiveHoldings
   ===================================================================== */
USE VaultArchive;
GO

/* 1. Access log: every Search, View, and Edit (with field-level diff). */
IF OBJECT_ID('dbo.VaultAccessLog') IS NULL
BEGIN
    CREATE TABLE dbo.VaultAccessLog
    (
        VaultAccessLogID  int IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_VaultAccessLog PRIMARY KEY,
        LoggedAt          datetime2(0) NOT NULL
            CONSTRAINT DF_VaultAccessLog_LoggedAt DEFAULT SYSDATETIME(),
        LoginName         nvarchar(128) NOT NULL,
        Action            varchar(20)   NOT NULL,   -- Search / View / Edit
        SPListItemID      int           NULL,       -- record touched (View/Edit)
        Detail            nvarchar(4000) NULL,      -- search criteria or edit diff
        ClientIP          varchar(45)   NULL
    );
    CREATE INDEX IX_VaultAccessLog_When   ON dbo.VaultAccessLog (LoggedAt DESC);
    CREATE INDEX IX_VaultAccessLog_Record ON dbo.VaultAccessLog (SPListItemID)
        WHERE SPListItemID IS NOT NULL;
END
GO

/* 2. Portal service account.
      IIS and SQL5 are different machines, so use a DOMAIN service account
      running the app pool (same pattern as svc-lanfamportal). Adjust the
      name to whatever account you create. */
DECLARE @acct sysname = N'GUELPH\svc-vaultportal';   -- <<< ADJUST

DECLARE @sql nvarchar(max);
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @acct)
BEGIN
    SET @sql = N'CREATE LOGIN ' + QUOTENAME(@acct) + N' FROM WINDOWS;';
    EXEC (@sql);
END
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @acct)
BEGIN
    SET @sql = N'CREATE USER ' + QUOTENAME(@acct) +
               N' FOR LOGIN ' + QUOTENAME(@acct) + N';';
    EXEC (@sql);
END

/* 3. Least privilege:
      - read the register
      - update it (the portal enforces WHO may edit via the AD editors group;
        SQL grants the app account the ability to carry those edits out)
      - append to the audit log (no read: reviews are done by you in SSMS) */
SET @sql = N'GRANT SELECT, UPDATE ON dbo.ArchiveHoldings TO ' + QUOTENAME(@acct) + N';'
         + N'GRANT INSERT ON dbo.VaultAccessLog TO ' + QUOTENAME(@acct) + N';';
EXEC (@sql);
GO

/* ---------------------------------------------------------------------
   4. Audit review queries (for you, not the portal)

-- latest activity
SELECT TOP 100 * FROM dbo.VaultAccessLog ORDER BY VaultAccessLogID DESC;

-- who uses the register
SELECT LoginName, COUNT(*) AS Actions, MAX(LoggedAt) AS LastSeen
FROM dbo.VaultAccessLog GROUP BY LoginName ORDER BY Actions DESC;

-- full change history for one record
SELECT LoggedAt, LoginName, Detail
FROM dbo.VaultAccessLog
WHERE SPListItemID = 12345 AND Action = 'Edit'
ORDER BY LoggedAt DESC;
--------------------------------------------------------------------- */
