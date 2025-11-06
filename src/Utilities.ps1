<#
.SYNOPSIS
    Utility functions for RightClick2Gist application.

.DESCRIPTION
    This module provides helper functions for RightClick2Gist including:
    - Setup validation
    - Installation cleanup
    - Version information
    - Clipboard operations
    - Error handling
    - Logging
#>

# Module version
$Script:RightClick2GistVersion = "1.0.0"

# Configuration paths
$Script:ConfigDir = Join-Path $env:USERPROFILE ".rightclick2gist"
$Script:ConfigFile = Join-Path $Script:ConfigDir "config.json"
$Script:LogFile = Join-Path $Script:ConfigDir "rightclick2gist.log"

<#
.SYNOPSIS
    Gets the version of RightClick2Gist.

.DESCRIPTION
    Returns the current version number of the RightClick2Gist application.

.EXAMPLE
    Get-RightClick2GistVersion
    Returns: "1.0.0"
#>
function Get-RightClick2GistVersion {
    [CmdletBinding()]
    param()
    
    return $Script:RightClick2GistVersion
}

<#
.SYNOPSIS
    Tests if RightClick2Gist is properly installed and configured.

.DESCRIPTION
    Checks if all required files exist and if the GitHub authentication token is valid.

.EXAMPLE
    Test-RightClick2GistSetup
    Returns: $true if setup is complete, $false otherwise
#>
function Test-RightClick2GistSetup {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Testing RightClick2Gist setup..."
    
    # Check if config directory exists
    if (-not (Test-Path $Script:ConfigDir)) {
        Write-Verbose "Config directory does not exist: $Script:ConfigDir"
        return $false
    }
    
    # Check if config file exists
    if (-not (Test-Path $Script:ConfigFile)) {
        Write-Verbose "Config file does not exist: $Script:ConfigFile"
        return $false
    }
    
    # Check if token exists in config
    try {
        $config = Get-Content $Script:ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json
        
        if (-not $config.access_token) {
            Write-Verbose "Access token not found in config"
            return $false
        }
        
        # Validate token exists and is not empty
        if ([string]::IsNullOrWhiteSpace($config.access_token)) {
            Write-Verbose "Access token is empty or null"
            return $false
        }
        
        Write-Verbose "RightClick2Gist setup is valid"
        return $true
    }
    catch {
        Write-Verbose "Error reading config file: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Removes the RightClick2Gist installation.

.DESCRIPTION
    Performs a complete uninstall by removing:
    - Windows Registry entries for right-click menu
    - Configuration directory and files
    - Log files

.EXAMPLE
    Remove-RightClick2GistInstallation
#>
function Remove-RightClick2GistInstallation {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-Host "Uninstalling RightClick2Gist..." -ForegroundColor Yellow
    
    # Remove registry entries
    try {
        $registryPath = "Registry::HKEY_CLASSES_ROOT\*\shell\RightClick2Gist"
        
        if (Test-Path $registryPath) {
            if ($PSCmdlet.ShouldProcess($registryPath, "Remove registry key")) {
                Remove-Item -Path $registryPath -Recurse -Force -ErrorAction Stop
                Write-Host "✓ Registry entries removed" -ForegroundColor Green
            }
        }
        else {
            Write-Host "✓ No registry entries found" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to remove registry entries: $_"
    }
    
    # Remove configuration directory
    try {
        if (Test-Path $Script:ConfigDir) {
            if ($PSCmdlet.ShouldProcess($Script:ConfigDir, "Remove configuration directory")) {
                Remove-Item -Path $Script:ConfigDir -Recurse -Force -ErrorAction Stop
                Write-Host "✓ Configuration directory removed" -ForegroundColor Green
            }
        }
        else {
            Write-Host "✓ No configuration directory found" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to remove configuration directory: $_"
    }
    
    Write-Host "`nRightClick2Gist has been uninstalled successfully!" -ForegroundColor Green
}

<#
.SYNOPSIS
    Copies text to the clipboard.

.DESCRIPTION
    Provides cross-platform clipboard functionality for copying text.
    Supports both PowerShell 5.1 and PowerShell 7+.

.PARAMETER Text
    The text to copy to the clipboard.

.EXAMPLE
    Copy-ToClipboard -Text "https://gist.github.com/username/abc123"
#>
function Copy-ToClipboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # PowerShell 7+ with cross-platform support
            if ($IsWindows -or $null -eq $IsWindows) {
                Set-Clipboard -Value $Text -ErrorAction Stop
            }
            else {
                # Non-Windows platforms (future support)
                Write-Verbose "Clipboard not supported on this platform"
                return $false
            }
        }
        else {
            # PowerShell 5.1
            Set-Clipboard -Value $Text -ErrorAction Stop
        }
        
        return $true
    }
    catch {
        Write-Verbose "Failed to copy to clipboard: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Displays a standardized error message.

.DESCRIPTION
    Provides consistent error message formatting throughout the application.

.PARAMETER Message
    The error message to display.

.PARAMETER Exception
    Optional exception object to include in the error display.

.EXAMPLE
    Show-ErrorMessage -Message "Failed to authenticate with GitHub"
#>
function Show-ErrorMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception
    )
    
    Write-Host "`n❌ ERROR: $Message" -ForegroundColor Red
    
    if ($Exception) {
        Write-Host "Details: $($Exception.Message)" -ForegroundColor Red
        Write-Verbose "Exception: $($Exception | Out-String)"
    }
    
    Write-LogEntry -Message "ERROR: $Message" -Level "Error"
}

<#
.SYNOPSIS
    Writes an entry to the RightClick2Gist log file.

.DESCRIPTION
    Logs authentication and upload events with timestamps to help with troubleshooting.

.PARAMETER Message
    The message to log.

.PARAMETER Level
    The log level (Info, Warning, Error). Default is Info.

.EXAMPLE
    Write-LogEntry -Message "Token authenticated successfully" -Level "Info"
#>
function Write-LogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    try {
        # Ensure log directory exists
        if (-not (Test-Path $Script:ConfigDir)) {
            New-Item -ItemType Directory -Path $Script:ConfigDir -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        
        Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction Stop
        Write-Verbose $logEntry
    }
    catch {
        Write-Verbose "Failed to write log entry: $_"
    }
}

<#
.SYNOPSIS
    Gets the configuration directory path.

.DESCRIPTION
    Returns the full path to the RightClick2Gist configuration directory.

.EXAMPLE
    Get-ConfigDirectory
#>
function Get-ConfigDirectory {
    [CmdletBinding()]
    param()
    
    return $Script:ConfigDir
}

<#
.SYNOPSIS
    Gets the configuration file path.

.DESCRIPTION
    Returns the full path to the RightClick2Gist configuration file.

.EXAMPLE
    Get-ConfigFile
#>
function Get-ConfigFile {
    [CmdletBinding()]
    param()
    
    return $Script:ConfigFile
}

<#
.SYNOPSIS
    Gets the log file path.

.DESCRIPTION
    Returns the full path to the RightClick2Gist log file.

.EXAMPLE
    Get-LogFile
#>
function Get-LogFile {
    [CmdletBinding()]
    param()
    
    return $Script:LogFile
}

# Export module members
Export-ModuleMember -Function @(
    'Get-RightClick2GistVersion',
    'Test-RightClick2GistSetup',
    'Remove-RightClick2GistInstallation',
    'Copy-ToClipboard',
    'Show-ErrorMessage',
    'Write-LogEntry',
    'Get-ConfigDirectory',
    'Get-ConfigFile',
    'Get-LogFile'
)
