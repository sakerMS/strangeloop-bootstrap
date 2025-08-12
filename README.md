# St## 🎯 Repository Structure

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ C## 📁 Deployment Structure

When deployed to GitHub, the structure is:
```
sakerMS/strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ Complete s## 📋 File Descriptions

| File | Purpose | User Facing | Architecture |
|------|---------|-------------|-------------|
| `setup_strangeloop.ps1` | Complete standalone setup | ✅ Download & Run | **Single Script (no parameters)** |
| `reset_strangeloop.ps1` | **SAFE RESET - Remove setup changes only** | 🔄 **Essential for troubleshooting** | **Project-safe cleanup** |
| `docs/user_guide.md` | User guide | 📚 Documentation | Documentation |
| `docs/deployment_guide.md` | Deployment guide | 📚 Documentation | Documentation |

### Key Changes in Single Script Architecture
- ❌ **Removed**: All parameters - now completely parameterless
- ❌ **Removed**: Legacy platform scripts - completely eliminated
- ❌ **Removed**: Download functionality and external dependencies
- ❌ **Removed**: Logging prefixes and complex output formatting
├── reset_strangeloop.ps1                # 🔄 Safe reset functionality
├── docs/                                # 📂 Documentation
│   ├── user_guide.md                    # 📚 User installation guide
│   └── deployment_guide.md              # 📚 GitHub deployment guide
└── README.md                            # 📖 Main documentation
```one Setup (Single Entry Point)
├── reset_strangeloop.ps1                # 🔄 RESET SCRIPT - Safely revert setup changes
├── docs/                                # 📂 Documentation
│   ├── user_guide.md                    # 📚 User installation guide
│   └── deployment_guide.md              # 📚 GitHub deployment guide
└── README.md                            # 📖 This file
```strap Scripts

This directory contains the complete StrangeLoop CLI standalone setup system with a minimalist single-script architecture.

## 🎯 Repository Structure

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ Complete Standalone Setup (Single Entry Point)
├── reset_strangeloop.ps1                # 🔄 RESET SCRIPT - Safely revert setup changes
├── scripts/                             # 📂 Legacy Platform Scripts (Unused)
│   ├── strangeloop_linux.ps1            # �️ Legacy - No longer used
│   └── strangeloop_windows.ps1          # 🗃️ Legacy - No longer used
├── docs/                                # 📂 Documentation
│   ├── user_guide.md                    # 📚 User installation guide
│   └── deployment_guide.md              # 📚 GitHub deployment guide
└── README.md                            # 📖 This file
```

## 🔄 **Reset Script - Clean Uninstall**

**`reset_strangeloop.ps1`** - Safely remove all changes made by the setup script:

### **What it removes:**
- ✅ **Execution policy changes** (resets to Restricted if changed to RemoteSigned)
- ✅ **Temporary files** (cleans up any setup-related temp files)

### **What it keeps safe:**
- 🛡️ **Your StrangeLoop projects** - All project directories remain untouched
- 🛡️ **StrangeLoop CLI** - The CLI itself is not uninstalled
- 🛡️ **User data** - All your work and configurations are preserved

### **Usage:**
```powershell
# Safe reset (asks for confirmation)
.\reset_strangeloop.ps1

# See what would be removed without actually doing it
.\reset_strangeloop.ps1 -WhatIf

# Force reset without prompts
.\reset_strangeloop.ps1 -Force

# Download and run reset script directly
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"
.\reset_strangeloop.ps1
```

## ⚙️ **Setup Script Usage**

### **Minimalist Design**
*All complexity has been removed for maximum simplicity and reliability. No configuration options, no skip parameters, no verbose modes.*

### **Single Command**
```powershell
.\setup_strangeloop.ps1
```

### **Complete Setup Features**
- **Complete Setup** - Full installation and configuration
  - Always checks prerequisites (PowerShell, Git, curl)
  - Always installs/updates StrangeLoop CLI to latest version
  - Always installs/updates all required packages
  - Interactive loop selection with smart environment detection
  - Example: `.\setup_strangeloop.ps1`

## 🎯 **Component Overview**

### Primary Script (Complete Solution)
- **`setup_strangeloop.ps1`** - **Single Standalone Setup Script**
  - Contains ALL functionality in a single file
  - Handles environment analysis and loop selection
  - Automatically derives WSL/Windows environment from selected loop
  - Supports both WSL and Windows project initialization
  - No external dependencies - completely self-contained
  - **Single Script Design**: No parameters required - maximum simplicity

### Reset Script (Troubleshooting)
- **`reset_strangeloop.ps1`** - **SAFE CLEANUP** - Remove only setup changes
  - ✅ Resets execution policy changes  
  - ✅ Cleans temporary files
  - 🛡️ **PRESERVES all your projects and work**
  - Perfect for: Testing, troubleshooting, or cleaning up after setup
  - **Safe by design** - Won't touch user-created content

### Documentation & Tools
- **`docs/user_guide.md`** - Complete user installation and usage guide
- **`docs/deployment_guide.md`** - GitHub deployment and maintenance guide

## 🚀 How It Works (Single Script Architecture)

1. **Single File**: Users only need `setup_strangeloop.ps1` - completely standalone
2. **Zero Configuration**: No parameters needed - just run it
3. **Smart Environment Detection**: Automatically determines WSL/Windows based on selected loop
4. **Loop-First Approach**: Shows all available loops, then derives environment requirements
5. **Self-Contained**: All functionality built into the main script - no external dependencies
6. **Always Reliable**: Always checks prerequisites and installs latest packages
7. **Clean Output**: No logging prefixes - simple, clear messages

## 📁 Deployment Structure

When deployed to GitHub, the structure is:
```
sakerMS/strangeloop-bootstrap/
├── setup_strangeloop.ps1                # ⭐ Complete standalone setup
├── reset_strangeloop.ps1                # 🔄 Safe reset functionality
├── test.ps1                             # 🧪 Test launcher (convenience)
├── scripts/                             # 📂 Legacy files (not used)
│   ├── strangeloop_linux.ps1            # �️ Legacy
│   └── strangeloop_windows.ps1          # 🗃️ Legacy
├── tests/                               # 🧪 Test Framework
│   ├── test_setup_strangeloop.ps1       # Integration tests
│   ├── test_setup_functions.ps1         # Unit tests
│   ├── run_all_tests.ps1               # Test runner with reporting
│   ├── test_usage_guide.ps1            # Interactive test guide
│   └── TEST_FRAMEWORK_README.md         # Test documentation
├── docs/                                # 📂 Documentation
│   ├── user_guide.md                    # 📚 User installation guide
│   └── deployment_guide.md              # 📚 GitHub deployment guide
└── README.md                            # 📖 Main documentation
```

## 🧪 Test Framework

A comprehensive test suite validates the setup script's functionality across different environments and use cases.

### Test Structure
- **`test.ps1`** - Convenience launcher in root directory
- **`tests/test_setup_strangeloop.ps1`** - Integration tests (613 lines)
  - System requirements validation
  - WSL integration testing
  - VS Code integration testing
  - Network connectivity checks
  - Performance benchmarking
- **`tests/test_setup_functions.ps1`** - Unit tests (456 lines)
  - Function-level validation
  - Parameter testing
  - Edge case handling
  - Performance testing
- **`tests/run_all_tests.ps1`** - Test orchestration (448 lines)
  - Comprehensive test execution
  - HTML/JSON report generation
  - Performance metrics
  - Failure analysis

### Running Tests
```powershell
# Quick test (from root directory)
.\test.ps1

# Integration tests only
.\test.ps1 -Type integration

# Unit tests only
.\test.ps1 -Type unit

# All tests with detailed reporting
.\test.ps1 -Type all

# From tests directory
cd tests
.\run_all_tests.ps1 -TestSuite All -OutputFormat HTML
```

### Test Categories
- **System Requirements**: PowerShell version, Git availability, WSL status
- **Script Validation**: Function loading, parameter handling, error scenarios
- **WSL Integration**: Ubuntu installation, package management, cross-platform compatibility
- **VS Code Integration**: Extension management, workspace configuration
- **Network Connectivity**: Download capabilities, package repositories
- **Performance**: Execution time, memory usage, resource optimization
- **Security**: Execution policy handling, safe file operations

## 🔗 GitHub URLs

**Repository**: `https://github.com/sakerMS/strangeloop-bootstrap`  
**Branch**: `main`

**User Download URL**:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"
```

## 💻 Usage Examples

### For End Users (Ultra-Simplified)
```powershell
# One-line installation (complete setup)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1

# Standard usage (no parameters needed)
.\setup_strangeloop.ps1
```

### Smart Environment Selection
The script automatically determines the environment based on your loop selection:

```powershell
# The script will automatically:
# 1. Show ALL available loops with platform indicators [WSL], [Win], [Any]
# 2. After you select a loop, it derives the environment:
#    - WSL-required loops (python-mcp-server, flask-linux) → Force WSL
#    - Windows-only loops (ads-snr-basic, asp-dotnet-framework-api) → Force Windows
#    - Universal loops (python-cli) → Let you choose if WSL is available
# 3. Always check prerequisites and install latest packages for reliability
```

### For Testing/Development
```powershell
# 🔄 SAFE RESET - Remove only setup changes (keeps your projects)
.\reset_strangeloop.ps1

# Preview what would be reset (no actual changes)
.\reset_strangeloop.ps1 -WhatIf

# Force reset without prompts
.\reset_strangeloop.ps1 -Force

# Download reset script directly from GitHub
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"
.\reset_strangeloop.ps1
```

## 🛠️ Development Workflow

### For Script Maintainers
1. **Single File Development**: All functionality is in `setup_strangeloop.ps1`
2. **Test Locally**: Test the script directly - completely standalone
3. **Legacy Cleanup**: Platform scripts no longer used or maintained
4. **Simple Deployment**: Just push changes to GitHub - immediately available

### Architecture Benefits
- ✅ **Zero Configuration**: No parameters needed - just run the script
- ✅ **Always Reliable**: Prerequisites and packages always checked and updated
- ✅ **Maximum Simplicity**: No complex options, modes, or external dependencies
- ✅ **Smart Environment Detection**: Derives WSL/Windows from loop selection
- ✅ **Consistent Experience**: Same setup flow for all users
- ✅ **Clean Output**: No prefixes or verbose logging - clear, simple messages
- ✅ **Up-to-date Packages**: Ensures latest versions are installed
- ✅ **Minimalist Design**: Only 1 optional parameter for maximum simplicity

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

### Quick Reset (Start Fresh)
If you encounter issues or want to clean up setup changes:
```powershell
# 🔄 SAFE RESET - Download and run reset script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"
.\reset_strangeloop.ps1

# Or if you have the repository locally
.\reset_strangeloop.ps1 -Force
```

**The reset script is SAFE** - it only removes setup-related changes and preserves all your projects and work.

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
# 🔄 RECOMMENDED - Safe reset (preserves your projects)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"
.\reset_strangeloop.ps1

# Preview what would be reset
.\reset_strangeloop.ps1 -WhatIf

# Or if you have the repository locally
.\reset_strangeloop.ps1 -Force
```

**✅ Safe Reset Features:**
- Only removes setup-related changes (temp files, execution policy)
- **Preserves all your StrangeLoop projects and work**
- Does not uninstall StrangeLoop CLI or affect user data
- Perfect for troubleshooting without losing your work

### Common Setup Issues
- WSL installation may require system restart
- Azure CLI requires AdsFPS Subscription access
- StrangeLoop installer requires manual completion
- Internet connection required for all script downloads

## 📋 File Descriptions

| File | Purpose | User Facing | Architecture |
|------|---------|-------------|-------------|
| `setup_strangeloop.ps1` | Complete unified setup | ✅ Download & Run | **Minimalist (no parameters)** |
| `reset_strangeloop.ps1` | **SAFE RESET - Remove setup changes only** | 🔄 **Essential for troubleshooting** | **Project-safe cleanup** |
| `scripts/strangeloop_linux.ps1` | Linux-specific logic | �️ Legacy/Unused | Platform-specific |
| `scripts/strangeloop_windows.ps1` | Windows-specific logic | �️ Legacy/Unused | Platform-specific |
| `docs/user_guide.md` | User guide | 📚 Documentation | Documentation |
| `docs/deployment_guide.md` | Deployment guide | 📚 Documentation | Documentation |

### Key Changes in Single Script Architecture
- ❌ **Removed**: All parameters - now completely parameterless
- ❌ **Removed**: Download functionality and platform script dependencies
- ❌ **Removed**: Logging prefixes and complex output formatting
- ❌ **Removed**: External file dependencies and modular architecture
- ✅ **Enhanced**: True single-script design - completely standalone
- ✅ **Simplified**: Clean, prefix-free output for better user experience
- ✅ **Streamlined**: Fixed Windows settings.yaml update logic

---
**Version**: 6.1 (Single Script Architecture)  
**Created**: August 2025  
**Author**: Sakr Omera/Bing Ads Teams Egypt  
**Repository**: GitHub - sakerMS/strangeloop-bootstrap  
**Architecture**: Single standalone script with zero dependencies
