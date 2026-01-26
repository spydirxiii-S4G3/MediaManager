# =============================================================================
# Wikipedia.ps1
# Scrapes Wikipedia episode lists for accurate season/episode information
# =============================================================================

# Load required assembly for URL encoding
Add-Type -AssemblyName System.Web

function Get-WikipediaEpisodeList {
    <#
    .SYNOPSIS
        Scrapes Wikipedia for episode list information
    
    .PARAMETER SeriesName
        Name of the series to search for
    
    .PARAMETER Season
        Optional season number to get specific season data
    
    .OUTPUTS
        Episode list with titles and numbers
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SeriesName,
        
        [int]$Season = 0
    )
    
    try {
        # Build Wikipedia URL variations
        $searchName = $SeriesName -replace '\s+', '_'
        $searchNameHyphen = $SeriesName -replace '\s+', '-'
        
        # Try many variations to find the page
        $urls = @()
        
        # For each naming style (underscore and hyphen), try common patterns
        foreach ($name in @($searchName, $searchNameHyphen)) {
            $urls += "https://en.wikipedia.org/wiki/List_of_${name}_episodes"
            $urls += "https://en.wikipedia.org/wiki/${name}_episodes"
            $urls += "https://en.wikipedia.org/wiki/${name}_(TV_series)"
            $urls += "https://en.wikipedia.org/wiki/${name}_(anime)"
            $urls += "https://en.wikipedia.org/wiki/${name}_(manga)"
            $urls += "https://en.wikipedia.org/wiki/${name}_episode_list"
            $urls += "https://en.wikipedia.org/wiki/Episode_list_of_${name}"
            $urls += "https://en.wikipedia.org/wiki/${name}_(season_${Season})"
            $urls += "https://en.wikipedia.org/wiki/${name}_season_${Season}"
            $urls += "https://en.wikipedia.org/wiki/${name}"
            $urls += "https://en.wikipedia.org/wiki/${name}:_Episode_list"
            $urls += "https://en.wikipedia.org/wiki/List_of_${name}_episodes_(TV_series)"
            $urls += "https://en.wikipedia.org/wiki/List_of_${name}_episodes_(anime)"
        }
        
        # Remove duplicates
        $urls = $urls | Select-Object -Unique
        
        Write-Verbose "Searching Wikipedia with $($urls.Count) URL variations..."
        Write-Verbose "  Underscore variant: $searchName"
        Write-Verbose "  Hyphen variant: $searchNameHyphen"
        
        $content = $null
        $foundUrl = $null
        
        foreach ($url in $urls) {
            try {
                Write-Verbose "Trying: $url"
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    $content = $response.Content
                    $foundUrl = $url
                    Write-Verbose "SUCCESS: Found page at $url"
                    break
                }
            }
            catch {
                Write-Verbose "Not found: $url"
                continue
            }
        }
        
        if (-not $content) {
            # Last resort: Try Google search to find the Wikipedia page
            Write-Verbose "Direct URL search failed, trying Google search..."
            
            try {
                $googleQuery = [System.Web.HttpUtility]::UrlEncode("$SeriesName episodes site:en.wikipedia.org")
                $googleUrl = "https://www.google.com/search?q=$googleQuery"
                
                Write-Verbose "Google search: $googleUrl"
                
                $googleResponse = Invoke-WebRequest -Uri $googleUrl -UseBasicParsing -TimeoutSec 10 -UserAgent "Mozilla/5.0" -ErrorAction Stop
                
                # Extract Wikipedia URLs from search results
                $wikiUrlPattern = 'https://en\.wikipedia\.org/wiki/[^"&<>]+'
                $wikiUrls = [regex]::Matches($googleResponse.Content, $wikiUrlPattern) | 
                    ForEach-Object { $_.Value } | 
                    Where-Object { $_ -match 'episode' -or $_ -match 'list' } |
                    Select-Object -Unique -First 5
                
                Write-Verbose "Found $($wikiUrls.Count) Wikipedia URLs from Google"
                
                foreach ($wikiUrl in $wikiUrls) {
                    try {
                        Write-Verbose "Trying Google result: $wikiUrl"
                        $response = Invoke-WebRequest -Uri $wikiUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                        if ($response.StatusCode -eq 200) {
                            $content = $response.Content
                            $foundUrl = $wikiUrl
                            Write-Verbose "SUCCESS: Found page via Google: $wikiUrl"
                            break
                        }
                    }
                    catch {
                        continue
                    }
                }
            }
            catch {
                Write-Verbose "Google search also failed: $_"
            }
        }
        
        if (-not $content) {
            Write-LogMessage "Wikipedia: No episode list found for '$SeriesName' (tried $($urls.Count) direct URLs + Google search)" -Level Info -Category API -Source "Get-WikipediaEpisodeList"
            Write-LogMessage "Will fall back to Jikan/MAL for episode data" -Level Info -Category API -Source "Get-WikipediaEpisodeList"
            return $null
        }
        
        Write-LogMessage "Found Wikipedia page: $foundUrl" -Level Success -Category API -Source "Get-WikipediaEpisodeList"
        
        # Parse episode information from tables
        $episodes = @()
        
        # Look for episode table patterns
        $tablePattern = '<table[^>]*class="[^"]*wikitable[^"]*"[^>]*>(.*?)</table>'
        $tables = [regex]::Matches($content, $tablePattern, 'Singleline')
        
        foreach ($table in $tables) {
            $tableHtml = $table.Groups[1].Value
            
            # Extract rows
            $rowPattern = '<tr[^>]*>(.*?)</tr>'
            $rows = [regex]::Matches($tableHtml, $rowPattern, 'Singleline')
            
            foreach ($row in $rows) {
                $rowHtml = $row.Groups[1].Value
                
                # Extract cells
                $cellPattern = '<t[dh][^>]*>(.*?)</t[dh]>'
                $cells = [regex]::Matches($rowHtml, $cellPattern, 'Singleline')
                
                if ($cells.Count -ge 3) {
                    # Try to extract episode number and title
                    $cellValues = @()
                    foreach ($cell in $cells) {
                        $cellText = $cell.Groups[1].Value
                        # Remove HTML tags
                        $cellText = $cellText -replace '<[^>]+>', ''
                        # Decode HTML entities
                        $cellText = [System.Web.HttpUtility]::HtmlDecode($cellText)
                        $cellText = $cellText.Trim()
                        $cellValues += $cellText
                    }
                    
                    # Look for episode number and title patterns
                    foreach ($i in 0..($cellValues.Count - 2)) {
                        if ($cellValues[$i] -match '^\d+$') {
                            $epNum = [int]$cellValues[$i]
                            $epTitle = $cellValues[$i + 1]
                            
                            if ($epTitle -and $epTitle.Length -gt 2 -and $epTitle -notmatch '^\d+$') {
                                # Clean title
                                $epTitle = $epTitle -replace '"', ''
                                $epTitle = $epTitle -replace '\[.*?\]', ''
                                $epTitle = $epTitle.Trim()
                                
                                if ($epTitle.Length -gt 0) {
                                    $episodes += [PSCustomObject]@{
                                        Number = $epNum
                                        Title = $epTitle
                                        Season = $Season
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if ($episodes.Count -gt 0) {
            # Remove duplicates
            $episodes = $episodes | Sort-Object Number -Unique
            Write-LogMessage "Extracted $($episodes.Count) episodes from Wikipedia" -Level Success -Category API -Source "Get-WikipediaEpisodeList"
            return $episodes
        }
        
        Write-Warning "Could not extract episode data from Wikipedia page"
        return $null
    }
    catch {
        Write-ErrorLog -Message "Failed to get Wikipedia episode list" `
            -ErrorRecord $_ `
            -Category API `
            -Context @{
                SeriesName = $SeriesName
                Season = $Season
            } `
            -Source "Get-WikipediaEpisodeList"
        
        return $null
    }
}

function Get-WikipediaSeasonMapping {
    <#
    .SYNOPSIS
        Gets season mapping information from Wikipedia
    
    .PARAMETER SeriesName
        Name of the series
    
    .OUTPUTS
        Hashtable of season mappings
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SeriesName
    )
    
    # Pre-defined mappings for known series
    $knownMappings = @{
        'Pokemon' = @{
            Seasons = @(
                @{ Number = 1; Names = @('Indigo League', 'Kanto'); Episodes = 82 }
                @{ Number = 2; Names = @('Adventures in the Orange Islands', 'Orange Islands', 'Orange League'); Episodes = 36 }
                @{ Number = 3; Names = @('The Johto Journeys', 'Johto'); Episodes = 41 }
                @{ Number = 4; Names = @('Johto League Champions'); Episodes = 52 }
                @{ Number = 5; Names = @('Master Quest', 'Johto Master Quest'); Episodes = 65 }
                @{ Number = 6; Names = @('Advanced', 'Hoenn', 'Advanced Generation'); Episodes = 40 }
                @{ Number = 7; Names = @('Advanced Challenge', 'Hoenn Challenge'); Episodes = 52 }
                @{ Number = 8; Names = @('Advanced Battle', 'Hoenn Battle'); Episodes = 54 }
                @{ Number = 9; Names = @('Battle Frontier', 'Advanced Battle Frontier'); Episodes = 47 }
                @{ Number = 10; Names = @('Diamond and Pearl', 'Sinnoh', 'DP'); Episodes = 52 }
                @{ Number = 11; Names = @('Diamond and Pearl Battle Dimension', 'Battle Dimension'); Episodes = 52 }
                @{ Number = 12; Names = @('Diamond and Pearl Galactic Battles', 'Galactic Battles'); Episodes = 53 }
                @{ Number = 13; Names = @('Diamond and Pearl Sinnoh League Victors', 'Sinnoh League Victors'); Episodes = 34 }
                @{ Number = 14; Names = @('Black and White', 'Black & White', 'Unova', 'BW', 'Best Wishes'); Episodes = 48 }
                @{ Number = 15; Names = @('Black and White Rival Destinies', 'Rival Destinies'); Episodes = 49 }
                @{ Number = 16; Names = @('Black and White Adventures in Unova', 'Adventures in Unova'); Episodes = 45 }
                @{ Number = 17; Names = @('XY', 'X and Y', 'X & Y', 'Kalos'); Episodes = 48 }
                @{ Number = 18; Names = @('XY Kalos Quest', 'Kalos Quest'); Episodes = 45 }
                @{ Number = 19; Names = @('XYZ', 'X Y Z', 'Kalos League'); Episodes = 47 }
                @{ Number = 20; Names = @('Sun and Moon', 'Sun & Moon', 'Alola', 'SM'); Episodes = 43 }
                @{ Number = 21; Names = @('Sun and Moon Ultra Adventures', 'Ultra Adventures'); Episodes = 49 }
                @{ Number = 22; Names = @('Sun and Moon Ultra Legends', 'Ultra Legends'); Episodes = 54 }
                @{ Number = 23; Names = @('Journeys', 'Sword and Shield', 'Galar'); Episodes = 48 }
                @{ Number = 24; Names = @('Master Journeys'); Episodes = 42 }
                @{ Number = 25; Names = @('Ultimate Journeys'); Episodes = 45 }
            )
        }
    }
    
    # Check if we have a known mapping
    foreach ($key in $knownMappings.Keys) {
        if ($SeriesName -match $key) {
            return $knownMappings[$key]
        }
    }
    
    return $null
}

function Find-SeasonByName {
    <#
    .SYNOPSIS
        Finds season number by season name
    
    .PARAMETER SeriesName
        Series name
    
    .PARAMETER SeasonName
        Season name to search for
    
    .OUTPUTS
        Season number or 1 if not found
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SeriesName,
        
        [Parameter(Mandatory)]
        [string]$SeasonName
    )
    
    $mapping = Get-WikipediaSeasonMapping -SeriesName $SeriesName
    
    if ($mapping) {
        foreach ($season in $mapping.Seasons) {
            foreach ($name in $season.Names) {
                if ($SeasonName -match [regex]::Escape($name)) {
                    Write-Verbose "Matched '$SeasonName' to Season $($season.Number) via name '$name'"
                    return $season.Number
                }
            }
        }
    }
    
    # Fallback to regex extraction
    if ($SeasonName -match 'Season\s+(\d+)') {
        return [int]$Matches[1]
    }
    
    return 1
}

function Get-EpisodeTitleFromWikipedia {
    <#
    .SYNOPSIS
        Gets episode title from Wikipedia for a specific episode
    
    .PARAMETER SeriesName
        Series name
    
    .PARAMETER Season
        Season number
    
    .PARAMETER Episode
        Episode number
    
    .OUTPUTS
        Episode title or empty string
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SeriesName,
        
        [Parameter(Mandatory)]
        [int]$Season,
        
        [Parameter(Mandatory)]
        [int]$Episode
    )
    
    try {
        $episodes = Get-WikipediaEpisodeList -SeriesName $SeriesName -Season $Season
        
        if ($episodes) {
            $ep = $episodes | Where-Object { $_.Number -eq $Episode } | Select-Object -First 1
            if ($ep) {
                return $ep.Title
            }
        }
        
        return ''
    }
    catch {
        Write-Verbose "Failed to get episode title from Wikipedia: $_"
        return ''
    }
}