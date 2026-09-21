$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Get-Content (Join-Path $root '.env') | ForEach-Object {
  $line = $_.Trim(); $i = $line.IndexOf('=')
  if ($i -gt 0 -and $line.Substring(0,$i) -match '^PG') {
    Set-Item "Env:$($line.Substring(0,$i))" $line.Substring($i+1)
  }
}
# DDL, fixtures and all mutations roll back together, even on assertion errors.
$migration = Join-Path $root 'db/migrations/073_parampos_lifecycle.sql'
$tests = Join-Path $root 'test/parampos_lifecycle.sql'
& psql -X -w -v ON_ERROR_STOP=1 -c 'BEGIN;' -f $migration -f $tests -c 'ROLLBACK;'
if ($LASTEXITCODE -ne 0) { throw 'ParamPOS lifecycle regression failed' }
Write-Output 'ParamPOS lifecycle regression passed (rolled back).'

$fixture = Start-Process -FilePath (Get-Command node).Source -ArgumentList @((Join-Path $root 'test/parampos-soap-fixture.cjs')) -WorkingDirectory $root -WindowStyle Hidden -PassThru
try {
  Start-Sleep -Milliseconds 500
  if ($fixture.HasExited) { throw 'SOAP fixture could not start; port 18089 must be free.' }
  Push-Location $root
  try {
    & gleam run -m parampos_test
    if ($LASTEXITCODE -ne 0) { throw 'ParamPOS protocol tests failed' }
    & gleam run -m parampos_integration
    if ($LASTEXITCODE -ne 0) { throw 'ParamPOS HTTP integration failed' }
    $counts = Invoke-RestMethod 'http://127.0.0.1:18089/counts'
    if ($counts.starts -ne 3 -or $counts.pays -ne 1) { throw "Unexpected bank call counts: $($counts | ConvertTo-Json -Compress)" }
    Write-Output 'Three 3D attempts, exactly one charge; failures, expiry and repeats made no extra charges.'
  } finally { Pop-Location }
} finally {
  if (!$fixture.HasExited) { Stop-Process -Id $fixture.Id }
}
