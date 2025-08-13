# StrangeLoop CLI Bootstrap Repository - Enterprise Setup System

This repository contains the complete StrangeLoop CLI standalone setup system with enterprise-grade WSL management, enhanced error handling, and robust Azure DevOps integration.

## ⭐ Quick Start (Recommended)

**To access and run the setup script directly from GitHub, use:**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

**If you already have the script locally, run:**
```powershell
.\setup_strangeloop.ps1
```

## 🎯 Repository Structure

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1      # ⭐ Complete Standalone Setup
├── reset_strangeloop.ps1      # 🔄 RESET SCRIPT - Safely revert setup changes
├── docs/                      # 📂 Documentation
│   ├── user_guide.md          # 📚 User installation guide
│   └── deployment_guide.md    # 📚 Deployment guide
└── README.md                  # 📖 Main documentation
```

## 📋 File Descriptions

| File                      | Purpose                                      |
|--------------------------|----------------------------------------------|
| setup_strangeloop.ps1     | Enterprise WSL setup with enhanced error handling |
| reset_strangeloop.ps1     | SAFE RESET - Remove setup changes only       |
| docs/user_guide.md        | User installation guide                      |
| docs/deployment_guide.md  | Deployment guide                             |
| README.md                 | Main documentation                           |

## 🚀 What's New in v3.0 Enterprise WSL Edition

- Enhanced error handling and reliability for StrangeLoop installation
- Direct WSL execution (no DEBIAN_FRONTEND complexity)
- Enterprise WSL session management and health monitoring
- Reset script improvements: default "No" confirmations, project-safe cleanup, What-If mode

## 📖 Complete Setup Guide

### Step 1: Prerequisites
- Windows 10/11 with PowerShell 5.1+
- Administrator privileges (for WSL installation if needed)
- Internet connection (for downloading dependencies)

### Step 2: Download the Repository
```powershell
# Option 1: Direct download
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"

# Option 2: Clone repository
# git clone https://github.com/sakerMS/strangeloop-bootstrap.git
# cd strangeloop-bootstrap
```

### Step 3: Run the Setup
```powershell
.\setup_strangeloop.ps1
```

### Step 4: Verify Installation
```powershell
# Check StrangeLoop installation
strangeloop --version
```

## 🔄 Troubleshooting & Reset

If you need to clean up setup changes or troubleshoot issues:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"; .\reset_strangeloop.ps1
```

- All destructive operations default to safe "No" option with clear `[y/N - default: N]` indicators
- Projects are preserved
- Use `-WhatIf` to preview changes before execution
- Use `-Force` to skip confirmations for automation

## 📚 Additional Documentation

- [`docs/user_guide.md`](docs/user_guide.md) - User installation guide
- [`docs/deployment_guide.md`](docs/deployment_guide.md) - Deployment guide

---

**Author**: Sakr Omera/Bing Ads Teams Egypt  
**Version**: 3.0.0 Enterprise WSL Edition  
**Last Updated**: August 14, 2025
