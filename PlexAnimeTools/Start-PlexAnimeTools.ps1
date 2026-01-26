# =============================================================================
# Start-PlexAnimeTools.ps1
# Launcher script for PlexAnimeTools module
# Place this in the PlexAnimeTools base folder
# THIS FILE SHOULD NOT BE MODIFIED
# =============================================================================

#Requires -Version 5.1

<#
.SYNOPSIS
    Starts PlexAnimeTools module with GUI or CLI options.

.DESCRIPTION
    This launcher script handles module loading and provides easy access to
    PlexAnimeTools functionality. Run without parameters for interactive menu.

.PARAMETER GUI
    Launch the graphical user interface

.PARAMETER CLI
    Start in command-line mode with prompt

.PARAMETER Test
    Launch the comprehensive testing GUI

.PARAMETER Info
    Display module information and help

.EXAMPLE
    .\Start-PlexAnimeTools.ps1
    Shows interactive menu

.EXAMPLE
    .\Start-PlexAnimeTools.ps1 -GUI
    Launches GUI directly

.EXAMPLE
    .\Start-PlexAnimeTools.ps1 -Test
    Launches testing GUI
#>

[CmdletBinding(DefaultParameterSetName='Menu')]
param(
    [Parameter(ParameterSetName='GUI')]
    [switch]$GUI,
    
    [Parameter(ParameterSetName='CLI')]
    [switch]$CLI,
    
    [Parameter(ParameterSetName='Test')]
    [switch]$Test,
    
    [Parameter(ParameterSetName='Info')]
    [switch]$Info
)

# =============================================================================
# Functions
# =============================================================================

function Show-Banner {
    $banner = @"

Ã¢â€¢â€Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢â€”
Ã¢â€¢â€˜                                                           Ã¢â€¢â€˜
Ã¢â€¢â€˜              PlexAnimeTools v2.0.0                        Ã¢â€¢â€˜
Ã¢â€¢â€˜              Media Organization for Plex                  Ã¢â€¢â€˜
Ã¢â€¢â€˜                                                           Ã¢â€¢â€˜
Ã¢â€¢Å¡Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host ""
    Write-Host "  [1] Launch GUI (Graphical Interface)" -ForegroundColor Green
    Write-Host "  [2] CLI Mode (Command Line)" -ForegroundColor Green
    Write-Host "  [3] Quick Start Guide" -ForegroundColor Yellow
    Write-Host "  [4] Test Suite (Comprehensive Testing GUI)" -ForegroundColor Yellow
    Write-Host "  [5] Module Information" -ForegroundColor Cyan
    Write-Host "  [6] View README" -ForegroundColor Cyan
    Write-Host "  [0] Exit" -ForegroundColor Red
    Write-Host ""
}

function Show-QuickStart {
    Clear-Host
    Show-Banner
    
    Write-Host "QUICK START GUIDE" -ForegroundColor Cyan
    Write-Host "Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "1. ORGANIZE MEDIA (Preview Mode):" -ForegroundColor Yellow
    Write-Host "   Invoke-AnimeOrganize -Path 'D:\Downloads\Anime' -OutputPath 'D:\Plex\Anime' -WhatIf" -ForegroundColor White
    Write-Host ""
    
    Write-Host "2. ORGANIZE MEDIA (Execute):" -ForegroundColor Yellow
    Write-Host "   Invoke-AnimeOrganize -Path 'D:\Downloads\Anime' -OutputPath 'D:\Plex\Anime'" -ForegroundColor White
    Write-Host ""
    
    Write-Host "3. GET ANIME INFO:" -ForegroundColor Yellow
    Write-Host "   Get-AnimeInfo -Title 'Attack on Titan' -IncludeEpisodes" -ForegroundColor White
    Write-Host ""
    
    Write-Host "4. TEST PLEX COMPATIBILITY:" -ForegroundColor Yellow
    Write-Host "   Test-PlexScan -Path 'D:\Plex\Anime\ShowName' -Detailed" -ForegroundColor White
    Write-Host ""
    
    Write-Host "5. BATCH PROCESS FOLDERS:" -ForegroundColor Yellow
    Write-Host "   Get-ChildItem 'D:\Downloads' -Directory | Invoke-AnimeOrganize -OutputPath 'D:\Plex'" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-ModuleInfo {
    Clear-Host
    Show-Banner
    
    Write-Host "MODULE INFORMATION" -ForegroundColor Cyan
    Write-Host "Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â" -ForegroundColor Cyan
    Write-Host ""
    
    # Get module info
    $module = Get-Module PlexAnimeTools
    
    if ($module) {
        Write-Host "  Version:        " -NoNewline -ForegroundColor Gray
        Write-Host $module.Version -ForegroundColor White
        
        Write-Host "  Author:         " -NoNewline -ForegroundColor Gray
        Write-Host $module.Author -ForegroundColor White
        
        Write-Host "  Module Path:    " -NoNewline -ForegroundColor Gray
        Write-Host $module.ModuleBase -ForegroundColor White
        
        Write-Host ""
        Write-Host "  Available Commands:" -ForegroundColor Yellow
        
        $commands = Get-Command -Module PlexAnimeTools | Sort-Object Name
        foreach ($cmd in $commands) {
            Write-Host "    Ã¢â‚¬Â¢ " -NoNewline -ForegroundColor Gray
            Write-Host $cmd.Name -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "  Configuration Profiles:" -ForegroundColor Yellow
        
        $configPath = Join-Path $module.ModuleBase 'Config'
        if (Test-Path $configPath) {
            $configs = Get-ChildItem -Path $configPath -Filter "*.json"
            foreach ($config in $configs) {
                Write-Host "    Ã¢â‚¬Â¢ " -NoNewline -ForegroundColor Gray
                Write-Host $config.BaseName -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "  Module not loaded!" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Show-ReadMe {
    $readmePath = Join-Path $PSScriptRoot "README.md"
    
    if (Test-Path $readmePath) {
        try {
            Start-Process $readmePath
            Write-Host "Opening README.md..." -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host "Could not open README.md automatically." -ForegroundColor Yellow
            Write-Host "File location: $readmePath" -ForegroundColor Cyan
            Start-Sleep -Seconds 3
        }
    }
    else {
        Write-Host "README.md not found at: $readmePath" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

function Start-CLIMode {
    Clear-Host
    Show-Banner
    
    Write-Host "CLI MODE - Interactive PowerShell" -ForegroundColor Cyan
    Write-Host "Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "All PlexAnimeTools commands are available." -ForegroundColor White
    Write-Host "Type 'Get-Command -Module PlexAnimeTools' to see available commands." -ForegroundColor White
    Write-Host "Type 'exit' to return to menu." -ForegroundColor White
    Write-Host ""
    Write-Host "Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â" -ForegroundColor Cyan
    Write-Host ""
    
    # Interactive prompt
    while ($true) {
        Write-Host "PlexAnimeTools> " -NoNewline -ForegroundColor Green
        $command = Read-Host
        
        if ($command -eq 'exit' -or $command -eq 'quit') {
            break
        }
        
        if ([string]::IsNullOrWhiteSpace($command)) {
            continue
        }
        
        try {
            Invoke-Expression $command
        }
        catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

function Start-TestGUI {
    # Launches the comprehensive testing GUI
    # All test results are logged to Logs/Testing folder
    Start-TestingGUI
}

# =============================================================================
# Main Script
# =============================================================================

# Get script directory
$scriptPath = $PSScriptRoot
$modulePath = Join-Path $scriptPath "PlexAnimeTools.psd1"

# Check if module manifest exists
if (-not (Test-Path $modulePath)) {
    Write-Host "ERROR: PlexAnimeTools.psd1 not found!" -ForegroundColor Red
    Write-Host "Expected location: $modulePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please ensure this script is in the PlexAnimeTools base folder." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Import module
try {
    Write-Host "Loading PlexAnimeTools module..." -ForegroundColor Cyan
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "Module loaded successfully!" -ForegroundColor Green
    Write-Host ""
    Start-Sleep -Seconds 1
}
catch {
    Write-Host "ERROR: Failed to load module!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Handle parameter-based execution
if ($GUI) {
    Clear-Host
    Show-Banner
    Write-Host "Launching GUI..." -ForegroundColor Cyan
    Write-Host ""
    Start-Sleep -Seconds 1
    Start-PlexGUI
    exit 0
}

if ($CLI) {
    Start-CLIMode
    exit 0
}

if ($Test) {
    Clear-Host
    Show-Banner
    Write-Host "Launching Test Suite..." -ForegroundColor Cyan
    Write-Host ""
    Start-Sleep -Seconds 1
    Start-TestGUI
    exit 0
}

if ($Info) {
    Show-ModuleInfo
    exit 0
}

# Interactive menu mode (default)
while ($true) {
    Clear-Host
    Show-Banner
    Show-Menu
    
    Write-Host "Select an option: " -NoNewline -ForegroundColor Yellow
    $choice = Read-Host
    
    switch ($choice) {
        '1' {
            Clear-Host
            Show-Banner
            Write-Host "Launching GUI..." -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 1
            Start-PlexGUI
        }
        '2' {
            Start-CLIMode
        }
        '3' {
            Show-QuickStart
        }
        '4' {
            Clear-Host
            Show-Banner
            Write-Host "Launching Test Suite..." -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 1
            Start-TestGUI
        }
        '5' {
            Show-ModuleInfo
        }
        '6' {
            Show-ReadMe
        }
        '0' {
            Write-Host ""
            Write-Host "Exiting PlexAnimeTools..." -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 1
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "Invalid selection. Please choose 0-6." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}