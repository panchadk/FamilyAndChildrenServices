-- ============================================================================
-- portal_db_setup.sql -- run against IFRSArchive before deploying the portal
--   1. Portal audit table
--   2. vw_CaseSpine: dynamic UNION across every vw_All_* view that carries
--      a CaseNumber column (system views like Transaction Log are skipped)
-- ============================================================================
SET NOCOUNT ON;

IF OBJECT_ID('dbo.PortalAudit') IS NULL
BEGIN
    CREATE TABLE dbo.PortalAudit (
        AuditId    BIGINT IDENTITY(1,1) PRIMARY KEY,
        EventTime  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
        UserName   NVARCHAR(128)  NOT NULL,
        Action     NVARCHAR(40)   NOT NULL,   -- Search / CaseView / DocView / AttachmentView / PersonSearch
        CaseNumber NVARCHAR(100)  NULL,
        UNID       NVARCHAR(32)   NULL,
        Detail     NVARCHAR(400)  NULL,
        ClientIP   NVARCHAR(45)   NULL
    );
    CREATE NONCLUSTERED INDEX IX_PortalAudit_Time ON dbo.PortalAudit (EventTime);
    CREATE NONCLUSTERED INDEX IX_PortalAudit_User ON dbo.PortalAudit (UserName, EventTime);
END;

-- ---------------- vw_CaseSpine ----------------
DECLARE @union NVARCHAR(MAX) = NULL;

SELECT @union = STRING_AGG(CAST(
    'SELECT CaseNumber, ''' + REPLACE(v.name, 'vw_All_', '') + ''' AS Form, UNID, Created, ' +
    'SourceDb, Era, SourceTable, ' +
    CASE WHEN c_sur.name IS NOT NULL THEN 'CaseSurname' ELSE 'CAST(NULL AS NVARCHAR(255))' END + ' AS Surname, ' +
    CASE WHEN c_giv.name IS NOT NULL THEN 'CaseGiven'   ELSE 'CAST(NULL AS NVARCHAR(255))' END + ' AS GivenName ' +
    'FROM dbo.' + QUOTENAME(v.name)
    AS NVARCHAR(MAX)), CHAR(10) + 'UNION ALL' + CHAR(10))
FROM sys.views v
JOIN sys.columns c_case ON c_case.object_id = v.object_id AND c_case.name = 'CaseNumber'
LEFT JOIN sys.columns c_sur ON c_sur.object_id = v.object_id AND c_sur.name = 'CaseSurname'
LEFT JOIN sys.columns c_giv ON c_giv.object_id = v.object_id AND c_giv.name = 'CaseGiven'
WHERE v.name LIKE 'vw[_]All[_]%';

DECLARE @sql NVARCHAR(MAX) = N'CREATE OR ALTER VIEW dbo.vw_CaseSpine AS' + CHAR(10) + @union + N';';
EXEC sp_executesql @sql;

SELECT 'vw_CaseSpine created over ' +
       CAST((SELECT COUNT(*) FROM sys.views v
             JOIN sys.columns c ON c.object_id=v.object_id AND c.name='CaseNumber'
             WHERE v.name LIKE 'vw[_]All[_]%') AS VARCHAR(10)) + ' views' AS Result;

-- ============================================================================
-- 3. MATERIALIZE the spine (required for performance):
--    Run after the view is created. The portal queries dbo.CaseSpine.
--    Re-run this block only if archive data ever changes (it shouldn't).
-- ============================================================================
-- IF OBJECT_ID('dbo.CaseSpine') IS NOT NULL DROP TABLE dbo.CaseSpine;
-- SELECT * INTO dbo.CaseSpine FROM dbo.vw_CaseSpine;
-- CREATE CLUSTERED INDEX IX_CaseSpine ON dbo.CaseSpine (CaseNumber, Form, Created);
-- CREATE NONCLUSTERED INDEX IX_CaseSpine_Name ON dbo.CaseSpine (Surname, GivenName)
--     INCLUDE (CaseNumber, Form, Created, Era);
