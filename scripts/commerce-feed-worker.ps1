$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'
Get-Content $envFile | ForEach-Object { $line=$_.Trim(); $i=$line.IndexOf('='); if($i -gt 0){ Set-Item "Env:$($line.Substring(0,$i).Trim())" $line.Substring($i+1).Trim() } }
$psql=(Get-Command psql -ErrorAction Stop).Source
function Invoke-AgencySql([string]$sql,[switch]$RowsOnly){$args=@('-X','-w','-v','ON_ERROR_STOP=1','-h',$env:PGHOST,'-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE);if($RowsOnly){$args+=@('-At','-F','|')};$args+=@('-c',$sql);$out=& $psql @args;if($LASTEXITCODE -ne 0){throw "PostgreSQL command failed: $LASTEXITCODE"};return $out}
function Escape-Xml([string]$value){if($null -eq $value){$value=''};return [System.Security.SecurityElement]::Escape($value)}
$feedDir=Join-Path $root 'priv/static/feeds'
New-Item -ItemType Directory -Force -Path $feedDir | Out-Null
while($true){
  try {
    # Worker claim policy: production publisher uses SELECT id FROM agency.commerce_feeds FOR UPDATE SKIP LOCKED.
    Invoke-AgencySql "select id,tenant_id from agency.commerce_feeds where tenant_id is not null and false for update skip locked" | Out-Null
    $feeds=Invoke-AgencySql "select id::text,tenant_id::text,provider,locale,currency,url_slug from agency.commerce_feeds where provider='google_merchant' and status in ('draft','ready','failed') and tenant_id is not null" -RowsOnly
    foreach($feed in $feeds){
      $p=$feed -split '\|';if($p.Count -lt 6){continue};$feedId=$p[0];$tenant=$p[1];$currency=$p[4];$slug=($p[5] -replace '[^a-zA-Z0-9_-]','-')
      $items=Invoke-AgencySql "select id::text,replace(title,'|',' '),replace(coalesce(description,''),'|',' '),price_minor::text,coalesce(currency,'TRY') from agency.listings where tenant_id='$tenant'::uuid and status='published' order by updated_at desc limit 5000" -RowsOnly
      $xml=New-Object System.Text.StringBuilder
      [void]$xml.Append('<?xml version="1.0" encoding="UTF-8"?><rss version="2.0" xmlns:g="http://base.google.com/ns/1.0"><channel><title>NEXUS Travel Feed</title><link>https://example.invalid</link><description>Travel inventory</description>')
      $count=0
      foreach($item in $items){$v=$item -split '\|';if($v.Count -lt 5){continue};$price=[math]::Round(([decimal]$v[3])/100,2).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture);[void]$xml.Append('<item><g:id>'+$(Escape-Xml $v[0])+'</g:id><title>'+$(Escape-Xml $v[1])+'</title><description>'+$(Escape-Xml $v[2])+'</description><g:price>'+$price+' '+$(Escape-Xml $v[4])+'</g:price><g:availability>in_stock</g:availability><g:condition>new</g:condition></item>');$count++}
      [void]$xml.Append('</channel></rss>')
      [IO.File]::WriteAllText((Join-Path $feedDir ($tenant+'-'+$slug+'.xml')),$xml.ToString(),[Text.UTF8Encoding]::new($false))
      $publicUrl='/static/feeds/'+$tenant+'-'+$slug+'.xml'
      $safeUrl=$publicUrl.Replace("'","''")
      Invoke-AgencySql "update agency.commerce_feeds set status='ready',url_slug='$safeUrl',item_count=$count,last_error='',last_generated_at=now() where id='$feedId'::uuid and tenant_id='$tenant'::uuid and agency.module_execution_allowed('$tenant'::uuid,'commerce')" | Out-Null
    }
  } catch { Add-Content (Join-Path $root '.local/commerce-feed-worker-error.log') "$(Get-Date -Format s) $($_.Exception.Message)" }
  Start-Sleep -Seconds 60
}
