<#
.SYNOPSIS
    Main setup script for RightClick2Gist application.

.DESCRIPTION
    This script installs and configures RightClick2Gist:
    1. Verifies administrator privileges
    2. Prompts for GitHub OAuth App client_id
    3. Performs OAuth Device Flow authentication
    4. Adds right-click context menu entry
    5. Verifies installation

.EXAMPLE
    .\Install-RightClick2Gist.ps1

.EXAMPLE
    .\Install-RightClick2Gist.ps1 -Verbose

.NOTES
    Requires Administrator privileges to modify Windows Registry.
    User must register a GitHub OAuth App before running this script.
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param()

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import required modules
Import-Module (Join-Path $scriptPath "Utilities.ps1") -Force
Import-Module (Join-Path $scriptPath "Auth-GitHub.ps1") -Force
Import-Module (Join-Path $scriptPath "Config-Registry.ps1") -Force

<#
.SYNOPSIS
    Main installation function.

.DESCRIPTION
    Orchestrates the complete installation process for RightClick2Gist.
#>
function Install-RightClick2Gist {
    [CmdletBinding()]
    param()
    
    Clear-Host
    
    Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              RightClick2Gist Setup Wizard                     ║
║              Version $(Get-RightClick2GistVersion)                                      ║
║                                                               ║
║  Upload files as GitHub Gists via Windows Explorer           ║
║  right-click context menu                                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
    
    Write-LogEntry -Message "Starting RightClick2Gist installation"
    
    try {
        # Step 1: Verify Administrator
        Write-Host "Step 1/5: Verifying administrator privileges..." -ForegroundColor Yellow
        
        if (-not (Test-Administrator)) {
            throw "This script must be run as Administrator. Please right-click and select 'Run as Administrator'."
        }
        
        Write-Host "✓ Running with administrator privileges" -ForegroundColor Green
        
        # Step 2: Check if already installed
        Write-Host "`nStep 2/5: Checking existing installation..." -ForegroundColor Yellow
        
        $isInstalled = Test-RightClick2GistSetup
        
        if ($isInstalled) {
            Write-Host "⚠ RightClick2Gist is already installed" -ForegroundColor Yellow
            
            $reinstall = Read-Host "Do you want to reinstall? (Y/N)"
            
            if ($reinstall -ne "Y" -and $reinstall -ne "y") {
                Write-Host "`nInstallation cancelled." -ForegroundColor Yellow
                return
            }
            
            Write-Host "Proceeding with reinstallation..." -ForegroundColor Yellow
        }
        else {
            Write-Host "✓ No existing installation found" -ForegroundColor Green
        }
        
        # Step 3: Get GitHub OAuth App client_id
        Write-Host "`nStep 3/5: GitHub OAuth App Configuration" -ForegroundColor Yellow
        Write-Host @"

To use RightClick2Gist, you need to register a GitHub OAuth App:

1. Go to: https://github.com/settings/developers
2. Click "New OAuth App" or "Register a new application"
3. Fill in:
   - Application name: RightClick2Gist (or any name you prefer)
   - Homepage URL: https://github.com/lmichaelwar/RightClick2Gist
   - Authorization callback URL: https://github.com (not used for Device Flow)
4. Click "Register application"
5. Copy the "Client ID" (looks like: Iv1.abc123def456...)

Note: You do NOT need the Client Secret for OAuth Device Flow.

"@ -ForegroundColor White
        
        # Try to get existing client_id
        $configFile = Get-ConfigFile
        $existingClientId = $null
        
        if (Test-Path $configFile) {
            try {
                $config = Get-Content $configFile -Raw | ConvertFrom-Json
                $existingClientId = $config.client_id
            }
            catch {
                Write-Verbose "Could not read existing client_id: $_"
            }
        }
        
        if ($existingClientId) {
            Write-Host "Existing Client ID found: $existingClientId" -ForegroundColor Gray
            $useExisting = Read-Host "Use existing Client ID? (Y/N)"
            
            if ($useExisting -eq "Y" -or $useExisting -eq "y") {
                $clientId = $existingClientId
            }
            else {
                $clientId = Read-Host "Enter your GitHub OAuth App Client ID"
            }
        }
        else {
            $clientId = Read-Host "Enter your GitHub OAuth App Client ID"
        }
        
        # Validate client_id format
        if ([string]::IsNullOrWhiteSpace($clientId)) {
            throw "Client ID cannot be empty"
        }
        
        # GitHub OAuth App client IDs typically start with "Iv1." or "Iv23."
        if ($clientId -notmatch '^Iv[0-9]+\.') {
            Write-Warning "Client ID format is unusual. GitHub OAuth App client IDs typically start with 'Iv1.' or 'Iv23.'"
            Write-Warning "Proceeding anyway, but authentication may fail if the Client ID is incorrect."
        }
        
        Write-Host "✓ Client ID accepted: $clientId" -ForegroundColor Green
        
        # Step 4: Perform OAuth authentication
        Write-Host "`nStep 4/5: GitHub OAuth Authentication" -ForegroundColor Yellow
        
        $authSuccess = Start-GitHubDeviceFlow -ClientId $clientId
        
        if (-not $authSuccess) {
            throw "Authentication failed. Please try again."
        }
        
        # Verify token was saved
        if (-not (Test-RightClick2GistSetup)) {
            throw "Authentication appeared to succeed, but token was not saved properly."
        }
        
        # Step 5: Configure Registry
        Write-Host "`nStep 5/5: Configuring Windows Registry" -ForegroundColor Yellow
        
        $uploadScriptPath = Join-Path $scriptPath "Upload-Gist.ps1"
        
        if (-not (Test-Path $uploadScriptPath)) {
            throw "Upload-Gist.ps1 not found at: $uploadScriptPath"
        }
        
        $registrySuccess = Add-ContextMenuEntry -UploadScriptPath $uploadScriptPath
        
        if (-not $registrySuccess) {
            throw "Failed to configure registry entries"
        }
        
        # Installation complete
        Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              ✓ Installation Complete!                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green
        
        Write-Host "RightClick2Gist has been installed successfully!" -ForegroundColor Green
        Write-Host "`nHow to use:" -ForegroundColor Cyan
        Write-Host "1. Right-click any file in Windows Explorer" -ForegroundColor White
        Write-Host "2. Select 'Upload as GitHub Gist' from the context menu" -ForegroundColor White
        Write-Host "3. The file will be uploaded and the Gist URL will be copied to your clipboard" -ForegroundColor White
        
        Write-Host "`nConfiguration files location:" -ForegroundColor Cyan
        Write-Host "  $(Get-ConfigDirectory)" -ForegroundColor Gray
        
        Write-Host "`nLog file location:" -ForegroundColor Cyan
        Write-Host "  $(Get-LogFile)" -ForegroundColor Gray
        
        Write-Host "`nTo uninstall, run:" -ForegroundColor Cyan
        Write-Host "  Remove-RightClick2GistInstallation" -ForegroundColor White
        Write-Host "  (from PowerShell with Administrator privileges)" -ForegroundColor Gray
        
        Write-LogEntry -Message "Installation completed successfully"
        
    }
    catch {
        Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                                                               ║" -ForegroundColor Red
        Write-Host "║              ✗ Installation Failed                            ║" -ForegroundColor Red
        Write-Host "║                                                               ║" -ForegroundColor Red
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        
        Show-ErrorMessage -Message "Installation failed" -Exception $_
        
        Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
        Write-Host "- Ensure you're running PowerShell as Administrator" -ForegroundColor White
        Write-Host "- Check that you have internet connectivity to GitHub" -ForegroundColor White
        Write-Host "- Verify your GitHub OAuth App Client ID is correct" -ForegroundColor White
        Write-Host "- Check the log file for details: $(Get-LogFile)" -ForegroundColor White
        
        exit 1
    }
}

# Run installation
Install-RightClick2Gist
