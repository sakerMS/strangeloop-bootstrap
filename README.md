# StrangeLoop CLI Bootstrap Repository - Enterprise Setup System

This repository contains the complete StrangeLoop CLI standalone setup system with enterprise-grade WSL management, enhanced error handling, and robust Azure DevOps integration.

## ⭐ Quick Start (Recommended)

**For immediate setup, run this single command:**
```powershell
# Download and run the complete setup (v3.0 Enterprise WSL Edition)
.\setup_strangeloop.ps1
```

## 🎯 Repository Structure

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ Complete Standalone Setup (v3.0 Enterprise WSL Edition)
├── reset_strangeloop.ps1                # 🔄 RESET SCRIPT - Safely revert setup changes
├── scripts/                             # 📂 Utility Scripts (Future Use)
│   └── README.md                        # 📚 Scripts documentation
├── tests/                               # 🧪 Comprehensive Test Suite
│   ├── test_setup_strangeloop.ps1       # 🔬 Integration tests with Ubuntu detection
│   ├── test_setup_functions.ps1         # ⚙️ Unit function tests
│   ├── test_ubuntu_detection.ps1        # 🔍 Ubuntu detection testing utility
│   ├── test_runner.ps1                  # 🎯 Convenience test launcher
│   ├── run_all_tests.ps1               # 🎯 Test runner with reporting
│   ├── test_usage_guide.ps1            # 📚 Interactive testing guide
│   └── README.md                        # 📚 Testing documentation
├── docs/                                # 📂 Documentation
│   ├── user_guide.md                    # 📚 User installation guide
│   └── deployment_guide.md              # 📚 GitHub deployment guide
└── README.md                            # 📖 This file
```

## 📋 File Descriptions

| File | Purpose | User Facing | Architecture |
|------|---------|-------------|-------------|
| `setup_strangeloop.ps1` | **Enterprise WSL setup with enhanced error handling** | ✅ Download & Run | **v3.0 with versioning & session management** |
| `reset_strangeloop.ps1` | **SAFE RESET - Remove setup changes only** | 🔄 **Essential for troubleshooting** | **Project-safe cleanup with default No confirmations** |
| `tests/test_ubuntu_detection.ps1` | Ubuntu detection testing utility | 🔍 **Standalone testing** | **Diagnostic tool** |
| `tests/test_runner.ps1` | Convenience test launcher | 🎯 **Test convenience** | **Test launcher** |
| `tests/test_setup_strangeloop.ps1` | Integration tests with Ubuntu detection | 🧪 **Comprehensive testing** | **Test framework** |
| `tests/run_all_tests.ps1` | Test runner with reporting | 🎯 **Automated testing** | **Test automation** |

## 🚀 What's New in v3.0 Enterprise WSL Edition

### Enhanced Error Handling & Reliability
- **StrangeLoop Download Improvements**: Enhanced Azure DevOps artifact download with retry logic and comprehensive error detection
- **Authentication Verification**: Automatic Azure CLI authentication validation before download attempts
- **Package Corruption Detection**: Validates download integrity to prevent 0-byte or corrupted installations
- **Multiple Retry Methods**: Fallback download strategies for improved reliability

### Simplified WSL Architecture
- **Direct WSL Execution**: Streamlined `wsl -d Ubuntu -- bash -c "command"` approach without environment variable complexity
- **Removed DEBIAN_FRONTEND Complexity**: Eliminated all DEBIAN_FRONTEND references that were causing command hangs
- **Enterprise WSL Session Management**: Advanced session tracking, health monitoring, and performance reporting

### Enhanced User Safety
- **Reset Script Improvements**: Clear default "No" confirmations with enhanced visual indicators (`[y/N - default: N]`)
- **Project-Safe Cleanup**: Reset script preserves user projects while cleaning setup artifacts
- **What-If Mode**: Preview reset operations before execution

## 📖 Complete Setup Guide

### Step 1: Prerequisites
- Windows 10/11 with PowerShell 5.1+
- Administrator privileges (for WSL installation if needed)
- Internet connection (for downloading dependencies)

### Step 2: Download the Repository
```powershell
# Option 1: Direct download
git clone https://github.com/sakerMS/strangeloop-bootstrap.git
cd strangeloop-bootstrap

# Option 2: Download ZIP and extract
```

### Step 3: Run the Setup
```powershell
# Standard installation with enterprise WSL features
.\setup_strangeloop.ps1

# With additional parameters (optional)
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"

# Show version information
.\setup_strangeloop.ps1 -Version

# Enable verbose WSL debugging
.\setup_strangeloop.ps1 -VerboseWSL
```

### Step 4: Verify Installation
```powershell
# Check StrangeLoop installation
strangeloop --version

# Run tests to verify setup
.\tests\run_all_tests.ps1
```

## 🔄 Troubleshooting & Reset

### Common Issues & Solutions

#### StrangeLoop Installation Failed
**Symptoms**: Download timeout, 0-byte files, authentication errors
**Solutions**:
1. **Check Azure CLI Authentication**: `az account show`
2. **Manual Package Verification**: Check Azure DevOps package integrity
3. **Alternative Installation**: Use manual download from Azure DevOps
4. **Reset and Retry**: Use reset script and try again

```powershell
# Reset the setup completely
.\reset_strangeloop.ps1

# Preview what would be reset (safe mode)
.\reset_strangeloop.ps1 -WhatIf

# Force reset without confirmations
.\reset_strangeloop.ps1 -Force
```

#### WSL Session Issues
**Symptoms**: Commands hanging, session errors
**Solutions**:
1. **Check WSL Health**: Built-in session health monitoring
2. **Clean WSL Sessions**: Automatic cleanup after setup
3. **Performance Report**: View WSL session statistics

#### Environment Variable Issues
**Note**: v3.0 has eliminated all DEBIAN_FRONTEND complexity that previously caused command hangs.

### Reset Script Safety Features
- **Default to No**: All destructive operations default to "No" for safety
- **Clear Visual Indicators**: Confirmation prompts show `[y/N - default: N]`
- **Project Preservation**: User StrangeLoop projects are never touched
- **Granular Control**: Choose what to reset (WSL, Azure CLI, StrangeLoop CLI)

## 🧪 Testing Framework

### Available Tests
```powershell
# Run all tests with comprehensive reporting
.\tests\run_all_tests.ps1

# Interactive testing guide
.\tests\test_usage_guide.ps1

# Specific test categories
.\tests\test_ubuntu_detection.ps1      # Ubuntu WSL detection
.\tests\test_setup_functions.ps1       # Core functionality
.\tests\test_setup_strangeloop.ps1     # Full integration test
```

### Test Coverage
- ✅ Ubuntu WSL detection and validation
- ✅ PowerShell execution policy handling
- ✅ StrangeLoop CLI installation verification
- ✅ Azure DevOps authentication testing
- ✅ WSL session management validation
- ✅ Error handling and recovery testing

## 📊 Enterprise WSL Features

### Session Management
- **Health Monitoring**: Automatic session health checks
- **Performance Tracking**: Session execution time and resource usage
- **Cleanup Automation**: Automatic cleanup of unhealthy sessions
- **Visibility Control**: Toggle WSL window visibility for debugging

### Management Commands
```powershell
# View session performance and health
Show-WSLPerformanceReport

# Check session connectivity
Test-WSLSessionHealth

# Clean up unhealthy sessions
Optimize-WSLSessions

# Toggle WSL window visibility
Set-WSLWindowVisibility $true
```

## 🔧 Advanced Configuration

### Script Parameters
```powershell
# Skip prerequisite checks
.\setup_strangeloop.ps1 -SkipPrerequisites

# Skip development tools installation
.\setup_strangeloop.ps1 -SkipDevelopmentTools

# Enable verbose WSL output
.\setup_strangeloop.ps1 -VerboseWSL

# Show help information
.\setup_strangeloop.ps1 -Help
```

### Version Information
```powershell
# Display version and changelog
.\setup_strangeloop.ps1 -Version
```

Current version: **v3.0.0 Enterprise WSL Edition**
- Build: 20250813.1
- Author: Sakr Omera/Bing Ads Teams Egypt
- Last Updated: August 13, 2025

## 📚 Additional Documentation

- [`user_installation_guide.md`](user_installation_guide.md) - Detailed user installation guide
- [`deployment_guide.md`](deployment_guide.md) - GitHub deployment instructions
- [`tests/README.md`](tests/README.md) - Comprehensive testing documentation
- [`github_deployment_guide.md`](github_deployment_guide.md) - GitHub deployment specifics

## 🎯 Architecture Summary

### Design Principles
1. **Simplicity**: Single script entry point with minimal parameters
2. **Reliability**: Enhanced error handling and comprehensive retry logic
3. **Safety**: Default "No" confirmations and project preservation
4. **Enterprise-Grade**: Advanced WSL session management and monitoring
5. **Maintainability**: Clear versioning and comprehensive logging

### Key Improvements from Previous Versions
- ✅ Eliminated DEBIAN_FRONTEND complexity that caused hangs
- ✅ Enhanced StrangeLoop download with authentication verification
- ✅ Improved reset script safety with clear defaults
- ✅ Added enterprise WSL session management
- ✅ Comprehensive error detection and recovery
- ✅ Performance monitoring and health checks

## 🎉 Success Indicators

After successful setup, you should have:
- ✅ StrangeLoop CLI installed and functional
- ✅ WSL Ubuntu environment configured
- ✅ Python and Poetry properly configured
- ✅ Git user configuration set
- ✅ Azure CLI authenticated (if needed)
- ✅ All tests passing
- ✅ Enterprise WSL session management active

## 📞 Support & Contributing

For issues or improvements:
1. Check the troubleshooting section above
2. Run the reset script and retry
3. Check the test framework for diagnostics
4. Review Azure DevOps package integrity
5. Submit issues with detailed error logs

**Author**: Sakr Omera/Bing Ads Teams Egypt  
**Version**: 3.0.0 Enterprise WSL Edition  
**Last Updated**: August 13, 2025
