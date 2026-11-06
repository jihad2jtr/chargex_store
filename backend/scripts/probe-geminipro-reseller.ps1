$key = 'rsp_live_zfposT4Us2LMfhsm2RHDj9uDdV88oIbAFWZMRwljI40yn3RD'
$h = @{ 'X-API-Key' = $key }
$base = 'https://api-geminipro.ignorelist.com/api/reseller/v1'

foreach ($ep in @('account/info', 'account/balance', 'products')) {
  Write-Output "=== GET /$ep ==="
  try {
    $r = Invoke-RestMethod -Uri "$base/$ep" -Headers $h -TimeoutSec 20
    $r | ConvertTo-Json -Depth 6
  } catch {
    Write-Output ("ERR: " + $_.Exception.Message)
    if ($_.ErrorDetails) { Write-Output $_.ErrorDetails.Message }
  }
}
