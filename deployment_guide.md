# StrangeLoop Standalone Setup Deployment Guide

## For Repository Owners

### 1. Upload Scripts to Azure DevOps

Make sure your Azure DevOps repository has this structure:
```
strangeloop-bootstrap/
├── setup_strangeloop.ps1                 # Standalone launcher
├── setup_strangeloop_main.ps1            # Main orchestrator
├── setup_strangeloop_linux.ps1           # Linux/WSL setup
├── setup_strangeloop_windows.ps1         # Windows setup
└── [documentation and tools...]          # Additional files
```

### 2. Azure DevOps Raw File URLs

For Azure DevOps repositories, the raw file URLs follow this pattern:
```
https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/SCRIPT-NAME.ps1&version=GBstrangeloop-bootstrap&download=true
```

### 3. Test the Setup

```powershell
# Test with Azure DevOps repository
.\setup_strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap&version=GBstrangeloop-bootstrap"
```

## For End Users

### Quick Installation

#### Option 1: Download and Run
```powershell
# Download the launcher
Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"

# Run the setup
.\setup_strangeloop.ps1
```

#### Option 2: One-Line Installation
```powershell
Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -OutFile "setup_strangeloop.ps1"; .\setup_strangeloop.ps1
```

#### Option 3: Direct Execution (Advanced)
```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers?path=/strangeloop-bootstrap/setup_strangeloop.ps1&version=GBstrangeloop-bootstrap&download=true" -UseBasicParsing).Content
```

### Custom Options

```powershell
# Skip components
.\setup-strangeloop.ps1 -SkipPrerequisites -SkipDevelopmentTools

# Set user information
.\setup-strangeloop.ps1 -UserName "Your Name" -UserEmail "your.email@domain.com"

# Use different repository/branch
.\setup-strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers/items?path=/strangeloop-bootstrap&version=GBother-branch"
```

## Enterprise Deployment

### Internal Microsoft Deployment

1. **Azure DevOps (Current Setup):**
   ```powershell
   # Using the official AdsSnR repository
   .\setup-strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers/items?path=/strangeloop-bootstrap/scripts&version=GBstrangeloop-bootstrap"
   ```

2. **Alternative Internal Hosting:**
   ```powershell
   # Upload to internal SharePoint/file server
   .\setup-strangeloop.ps1 -BaseUrl "https://microsoft.sharepoint.com/teams/yourteam/scripts"
   
   # Use different Azure DevOps project
   .\setup-strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/YourProject/_git/YourRepo/items?path=/scripts&version=GBmain"
   ```

### Group Policy Deployment

Create a Group Policy script that:
1. Downloads the launcher to user's temp directory
2. Executes with predefined parameters
3. Cleans up after completion

### SCCM/Intune Deployment

Package the launcher script with:
1. Predefined BaseUrl pointing to internal repository
2. Silent execution parameters
3. Logging for deployment tracking

## Maintenance

### Updating Scripts

1. Update scripts in your repository
2. Users automatically get latest version on next run
3. No need to redistribute - launcher always downloads fresh copies

### Version Control

Consider using different branches for releases:
```powershell
# Use specific branch
.\setup-strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers/items?path=/strangeloop-bootstrap/scripts&version=GBrelease-v1.2.0"

# Use main/develop branch
.\setup-strangeloop.ps1 -BaseUrl "https://msasg.visualstudio.com/Bing_Ads/_git/AdsSnR_Containers/items?path=/strangeloop-bootstrap/scripts&version=GBdevelop"
```

### Monitoring

Track usage through:
- Azure DevOps repository insights
- Internal telemetry if added to scripts
- Corporate network logs (for internal hosting)
