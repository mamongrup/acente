$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
if (!(Test-Path -LiteralPath $envFile)) { throw 'Production .env is missing.' }
& "$PSScriptRoot/check-production-gates.ps1" -EnvPath $envFile
if ($LASTEXITCODE -ne 0) { throw 'Production configuration failed.' }
Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim()
  if (!$line -or $line.StartsWith('#')) { return }
  $index = $line.IndexOf('=')
  if ($index -gt 0) { Set-Item "Env:$($line.Substring(0, $index).Trim())" $line.Substring($index + 1).Trim() }
}
if ($env:APP_ENV -ne 'production') { throw 'APP_ENV=production is required.' }
$gleam = (Get-Command gleam -ErrorAction Stop).Source
$erlc = (Get-Command erlc -ErrorAction Stop).Source
Set-Location -LiteralPath $root
New-Item -ItemType Directory -Path (Join-Path $root '.local') -Force | Out-Null
& $gleam build
if ($LASTEXITCODE -ne 0) { throw 'Agency build failed.' }
$routerSource = Join-Path $root 'src/nexus_agency/erl/nexus_agency@router_impl.erl'
$routerOutput = Join-Path $root 'build/dev/erlang/nexus_agency/ebin'
& $erlc -o $routerOutput $routerSource
if ($LASTEXITCODE -ne 0) { throw 'Agency router build failed.' }
# Migration credentials must remain in a separate operator session.
Remove-Item Env:PGOWNER_PASSWORD,Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue
& $gleam run
if ($LASTEXITCODE -ne 0) { throw "Agency server exited: $LASTEXITCODE" }
