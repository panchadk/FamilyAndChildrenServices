-- ============================================================================
-- spine_v2.sql -- rebuild vw_CaseSpine with person-level name/DOB columns,
--                 then re-materialize dbo.CaseSpine.
-- Person columns come from whichever exists per view:
--   Surname: CG1LName (Caregiver) / ChildALName (Child)
--   Given:   CG1FName / ChildAFName
--   DOB:     CG1DOB   / ChildADOB
-- Views with neither carry NULLs (portal falls back to case name).
-- ============================================================================
SET NOCOUNT ON;

DECLARE @union NVARCHAR(MAX) = NULL;

SELECT @union = STRING_AGG(CAST(
    'SELECT CaseNumber, ''' + REPLACE(v.name, 'vw_All_', '') + ''' AS Form, UNID, Created, ' +
    'SourceDb, Era, SourceTable, ' +
    CASE WHEN c_sur.name IS NOT NULL THEN 'CaseSurname' ELSE 'CAST(NULL AS NVARCHAR(255))' END + ' AS Surname, ' +
    CASE WHEN c_giv.name IS NOT NULL THEN 'CaseGiven'   ELSE 'CAST(NULL AS NVARCHAR(255))' END + ' AS GivenName, ' +
    CASE WHEN p_cgl.name IS NOT NULL THEN 'CG1LName'
         WHEN p_chl.name IS NOT NULL THEN 'ChildALName'
         ELSE 'CAST(NULL AS NVARCHAR(255))' END + ' AS PersonSurname, ' +
    CASE WHEN p_cgf.name IS NOT NULL THEN 'CG1FName'
         WHEN p_chf.name IS NOT NULL THEN 'ChildAFName'
         ELSE 'CAST(NULL AS NVARCHAR(255))' END + ' AS PersonGiven, ' +
    CASE WHEN p_cgd.name IS NOT NULL THEN 'CG1DOB'
         WHEN p_chd.name IS NOT NULL THEN 'ChildADOB'
         ELSE 'CAST(NULL AS NVARCHAR(255))' END + ' AS PersonDOB ' +
    'FROM dbo.' + QUOTENAME(v.name)
    AS NVARCHAR(MAX)), CHAR(10) + 'UNION ALL' + CHAR(10))
FROM sys.views v
JOIN sys.columns c_case ON c_case.object_id = v.object_id AND c_case.name = 'CaseNumber'
LEFT JOIN sys.columns c_sur ON c_sur.object_id = v.object_id AND c_sur.name = 'CaseSurname'
LEFT JOIN sys.columns c_giv ON c_giv.object_id = v.object_id AND c_giv.name = 'CaseGiven'
LEFT JOIN sys.columns p_cgl ON p_cgl.object_id = v.object_id AND p_cgl.name = 'CG1LName'
LEFT JOIN sys.columns p_cgf ON p_cgf.object_id = v.object_id AND p_cgf.name = 'CG1FName'
LEFT JOIN sys.columns p_cgd ON p_cgd.object_id = v.object_id AND p_cgd.name = 'CG1DOB'
LEFT JOIN sys.columns p_chl ON p_chl.object_id = v.object_id AND p_chl.name = 'ChildALName'
LEFT JOIN sys.columns p_chf ON p_chf.object_id = v.object_id AND p_chf.name = 'ChildAFName'
LEFT JOIN sys.columns p_chd ON p_chd.object_id = v.object_id AND p_chd.name = 'ChildADOB'
WHERE v.name LIKE 'vw[_]All[_]%';

DECLARE @sql NVARCHAR(MAX) = N'CREATE OR ALTER VIEW dbo.vw_CaseSpine AS' + CHAR(10) + @union + N';';
EXEC sp_executesql @sql;
PRINT 'vw_CaseSpine v2 created.';

-- ---------------- Re-materialize ----------------
IF OBJECT_ID('dbo.CaseSpine') IS NOT NULL DROP TABLE dbo.CaseSpine;
SELECT * INTO dbo.CaseSpine FROM dbo.vw_CaseSpine;   -- the long step

ALTER TABLE dbo.CaseSpine ALTER COLUMN CaseNumber    NVARCHAR(400) NULL;
ALTER TABLE dbo.CaseSpine ALTER COLUMN Surname       NVARCHAR(400) NULL;
ALTER TABLE dbo.CaseSpine ALTER COLUMN GivenName     NVARCHAR(400) NULL;
ALTER TABLE dbo.CaseSpine ALTER COLUMN PersonSurname NVARCHAR(400) NULL;
ALTER TABLE dbo.CaseSpine ALTER COLUMN PersonGiven   NVARCHAR(400) NULL;
ALTER TABLE dbo.CaseSpine ALTER COLUMN PersonDOB     NVARCHAR(400) NULL;

CREATE CLUSTERED INDEX IX_CaseSpine ON dbo.CaseSpine (CaseNumber, Form, Created);
CREATE NONCLUSTERED INDEX IX_CaseSpine_Name
    ON dbo.CaseSpine (Surname, GivenName) INCLUDE (CaseNumber, Form, Created, Era);
CREATE NONCLUSTERED INDEX IX_CaseSpine_Person
    ON dbo.CaseSpine (PersonSurname, PersonGiven) INCLUDE (CaseNumber, Form, Created, Era);

SELECT COUNT(*) AS SpineRows FROM dbo.CaseSpine;
