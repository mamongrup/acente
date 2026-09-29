# run-server.ps1 — .env yukleyip gleam run calistirir
$ErrorActionPreference = 'Continue'
$root = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { 'C:\laragon\www\acente' }
Set-Location $root

$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#')) {
        $idx = $line.IndexOf('=')
        if ($idx -gt 0) {
            $k = $line.Substring(0, $idx).Trim()
            $v = $line.Substring($idx + 1).Trim()
            # Hem current process hem de User scope'a yaz
            [System.Environment]::SetEnvironmentVariable($k, $v, 'Process')
            try { [System.Environment]::SetEnvironmentVariable($k, $v, 'User') } catch {}
        }
    }
}

function Test-TcpPort([string]$HostName, [int]$Port, [int]$TimeoutMs = 750) {
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

function Start-LocalPostgresIfNeeded {
    $hostName = if ($env:PGHOST) { $env:PGHOST } else { '127.0.0.1' }
    $port = 5432
    if ($env:PGPORT -and [int]::TryParse($env:PGPORT, [ref]$port) -eq $false) { $port = 5432 }

    if (Test-TcpPort $hostName $port) { return }

    $dataDir = 'C:\laragon\data\postgresql'
    $pgCtl = 'C:\laragon\bin\postgresql\postgresql\bin\pg_ctl.exe'
    if (($hostName -eq '127.0.0.1' -or $hostName -eq 'localhost') -and (Test-Path -LiteralPath $dataDir) -and (Test-Path -LiteralPath $pgCtl)) {
        Write-Host "PostgreSQL $hostName`:$port kapalı görünüyor; lokal acente cluster başlatılıyor..."
        & $pgCtl start -D $dataDir -l (Join-Path $dataDir 'acente-start.log') | Out-Host
        Start-Sleep -Seconds 2
    }

    if (!(Test-TcpPort $hostName $port 1500)) {
        Write-Warning "PostgreSQL $hostName`:$port erişilemiyor. DB kullanan sayfalar/endpointler hata verebilir."
    }
}

Start-LocalPostgresIfNeeded

Write-Host "APP_ENV=$env:APP_ENV  PGHOST=$env:PGHOST  PORT=$env:APP_PORT"
& 'C:/laragon/bin/gleam/gleam.exe' build
if ($LASTEXITCODE -ne 0) { throw 'Gleam derlemesi başarısız.' }
& 'C:/laragon/bin/erlang/bin/erlc.exe' -o (Join-Path $root 'build/dev/erlang/nexus_agency/ebin') (Join-Path $root 'src/nexus_agency/erl/nexus_agency@router_impl.erl')
if ($LASTEXITCODE -ne 0) { throw 'Router Erlang derlemesi başarısız.' }
Write-Host "Gleam baslatiliyor..."
& 'C:/laragon/bin/gleam/gleam.exe' run
