<#
.SYNOPSIS
    GitHub OAuth Device Flow authentication module for RightClick2Gist.

.DESCRIPTION
    This module implements GitHub OAuth Device Flow authentication:
    1. Request device and user codes from GitHub
    2. Display user code and prompt user to authorize
    3. Poll for access token
    4. Store access token in config file

    OAuth Device Flow is used instead of personal access tokens for better security
    and user experience. This flow doesn't require client secrets.

.NOTES
    Requires internet connectivity to GitHub API endpoints.
    User must have a registered GitHub OAuth App with client_id.
#>

# Import utilities module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptPath "Utilities.ps1") -Force

# GitHub OAuth endpoints
$Script:DeviceCodeUrl = "https://github.com/login/device/code"
$Script:AccessTokenUrl = "https://github.com/login/oauth/access_token"
$Script:DeviceLoginUrl = "https://github.com/login/device"

<#
.SYNOPSIS
    Initiates GitHub OAuth Device Flow authentication.

.DESCRIPTION
    Performs the complete OAuth Device Flow process:
    - Requests device and user codes from GitHub
    - Displays authorization instructions to user
    - Polls GitHub for access token
    - Stores token in configuration file

.PARAMETER ClientId
    The GitHub OAuth App client ID. Users must register an OAuth app at
    https://github.com/settings/developers to obtain this.

.PARAMETER Scope
    The OAuth scope to request. Default is "gist" for gist creation permissions.

.EXAMPLE
    Start-GitHubDeviceFlow -ClientId "Iv1.1234567890abcdef"

.EXAMPLE
    Start-GitHubDeviceFlow -ClientId "Iv1.1234567890abcdef" -Scope "gist,repo"
#>
function Start-GitHubDeviceFlow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $false)]
        [string]$Scope = "gist"
    )
    
    Write-Host "`n🔐 Starting GitHub OAuth Device Flow authentication..." -ForegroundColor Cyan
    Write-LogEntry -Message "Starting OAuth Device Flow authentication"
    
    try {
        # Step 1: Request device and user codes
        Write-Verbose "Step 1: Requesting device code from GitHub"
        $deviceCodeResponse = Request-DeviceCode -ClientId $ClientId -Scope $Scope
        
        if (-not $deviceCodeResponse) {
            throw "Failed to obtain device code from GitHub"
        }
        
        # Step 2: Display user code and instructions
        Write-Host "`n" + ("=" * 60) -ForegroundColor Yellow
        Write-Host "  GITHUB AUTHENTICATION REQUIRED" -ForegroundColor Yellow
        Write-Host ("=" * 60) -ForegroundColor Yellow
        Write-Host "`nPlease follow these steps to authorize RightClick2Gist:" -ForegroundColor White
        Write-Host "`n1. Open your web browser and go to:" -ForegroundColor Cyan
        Write-Host "   $Script:DeviceLoginUrl" -ForegroundColor Green
        Write-Host "`n2. Enter this code when prompted:" -ForegroundColor Cyan
        Write-Host "   $($deviceCodeResponse.user_code)" -ForegroundColor Green -BackgroundColor Black
        Write-Host "`n3. Authorize the application" -ForegroundColor Cyan
        Write-Host "`n" + ("=" * 60) -ForegroundColor Yellow
        Write-Host "`nWaiting for authorization..." -ForegroundColor Yellow
        
        # Step 3: Poll for access token
        Write-Verbose "Step 3: Polling for access token"
        $accessToken = Wait-ForAccessToken `
            -ClientId $ClientId `
            -DeviceCode $deviceCodeResponse.device_code `
            -Interval $deviceCodeResponse.interval `
            -ExpiresIn $deviceCodeResponse.expires_in
        
        if (-not $accessToken) {
            throw "Failed to obtain access token"
        }
        
        # Step 4: Store token in config file
        Write-Verbose "Step 4: Storing access token in config"
        Save-AccessToken -AccessToken $accessToken -ClientId $ClientId
        
        Write-Host "`n✓ Authentication successful!" -ForegroundColor Green
        Write-Host "Access token has been stored securely in: $(Get-ConfigFile)" -ForegroundColor Gray
        Write-LogEntry -Message "OAuth authentication completed successfully"
        
        return $true
    }
    catch {
        Show-ErrorMessage -Message "Authentication failed" -Exception $_
        return $false
    }
}

<#
.SYNOPSIS
    Requests device and user codes from GitHub.

.DESCRIPTION
    Makes a POST request to GitHub's device code endpoint to initiate
    the OAuth Device Flow. Returns device_code, user_code, and polling parameters.

.PARAMETER ClientId
    The GitHub OAuth App client ID.

.PARAMETER Scope
    The OAuth scope to request.

.EXAMPLE
    Request-DeviceCode -ClientId "Iv1.abc123" -Scope "gist"
#>
function Request-DeviceCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [string]$Scope
    )
    
    try {
        $body = @{
            client_id = $ClientId
            scope = $Scope
        } | ConvertTo-Json
        
        $headers = @{
            "Accept" = "application/json"
            "Content-Type" = "application/json"
        }
        
        Write-Verbose "Requesting device code from: $Script:DeviceCodeUrl"
        $response = Invoke-RestMethod `
            -Uri $Script:DeviceCodeUrl `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop
        
        Write-Verbose "Device code obtained: $($response.device_code.Substring(0, 10))..."
        Write-Verbose "User code: $($response.user_code)"
        Write-Verbose "Polling interval: $($response.interval) seconds"
        Write-Verbose "Expires in: $($response.expires_in) seconds"
        
        return $response
    }
    catch {
        Write-Verbose "Error requesting device code: $_"
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Verbose "HTTP Status Code: $statusCode"
        }
        
        throw
    }
}

<#
.SYNOPSIS
    Polls GitHub for access token after user authorization.

.DESCRIPTION
    Continuously polls GitHub's access token endpoint until:
    - User authorizes (success)
    - Device code expires (failure)
    - Maximum timeout reached (failure)

.PARAMETER ClientId
    The GitHub OAuth App client ID.

.PARAMETER DeviceCode
    The device code obtained from Request-DeviceCode.

.PARAMETER Interval
    The polling interval in seconds (minimum 5 seconds per GitHub spec).

.PARAMETER ExpiresIn
    Time in seconds before the device code expires.

.EXAMPLE
    Wait-ForAccessToken -ClientId "Iv1.abc" -DeviceCode "xyz" -Interval 5 -ExpiresIn 900
#>
function Wait-ForAccessToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [string]$DeviceCode,
        
        [Parameter(Mandatory = $true)]
        [int]$Interval,
        
        [Parameter(Mandatory = $true)]
        [int]$ExpiresIn
    )
    
    # Ensure minimum 5-second interval per GitHub OAuth spec
    if ($Interval -lt 5) {
        $Interval = 5
        Write-Verbose "Adjusted polling interval to minimum 5 seconds"
    }
    
    # Calculate maximum timeout (15 minutes per OAuth spec)
    $maxTimeout = [Math]::Min($ExpiresIn, 900) # 900 seconds = 15 minutes
    $startTime = Get-Date
    $pollCount = 0
    
    Write-Verbose "Starting polling with $Interval second interval, max timeout: $maxTimeout seconds"
    
    while ($true) {
        $pollCount++
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        
        # Check if we've exceeded the timeout
        if ($elapsed -gt $maxTimeout) {
            Write-Host "`n❌ Timeout: Device code expired" -ForegroundColor Red
            Write-LogEntry -Message "OAuth polling timeout after $elapsed seconds" -Level "Error"
            throw "Authentication timeout - device code expired"
        }
        
        # Wait for the polling interval
        Start-Sleep -Seconds $Interval
        
        try {
            $body = @{
                client_id = $ClientId
                device_code = $DeviceCode
                grant_type = "urn:ietf:params:oauth:grant-type:device_code"
            } | ConvertTo-Json
            
            $headers = @{
                "Accept" = "application/json"
                "Content-Type" = "application/json"
            }
            
            Write-Verbose "Polling attempt #$pollCount at $([int]$elapsed) seconds elapsed"
            
            $response = Invoke-RestMethod `
                -Uri $Script:AccessTokenUrl `
                -Method Post `
                -Headers $headers `
                -Body $body `
                -ErrorAction Stop
            
            # Check response for errors
            if ($response.error) {
                switch ($response.error) {
                    "authorization_pending" {
                        Write-Verbose "Authorization pending, continuing to poll..."
                        # Show progress with elapsed time every 30 seconds
                        if ($pollCount % 6 -eq 0) {
                            Write-Host "`n  Still waiting... ($([int]$elapsed) seconds elapsed)" -ForegroundColor Yellow -NoNewline
                        } else {
                            Write-Host "." -NoNewline -ForegroundColor Yellow
                        }
                        continue
                    }
                    "slow_down" {
                        $Interval += 5
                        Write-Verbose "Rate limited - increasing interval to $Interval seconds"
                        Write-Host "`n  ⏱ Rate limited, slowing down polling..." -ForegroundColor Yellow -NoNewline
                        continue
                    }
                    "expired_token" {
                        Write-Host "`n❌ Device code has expired" -ForegroundColor Red
                        Write-LogEntry -Message "Device code expired" -Level "Error"
                        throw "Device code expired - please restart authentication"
                    }
                    "access_denied" {
                        Write-Host "`n❌ Access denied by user" -ForegroundColor Red
                        Write-LogEntry -Message "User denied authorization" -Level "Warning"
                        throw "Authorization was denied"
                    }
                    default {
                        Write-Verbose "Unexpected error: $($response.error)"
                        throw "Authentication error: $($response.error)"
                    }
                }
            }
            
            # Success - we have an access token
            if ($response.access_token) {
                Write-Host "" # New line after dots
                Write-Verbose "Access token received successfully"
                Write-LogEntry -Message "Access token obtained after $pollCount poll attempts"
                return $response.access_token
            }
        }
        catch {
            # Handle network errors differently from API errors
            if ($_.Exception.Message -notmatch "authorization_pending|slow_down") {
                Write-Verbose "Polling error: $_"
                
                # If we get a network error, wait and retry
                if ($_.Exception.Message -match "network|connection") {
                    Write-Host "⚠" -NoNewline -ForegroundColor Yellow
                    continue
                }
                
                throw
            }
        }
    }
}

<#
.SYNOPSIS
    Saves the access token to the configuration file.

.DESCRIPTION
    Stores the access token and client ID in the config.json file
    in the user's profile directory (~/.rightclick2gist/).

.PARAMETER AccessToken
    The GitHub access token to store.

.PARAMETER ClientId
    The GitHub OAuth App client ID.

.EXAMPLE
    Save-AccessToken -AccessToken "gho_abc123..." -ClientId "Iv1.xyz"
#>
function Save-AccessToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientId
    )
    
    try {
        $configDir = Get-ConfigDirectory
        $configFile = Get-ConfigFile
        
        # Ensure config directory exists
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created config directory: $configDir"
        }
        
        # Create or update config
        $config = @{
            client_id = $ClientId
            access_token = $AccessToken
            created_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            version = Get-RightClick2GistVersion
        }
        
        $configJson = $config | ConvertTo-Json -Depth 10
        Set-Content -Path $configFile -Value $configJson -Force -ErrorAction Stop
        
        Write-Verbose "Access token saved to: $configFile"
        Write-LogEntry -Message "Access token saved to config file"
    }
    catch {
        Write-Verbose "Error saving access token: $_"
        throw
    }
}

<#
.SYNOPSIS
    Validates if the stored access token is still valid.

.DESCRIPTION
    Checks if the access token exists and makes a test API call
    to verify it's still valid.

.EXAMPLE
    Test-AccessToken
    Returns: $true if valid, $false otherwise
#>
function Test-AccessToken {
    [CmdletBinding()]
    param()
    
    try {
        $configFile = Get-ConfigFile
        
        if (-not (Test-Path $configFile)) {
            Write-Verbose "Config file not found"
            return $false
        }
        
        $config = Get-Content $configFile -Raw -ErrorAction Stop | ConvertFrom-Json
        
        if (-not $config.access_token) {
            Write-Verbose "Access token not found in config"
            return $false
        }
        
        # Test token with a simple API call
        $headers = @{
            "Authorization" = "Bearer $($config.access_token)"
            "Accept" = "application/vnd.github+json"
        }
        
        $response = Invoke-RestMethod `
            -Uri "https://api.github.com/user" `
            -Method Get `
            -Headers $headers `
            -ErrorAction Stop
        
        Write-Verbose "Token is valid for user: $($response.login)"
        return $true
    }
    catch {
        Write-Verbose "Token validation failed: $_"
        return $false
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Start-GitHubDeviceFlow',
    'Test-AccessToken'
)
