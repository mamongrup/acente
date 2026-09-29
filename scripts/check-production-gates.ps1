param(
  [string]$EnvPath = ".env"
)

$ErrorActionPreference = 'Stop'
if (!(Test-Path $EnvPath)) { throw "Env file not found: $EnvPath" }

$values = @{}
Get-Content $EnvPath | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) {
    $values[$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim()
  }
}

function Require-Key([string]$key) {
  if (!$values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$values[$key])) {
    throw "$key is required."
  }
}

function Require-MinLength([string]$key, [int]$min) {
  Require-Key $key
  if(([string]$values[$key]).Length -lt $min) {
    throw "$key must be at least $min characters."
  }
}

function Require-HttpsUrl([string]$key) {
  Require-Key $key
  $url = [string]$values[$key]
  if (!$url.StartsWith('https://')) { throw "$key must start with https:// in production." }
  if ($url -match 'localhost|127\.0\.0\.1|::1') { throw "$key must not point to localhost in production." }
}

$appEnv = [string]$values['APP_ENV']
if ($appEnv -ne 'production') {
  Write-Host "APP_ENV=$appEnv; production gates skipped. Set APP_ENV=production to enforce."
  exit 0
}

Require-HttpsUrl 'APP_ORIGIN'
if ([uri]$values['APP_ORIGIN'] -and ([uri]$values['APP_ORIGIN']).Host -match '(^|\.)example\.(com|org|net)$') {
  throw 'APP_ORIGIN still uses an example domain.'
}
Require-MinLength 'SECRET_KEY_BASE' 64
Require-MinLength 'NEXUS_CONFIG_KEY' 64
Require-Key 'PGHOST'
Require-Key 'PGPORT'
Require-Key 'PGDATABASE'
Require-Key 'PGUSER'
Require-Key 'PGPASSWORD'
foreach ($key in @('PGPASSWORD','SECRET_KEY_BASE','NEXUS_CONFIG_KEY')) {
  if ([string]$values[$key] -match 'CHANGE_ME|generated-by-setup|change-this|^dummy$') {
    throw "$key contains a placeholder."
  }
}

Require-Key 'TRUSTED_PROXY_SECURE_COOKIES'
if ([string]$values['TRUSTED_PROXY_SECURE_COOKIES'] -ne 'true') {
  throw "TRUSTED_PROXY_SECURE_COOKIES=true is required in production. Configure reverse proxy cookie Secure/SameSite flags for upstream-set cookies."
}

Require-Key 'EDGE_RATE_LIMIT_ENABLED'
if ([string]$values['EDGE_RATE_LIMIT_ENABLED'] -ne 'true') {
  throw "EDGE_RATE_LIMIT_ENABLED=true is required in production. Configure reverse proxy/WAF/distributed rate limits."
}

Require-Key 'TRUST_PROXY_HEADERS'
if ([string]$values['TRUST_PROXY_HEADERS'] -ne 'true') {
  throw "TRUST_PROXY_HEADERS=true is required with the production edge. The trusted proxy must overwrite client-supplied forwarding headers and the origin must not be public."
}

$nexusOrigin = [string]$values['NEXUS_API_ORIGIN']
$nexusKey = [string]$values['NEXUS_API_KEY']
if ([bool]$nexusOrigin -ne [bool]$nexusKey) {
  throw 'NEXUS_API_ORIGIN and NEXUS_API_KEY must both be configured or both be empty.'
}
if ($nexusOrigin) {
  Require-HttpsUrl 'NEXUS_API_ORIGIN'
}

Write-Host 'Production gate check passed.'
