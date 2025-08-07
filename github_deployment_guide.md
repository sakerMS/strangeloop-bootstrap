# StrangeLoop Bootstrap - GitHub Deployment Guide

## 🚀 **GitHub Repository Setup**

### **Step 1: Create GitHub Repository**
1. **Go to GitHub**: https://github.com/new
2. **Repository name**: `strangeloop-bootstrap`
3. **Description**: "StrangeLoop CLI Bootstrap Scripts - Automated setup and installation"
4. **Visibility**: ✅ Public (for unrestricted downloads)
5. **Initialize**: ✅ Add README
6. **Click**: "Create repository"

### **Step 2: Upload Bootstrap Scripts**
Upload these files from your `bootstrap-scripts\` folder:

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1              # ✅ Main launcher (users download this)
├── setup_strangeloop_main.ps1         # ✅ Main orchestrator
├── setup_strangeloop_linux.ps1        # ✅ Linux/WSL setup
├── setup_strangeloop_windows.ps1      # ✅ Windows setup
├── setup_strangeloop_auth.ps1         # 🔒 SharePoint version (optional)
├── test_deployment.ps1                # 🧪 Testing script
├── README.md                          # 📋 Installation guide
└── docs/
    ├── deployment_guide.md
    ├── user_guide.md
    └── troubleshooting.md
```

### **Step 3: Update Repository URLs**
Once you create the repository, update the BaseUrl in the scripts:

**Replace `your-org` with your actual GitHub username/organization:**
```powershell
# From:
$BaseUrl = "https://raw.githubusercontent.com/your-org/strangeloop-bootstrap/main"

# To:
$BaseUrl = "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main"
```

## 🔗 **GitHub Raw URLs**

### **URL Format**
```
https://raw.githubusercontent.com/USERNAME/strangeloop-bootstrap/main/FILENAME.ps1
```

### **Individual File URLs**
```
Main Script:    https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1
Orchestrator:   https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop_main.ps1
Linux Setup:    https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop_linux.ps1
Windows Setup:  https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop_windows.ps1
```

## 📋 **User Installation Commands**

### **One-Line Installation (Main Goal)**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

### **Alternative: Download then Run**
```powershell
# Download
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"

# Run with options
.\setup_strangeloop.ps1 -SkipPrerequisites -UserName "Your Name"
```

### **Advanced Usage**
```powershell
# Use custom GitHub repository
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-fork/strangeloop-bootstrap/main"

# Skip various components
.\setup_strangeloop.ps1 -SkipPrerequisites -SkipDevelopmentTools

# Set Git configuration
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"
```

## 🧪 **Testing After Upload**

### **Test 1: Direct Download**
```powershell
# Test main script download
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "test_download.ps1"
Get-Content test_download.ps1 -Head 10  # Should show PowerShell script
Remove-Item test_download.ps1
```

### **Test 2: Complete Installation Flow**
```powershell
# Test full installation
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1 -SkipPrerequisites
```

### **Test 3: Validation Script**
```powershell
# Run the test deployment script
.\test_deployment.ps1 -TestDownload -ValidateScripts -BaseUrl "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main"
```

## 📝 **Repository Documentation**

### **README.md Content**
```markdown
# StrangeLoop CLI Bootstrap

Automated setup and installation scripts for StrangeLoop CLI development environment.

## 🚀 Quick Install

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

## 📋 What This Does

- ✅ Checks prerequisites (Git, Azure CLI, Git LFS)
- ✅ Sets up Azure authentication
- ✅ Installs StrangeLoop CLI
- ✅ Configures development environment
- ✅ Analyzes available templates

## ⚙️ Options

```powershell
# Skip prerequisites check
.\setup_strangeloop.ps1 -SkipPrerequisites

# Skip development tools
.\setup_strangeloop.ps1 -SkipDevelopmentTools

# Set Git user info
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"
```

## 🛠️ Manual Installation

If the one-line command doesn't work:

1. Download `setup_strangeloop.ps1`
2. Run `.\setup_strangeloop.ps1`
3. Scripts will automatically download additional components

## 📞 Support

- **Issues**: Create an issue in this repository
- **Documentation**: See `/docs` folder
- **Local Fallback**: Scripts work offline if downloaded manually
```

## 🎯 **Benefits of GitHub Hosting**

### **✅ Advantages**
- **No Authentication**: Public access without login
- **Reliable**: GitHub's global CDN
- **Version Control**: Track changes and releases
- **Issues/Discussions**: Built-in support system
- **Free**: No hosting costs
- **Standard Practice**: Industry norm for script distribution

### **🔄 Always Up-to-Date**
- **Latest Scripts**: Users always get current version
- **Easy Updates**: Just push to repository
- **Rollback**: Easy to revert if needed
- **Branching**: Test changes in separate branches

### **📊 Analytics**
- **Download Stats**: Track repository traffic
- **Issues**: See what problems users encounter
- **Contributions**: Allow community improvements

## 🚀 **Next Steps**

1. **Create GitHub repository** with the name `strangeloop-bootstrap`
2. **Upload all files** from your `bootstrap-scripts` folder
3. **Update the BaseUrl** with your actual GitHub username
4. **Test the complete flow** end-to-end
5. **Share the installation command** with your team

---
**Status**: ✅ Ready for GitHub deployment  
**URL Template**: `https://raw.githubusercontent.com/USERNAME/strangeloop-bootstrap/main/`  
**Installation**: One-line PowerShell command  
**Fallback**: Local scripts always work
