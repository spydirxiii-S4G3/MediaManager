# =============================================================================
# Content Detection Functions
# Automatic detection of anime, TV shows, cartoons, and movies
# CORRECTED VERSION - Fixed movie regex pattern
# =============================================================================

function Get-FolderStructureType {
    <#
    .SYNOPSIS
        Analyzes folder structure to determine organization pattern
    
    .PARAMETER FolderPath
        Path to folder to analyze
    
    .DESCRIPTION
        Detects various folder organization patterns:
        - Standard Plex: "Show Name/Season 01/episodes"
        - Prefixed Seasons: "Show Name/Show Name Season 01/episodes"
        - Flat Structure: "Show Name/episodes" (no season folders)
        - Movies: "Show Name/movie file"
    
    .EXAMPLE
        $structure = Get-FolderStructureType -FolderPath "D:\Anime\One Punch Man"
        # Returns: @{Type='PrefixedSeasons'; SeasonFolders=@(...); HasSubfolders=$true}
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath
    )
    
    if (-not (Test-Path $FolderPath)) {
        return @{
            Type = 'Invalid'
            SeasonFolders = @()
            HasSubfolders = $false
            VideoFiles = @()
        }
    }
    
    try {
        $folderName = Split-Path $FolderPath -Leaf
        
        # Get immediate subfolders
        $subfolders = Get-ChildItem -Path $FolderPath -Directory -ErrorAction Stop
        
        # Get video files in root
        $rootVideos = Get-ChildItem -Path $FolderPath -File -ErrorAction Stop | Where-Object {
            $script:VideoExtensions -contains $_.Extension.ToLower()
        }
        
        # Get all video files recursively
        $allVideos = Get-ChildItem -Path $FolderPath -File -Recurse -ErrorAction Stop | Where-Object {
            $script:VideoExtensions -contains $_.Extension.ToLower()
        }
        
        # Detect movies within the series
        # FIXED: Changed \bMovie\b to \bMovie\b(?!s) to not match "Movies" plural
        # Pattern 1: Root level movie files with "Movie" or movie name in filename
        $rootMovies = $rootVideos | Where-Object {
            $_.Name -match '\(Movie\)|\bMovie\b(?!s)' -or 
            $_.Name -match '\bFilm\b(?!s)' -or
            $_.BaseName -match ':\s*\w+\s+Movie|Movie:\s*\w+'
        }
        
        # Pattern 2: Folders named "Movie", "Movies", "Specials" containing videos
        $movieFolders = $subfolders | Where-Object {
            $_.Name -match '^(Movie|Movies|Film|Films)$' -or
            $_.Name -match '\bMovie\b|\bFilm\b'
        }
        
        # Pattern 3: Folders with specific movie names (e.g., "Mugen Train", "Road to Ninja")
        $namedMovieFolders = $subfolders | Where-Object {
            $folderVideos = Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue | 
                Where-Object { $script:VideoExtensions -contains $_.Extension.ToLower() }
            
            # If folder has videos and doesn't match season pattern, might be a movie
            ($folderVideos.Count -gt 0) -and 
            ($_.Name -notmatch 'Season|^S\d+') -and
            ($folderVideos.Count -le 3)  # Movies usually have 1-3 files (versions/extras)
        }
        
        $allMovieFolders = @($movieFolders) + @($namedMovieFolders) | Select-Object -Unique
        
        # Pattern 1: Standard Plex season folders "Season 01", "Season 02"
        $standardSeasons = $subfolders | Where-Object {
            $_.Name -match '^Season \d{2}$'
        }
        
        # Pattern 2: Prefixed season folders "Show Name Season 01"
        $prefixedSeasons = $subfolders | Where-Object {
            $_.Name -match 'Season \d{2}$' -and $_.Name -notmatch '^Season \d{2}$'
        }
        
        # Pattern 3: Named folders that might be seasons "Season 1", "S01", "S1"
        $namedSeasons = $subfolders | Where-Object {
            $_.Name -match '^(S|Season)\s*0*(\d{1,2})$'
        }
        
        # Determine structure type
        if ($standardSeasons.Count -gt 0) {
            return @{
                Type = 'StandardPlex'
                SeasonFolders = $standardSeasons
                HasSubfolders = $true
                VideoFiles = $allVideos
                RootVideos = $rootVideos
                Pattern = 'Season ##'
                MovieFiles = $rootMovies
                MovieFolders = $allMovieFolders
                HasMovies = (($rootMovies.Count -gt 0) -or ($allMovieFolders.Count -gt 0))
            }
        }
        elseif ($prefixedSeasons.Count -gt 0) {
            return @{
                Type = 'PrefixedSeasons'
                SeasonFolders = $prefixedSeasons
                HasSubfolders = $true
                VideoFiles = $allVideos
                RootVideos = $rootVideos
                Pattern = 'Show Name Season ##'
                MovieFiles = $rootMovies
                MovieFolders = $allMovieFolders
                HasMovies = (($rootMovies.Count -gt 0) -or ($allMovieFolders.Count -gt 0))
            }
        }
        elseif ($namedSeasons.Count -gt 0) {
            return @{
                Type = 'NamedSeasons'
                SeasonFolders = $namedSeasons
                HasSubfolders = $true
                VideoFiles = $allVideos
                RootVideos = $rootVideos
                Pattern = 'S## or Season #'
                MovieFiles = $rootMovies
                MovieFolders = $allMovieFolders
                HasMovies = (($rootMovies.Count -gt 0) -or ($allMovieFolders.Count -gt 0))
            }
        }
        elseif ($subfolders.Count -gt 0 -and $rootVideos.Count -eq 0) {
            # Has subfolders but they don't match season patterns
            # Check if subfolders contain videos
            $subfoldersWithVideos = $subfolders | Where-Object {
                $videoCount = (Get-ChildItem -Path $_.FullName -File -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $script:VideoExtensions -contains $_.Extension.ToLower() }).Count
                $videoCount -gt 0
            }
            
            if ($subfoldersWithVideos.Count -gt 0) {
                return @{
                    Type = 'CustomSubfolders'
                    SeasonFolders = $subfoldersWithVideos
                    HasSubfolders = $true
                    VideoFiles = $allVideos
                    RootVideos = $rootVideos
                    Pattern = 'Custom folder structure'
                    MovieFiles = $rootMovies
                    MovieFolders = $allMovieFolders
                    HasMovies = (($rootMovies.Count -gt 0) -or ($allMovieFolders.Count -gt 0))
                }
            }
        }
        
        # Flat structure - videos in root, no season folders
        if ($rootVideos.Count -gt 0) {
            if ($rootVideos.Count -eq 1) {
                return @{
                    Type = 'SingleMovie'
                    SeasonFolders = @()
                    HasSubfolders = $false
                    VideoFiles = $rootVideos
                    RootVideos = $rootVideos
                    Pattern = 'Single video file'
                }
            }
            else {
                return @{
                    Type = 'FlatSeries'
                    SeasonFolders = @()
                    HasSubfolders = $false
                    VideoFiles = $rootVideos
                    RootVideos = $rootVideos
                    Pattern = 'All episodes in root folder'
                }
            }
        }
        
        # Empty or unknown
        return @{
            Type = 'Unknown'
            SeasonFolders = @()
            HasSubfolders = ($subfolders.Count -gt 0)
            VideoFiles = $allVideos
            RootVideos = $rootVideos
            Pattern = 'Unable to determine'
        }
    }
    catch {
        Write-ErrorLog -Message "Error analyzing folder structure" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FolderPath = $FolderPath
                FolderName = (Split-Path $FolderPath -Leaf)
            } `
            -Source "Get-FolderStructureType"
        
        return @{
            Type = 'Error'
            SeasonFolders = @()
            HasSubfolders = $false
            VideoFiles = @()
            RootVideos = @()
            Error = $_.Exception.Message
        }
    }
}

function Test-ContentType {
    <#
    .SYNOPSIS
        Detects the content type of media in a folder
    
    .PARAMETER FolderPath
        Path to folder to analyze
    
    .PARAMETER AssumeAnime
        If set, assumes anime unless clearly something else
    
    .OUTPUTS
        Returns 'Anime', 'TV Series', 'Cartoon', or 'Movie'
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath,
        
        [switch]$AssumeAnime
    )
    
    if (-not (Test-Path $FolderPath)) {
        return 'Unknown'
    }
    
    try {
        $folderName = Split-Path $FolderPath -Leaf
        
        # Check for anime indicators
        $animeKeywords = @(
            'anime', 'season', 'episode', 'ova', 'ona', 'special',
            'BD', 'BluRay', 'BDRip', 'ep\d+', 'S\d+E\d+'
        )
        
        $animeGroups = @(
            'HorribleSubs', 'SubsPlease', 'Erai-raws', 'Commie',
            'FFF', 'GJM', 'Judas', 'Doki', 'gg', 'Coalgirls', 'UTW'
        )
        
        # Check folder name
        $hasAnimeKeyword = $false
        foreach ($keyword in $animeKeywords) {
            if ($folderName -match $keyword) {
                $hasAnimeKeyword = $true
                break
            }
        }
        
        $hasAnimeGroup = $false
        foreach ($group in $animeGroups) {
            if ($folderName -match "\[$group\]" -or $folderName -match $group) {
                $hasAnimeGroup = $true
                break
            }
        }
        
        # Check video files
        $videoFiles = Get-ChildItem -Path $FolderPath -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $script:DefaultConfig.VideoExtensions -contains $_.Extension.ToLower() }
        
        if ($videoFiles) {
            $hasAnimeInFiles = $false
            foreach ($file in $videoFiles) {
                foreach ($group in $animeGroups) {
                    if ($file.Name -match "\[$group\]" -or $file.Name -match $group) {
                        $hasAnimeInFiles = $true
                        break
                    }
                }
                if ($hasAnimeInFiles) { break }
            }
            
            if ($hasAnimeInFiles) {
                return 'Anime'
            }
        }
        
        # Check for movie indicators
        if ($folderName -match '\bmovie\b|\bfilm\b' -or 
            ($videoFiles -and $videoFiles.Count -eq 1)) {
            return 'Movie'
        }
        
        # Check for cartoon indicators
        if ($folderName -match 'cartoon|kids|children') {
            return 'Cartoon'
        }
        
        # Use folder structure as hint
        $structure = Get-FolderStructureType -FolderPath $FolderPath
        if ($structure.Type -eq 'SingleMovie') {
            return 'Movie'
        }
        
        # Default based on AssumeAnime flag
        if ($AssumeAnime -or $hasAnimeKeyword -or $hasAnimeGroup) {
            return 'Anime'
        }
        
        return 'TV Series'
    }
    catch {
        Write-Verbose "Error detecting content type: $_"
        return if ($AssumeAnime) { 'Anime' } else { 'TV Series' }
    }
}

function Get-VideoFiles {
    <#
    .SYNOPSIS
        Gets video files from a path
    
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
            ErrorAction = 'SilentlyContinue'
        }
        
        if ($Recurse) {
            $params.Recurse = $true
        }
        
        $files = Get-ChildItem @params | Where-Object {
            $script:DefaultConfig.VideoExtensions -contains $_.Extension.ToLower()
        }
        
        return $files
    }
    catch {
        Write-Verbose "Error getting video files: $_"
        return @()
    }
}

# ... REST OF DETECTION.PS1 FILE REMAINS THE SAME ...
# (All other functions like Test-ContentType, Get-VideoFiles, etc. remain unchanged)