# StrangeLoop CLI Bootstrap - User Guide

Automated setup and installation scripts for StrangeLoop CLI development environment.

## 🚀 **Quick Install**

Copy and paste this command into PowerShell:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

> **Note**: This uses the sakerMS GitHub repository.

## 📋 **What This Does**

The bootstrap script will:

- ✅ **Check Prerequisites**: Git, Azure CLI, Git LFS
- ✅ **Configure Git**: Line endings and user settings
- ✅ **Install StrangeLoop**: CLI and dependencies
- ✅ **Analyze Templates**: Show available project templates
- ✅ **Environment Setup**: Platform-specific configuration

## ⚙️ **Command Options**

### **Basic Usage**
```powershell
# Basic installation
.\setup_strangeloop.ps1

# With Git user configuration
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"
```

### **Skip Options**
```powershell
# Skip prerequisites check (if tools already installed)
.\setup_strangeloop.ps1 -SkipPrerequisites

# Skip development tools installation
.\setup_strangeloop.ps1 -SkipDevelopmentTools

# Skip both (minimal setup)
.\setup_strangeloop.ps1 -SkipPrerequisites -SkipDevelopmentTools
```

**When to use `-SkipPrerequisites`:**
- ✅ Git is already installed and configured
- ✅ Azure CLI is already installed
- ✅ Git LFS is already available
- ✅ Running on managed corporate environments
- ✅ Prerequisites installed via different package managers

**When to use `-SkipDevelopmentTools`:**
- ✅ Python environment already configured
- ✅ Poetry and pipx already installed
- ✅ Docker already set up
- ✅ WSL already configured for development
- ✅ Custom development environment in place

### **Maintenance Options**
```powershell
# Maintenance mode (update packages only)
.\setup_strangeloop.ps1 -MaintenanceMode

# Enable verbose logging for troubleshooting
.\setup_strangeloop.ps1 -Verbose

# Verbose mode with maintenance (detailed package updates)
.\setup_strangeloop.ps1 -Verbose -MaintenanceMode

# Set Git user configuration
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"

### **Advanced Combinations**
```powershell
# Combine multiple options
.\setup_strangeloop.ps1 -SkipPrerequisites -UserName "Your Name" -UserEmail "your.email@company.com"

# Maintenance mode with custom user settings
.\setup_strangeloop.ps1 -MaintenanceMode -UserName "Your Name" -UserEmail "your.email@company.com"

# Verbose mode with skipped components
.\setup_strangeloop.ps1 -Verbose -SkipPrerequisites -SkipDevelopmentTools

# Use custom repository URL
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-fork/strangeloop-bootstrap/main"
```

### **Enterprise Scenarios**
```powershell
# Corporate environment with pre-installed tools
.\setup_strangeloop.ps1 -SkipPrerequisites -UserName "John Doe" -UserEmail "john.doe@company.com"

# CI/CD pipeline with existing Docker
.\setup_strangeloop.ps1 -SkipDevelopmentTools -MaintenanceMode

# Troubleshooting deployment issues
.\setup_strangeloop.ps1 -Verbose -SkipPrerequisites
```
```

## 🏗️ **Architecture**

### **Modular Design**
```
setup_strangeloop.ps1           # 🚀 Main launcher (download this)
├── scripts/strangeloop_main.ps1   # 🎯 Main orchestrator
├── scripts/strangeloop_linux.ps1  # 🐧 Linux/WSL setup
└── scripts/strangeloop_windows.ps1 # 🪟 Windows setup
```

### **Smart Features**
- **📥 Dynamic Downloads**: Latest scripts downloaded automatically
- **🌐 Always Current**: Uses latest repository scripts
- **🎨 Rich Output**: Color-coded status messages and progress
- **⚡ Platform Detection**: Automatically configures for your environment
- **🛡️ Error Handling**: Comprehensive error recovery and troubleshooting

## 🛠️ **Alternative Installation Methods**

### **Option 1: Download and Run**
1. Download `setup_strangeloop.ps1` from the repository
2. Open PowerShell in the download folder
3. Run `.\setup_strangeloop.ps1`

### **Option 2: Clone Repository**
```powershell
git clone https://github.com/sakerMS/strangeloop-bootstrap.git
cd strangeloop-bootstrap
.\setup_strangeloop.ps1
```

### **Option 3: Custom Repository**
You can specify a custom repository URL for enterprise deployments:

```powershell
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-org/strangeloop-bootstrap/main"
```

## 🎯 **Supported Templates**

StrangeLoop includes templates for:

- **🌐 Web Applications**: Flask (Linux/Windows), ASP.NET Framework
- **🤖 AI Agents**: Python/C# Semantic Kernel, LangGraph
- **🔗 MCP Servers**: Python/C# Model Context Protocol servers
- **💻 CLI Tools**: Python command-line applications  
- **☁️ Cloud Services**: .NET Aspire, AdsSnR services

## 🔧 **Requirements**

### **Prerequisites** (installed automatically if missing)
- **PowerShell 5.1+**: Windows PowerShell or PowerShell Core
- **Git 2.0+**: Version control system
- **Azure CLI**: Microsoft Azure command-line interface
- **Git LFS**: Large file support for Git

### **Supported Platforms**
- **✅ Windows 10/11**: Native PowerShell support
- **✅ WSL (Windows Subsystem for Linux)**: Recommended for Linux templates
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

### **Reset Everything (Start Over)**

If you encounter persistent issues or want to completely start over:

```powershell
# Download reset script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"

# Basic reset (removes everything)
.\reset_strangeloop.ps1

# Reset with options
.\reset_strangeloop.ps1 -KeepWSL          # Keep WSL Ubuntu distribution
.\reset_strangeloop.ps1 -KeepGit          # Keep Git global configuration
.\reset_strangeloop.ps1 -WhatIf           # Preview what would be reset
.\reset_strangeloop.ps1 -Force            # Skip all confirmations
```

**What the reset script removes:**
- ✅ StrangeLoop CLI installation
- ✅ Python packages (pipx, Poetry packages)
- ✅ WSL Ubuntu distribution (optional)
- ✅ Git global configuration changes (optional)
- ✅ Environment variables
- ✅ Docker networks created by setup
- ✅ Temporary files

### **Getting Help**
- **📝 Create an Issue**: Use GitHub Issues for bug reports
- **📖 Documentation**: Check `/docs` folder for detailed guides
- **💬 Discussions**: Use GitHub Discussions for questions
- **🔄 Reset Script**: Use reset script to resolve issues and start over

---

**🎉 Ready to start building with StrangeLoop? Run the installation command above!**
