# StrangeLoop CLI Bootstrap - User Guide (v3.0 Enterprise WSL Edition)

Enterprise-grade automated setup for StrangeLoop CLI development environment with enhanced error handling, robust Azure DevOps integration, and advanced WSL session management.

## 🚀 **Quick Install**

Copy and paste this command into PowerShell:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

> **Note**: This uses the sakerMS GitHub repository with v3.0 Enterprise WSL Edition.

## 🔄 **Quick Reset (Enhanced Safety)**

If you need to clean up setup changes or troubleshoot issues:

```powershell
# Download and run reset script (SAFE - preserves your projects)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"; .\reset_strangeloop.ps1
```

**✅ Enhanced Reset Script Safety Features:**
- **Default "No" Confirmations**: All destructive operations default to safe "No" option with clear `[y/N - default: N]` indicators
- **Project Preservation**: **Preserves all your StrangeLoop projects and work**
- **Granular Control**: Choose what to reset (WSL, Azure CLI, StrangeLoop CLI)
- **What-If Mode**: Preview changes before execution with `-WhatIf` parameter
- **Force Mode**: Skip confirmations for automation with `-Force` parameter

## 📋 **What This Does (v3.0 Enhancements)**

The enterprise bootstrap script will:

- ✅ **Enhanced Prerequisites**: PowerShell, Git, curl with improved validation
- ✅ **Robust StrangeLoop Installation**: Enhanced Azure DevOps download with retry logic and corruption detection
- ✅ **Enterprise WSL Management**: Advanced session management, health monitoring, and performance reporting
- ✅ **Smart Environment Analysis**: WSL availability with enhanced detection and error recovery
- ✅ **Template Discovery**: Show available project templates with better error handling
- ✅ **Reliable Configuration**: Platform-specific setup with comprehensive error recovery

### **New v3.0 Features:**
- 🔥 **Enhanced Download Reliability**: Multiple retry methods for StrangeLoop installation with authentication verification
- 🛡️ **Package Corruption Detection**: Validates download integrity to prevent 0-byte installations
- 🚀 **Simplified WSL Architecture**: Eliminated DEBIAN_FRONTEND complexity that caused command hangs
- 📊 **Enterprise WSL Session Management**: Advanced session tracking and health monitoring
- ⚡ **Performance Monitoring**: Real-time WSL session performance and resource usage tracking

## ⚙️ **Usage (Enterprise Features)**

### **Standard Setup (Recommended)**
```powershell
# Complete setup with enterprise WSL features - no parameters needed
.\setup_strangeloop.ps1
```

### **Advanced Usage with v3.0 Features**
```powershell
# Show version and changelog information
.\setup_strangeloop.ps1 -Version

# Enable verbose WSL debugging and session monitoring
.\setup_strangeloop.ps1 -VerboseWSL

# Skip prerequisite checks (for advanced users)
.\setup_strangeloop.ps1 -SkipPrerequisites

# Pre-configure Git user information
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"

# Show detailed help with all parameters
.\setup_strangeloop.ps1 -Help
```

### **Reset Script Advanced Usage**
```powershell
# Standard reset with enhanced safety confirmations
.\reset_strangeloop.ps1

# Preview what would be reset without making changes
.\reset_strangeloop.ps1 -WhatIf

# Force reset without confirmations (for automation)
.\reset_strangeloop.ps1 -Force
```

## 🎯 **Design Philosophy**

### **Zero Configuration**
- **No parameters needed** - just run the script
- **Always reliable** - checks prerequisites and installs latest packages
- **Smart detection** - determines environment from your loop selection
- **Single script** - completely standalone with no external dependencies

**Use cases:**
- ✅ Pre-downloading for offline environments
- ✅ Development and testing scenarios
- ✅ Advanced customization needs

## 🏗️ **Architecture**

### **Minimalist Design**
```
setup_strangeloop.ps1           # 🚀 Complete setup (download this only)
├── Embedded functionality      # 🎯 All features built-in
├── Smart environment detection # 🧠 WSL vs Windows auto-detection  
└── Optional platform scripts   # 📦 Downloaded only if needed
    ├── strangeloop_linux.ps1   # � Linux/WSL specifics
    └── strangeloop_windows.ps1 # 🪟 Windows specifics
```
├── scripts/strangeloop_linux.ps1  # 🐧 Linux/WSL setup
└── scripts/strangeloop_windows.ps1 # 🪟 Windows setup
```

### **Smart Features**
- **📥 Self-Contained**: No external downloads needed for standard setup
- **🌐 Always Current**: Ensures latest StrangeLoop CLI and packages
- **🎨 Rich Output**: Color-coded status messages and progress
- **⚡ Smart Detection**: Automatically configures for your environment
- **🛡️ Error Handling**: Comprehensive error recovery and troubleshooting
- **🎯 Zero Config**: No parameters needed for standard installation

## 🛠️ **Installation Methods**

### **Option 1: One-Line Install (Recommended)**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

### **Option 2: Download and Run**
1. Download `setup_strangeloop.ps1` from the repository
2. Open PowerShell in the download folder
3. Run `.\setup_strangeloop.ps1`

### **Option 3: Clone Repository**
```powershell
git clone https://github.com/sakerMS/strangeloop-bootstrap.git
cd strangeloop-bootstrap
.\setup_strangeloop.ps1
```

## 🔧 **Troubleshooting Guide (v3.0 Enhanced)**

### **StrangeLoop Installation Issues**

#### **Problem**: Download Timeout or Failed Installation
**Symptoms**: 
- "Download timeout or failed" error messages
- 0-byte StrangeLoop installer files
- Authentication errors with Azure DevOps

**Solutions**:
1. **Check Azure CLI Authentication**:
   ```powershell
   az account show
   # If not logged in, run: az login
   ```

2. **Verify Package Integrity**:
   The script now automatically detects corrupted downloads and retries with enhanced methods

3. **Manual Package Download**:
   If automated download fails, manually download from Azure DevOps and place in the expected location

4. **Reset and Retry**:
   ```powershell
   .\reset_strangeloop.ps1
   .\setup_strangeloop.ps1
   ```

#### **Problem**: Commands Hanging or WSL Session Issues
**Note**: v3.0 has eliminated DEBIAN_FRONTEND complexity that previously caused command hangs.

**Solutions**:
1. **Use Enhanced WSL Session Management**:
   ```powershell
   # Check WSL session health
   Test-WSLSessionHealth
   
   # View performance report
   Show-WSLPerformanceReport
   
   # Clean up unhealthy sessions
   Optimize-WSLSessions
   ```

2. **Enable Verbose Mode for Debugging**:
   ```powershell
   .\setup_strangeloop.ps1 -VerboseWSL
   ```

#### **Problem**: Reset Script Safety Concerns
**Note**: v3.0 reset script defaults to safe "No" confirmations.

**Features**:
- All destructive operations default to "No" with clear `[y/N - default: N]` indicators
- Projects are never touched during reset
- Use `-WhatIf` to preview changes before execution

### **Environment Issues**

#### **PowerShell Execution Policy**
```powershell
# Check current policy
Get-ExecutionPolicy

# The script will handle this automatically, but manual fix:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### **WSL Not Available**
The script will detect WSL availability and guide you through installation if needed.

### **Enterprise WSL Features (New in v3.0)**

#### **Session Management Commands**
```powershell
# View session performance and health
Show-WSLPerformanceReport

# Check session connectivity
Test-WSLSessionHealth

# Clean up unhealthy sessions
Optimize-WSLSessions

# Toggle WSL window visibility for debugging
Set-WSLWindowVisibility $true
```

#### **Performance Monitoring**
- Real-time session execution time tracking
- Resource usage monitoring
- Automatic cleanup of unhealthy sessions
- Health status reporting

## 🎯 **Supported Templates**

StrangeLoop includes templates for:

- **🌐 Web Applications**: Flask (Linux/Windows), ASP.NET Framework
- **🤖 AI Agents**: Python/C# Semantic Kernel, LangGraph
- **🔗 MCP Servers**: Python/C# Model Context Protocol servers
- **💻 CLI Tools**: Python command-line applications  
- **☁️ Cloud Services**: .NET Aspire, AdsSnR services

## 🔧 **Requirements**

### **Prerequisites** (checked and installed automatically)
- **PowerShell 5.1+**: Windows PowerShell or PowerShell Core
- **Git**: Version control system
- **curl**: Download utility (typically pre-installed)

### **Supported Platforms**
- **✅ Windows 10/11**: Native PowerShell support
- **✅ WSL (Windows Subsystem for Linux)**: Automatically detected and used for Linux templates
- **✅ Linux**: With PowerShell Core installed

## 🐛 **Troubleshooting**

### **Common Issues**

**PowerShell Execution Policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Network/Download Issues**
- Check internet connection
- Try from different network
- Use manual installation method
- Scripts fall back to local versions automatically

**Skip Parameters Troubleshooting**

Use `-SkipPrerequisites` when you encounter:
- ❌ "Git is already installed" conflicts
- ❌ "Azure CLI installation failed" in corporate environments  
- ❌ Package manager conflicts with existing tools
- ❌ Corporate policies prevent software installation

Use `-SkipDevelopmentTools` when you encounter:
- ❌ "Python version conflicts" with existing installations
- ❌ "Docker Desktop already running" messages
- ❌ "Poetry already configured" warnings
- ❌ WSL distribution conflicts with existing setup

Combine both parameters (`-SkipPrerequisites -SkipDevelopmentTools`) when:
- ✅ Running in pre-configured development environments
- ✅ Using company-managed tool installations
- ✅ Performing StrangeLoop CLI installation only
- ✅ Working with custom development stacks

**Permission Issues**
```powershell
# Run PowerShell as Administrator
Right-click PowerShell → "Run as Administrator"
```

### **🔄 Reset Everything (Start Over) - SAFE METHOD**

If you encounter persistent issues or want to clean up setup changes:

```powershell
# 🔄 RECOMMENDED - Download and run safe reset script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"

# Safe reset (preserves your projects)
.\reset_strangeloop.ps1

# Preview what would be reset (no actual changes)
.\reset_strangeloop.ps1 -WhatIf

# Force reset without prompts
.\reset_strangeloop.ps1 -Force
```

**✅ Safe Reset Features:**
- ✅ **Only removes setup-related changes** (temp files, execution policy)
- 🛡️ **Preserves all your StrangeLoop projects and work**
- ✅ **Does not uninstall StrangeLoop CLI** or affect user data
- ✅ **Perfect for troubleshooting** without losing your work
- ✅ **No risk of data loss** - your projects stay intact

**When to use the reset script:**
- 🔧 Setup script encountered errors
- 🔧 Want to clean up temporary files
- 🔧 Execution policy needs to be reset
- 🔧 Testing or troubleshooting setup issues
- 🔧 Starting fresh without losing existing projects

### **Getting Help**
- **📝 Create an Issue**: Use GitHub Issues for bug reports
- **📖 Documentation**: Check `/docs` folder for detailed guides
- **💬 Discussions**: Use GitHub Discussions for questions
- **🔄 Reset Script**: Use reset script to resolve issues safely

---

**🎉 Ready to start building with StrangeLoop? Run the installation command above!**
