# =============================================================================
# Plex-Specific Functions
# Folder structure, naming, and artwork handling
# Updated with Enhanced Error Logging
# =============================================================================

function New-PlexFolderStructure {
    <#
    .SYNOPSIS
        Creates Plex-compatible folder structure
    
    .PARAMETER ShowInfo
        Hashtable containing show metadata
    
    .PARAMETER OutputPath
        Base output directory
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ShowInfo,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    try {
        $title = $ShowInfo.Title
        
        # Determine base path
        if ($ShowInfo.Type -eq 'Movie' -and -not $ShowInfo.IsRelatedMovie) {
            # Standalone movie goes in Movies subfolder
            $moviesPath = Join-Path $OutputPath 'Movies'
            $showPath = Join-Path $moviesPath $title
            
            if (-not (Test-Path $moviesPath)) {
                try {
                    New-Item -Path $moviesPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-LogMessage "Created Movies directory" -Level Success -Category FileSystem -Source "New-PlexFolderStructure"
                }
                catch {
                    Write-ErrorLog -Message "Failed to create Movies directory" `
                        -ErrorRecord $_ `
                        -Category FileSystem `
                        -Context @{
                            MoviesPath = $moviesPath
                            OutputPath = $OutputPath
                            ShowTitle = $title
                        } `
                        -Source "New-PlexFolderStructure"
                    throw
                }
            }
            
            if (-not (Test-Path $showPath)) {
                try {
                    New-Item -Path $showPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-LogMessage "Created: $showPath" -Level Success -Category FileSystem -Source "New-PlexFolderStructure"
                }
                catch {
                    Write-ErrorLog -Message "Failed to create show directory" `
                        -ErrorRecord $_ `
                        -Category FileSystem `
                        -Context @{
                            ShowPath = $showPath
                            MoviesPath = $moviesPath
                            ShowTitle = $title
                        } `
                        -Source "New-PlexFolderStructure"
                    throw
                }
            }
        }
        else {
            # Series or related movie
            $showPath = Join-Path $OutputPath $title
            
            if (-not (Test-Path $showPath)) {
                try {
                    New-Item -Path $showPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-LogMessage "Created: $showPath" -Level Success -Category FileSystem -Source "New-PlexFolderStructure"
                }
                catch {
                    Write-ErrorLog -Message "Failed to create show directory" `
                        -ErrorRecord $_ `
                        -Category FileSystem `
                        -Context @{
                            ShowPath = $showPath
                            OutputPath = $OutputPath
                            ShowTitle = $title
                            ShowType = $ShowInfo.Type
                        } `
                        -Source "New-PlexFolderStructure"
                    throw
                }
            }
        }
        
        # Download artwork if enabled
        if ($script:DefaultConfig.Features.DownloadArtwork -and $ShowInfo.ImageUrl) {
            $posterPath = Join-Path $showPath 'poster.jpg'
            
            if (-not (Test-Path $posterPath)) {
                Get-Artwork -Url $ShowInfo.ImageUrl -SavePath $posterPath
            }
            else {
                Write-Verbose "Poster already exists: $posterPath"
            }
        }
        
        return $showPath
    }
    catch {
        Write-ErrorLog -Message "Failed to create Plex folder structure" `
            -ErrorRecord $_ `
            -Category FileSystem `
            -Context @{
                ShowTitle = $ShowInfo.Title
                ShowType = $ShowInfo.Type
                OutputPath = $OutputPath
                IsRelatedMovie = $ShowInfo.IsRelatedMovie
            } `
            -Source "New-PlexFolderStructure"
        
        throw
    }
}

function Format-PlexFileName {
    <#
    .SYNOPSIS
        Formats filename according to Plex naming conventions
    
    .PARAMETER Title
        Show title
    
    .PARAMETER Season
        Season number
    
    .PARAMETER Episode
        Episode number
    
    .PARAMETER EpisodeTitle
        Episode title
    
    .PARAMETER Extension
        File extension
    
    .PARAMETER Type
        Content type (Episode, Movie, Special)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [int]$Season = 1,
        
        [int]$Episode = 1,
        
        [string]$EpisodeTitle = '',
        
        [string]$Extension = '.mkv',
        
        [ValidateSet('Episode', 'Movie', 'Special')]
        [string]$Type = 'Episode',
        
        [string]$Quality = ''
    )
    
    try {
        # Get format from config
        $format = $script:DefaultConfig.NamingFormat.$Type
        
        # Replace placeholders
        $fileName = $format `
            -replace '\{Title\}', $Title `
            -replace '\{Season:D2\}', $Season.ToString('D2') `
            -replace '\{Episode:D2\}', $Episode.ToString('D2') `
            -replace '\{EpisodeTitle\}', $EpisodeTitle `
            -replace '\{Quality\}', $Quality `
            -replace '\{Year\}', ''
        
        # Sanitize filename
        $fileName = Remove-InvalidFileNameChars -Name $fileName
        
        # Remove extra spaces
        $fileName = $fileName -replace '\s+', ' '
        $fileName = $fileName.Trim()
        
        return "$fileName$Extension"
    }
    catch {
        Write-ErrorLog -Message "Failed to format Plex filename" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                Title = $Title
                Season = $Season
                Episode = $Episode
                EpisodeTitle = $EpisodeTitle
                Type = $Type
                Extension = $Extension
            } `
            -Source "Format-PlexFileName"
        
        # Return safe fallback
        return "$Title - S$($Season.ToString('D2'))E$($Episode.ToString('D2'))$Extension"
    }
}

function Get-Artwork {
    <#
    .SYNOPSIS
        Downloads artwork/poster image
    
    .PARAMETER Url
        Image URL
    
    .PARAMETER SavePath
        Path to save image
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [string]$SavePath
    )
    
    try {
        Write-LogMessage "Downloading artwork..." -Level Info -Category Network -Source "Get-Artwork"
        
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $SavePath)
        $webClient.Dispose()
        
        Write-LogMessage "Artwork saved: $SavePath" -Level Success -Category Network -Source "Get-Artwork"
        return $true
    }
    catch {
        Write-ErrorLog -Message "Failed to download artwork" `
            -ErrorRecord $_ `
            -Category Network `
            -Context @{
                URL = $Url
                SavePath = $SavePath
                SaveDirectory = (Split-Path $SavePath -Parent)
                SaveDirectoryExists = (Test-Path (Split-Path $SavePath -Parent))
            } `
            -Source "Get-Artwork"
        
        return $false
    }
}

function New-SeasonFolder {
    <#
    .SYNOPSIS
        Creates season subfolder
    
    .PARAMETER ShowPath
        Show base directory
    
    .PARAMETER Season
        Season number
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShowPath,
        
        [Parameter(Mandatory)]
        [int]$Season
    )
    
    try {
        $seasonFolder = "Season $($Season.ToString('D2'))"
        $seasonPath = Join-Path $ShowPath $seasonFolder
        
        if (-not (Test-Path $seasonPath)) {
            New-Item -Path $seasonPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-LogMessage "Created: $seasonFolder" -Level Success -Category FileSystem -Source "New-SeasonFolder"
        }
        
        return $seasonPath
    }
    catch {
        Write-ErrorLog -Message "Failed to create season folder" `
            -ErrorRecord $_ `
            -Category FileSystem `
            -Context @{
                ShowPath = $ShowPath
                Season = $Season
                SeasonFolder = "Season $($Season.ToString('D2'))"
                ShowPathExists = (Test-Path $ShowPath)
            } `
            -Source "New-SeasonFolder"
        
        throw
    }
}

function Move-MediaFile {
    <#
    .SYNOPSIS
        Moves media file to destination
    
    .PARAMETER SourcePath
        Source file path
    
    .PARAMETER DestinationPath
        Destination file path
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )
    
    $sourceName = Split-Path $SourcePath -Leaf
    $destName = Split-Path $DestinationPath -Leaf
    
    # Check if destination exists
    if (Test-Path $DestinationPath) {
        Write-LogMessage "SKIP: Target already exists - $destName" -Level Warning -Category FileSystem -Source "Move-MediaFile"
        return $false
    }
    
    # Validate source exists
    if (-not (Test-Path $SourcePath)) {
        Write-ErrorLog -Message "Source file not found" `
            -ErrorRecord $null `
            -Category Validation `
            -Context @{
                SourcePath = $SourcePath
                DestinationPath = $DestinationPath
                SourceName = $sourceName
            } `
            -Source "Move-MediaFile"
        
        return $false
    }
    
    try {
        # Ensure destination directory exists
        $destDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $destDir)) {
            Write-ErrorLog -Message "Destination directory does not exist" `
                -ErrorRecord $null `
                -Category Validation `
                -Context @{
                    DestinationDirectory = $destDir
                    DestinationPath = $DestinationPath
                    SourcePath = $SourcePath
                } `
                -Source "Move-MediaFile"
            
            return $false
        }
        
        Move-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
        Write-LogMessage "Moved: $sourceName -> $destName" -Level Success -Category FileSystem -Source "Move-MediaFile"
        return $true
    }
    catch {
        Write-ErrorLog -Message "Failed to move file: $sourceName" `
            -ErrorRecord $_ `
            -Category FileSystem `
            -Context @{
                SourcePath = $SourcePath
                DestinationPath = $DestinationPath
                SourceExists = (Test-Path $SourcePath)
                DestinationExists = (Test-Path $DestinationPath)
                DestinationDirectory = (Split-Path $DestinationPath -Parent)
                DestinationDirExists = (Test-Path (Split-Path $DestinationPath -Parent))
                SourceSize = (Get-Item $SourcePath -ErrorAction SilentlyContinue).Length
            } `
            -Source "Move-MediaFile"
        
        return $false
    }
}