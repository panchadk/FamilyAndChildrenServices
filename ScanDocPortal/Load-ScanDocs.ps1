<#
    Load-ScanDocs.ps1
    -----------------------------------------------------------------
    Walks \\manage-srv\scanned_files\Children, parses folder + PDF
    names, bulk-loads scan.ScanStaging, then runs scan.usp_MergeScanStaging.

    Folder pattern : {caseref}_{firstname}_{lastname}
    File   pattern : {caseref}_{firstname}_{lastname}_{doctype}.pdf
                     (no doctype token -> 'master')

    Run on a box whose account can read the share AND reach SQL5.
    Windows Auth is used for the SQL connection.
    -----------------------------------------------------------------
#>

[CmdletBinding()]
param(
    [string]$ShareRoot = '\\manage-srv\scanned_files\Children',
    [string]$SqlServer = 'SQL5',
    [string]$Database  = 'ScanArchive'
)

$ErrorActionPreference = 'Stop'

# ---- Parse a folder name into ref/base/suffix/first/last ------------
function Parse-FolderName {
    param([string]$Name)

    # Expect: {caseref}_{firstname}_{lastname...}
    # caseref = digits + optional single alpha suffix, e.g. 12043a
    $parts = $Name -split '_', 3    # split into at most 3: ref, first, rest(last)
    if ($parts.Count -lt 3) {
        # Can't parse cleanly - keep raw name, leave names null
        return [pscustomobject]@{
            CaseRef = $parts[0]; CaseRefBase = ($parts[0] -replace '[^\d]', '')
            CaseRefSuffix = $null; FirstName = $null; LastName = $null
        }
    }

    $ref   = $parts[0]
    $first = $parts[1]
    $last  = $parts[2]                       # may contain apostrophes/hyphens

    $base   = ($ref -replace '[^\d]', '')    # numeric portion
    $suffix = ($ref -replace '\d', '')       # alpha portion (may be empty)
    if ([string]::IsNullOrEmpty($suffix)) { $suffix = $null }

    [pscustomobject]@{
        CaseRef       = $ref
        CaseRefBase   = $base
        CaseRefSuffix = $suffix
        FirstName     = $first
        LastName      = $last
    }
}

# ---- Parse doctype token off a PDF file name -----------------------
function Get-DocType {
    param([string]$FileBaseName, [string]$FolderName)

    # Strip the folder prefix if the file repeats it, then take remainder.
    $rest = $FileBaseName
    if ($FileBaseName.ToLower().StartsWith($FolderName.ToLower())) {
        $rest = $FileBaseName.Substring($FolderName.Length).TrimStart('_')
    }
    if ([string]::IsNullOrWhiteSpace($rest)) { return 'master' }
    return $rest
}

Write-Host "Scanning $ShareRoot ..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $ShareRoot)) {
    throw "Share root not reachable: $ShareRoot"
}

# ---- Build the DataTable that mirrors scan.ScanStaging -------------
$dt = New-Object System.Data.DataTable
$cols = @(
    'FolderName','FolderRelPath','FolderDate','CaseRef','CaseRefBase',
    'CaseRefSuffix','FirstName','LastName','FileName','FileRelPath',
    'DocType','FileSizeBytes','FileDate'
)
foreach ($c in $cols) { [void]$dt.Columns.Add($c) }

$folders = Get-ChildItem -LiteralPath $ShareRoot -Directory
Write-Host ("Found {0} folders." -f $folders.Count) -ForegroundColor Cyan

$rootLen = $ShareRoot.TrimEnd('\').Length + 1

foreach ($f in $folders) {
    $p = Parse-FolderName -Name $f.Name
    $folderRel = $f.FullName.Substring($rootLen)

    $pdfs = Get-ChildItem -LiteralPath $f.FullName -Filter *.pdf -File -ErrorAction SilentlyContinue

    if ($pdfs.Count -eq 0) {
        # Folder with no PDFs - still record the case row
        $r = $dt.NewRow()
        $r['FolderName']    = $f.Name
        $r['FolderRelPath'] = $folderRel
        $r['FolderDate']    = $f.LastWriteTime
        $r['CaseRef']       = $p.CaseRef
        $r['CaseRefBase']   = $p.CaseRefBase
        $r['CaseRefSuffix'] = if ($null -eq $p.CaseRefSuffix) { [DBNull]::Value } else { $p.CaseRefSuffix }
        $r['FirstName']     = if ($null -eq $p.FirstName) { [DBNull]::Value } else { $p.FirstName }
        $r['LastName']      = if ($null -eq $p.LastName)  { [DBNull]::Value } else { $p.LastName }
        $r['FileName']      = [DBNull]::Value
        $r['FileRelPath']   = [DBNull]::Value
        $r['DocType']       = [DBNull]::Value
        $r['FileSizeBytes'] = [DBNull]::Value
        $r['FileDate']      = [DBNull]::Value
        $dt.Rows.Add($r)
        continue
    }

    foreach ($pdf in $pdfs) {
        $r = $dt.NewRow()
        $r['FolderName']    = $f.Name
        $r['FolderRelPath'] = $folderRel
        $r['FolderDate']    = $f.LastWriteTime
        $r['CaseRef']       = $p.CaseRef
        $r['CaseRefBase']   = $p.CaseRefBase
        $r['CaseRefSuffix'] = if ($null -eq $p.CaseRefSuffix) { [DBNull]::Value } else { $p.CaseRefSuffix }
        $r['FirstName']     = if ($null -eq $p.FirstName) { [DBNull]::Value } else { $p.FirstName }
        $r['LastName']      = if ($null -eq $p.LastName)  { [DBNull]::Value } else { $p.LastName }
        $r['FileName']      = $pdf.Name
        $r['FileRelPath']   = $pdf.FullName.Substring($rootLen)
        $r['DocType']       = Get-DocType -FileBaseName $pdf.BaseName -FolderName $f.Name
        $r['FileSizeBytes'] = [long]$pdf.Length
        $r['FileDate']      = $pdf.LastWriteTime
        $dt.Rows.Add($r)
    }
}

Write-Host ("Staged {0} rows. Loading to {1}.{2} ..." -f $dt.Rows.Count, $SqlServer, $Database) -ForegroundColor Cyan

# ---- Connect (Windows Auth) ---------------------------------------
$connStr = "Server=$SqlServer;Database=$Database;Integrated Security=SSPI;TrustServerCertificate=True;"
$conn = New-Object System.Data.SqlClient.SqlConnection $connStr
$conn.Open()

try {
    # Truncate staging
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'TRUNCATE TABLE scan.ScanStaging;'
    [void]$cmd.ExecuteNonQuery()

    # Bulk copy
    $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($conn)
    $bulk.DestinationTableName = 'scan.ScanStaging'
    $bulk.BatchSize = 5000
    foreach ($c in $cols) { [void]$bulk.ColumnMappings.Add($c, $c) }
    $bulk.WriteToServer($dt)

    # Merge
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'scan.usp_MergeScanStaging'
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $reader = $cmd.ExecuteReader()
    while ($reader.Read()) {
        Write-Host ("Merge complete. Cases: {0}  Documents: {1}" -f $reader['TotalCases'], $reader['TotalDocuments']) -ForegroundColor Green
    }
    $reader.Close()
}
finally {
    $conn.Close()
}
