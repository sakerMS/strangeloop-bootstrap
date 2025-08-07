# StrangeLoop Bootstrap Scripts

This directory contains the complete StrangeLoop CLI standalone setup system that can be deployed and downloaded independently.

## 🎯 Standalone Architecture

### Primary Script (User Entry Point)
- **`setup_strangeloop.ps1`** - Standalone launcher that users download and run
  - Downloads and executes all other scripts dynamically from Azure DevOps
  - Handles parameter passing and error recovery
  - Provides graceful fallback to local scripts if download fails

### Core Setup Scripts (Downloaded Dynamically)
- **`setup_strangeloop_main.ps1`** - Main orchestrator that handles the complete setup flow
- **`setup_strangeloop_linux.ps1`** - Linux/WSL environment setup and dependency management  
- **`setup_strangeloop_windows.ps1`** - Windows environment setup and dependency management

### Documentation & Tools
- **`azure_devops_setup.md`** - Azure DevOps deployment guide and URL configuration
- **`deployment_guide.md`** - Complete deployment instructions for different environments
- **`standalone_setup.md`** - User documentation for the standalone setup system
- **`implementation_summary.md`** - Technical overview of the entire system
- **`test_deployment.ps1`** - Validation tool for testing deployment readiness

### Legacy Files
- **`setup_strangeloop_original.ps1`** - Backup of original monolithic script
- **`readme_setup.md`** - Legacy setup documentation

## 🚀 How It Works

1. **User Downloads**: Only needs `setup-strangeloop.ps1`
2. **Dynamic Download**: Launcher downloads latest scripts from Azure DevOps
3. **Execution**: Scripts run with temporary files and proper cleanup
4. **Fallback**: Uses local scripts if remote download fails

## 📁 Deployment Structure

When deployed to Azure DevOps, the structure should be:
```
AdsSnR_Containers/strangeloop-bootstrap/
├── setup-strangeloop.ps1                 # ⭐ User download point
├── Setup-StrangeLoop-Main.ps1           # 🎯 Main orchestrator
├── Setup-StrangeLoop-Linux.ps1          # 🐧 Linux/WSL setup
├── Setup-StrangeLoop-Windows.ps1        # 🪟 Windows setup
└── [documentation files...]             # 📚 Guides and tools
```

## 🔗 Azure DevOps URLs

**Repository**: `https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers`  
**Branch**: `strangeloop-bootstrap`

**User Download URL**:
```powershell
Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"
```

## 💻 Usage Examples

### For End Users
```powershell
# One-line installation
Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1

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
3. **Deploy**: Upload changed scripts to Azure DevOps
4. **Validate**: Run `test-deployment.ps1` to verify deployment

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
- Azure DevOps access (Microsoft employees)

## 🚨 Troubleshooting

### Download Issues
- Check internet connection and Azure DevOps access
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

## 📋 File Descriptions

| File | Purpose | User Facing |
|------|---------|-------------|
| `setup_strangeloop.ps1` | Main launcher | ✅ Download & Run |
| `setup_strangeloop_main.ps1` | Orchestrator | 🔄 Auto-downloaded |
| `setup_strangeloop_linux.ps1` | Linux setup | 🔄 Auto-downloaded |
| `setup_strangeloop_windows.ps1` | Windows setup | 🔄 Auto-downloaded |
| `test_deployment.ps1` | Validation tool | 🛠️ Development |
| `azure_devops_setup.md` | Deployment guide | 📚 Documentation |
| `deployment_guide.md` | Usage instructions | 📚 Documentation |
| `standalone_setup.md` | User guide | 📚 Documentation |

---
**Version**: 2.0 (Standalone Architecture)  
**Created**: August 2025  
**Author**: Sakr Omera/Bing Ads Teams Egypt  
**Repository**: Azure DevOps - AdsSnR_Containers/strangeloop-bootstrap
