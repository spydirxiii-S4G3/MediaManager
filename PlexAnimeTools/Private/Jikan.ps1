# =============================================================================
# Jikan API Functions (MyAnimeList Unofficial API)
# API Documentation: https://docs.api.jikan.moe/
# Updated with Enhanced Error Logging
# =============================================================================

function Search-JikanAPI {
    <#
    .SYNOPSIS
        Searches MyAnimeList via Jikan API
    
    .PARAMETER Query
        Search query string
    
    .PARAMETER Type
        Content type filter (tv, movie, ova, special, ona)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [ValidateSet('', 'tv', 'movie', 'ova', 'special', 'ona')]
        [string]$Type = ''
    )
    
    try {
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
        $url = "https://api.jikan.moe/v4/anime?q=$encodedQuery&limit=15"
        
        if ($Type) {
            $url += "&type=$Type"
        }
        
        Write-LogMessage "Searching Jikan for: $Query" -Level Info -Category API -Source "Search-JikanAPI"
        
        # Rate limiting
        Start-Sleep -Milliseconds $script:DefaultConfig.JikanRateLimit
        
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        if ($response.data -and $response.data.Count -gt 0) {
            Write-LogMessage "Found $($response.data.Count) result(s)" -Level Success -Category API -Source "Search-JikanAPI"
            return $response.data
        }
        
        Write-LogMessage "No results found" -Level Warning -Category API -Source "Search-JikanAPI"
        return $null
    }
    catch {
        Write-ErrorLog -Message "Jikan API search failed for query: $Query" `
            -ErrorRecord $_ `
            -Category API `
            -Context @{
                Query = $Query
                Type = $Type
                URL = $url
                RateLimit = $script:DefaultConfig.JikanRateLimit
                EncodedQuery = $encodedQuery
            } `
            -Source "Search-JikanAPI"
        
        return $null
    }
}

function Get-JikanEpisodes {
    <#
    .SYNOPSIS
        Retrieves episode list for an anime from Jikan
    
    .PARAMETER MalId
        MyAnimeList ID
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$MalId
    )
    
    try {
        $allEpisodes = @()
        $page = 1
        $maxPages = 100  # Safety limit
        
        Write-LogMessage "Fetching episodes for MAL ID: $MalId" -Level Info -Category API -Source "Get-JikanEpisodes"
        
        do {
            $url = "https://api.jikan.moe/v4/anime/$MalId/episodes?page=$page"
            
            # Rate limiting
            Start-Sleep -Milliseconds $script:DefaultConfig.JikanRateLimit
            
            try {
                $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
                
                if ($response.data) {
                    $allEpisodes += $response.data
                    Write-Verbose "Fetched page $page with $($response.data.Count) episode(s)"
                }
                
                $hasNextPage = $response.pagination.has_next_page
                $page++
            }
            catch {
                Write-ErrorLog -Message "Failed to fetch episode page $page for MAL ID: $MalId" `
                    -ErrorRecord $_ `
                    -Category API `
                    -Context @{
                        MalId = $MalId
                        Page = $page
                        URL = $url
                        EpisodesFetchedSoFar = $allEpisodes.Count
                    } `
                    -Source "Get-JikanEpisodes"
                
                # Break the loop on error
                break
            }
            
        } while ($hasNextPage -and $page -le $maxPages)
        
        if ($allEpisodes.Count -gt 0) {
            Write-LogMessage "Fetched $($allEpisodes.Count) episode(s) from Jikan" -Level Success -Category API -Source "Get-JikanEpisodes"
        }
        else {
            Write-LogMessage "No episodes found for MAL ID: $MalId" -Level Warning -Category API -Source "Get-JikanEpisodes"
        }
        
        return $allEpisodes
    }
    catch {
        Write-ErrorLog -Message "Failed to get episodes for MAL ID: $MalId" `
            -ErrorRecord $_ `
            -Category API `
            -Context @{
                MalId = $MalId
                MaxPages = $maxPages
                RateLimit = $script:DefaultConfig.JikanRateLimit
            } `
            -Source "Get-JikanEpisodes"
        
        return @()
    }
}

function Get-JikanAnimeDetails {
    <#
    .SYNOPSIS
        Retrieves full anime details from Jikan
    
    .PARAMETER MalId
        MyAnimeList ID
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$MalId
    )
    
    try {
        $url = "https://api.jikan.moe/v4/anime/$MalId/full"
        
        Write-LogMessage "Fetching details for MAL ID: $MalId" -Level Info -Category API -Source "Get-JikanAnimeDetails"
        
        # Rate limiting
        Start-Sleep -Milliseconds $script:DefaultConfig.JikanRateLimit
        
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        if ($response.data) {
            Write-LogMessage "Retrieved details successfully" -Level Success -Category API -Source "Get-JikanAnimeDetails"
            return $response.data
        }
        
        Write-LogMessage "No data returned for MAL ID: $MalId" -Level Warning -Category API -Source "Get-JikanAnimeDetails"
        return $null
    }
    catch {
        Write-ErrorLog -Message "Failed to get anime details for MAL ID: $MalId" `
            -ErrorRecord $_ `
            -Category API `
            -Context @{
                MalId = $MalId
                URL = $url
                RateLimit = $script:DefaultConfig.JikanRateLimit
            } `
            -Source "Get-JikanAnimeDetails"
        
        return $null
    }
}