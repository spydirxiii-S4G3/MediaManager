# =============================================================================
# Naming and String Manipulation Functions
# Updated with Enhanced Error Logging
# =============================================================================

function Clean-SearchQuery {
    <#
    .SYNOPSIS
        Cleans folder name for API search
    
    .PARAMETER Query
        Raw query string
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query
    )
    
    try {
        $cleaned = $Query
        
        # Remove tags based on config
        if ($script:DefaultConfig.SearchSettings.RemoveTags) {
            foreach ($tag in $script:DefaultConfig.SearchSettings.RemoveTags) {
                if ($tag -eq '*') {
                    # Remove all bracketed content
                    $cleaned = $cleaned -replace '\[.*?\]', ''
                    $cleaned = $cleaned -replace '\{.*?\}', ''
                }
                else {
                    # Remove specific tag
                    $cleaned = $cleaned -replace [regex]::Escape($tag), ''
                }
            }
        }
        
        # Remove quality indicators
        if ($script:DefaultConfig.SearchSettings.RemoveQuality) {
            foreach ($quality in $script:DefaultConfig.SearchSettings.RemoveQuality) {
                if ($quality -eq '*') {
                    # Remove all quality indicators
                    $cleaned = $cleaned -replace '\b(1080p|720p|480p|2160p|4K|BluRay|BDRip|WEB-?DL|WEBRip|x264|x265|HEVC|10bit)\b', ''
                }
                else {
                    # Remove specific quality tag
                    $cleaned = $cleaned -replace "\b$quality\b", ''
                }
            }
        }
        
        # Remove season info if configured
        if ($script:DefaultConfig.SearchSettings.RemoveSeasonInfo) {
            $cleaned = $cleaned -replace '\b(Season|S)\s*0*(\d+)\b', ''
            $cleaned = $cleaned -replace '\bOVA\b', ''
            $cleaned = $cleaned -replace '\bONA\b', ''
        }
        
        # Cleanup
        $cleaned = $cleaned -replace '_', ' '
        $cleaned = $cleaned -replace '-', ' '
        $cleaned = $cleaned -replace '\s+', ' '
        $cleaned = $cleaned.Trim()
        
        Write-Verbose "Cleaned query: '$Query' -> '$cleaned'"
        
        return $cleaned
    }
    catch {
        Write-ErrorLog -Message "Error cleaning search query" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                OriginalQuery = $Query
                RemoveTags = ($script:DefaultConfig.SearchSettings.RemoveTags -join ', ')
                RemoveQuality = ($script:DefaultConfig.SearchSettings.RemoveQuality -join ', ')
            } `
            -Source "Clean-SearchQuery"
        
        # Return original query as fallback
        return $Query
    }
}

function Remove-InvalidFileNameChars {
    <#
    .SYNOPSIS
        Removes invalid filesystem characters
    
    .PARAMETER Name
        Filename to sanitize
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    try {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-ErrorLog -Message "Empty name provided for sanitization" `
                -ErrorRecord $null `
                -Category Validation `
                -Context @{
                    ProvidedName = $Name
                    IsNull = ($null -eq $Name)
                    IsEmpty = ([string]::IsNullOrEmpty($Name))
                } `
                -Source "Remove-InvalidFileNameChars"
            
            return "Untitled"
        }
        
        # Use regex to remove all invalid characters at once
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        $invalidPattern = "[{0}]" -f [regex]::Escape(($invalidChars -join ''))
        
        $sanitized = $Name -replace $invalidPattern, ''
        
        # Additional cleanup for common problematic characters
        $sanitized = $sanitized -replace ':', ' -'
        $sanitized = $sanitized -replace '\*', ''
        $sanitized = $sanitized -replace '\?', ''
        $sanitized = $sanitized -replace '"', "'"
        $sanitized = $sanitized -replace '<', ''
        $sanitized = $sanitized -replace '>', ''
        $sanitized = $sanitized -replace '\|', ''
        $sanitized = $sanitized -replace '/', '-'
        $sanitized = $sanitized -replace '\\', '-'
        
        # Remove extra spaces
        $sanitized = $sanitized -replace '\s+', ' '
        $sanitized = $sanitized.Trim()
        
        # Ensure we return something valid
        if ([string]::IsNullOrWhiteSpace($sanitized)) {
            Write-LogMessage "Sanitization resulted in empty string, using 'Untitled'" -Level Warning -Category Processing -Source "Remove-InvalidFileNameChars"
            return "Untitled"
        }
        
        return $sanitized
    }
    catch {
        Write-ErrorLog -Message "Error removing invalid filename characters" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                OriginalName = $Name
                NameLength = $Name.Length
            } `
            -Source "Remove-InvalidFileNameChars"
        
        # Return safe fallback
        return "Untitled"
    }
}

function Get-EpisodeNumber {
    <#
    .SYNOPSIS
        Extracts episode number from filename
    
    .PARAMETER FileName
        Filename to parse
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )
    
    try {
        # Try various patterns
        $patterns = @(
            '(?:S\d+E|E|EP|Episode)(\d{1,4})',  # S01E05, E05, EP05
            '\s-\s(\d{1,4})\s',                  # - 05 -
            '\s(\d{1,4})\s',                     # space 05 space
            '\[(\d{1,4})\]',                     # [05]
            '_(\d{1,4})_',                       # _05_
            '^(\d{1,4})\s',                      # starts with number
            '\s(\d{1,4})$',                      # ends with number
            '(?:^|\D)(\d{1,4})(?:\D|$)'         # any number surrounded by non-digits
        )
        
        foreach ($pattern in $patterns) {
            if ($FileName -match $pattern) {
                $epNum = [int]$Matches[1]
                Write-Verbose "Extracted episode number: $epNum from pattern: $pattern"
                return $epNum
            }
        }
        
        Write-Verbose "No episode number found in: $FileName"
        return -1
    }
    catch {
        Write-ErrorLog -Message "Error extracting episode number from filename" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FileName = $FileName
                PatternsAttempted = $patterns.Count
            } `
            -Source "Get-EpisodeNumber"
        
        return -1
    }
}

function Get-SeasonNumber {
    <#
    .SYNOPSIS
        Extracts season number from filename or folder
    
    .PARAMETER Name
        Name to parse
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    try {
        # Try patterns
        $patterns = @(
            'Season\s*0*(\d+)',
            'S0*(\d+)E',
            '\bS0*(\d+)\b'
        )
        
        foreach ($pattern in $patterns) {
            if ($Name -match $pattern) {
                $seasonNum = [int]$Matches[1]
                Write-Verbose "Extracted season number: $seasonNum"
                return $seasonNum
            }
        }
        
        return 1  # Default to season 1
    }
    catch {
        Write-ErrorLog -Message "Error extracting season number" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                Name = $Name
                PatternsAttempted = $patterns.Count
            } `
            -Source "Get-SeasonNumber"
        
        return 1  # Default to season 1
    }
}

function Get-QualityTag {
    <#
    .SYNOPSIS
        Extracts quality tag from filename
    
    .PARAMETER FileName
        Filename to parse
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )
    
    try {
        $qualityPatterns = @{
            '2160p|4K|UHD' = '2160p'
            '1080p|FHD' = '1080p'
            '720p|HD' = '720p'
            '480p|SD' = '480p'
        }
        
        foreach ($pattern in $qualityPatterns.Keys) {
            if ($FileName -match $pattern) {
                return $qualityPatterns[$pattern]
            }
        }
        
        return ''
    }
    catch {
        Write-ErrorLog -Message "Error extracting quality tag from filename" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FileName = $FileName
            } `
            -Source "Get-QualityTag"
        
        return ''
    }
}

function Get-ReleaseGroup {
    <#
    .SYNOPSIS
        Extracts release group from filename
    
    .PARAMETER FileName
        Filename to parse
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )
    
    try {
        # Look for bracketed group at start or end
        if ($FileName -match '^\[([^\]]+)\]') {
            return $Matches[1]
        }
        
        if ($FileName -match '\[([^\]]+)\]$') {
            return $Matches[1]
        }
        
        return ''
    }
    catch {
        Write-ErrorLog -Message "Error extracting release group from filename" `
            -ErrorRecord $_ `
            -Category Processing `
            -Context @{
                FileName = $FileName
            } `
            -Source "Get-ReleaseGroup"
        
        return ''
    }
}