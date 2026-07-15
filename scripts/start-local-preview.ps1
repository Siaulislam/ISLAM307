# ISLAM 307 — Local Chrome preview (same idea as XMONEY on localhost:5500)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Port = 5500

Set-Location $Root

Write-Host ""
Write-Host "ISLAM 307 local preview" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host "Folder: $Root"
Write-Host ""
Write-Host "Open in Chrome:" -ForegroundColor Cyan
Write-Host "  http://localhost:$Port/preview/" -ForegroundColor Yellow
Write-Host "  http://localhost:$Port/design/mockups/index.html" -ForegroundColor Yellow
Write-Host "  http://localhost:$Port/design/mockups/phase3-mockups.html" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor DarkGray
Write-Host ""

$previewUrl = "http://localhost:$Port/preview/"
Start-Process "chrome.exe" $previewUrl -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) {
  Start-Process "msedge.exe" $previewUrl -ErrorAction SilentlyContinue
}

python -m http.server $Port --bind 127.0.0.1
