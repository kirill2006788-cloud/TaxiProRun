# Production smoke outline — КОРОЛИ ДОРОГ
# Usage:
#   .\scripts\smoke_e2e.ps1
#   .\scripts\smoke_e2e.ps1 -BaseUrl https://api.example.com
# Full manual steps: docs/SMOKE_E2E.md

param(
  [string]$BaseUrl = $(if ($env:API_BASE_URL) { $env:API_BASE_URL } else { 'http://161.104.19.23' })
)

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')

Write-Host "=== Smoke E2E outline ===" -ForegroundColor Cyan
Write-Host "API: $BaseUrl"
Write-Host ""

Write-Host "1) Health check..." -ForegroundColor Yellow
$healthPaths = @('/api/health', '/health', '/api/taxi/tariffs')
$ok = $false
foreach ($p in $healthPaths) {
  try {
    $uri = "$BaseUrl$p"
    $r = Invoke-WebRequest -Uri $uri -Method GET -TimeoutSec 15 -UseBasicParsing
    Write-Host "  OK $($r.StatusCode) $uri"
    $ok = $true
    break
  } catch {
    Write-Host "  skip $uri — $($_.Exception.Message)"
  }
}
if (-not $ok) {
  Write-Warning "No health endpoint responded. Check API_BASE_URL / VPN / firewall."
}

Write-Host ""
Write-Host "2) Manual checklist (devices required):" -ForegroundColor Yellow
@(
  '[ ] Passenger: OTP login, USE_MOCK_API=false'
  '[ ] Passenger: create cash order → note orderId'
  '[ ] Driver: online → accept → arrived → start → complete'
  '[ ] Passenger: rate trip; history shows order'
  '[ ] Admin: /admin/ sees order + client + driver'
  '[ ] Prod: OTP_DEBUG_LOG=0; no demo OTP'
) | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "Details: docs/SMOKE_E2E.md" -ForegroundColor Green
Write-Host "Monitoring: docs/MONITORING.md"
