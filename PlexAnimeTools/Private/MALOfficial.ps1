# =============================================================================
# Official MyAnimeList API Functions
# Requires MAL API Client ID (free from https://myanimelist.net/apiconfig)
# API Documentation: https://myanimelist.net/apiconfig/references/api/v2
# Save as: Private/PrivateMALOfficial.ps1
# =============================================================================

function Get-MALAccessToken {
    <#
    .SYNOPSIS
        Gets or refreshes MAL API access token using OAuth2 PKCE
    
    .PARAMETER ClientId
        MAL API Client ID
    
    .PARAMETER Force
        Force new authentication even if token exists
    #>
    
    [CmdletBinding()]
    param(
        [string]$ClientId,
        
        [switch]$Force
    )
    
    # Check for existing token
    $tokenPath = Join-Path $script:ModuleRoot 'Config\.mal_token.json'
    
    if (-not $Force -and (Test-Path $tokenPath)) {
        try {
            $tokenData = Get-Content $tokenPath -Raw | ConvertFrom-Json
            
            # Check if token is still valid (expires in 31 days typically)
            $expiryDate = [DateTime]$tokenData.ExpiryDate
            if ($expiryDate -gt (Get-Date).AddHours(1)) {
                Write-Verbose "Using cached MAL access token"
                return $tokenData.AccessToken
            }
        }
        catch {
            Write-Verbose "Failed to load cached token: $_"
        }
    }
    
    # Generate PKCE code verifier and challenge
    $codeVerifier = New-MALCodeVerifier
    $codeChallenge = Get-MALCodeChallenge -CodeVerifier $codeVerifier
    
    # Start OAuth flow
    $state = [System.Guid]::NewGuid().ToString()
    $authUrl = "https://myanimelist.net/v1/oauth2/authorize?response_type=code&client_id=$ClientId&state=$state&code_challenge=$codeChallenge&code_challenge_method=plain"
    
    Write-Host ""
    Write-Host "Opening MyAnimeList authentication page..." -ForegroundColor Cyan
    Write-Host "Please log in and authorize the application." -ForegroundColor Yellow
    Write-Host ""
    
    Start-Process $authUrl
    
    # Wait for callback (user needs to copy the URL)
    Write-Host "After authorizing, you will be redirected to localhost." -ForegroundColor Yellow
    Write-Host "Copy the ENTIRE URL from your browser and paste it here:" -ForegroundColor Yellow
    Write-Host ""
    $callbackUrl = Read-Host "Paste callback URL"
    
    # Extract authorization code
    if ($callbackUrl -match 'code=([^&]+)') {
        $authCode = $Matches[1]
    }
    else {
        throw "Could not extract authorization code from URL"
    }
    
    # Exchange code for access token
    $tokenUrl = "https://myanimelist.net/v1/oauth2/token"
    $body = @{
        client_id = $ClientId
        code = $authCode
        code_verifier = $codeVerifier
        grant_type = 'authorization_code'
    }
    
    try {
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded'
        
        # Save token
        $tokenData = @{
            AccessToken = $response.access_token
            RefreshToken = $response.refresh_token
            ExpiryDate = (Get-Date).AddSeconds($response.expires_in).ToString('o')
            ClientId = $ClientId
        }
        
        $tokenData | ConvertTo-Json | Out-File -FilePath $tokenPath -Force -Encoding UTF8
        
        Write-Host ""
        Write-Host "Successfully authenticated with MyAnimeList!" -ForegroundColor Green
        Write-Host ""
        
        return $response.access_token
    }
    catch {
        Write-Error "Failed to get access token: $_"
        return $null
    }
}

function New-MALCodeVerifier {
    <#
    .SYNOPSIS
        Generates PKCE code verifier
    #>
    
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    
    $base64 = [Convert]::ToBase64String($bytes)
    # URL-safe base64
    $codeVerifier = $base64.Replace('+', '-').Replace('/', '_').Replace('=', '')
    
    return $codeVerifier.Substring(0, [Math]::Min(128, $codeVerifier.Length))
}

function Get-MALCodeChallenge {
    <#
    .SYNOPSIS
        Generates PKCE code challenge
    #>
    
    param([string]$CodeVerifier)
    
    # For plain method, challenge = verifier
    return $CodeVerifier
}

function Search-MALOfficial {
    <#
    .SYNOPSIS
        Searches anime using official MAL API
    
    .PARAMETER Query
        Search query
    
    .PARAMETER ClientId
        MAL API Client ID
    
    .PARAMETER Limit
        Number of results (default: 10)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        
        [Parameter(Mandatory)]
        [string]$ClientId,
        
        [int]$Limit = 10
    )
    
    try {
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
        $url = "https://api.myanimelist.net/v2/anime?q=$encodedQuery&limit=$Limit&fields=id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_episodes,status,genres,media_type,studios"
        
        Write-LogMessage "Searching MAL Official API for: $Query" -Level Info
        
        $headers = @{
            'X-MAL-CLIENT-ID' = $ClientId
        }
        
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop
        
        if ($response.data) {
            Write-LogMessage "Found $($response.data.Count) result(s) from MAL Official" -Level Success
            return $response.data
        }
        
        Write-LogMessage "No results found" -Level Warning
        return $null
    }
    catch {
        Write-LogMessage "MAL Official search failed: $($_.Exception.Message)" -Level Error
        Write-ErrorLog "Search-MALOfficial failed for query: $Query" $_
        return $null
    }
}

function Get-MALAnimeDetails {
    <#
    .SYNOPSIS
        Gets detailed anime info from official MAL API
    
    .PARAMETER AnimeId
        MAL Anime ID
    
    .PARAMETER ClientId
        MAL API Client ID
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$AnimeId,
        
        [Parameter(Mandatory)]
        [string]$ClientId
    )
    
    try {
        $fields = "id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,created_at,updated_at,media_type,status,genres,my_list_status,num_episodes,start_season,broadcast,source,average_episode_duration,rating,pictures,background,related_anime,related_manga,recommendations,studios,statistics"
        $url = "https://api.myanimelist.net/v2/anime/${AnimeId}?fields=$fields"
        
        Write-LogMessage "Fetching anime details from MAL Official for ID: $AnimeId" -Level Info
        
        $headers = @{
            'X-MAL-CLIENT-ID' = $ClientId
        }
        
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop
        
        if ($response) {
            Write-LogMessage "Retrieved details successfully from MAL Official" -Level Success
            return $response
        }
        
        return $null
    }
    catch {
        Write-LogMessage "Failed to get MAL Official anime details: $($_.Exception.Message)" -Level Error
        Write-ErrorLog "Get-MALAnimeDetails failed for ID: $AnimeId" $_
        return $null
    }
}

function Get-MALClientId {
    <#
    .SYNOPSIS
        Gets MAL Client ID from config
    #>
    
    if ($script:DefaultConfig.MALClientId -and $script:DefaultConfig.MALClientId -ne "YOUR_MAL_CLIENT_ID_HERE") {
        return $script:DefaultConfig.MALClientId
    }
    
    return $null
}

function Test-MALOfficialAPI {
    <#
    .SYNOPSIS
        Tests if MAL Official API is configured and working
    #>
    
    [CmdletBinding()]
    param()
    
    $clientId = Get-MALClientId
    
    if (-not $clientId) {
        Write-Host "MAL Official API is not configured." -ForegroundColor Yellow
        Write-Host "To enable it:" -ForegroundColor Cyan
        Write-Host "  1. Go to: https://myanimelist.net/apiconfig" -ForegroundColor White
        Write-Host "  2. Create a new API client (free)" -ForegroundColor White
        Write-Host "  3. Add your Client ID to the config file" -ForegroundColor White
        Write-Host "  4. Set redirect URI to: http://localhost" -ForegroundColor White
        return $false
    }
    
    try {
        # Try a simple search
        $result = Search-MALOfficial -Query "Naruto" -ClientId $clientId -Limit 1
        
        if ($result) {
            Write-Host "MAL Official API is working!" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "MAL Official API returned no results." -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "MAL Official API test failed: $_" -ForegroundColor Red
        return $false
    }
}
