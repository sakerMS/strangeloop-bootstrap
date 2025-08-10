# StrangeLoop Bootstrap Scripts

This directory contains the complete StrangeLoop CLI standalone setup system that can be deployed and downloaded independently from GitHub.

## 🎯 Repository Structure

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ Main launcher (User Entry Point)
├── reset_strangeloop.ps1                # 🔄 Reset script (revert all changes)
├── scripts/                             # 📂 Core Setup Scripts
│   ├── strangeloop_main.ps1             # 🎯 Main orchestrator
│   ├── strangeloop_linux.ps1            # 🐧 Linux/WSL setup
│   └── strangeloop_windows.ps1          # 🪟 Windows setup
├── docs/                                # 📂 Documentation
│   ├── user_guide.md                    # 📚 User installation guide
│   └── deployment_guide.md              # 📚 GitHub deployment guide
└── README.md                            # 📖 This file
```

## 🎯 Component Overview

### Primary Script (User Entry Point)
- **`setup_strangeloop.ps1`** - Standalone launcher that users download and run
  - Downloads and executes all other scripts dynamically from GitHub
  - Handles parameter passing and error recovery
  - Requires internet connection and GitHub access

### Reset Script (Troubleshooting)
- **`reset_strangeloop.ps1`** - Revert all changes made by the setup
  - Removes StrangeLoop CLI installation
  - Cleans up Python packages and WSL environment
  - Resets Git configuration and environment variables
  - Useful for testing, troubleshooting, or starting over

### Core Setup Scripts (Downloaded Dynamically)
- **`scripts/strangeloop_main.ps1`** - Main orchestrator that handles the complete setup flow
- **`scripts/strangeloop_linux.ps1`** - Linux/WSL environment setup and dependency management  
- **`scripts/strangeloop_windows.ps1`** - Windows environment setup and dependency management

### Documentation & Tools
- **`docs/user_guide.md`** - Complete user installation and usage guide
- **`docs/deployment_guide.md`** - GitHub deployment and maintenance guide

## 🚀 How It Works

1. **User Downloads**: Only needs `setup_strangeloop.ps1`
2. **Dynamic Download**: Launcher downloads latest scripts from GitHub
3. **Execution**: Scripts run with temporary files and proper cleanup
4. **Online Only**: Always uses latest scripts from repository

## 📁 Deployment Structure

When deployed to GitHub, the structure should be:
```
sakerMS/strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ User download point
├── scripts/                             # 📂 Core setup scripts
│   ├── strangeloop_main.ps1             # 🎯 Main orchestrator
│   ├── strangeloop_linux.ps1            # 🐧 Linux/WSL setup
│   └── strangeloop_windows.ps1          # 🪟 Windows setup
├── docs/                                # 📂 Documentation
│   ├── user_guide.md                    # 📚 User installation guide
│   └── deployment_guide.md              # 📚 GitHub deployment guide
└── README.md                            # 📖 Main documentation
```

## 🔗 GitHub URLs

**Repository**: `https://github.com/sakerMS/strangeloop-bootstrap`  
**Branch**: `main`

**User Download URL**:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"
```

## 💻 Usage Examples

### For End Users
```powershell
# One-line installation
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1

# With parameters
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "you@domain.com"

# Maintenance mode (update packages only)
.\setup_strangeloop.ps1 -MaintenanceMode

# Skip components
.\setup_strangeloop.ps1 -SkipPrerequisites -SkipDevelopmentTools

# Maintenance mode with skipped prerequisites
.\setup_strangeloop.ps1 -MaintenanceMode -SkipPrerequisites
```

### For Testing/Development
```powershell
# Reset all changes (for testing/troubleshooting)
.\reset_strangeloop.ps1

# Reset with options
.\reset_strangeloop.ps1 -KeepWSL -KeepGit    # Keep WSL and Git settings
.\reset_strangeloop.ps1 -WhatIf              # See what would be reset
.\reset_strangeloop.ps1 -Force               # Skip confirmation prompts
```

## 🛠️ Development Workflow

### For Script Maintainers
1. **Edit Scripts**: Make changes to setup scripts in this repository
2. **Test Remotely**: Test with GitHub URLs after pushing changes
3. **Deploy**: Scripts are immediately available via GitHub raw URLs
4. **Validate**: Test deployment with the main launcher script from different locations

### For Repository Updates
1. **Update URLs**: Modify paths in `setup_strangeloop.ps1` if repository structure changes
2. **Update Documentation**: Keep deployment guides current
3. **Test Deployment**: Validate with test scripts before sharing with users

## 🔧 Platform Support

### Linux/WSL (Recommended)
- **Templates**: `flask-linux`, `python-mcp-server`, `python-cli`, `python-semantic-kernel-agent`, `langgraph-agent`, `csharp-mcp-server`, `csharp-semantic-kernel-agent`, `dotnet-aspire`
- **Environment**: Ubuntu-24.04 LTS in WSL 2
- **Tools**: Python 3.9+, Poetry, pipx, Git, Docker (Linux containers)

### Windows Native
- **Templates**: `flask-windows`, `ads-snr-basic`, `asp-dotnet-framework-api`
- **Environment**: Windows 10/11 native
- **Tools**: Python 3.9+, Poetry, pipx, Git, Docker (Windows containers), .NET Framework

## ✅ Prerequisites

- Windows 10/11 with PowerShell 5.1+
- Internet connection for script downloads
- Execution policy: RemoteSigned or Unrestricted
- GitHub access for downloading scripts

## 🚨 Troubleshooting

### Download Issues
- Check internet connection and GitHub access
- Verify URLs in deployment documentation
- Ensure repository is publicly accessible
- Try downloading scripts manually to verify connectivity

### Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Reset Everything (Start Over)
If you encounter issues or want to start fresh:
```powershell
# Download and run reset script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"
.\reset_strangeloop.ps1

# Or if you have the repository locally
.\reset_strangeloop.ps1 -Force
```

### Common Setup Issues
- WSL installation may require system restart
- Azure CLI requires AdsFPS Subscription access
- StrangeLoop installer requires manual completion
- Internet connection required for all script downloads

## 📋 File Descriptions

| File | Purpose | User Facing |
|------|---------|-------------|
| `setup_strangeloop.ps1` | Main launcher | ✅ Download & Run |
| `reset_strangeloop.ps1` | Reset script | 🔄 Troubleshooting |
| `scripts/strangeloop_main.ps1` | Orchestrator | 🔄 Auto-downloaded |
| `scripts/strangeloop_linux.ps1` | Linux setup | 🔄 Auto-downloaded |
| `scripts/strangeloop_windows.ps1` | Windows setup | 🔄 Auto-downloaded |
| `docs/user_guide.md` | User guide | 📚 Documentation |
| `docs/deployment_guide.md` | Deployment guide | 📚 Documentation |

---
**Version**: 2.0 (Standalone Architecture)  
**Created**: August 2025  
**Author**: Sakr Omera/Bing Ads Teams Egypt  
**Repository**: GitHub - sakerMS/strangeloop-bootstrap
