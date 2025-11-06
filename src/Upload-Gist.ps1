<#
.SYNOPSIS
    Uploads a file to GitHub Gist.

.DESCRIPTION
    This script reads a file and uploads it as a GitHub Gist using the
    GitHub API. It uses the stored access token from the configuration file.

.PARAMETER FilePath
    The path to the file to upload as a Gist.

.PARAMETER Public
    Whether to create a public or private Gist. Default is $true (public).

.PARAMETER Description
    Optional description for the Gist. If not provided, uses the filename.

.EXAMPLE
    Upload-Gist -FilePath "C:\Users\John\Documents\script.ps1"

.EXAMPLE
    Upload-Gist -FilePath "C:\temp\config.json" -Public $false

.EXAMPLE
    Upload-Gist -FilePath "C:\code\example.py" -Description "Python example script"

.NOTES
    Requires authentication to be completed first via Auth-GitHub.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FilePath,
    
    [Parameter(Mandatory = $false)]
    [bool]$Public = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$Description = ""
)

# Import utilities module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptPath "Utilities.ps1") -Force

# GitHub Gist API endpoint
$Script:GistApiUrl = "https://api.github.com/gists"

<#
.SYNOPSIS
    Main function to upload a file as a Gist.

.DESCRIPTION
    Orchestrates the Gist upload process:
    1. Validates file exists
    2. Reads access token from config
    3. Reads file content
    4. Creates Gist via API
    5. Returns Gist URL

.PARAMETER FilePath
    Path to the file to upload.

.PARAMETER Public
    Whether to create a public or private Gist.

.PARAMETER Description
    Optional description for the Gist.
#>
function Invoke-GistUpload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [bool]$Public = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )
    
    try {
        Write-Verbose "Starting Gist upload process for: $FilePath"
        Write-LogEntry -Message "Starting Gist upload: $FilePath"
        
        # Step 1: Validate file exists
        if (-not (Test-Path $FilePath)) {
            throw "File not found: $FilePath"
        }
        
        $fileInfo = Get-Item $FilePath -ErrorAction Stop
        
        if ($fileInfo.PSIsContainer) {
            throw "Cannot upload directories. Please select a file."
        }
        
        Write-Verbose "File validated: $($fileInfo.Name) ($($fileInfo.Length) bytes)"
        
        # Step 2: Get access token
        $accessToken = Get-AccessToken
        
        if (-not $accessToken) {
            throw "Authentication required. Please run Install-RightClick2Gist.ps1 first."
        }
        
        # Step 3: Read file content
        $fileName = $fileInfo.Name
        $fileContent = Get-FileContent -FilePath $FilePath
        
        # Step 4: Set description
        if ([string]::IsNullOrWhiteSpace($Description)) {
            $Description = $fileName
        }
        
        # Step 5: Create Gist
        Write-Host "`n📤 Uploading '$fileName' to GitHub Gist..." -ForegroundColor Cyan
        
        $gistUrl = New-Gist `
            -AccessToken $accessToken `
            -FileName $fileName `
            -FileContent $fileContent `
            -Description $Description `
            -Public $Public
        
        if ($gistUrl) {
            Write-Host "✓ Gist created successfully!" -ForegroundColor Green
            Write-Host "`nGist URL: " -NoNewline -ForegroundColor White
            Write-Host $gistUrl -ForegroundColor Cyan
            
            # Try to copy to clipboard
            $copied = Copy-ToClipboard -Text $gistUrl
            
            if ($copied) {
                Write-Host "✓ URL copied to clipboard" -ForegroundColor Green
            }
            
            Write-LogEntry -Message "Gist created successfully: $gistUrl"
            
            # Show success message box on Windows
            if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) {
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                    [System.Windows.Forms.MessageBox]::Show(
                        "Gist URL: $gistUrl`n`nURL has been copied to clipboard.",
                        "RightClick2Gist - Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    ) | Out-Null
                }
                catch {
                    Write-Verbose "Could not show message box: $_"
                }
            }
            
            return $gistUrl
        }
        else {
            throw "Failed to create Gist (no URL returned)"
        }
    }
    catch {
        Show-ErrorMessage -Message "Failed to upload Gist" -Exception $_
        
        # Show error message box on Windows
        if ($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows) {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                [System.Windows.Forms.MessageBox]::Show(
                    "Error: $($_.Exception.Message)`n`nPlease check the log file for details.",
                    "RightClick2Gist - Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
            catch {
                Write-Verbose "Could not show error message box: $_"
            }
        }
        
        throw
    }
}

<#
.SYNOPSIS
    Retrieves the access token from the configuration file.

.DESCRIPTION
    Reads and returns the stored GitHub access token from config.json.

.EXAMPLE
    Get-AccessToken
#>
function Get-AccessToken {
    [CmdletBinding()]
    param()
    
    try {
        $configFile = Get-ConfigFile
        
        if (-not (Test-Path $configFile)) {
            Write-Verbose "Config file not found: $configFile"
            return $null
        }
        
        $config = Get-Content $configFile -Raw -ErrorAction Stop | ConvertFrom-Json
        
        if (-not $config.access_token) {
            Write-Verbose "Access token not found in config"
            return $null
        }
        
        Write-Verbose "Access token retrieved from config"
        return $config.access_token
    }
    catch {
        Write-Verbose "Error reading access token: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Reads the content of a file with proper encoding.

.DESCRIPTION
    Reads file content and handles special characters and encoding (UTF-8).

.PARAMETER FilePath
    Path to the file to read.

.EXAMPLE
    Get-FileContent -FilePath "C:\temp\file.txt"
#>
function Get-FileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        # Read file with UTF-8 encoding to handle special characters
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
        
        # If content is null or empty, return empty string
        if ($null -eq $content) {
            $content = ""
        }
        
        Write-Verbose "File content read: $($content.Length) characters"
        return $content
    }
    catch {
        Write-Verbose "Error reading file content: $_"
        throw "Failed to read file: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Creates a new Gist via GitHub API.

.DESCRIPTION
    Makes a POST request to the GitHub Gist API to create a new Gist.

.PARAMETER AccessToken
    The GitHub access token.

.PARAMETER FileName
    The name of the file in the Gist.

.PARAMETER FileContent
    The content of the file.

.PARAMETER Description
    Description of the Gist.

.PARAMETER Public
    Whether the Gist should be public or private.

.EXAMPLE
    New-Gist -AccessToken "token" -FileName "script.ps1" -FileContent "code" -Description "My script"
#>
function New-Gist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        
        [Parameter(Mandatory = $true)]
        [string]$FileContent,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $true)]
        [bool]$Public
    )
    
    try {
        # Build Gist request body
        $gistBody = @{
            description = $Description
            public = $Public
            files = @{
                $FileName = @{
                    content = $FileContent
                }
            }
        }
        
        $bodyJson = $gistBody | ConvertTo-Json -Depth 10
        Write-Verbose "Gist request body prepared (${Description})"
        
        # Prepare headers
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Accept" = "application/vnd.github+json"
            "Content-Type" = "application/json"
        }
        
        # Make API request
        Write-Verbose "Sending POST request to: $Script:GistApiUrl"
        
        $response = Invoke-RestMethod `
            -Uri $Script:GistApiUrl `
            -Method Post `
            -Headers $headers `
            -Body $bodyJson `
            -ErrorAction Stop
        
        Write-Verbose "Gist created with ID: $($response.id)"
        
        return $response.html_url
    }
    catch {
        Write-Verbose "Error creating Gist: $_"
        
        # Handle specific API errors
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            switch ($statusCode) {
                401 {
                    throw "Authentication failed. Your access token may be invalid or expired. Please re-run Install-RightClick2Gist.ps1"
                }
                403 {
                    throw "Access forbidden. You may have exceeded the GitHub API rate limit or don't have permission to create Gists."
                }
                404 {
                    throw "GitHub API endpoint not found. Please check your internet connection."
                }
                422 {
                    throw "Invalid request. The file content may contain invalid data."
                }
                default {
                    throw "GitHub API error (HTTP $statusCode): $($_.Exception.Message)"
                }
            }
        }
        
        throw
    }
}

# Execute main function
try {
    Invoke-GistUpload -FilePath $FilePath -Public $Public -Description $Description
}
catch {
    # Error already handled in Invoke-GistUpload
    exit 1
}
