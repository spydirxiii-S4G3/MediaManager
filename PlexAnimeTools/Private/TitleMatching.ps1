# =============================================================================
# Enhanced Title Matching System
# Smart matching for anime/TV series with multiple naming conventions
# FIXED: Array access syntax corrected for PowerShell
# =============================================================================

# Known franchise mappings for better matching
$script:FranchiseMappings = @{
    'Pokemon' = @{
        MainTitle = 'Pokemon'
        Aliases = @(
            'Pokémon',
            'Pocket Monsters'
        )
        SubSeries = @(
            @{ Name = 'Indigo League'; Season = 1; Aliases = @('Kanto') }
            @{ Name = 'Adventures in the Orange Islands'; Season = 2; Aliases = @('Orange Islands', 'Orange League') }
            @{ Name = 'The Johto Journeys'; Season = 3; Aliases = @('Johto') }
            @{ Name = 'Johto League Champions'; Season = 4; Aliases = @('Johto League') }
            @{ Name = 'Master Quest'; Season = 5; Aliases = @('Johto Master Quest') }
            @{ Name = 'Advanced'; Season = 6; Aliases = @('Hoenn', 'Advanced Generation') }
            @{ Name = 'Advanced Challenge'; Season = 7; Aliases = @('Hoenn Challenge') }
            @{ Name = 'Advanced Battle'; Season = 8; Aliases = @('Hoenn Battle') }
            @{ Name = 'Battle Frontier'; Season = 9; Aliases = @('Advanced Battle Frontier') }
            @{ Name = 'Diamond and Pearl'; Season = 10; Aliases = @('Sinnoh', 'DP') }
            @{ Name = 'Diamond and Pearl Battle Dimension'; Season = 11; Aliases = @('Sinnoh Battle Dimension') }
            @{ Name = 'Diamond and Pearl Galactic Battles'; Season = 12; Aliases = @('Sinnoh Galactic Battles') }
            @{ Name = 'Diamond and Pearl Sinnoh League Victors'; Season = 13; Aliases = @('Sinnoh League Victors') }
            @{ Name = 'Black and White'; Season = 14; Aliases = @('Unova', 'BW', 'Best Wishes') }
            @{ Name = 'Black and White Rival Destinies'; Season = 15; Aliases = @('Unova Rival Destinies') }
            @{ Name = 'Black and White Adventures in Unova'; Season = 16; Aliases = @('Adventures in Unova') }
            @{ Name = 'XY'; Season = 17; Aliases = @('X and Y', 'Kalos') }
            @{ Name = 'XY Kalos Quest'; Season = 18; Aliases = @('Kalos Quest') }
            @{ Name = 'XYZ'; Season = 19; Aliases = @('X Y Z', 'Kalos League') }
            @{ Name = 'Sun and Moon'; Season = 20; Aliases = @('Alola', 'SM') }
            @{ Name = 'Sun and Moon Ultra Adventures'; Season = 21; Aliases = @('Alola Ultra Adventures') }
            @{ Name = 'Sun and Moon Ultra Legends'; Season = 22; Aliases = @('Alola Ultra Legends') }
            @{ Name = 'Journeys'; Season = 23; Aliases = @('Sword and Shield', 'Galar') }
            @{ Name = 'Master Journeys'; Season = 24 }
            @{ Name = 'Ultimate Journeys'; Season = 25 }
        )
    }
    'Naruto' = @{
        MainTitle = 'Naruto'
        Aliases = @()
        SubSeries = @(
            @{ Name = 'Naruto'; Season = 1 }
            @{ Name = 'Naruto Shippuden'; Season = 2; Aliases = @('Shippuden', 'Shippuuden') }
            @{ Name = 'Boruto'; Season = 3; Aliases = @('Boruto: Naruto Next Generations') }
        )
    }
    'Dragon Ball' = @{
        MainTitle = 'Dragon Ball'
        Aliases = @('Dragonball')
        SubSeries = @(
            @{ Name = 'Dragon Ball'; Season = 1 }
            @{ Name = 'Dragon Ball Z'; Season = 2; Aliases = @('DBZ') }
            @{ Name = 'Dragon Ball GT'; Season = 3; Aliases = @('DBGT') }
            @{ Name = 'Dragon Ball Super'; Season = 4; Aliases = @('DBS') }
        )
    }
}

function Find-BestTitleMatch {
    <#
    .SYNOPSIS
        Finds the best matching title using fuzzy matching and franchise awareness
    
    .PARAMETER Query
        Search query (folder name)
    
    .PARAMETER ExistingTitles
        Array of existing title paths to match against
    
    .OUTPUTS
        Best matching title or null if no good match
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [Parameter(Mandatory)]
        [array]$ExistingTitles
    )
    
    try {
        # Clean the query
        $cleanQuery = $Query -replace 'Season\s+\d+', '' -replace '\s+', ' ' -replace '[^\w\s]', '' 
        $cleanQuery = $cleanQuery.Trim()
        
        Write-Verbose "Finding match for: '$cleanQuery'"
        Write-Verbose "Against $($ExistingTitles.Count) existing titles"
        
        $bestMatch = $null
        $bestScore = 0
        
        foreach ($existingPath in $ExistingTitles) {
            $existingTitle = Split-Path $existingPath -Leaf
            $cleanExisting = $existingTitle -replace '[^\w\s]', '' -replace '\s+', ' '
            $cleanExisting = $cleanExisting.Trim()
            
            # Calculate similarity score
            $score = Get-SimilarityScore -String1 $cleanQuery -String2 $cleanExisting
            
            # Check for franchise match
            $franchiseBonus = Get-FranchiseMatchBonus -Query $Query -ExistingTitle $existingTitle
            $score += $franchiseBonus
            
            Write-Verbose "  '$cleanExisting': Score = $score (bonus: $franchiseBonus)"
            
            if ($score > $bestScore) {
                $bestScore = $score
                $bestMatch = $existingPath
            }
        }
        
        # Only return match if score is above threshold
        $threshold = 0.6
        if ($bestScore -ge $threshold) {
            Write-Verbose "Best match: '$bestMatch' (score: $bestScore)"
            return @{
                Path = $bestMatch
                Score = $bestScore
                Title = (Split-Path $bestMatch -Leaf)
            }
        }
        
        Write-Verbose "No good match found (best score: $bestScore < threshold: $threshold)"
        return $null
    }
    catch {
        Write-Verbose "Error in Find-BestTitleMatch: $_"
        return $null
    }
}

function Get-SimilarityScore {
    <#
    .SYNOPSIS
        Calculates similarity score between two strings using multiple methods
    
    .PARAMETER String1
        First string
    
    .PARAMETER String2
        Second string
    
    .OUTPUTS
        Similarity score between 0 and 1
    #>
    
    [CmdletBinding()]
    param(
        [string]$String1,
        [string]$String2
    )
    
    $s1 = $String1.ToLower()
    $s2 = $String2.ToLower()
    
    # Exact match
    if ($s1 -eq $s2) {
        return 1.0
    }
    
    # One contains the other
    if ($s1.Contains($s2) -or $s2.Contains($s1)) {
        $longer = if ($s1.Length -gt $s2.Length) { $s1 } else { $s2 }
        $shorter = if ($s1.Length -le $s2.Length) { $s1 } else { $s2 }
        return 0.8 * ($shorter.Length / $longer.Length)
    }
    
    # Calculate Levenshtein distance
    $distance = Get-LevenshteinDistance -String1 $s1 -String2 $s2
    $maxLength = [Math]::Max($s1.Length, $s2.Length)
    
    if ($maxLength -eq 0) {
        return 1.0
    }
    
    $similarity = 1.0 - ($distance / $maxLength)
    
    # Boost score if words match
    $words1 = $s1 -split '\s+' | Where-Object { $_.Length -gt 2 }
    $words2 = $s2 -split '\s+' | Where-Object { $_.Length -gt 2 }
    
    $matchingWords = 0
    foreach ($word in $words1) {
        if ($words2 -contains $word) {
            $matchingWords++
        }
    }
    
    if ($words1.Count -gt 0) {
        $wordBonus = ($matchingWords / $words1.Count) * 0.2
        $similarity += $wordBonus
    }
    
    return [Math]::Min($similarity, 1.0)
}

function Get-LevenshteinDistance {
    <#
    .SYNOPSIS
        Calculates Levenshtein distance between two strings
    #>
    
    [CmdletBinding()]
    param(
        [string]$String1,
        [string]$String2
    )
    
    $len1 = $String1.Length
    $len2 = $String2.Length
    
    # FIXED: Corrected multi-dimensional array syntax for PowerShell
    $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)
    
    for ($i = 0; $i -le $len1; $i++) {
        $matrix[$i, 0] = $i
    }
    
    for ($j = 0; $j -le $len2; $j++) {
        $matrix[0, $j] = $j
    }
    
    for ($i = 1; $i -le $len1; $i++) {
        for ($j = 1; $j -le $len2; $j++) {
            $cost = if ($String1[$i - 1] -eq $String2[$j - 1]) { 0 } else { 1 }
            
            # FIXED: Separate variable assignments instead of nested expressions
            $deletion = $matrix[($i - 1), $j] + 1
            $insertion = $matrix[$i, ($j - 1)] + 1
            $substitution = $matrix[($i - 1), ($j - 1)] + $cost
            
            $matrix[$i, $j] = [Math]::Min([Math]::Min($deletion, $insertion), $substitution)
        }
    }
    
    return $matrix[$len1, $len2]
}

function Get-FranchiseMatchBonus {
    <#
    .SYNOPSIS
        Gets bonus score for franchise/sub-series matches
    
    .PARAMETER Query
        Search query
    
    .PARAMETER ExistingTitle
        Existing title to match against
    
    .OUTPUTS
        Bonus score (0-0.4)
    #>
    
    [CmdletBinding()]
    param(
        [string]$Query,
        [string]$ExistingTitle
    )
    
    $bonus = 0
    
    foreach ($franchise in $script:FranchiseMappings.Keys) {
        $franchiseInfo = $script:FranchiseMappings[$franchise]
        
        # Check if query and existing both relate to this franchise
        $queryMatchesFranchise = $Query -match $franchise -or 
                                 $franchiseInfo.Aliases | Where-Object { $Query -match $_ }
        
        $existingMatchesFranchise = $ExistingTitle -match $franchise -or
                                    $franchiseInfo.Aliases | Where-Object { $ExistingTitle -match $_ }
        
        if ($queryMatchesFranchise -and $existingMatchesFranchise) {
            $bonus += 0.3
            
            # Check for sub-series match
            foreach ($subSeries in $franchiseInfo.SubSeries) {
                $queryMatchesSub = $Query -match $subSeries.Name -or
                                  $subSeries.Aliases | Where-Object { $Query -match $_ }
                
                $existingMatchesSub = $ExistingTitle -match $subSeries.Name -or
                                     $subSeries.Aliases | Where-Object { $ExistingTitle -match $_ }
                
                if ($queryMatchesSub -and $existingMatchesSub) {
                    $bonus += 0.1
                    break
                }
            }
            
            break
        }
    }
    
    return $bonus
}

function Get-FranchiseMainTitle {
    <#
    .SYNOPSIS
        Gets the main franchise title for a query
    
    .PARAMETER Query
        Search query
    
    .OUTPUTS
        Main franchise title or original query
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query
    )
    
    foreach ($franchise in $script:FranchiseMappings.Keys) {
        $franchiseInfo = $script:FranchiseMappings[$franchise]
        
        if ($Query -match $franchise -or 
            $franchiseInfo.Aliases | Where-Object { $Query -match $_ }) {
            return $franchiseInfo.MainTitle
        }
    }
    
    return $Query
}

function Get-SubSeriesSeason {
    <#
    .SYNOPSIS
        Gets the season number for a franchise sub-series
    
    .PARAMETER Query
        Search query containing sub-series name
    
    .OUTPUTS
        Season number or 1 if not found
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query
    )
    
    foreach ($franchise in $script:FranchiseMappings.Keys) {
        $franchiseInfo = $script:FranchiseMappings[$franchise]
        
        if ($Query -match $franchise -or 
            $franchiseInfo.Aliases | Where-Object { $Query -match $_ }) {
            
            foreach ($subSeries in $franchiseInfo.SubSeries) {
                if ($Query -match $subSeries.Name -or
                    $subSeries.Aliases | Where-Object { $Query -match $_ }) {
                    return $subSeries.Season
                }
            }
        }
    }
    
    # Try to extract season number from query
    if ($Query -match 'Season\s+(\d+)') {
        return [int]$Matches[1]
    }
    
    return 1
}