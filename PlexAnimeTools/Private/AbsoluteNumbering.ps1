# =============================================================================
# AbsoluteNumbering.ps1 - ENHANCED VERSION (SYNTAX FIXED)
# Handles absolute episode numbering with real-world season mapping
# Examples: One Piece (408 = S12E01), Naruto, etc.
# =============================================================================

function Get-AbsoluteEpisodeNumber {
    <#
    .SYNOPSIS
        Extracts absolute episode number from filename
    
    .DESCRIPTION
        Handles files with absolute numbering like:
        - "One Piece - 408.mkv" (absolute 408)
        - "One Piece Episode 408.mp4"
        - "Naruto - 220.mkv"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )
    
    try {
        # Remove common prefixes and suffixes
        $cleanName = $FileName
        $cleanName = $cleanName -replace '\[.*?\]', ''
        $cleanName = $cleanName -replace '\(.*?\)', ''
        $cleanName = $cleanName -replace 'English Dubbed', ''
        $cleanName = $cleanName -replace 'Watch Anime.*$', ''
        $cleanName = $cleanName -replace '\.(mkv|mp4|avi|m4v)$', ''
        
        # Pattern 1: "Series - ### - Title" or "Series - ###"
        if ($cleanName -match '^.+?\s*-\s*0*(\d{1,4})\s*[-\s]') {
            $episodeNum = [int]$Matches[1]
            Write-Verbose "Absolute episode: $episodeNum from pattern 'Series - ###'"
            return $episodeNum
        }
        
        # Pattern 2: "Episode ####"
        if ($cleanName -match 'Episode[\s\-]*0*(\d{1,4})\s*$') {
            $episodeNum = [int]$Matches[1]
            Write-Verbose "Absolute episode: $episodeNum from 'Episode ###'"
            return $episodeNum
        }
        
        # Pattern 3: "Ep ####"
        if ($cleanName -match 'Ep[\s\-]*0*(\d{1,4})\s*$') {
            $episodeNum = [int]$Matches[1]
            Write-Verbose "Absolute episode: $episodeNum from 'Ep ###'"
            return $episodeNum
        }
        
        # Pattern 4: Trailing numbers
        if ($cleanName -match '\s+0*(\d{1,4})\s*$') {
            $episodeNum = [int]$Matches[1]
            if ($episodeNum -ge 1 -and $episodeNum -le 9999) {
                Write-Verbose "Absolute episode: $episodeNum from trailing number"
                return $episodeNum
            }
        }
        
        return -1
    }
    catch {
        Write-Verbose "Failed to extract absolute episode: $_"
        return -1
    }
}

function Get-SeasonFromAbsoluteNumber {
    <#
    .SYNOPSIS
        Maps absolute episode number to season/episode using Jikan API
    
    .DESCRIPTION
        Example: One Piece Episode 408 -> Season 12, Episode 1
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SeriesName,
        
        [Parameter(Mandatory)]
        [int]$AbsoluteEpisode,
        
        [int]$MalId = 0
    )
    
    try {
        Write-LogMessage "Mapping absolute episode $AbsoluteEpisode for: $SeriesName" -Level Info -Category Processing
        
        # Search for series if no MAL ID
        if ($MalId -eq 0) {
            $cleanQuery = Clean-SearchQuery -Query $SeriesName
            $searchResults = Search-JikanAPI -Query $cleanQuery
            
            if (-not $searchResults) {
                Write-LogMessage "No results found for: $SeriesName" -Level Warning -Category API
                return @{
                    Season = 1
                    Episode = $AbsoluteEpisode
                    Confidence = 'Low'
                    Method = 'Fallback'
                }
            }
            
            $MalId = $searchResults[0].mal_id
            Write-Verbose "Found MAL ID: $MalId"
        }
        
        # Get main anime details
        $animeDetails = Get-JikanAnimeDetails -MalId $MalId
        
        if (-not $animeDetails) {
            Write-LogMessage "Failed to get details for MAL ID: $MalId" -Level Warning -Category API
            return @{
                Season = 1
                Episode = $AbsoluteEpisode
                Confidence = 'Low'
                Method = 'Fallback'
            }
        }
        
        Write-Verbose "Series: $($animeDetails.title)"
        Write-Verbose "Type: $($animeDetails.type)"
        
        # Build season list
        $allSeasons = @()
        $allSeasons += @{
            MalId = $MalId
            Title = $animeDetails.title
            Episodes = $animeDetails.episodes
            Type = $animeDetails.type
            SeasonNumber = 1
            Year = $animeDetails.year
        }
        
        # Get sequels
        if ($animeDetails.relations) {
            $sequelCount = 1
            
            foreach ($relation in $animeDetails.relations) {
                if ($relation.relation -eq 'Sequel') {
                    foreach ($entry in $relation.entry) {
                        if ($entry.type -eq 'anime') {
                            Start-Sleep -Milliseconds 500
                            
                            $relatedDetails = Get-JikanAnimeDetails -MalId $entry.mal_id
                            
                            if ($relatedDetails -and $relatedDetails.episodes -gt 0) {
                                $sequelCount++
                                $seasonTitle = $relatedDetails.title
                                $seasonEps = $relatedDetails.episodes
                                
                                $allSeasons += @{
                                    MalId = $entry.mal_id
                                    Title = $seasonTitle
                                    Episodes = $seasonEps
                                    Type = $relatedDetails.type
                                    SeasonNumber = $sequelCount
                                    Year = $relatedDetails.year
                                }
                                
                                Write-Verbose "Added Season $sequelCount - $seasonTitle ($seasonEps eps)"
                            }
                        }
                    }
                }
            }
        }
        
        # Sort by year
        $allSeasons = $allSeasons | Sort-Object Year, SeasonNumber
        Write-Verbose "Total seasons: $($allSeasons.Count)"
        
        # Map absolute to season/episode
        $runningTotal = 0
        
        foreach ($seasonData in $allSeasons) {
            $seasonEpisodes = $seasonData.Episodes
            
            if ($AbsoluteEpisode -le ($runningTotal + $seasonEpisodes)) {
                $episodeInSeason = $AbsoluteEpisode - $runningTotal
                
                Write-LogMessage "SUCCESS: Absolute $AbsoluteEpisode -> Season $($seasonData.SeasonNumber) Episode $episodeInSeason" -Level Success -Category Processing
                
                return @{
                    Season = $seasonData.SeasonNumber
                    Episode = $episodeInSeason
                    SeasonTitle = $seasonData.Title
                    SeasonEpisodeCount = $seasonEpisodes
                    TotalSeasons = $allSeasons.Count
                    AbsoluteEpisode = $AbsoluteEpisode
                    Confidence = 'High'
                    Method = 'Jikan API'
                }
            }
            
            $runningTotal += $seasonEpisodes
        }
        
        # Beyond known episodes
        if ($AbsoluteEpisode -gt $runningTotal) {
            Write-LogMessage "Episode $AbsoluteEpisode exceeds known ($runningTotal)" -Level Warning -Category Processing
            
            $lastSeason = $allSeasons[-1]
            $episodesIntoNew = $AbsoluteEpisode - $runningTotal
            
            if ($episodesIntoNew -gt 12) {
                $newSeason = $lastSeason.SeasonNumber + 1
                return @{
                    Season = $newSeason
                    Episode = $episodesIntoNew
                    SeasonTitle = "$($animeDetails.title) (Unreleased Season)"
                    TotalSeasons = $allSeasons.Count
                    AbsoluteEpisode = $AbsoluteEpisode
                    Confidence = 'Low'
                    Method = 'Extrapolation'
                    Warning = "Beyond known releases"
                }
            }
            else {
                return @{
                    Season = $lastSeason.SeasonNumber
                    Episode = ($lastSeason.Episodes + $episodesIntoNew)
                    SeasonTitle = $lastSeason.Title
                    TotalSeasons = $allSeasons.Count
                    AbsoluteEpisode = $AbsoluteEpisode
                    Confidence = 'Medium'
                    Method = 'Continuation'
                    Warning = "May be ongoing season"
                }
            }
        }
        
        return @{
            Season = 1
            Episode = $AbsoluteEpisode
            Confidence = 'Low'
            Method = 'Fallback'
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to map absolute episode" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                SeriesName = $SeriesName
                AbsoluteEpisode = $AbsoluteEpisode
                MalId = $MalId
            } `
            -Source "Get-SeasonFromAbsoluteNumber"
        
        return @{
            Season = 1
            Episode = $AbsoluteEpisode
            Confidence = 'Low'
            Method = 'Error'
        }
    }
}

function Test-IsAbsoluteNumbering {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Files
    )
    
    $absoluteCount = 0
    $seasonEpisodeCount = 0
    $maxNumber = 0
    
    foreach ($file in $Files) {
        $fileName = $file.BaseName
        
        if ($fileName -match 'S\d{1,2}E\d{1,4}') {
            $seasonEpisodeCount++
        }
        else {
            $absNum = Get-AbsoluteEpisodeNumber -FileName $fileName
            if ($absNum -gt 0) {
                $absoluteCount++
                if ($absNum -gt $maxNumber) {
                    $maxNumber = $absNum
                }
            }
        }
    }
    
    Write-Verbose "Absolute: $absoluteCount (max: $maxNumber)"
    Write-Verbose "S##E##: $seasonEpisodeCount"
    
    $isAbsolute = ($absoluteCount -gt $seasonEpisodeCount) -and ($maxNumber -gt 50)
    
    return @{
        IsAbsolute = $isAbsolute
        AbsoluteCount = $absoluteCount
        SeasonEpisodeCount = $seasonEpisodeCount
        MaxEpisodeNumber = $maxNumber
    }
}

function Convert-AbsoluteToSeasonEpisode {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath,
        
        [Parameter(Mandatory)]
        [string]$SeriesName,
        
        [string]$OutputPath,
        
        [switch]$WhatIf
    )
    
    try {
        Write-LogMessage "========================================" -Level Info
        Write-LogMessage "Absolute Numbering Conversion" -Level Info
        Write-LogMessage "Series: $SeriesName" -Level Info
        Write-LogMessage "========================================" -Level Info
        
        $files = Get-VideoFiles -Path $FolderPath -Recurse
        
        if ($files.Count -eq 0) {
            Write-LogMessage "No video files found" -Level Warning
            return
        }
        
        $check = Test-IsAbsoluteNumbering -Files $files
        
        if (-not $check.IsAbsolute) {
            Write-LogMessage "NOT absolute numbering" -Level Info
            return
        }
        
        Write-LogMessage "CONFIRMED: Absolute numbering" -Level Success
        
        $cleanQuery = Clean-SearchQuery -Query $SeriesName
        $searchResults = Search-JikanAPI -Query $cleanQuery
        
        if (-not $searchResults) {
            Write-LogMessage "Series not found in MAL" -Level Error
            return
        }
        
        $malId = $searchResults[0].mal_id
        Write-LogMessage "Found MAL ID: $malId" -Level Success
        
        $mappings = @()
        $failedMappings = @()
        
        foreach ($file in $files) {
            $absNum = Get-AbsoluteEpisodeNumber -FileName $file.BaseName
            
            if ($absNum -gt 0) {
                $mapping = Get-SeasonFromAbsoluteNumber -SeriesName $SeriesName -AbsoluteEpisode $absNum -MalId $malId
                
                if ($mapping.Confidence -eq 'High') {
                    $mappings += @{
                        File = $file
                        AbsoluteEpisode = $absNum
                        Season = $mapping.Season
                        Episode = $mapping.Episode
                        SeasonTitle = $mapping.SeasonTitle
                        Confidence = $mapping.Confidence
                        Method = $mapping.Method
                    }
                    
                    $seasonStr = $mapping.Season.ToString('D2')
                    $episodeStr = $mapping.Episode.ToString('D2')
                    Write-Host "  OK Abs $absNum -> S${seasonStr}E${episodeStr}" -ForegroundColor Green
                }
                else {
                    $failedMappings += @{
                        File = $file
                        AbsoluteEpisode = $absNum
                        Reason = $mapping.Method
                    }
                    
                    Write-Host "  FAILED Abs $absNum" -ForegroundColor Red
                }
            }
        }
        
        Write-LogMessage "========================================" -Level Info
        Write-LogMessage "Summary: $($mappings.Count) mapped, $($failedMappings.Count) failed" -Level Info
        Write-LogMessage "========================================" -Level Info
        
        return @{
            Mappings = $mappings
            Failed = $failedMappings
            TotalFiles = $files.Count
            MappedFiles = $mappings.Count
        }
    }
    catch {
        Write-ErrorLog -Message "Failed to convert absolute numbering" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FolderPath = $FolderPath
                SeriesName = $SeriesName
            } `
            -Source "Convert-AbsoluteToSeasonEpisode"
    }
}

Export-ModuleMember -Function @(
    'Get-AbsoluteEpisodeNumber',
    'Get-SeasonFromAbsoluteNumber',
    'Test-IsAbsoluteNumbering',
    'Convert-AbsoluteToSeasonEpisode'
)