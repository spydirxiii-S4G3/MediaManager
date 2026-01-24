# =============================================================================
# PlexAnimeTools Module Loader
# Loads configuration, private functions, and public functions
# =============================================================================

#Requires -Version 5.1

# Get module root path
$script:ModuleRoot = $PSScriptRoot

Write-Verbose "Loading PlexAnimeTools from: $script:ModuleRoot"

# =============================================================================
# Initialize Module Variables
# =============================================================================

# Configuration path
$script:ConfigPath = Join-Path $script:ModuleRoot 'Config'

# Logs path
$script:LogsPath = Join-Path $script:ModuleRoot 'Logs'

# Create Logs directory if it doesn't exist
if (-not (Test-Path $script:LogsPath)) {
    try {
        New-Item -Path $script:LogsPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created Logs directory: $script:LogsPath"
    }
    catch {
        Write-Warning "Failed to create Logs directory, falling back to module root"
        $script:LogsPath = $script:ModuleRoot
    }
}

# Load default configuration
$defaultConfigFile = Join-Path $script:ConfigPath 'default.json'
if (Test-Path $defaultConfigFile) {
    try {
        $script:DefaultConfig = Get-Content $defaultConfigFile -Raw | ConvertFrom-Json
        Write-Verbose "Default configuration loaded"
    }
    catch {
        Write-Warning "Failed to load default configuration: $_"
        # Create minimal fallback config
        $script:DefaultConfig = [PSCustomObject]@{
            TMDbAPIKey = "YOUR_TMDB_API_KEY_HERE"
            JikanRateLimit = 500
            TMDbRateLimit = 300
            VideoExtensions = @('.mkv', '.mp4', '.avi', '.m4v', '.mov', '.wmv', '.flv', '.webm', '.ts')
        }
    }
}
else {
    Write-Warning "Default configuration file not found: $defaultConfigFile"
    $script:DefaultConfig = [PSCustomObject]@{
        TMDbAPIKey = "YOUR_TMDB_API_KEY_HERE"
        JikanRateLimit = 500
        TMDbRateLimit = 300
        VideoExtensions = @('.mkv', '.mp4', '.avi', '.m4v', '.mov', '.wmv', '.flv', '.webm', '.ts')
    }
}

# Video file extensions
$script:VideoExtensions = $script:DefaultConfig.VideoExtensions

# Initialize log file in Logs directory
$script:LogFile = Join-Path $script:LogsPath "PlexAnimeTools_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# GUI log textbox reference (set when GUI is launched)
$script:GuiLogBox = $null

# Initialize processing log file (set by Start-ProcessingLog)
$script:ProcessingLogFile = $null

Write-Verbose "Log file: $script:LogFile"

# =============================================================================
# Global Error Handler - Captures ALL PowerShell errors
# =============================================================================

# Set up transcript to capture all console output
$script:TranscriptPath = Join-Path $script:LogsPath "Transcript_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    Start-Transcript -Path $script:TranscriptPath -Append -ErrorAction SilentlyContinue
    Write-Verbose "Transcript logging started: $script:TranscriptPath"
}
catch {
    Write-Verbose "Transcript already running or failed to start"
}

# Trap all errors
$ErrorActionPreference = 'Continue'

# Create a global error event handler
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($CommandName, $CommandLookupEventArgs)
    
    $errorMsg = "Command not found: $CommandName"
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [ERROR] $errorMsg"
        Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {}
}

# =============================================================================
# Load Private Functions
# =============================================================================

$privatePath = Join-Path $script:ModuleRoot 'Private'

if (Test-Path $privatePath) {
    $privateFiles = @(Get-ChildItem -Path "$privatePath\*.ps1" -ErrorAction SilentlyContinue)
    
    foreach ($import in $privateFiles) {
        try {
            Write-Verbose "Loading private function: $($import.Name)"
            . $import.FullName
        }
        catch {
            Write-Error "Failed to import private function $($import.FullName): $_"
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [ERROR] Failed to load private function: $($import.Name)`n  Exception: $($_.Exception.Message)"
            Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
        }
    }
    
    Write-Verbose "Loaded $($privateFiles.Count) private function(s)"
}
else {
    Write-Warning "Private functions directory not found: $privatePath"
}

# =============================================================================
# Load Public Functions
# =============================================================================

$publicPath = Join-Path $script:ModuleRoot 'Public'

if (Test-Path $publicPath) {
    $publicFiles = @(Get-ChildItem -Path "$publicPath\*.ps1" -ErrorAction SilentlyContinue)
    
    foreach ($import in $publicFiles) {
        try {
            Write-Verbose "Loading public function: $($import.Name)"
            . $import.FullName
        }
        catch {
            Write-Error "Failed to import public function $($import.FullName): $_"
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [ERROR] Failed to load public function: $($import.Name)`n  Exception: $($_.Exception.Message)"
            Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
        }
    }
    
    Write-Verbose "Loaded $($publicFiles.Count) public function(s)"
    
    # Export public functions
    Export-ModuleMember -Function $publicFiles.BaseName
}
else {
    Write-Warning "Public functions directory not found: $publicPath"
}

# =============================================================================
# Initialize Logging
# =============================================================================

try {
    $logHeader = @"
========================================
PlexAnimeTools Module v2.0.0
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Module Path: $script:ModuleRoot
Log File: $script:LogFile
Transcript: $script:TranscriptPath
========================================

"@
    $logHeader | Out-File -FilePath $script:LogFile -Force -Encoding UTF8
    Write-Verbose "Logging initialized"
}
catch {
    Write-Warning "Failed to initialize logging: $_"
}

# =============================================================================
# Module Cleanup on Exit
# =============================================================================

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    try {
        Stop-Transcript -ErrorAction SilentlyContinue
    }
    catch {}
}

# =============================================================================
# Module Loaded
# =============================================================================

Write-Verbose "PlexAnimeTools module loaded successfully"
Write-Host "PlexAnimeTools v2.0.0 loaded. Type 'Get-Command -Module PlexAnimeTools' to see available commands." -ForegroundColor Green
Write-Host "Logs directory: $script:LogsPath" -ForegroundColor Cyan
Write-Host "Active log: $script:LogFile" -ForegroundColor Cyan
Write-Host "Transcript: $script:TranscriptPath" -ForegroundColor Cyan