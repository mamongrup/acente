param(
  [string]$EnvPath = ".env",
  [string]$BaseUrl = ""
)

$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $EnvPath)) { throw "Env file not found: $EnvPath" }

$values = @{}
Get-Content -LiteralPath $EnvPath | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $idx = $line.IndexOf('=')
  if ($idx -gt 0) {
    $values[$line.Substring(0, $idx).Trim()] = $line.Substring($idx + 1).Trim()
  }
}

function Value-Or([string]$key, [string]$fallback) {
  if ($values.ContainsKey($key) -and ![string]::IsNullOrWhiteSpace([string]$values[$key])) {
    return [string]$values[$key]
  }
  return $fallback
}

function Test-TcpPort([string]$HostName, [int]$Port, [int]$TimeoutMs = 1500) {
  try {
    $client = [System.Net.Sockets.TcpClient]::new()
    $iar = $client.BeginConnect($HostName, $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
    if (!$ok) {
      $client.Close()
      return $false
    }
    $client.EndConnect($iar)
    $client.Close()
    return $true
  } catch {
    return $false
  }
}

$pgHost = Value-Or 'PGHOST' '127.0.0.1'
$pgPort = [int](Value-Or 'PGPORT' '5432')
$appPort = [int](Value-Or 'APP_PORT' '8082')
if (!$BaseUrl) { $BaseUrl = "http://127.0.0.1:$appPort" }

$errors = New-Object System.Collections.Generic.List[string]

if (!(Test-TcpPort $pgHost $pgPort)) {
  $errors.Add("PostgreSQL unreachable at $pgHost`:$pgPort")
}

if (!(Test-TcpPort '127.0.0.1' $appPort)) {
  $errors.Add("Acente app port unreachable at 127.0.0.1:$appPort")
} else {
  try {
    $homeResponse = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/" -TimeoutSec 10
    if ($homeResponse.StatusCode -ne 200) { $errors.Add("Home returned HTTP $($homeResponse.StatusCode)") }
  } catch {
    $errors.Add("Home request failed: $($_.Exception.Message)")
  }

  try {
    $rates = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/public/rates" -TimeoutSec 10
    if ($rates.StatusCode -ne 200) { $errors.Add("Rates returned HTTP $($rates.StatusCode)") }
  } catch {
    $errors.Add("Rates request failed: $($_.Exception.Message)")
  }
}

if ($errors.Count -gt 0) {
  foreach ($err in $errors) { Write-Error $err }
  exit 1
}

Write-Host "Runtime health check passed: PostgreSQL, app port, home and rates are healthy."
