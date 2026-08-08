# setup_custom_endpoint.ps1 — deterministic Hermes CLI + Desktop custom endpoint setup (WINDOWS)
# Replicable by humans & machines. Idempotent (safe to re-run).
#
# Usage (PowerShell):
#   .\setup_custom_endpoint.ps1 -BaseUrl "https://gateway.example.com/v1" -ApiKey "sk-xxx" -Model "org/model" [-Name "my-gateway"]
#
# One-liner (download & run):
#   iex ((New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/dedieko-priyadi/hermes-custom-endpoint-setup/main/setup_custom_endpoint.ps1"))

param(
    [Parameter(Mandatory = $true)][string]$BaseUrl,
    [Parameter(Mandatory = $true)][string]$ApiKey,
    [Parameter(Mandatory = $true)][string]$Model,
    [string]$Name = "custom-endpoint"
)

$ErrorActionPreference = "Stop"

# ── 0. Hermes installed? ─────────────────────────────────────────────────────
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Hermes..."
    irm https://hermes-agent.nousresearch.com/install.ps1 | iex
    # refresh PATH for this session
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}
if (-not (Get-Command hermes -ErrorAction SilentlyContinue)) {
    Write-Error "hermes not available after install. Reopen terminal and re-run."
}

Write-Host "=== [1/4] Configure model (CLI + Desktop shared config) ==="
hermes config set model.provider custom
hermes config set model.base_url $BaseUrl
hermes config set model.api_key $ApiKey
hermes config set model.default $Model
hermes config set model.api_mode chat_completions

Write-Host "=== [2/4] Register named custom provider ==="
hermes config set custom_providers.0.name $Name
hermes config set custom_providers.0.base_url $BaseUrl
hermes config set custom_providers.0.api_key $ApiKey
hermes config set custom_providers.0.model $Model
hermes config set custom_providers.0.api_mode chat_completions
hermes config set custom_providers.0.models.0 $Model

Write-Host "=== [3/4] Live endpoint test (real API call) ==="
$body = @{
    model    = $Model
    messages = @(@{ role = "user"; content = "ping" })
    max_tokens = 5
} | ConvertTo-Json -Depth 5
try {
    $resp = Invoke-RestMethod -Uri "$BaseUrl/chat/completions" `
        -Method Post -Headers @{ Authorization = "Bearer $ApiKey" } `
        -ContentType "application/json" -Body $body -TimeoutSec 30
    Write-Host "OK: endpoint responded 200"
} catch {
    Write-Warning "Endpoint test failed: $($_.Exception.Message)"
    Write-Warning "Config written anyway — fix endpoint, then re-run."
}

Write-Host "=== [4/4] Hermes self-test (CLI talks to endpoint) ==="
$out = hermes chat -q "Reply with exactly: CONNECTED" 2>&1 | Out-String
if ($out -match "CONNECTED") {
    Write-Host "OK: hermes chat connected via custom endpoint"
} else {
    Write-Warning "hermes self-test did not echo CONNECTED. Output: $out"
}

Write-Host ""
Write-Host "DONE. Config written to ~/.hermes/config.yaml"
Write-Host "Launch Desktop:  hermes desktop"
Write-Host "Desktop auto-uses this config (same file)."
Write-Host "Verify again anytime:  .\verify_custom_endpoint.ps1"
