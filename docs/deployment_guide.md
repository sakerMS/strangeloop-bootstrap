# StrangeLoop Bootstrap - Deployment Guide

Complete guide for deploying and maintaining the StrangeLoop Bootstrap system on GitHub.

## 🚀 **GitHub Repository Setup**

### **Step 1: Create GitHub Repository**
1. **Go to GitHub**: https://github.com/new
2. **Repository name**: `strangeloop-bootstrap`
3. **Description**: "StrangeLoop CLI Bootstrap Scripts - Single script automated setup"
4. **Visibility**: ✅ Public (for unrestricted downloads)
5. **Initialize**: ✅ Add README
6. **Click**: "Create repository"

### **Step 2: Repository Structure**
Upload files to your GitHub repository with this structure:

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                 # ✅ Single standalone setup script
├── reset_strangeloop.ps1                 # 🔄 SAFE RESET script (clean up setup changes)
├── scripts/                              # 📂 Legacy files (not used)
│   ├── strangeloop_linux.ps1             # �️ Legacy - No longer used
│   └── strangeloop_windows.ps1           # 🗃️ Legacy - No longer used
├── docs/                                 # 📂 Documentation folder
│   ├── user_guide.md                     # 📚 User installation guide
│   └── deployment_guide.md               # 📚 This deployment guide
└── README.md                             # 📖 Main documentation
```

## 🔗 **GitHub Raw URLs**

### **URL Format**
```
https://raw.githubusercontent.com/USERNAME/strangeloop-bootstrap/main/FILEPATH
```

### **Individual File URLs**
```
Setup Script:   https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1
Reset Script:   https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1
Linux Setup:    https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/scripts/strangeloop_linux.ps1
Windows Setup:  https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/scripts/strangeloop_windows.ps1
```

## 📋 **User Installation Commands**

### **One-Line Installation (Main Goal)**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

### **Reset/Cleanup Command**
```powershell
# Safe reset - removes only setup changes, preserves projects
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1" -OutFile "reset_strangeloop.ps1"; .\reset_strangeloop.ps1
```

### **Two-Step Installation**
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"

# Run the setup (no parameters needed)
.\setup_strangeloop.ps1
```

### **One-Line Installation**
```powershell
# Download and run in one command
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

### **Custom Repository**
```powershell
# Use different repository/branch
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-fork/strangeloop-bootstrap/develop"
```

## 🔧 **GitHub Solutions & Alternatives**

### **Solution 1: GitHub Repository (Current Implementation)**
Use GitHub raw URLs for reliable access:

```bash
# Repository: sakerMS/strangeloop-bootstrap
# Use GitHub raw URLs:
https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1
```

### **Solution 2: Fork Repository for Customization**
Create your own fork for custom configurations:

```powershell
# Fork the repository on GitHub
# Use your fork's URLs:
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-username/strangeloop-bootstrap/main"
```

### **Solution 3: Fork for Custom Configuration**
Create your own fork for enterprise customization:

```powershell
# Fork the repository and customize as needed
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-enterprise/strangeloop-bootstrap/main"
```

## 🏢 **Enterprise Deployment**

### **Internal/Enterprise Deployment**

1. **GitHub (Current Setup):**
   ```powershell
   # Using the official GitHub repository
   .\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main"
   ```

2. **Alternative Internal Hosting:**
   ```powershell
   # Upload to internal file server/CDN
   .\setup_strangeloop.ps1 -BaseUrl "https://internal.company.com/tools/strangeloop"
   
   # Use fork of GitHub repository
   .\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/company-org/strangeloop-bootstrap/main"
   ```

### **Group Policy Deployment**

Create a Group Policy script that:
1. Downloads the single setup script to user's directory
2. Executes with zero configuration required
3. All functionality self-contained in one file

### **SCCM/Intune Deployment**

Package the setup script for:
1. Silent execution in enterprise environments
2. Predefined project directories
3. Logging for deployment tracking

## 🔄 **Maintenance**

### **Updating the Script**

1. Update `setup_strangeloop.ps1` in your repository
2. Users automatically get latest version on next download
3. No dependencies to manage - single file deployment

### **Version Control**

Consider using different branches for releases:
```powershell
# Use specific branch
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/release-v1.2.0"

# Use main/develop branch
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/develop"
```

### **Monitoring**

Track usage through:
- GitHub repository insights
- Internal telemetry if added to scripts
- Corporate network logs (for internal hosting)

## 📋 **Advantages of GitHub**

1. **Public Access**: No authentication required
2. **Always Latest**: Direct access to repository files
3. **Version Control**: Use specific branches or commits
4. **Reliable CDN**: GitHub's global content delivery network
5. **Real-time Updates**: Changes are immediately available

## 🧪 **Testing Deployment**

### **Quick Test**
```powershell
# Test one-line installation
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

### **Custom Repository Test**
```powershell
# Test with custom fork
.\setup_strangeloop.ps1 -BaseUrl "https://raw.githubusercontent.com/your-org/strangeloop-bootstrap/main"
```

### **Maintenance Mode Test**
```powershell
# Test maintenance mode for package updates
iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1").Content -MaintenanceMode
```

### **Reset Functionality Test**
```powershell
# Test reset script (preview mode)
iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1").Content -WhatIf

# Test selective reset options
iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1").Content -KeepGit -KeepWSL
```

## 🔄 **Maintenance Operations**

### **Regular Package Updates**
Use MaintenanceMode for periodic updates without full reinstall:

```powershell
# Individual workstation
iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1").Content -MaintenanceMode

# Enterprise batch updates
$computers = @("PC001", "PC002", "PC003")
Invoke-Command -ComputerName $computers -ScriptBlock {
    iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1").Content -MaintenanceMode
}
```

### **Environment Reset and Troubleshooting**
Use reset script for troubleshooting or clean environment preparation:

```powershell
# Complete reset (removes everything)
iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1").Content -Force

# Selective reset (keep Git and WSL)
iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1").Content -KeepGit -KeepWSL

# Preview reset actions
iex (iwr "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/reset_strangeloop.ps1").Content -WhatIf
```

---
**Status**: GitHub implementation active  
**Requirements**: Internet connection required  
**Recommendation**: GitHub for all distribution
