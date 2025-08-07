# StrangeLoop CLI - One-Command Installation

## 🚀 **Quick Install**

Copy and paste this command into PowerShell:

```powershell
Invoke-WebRequest -Uri "https://microsofteur-my.sharepoint.com/personal/sakromera_microsoft_com/_layouts/15/download.aspx?SourceUrl=%2Fpersonal%2Fsakromera%5Fmicrosoft%5Fcom%2FDocuments%2Fstrangeloop%2Dbootstrap%2Dscripts%2Fsetup%5Fstrangeloop%2Eps1" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

That's it! The script will:
- ✅ Download the latest setup scripts
- ✅ Check prerequisites (Git, Azure CLI, Git LFS)
- ✅ Set up Azure authentication
- ✅ Install StrangeLoop CLI
- ✅ Configure your development environment

## 📝 **What This Does**

1. **Downloads** the latest StrangeLoop setup launcher
2. **Automatically downloads** all required setup scripts
3. **Checks prerequisites** and installs missing tools
4. **Configures Azure** authentication and subscriptions
5. **Installs StrangeLoop** CLI if not already present
6. **Analyzes templates** and sets up your environment

## ⚙️ **Optional Parameters**

```powershell
# Skip prerequisites check (if you know everything is installed)
.\setup_strangeloop.ps1 -SkipPrerequisites

# Skip development tools installation
.\setup_strangeloop.ps1 -SkipDevelopmentTools

# Set Git user information
.\setup_strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@company.com"

# Combine options
.\setup_strangeloop.ps1 -SkipPrerequisites -UserName "Your Name"
```

## 🔄 **Always Up-to-Date**

The launcher downloads the latest scripts each time, so you always get:
- Latest bug fixes
- New features
- Updated prerequisites
- Current template library

## 🛠️ **Troubleshooting**

If the download fails, the script will automatically use local scripts if available. 

**Common issues:**
- **Network restrictions:** Try running from a different network
- **Execution policy:** Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **SharePoint access:** Ensure you can access Microsoft SharePoint

## 📞 **Support**

If you encounter issues, the script provides detailed error messages and troubleshooting steps.

---
**Ready to start building with StrangeLoop? Run the command above!** 🚀
