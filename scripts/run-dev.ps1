$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  $idx = $line.IndexOf('=')
  if ($idx -gt 0) {
    $key = $line.Substring(0, $idx).Trim()
    $val = $line.Substring($idx + 1).Trim()
    [Environment]::SetEnvironmentVariable($key, $val, 'Process')
  }
}
Set-Location $root
gleam run
