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

```powershell
# Basic installation
.\setup_strangeloop.ps1

# Skip prerequisites check (if tools already installed)
.\setup_strangeloop.ps1 -SkipPrerequisites

# Skip development tools installation
.\setup_strangeloop.ps1 -SkipDevelopmentTools

# Set Git user configuration
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"

# Combine multiple options
.\setup_strangeloop.ps1 -SkipPrerequisites -UserName "Your Name" -UserEmail "your.email@company.com"

# Use custom repository URL
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-fork/strangeloop-bootstrap/main"
```

## 🏗️ **Architecture**

### **Modular Design**
```
setup_strangeloop.ps1           # 🚀 Main launcher (download this)
├── scripts/setup_strangeloop_main.ps1   # 🎯 Main orchestrator
├── scripts/setup_strangeloop_linux.ps1  # 🐧 Linux/WSL setup
└── scripts/setup_strangeloop_windows.ps1 # 🪟 Windows setup
```

### **Smart Features**
- **📥 Dynamic Downloads**: Latest scripts downloaded automatically
- **🔄 Fallback Mechanism**: Uses local scripts if download fails
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

### **Option 3: Local Scripts**
If downloads fail, the script automatically falls back to local versions.

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

**Permission Issues**
```powershell
# Run PowerShell as Administrator
Right-click PowerShell → "Run as Administrator"
```

### **Getting Help**
- **📝 Create an Issue**: Use GitHub Issues for bug reports
- **📖 Documentation**: Check `/docs` folder for detailed guides
- **💬 Discussions**: Use GitHub Discussions for questions
- **🔄 Fallback**: Local scripts always work as backup

---

**🎉 Ready to start building with StrangeLoop? Run the installation command above!**
