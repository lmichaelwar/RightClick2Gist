<#
.SYNOPSIS
    Windows Registry configuration module for RightClick2Gist.

.DESCRIPTION
    This module manages Windows Registry entries to add "Upload as GitHub Gist"
    to the right-click context menu for all file types in Windows Explorer.

.NOTES
    Requires Administrator privileges to modify HKEY_CLASSES_ROOT.
#>

# Import utilities module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptPath "Utilities.ps1") -Force

# Registry paths
$Script:RegistryPath = "Registry::HKEY_CLASSES_ROOT\*\shell\RightClick2Gist"
$Script:RegistryCommandPath = "Registry::HKEY_CLASSES_ROOT\*\shell\RightClick2Gist\command"

<#
.SYNOPSIS
    Adds the RightClick2Gist option to the Windows Explorer context menu.

.DESCRIPTION
    Creates registry entries in HKEY_CLASSES_ROOT\*\shell\ to add a
    "Upload as GitHub Gist" option to the right-click menu for all file types.

.PARAMETER UploadScriptPath
    The full path to the Upload-Gist.ps1 script.

.EXAMPLE
    Add-ContextMenuEntry -UploadScriptPath "C:\Path\To\Upload-Gist.ps1"

.NOTES
    Requires Administrator privileges.
#>
function Add-ContextMenuEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UploadScriptPath
    )
    
    # Verify script is running with admin privileges
    if (-not (Test-Administrator)) {
        throw "Administrator privileges required to modify registry. Please run as Administrator."
    }
    
    Write-Host "`n⚙️ Adding right-click context menu entry..." -ForegroundColor Cyan
    Write-LogEntry -Message "Adding context menu registry entry"
    
    try {
        # Validate upload script exists
        if (-not (Test-Path $UploadScriptPath)) {
            throw "Upload script not found: $UploadScriptPath"
        }
        
        Write-Verbose "Creating registry key: $Script:RegistryPath"
        
        # Create main registry key
        if (-not (Test-Path $Script:RegistryPath)) {
            New-Item -Path $Script:RegistryPath -Force -ErrorAction Stop | Out-Null
        }
        
        # Set the menu text
        Set-ItemProperty -Path $Script:RegistryPath `
            -Name "(Default)" `
            -Value "Upload as GitHub Gist" `
            -ErrorAction Stop
        
        # Set the icon (optional - using PowerShell icon)
        $powershellPath = (Get-Command powershell.exe).Source
        Set-ItemProperty -Path $Script:RegistryPath `
            -Name "Icon" `
            -Value "`"$powershellPath`"" `
            -ErrorAction Stop
        
        Write-Verbose "Creating command registry key: $Script:RegistryCommandPath"
        
        # Create command subkey
        if (-not (Test-Path $Script:RegistryCommandPath)) {
            New-Item -Path $Script:RegistryCommandPath -Force -ErrorAction Stop | Out-Null
        }
        
        # Build the command string
        # Use -WindowStyle Hidden to run without showing PowerShell window
        # Use -ExecutionPolicy Bypass to ensure script runs
        $command = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$UploadScriptPath`" -FilePath `"%1`""
        
        Write-Verbose "Setting command: $command"
        
        # Set the command to execute
        Set-ItemProperty -Path $Script:RegistryCommandPath `
            -Name "(Default)" `
            -Value $command `
            -ErrorAction Stop
        
        Write-Host "✓ Context menu entry added successfully" -ForegroundColor Green
        Write-Host "  Menu text: 'Upload as GitHub Gist'" -ForegroundColor Gray
        Write-LogEntry -Message "Context menu entry added successfully"
        
        return $true
    }
    catch {
        Show-ErrorMessage -Message "Failed to add context menu entry" -Exception $_
        return $false
    }
}

<#
.SYNOPSIS
    Removes the RightClick2Gist option from the Windows Explorer context menu.

.DESCRIPTION
    Deletes the registry entries created by Add-ContextMenuEntry.

.EXAMPLE
    Remove-ContextMenuEntry

.NOTES
    Requires Administrator privileges.
#>
function Remove-ContextMenuEntry {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    # Verify script is running with admin privileges
    if (-not (Test-Administrator)) {
        throw "Administrator privileges required to modify registry. Please run as Administrator."
    }
    
    Write-Host "`n⚙️ Removing right-click context menu entry..." -ForegroundColor Cyan
    Write-LogEntry -Message "Removing context menu registry entry"
    
    try {
        if (Test-Path $Script:RegistryPath) {
            if ($PSCmdlet.ShouldProcess($Script:RegistryPath, "Remove registry key")) {
                Remove-Item -Path $Script:RegistryPath -Recurse -Force -ErrorAction Stop
                Write-Host "✓ Context menu entry removed successfully" -ForegroundColor Green
                Write-LogEntry -Message "Context menu entry removed successfully"
            }
        }
        else {
            Write-Host "✓ No context menu entry found (already removed)" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Show-ErrorMessage -Message "Failed to remove context menu entry" -Exception $_
        return $false
    }
}

<#
.SYNOPSIS
    Tests if the context menu entry exists.

.DESCRIPTION
    Checks if the RightClick2Gist registry entries are present.

.EXAMPLE
    Test-ContextMenuEntry
    Returns: $true if entry exists, $false otherwise
#>
function Test-ContextMenuEntry {
    [CmdletBinding()]
    param()
    
    try {
        if (Test-Path $Script:RegistryPath) {
            Write-Verbose "Context menu entry exists"
            return $true
        }
        else {
            Write-Verbose "Context menu entry does not exist"
            return $false
        }
    }
    catch {
        Write-Verbose "Error checking context menu entry: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Tests if the current user has Administrator privileges.

.DESCRIPTION
    Checks if the PowerShell session is running with elevated privileges.

.EXAMPLE
    Test-Administrator
    Returns: $true if running as admin, $false otherwise
#>
function Test-Administrator {
    [CmdletBinding()]
    param()
    
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
        
        return $principal.IsInRole($adminRole)
    }
    catch {
        Write-Verbose "Error checking administrator status: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Updates the context menu entry with a new script path.

.DESCRIPTION
    Updates the registry command path if the Upload-Gist.ps1 script
    has been moved to a new location.

.PARAMETER UploadScriptPath
    The new full path to the Upload-Gist.ps1 script.

.EXAMPLE
    Update-ContextMenuEntry -UploadScriptPath "D:\Scripts\Upload-Gist.ps1"

.NOTES
    Requires Administrator privileges.
#>
function Update-ContextMenuEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UploadScriptPath
    )
    
    Write-Verbose "Updating context menu entry with new script path"
    
    # Simply remove and re-add the entry
    Remove-ContextMenuEntry -Confirm:$false | Out-Null
    return Add-ContextMenuEntry -UploadScriptPath $UploadScriptPath
}

<#
.SYNOPSIS
    Gets information about the current context menu configuration.

.DESCRIPTION
    Returns details about the registry entries including the command path.

.EXAMPLE
    Get-ContextMenuInfo
#>
function Get-ContextMenuInfo {
    [CmdletBinding()]
    param()
    
    if (-not (Test-ContextMenuEntry)) {
        Write-Host "Context menu entry is not installed" -ForegroundColor Yellow
        return $null
    }
    
    try {
        $menuText = (Get-ItemProperty -Path $Script:RegistryPath -Name "(Default)")."(Default)"
        $icon = (Get-ItemProperty -Path $Script:RegistryPath -Name "Icon" -ErrorAction SilentlyContinue).Icon
        $command = (Get-ItemProperty -Path $Script:RegistryCommandPath -Name "(Default)")."(Default)"
        
        $info = [PSCustomObject]@{
            MenuText = $menuText
            Icon = $icon
            Command = $command
            RegistryPath = $Script:RegistryPath
            CommandPath = $Script:RegistryCommandPath
        }
        
        return $info
    }
    catch {
        Write-Verbose "Error getting context menu info: $_"
        return $null
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Add-ContextMenuEntry',
    'Remove-ContextMenuEntry',
    'Test-ContextMenuEntry',
    'Test-Administrator',
    'Update-ContextMenuEntry',
    'Get-ContextMenuInfo'
)
