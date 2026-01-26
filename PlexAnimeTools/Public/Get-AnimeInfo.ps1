# =============================================================================
# Get-AnimeInfo Function
# Retrieves anime information from Jikan/MAL
# =============================================================================

function Get-AnimeInfo {
    <#
    .SYNOPSIS
        Gets anime information from MyAnimeList via Jikan API
    
    .DESCRIPTION
        Searches MyAnimeList and returns detailed anime information including
        episodes, synopsis, scores, and metadata
    
    .PARAMETER Title
        Anime title to search for
    
    .PARAMETER MalId
        MyAnimeList ID for direct lookup
    
    .PARAMETER IncludeEpisodes
        Include full episode list in results
    
    .EXAMPLE
        Get-AnimeInfo -Title "Attack on Titan"
        
        Searches for Attack on Titan and returns details
    
    .EXAMPLE
        Get-AnimeInfo -MalId 16498 -IncludeEpisodes
        
        Gets details for MAL ID 16498 with full episode list
    
    .EXAMPLE
        Get-AnimeInfo -Title "One Piece" | Select-Object Title, Episodes, Score
        
        Search and select specific properties
    
    .EXAMPLE
        Get-AnimeInfo -Title "Naruto" -IncludeEpisodes | 
            Select-Object -ExpandProperty EpisodeList | 
            Export-Csv "naruto_episodes.csv"
        
        Export episode list to CSV
    #>
    
    [CmdletBinding(DefaultParameterSetName = 'Title')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Title', Position = 0)]
        [string]$Title,
        
        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [int]$MalId,
        
        [switch]$IncludeEpisodes
    )
    
    try {
        # Search or get direct
        if ($PSCmdlet.ParameterSetName -eq 'Title') {
            Write-LogMessage "Searching for: $Title" -Level Info
            
            $results = Search-JikanAPI -Query $Title
            
            if (-not $results) {
                Write-LogMessage "No results found for: $Title" -Level Warning
                return $null
            }
            
            if ($results.Count -gt 1) {
                Write-LogMessage "Found $($results.Count) results, using first match" -Level Warning
            }
            
            # Use first result
            $anime = $results[0]
            $MalId = $anime.mal_id
            
            Write-LogMessage "Selected: $($anime.title) (MAL ID: $MalId)" -Level Info
        }
        
        # Get detailed info
        Write-LogMessage "Fetching details for MAL ID: $MalId" -Level Info
        $details = Get-JikanAnimeDetails -MalId $MalId
        
        if (-not $details) {
            Write-LogMessage "Failed to get details for MAL ID: $MalId" -Level Error
            return $null
        }
        
        # Get episodes if requested
        $episodeList = @()
        if ($IncludeEpisodes) {
            Write-LogMessage "Fetching episode list..." -Level Info
            $episodes = Get-JikanEpisodes -MalId $MalId
            
            $episodeList = $episodes | ForEach-Object {
                [PSCustomObject]@{
                    Number = $_.mal_id
                    Title = $_.title
                    Aired = $_.aired
                    Filler = $_.filler
                    Recap = $_.recap
                }
            }
        }
        
        # Build comprehensive info object
        $info = [PSCustomObject]@{
            PSTypeName = 'PlexAnimeTools.AnimeInfo'
            MalId = $details.mal_id
            Title = $details.title
            EnglishTitle = $details.title_english
            JapaneseTitle = $details.title_japanese
            Type = $details.type
            Episodes = $details.episodes
            Status = $details.status
            Airing = $details.airing
            Aired = @{
                From = $details.aired.from
                To = $details.aired.to
            }
            Score = $details.score
            ScoredBy = $details.scored_by
            Rank = $details.rank
            Popularity = $details.popularity
            Members = $details.members
            Favorites = $details.favorites
            Year = $details.year
            Season = $details.season
            Studios = ($details.studios | Select-Object -ExpandProperty name) -join ', '
            Genres = ($details.genres | Select-Object -ExpandProperty name) -join ', '
            Themes = ($details.themes | Select-Object -ExpandProperty name) -join ', '
            Demographics = ($details.demographics | Select-Object -ExpandProperty name) -join ', '
            Synopsis = $details.synopsis
            Background = $details.background
            ImageUrl = $details.images.jpg.large_image_url
            TrailerUrl = $details.trailer.url
            MalUrl = $details.url
            EpisodeList = $episodeList
        }
        
        Write-LogMessage "Successfully retrieved info for: $($info.Title)" -Level Success
        
        return $info
    }
    catch {
        Write-ErrorLog "Get-AnimeInfo failed" $_
        return $null
    }
}
