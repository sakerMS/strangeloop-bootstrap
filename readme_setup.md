# StrangeLoop CLI Setup

This repository contains automated setup scripts for the StrangeLoop CLI development environment.

## Quick Start

Run the main setup script from the root directory:

```powershell
.\Setup-StrangeLoop.ps1
```

This launcher will automatically call the appropriate scripts from the `scripts/` folder.

## File Structure

```
q:\src\strangeloop\
├── Setup-StrangeLoop.ps1              # 🚀 Main launcher script (START HERE)
├── README-Setup.md                    # This documentation
├── setup-strangeloop-original.ps1    # Original monolithic script (preserved)
└── scripts/                           # 📁 All setup scripts
    ├── README.md                      # Detailed documentation
    ├── Setup-StrangeLoop-Main.ps1     # Main entry point and orchestrator
    ├── Setup-StrangeLoop-Linux.ps1    # Linux/WSL dependencies
    └── Setup-StrangeLoop-Windows.ps1  # Windows dependencies
```

## Scripts Overview

### 🚀 Setup-StrangeLoop.ps1 (Root Launcher)
**The main entry point - start here!**
- Simple launcher that calls the modular scripts
- Passes all parameters through to the main script
- Provides easy access from the root directory

### 📋 scripts/Setup-StrangeLoop-Main.ps1 (Main Orchestrator)
**Handles the complete setup flow**
- Prerequisites checking (Azure CLI, Git, Git LFS)
- Azure authentication and subscription setup
- StrangeLoop CLI installation
- Loop analysis and platform requirement determination
- Calls appropriate OS-specific dependency script
- Loop initialization and project creation
- Final configuration and setup completion

### 🐧 scripts/Setup-StrangeLoop-Linux.ps1 (Linux/WSL Dependencies)
**Handles Linux/WSL-specific environment setup**
- WSL installation and Ubuntu-24.04 setup
- System package management and updates
- Python development environment (Python 3.9+, pip, venv)
- Package management tools (pipx, Poetry)
- Git configuration for Linux environment
- Docker configuration for Linux containers
- Cross-platform compatibility settings

### 🪟 scripts/Setup-StrangeLoop-Windows.ps1 (Windows Dependencies)
**Handles Windows-specific environment setup**
- Windows Python environment verification/setup
- Package management tools (pipx, Poetry) for Windows
- Git configuration for Windows environment
- Docker configuration for Windows containers
- Development tools and IDE detection
- .NET Framework and .NET Core/5+ detection
- Windows-specific compatibility settings

## Usage Examples

### Basic Setup (Recommended)
```powershell
.\Setup-StrangeLoop.ps1
```

### Advanced Usage

```powershell
# Skip prerequisites check (if already installed)
.\Setup-StrangeLoop.ps1 -SkipPrerequisites

# Skip development tools setup (environment only)
.\Setup-StrangeLoop.ps1 -SkipDevelopmentTools

# Provide user information upfront
.\Setup-StrangeLoop.ps1 -UserName "John Doe" -UserEmail "john.doe@company.com"

# Combined parameters
.\Setup-StrangeLoop.ps1 -SkipPrerequisites -UserName "John Doe" -UserEmail "john.doe@company.com"
```

### Direct Script Execution (Advanced)

```powershell
# Run main script directly
.\scripts\Setup-StrangeLoop-Main.ps1

# Update Linux/WSL environment only
.\scripts\Setup-StrangeLoop-Linux.ps1 -UserName "John Doe" -UserEmail "john.doe@company.com"

# Update Windows environment only
.\scripts\Setup-StrangeLoop-Windows.ps1
```

## Architecture Benefits

- ✅ **Easy Access**: Simple launcher in root directory
- ✅ **Modular Design**: Each script handles specific responsibilities
- ✅ **Independent Execution**: OS-specific scripts can be run standalone for updates
- ✅ **Reduced Interdependencies**: Code duplication acceptable to avoid complex dependencies
- ✅ **Clear Separation**: Prerequisites, platform detection, dependency management, and project setup are clearly separated
- ✅ **Maintenance**: Easier to maintain and update specific components

## Platform Support

### Linux/WSL (Recommended)
- **Required for**: `flask-linux`, `python-mcp-server`, `python-cli`, `python-semantic-kernel-agent`, `langgraph-agent`, `csharp-mcp-server`, `csharp-semantic-kernel-agent`, `dotnet-aspire`
- **Environment**: Ubuntu-24.04 LTS in WSL 2
- **Tools**: Python 3.9+, Poetry, pipx, Git, Docker (Linux containers)

### Windows Native
- **Compatible with**: `flask-windows`, `ads-snr-basic`, `asp-dotnet-framework-api`
- **Environment**: Windows 10/11 native
- **Tools**: Python 3.9+, Poetry, pipx, Git, Docker (Windows containers), .NET Framework

## Prerequisites

Before running any script, ensure you have:
- Windows 10/11 with PowerShell 5.1+
- Execution Policy set to RemoteSigned or Unrestricted
- Administrator privileges (for WSL installation if needed)

## Troubleshooting

### Common Issues
1. **Execution Policy**: Run `Set-ExecutionPolicy RemoteSigned` as Administrator
2. **WSL Installation**: May require system restart
3. **Azure CLI**: Ensure you have access to AdsFPS Subscription
4. **StrangeLoop Installation**: Complete the installer manually when prompted

### Getting Help
- Check `scripts/README.md` for detailed documentation
- Review error messages for specific guidance
- Ensure all prerequisites are met before running

## Version Information
- **Version**: 1.0
- **Created**: August 2025
- **Author**: Sakr Omera/Bing Ads Teams Egypt
- **Compatibility**: Windows 10/11, PowerShell 5.1+
