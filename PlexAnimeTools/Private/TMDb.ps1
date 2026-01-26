# =============================================================================
# TMDb API Functions (The Movie Database)
# API Documentation: https://developers.themoviedb.org/
# Updated with Enhanced Error Logging
# =============================================================================

function Search-TMDbAPI {
    <#
    .SYNOPSIS
        Searches The Movie Database
    
    .PARAMETER Query
        Search query string
    
    .PARAMETER Type
        Content type (tv or movie)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [ValidateSet('tv', 'movie')]
        [string]$Type = 'tv'
    )
    
    # Check if API key is configured
    if ($script:DefaultConfig.TMDbAPIKey -eq "YOUR_TMDB_API_KEY_HERE") {
        Write-ErrorLog -Message "TMDb API key not configured" `
            -ErrorRecord $null `
            -Category Configuration `
            -Context @{
                Query = $Query
                Type = $Type
                ConfigFile = (Join-Path $script:ConfigPath "default.json")
                HelpURL = "https://www.themoviedb.org/settings/api"
            } `
            -Source "Search-TMDbAPI"
        
        Write-LogMessage "Get a free API key at: https://www.themoviedb.org/settings/api" -Level Info -Category Configuration -Source "Search-TMDbAPI"
        return $null
    }
    
    try {
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
        $apiKey = $script:DefaultConfig.TMDbAPIKey
        $url = "https://api.themoviedb.org/3/search/$Type`?api_key=$apiKey&query=$encodedQuery"
        
        Write-LogMessage "Searching TMDb for: $Query ($Type)" -Level Info -Category API -Source "Search-TMDbAPI"
        
        # Rate limiting
        Start-Sleep -Milliseconds $script:DefaultConfig.TMDbRateLimit
        
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        if ($response.results -and $response.results.Count -gt 0) {
            Write-LogMessage "Found $($response.results.Count) result(s)" -Level Success -Category API -Source "Search-TMDbAPI"
            return $response.results
        }
        
        Write-LogMessage "No results found" -Level Warning -Category API -Source "Search-TMDbAPI"
        return $null
    }
    catch {
        Write-ErrorLog -Message "TMDb API search failed for query: $Query" `
            -ErrorRecord $_ `
            -Category API `
            -Context @{
                Query = $Query
                Type = $Type
                URL = $url
                RateLimit = $script:DefaultConfig.TMDbRateLimit
                EncodedQuery = $encodedQuery
                APIKeyLength = $apiKey.Length
            } `
            -Source "Search-TMDbAPI"
        
        return $null
    }
}

function Get-TMDbDetails {
    <#
    .SYNOPSIS
        Retrieves detailed information from TMDb
    
    .PARAMETER Id
        TMDb ID
    
    .PARAMETER Type
        Content type (tv or movie)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Id,
        
        [ValidateSet('tv', 'movie')]
        [string]$Type = 'tv'
    )
    
    try {
        $apiKey = $script:DefaultConfig.TMDbAPIKey
        $url = "https://api.themoviedb.org/3/$Type/${Id}?api_key=$apiKey"
        
        Write-LogMessage "Fetching TMDb details for ID: $Id" -Level Info -Category API -Source "Get-TMDbDetails"
        
        # Rate limiting
        Start-Sleep -Milliseconds $script:DefaultConfig.TMDbRateLimit
        
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        if ($response) {
            Write-LogMessage "Retrieved details successfully" -Level Success -Category API -Source "Get-TMDbDetails"
            return $response
        }
        
        Write-LogMessage "No data returned for TMDb ID: $Id" -Level Warning -Category API -Source "Get-TMDbDetails"
        return $null
    }
    catch {
        Write-ErrorLog -Message "Failed to get TMDb details for ID: $Id" `
            -ErrorRecord $_ `
            -Category API `
            -Context @{
                TMDbId = $Id
                Type = $Type
                URL = $url
                RateLimit = $script:DefaultConfig.TMDbRateLimit
            } `
            -Source "Get-TMDbDetails"
        
        return $null
    }
}

function Get-TMDbSeasonDetails {
    <#
    .SYNOPSIS
        Retrieves season details from TMDb
    
    .PARAMETER ShowId
        TMDb show ID
    
    .PARAMETER SeasonNumber
        Season number
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$ShowId,
        
        [Parameter(Mandatory)]
        [int]$SeasonNumber
    )
    
    try {
        $apiKey = $script:DefaultConfig.TMDbAPIKey
        $url = "https://api.themoviedb.org/3/tv/$ShowId/season/${SeasonNumber}?api_key=$apiKey"
        
        Write-LogMessage "Fetching season $SeasonNumber details" -Level Info -Category API -Source "Get-TMDbSeasonDetails"
        
        # Rate limiting
        Start-Sleep -Milliseconds $script:DefaultConfig.TMDbRateLimit
        
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        if ($response) {
            Write-LogMessage "Retrieved $($response.episodes.Count) episode(s)" -Level Success -Category API -Source "Get-TMDbSeasonDetails"
            return $response
        }
        
        Write-LogMessage "No data returned for Show ID: $ShowId, Season: $SeasonNumber" -Level Warning -Category API -Source "Get-TMDbSeasonDetails"
        return $null
    }
    catch {
        Write-ErrorLog -Message "Failed to get season details for Show ID: $ShowId, Season: $SeasonNumber" `
            -ErrorRecord $_ `
            -Category API `
            -Context @{
                ShowId = $ShowId
                SeasonNumber = $SeasonNumber
                URL = $url
                RateLimit = $script:DefaultConfig.TMDbRateLimit
            } `
            -Source "Get-TMDbSeasonDetails"
        
        return $null
    }
}