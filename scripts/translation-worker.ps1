#Requires -Version 5.1
<#
.SYNOPSIS
    Kategori filtre ceviri iscisi - category_filter_translations kuyruğunu işler.

.DESCRIPTION
    agency.category_filter_translations tablosunda status='queued' olan satirlari
    batch halinde alir, Gemini API ile cevirir ve sonucu 'translated' statusuyle
    gunceller.

    Gecerli status degerleri: queued | translated | approved | published | failed

    Davranis:
    - GEMINI_API_KEY bossa worker log yazar ve 60s bekler (satirlar queued kalir).
      Bu sayede API key eklendiginde otomatik olarak devreye girer.
    - Her batch 10 satir; API cagrilarinin aralarinda kisa bekleme uygulanir.
    - Hata durumunda satir 'queued' durumuna geri doner (yeniden deneme).
    - Idempotent: ayni satir birden fazla kez islenirse sonuc degismez.

    Calistirma:
      .\scripts\translation-worker.ps1

    Zamanlanmis gorev (Windows Task Scheduler):
      Program: powershell.exe
      Args   : -ExecutionPolicy Bypass -File "C:\laragon\www\acente\scripts\translation-worker.ps1"
#>

$ErrorActionPreference = 'Continue'
$root    = Split-Path $PSScriptRoot -Parent
$logFile = Join-Path $root '.local/translation-worker.log'
$null    = New-Item -ItemType Directory -Force -Path (Join-Path $root '.local')

# --- .env yukle -----------------------------------------------------------
Get-Content (Join-Path $root '.env') | ForEach-Object {
    $line = $_.Trim()
    if ($line.StartsWith('#') -or $line.Length -eq 0) { return }
    $idx = $line.IndexOf('=')
    if ($idx -gt 0) {
        Set-Item "Env:$($line.Substring(0, $idx).Trim())" $line.Substring($idx + 1).Trim()
    }
}

$psql = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'

function Write-Log([string]$msg) {
    $ts   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $line = "$ts [translation-worker] $msg"
    Write-Host $line
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Invoke-AgencySql([string]$sql, [switch]$RowsOnly) {
    $a = @('-X', '-w', '-v', 'ON_ERROR_STOP=1',
           '-h', $env:PGHOST, '-p', $env:PGPORT,
           '-U', $env:PGUSER, '-d', $env:PGDATABASE)
    if ($RowsOnly) { $a += @('-At') }
    $a += @('-c', $sql)
    $out = & $psql @a
    if ($LASTEXITCODE -ne 0) { throw "PostgreSQL hatasi: $LASTEXITCODE" }
    return $out
}

function Invoke-GeminiTranslate([string]$sourceText, [string]$targetLang) {
    $apiKey = $env:GEMINI_API_KEY
    $model  = if ($env:AI_MODEL) { $env:AI_MODEL } else { 'gemini-2.0-flash-lite' }
    if (-not $apiKey -or $apiKey.Trim() -eq '') { return $null }

    $langNames = @{
        'en' = 'English'; 'de' = 'German (Deutsch)';
        'fr' = 'French (Francais)'; 'ru' = 'Russian';
        'zh' = 'Simplified Chinese'
    }
    $langName  = if ($langNames[$targetLang]) { $langNames[$targetLang] } else { $targetLang }

    $sysText  = "You are a professional travel-industry translator. Translate the given Turkish UI label into $langName concisely. Output ONLY the translated text, nothing else. Keep it short (a filter label, not a paragraph)."
    $userText = "Translate to ${langName}: $sourceText"

    $payload = @{
        systemInstruction = @{ parts = @(@{ text = $sysText }) }
        contents = @(@{ role = 'user'; parts = @(@{ text = $userText }) })
        generationConfig = @{ temperature = 0.3; maxOutputTokens = 128 }
    } | ConvertTo-Json -Depth 6

    $url = "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=$apiKey"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $payload -TimeoutSec 25
        return ($resp.candidates[0].content.parts[0].text -replace '^\s+|\s+$', '')
    } catch {
        throw "Gemini API hatasi: $($_.Exception.Message)"
    }
}

# --- Ana dongu -----------------------------------------------------------

$hasApiKey = ($env:GEMINI_API_KEY -and $env:GEMINI_API_KEY.Trim() -ne '')
Write-Log "Ceviri worker basladi. API key mevcut: $hasApiKey"

if (-not $hasApiKey) {
    Write-Log "UYARI: GEMINI_API_KEY tanimlanmamis. Satirlar queued durumunda kalacak."
    Write-Log "       .env dosyasina GEMINI_API_KEY eklendiginde ceviri otomatik baslar."
}

while ($true) {
    try {
        # API key yoksa bos dongu - satirlara dokunma, bekle
        if (-not $hasApiKey) {
            # Her dongu basinda key'i yeniden kontrol et (runtime ekleme icin)
            $hasApiKey = ($env:GEMINI_API_KEY -and $env:GEMINI_API_KEY.Trim() -ne '')
            if (-not $hasApiKey) {
                Start-Sleep -Seconds 60
                continue
            }
            Write-Log "GEMINI_API_KEY algilandi, ceviri baslatiyor."
        }

        # 1. Batch al - 10 satir, FOR UPDATE SKIP LOCKED ile
        $claimSql = "SELECT entity_type ||'|'|| entity_id::text ||'|'|| language_code FROM agency.category_filter_translations WHERE status='queued' ORDER BY updated_at LIMIT 10 FOR UPDATE SKIP LOCKED"

        # Basit SELECT - isaretle + isle -> UPDATE
        $rowsSql = "SELECT entity_type, entity_id::text, language_code FROM agency.category_filter_translations WHERE status='queued' ORDER BY updated_at LIMIT 10"
        $rows = Invoke-AgencySql $rowsSql -RowsOnly
        $rows = @($rows | Where-Object { $_ -ne '' })

        if ($rows.Count -eq 0) {
            Start-Sleep -Seconds 5
            continue
        }

        Write-Log "Islenecek kayit: $($rows.Count)"

        # 2. Her satir icin cevir
        foreach ($row in $rows) {
            $parts = $row -split '\|'
            if ($parts.Count -lt 3) { continue }
            $eType = $parts[0].Trim()
            $eId   = $parts[1].Trim()
            $lang  = $parts[2].Trim()

            try {
                # Kaynak metni al (Turkce baslik)
                $srcSql = switch ($eType) {
                    'group' { "SELECT g.title ||'|'|| coalesce(g.help_text,'') FROM agency.category_filter_groups g WHERE g.id='$eId'::uuid" }
                    'item'  { "SELECT i.title ||'|'|| coalesce(i.help_text,'') FROM agency.category_filter_items  i WHERE i.id='$eId'::uuid" }
                    default { $null }
                }
                if (-not $srcSql) {
                    $failSql = "UPDATE agency.category_filter_translations SET status='failed', provider='unknown_entity', updated_at=now() WHERE entity_type='$eType' AND entity_id='$eId'::uuid AND language_code='$lang'"
                    Invoke-AgencySql $failSql | Out-Null
                    continue
                }

                $srcOut = Invoke-AgencySql $srcSql -RowsOnly
                $srcRow = @($srcOut | Where-Object { $_ -ne '' }) | Select-Object -First 1
                if (-not $srcRow) {
                    $failSql = "UPDATE agency.category_filter_translations SET status='failed', provider='src_not_found', updated_at=now() WHERE entity_type='$eType' AND entity_id='$eId'::uuid AND language_code='$lang'"
                    Invoke-AgencySql $failSql | Out-Null
                    continue
                }

                $srcParts = $srcRow -split '\|'
                $srcTitle = $srcParts[0].Trim()
                $srcHelp  = if ($srcParts.Count -gt 1) { $srcParts[1].Trim() } else { '' }

                # Cevir - hata olursa kaynak metni kullan (graceful degradation)
                $tTitle = Invoke-GeminiTranslate $srcTitle $lang
                $tHelp  = ''
                if ($srcHelp -ne '') {
                    $tHelp = Invoke-GeminiTranslate $srcHelp $lang
                }
                if (-not $tTitle -or $tTitle -eq '') { $tTitle = $srcTitle }
                if (-not $tHelp  -or $tHelp  -eq '') { $tHelp  = $srcHelp  }

                $safeTitle = $tTitle.Replace("'", "''")
                $safeHelp  = $tHelp.Replace("'", "''")
                $provider  = if ($env:AI_PROVIDER) { $env:AI_PROVIDER } else { 'gemini' }
                $model2    = if ($env:AI_MODEL)    { $env:AI_MODEL    } else { 'gemini-2.0-flash-lite' }
                $safeProvider = "$provider/$model2"

                $updSql = "UPDATE agency.category_filter_translations SET title='$safeTitle', help_text='$safeHelp', status='translated', provider='$safeProvider', updated_at=now() WHERE entity_type='$eType' AND entity_id='$eId'::uuid AND language_code='$lang' AND status='queued'"
                Invoke-AgencySql $updSql | Out-Null
                Write-Log "OK [$lang] $eType '$srcTitle' -> '$tTitle'"

            } catch {
                Write-Log "HATA [$lang] $eType $eId - $($_.Exception.Message)"
                # Satiri queued'da birak, bir sonraki iterasyonda tekrar denenecek
            }
        }

        # Rate-limit: 10 satir sonrasi kisa bekleme
        Start-Sleep -Milliseconds 1500

    } catch {
        Write-Log "Worker dongus hatasi: $($_.Exception.Message)"
        Add-Content -LiteralPath (Join-Path $root '.local/translation-error.log') `
            -Value "$(Get-Date -Format s) $($_.Exception.Message)" -Encoding UTF8
        Start-Sleep -Seconds 15
    }
}
