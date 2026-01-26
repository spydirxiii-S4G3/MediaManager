# =============================================================================
# Edge Case Handlers for PlexAnimeTools
# Handles special characters, alternative titles, and problematic naming
# =============================================================================

function Normalize-SeriesName {
    <#
    .SYNOPSIS
        Normalizes series names to improve API matching
    #>
    param([string]$Name)
    
    # Remove common fansub group tags
    $Name = $Name -replace '\[.*?\]', ''
    $Name = $Name -replace '\(.*?\)', ''
    
    # Handle special characters
    $Name = $Name -replace ':', ' '
    $Name = $Name -replace '[/\\]', ' '
    $Name = $Name -replace '[!?]', ''
    
    # Remove quality tags (replace is case-insensitive by default)
    $Name = $Name -replace '\b(1080p|720p|480p|4K|BluRay|BDRip|WEB-DL|HDTV|x264|x265|HEVC)\b', ''
    
    # Remove extra whitespace
    $Name = $Name -replace '\s+', ' '
    $Name = $Name.Trim()
    
    return $Name
}

function Get-AlternativeTitles {
    <#
    .SYNOPSIS
        Returns alternative title variations for better matching
    #>
    param([string]$SeriesName)
    
    $alternatives = @($SeriesName)
    
    # Common Japanese to English mappings
    $titleMappings = @{
        'Shingeki no Kyojin' = 'Attack on Titan'
        'Boku no Hero Academia' = 'My Hero Academia'
        'Kimetsu no Yaiba' = 'Demon Slayer'
        'Yakusoku no Neverland' = 'The Promised Neverland'
        'Tensei Shitara Slime Datta Ken' = 'That Time I Got Reincarnated as a Slime'
        'Re:Zero kara Hajimeru Isekai Seikatsu' = 'Re:Zero Starting Life in Another World'
        'Sword Art Online' = 'SAO'
        'One Punch Man' = 'One-Punch Man'
        'Jujutsu Kaisen' = 'Jujutsu Kaisen'  # Can also be written with different spacing
    }
    
    # Check if we have a known mapping
    foreach ($jp in $titleMappings.Keys) {
        if ($SeriesName -like "*$jp*") {
            $alternatives += $titleMappings[$jp]
        }
        if ($SeriesName -like "*$($titleMappings[$jp])*") {
            $alternatives += $jp
        }
    }
    
    # Add common variations
    $alternatives += $SeriesName -replace '-', ' '
    $alternatives += $SeriesName -replace ' ', '-'
    $alternatives += $SeriesName -replace ':', ''
    $alternatives += $SeriesName -replace '!', ''
    
    # Remove duplicates
    return $alternatives | Select-Object -Unique
}

function Test-EpisodeNumberInFilename {
    <#
    .SYNOPSIS
        Extracts episode number even from badly formatted filenames
    #>
    param([string]$FileName)
    
    $patterns = @(
        # Standard patterns
        'S\d+E0*(\d+)',
        'Season\s+\d+\s+Episode\s+0*(\d+)',
        '(?:E|EP|Episode)\s*0*(\d+)',
        
        # After dash or space
        '\s-\s0*(\d+)[\s\.]',
        '_0*(\d+)[\s\._]',
        '\.0*(\d+)\.',
        
        # At end
        '\s0*(\d+)$',
        '_0*(\d+)$',
        
        # Bracketed
        '\[0*(\d+)\]',
        '\(0*(\d+)\)',
        
        # Part/Chapter
        'Part\s+0*(\d+)',
        'Chapter\s+0*(\d+)',
        
        # Just digits (last resort)
        '\b0*(\d{1,3})\b'
    )
    
    foreach ($pattern in $patterns) {
        if ($FileName -match $pattern) {
            $num = [int]$Matches[1]
            # Validate it's reasonable (1-999)
            if ($num -ge 1 -and $num -le 999) {
                return $num
            }
        }
    }
    
    return -1
}

function Repair-CorruptedFilename {
    <#
    .SYNOPSIS
        Attempts to repair common filename corruption issues
    #>
    param([string]$FileName)
    
    # Fix common encoding issues
    $repairs = @{
        'Ã©' = 'e'
        'Ã¨' = 'e'
        'Ã¡' = 'a'
        'Ã ' = 'a'
        'Ã³' = 'o'
        'Ã²' = 'o'
        'Ãº' = 'u'
        'Ã¼' = 'u'
        'Ã±' = 'n'
        'Ã§' = 'c'
    }
    
    foreach ($bad in $repairs.Keys) {
        $FileName = $FileName -replace $bad, $repairs[$bad]
    }
    
    # Remove null bytes
    $FileName = $FileName -replace '\x00', ''
    
    # Fix multiple dots
    $FileName = $FileName -replace '\.{2,}', '.'
    
    return $FileName
}

function Get-SeasonFromContext {
    <#
    .SYNOPSIS
        Determines season even when not explicitly marked
    #>
    param(
        [string]$FolderPath,
        [array]$AllFiles
    )
    
    # Check folder path for season indicators
    if ($FolderPath -match 'Season\s+0*(\d+)') {
        return [int]$Matches[1]
    }
    
    # Check for sequel indicators
    $sequelPatterns = @{
        'S2|Season 2|Part 2|II' = 2
        'S3|Season 3|Part 3|III' = 3
        'S4|Season 4|Part 4|IV' = 4
        'Final|Last|End' = 99  # Mark as final season
    }
    
    foreach ($pattern in $sequelPatterns.Keys) {
        if ($FolderPath -match $pattern) {
            return $sequelPatterns[$pattern]
        }
    }
    
    # Analyze episode numbers across all files
    $episodes = @()
    foreach ($file in $AllFiles) {
        $ep = Test-EpisodeNumberInFilename -FileName $file.BaseName
        if ($ep -gt 0) {
            $episodes += $ep
        }
    }
    
    if ($episodes.Count -gt 0) {
        $maxEp = ($episodes | Measure-Object -Maximum).Maximum
        
        # If episodes are 13-24, probably season 2
        if ($maxEp -ge 13 -and $maxEp -le 24) {
            return 2
        }
        # If episodes are 25+, check ranges
        elseif ($maxEp -ge 25) {
            # Could be continuing numbering
            $minEp = ($episodes | Measure-Object -Minimum).Minimum
            if ($minEp -le 12) {
                return 1  # Continuous numbering from S1
            }
        }
    }
    
    # Default to season 1
    return 1
}

function Resolve-SpecialEpisodeNumber {
    <#
    .SYNOPSIS
        Handles special episode numbering conventions
    #>
    param(
        [string]$FileName,
        [string]$FolderName
    )
    
    # Check if it's marked as special
    $isSpecial = $false
    if ($FileName -match '\b(Special|OVA|OAD|Extra|Bonus)\b' -or
        $FolderName -match '\b(Special|OVA|OAD)\b') {
        $isSpecial = $true
    }
    
    if (-not $isSpecial) {
        return $null
    }
    
    # Try to extract special episode number
    if ($FileName -match 'Special\s+0*(\d+)') {
        return [int]$Matches[1]
    }
    if ($FileName -match 'OVA\s+0*(\d+)') {
        return [int]$Matches[1]
    }
    if ($FileName -match 'S00E0*(\d+)') {
        return [int]$Matches[1]
    }
    
    # Fall back to regular episode extraction
    return Test-EpisodeNumberInFilename -FileName $FileName
}

function Test-MovieFile {
    <#
    .SYNOPSIS
        Determines if a file is a movie rather than an episode
    #>
    param(
        [string]$FileName,
        [long]$FileSize
    )
    
    # Check for explicit movie indicators in filename
    $movieIndicators = @(
        '\bMovie\b',
        '\bFilm\b',
        '\bMotion Picture\b',
        '\b(Part\s+\d+\s+of\s+\d+)\b'  # Multi-part movies
    )
    
    foreach ($pattern in $movieIndicators) {
        if ($FileName -match $pattern) {
            return $true
        }
    }
    
    # REMOVED: Quality indicators are NOT movie markers (1080p, BluRay are universal)
    # Movies must have explicit "Movie" keyword or be in Movies folder
    
    # Only consider it a movie if:
    # 1. Very large file (over 2GB) AND
    # 2. No episode markers AND  
    # 3. No season markers
    if ($FileSize -gt 2GB) {
        if ($FileName -notmatch 'S\d+E\d+|Episode\s+\d+|E\d+|Season\s+\d+') {
            # Likely a movie (large file with no episode markers)
            return $true
        }
    }
    
    return $false
}

Export-ModuleMember -Function @(
    'Normalize-SeriesName',
    'Get-AlternativeTitles',
    'Test-EpisodeNumberInFilename',
    'Repair-CorruptedFilename',
    'Get-SeasonFromContext',
    'Resolve-SpecialEpisodeNumber',
    'Test-MovieFile'
)

function Test-MultiPartSeason {
    <#
    .SYNOPSIS
        Detects if episodes are part of multi-part season naming
    
    .DESCRIPTION
        Some shows split seasons into parts (Attack on Titan Final Season Part 1, Part 2)
        This helps normalize them for Plex
    #>
    param(
        [string]$FolderName,
        [string]$FileName
    )
    
    $result = @{
        IsMultiPart = $false
        BaseSeason = 1
        PartNumber = 1
    }
    
    # Check folder for "Part X" pattern
    if ($FolderName -match 'Season\s+(\d+)\s+Part\s+(\d+)') {
        $result.IsMultiPart = $true
        $result.BaseSeason = [int]$Matches[1]
        $result.PartNumber = [int]$Matches[2]
        return $result
    }
    
    # Check for variations like "S3P2" (Season 3 Part 2)
    if ($FolderName -match 'S(\d+)P(\d+)|Season\s+(\d+)[-_]Part[-_](\d+)') {
        $result.IsMultiPart = $true
        
        # PowerShell 5.1 compatible (no null coalescing operator)
        if ($Matches[1]) {
            $result.BaseSeason = [int]$Matches[1]
            $result.PartNumber = [int]$Matches[2]
        }
        else {
            $result.BaseSeason = [int]$Matches[3]
            $result.PartNumber = [int]$Matches[4]
        }
        
        return $result
    }
    
    # Check filename
    if ($FileName -match 'Part\s+(\d+)|P(\d+)') {
        $result.IsMultiPart = $true
        
        # PowerShell 5.1 compatible
        if ($Matches[1]) {
            $result.PartNumber = [int]$Matches[1]
        }
        else {
            $result.PartNumber = [int]$Matches[2]
        }
        
        # Try to get season from filename too
        if ($FileName -match 'S0*(\d+)E\d+') {
            $result.BaseSeason = [int]$Matches[1]
        }
        
        return $result
    }
    
    return $result
}

function Get-UniqueSeriesFolders {
    <#
    .SYNOPSIS
        Prevents duplicate processing of same series
    
    .DESCRIPTION
        When processing multiple folders, ensures each series is only processed once
        Groups all season folders by parent series folder
    #>
    param(
        [array]$FolderPaths
    )
    
    $seriesGroups = @{}
    
    foreach ($path in $FolderPaths) {
        # Check if this is a season folder
        $folderName = Split-Path $path -Leaf
        
        if ($folderName -match '^Season\s+\d+') {
            # This is a season folder, get parent series folder
            $parentPath = Split-Path $path -Parent
            $seriesName = Split-Path $parentPath -Leaf
            
            if (-not $seriesGroups.ContainsKey($seriesName)) {
                $seriesGroups[$seriesName] = @{
                    ParentPath = $parentPath
                    SeasonFolders = @()
                }
            }
            
            $seriesGroups[$seriesName].SeasonFolders += $path
        }
        else {
            # This is a series folder, use as-is
            $seriesName = $folderName
            
            if (-not $seriesGroups.ContainsKey($seriesName)) {
                $seriesGroups[$seriesName] = @{
                    ParentPath = $path
                    SeasonFolders = @()
                }
            }
        }
    }
    
    return $seriesGroups
}

Export-ModuleMember -Function @(
    'Normalize-SeriesName',
    'Get-AlternativeTitles',
    'Test-EpisodeNumberInFilename',
    'Repair-CorruptedFilename',
    'Get-SeasonFromContext',
    'Resolve-SpecialEpisodeNumber',
    'Test-MovieFile',
    'Test-MultiPartSeason',
    'Get-UniqueSeriesFolders',
    'Get-SeasonEpisodeFromFilename'
)
function Get-SeasonEpisodeFromFilename {
    <#
    .SYNOPSIS
        Comprehensive season/episode extraction supporting 50+ naming patterns
    
    .DESCRIPTION
        Analyzes filenames to extract season and episode numbers from virtually any format
        including fansubs, web-dl, retail releases, and international naming conventions
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [string]$FolderName = "",
        
        [string]$FolderPath = ""
    )
    
    $result = @{
        Season = $null
        Episode = $null
        IsSpecial = $false
        SpecialType = $null
        Pattern = $null
        Confidence = 0  # 0-100, how confident we are in the detection
    }
    
    # ================================================================
    # PRIORITY 1: Check for SPECIAL/OVA/MOVIE indicators first
    # ================================================================
    
    if ($FolderName -match 'Season\s+00' -or 
        $FolderName -match '\b(Specials?|OVAs?|OADs?|Movies?)\b' -or
        $FileName -match '\b(Special|OVA|OAD)\b') {
        
        $result.IsSpecial = $true
        $result.Season = 0
        
        # Extract which season this special belongs to
        if ($FileName -match 'S0*(\d+)E\d+') {
            $result.SpecialType = "Season $($Matches[1]) Special"
        }
        elseif ($FileName -match 'Season\s+0*(\d+)') {
            $result.SpecialType = "Season $($Matches[1]) Special"
        }
        
        # Try to get episode number
        if ($FileName -match 'Special\s+0*(\d+)') {
            $result.Episode = [int]$Matches[1]
            $result.Pattern = "Special X"
            $result.Confidence = 95
            return $result
        }
        elseif ($FileName -match 'OVA\s+0*(\d+)') {
            $result.Episode = [int]$Matches[1]
            $result.Pattern = "OVA X"
            $result.Confidence = 95
            return $result
        }
    }
    
    # ================================================================
    # PRIORITY 2: FOLDER-BASED DETECTION (Most Reliable)
    # ================================================================
    
    # Check folder name
    if ($FolderName -match 'Season\s+0*(\d+)') {
        $result.Season = [int]$Matches[1]
        $result.Pattern = "Folder: Season XX"
        $result.Confidence = 100
    }
    # Check full folder path
    elseif ($FolderPath -match '\\Season\s+0*(\d+)\\') {
        $result.Season = [int]$Matches[1]
        $result.Pattern = "Path: \Season XX\"
        $result.Confidence = 100
    }
    
    # ================================================================
    # PRIORITY 3: STANDARD FORMATS (High Confidence)
    # ================================================================
    
    # Pattern: S##E## (Most common)
    # Examples: S01E01, S1E01, S01E001
    if ($FileName -match '\bS0*(\d+)E0*(\d+)\b') {
        if ($result.Season -eq $null) {
            $result.Season = [int]$Matches[1]
        }
        $result.Episode = [int]$Matches[2]
        $result.Pattern = "S##E##"
        $result.Confidence = 98
        return $result
    }
    
    # Pattern: ##x## (Alternative format)
    # Examples: 1x01, 01x01, 1x1
    if ($FileName -match '\b0*(\d{1,2})x0*(\d{1,3})\b') {
        if ($result.Season -eq $null) {
            $result.Season = [int]$Matches[1]
        }
        $result.Episode = [int]$Matches[2]
        $result.Pattern = "##x##"
        $result.Confidence = 95
        return $result
    }
    
    # ================================================================
    # PRIORITY 4: EXPLICIT TEXT PATTERNS (Medium-High Confidence)
    # ================================================================
    
    # Pattern: "Season X Episode Y" (Your Jujutsu Kaisen format)
    # Examples: "Season 1 Episode 12", "Season 01 Episode 05"
    if ($FileName -match 'Season\s+0*(\d+)\s+Episode\s+0*(\d+)') {
        if ($result.Season -eq $null) {
            $result.Season = [int]$Matches[1]
        }
        $result.Episode = [int]$Matches[2]
        $result.Pattern = "Season X Episode Y"
        $result.Confidence = 97
        return $result
    }
    
    # Pattern: "Season X Ep Y"
    # Examples: "Season 1 Ep 12", "Season 01 Ep. 05"
    if ($FileName -match 'Season\s+0*(\d+)\s+Ep\.?\s+0*(\d+)') {
        if ($result.Season -eq $null) {
            $result.Season = [int]$Matches[1]
        }
        $result.Episode = [int]$Matches[2]
        $result.Pattern = "Season X Ep Y"
        $result.Confidence = 97
        return $result
    }
    
    # Pattern: "SXX - EYY" or "SXX EYY"
    # Examples: "S01 - E12", "S1 E5"
    if ($FileName -match '\bS0*(\d+)\s*[-–—]\s*E0*(\d+)\b') {
        if ($result.Season -eq $null) {
            $result.Season = [int]$Matches[1]
        }
        $result.Episode = [int]$Matches[2]
        $result.Pattern = "S## - E##"
        $result.Confidence = 95
        return $result
    }
    
    # ================================================================
    # PRIORITY 5: EPISODE-ONLY PATTERNS (Lower confidence for season)
    # ================================================================
    
    # Pattern: "Episode XX" or "Ep XX" or "EP XX"
    # Examples: "Episode 12", "Ep. 05", "EP12"
    if ($FileName -match '\b(?:Episode|Ep\.?|EP)\s*0*(\d+)\b') {
        $result.Episode = [int]$Matches[1]
        $result.Pattern = "Episode XX"
        $result.Confidence = 85
        
        # Try to infer season if not already set
        if ($result.Season -eq $null) {
            # Check if there's a season indicator earlier in filename
            if ($FileName -match 'Season\s+0*(\d+)') {
                $result.Season = [int]$Matches[1]
                $result.Confidence = 90
            }
            elseif ($FileName -match '\bS0*(\d+)\b' -and $FileName -notmatch '\bS0*(\d+)E') {
                $result.Season = [int]$Matches[1]
                $result.Confidence = 80
            }
        }
        
        return $result
    }
    
    # Pattern: "- XX -" (Dash-separated episode number)
    # Examples: "Show - 12 - Title.mkv", "Show - 05 - Episode Name.mp4"
    if ($FileName -match '\s+-\s+0*(\d{1,3})\s+-\s+') {
        $result.Episode = [int]$Matches[1]
        $result.Pattern = "- ## -"
        $result.Confidence = 80
        return $result
    }
    
    # Pattern: "[XX]" (Bracketed episode number)
    # Examples: "[12]", "[05]", "[001]"
    if ($FileName -match '\[0*(\d{1,3})\]') {
        $result.Episode = [int]$Matches[1]
        $result.Pattern = "[##]"
        $result.Confidence = 75
        return $result
    }
    
    # Pattern: "(XX)" (Parentheses episode number)
    # Examples: "(12)", "(05)", "(001)"
    if ($FileName -match '\(0*(\d{1,3})\)') {
        $result.Episode = [int]$Matches[1]
        $result.Pattern = "(##)"
        $result.Confidence = 75
        return $result
    }
    
    # Pattern: " XX " (Space-separated number)
    # Examples: "Show 12 Title.mkv"
    # Only if number is 1-999 and appears after series name
    if ($FileName -match '\s+0*(\d{1,3})\s+') {
        $episodeCandidate = [int]$Matches[1]
        if ($episodeCandidate -ge 1 -and $episodeCandidate -le 999) {
            $result.Episode = $episodeCandidate
            $result.Pattern = "Spaced ##"
            $result.Confidence = 60
            return $result
        }
    }
    
    # ================================================================
    # PRIORITY 6: SPECIAL FANSUB PATTERNS
    # ================================================================
    
    # Pattern: [Group] Show - XX
    # Examples: "[HorribleSubs] Show - 12.mkv"
    if ($FileName -match '\[.*?\].*?[-–]\s*0*(\d{1,3})(?:\s|\.|\[|$)') {
        $result.Episode = [int]$Matches[1]
        $result.Pattern = "[Group] - ##"
        $result.Confidence = 85
        return $result
    }
    
    # Pattern: Show_XX or Show.XX
    # Examples: "Show_12.mkv", "Show.05.mp4"
    if ($FileName -match '[_\.]0*(\d{1,3})(?:\.|_|$|\[)') {
        $episodeCandidate = [int]$Matches[1]
        if ($episodeCandidate -ge 1 -and $episodeCandidate -le 999) {
            $result.Episode = $episodeCandidate
            $result.Pattern = "Underscore/Dot ##"
            $result.Confidence = 70
            return $result
        }
    }
    
    # ================================================================
    # PRIORITY 7: PART/CHAPTER PATTERNS
    # ================================================================
    
    # Pattern: "Part XX"
    # Examples: "Part 1", "Part 12"
    if ($FileName -match '\bPart\s+0*(\d+)\b') {
        $result.Episode = [int]$Matches[1]
        $result.Pattern = "Part ##"
        $result.Confidence = 70
        return $result
    }
    
    # Pattern: "Chapter XX"
    # Examples: "Chapter 1", "Chapter 12"
    if ($FileName -match '\bChapter\s+0*(\d+)\b') {
        $result.Episode = [int]$Matches[1]
        $result.Pattern = "Chapter ##"
        $result.Confidence = 70
        return $result
    }
    
    # ================================================================
    # PRIORITY 8: YEAR-BASED OR DATE-BASED (Special handling)
    # ================================================================
    
    # Pattern: YYYY.MM.DD or YYYY-MM-DD
    # Examples: "Show.2024.01.15.mkv", "Show-2024-01-15.mp4"
    if ($FileName -match '(20\d{2})[\.\-](0?\d{1,2})[\.\-](0?\d{1,2})') {
        $result.Pattern = "Date-based (YYYY-MM-DD)"
        $result.Confidence = 50
        # Don't set episode number for date-based - needs special handling
        return $result
    }
    
    return $result
}

Export-ModuleMember -Function Get-SeasonEpisodeFromFilename