# =============================================================================
# Content Detection Functions
# Automatic detection of anime, TV shows, cartoons, and movies
# Updated with Enhanced Error Logging
# =============================================================================

function Test-ContentType {
    <#
    .SYNOPSIS
        Detects content type from folder
    
    .PARAMETER FolderPath
        Path to folder
    
    .PARAMETER AssumeAnime
        Assume anime unless proven otherwise (better default for anime libraries)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath,
        
        [switch]$AssumeAnime
    )
    
    if (-not (Test-Path $FolderPath)) {
        Write-ErrorLog -Message "Folder not found for content detection" `
            -ErrorRecord $null `
            -Category Validation `
            -Context @{
                FolderPath = $FolderPath
                ParentPath = (Split-Path $FolderPath -Parent)
                ParentExists = (Test-Path (Split-Path $FolderPath -Parent))
                AssumeAnime = $AssumeAnime
            } `
            -Source "Test-ContentType"
        
        return 'Unknown'
    }
    
    try {
        # Get video files
        $files = Get-ChildItem -Path $FolderPath -File -Recurse -ErrorAction Stop | Where-Object {
            $script:VideoExtensions -contains $_.Extension.ToLower()
        }
        
        $folderName = Split-Path $FolderPath -Leaf
        
        # Movie detection - single file with movie keyword or year
        if ($files.Count -eq 1) {
            $movieKeywords = $script:DefaultConfig.AutoDetection.MovieKeywords
            $hasMovieKeyword = $false
            
            foreach ($keyword in $movieKeywords) {
                if ($folderName -match "\b$keyword\b") {
                    $hasMovieKeyword = $true
                    break
                }
            }
            
            # Year in parentheses also indicates movie
            if ($folderName -match '\(\d{4}\)' -or $hasMovieKeyword) {
                Write-Verbose "Single file with movie indicator - likely a movie"
                return 'Movie'
            }
        }
        
        # Anime detection - keywords (check first, most specific)
        $animeKeywords = $script:DefaultConfig.AutoDetection.AnimeKeywords
        foreach ($keyword in $animeKeywords) {
            if ($folderName -match "\b$keyword\b") {
                Write-Verbose "Anime keyword detected: $keyword"
                return 'Anime'
            }
        }
        
        # Anime detection - release groups (very strong indicator)
        $animeGroups = $script:DefaultConfig.AutoDetection.AnimeGroups
        foreach ($group in $animeGroups) {
            if ($folderName -match "\[$group\]" -or $folderName -match "\b$group\b") {
                Write-Verbose "Anime release group detected: $group"
                return 'Anime'
            }
        }
        
        # Check file names for anime indicators
        foreach ($file in $files) {
            $fileName = $file.BaseName
            
            # Check for anime groups in filenames
            foreach ($group in $animeGroups) {
                if ($fileName -match "\[$group\]") {
                    Write-Verbose "Anime group found in filename: $group"
                    return 'Anime'
                }
            }
            
            # Check for common anime patterns
            if ($fileName -match '\[.*?\].*?\d{2,3}') {
                Write-Verbose "Anime naming pattern detected in filename"
                return 'Anime'
            }
        }
        
        # Cartoon detection
        if ($folderName -match '\b(cartoon|animation|animated)\b') {
            Write-Verbose "Cartoon keyword detected"
            return 'Cartoon'
        }
        
        # Western TV show indicators
        if ($folderName -match '\b(Season|Series|Complete)\b' -and $folderName -notmatch '\b(anime|ova|ona)\b') {
            Write-Verbose "Western TV series indicator detected"
            return 'TV Series'
        }
        
        # If processing from an "Anime" library path, default to Anime
        if ($FolderPath -match '\\Anime\\' -or $FolderPath -match '/Anime/') {
            Write-Verbose "Path contains 'Anime' directory - defaulting to Anime"
            return 'Anime'
        }
        
        # If AssumeAnime switch is set, default to Anime
        if ($AssumeAnime) {
            Write-Verbose "AssumeAnime flag set - defaulting to Anime"
            return 'Anime'
        }
        
        # Multiple files without clear indicators - default to Anime for anime libraries
        if ($files.Count -gt 1) {
            Write-Verbose "Multiple files detected - defaulting to Anime"
            return 'Anime'
        }
        
        # Last resort - default to TV Series
        Write-Verbose "No specific indicators - defaulting to TV Series"
        return 'TV Series'
    }
    catch {
        Write-ErrorLog -Message "Error during content type detection" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FolderPath = $FolderPath
                FolderName = (Split-Path $FolderPath -Leaf)
                AssumeAnime = $AssumeAnime
                FolderExists = (Test-Path $FolderPath)
            } `
            -Source "Test-ContentType"
        
        return 'Unknown'
    }
}

function Get-VideoFiles {
    <#
    .SYNOPSIS
        Gets all video files from a path
    
    .PARAMETER Path
        Path to search
    
    .PARAMETER Recurse
        Search recursively
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$Recurse
    )
    
    try {
        $params = @{
            Path = $Path
            File = $true
            ErrorAction = 'Stop'
        }
        
        if ($Recurse) {
            $params.Recurse = $true
        }
        
        $files = Get-ChildItem @params | Where-Object {
            $script:VideoExtensions -contains $_.Extension.ToLower()
        } | Sort-Object FullName
        
        Write-Verbose "Found $($files.Count) video file(s) in: $Path"
        
        return $files
    }
    catch {
        Write-ErrorLog -Message "Error getting video files from path" `
            -ErrorRecord $_ `
            -Category FileSystem `
            -Context @{
                Path = $Path
                Recurse = $Recurse
                PathExists = (Test-Path $Path)
                VideoExtensions = ($script:VideoExtensions -join ', ')
            } `
            -Source "Get-VideoFiles"
        
        return @()
    }
}

function Test-IsAnime {
    <#
    .SYNOPSIS
        Checks if content is likely anime
    
    .PARAMETER FolderName
        Folder name to check
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FolderName
    )
    
    try {
        $animeKeywords = $script:DefaultConfig.AutoDetection.AnimeKeywords
        $animeGroups = $script:DefaultConfig.AutoDetection.AnimeGroups
        
        # Check keywords
        foreach ($keyword in $animeKeywords) {
            if ($FolderName -match "\b$keyword\b") {
                return $true
            }
        }
        
        # Check release groups
        foreach ($group in $animeGroups) {
            if ($FolderName -match "\[$group\]" -or $FolderName -match "\b$group\b") {
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-ErrorLog -Message "Error checking if content is anime" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FolderName = $FolderName
                AnimeKeywords = ($script:DefaultConfig.AutoDetection.AnimeKeywords -join ', ')
            } `
            -Source "Test-IsAnime"
        
        return $false
    }
}

function Test-IsMovie {
    <#
    .SYNOPSIS
        Checks if content is likely a movie
    
    .PARAMETER FolderPath
        Folder path to check
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath
    )
    
    try {
        # Check file count
        $files = Get-VideoFiles -Path $FolderPath
        if ($files.Count -eq 1) {
            return $true
        }
        
        # Check keywords
        $folderName = Split-Path $FolderPath -Leaf
        $movieKeywords = $script:DefaultConfig.AutoDetection.MovieKeywords
        
        foreach ($keyword in $movieKeywords) {
            if ($folderName -match "\b$keyword\b") {
                return $true
            }
        }
        
        # Check for year
        if ($folderName -match '\(\d{4}\)') {
            return $true
        }
        
        return $false
    }
    catch {
        Write-ErrorLog -Message "Error checking if content is movie" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FolderPath = $FolderPath
                FolderName = (Split-Path $FolderPath -Leaf)
                PathExists = (Test-Path $FolderPath)
            } `
            -Source "Test-IsMovie"
        
        return $false
    }
}

function Get-FolderSummary {
    <#
    .SYNOPSIS
        Gets summary information about a folder
    
    .PARAMETER FolderPath
        Folder to analyze
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath
    )
    
    try {
        $files = Get-VideoFiles -Path $FolderPath -Recurse
        $folderName = Split-Path $FolderPath -Leaf
        $contentType = Test-ContentType -FolderPath $FolderPath
        
        return [PSCustomObject]@{
            Path = $FolderPath
            Name = $folderName
            FileCount = $files.Count
            ContentType = $contentType
            TotalSize = ($files | Measure-Object -Property Length -Sum).Sum
            Extensions = ($files | Select-Object -ExpandProperty Extension -Unique)
        }
    }
    catch {
        Write-ErrorLog -Message "Error getting folder summary" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FolderPath = $FolderPath
                PathExists = (Test-Path $FolderPath)
            } `
            -Source "Get-FolderSummary"
        
        return $null
    }
}