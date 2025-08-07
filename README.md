# StrangeLoop Bootstrap Scripts

This directory contains the complete StrangeLoop CLI standalone setup system that can be deployed and downloaded independently from GitHub.

## 🎯 Repository Structure

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ Main launcher (User Entry Point)
├── scripts/                             # 📂 Core Setup Scripts
│   ├── setup_strangeloop_main.ps1       # 🎯 Main orchestrator
│   ├── setup_strangeloop_linux.ps1      # 🐧 Linux/WSL setup
│   └── setup_strangeloop_windows.ps1    # 🪟 Windows setup
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
  - Provides graceful fallback to local scripts if download fails

### Core Setup Scripts (Downloaded Dynamically)
- **`scripts/setup_strangeloop_main.ps1`** - Main orchestrator that handles the complete setup flow
- **`scripts/setup_strangeloop_linux.ps1`** - Linux/WSL environment setup and dependency management  
- **`scripts/setup_strangeloop_windows.ps1`** - Windows environment setup and dependency management

### Documentation & Tools
- **`docs/user_guide.md`** - Complete user installation and usage guide
- **`docs/deployment_guide.md`** - GitHub deployment and maintenance guide

### Legacy Files
- **`setup_strangeloop_original.ps1`** - Backup of original monolithic script
- **`readme_setup.md`** - Legacy setup documentation

## 🚀 How It Works

1. **User Downloads**: Only needs `setup_strangeloop.ps1`
2. **Dynamic Download**: Launcher downloads latest scripts from GitHub
3. **Execution**: Scripts run with temporary files and proper cleanup
4. **Fallback**: Uses local scripts if remote download fails

## 📁 Deployment Structure

When deployed to GitHub, the structure should be:
```
sakerMS/strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ User download point
├── scripts/                             # 📂 Core setup scripts
│   ├── setup_strangeloop_main.ps1       # 🎯 Main orchestrator
│   ├── setup_strangeloop_linux.ps1      # 🐧 Linux/WSL setup
│   └── setup_strangeloop_windows.ps1    # 🪟 Windows setup
├── docs/                                # 📂 Documentation
│   ├── github_deployment_guide.md       # 📚 Deployment guide
│   ├── github_solutions.md              # 📚 Download solutions
│   ├── user_installation_guide.md       # 📚 User guide
│   └── [other documentation...]         # 📚 Additional docs
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

# Skip components
.\setup_strangeloop.ps1 -SkipPrerequisites -SkipDevelopmentTools
```

### For Testing/Development
```powershell
# Test deployment readiness
.\test_deployment.ps1 -TestDownload -ValidateScripts

# Use local scripts (development mode)
.\setup_strangeloop.ps1
# (Automatically falls back to local if download fails)
```

## 🛠️ Development Workflow

### For Script Maintainers
1. **Edit Scripts**: Make changes to setup scripts in this folder
2. **Test Locally**: Test with fallback mechanism using local scripts
3. **Deploy**: Push changed scripts to GitHub
4. **Validate**: Run `test_deployment.ps1` to verify deployment

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
- Use local fallback mode for development

### Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Common Setup Issues
- WSL installation may require system restart
- Azure CLI requires AdsFPS Subscription access
- StrangeLoop installer requires manual completion
- For local development, ensure scripts are in `scripts/` folder

## 📋 File Descriptions

| File | Purpose | User Facing |
|------|---------|-------------|
| `setup_strangeloop.ps1` | Main launcher | ✅ Download & Run |
| `scripts/setup_strangeloop_main.ps1` | Orchestrator | 🔄 Auto-downloaded |
| `scripts/setup_strangeloop_linux.ps1` | Linux setup | 🔄 Auto-downloaded |
| `scripts/setup_strangeloop_windows.ps1` | Windows setup | 🔄 Auto-downloaded |
| `docs/user_guide.md` | User guide | 📚 Documentation |
| `docs/deployment_guide.md` | Deployment guide | 📚 Documentation |

---
**Version**: 2.0 (Standalone Architecture)  
**Created**: August 2025  
**Author**: Sakr Omera/Bing Ads Teams Egypt  
**Repository**: GitHub - sakerMS/strangeloop-bootstrap
