/* ============================================================
   LANFAM Archive Portal - one-time database setup
   Run in SSMS against the LanfamArchive instance AFTER creating
   the IIS application pool (default name: LanfamPortal).
   ============================================================ */
USE [LanfamArchive];
GO

/* 1. Audit table - every search and record view lands here */
IF OBJECT_ID('lanfam.AccessLog') IS NULL
CREATE TABLE lanfam.AccessLog (
    AccessLogID BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_AccessLog PRIMARY KEY,
    LoggedAt    DATETIME2(0) NOT NULL
        CONSTRAINT DF_AccessLog_LoggedAt DEFAULT SYSDATETIME(),
    LoginName   NVARCHAR(128) NULL,
    ClientIP    VARCHAR(45) NULL,
    Action      VARCHAR(30) NOT NULL,   -- SEARCH / VIEW_CHILD / VIEW_FAMILY
    Detail      NVARCHAR(400) NULL
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_AccessLog_When'
               AND object_id=OBJECT_ID('lanfam.AccessLog'))
    CREATE INDEX IX_AccessLog_When ON lanfam.AccessLog (LoggedAt)
        INCLUDE (LoginName, Action);
GO

/* 2. Login for the IIS app pool identity.
      If SQL Server is on the SAME machine as IIS, the app pool
      identity is 'IIS APPPOOL\<PoolName>'.
      If SQL Server is on a DIFFERENT machine, run the app pool as
      a domain account (e.g. FCSGW\svc-lanfamportal) and grant that
      instead - replace the name below accordingly.               */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals
               WHERE name = N'IIS APPPOOL\LanfamPortal')
    CREATE LOGIN [IIS APPPOOL\LanfamPortal] FROM WINDOWS;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals
               WHERE name = N'IIS APPPOOL\LanfamPortal')
    CREATE USER [IIS APPPOOL\LanfamPortal]
        FOR LOGIN [IIS APPPOOL\LanfamPortal];
GO

/* 3. Least privilege: read the archive, write ONLY the audit log */
GRANT SELECT ON SCHEMA::lanfam TO [IIS APPPOOL\LanfamPortal];
GRANT INSERT ON lanfam.AccessLog TO [IIS APPPOOL\LanfamPortal];
GO

/* 4. Quick audit review queries (for you, not the portal)
SELECT TOP 100 * FROM lanfam.AccessLog ORDER BY AccessLogID DESC;

SELECT LoginName, COUNT(*) AS Lookups, MAX(LoggedAt) AS LastSeen
FROM lanfam.AccessLog GROUP BY LoginName ORDER BY Lookups DESC;
*/
