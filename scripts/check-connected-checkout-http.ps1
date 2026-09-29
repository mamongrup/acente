$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Get-Content -LiteralPath (Join-Path $root '.env') | ForEach-Object {
  $line = $_.Trim()
  $index = $line.IndexOf('=')
  if ($index -gt 0 -and !$line.StartsWith('#')) {
    Set-Item "Env:$($line.Substring(0,$index).Trim())" $line.Substring($index + 1).Trim()
  }
}
$pg = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe'
$pgArgs = @('-X','-w','-v','ON_ERROR_STOP=1','-At','-h',$env:PGHOST,
  '-p',$env:PGPORT,'-U',$env:PGUSER,'-d',$env:PGDATABASE)
$base = 'http://127.0.0.1:8082'
$listingId = $null
$localListingId = $null
$testContactSettingCreated = $false
$testClientIp = '2001:db8:' + (([guid]::NewGuid().ToString('N')).Substring(0,4)) + ':' + (([guid]::NewGuid().ToString('N')).Substring(0,4)) + '::1'
function Invoke-HttpSafe {
  param([string]$Uri, [string]$Method = 'Get', $Body, $WebSession, [hashtable]$Headers, [string]$ContentType)
  if ($Method -eq 'Get' -and -not $WebSession) {
    $raw = & curl.exe -s -i $Uri
    $headerText = ($raw -join "`n")
    $parts = $headerText -split "`r?`n`r?`n", 2
    $statusLine = ($parts[0] -split "`r?`n")[0]
    $statusCode = if ($statusLine -match 'HTTP/\S+\s+(\d+)') { [int]$matches[1] } else { 0 }
    $content = if ($parts.Length -gt 1) { $parts[1] } else { '' }
    return [PSCustomObject]@{
      StatusCode = $statusCode
      Content = $content
    }
  }
  $params = @{ Uri = $Uri; Method = $Method; UseBasicParsing = $true }
  if ($Body) { $params['Body'] = $Body }
  if ($WebSession) { $params['WebSession'] = $WebSession }
  if ($Headers) { $params['Headers'] = $Headers }
  if ($ContentType) { $params['ContentType'] = $ContentType }
  try {
    return Invoke-WebRequest @params
  } catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp) {
      $content = if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        $_.ErrorDetails.Message
      } else {
        (New-Object System.IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
      }
      return [PSCustomObject]@{
        StatusCode = [int]$resp.StatusCode
        Content = $content
      }
    }
    throw
  }
}

try {
  $supportedId = & $pg @pgArgs -c "select l.id from agency.listings l join agency.tenants t on t.id=l.tenant_id where t.slug='nexus-demo' and l.status='published' and l.category='hotel' and l.currency='TRY' limit 1"
  if ($LASTEXITCODE -ne 0 -or !$supportedId) { throw 'Supported checkout fixture missing' }
  $sql = @"
insert into agency.listings(tenant_id,code,category,title,locality,description,currency,price_minor,status,source,metadata,images,owner_info,cancellation_policy)
select id,'http-gate-'||gen_random_uuid(),'tour','HTTP gate tour','Antalya','HTTP gate fixture','TRY',10000,'published','nexus',
  jsonb_build_object('contract_fields',jsonb_build_object('tour_type','Culture','duration','1 day','start_point','Antalya')),
  jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),
  jsonb_build_object('provider','HTTP gate fixture'),jsonb_build_object('policy','Standard')
from agency.tenants where slug='nexus-demo' returning id;
"@
  $listingId = @(& $pg @pgArgs -c $sql) | Where-Object { $_ -match '^[0-9a-f-]{36}$' } | Select-Object -First 1
  if ($LASTEXITCODE -ne 0 -or !$listingId) { throw 'Connected checkout fixture failed' }
  $localSql = $sql.Replace("'http-gate-'", "'http-local-gate-'").Replace("'HTTP gate tour'", "'HTTP local gate tour'").Replace("'nexus',", "'manual',")
  $localListingId = @(& $pg @pgArgs -c $localSql) | Where-Object { $_ -match '^[0-9a-f-]{36}$' } | Select-Object -First 1
  if ($LASTEXITCODE -ne 0 -or !$localListingId) { throw 'Local checkout fixture failed' }
  $detail = Invoke-WebRequest -Uri "$base/urunler/$listingId`?tenant=nexus-demo" -UseBasicParsing
  if ($detail.Content -notmatch 'name="tenant"' -or $detail.Content -notmatch 'action="/iletisim"' `
    -or $detail.Content -notmatch 'Rezervasyon teklifi iste') {
    throw 'Connected product detail did not show the inquiry action'
  }
  $localDetail = Invoke-WebRequest -Uri "$base/urunler/$localListingId`?tenant=nexus-demo" -UseBasicParsing
  if ($localDetail.Content -notmatch 'action="/rezervasyon"') { throw 'Local tour lost checkout action' }
  $checkIn = (Get-Date).AddDays(2).ToString('yyyy-MM-dd')
  $checkOut = (Get-Date).AddDays(3).ToString('yyyy-MM-dd')
  $blocked = Invoke-HttpSafe -Uri "$base/rezervasyon?listing=$listingId&tenant=nexus-demo&check_in=$checkIn&check_out=$checkOut&guests=3"
  if ([int]$blocked.StatusCode -ne 409 -or $blocked.Content -notmatch 'Rezervasyon talebi g&#246;nderin' `
    -or $blocked.Content -notmatch "/iletisim\?listing=$listingId&amp;tenant=" `
    -or $blocked.Content -notmatch "amp;check_in=$checkIn&amp;check_out=$checkOut&amp;guests=3") {
    throw "Connected checkout GET gate failed: $([int]$blocked.StatusCode)"
  }
  $contact = Invoke-WebRequest -Uri "$base/iletisim?listing=$listingId&tenant=nexus-demo&check_in=$checkIn&check_out=$checkOut&guests=3" -UseBasicParsing
  if ($contact.Content -notmatch ('name="listing_id"[^>]*value="' + $listingId + '"') `
    -or $contact.Content -notmatch ('name="check_in"[^>]*value="' + $checkIn + '"') `
    -or $contact.Content -notmatch ('name="check_out"[^>]*value="' + $checkOut + '"') `
    -or $contact.Content -notmatch 'name="guest_count"[^>]*value="3"') {
    throw 'Connected listing or travel details were not preserved in the contact form'
  }
  $contact = Invoke-WebRequest -Uri "$base/iletisim?listing=$listingId&tenant=nexus-demo" -UseBasicParsing -SessionVariable inquirySession
  $inquiryCsrf = [regex]::Match($contact.Content,'name="csrf_token"[^>]*value="([^"]+)"').Groups[1].Value
  if (!$inquiryCsrf) { throw 'Inquiry CSRF token missing' }
  $contactSettingCount = & $pg @pgArgs -c "select count(*) from agency.settings s join agency.tenants t on t.id=s.tenant_id where t.slug='nexus-demo' and s.key='contact_email'"
  if ($LASTEXITCODE -ne 0 -or $contactSettingCount -ne '0') { throw 'Test tenant contact email is configured; refusing to send a test notification' }
  & $pg @pgArgs -c "insert into agency.settings(tenant_id,key,value) select id,'contact_email',to_jsonb('inquiry-gate@example.invalid'::text) from agency.tenants where slug='nexus-demo'" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Test contact setting failed' }
  $testContactSettingCreated = $true
  $inquiryForm = @{
    listing_id = $listingId; tenant = 'nexus-demo'; name = 'Inquiry Gate Test'
    email = 'customer-inquiry@example.invalid'; phone = ''; message = 'Test inquiry'
    check_in = $checkIn; check_out = $checkOut; guest_count = '3'; website = ''
    idempotency_key = "inquiry-gate-$([guid]::NewGuid())"; csrf_token = $inquiryCsrf
  }
  foreach ($attempt in 1..2) {
    $inquiryResponse = Invoke-HttpSafe -Uri "$base/iletisim" -Method Post -Body $inquiryForm `
      -WebSession $inquirySession -Headers @{Accept='application/json';'X-Forwarded-For'=$testClientIp} `
      -ContentType 'application/x-www-form-urlencoded'
    if ([int]$inquiryResponse.StatusCode -ne 200 -or $inquiryResponse.Content -notmatch '"ok":true') {
      throw "Inquiry POST failed on attempt $attempt`: $([int]$inquiryResponse.StatusCode)"
    }
  }
  $inquiryCount = & $pg @pgArgs -c "select count(*) from agency.public_inquiries where listing_id='$listingId'::uuid"
  $notificationCount = & $pg @pgArgs -c "select count(*) from agency.notifications where payload->>'listing_id'='$listingId' and payload->>'to'='inquiry-gate@example.invalid' and payload->>'email'='inquiry-gate@example.invalid' and payload->>'customer_email'='customer-inquiry@example.invalid'"
  if ($inquiryCount -ne '1' -or $notificationCount -ne '1') {
    throw "Inquiry idempotency failed: $inquiryCount inquiries, $notificationCount notifications"
  }
  $foreignId = & $pg @pgArgs -c "select l.id from agency.listings l join agency.tenants t on t.id=l.tenant_id where t.slug='test-agency' and l.status='published' limit 1"
  if ($LASTEXITCODE -ne 0 -or !$foreignId) { throw 'Foreign tenant fixture missing' }
  $inquiryForm.listing_id = $foreignId
  $inquiryForm.idempotency_key = "foreign-inquiry-gate-$([guid]::NewGuid())"
  $foreignResponse = Invoke-HttpSafe -Uri "$base/iletisim" -Method Post -Body $inquiryForm `
    -WebSession $inquirySession -Headers @{Accept='application/json';'X-Forwarded-For'=$testClientIp} `
    -ContentType 'application/x-www-form-urlencoded'
  if ([int]$foreignResponse.StatusCode -ne 400) { throw "Foreign listing inquiry returned $([int]$foreignResponse.StatusCode) instead of 400" }
  $supported = Invoke-WebRequest -Uri "$base/rezervasyon?listing=$supportedId&tenant=nexus-demo" -UseBasicParsing -SessionVariable session
  $supportedDetail = Invoke-WebRequest -Uri "$base/urunler/$supportedId`?tenant=nexus-demo" -UseBasicParsing
  if ($supportedDetail.Content -notmatch 'action="/rezervasyon"') { throw 'Supported product lost checkout action' }
  $csrf = [regex]::Match($supported.Content,'name="csrf_token"[^>]*value="([^"]+)"').Groups[1].Value
  if (!$csrf) { throw 'CSRF token missing' }
  $form = @{
    listing_id = $listingId; tenant = 'nexus-demo'; name = 'Gate Test'
    email = 'gate@example.invalid'; phone = ''
    check_in = (Get-Date).AddDays(2).ToString('yyyy-MM-dd')
    check_out = (Get-Date).AddDays(3).ToString('yyyy-MM-dd')
    guest_count = '2'; idempotency_key = "gate-$([guid]::NewGuid())"; csrf_token = $csrf
  }
  $response = Invoke-HttpSafe -Uri "$base/api/public/checkout/start" -Method Post -Body $form `
    -WebSession $session -ContentType 'application/x-www-form-urlencoded'
  if ([int]$response.StatusCode -ne 409 -or $response.Content -notmatch '"ok":false') {
    throw "Connected checkout POST gate failed: $([int]$response.StatusCode)"
  }
  $orderCount = & $pg @pgArgs -c "select count(*) from agency.orders o join agency.reservations r on r.id=o.reservation_id where r.listing_id='$listingId'::uuid"
  if ($LASTEXITCODE -ne 0 -or $orderCount -ne '0') { throw 'Connected checkout created an order' }
  & $pg @pgArgs -c "update agency.listings set currency='EUR' where id='$listingId'::uuid" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Currency fixture update failed' }
  $foreignCurrency = Invoke-HttpSafe -Uri "$base/rezervasyon?listing=$listingId&tenant=nexus-demo"
  if ([int]$foreignCurrency.StatusCode -ne 409) { throw 'Connected non-TRY listing bypassed the inquiry gate' }
  Write-Output 'Connected checkout HTTP GET/POST gates passed; no order created.'
} finally {
  if ($listingId) {
    & $pg @pgArgs -c "delete from agency.notifications where payload->>'listing_id'='$listingId'; delete from agency.public_inquiries where listing_id='$listingId'::uuid" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Inquiry fixture cleanup failed' }
    & $pg @pgArgs -c "delete from agency.listings where id='$listingId'::uuid" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Connected checkout fixture cleanup failed' }
  }
  if ($localListingId) {
    & $pg @pgArgs -c "delete from agency.listings where id='$localListingId'::uuid" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Local checkout fixture cleanup failed' }
  }
  if ($testContactSettingCreated) {
    & $pg @pgArgs -c "delete from agency.settings s using agency.tenants t where s.tenant_id=t.id and t.slug='nexus-demo' and s.key='contact_email' and s.value=to_jsonb('inquiry-gate@example.invalid'::text)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Test contact setting cleanup failed' }
  }
}
