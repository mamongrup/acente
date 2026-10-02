param(
  [string]$EnvPath = ".env",
  [int]$KeepDays = 30,
  [int]$BatchSize = 5000,
  # Operasyonel kanit dosyalari (asagida varsayilanlar). Bos birakilirsa
  # varsayilan liste kullanilir.
  [string[]]$LogPath = @(),
  # Dosya loglari icin yas siniri (gun).
  [int]$LogKeepDays = 30,
  # Dosya loglari icin boyut tavani (KB). Asilirsa EN YENI satirlar korunur.
  [int]$LogMaxKb = 256
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$resolvedEnv = if ([IO.Path]::IsPathRooted($EnvPath)) { $EnvPath } else { Join-Path $root $EnvPath }
if (!(Test-Path -LiteralPath $resolvedEnv)) { throw "Env file not found: $resolvedEnv" }
if ($KeepDays -lt 7 -or $KeepDays -gt 3650) { throw 'KeepDays must be between 7 and 3650.' }
if ($BatchSize -lt 1 -or $BatchSize -gt 50000) { throw 'BatchSize must be between 1 and 50000.' }
if ($LogKeepDays -lt 1 -or $LogKeepDays -gt 3650) { throw 'LogKeepDays must be between 1 and 3650.' }
if ($LogMaxKb -lt 1 -or $LogMaxKb -gt 102400) { throw 'LogMaxKb must be between 1 and 102400.' }

$values = @{}
Get-Content -LiteralPath $resolvedEnv | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) { $values[$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim() }
}

foreach ($key in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD')) {
  if (!$values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$values[$key])) {
    throw "$key is required."
  }
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (!$psql) {
  $psql = Get-ChildItem 'C:\laragon\bin\postgresql\*\bin\psql.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
}
if (!$psql) { throw 'psql executable not found.' }

$env:PGPASSWORD = [string]$values['PGPASSWORD']
try {
  & $psql.Source -v ON_ERROR_STOP=1 -h $values['PGHOST'] -p $values['PGPORT'] `
    -U $values['PGUSER'] -d $values['PGDATABASE'] -At `
    -c "SELECT * FROM agency.purge_security_defense_data($KeepDays, $BatchSize);"
  if ($LASTEXITCODE -ne 0) { throw "Security retention failed with exit code $LASTEXITCODE" }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

# --- Operational log files: age and size limits -------------------------
# Log lines are handled as raw byte ranges so that the surviving content is
# copied through untouched; no re-encoding of partially non-ASCII lines.
# Age is taken from the leading "YYYY-MM-DD HH:MM:SS" timestamp when it is
# present. Lines without a parsable timestamp are never dropped by age; they
# can still be dropped by the size cap, which always keeps the newest line.
$defaultLogFiles = @('.local/rotation-check.log')
$logFiles = if ($LogPath -and $LogPath.Count -gt 0) { @($LogPath) } else { $defaultLogFiles }
$cutoff = (Get-Date).AddDays(-$LogKeepDays)
$maxBytes = [int64]$LogMaxKb * 1024
$crlf = [byte[]](13, 10)
$stampPattern = '^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})'

function Get-LogLineStamp {
  param([byte[]]$Bytes, [int]$Offset, [int]$Length)
  if ($Length -lt 10) { return $null }
  $take = [Math]::Min(19, $Length)
  $head = [Text.Encoding]::ASCII.GetString($Bytes, $Offset, $take)
  $m = [regex]::Match($head, $stampPattern)
  if (!$m.Success) { return $null }
  try {
    return [datetime]::new(
      [int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value,
      [int]$m.Groups[4].Value, [int]$m.Groups[5].Value, [int]$m.Groups[6].Value)
  } catch {
    return $null
  }
}

$totalAgeDropped = 0
$totalSizeDropped = 0
foreach ($entry in $logFiles) {
  if ([string]::IsNullOrWhiteSpace($entry)) { continue }
  $resolvedLog = if ([IO.Path]::IsPathRooted($entry)) { $entry } else { Join-Path $root $entry }
  if (!(Test-Path -LiteralPath $resolvedLog)) {
    Write-Host "Log retention: skip (missing) $resolvedLog"
    continue
  }
  $bytes = [IO.File]::ReadAllBytes($resolvedLog)
  if ($bytes.Length -eq 0) { continue }

  $lines = New-Object System.Collections.Generic.List[object]
  $start = 0
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -ne 10) { continue }
    $end = $i
    if ($end -gt $start -and $bytes[$end - 1] -eq 13) { $end-- }
    $lines.Add([pscustomobject]@{ Offset = $start; Length = $end - $start })
    $start = $i + 1
  }
  if ($start -lt $bytes.Length) {
    $lines.Add([pscustomobject]@{ Offset = $start; Length = $bytes.Length - $start })
  }

  $kept = New-Object System.Collections.Generic.List[object]
  foreach ($ln in $lines) {
    $stamp = Get-LogLineStamp -Bytes $bytes -Offset $ln.Offset -Length $ln.Length
    if ($stamp -ne $null -and $stamp -lt $cutoff) { continue }
    $kept.Add($ln)
  }
  $ageDropped = $lines.Count - $kept.Count

  $total = [int64]0
  foreach ($ln in $kept) { $total += $ln.Length + 2 }
  $first = 0
  while ($total -gt $maxBytes -and $first -lt ($kept.Count - 1)) {
    $total -= $kept[$first].Length + 2
    $first++
  }
  $sizeDropped = $first

  if ($ageDropped -eq 0 -and $sizeDropped -eq 0) {
    Write-Host "Log retention: kept $resolvedLog ($($kept.Count) lines, $total bytes, cap=$maxBytes bytes)"
    continue
  }

  $out = New-Object System.IO.MemoryStream
  for ($i = $first; $i -lt $kept.Count; $i++) {
    [void]$out.Write($bytes, $kept[$i].Offset, $kept[$i].Length)
    [void]$out.Write($crlf, 0, 2)
  }
  $payload = $out.ToArray()
  $tempPath = "$resolvedLog.retention.tmp"
  try {
    [IO.File]::WriteAllBytes($tempPath, $payload)
    Move-Item -LiteralPath $tempPath -Destination $resolvedLog -Force
  } finally {
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
  }

  $totalAgeDropped += $ageDropped
  $totalSizeDropped += $sizeDropped
  Write-Host "Log retention: trimmed $resolvedLog (age=$ageDropped lines, size=$sizeDropped lines, $total bytes left)"
}

Write-Host "Log retention summary: files=$($logFiles.Count) age_dropped=$totalAgeDropped size_dropped=$totalSizeDropped (keep_days=$LogKeepDays max_kb=$LogMaxKb)"
