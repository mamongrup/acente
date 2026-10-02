param([switch]$Once)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$workerArgs = @((Join-Path $PSScriptRoot 'calendar-worker.mjs'))
if ($Once) { $workerArgs += '--once' }
& node @workerArgs
if ($LASTEXITCODE -ne 0) { throw 'Takvim işçisi durdu.' }
