# ===============================================================================
#  Media File Renamer - Launcher
#  A professional TV show episode file renaming tool with GUI
# ===============================================================================
#
#  USAGE:   Right-click -> Run with PowerShell
#           OR:  powershell -ExecutionPolicy Bypass -File "Launch.ps1"
#
# ===============================================================================

$ErrorActionPreference = "Stop"

# -- Resolve script location --------------------------------------------------
# Handle different launch methods (right-click, terminal, ISE, shortcut)
try {
    if ($PSScriptRoot) {
        $ScriptDir = $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    } elseif ($MyInvocation.MyCommand.Definition) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    } else {
        $ScriptDir = (Get-Location).Path
    }
} catch {
    $ScriptDir = (Get-Location).Path
}

# Make sure we're in the right directory
Set-Location $ScriptDir

Write-Host ""
Write-Host "  Media File Renamer" -ForegroundColor Cyan
Write-Host "  Loading from: $ScriptDir" -ForegroundColor DarkGray
Write-Host ""

# -- Load assemblies ----------------------------------------------------------
try {
    Write-Host "  Loading assemblies..." -ForegroundColor DarkGray
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic
} catch {
    Write-Host ""
    Write-Host "  ERROR: Failed to load .NET assemblies." -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# -- Share root dir globally for modules --------------------------------------
$global:AppRootDir = $ScriptDir
$ModulesDir = Join-Path $ScriptDir "Modules"

# -- Validate folder structure ------------------------------------------------
if (-not (Test-Path $ModulesDir)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Cannot find the Modules folder.`n`nExpected at:`n$ModulesDir`n`nMake sure you extracted the full zip and kept the folder structure intact.",
        "Media File Renamer",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

$requiredModules = @(
    "ThemeManager.ps1",
    "FileScanner.ps1",
    "NameParser.ps1",
    "NameBuilder.ps1",
    "Renamer.ps1",
    "PresetManager.ps1",
    "ApiLookup.ps1",
    "LogExporter.ps1"
)

$missing = @()
foreach ($mod in $requiredModules) {
    $modPath = Join-Path $ModulesDir $mod
    if (-not (Test-Path $modPath)) {
        $missing += $mod
    }
}

if ($missing.Count -gt 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "Missing module files:`n`n$($missing -join "`n")`n`nExpected in:`n$ModulesDir",
        "Media File Renamer",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

# -- Load modules one by one with error reporting -----------------------------
foreach ($mod in $requiredModules) {
    $modPath = Join-Path $ModulesDir $mod
    Write-Host "  Loading $mod" -ForegroundColor DarkGray
    try {
        . $modPath
    } catch {
        Write-Host ""
        Write-Host "  ERROR loading ${mod}:" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        [System.Windows.Forms.MessageBox]::Show(
            "Error loading module: $mod`n`n$($_.Exception.Message)",
            "Media File Renamer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Write-Host "  Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# -- Launch main form ---------------------------------------------------------
$mainFormPath = Join-Path $ScriptDir "MainForm.ps1"
if (-not (Test-Path $mainFormPath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Cannot find MainForm.ps1`n`nExpected at:`n$mainFormPath",
        "Media File Renamer",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

Write-Host "  Launching GUI..." -ForegroundColor Green
Write-Host ""

try {
    . $mainFormPath
} catch {
    Write-Host ""
    Write-Host "  ===============================================" -ForegroundColor Red
    Write-Host "  ERROR: Application crashed" -ForegroundColor Red
    Write-Host "  ===============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Source:  $($_.InvocationInfo.ScriptName)" -ForegroundColor Yellow
    Write-Host "  Line:    $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host ""
    
    try {
        [System.Windows.Forms.MessageBox]::Show(
            "Application error:`n`n$($_.Exception.Message)`n`nFile: $(Split-Path $_.InvocationInfo.ScriptName -Leaf)`nLine: $($_.InvocationInfo.ScriptLineNumber)",
            "Media File Renamer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } catch { }
    
    Write-Host "  Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
