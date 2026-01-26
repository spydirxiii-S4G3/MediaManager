Write-Host "" 
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PlexAnimeTools - Quick Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" 

Write-Host "[Test 1] Checking Module Files..." -ForegroundColor Yellow
if (Test-Path ".\PlexAnimeTools.psd1") { Write-Host "  ? Module Manifest" -ForegroundColor Green } else { Write-Host "  ? Module Manifest MISSING" -ForegroundColor Red }
if (Test-Path ".\PlexAnimeTools.psm1") { Write-Host "  ? Module Loader" -ForegroundColor Green } else { Write-Host "  ? Module Loader MISSING" -ForegroundColor Red }
Write-Host "" 

Write-Host "[Test 2] Checking Public Functions..." -ForegroundColor Yellow
if (Test-Path ".\Public\Start-SmartOrganize.ps1") { Write-Host "  ? Start-SmartOrganize.ps1" -ForegroundColor Green } else { Write-Host "  ? Start-SmartOrganize.ps1 MISSING" -ForegroundColor Red }
if (Test-Path ".\Public\Invoke-AnimeOrganize.ps1") { Write-Host "  ? Invoke-AnimeOrganize.ps1" -ForegroundColor Green } else { Write-Host "  ? Invoke-AnimeOrganize.ps1 MISSING" -ForegroundColor Red }
if (Test-Path ".\Public\Start-PlexGUI.ps1") { Write-Host "  ? Start-PlexGUI.ps1" -ForegroundColor Green } else { Write-Host "  ? Start-PlexGUI.ps1 MISSING" -ForegroundColor Red }
if (Test-Path ".\Public\Get-AnimeInfo.ps1") { Write-Host "  ? Get-AnimeInfo.ps1" -ForegroundColor Green } else { Write-Host "  ? Get-AnimeInfo.ps1 MISSING" -ForegroundColor Red }
if (Test-Path ".\Public\Test-PlexScan.ps1") { Write-Host "  ? Test-PlexScan.ps1" -ForegroundColor Green } else { Write-Host "  ? Test-PlexScan.ps1 MISSING" -ForegroundColor Red }
if (Test-Path ".\Public\Start-TestingGUI.ps1") { Write-Host "  ? Start-TestingGUI.ps1" -ForegroundColor Green } else { Write-Host "  ? Start-TestingGUI.ps1 MISSING" -ForegroundColor Red }
Write-Host "" 

Write-Host "[Test 3] Importing Module..." -ForegroundColor Yellow
try {
    Import-Module .\PlexAnimeTools.psd1 -Force -ErrorAction Stop
    Write-Host "  ? Module imported successfully" -ForegroundColor Green
    $commands = Get-Command -Module PlexAnimeTools
    Write-Host "    Exported functions: $($commands.Count)" -ForegroundColor Gray
    $commands | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
} catch {
    Write-Host "  ? Module import FAILED: $_" -ForegroundColor Red
}
Write-Host "" 

Write-Host "[Test 4] Checking Function Availability..." -ForegroundColor Yellow
if (Get-Command Start-SmartOrganize -ErrorAction SilentlyContinue) { Write-Host "  ? Start-SmartOrganize available" -ForegroundColor Green } else { Write-Host "  ? Start-SmartOrganize NOT AVAILABLE" -ForegroundColor Red }
if (Get-Command Invoke-AnimeOrganize -ErrorAction SilentlyContinue) { Write-Host "  ? Invoke-AnimeOrganize available" -ForegroundColor Green } else { Write-Host "  ? Invoke-AnimeOrganize NOT AVAILABLE" -ForegroundColor Red }
if (Get-Command Start-PlexGUI -ErrorAction SilentlyContinue) { Write-Host "  ? Start-PlexGUI available" -ForegroundColor Green } else { Write-Host "  ? Start-PlexGUI NOT AVAILABLE" -ForegroundColor Red }
if (Get-Command Get-AnimeInfo -ErrorAction SilentlyContinue) { Write-Host "  ? Get-AnimeInfo available" -ForegroundColor Green } else { Write-Host "  ? Get-AnimeInfo NOT AVAILABLE" -ForegroundColor Red }
if (Get-Command Test-PlexScan -ErrorAction SilentlyContinue) { Write-Host "  ? Test-PlexScan available" -ForegroundColor Green } else { Write-Host "  ? Test-PlexScan NOT AVAILABLE" -ForegroundColor Red }
if (Get-Command Start-TestingGUI -ErrorAction SilentlyContinue) { Write-Host "  ? Start-TestingGUI available" -ForegroundColor Green } else { Write-Host "  ? Start-TestingGUI NOT AVAILABLE" -ForegroundColor Red }
Write-Host "" 

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "? VALIDATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" 
