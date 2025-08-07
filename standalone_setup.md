# StrangeLoop Standalone Setup

This directory contains scripts that can be used as standalone installers for StrangeLoop development environments.

## Quick Start (Recommended)

### Option 1: Download and Run Single Script

1. Download the standalone launcher:
   ```powershell
   Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"
   ```

2. Run the setup:
   ```powershell
   .\setup_strangeloop.ps1
   ```

### Option 2: One-Line Installation

```powershell
Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

## How It Works

The standalone launcher (`setup-strangeloop.ps1`) automatically:

1. **Downloads Required Scripts**: Fetches the latest modular setup scripts from Azure DevOps
2. **Detects Environment**: Determines if you need Linux/WSL or Windows-only setup
3. **Downloads Platform Scripts**: Gets the appropriate Linux or Windows setup script
4. **Executes Setup**: Runs the complete setup process
5. **Cleans Up**: Removes temporary files after completion

## Script Architecture

- **`setup-strangeloop.ps1`** - Standalone launcher (only file users need to download)
- **`scripts/Setup-StrangeLoop-Main.ps1`** - Main orchestrator (downloaded dynamically)
- **`scripts/Setup-StrangeLoop-Linux.ps1`** - Linux/WSL setup (downloaded when needed)
- **`scripts/Setup-StrangeLoop-Windows.ps1`** - Windows setup (downloaded when needed)

## Configuration Options

### Custom Base URL

If you're hosting the scripts on a different repository or branch:

```powershell
.\setup_strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap&version=GBdevelop"
```

### Skip Components

```powershell
# Skip prerequisite checks
.\setup-strangeloop.ps1 -SkipPrerequisites

# Skip development tools installation
.\setup-strangeloop.ps1 -SkipDevelopmentTools

# Set Git user information
.\setup-strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@domain.com"
```

## Benefits of Standalone Approach

1. **Single File Download**: Users only need to download one file
2. **Always Latest**: Scripts are downloaded fresh from the Azure DevOps repository
3. **No Repository Required**: No need to clone the entire repository
4. **Automatic Updates**: Always gets the latest version of setup scripts
5. **Cross-Platform**: Works on any Windows machine with PowerShell
6. **Minimal Footprint**: No local files left behind after setup

## Requirements

- Windows 10/11 with PowerShell 5.1+
- Internet connection for script downloads
- Execution policy: RemoteSigned or Unrestricted

## Troubleshooting

### Execution Policy Issues

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Network Issues

If you have network restrictions, you can:

1. Download all scripts manually to a local folder
2. Run the local version with scripts in the `scripts/` folder
3. Use a corporate proxy or internal mirror

### Custom Hosting

To host scripts internally:

1. Upload scripts to your internal web server/repository
2. Update the `BaseUrl` parameter to point to your internal location
3. Ensure scripts maintain the same file structure and names

## Development

For development and testing of the standalone setup:

1. Test with local scripts first using the `scripts/` folder structure
2. Upload to a test branch/repository
3. Test the standalone download process
4. Merge to main repository when validated

## Security Considerations

- Scripts are downloaded over HTTPS
- Always verify the source URL before running
- Review script content if downloading from unofficial sources
- Consider code-signing for enterprise deployments
