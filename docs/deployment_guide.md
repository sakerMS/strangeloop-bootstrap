# StrangeLoop Bootstrap - Deployment Guide

Complete guide for deploying and maintaining the StrangeLoop Bootstrap system on GitHub.

## 🚀 **GitHub Repository Setup**

### **Step 1: Create GitHub Repository**
1. **Go to GitHub**: https://github.com/new
2. **Repository name**: `strangeloop-bootstrap`
3. **Description**: "StrangeLoop CLI Bootstrap Scripts - Automated setup and installation"
4. **Visibility**: ✅ Public (for unrestricted downloads)
5. **Initialize**: ✅ Add README
6. **Click**: "Create repository"

### **Step 2: Repository Structure**
Upload files to your GitHub repository with this structure:

```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                 # ✅ Main launcher (users download this)
├── scripts/                              # 📂 Core setup scripts folder
│   ├── setup_strangeloop_main.ps1        # ✅ Main orchestrator
│   ├── setup_strangeloop_linux.ps1       # ✅ Linux/WSL setup
│   └── setup_strangeloop_windows.ps1     # ✅ Windows setup
├── docs/                                 # 📂 Documentation folder
│   ├── user_guide.md                     # 📚 User installation guide
│   ├── deployment_guide.md               # 📚 This deployment guide
│   └── implementation_summary.md         # 📚 Technical overview
└── README.md                             # 📖 Main documentation
```

## 🔗 **GitHub Raw URLs**

### **URL Format**
```
https://raw.githubusercontent.com/USERNAME/strangeloop-bootstrap/main/FILEPATH
```

### **Individual File URLs**
```
Main Script:    https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1
Orchestrator:   https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/scripts/setup_strangeloop_main.ps1
Linux Setup:    https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/scripts/setup_strangeloop_linux.ps1
Windows Setup:  https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/scripts/setup_strangeloop_windows.ps1
```

## 📋 **User Installation Commands**

### **One-Line Installation (Main Goal)**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

### **Two-Step Installation**
```powershell
# Download the launcher
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"

# Run the setup
.\setup_strangeloop.ps1
```

### **With Parameters**
```powershell
# Download and run with custom options
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/sakerMS/strangeloop-bootstrap/main/setup_strangeloop.ps1" -OutFile "setup_strangeloop.ps1"
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "you@domain.com"
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

### **Solution 3: Use Local Scripts (Development)**
The local fallback mechanism works perfectly:

```powershell
# System automatically falls back to local scripts
.\setup_strangeloop.ps1 -SkipPrerequisites
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
1. Downloads the launcher to user's temp directory
2. Executes with predefined parameters
3. Cleans up after completion

### **SCCM/Intune Deployment**

Package the launcher script with:
1. Predefined BaseUrl pointing to internal repository
2. Silent execution parameters
3. Logging for deployment tracking

## 🔄 **Maintenance**

### **Updating Scripts**

1. Update scripts in your repository
2. Users automatically get latest version on next run
3. No need to redistribute - launcher always downloads fresh copies

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
5. **Local Fallback**: Scripts work offline if already downloaded

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

---
**Status**: GitHub implementation active  
**Fallback**: Local scripts work 100%  
**Recommendation**: GitHub for all distribution
