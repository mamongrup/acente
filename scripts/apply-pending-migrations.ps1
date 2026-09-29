param([int]$From = 175, [int]$To = 224)
$ErrorActionPreference = 'Continue'
$pgArgs = @('-U', 'postgres', '-d', 'nexus_agency', '--no-psqlrc')

$files = Get-ChildItem (Join-Path $PSScriptRoot '..\db\migrations') -Filter '*.sql' |
  Where-Object {
    $num = [int](($_.Name -split '_')[0])
    $num -ge $From -and $num -le $To
  } | Sort-Object Name

$pass = 0; $fail = 0; $errors = @()

foreach ($f in $files) {
  $out = & psql @pgArgs -f $f.FullName 2>&1
  $errLines = $out | Where-Object { $_ -match '\bERROR\b' -and $_ -notmatch 'already exists' }
  if ($errLines) {
    $fail++
    Write-Host "FAIL: $($f.Name)" -ForegroundColor Red
    $errLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    $errors += $f.Name
  } else {
    $pass++
    Write-Host "OK:   $($f.Name)" -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "Migration sonucu: $pass gecti, $fail basarisiz."
if ($errors) {
  Write-Host "Basarisiz dosyalar:" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "  $_" }
  exit 1
}
exit 0
