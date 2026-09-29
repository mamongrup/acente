param(
  [string]$EnvPath = ".env",
  [string]$OutputDirectory = ".local/backups",
  [switch]$RestoreTest,
  [string]$MaintenanceDatabase = "postgres",
  [string]$MaintenanceUser = "",
  [string]$MaintenancePassword = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = Join-Path $root $EnvPath
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }

Get-Content -LiteralPath $resolvedEnv | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith("#")) { return }
  $index = $line.IndexOf("=")
  if ($index -gt 0) {
    Set-Item "Env:$($line.Substring(0, $index).Trim())" $line.Substring($index + 1).Trim()
  }
}

function Resolve-Tool([string]$Name) {
  $laragon = "C:/laragon/bin/postgresql/postgresql/bin/$Name.exe"
  if (Test-Path -LiteralPath $laragon) { return $laragon }
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw "$Name not found."
}

$pgDump = Resolve-Tool "pg_dump"
$pgRestore = Resolve-Tool "pg_restore"
$psql = Resolve-Tool "psql"
$createdb = Resolve-Tool "createdb"
$dropdb = Resolve-Tool "dropdb"

$maintenanceUser = if ($MaintenanceUser) { $MaintenanceUser } else { $env:PGUSER }
$originalPgPassword = $env:PGPASSWORD

$backupDir = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$dumpPath = Join-Path $backupDir "$($env:PGDATABASE)-$stamp.dump"

try {
  & $pgDump -w -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -Fc -f $dumpPath
  if ($LASTEXITCODE -ne 0) { throw "pg_dump failed: $LASTEXITCODE" }
  Write-Host "Backup created: $dumpPath"

  if (!$RestoreTest) {
    Write-Host "Restore test skipped. Re-run with -RestoreTest to verify the dump in a temporary database."
    return
  }

  if ($MaintenancePassword) {
    $env:PGPASSWORD = $MaintenancePassword
  } elseif ($MaintenanceUser -and $MaintenanceUser -ne $env:PGUSER) {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  }

  $tempDb = "$($env:PGDATABASE)_restore_drill_$([guid]::NewGuid().ToString('N').Substring(0, 8))"
  $created = $false
  try {
    & $createdb -w -h $env:PGHOST -p $env:PGPORT -U $maintenanceUser $tempDb
    if ($LASTEXITCODE -ne 0) {
      throw "createdb failed: $LASTEXITCODE. Restore drills require a maintenance DB user with CREATEDB permission; pass -MaintenanceUser and optionally -MaintenancePassword."
    }
    $created = $true

    & $pgRestore -w -h $env:PGHOST -p $env:PGPORT -U $maintenanceUser -d $tempDb --no-owner --no-privileges $dumpPath
    if ($LASTEXITCODE -ne 0) { throw "pg_restore failed: $LASTEXITCODE" }

    $check = & $psql -X -w -h $env:PGHOST -p $env:PGPORT -U $maintenanceUser -d $tempDb -At -c "select count(*) from agency.tenants;"
    if ($LASTEXITCODE -ne 0 -or $check -notmatch '^\d+$') { throw "restore verification query failed: $LASTEXITCODE" }
    Write-Host "Restore drill passed in temporary database $tempDb. Tenant rows: $check"
  } finally {
    if ($created) {
      & $dropdb -w -h $env:PGHOST -p $env:PGPORT -U $maintenanceUser --if-exists $tempDb | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Temporary restore database cleanup failed: $tempDb" }
    }
  }
} finally {
  $env:PGPASSWORD = $originalPgPassword
}
