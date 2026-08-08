# verify_custom_endpoint.ps1 — deterministic verification of Hermes custom endpoint setup (WINDOWS)
# Exit 0 = all checks pass. Non-zero = something wrong.
#
# Usage: .\verify_custom_endpoint.ps1  (values read from live config)

$ErrorActionPreference = "Continue"
$FAIL = 0

Write-Host "=== [1/4] Config check ==="
$provider = (hermes config get model.provider 2>$null) -join "" 
$baseUrl  = (hermes config get model.base_url 2>$null) -join ""
$model    = (hermes config get model.default 2>$null) -join ""
Write-Host "  provider : $provider"
Write-Host "  base_url : $baseUrl"
Write-Host "  model    : $model"
if ($provider -ne "custom") { Write-Host "  [X] provider != custom"; $FAIL = 1 } else { Write-Host "  [OK] provider=custom" }
if ([string]::IsNullOrWhiteSpace($baseUrl)) { Write-Host "  [X] base_url empty"; $FAIL = 1 } else { Write-Host "  [OK] base_url set" }
if ([string]::IsNullOrWhiteSpace($model)) { Write-Host "  [X] model empty"; $FAIL = 1 } else { Write-Host "  [OK] model set" }

Write-Host "=== [2/4] Endpoint live test ==="
$apiKey = (hermes config get model.api_key 2>$null) -join ""
$body = @{
    model    = $model
    messages = @(@{ role = "user"; content = "ping" })
    max_tokens = 5
} | ConvertTo-Json -Depth 5
try {
    $resp = Invoke-RestMethod -Uri "$baseUrl/chat/completions" `
        -Method Post -Headers @{ Authorization = "Bearer $apiKey" } `
        -ContentType "application/json" -Body $body -TimeoutSec 30
    Write-Host "  [OK] endpoint reachable"
} catch {
    Write-Host "  [X] endpoint failed: $($_.Exception.Message)"
    $FAIL = 1
}

Write-Host "=== [3/4] Hermes self-test ==="
$out = hermes chat -q "Reply with exactly: CONNECTED" 2>&1 | Out-String
if ($out -match "CONNECTED") { Write-Host "  [OK] CLI connected" } else { Write-Host "  [X] CLI failed: $($out.Substring(0, [Math]::Min(120, $out.Length)))"; $FAIL = 1 }

Write-Host "=== [4/4] Desktop config presence ==="
$cfgPath = Join-Path $env:USERPROFILE ".hermes\config.yaml"
if (Test-Path $cfgPath) { Write-Host "  [OK] config.yaml exists (Desktop reads it)" } else { Write-Host "  [X] config.yaml missing"; $FAIL = 1 }

Write-Host ""
if ($FAIL -eq 0) {
    Write-Host "ALL CHECKS PASSED - CLI + Desktop are connected to $baseUrl"
    exit 0
} else {
    Write-Host "$FAIL check(s) failed - see above. Re-run setup_custom_endpoint.ps1."
    exit 1
}
