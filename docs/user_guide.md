# StrangeLoop CLI Bootstrap - User Guide

Zero-configuration automated setup for StrangeLoop CLI development environment.

## 🚀 **Quick Install**

Copy and paste this command into PowerShell:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

> **Note**: This uses the sakerMS GitHub repository.

## � **Quick Reset (Clean Up)**

If you need to clean up setup changes or troubleshoot:

```powershell
# Download and run reset script (SAFE - preserves your projects)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"; .\reset_strangeloop.ps1
```

**✅ The reset script is SAFE:**
- Only removes setup-related changes (execution policy)
- **Preserves all your StrangeLoop projects and work**
- Does not uninstall StrangeLoop CLI or affect user data

## �📋 **What This Does**

The bootstrap script will:

- ✅ **Check Prerequisites**: PowerShell, Git, curl
- ✅ **Install StrangeLoop**: CLI and dependencies (always latest version)
- ✅ **Analyze Environment**: WSL availability for Linux environments
- ✅ **Discover Templates**: Show available project templates
- ✅ **Smart Setup**: Platform-specific configuration based on your choice

## ⚙️ **Usage (Ultra-Simple)**

### **Standard Setup (Recommended)**
```powershell
# Complete setup - no parameters needed
.\setup_strangeloop.ps1
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
