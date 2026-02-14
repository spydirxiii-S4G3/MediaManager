# ===============================================================================
# PresetManager.ps1 - Save / Load Naming Presets & Application Settings
# ===============================================================================

$global:AppSettingsPath = ""
$global:PresetsFolder = ""

function Initialize-PresetManager {
    param([string]$SettingsPath = "")
    if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
        # Use the app root directory (set by Launch.ps1), fall back to script location
        $root = if ($global:AppRootDir) { $global:AppRootDir } else { $PSScriptRoot }
        $global:AppSettingsPath = Join-Path $root "settings.json"
        $global:PresetsFolder = Join-Path $root "Presets"
    } else {
        $global:AppSettingsPath = Join-Path $SettingsPath "settings.json"
        $global:PresetsFolder = Join-Path $SettingsPath "Presets"
    }
    if (-not (Test-Path $global:PresetsFolder)) {
        New-Item -Path $global:PresetsFolder -ItemType Directory -Force | Out-Null
    }
}

function Get-DefaultSettings {
    return @{
        LastFolder      = ""
        WindowWidth     = 1100
        WindowHeight    = 750
        WindowX         = -1
        WindowY         = -1
        ThemePreference = "System"  # "System", "Dark", "Light"
        LastPreset      = ""
        TvdbApiKey      = ""
        TmdbApiKey      = ""
        PresetSaveLocation = ""
        NamingTemplate  = "{show} - S{season}E{episode}"
    }
}

function Load-AppSettings {
    $defaults = Get-DefaultSettings
    $loadPath = $global:AppSettingsPath
    if ([string]::IsNullOrWhiteSpace($loadPath)) {
        $root = if ($global:AppRootDir) { $global:AppRootDir } else { $PSScriptRoot }
        $loadPath = Join-Path $root "settings.json"
    }
    if (Test-Path $loadPath) {
        try {
            $json = Get-Content $loadPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $settings = @{}
            foreach ($key in $defaults.Keys) {
                if ($json.PSObject.Properties.Name -contains $key) {
                    $settings[$key] = $json.$key
                } else {
                    $settings[$key] = $defaults[$key]
                }
            }
            return $settings
        } catch {
            return $defaults
        }
    }
    return $defaults
}

function Save-AppSettings {
    param([hashtable]$Settings)
    try {
        $savePath = $global:AppSettingsPath
        if ([string]::IsNullOrWhiteSpace($savePath)) {
            $root = if ($global:AppRootDir) { $global:AppRootDir } else { $PSScriptRoot }
            $savePath = Join-Path $root "settings.json"
        }
        $Settings | ConvertTo-Json -Depth 5 | Set-Content -Path $savePath -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

function Get-PresetTemplate {
    return @{
        Name               = "Default"
        ShowName           = ""
        SeasonNumber       = 1
        NamingTemplate     = "{show} - S{season}E{episode}"
        Separator          = " - "
        SortOrder          = "Name"
        SortDescending     = $false
        StartEpisode       = 1
        Extensions         = @(".mp4", ".avi", ".mkv", ".mov")
        EpisodeTitleSource = "None"  # "None","Parse","Manual","TVDB","TMDB"
        StripJunk          = $true
        RemoveBrackets     = $true
        ReplaceDotsUnders  = $true
        TrimWhitespace     = $true
        SeasonPad          = 2
        EpisodePad         = 2
        FileAction         = "Rename"  # "Rename","Copy","Move"
    }
}

function Save-Preset {
    param(
        [hashtable]$Preset,
        [string]$CustomFolder = ""
    )

    $folder = if ($CustomFolder -ne "") { $CustomFolder } else { $global:PresetsFolder }
    if (-not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    $safeName = $Preset.Name -replace '[^\w\-\. ]', '_'
    $filePath = Join-Path $folder "$safeName.json"

    try {
        $Preset | ConvertTo-Json -Depth 5 | Set-Content -Path $filePath -Encoding UTF8
        return $filePath
    } catch {
        return ""
    }
}

function Load-Preset {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return $null }
    try {
        $json = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $preset = @{}
        $template = Get-PresetTemplate
        foreach ($key in $template.Keys) {
            if ($json.PSObject.Properties.Name -contains $key) {
                $val = $json.$key
                # Convert arrays back
                if ($val -is [System.Object[]]) { $val = @($val) }
                $preset[$key] = $val
            } else {
                $preset[$key] = $template[$key]
            }
        }
        return $preset
    } catch {
        return $null
    }
}

function Get-AllPresets {
    param([string]$CustomFolder = "")
    $folder = if ($CustomFolder -ne "") { $CustomFolder } else { $global:PresetsFolder }
    if (-not (Test-Path $folder)) { return @() }

    $presets = @()
    Get-ChildItem -Path $folder -Filter "*.json" -File | ForEach-Object {
        $preset = Load-Preset -FilePath $_.FullName
        if ($preset) {
            $presets += @{ Name = $preset.Name; Path = $_.FullName; Data = $preset }
        }
    }
    return $presets
}

function Remove-Preset {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        Remove-Item -Path $FilePath -Force
        return $true
    }
    return $false
}
