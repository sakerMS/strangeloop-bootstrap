# Azure DevOps Integration Summary

## ✅ Updated URLs and Configuration

I've successfully updated all the StrangeLoop standalone setup scripts and documentation to use your Azure DevOps repository:

**Repository:** `https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers`  
**Branch:** `strangeloop-bootstrap`  
**Path:** `/strangeloop-bootstrap/`

## 📁 Required Repository Structure

Upload these files to your Azure DevOps repository with this structure:

```
AdsSnR_Containers/
└── strangeloop-bootstrap/
    ├── setup_strangeloop.ps1                 # ⭐ Main launcher (users download this)
    ├── setup_strangeloop_main.ps1            # 🎯 Main orchestrator
    ├── setup_strangeloop_linux.ps1           # 🐧 Linux/WSL setup
    ├── setup_strangeloop_windows.ps1         # 🪟 Windows setup
    └── [documentation files...]              # 📚 Guides and validation tools
```

## 🔗 URLs Updated

### Launcher Script URLs
- **Main Script**: `https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop_main.ps1&version=GBstrangeloop-bootstrap&download=true`
- **Linux Script**: `https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop_linux.ps1&version=GBstrangeloop-bootstrap&download=true`
- **Windows Script**: `https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop_windows.ps1&version=GBstrangeloop-bootstrap&download=true`

### User Download URL
```powershell
Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"
```

## 📝 Files Updated

1. **✅ `setup-strangeloop.ps1`** - Updated default BaseUrl to Azure DevOps
2. **✅ `DEPLOYMENT-GUIDE.md`** - Updated with Azure DevOps URLs and Microsoft-specific instructions
3. **✅ `STANDALONE-SETUP.md`** - Updated all example URLs
4. **✅ `test-deployment.ps1`** - Updated validation script URLs
5. **✅ `IMPLEMENTATION-SUMMARY.md`** - Complete overview maintained

## 🚀 Next Steps

### 1. Upload to Azure DevOps
Upload these files to your `strangeloop-bootstrap` branch:
- `setup_strangeloop.ps1` (main launcher)
- `setup_strangeloop_main.ps1`
- `setup_strangeloop_linux.ps1` 
- `setup_strangeloop_windows.ps1`
- Documentation and validation files

### 2. Test Deployment
Once uploaded, test with:
```powershell
.\test-deployment.ps1 -TestDownload -ValidateScripts
```

### 3. Share with Users
Users can then install with one command:
```powershell
Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

## 🔒 Azure DevOps Benefits

- **Internal Microsoft Access**: Only accessible to Microsoft employees with proper permissions
- **Version Control**: Full Git history and branch management
- **Security**: Enterprise-grade security and access controls
- **Integration**: Works with Microsoft's internal tools and policies
- **Compliance**: Meets Microsoft's internal compliance requirements

## ⚙️ Branch Management

Use different branches for different versions:
```powershell
# Development version
.\setup_strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap&version=GBdevelop"

# Release version  
.\setup_strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap&version=GBrelease-v1.0"
```

The standalone setup system is now fully configured for your Azure DevOps environment and ready for deployment!
