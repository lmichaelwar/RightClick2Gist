# RightClick2Gist

**Upload files to GitHub Gists with a single right-click!**

RightClick2Gist is a Windows PowerShell application that adds "Upload as GitHub Gist" to your Windows Explorer context menu. Simply right-click any file, select the option, and instantly create a GitHub Gist with the URL automatically copied to your clipboard.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)

## ✨ Features

- 🖱️ **One-Click Upload**: Right-click any file in Windows Explorer to upload it as a Gist
- 🔐 **Secure OAuth**: Uses GitHub OAuth Device Flow (no personal access tokens needed)
- 📋 **Auto-Copy**: Gist URL automatically copied to clipboard
- 📝 **All File Types**: Works with any file type
- 🪟 **Windows Integration**: Native Windows Explorer context menu integration
- 🔧 **Easy Setup**: Simple installation wizard
- 📊 **Logging**: Activity logs for troubleshooting

## 📋 Requirements

- Windows 10 or later
- PowerShell 5.1 or PowerShell 7+
- Administrator privileges (for installation only)
- GitHub account
- GitHub OAuth App (instructions below)

## 🚀 Installation

### Step 1: Register a GitHub OAuth App

Before installing RightClick2Gist, you need to create a GitHub OAuth App:

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click **"New OAuth App"** or **"Register a new application"**
3. Fill in the application details:
   - **Application name**: `RightClick2Gist` (or any name you prefer)
   - **Homepage URL**: `https://github.com/lmichaelwar/RightClick2Gist`
   - **Authorization callback URL**: `https://github.com` (not used for Device Flow, but required)
4. Click **"Register application"**
5. **Copy the Client ID** (looks like: `Iv1.abc123def456...`)
   - ⚠️ **Note**: You do NOT need the Client Secret for OAuth Device Flow

### Step 2: Clone or Download This Repository

```powershell
# Clone the repository
git clone https://github.com/lmichaelwar/RightClick2Gist.git
cd RightClick2Gist
```

Or download and extract the ZIP file from GitHub.

### Step 3: Run the Installation Script

1. Open PowerShell **as Administrator** (right-click PowerShell → "Run as Administrator")
2. Navigate to the repository directory:
   ```powershell
   cd C:\path\to\RightClick2Gist
   ```
3. Run the installation script:
   ```powershell
   .\src\Install-RightClick2Gist.ps1
   ```
4. Follow the setup wizard:
   - Enter your GitHub OAuth App **Client ID**
   - Open the provided URL in your browser
   - Enter the displayed code to authorize the app
   - Wait for authentication to complete

The installer will:
- ✅ Verify administrator privileges
- ✅ Authenticate with GitHub using OAuth Device Flow
- ✅ Store your access token securely
- ✅ Add the context menu entry to Windows Registry

## 📖 Usage

### Upload a File as a Gist

1. **Right-click** any file in Windows Explorer
2. Select **"Upload as GitHub Gist"** from the context menu
3. Wait a moment for the upload to complete
4. A success message will appear, and the Gist URL will be copied to your clipboard
5. Paste the URL anywhere to share your Gist!

### Manual Upload (Optional)

You can also upload files manually from PowerShell:

```powershell
# Upload a public gist
.\src\Upload-Gist.ps1 -FilePath "C:\path\to\file.txt"

# Upload a private gist
.\src\Upload-Gist.ps1 -FilePath "C:\path\to\file.txt" -Public $false

# Upload with custom description
.\src\Upload-Gist.ps1 -FilePath "C:\path\to\file.txt" -Description "My custom description"
```

## 🔧 Configuration

### Configuration Files

RightClick2Gist stores configuration in your user profile:

- **Config Directory**: `%USERPROFILE%\.rightclick2gist\`
- **Config File**: `%USERPROFILE%\.rightclick2gist\config.json`
- **Log File**: `%USERPROFILE%\.rightclick2gist\rightclick2gist.log`

### Config File Structure

```json
{
  "client_id": "Iv1.abc123def456",
  "access_token": "gho_abc123...",
  "created_at": "2025-01-15 10:30:00",
  "version": "1.0.0"
}
```

⚠️ **Security Note**: Keep your `config.json` file secure! It contains your GitHub access token.

## 🛠️ Troubleshooting

### Installation Issues

**Problem**: "This script must be run as Administrator"
- **Solution**: Right-click PowerShell and select "Run as Administrator"

**Problem**: "Execution of scripts is disabled on this system"
- **Solution**: Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Problem**: Authentication timeout
- **Solution**: The device code expires after 15 minutes. Restart the installation and complete authorization more quickly.

### Upload Issues

**Problem**: "Authentication required. Please run Install-RightClick2Gist.ps1 first"
- **Solution**: Your access token may be missing or invalid. Re-run the installation script.

**Problem**: "Access forbidden. You may have exceeded the GitHub API rate limit"
- **Solution**: Wait an hour and try again. GitHub has rate limits for API usage.

**Problem**: Context menu option doesn't appear
- **Solution**: 
  1. Restart Windows Explorer (Task Manager → Windows Explorer → Restart)
  2. Verify installation with: `Test-RightClick2GistSetup` in PowerShell

### Viewing Logs

```powershell
# View the log file
Get-Content "$env:USERPROFILE\.rightclick2gist\rightclick2gist.log" -Tail 50
```

## 🗑️ Uninstallation

To completely remove RightClick2Gist:

1. Open PowerShell **as Administrator**
2. Load the utilities module:
   ```powershell
   Import-Module "C:\path\to\RightClick2Gist\src\Utilities.ps1"
   ```
3. Run the uninstall command:
   ```powershell
   Remove-RightClick2GistInstallation
   ```

This will:
- ✅ Remove registry entries (context menu)
- ✅ Delete configuration directory and files
- ✅ Clean up log files

## 🔐 Security & Privacy

- **OAuth Device Flow**: More secure than personal access tokens
- **Scoped Permissions**: Only requests `gist` scope (minimal permissions)
- **Local Storage**: Token stored locally in your user profile
- **No Telemetry**: No usage data collected
- **Open Source**: Full source code available for audit

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- GitHub for the Gist API and OAuth Device Flow
- PowerShell community for excellent documentation

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/lmichaelwar/RightClick2Gist/issues)
- **Discussions**: [GitHub Discussions](https://github.com/lmichaelwar/RightClick2Gist/discussions)

## 🗺️ Roadmap

- [ ] Support for uploading multiple files as a single Gist
- [ ] GUI configuration tool
- [ ] Gist update functionality
- [ ] Gist deletion from context menu
- [ ] Support for folder uploads
- [ ] Customizable context menu text
- [ ] Cross-platform support (macOS, Linux)

---

**Made with ❤️ for the GitHub community**
