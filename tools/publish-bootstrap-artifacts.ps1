#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys strangeloop-bootstrap scripts for Azure DevOps Artifacts distribution

.DESCRIPTION
    This script creates a distributable package containing the strangeloop-bootstrap scripts
    and uploads them to Azure DevOps Artifacts as a Universal Package.
    
    The package includes:
    - setup-wrapper.ps1: PowerShell 5.1+ compatible entry point that ensures PowerShell 7
    - setup-wrapper.sh: Shell script entry point for Linux/WSL environments
    - core/main.ps1: Main setup orchestrator requiring PowerShell 7+
    - phases/ directory with all bootstrap phases and functionality
    - Version metadata

.PARAMETER Version
    Version number for the package (e.g., "0.0.1", "1.2.3-beta")
    If not specified, will auto-increment from the latest version in Azure DevOps Artifacts
    If no existing versions found, starts with "0.0.1"

.PARAMETER ForceStable
    When used with auto-generated versions, ensures the version format is stable
    This parameter is maintained for compatibility but auto-increment already produces stable versions

.PARAMETER Organization
    Azure DevOps organization URL (e.g., "https://dev.azure.com/yourorg")

.PARAMETER Project
    Azure DevOps project name

.PARAMETER Feed
    Azure DevOps Artifacts feed name

.PARAMETER PackageName
    Name of the universal package (default: "strangeloop-bootstrap")

.PARAMETER WhatIf
    Show what would be done without actually executing

.EXAMPLE
    .\deploy-artifacts.ps1 -Version "0.0.1"
    
    Deploy version 0.0.1 for default Azure DevOps configuration

.EXAMPLE
    .\deploy-artifacts.ps1
    
    Auto-increment from latest version in Azure DevOps (e.g., if latest is 0.0.5, deploys 0.0.6)

.EXAMPLE
    .\deploy-artifacts.ps1 -Organization "https://dev.azure.com/microsoft" -Project "strangeloop" -Feed "bootstrap-feed"
    
    Auto-increment version with custom Azure DevOps configuration
#>

[CmdletBinding()]
param(
    [string]$Version,
    [switch]$ForceStable,
    [string]$Organization = "https://msasg.visualstudio.com/",
    [string]$Project = "Bing_Ads", 
    [string]$Feed = "strangeloop",
    [string]$PackageName = "strangeloop-bootstrap",
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import shared bootstrap functions
$BootstrapRoot = Split-Path $PSScriptRoot -Parent
$LibPath = Join-Path $BootstrapRoot "lib"

# Import common write functions
. (Join-Path $LibPath "display\write-functions.ps1")

# Import display functions for banner
. (Join-Path $LibPath "display\display-functions.ps1")

# Display banner using shared function
Show-Banner -Title "strangeloop Bootstrap - Azure Artifacts Deployer" -Description "Package and deploy bootstrap scripts to Azure DevOps Artifacts"

function Get-LatestPackageVersion {
    <#
    .SYNOPSIS
        Gets the latest version of the package from Azure DevOps Artifacts
    
    .OUTPUTS
        String containing the latest version number, or $null if package doesn't exist
    #>
    param(
        [string]$Organization,
        [string]$Project,
        [string]$Feed,
        [string]$PackageName
    )
    
    try {
        Write-Info "Checking for existing package versions..."
        
        # List all versions of the package
        $versions = az artifacts universal package list --organization $Organization --project $Project --scope project --feed $Feed --query "[?name=='$PackageName'].versions[].version" -o tsv 2>$null
        
        if ($LASTEXITCODE -ne 0 -or -not $versions) {
            Write-Info "No existing versions found for package '$PackageName'"
            return $null
        }
        
        # Parse and sort versions
        $versionObjects = @()
        foreach ($ver in $versions) {
            if ($ver -match '^(\d+)\.(\d+)\.(\d+)') {
                $versionObjects += [PSCustomObject]@{
                    Original = $ver
                    Major = [int]$matches[1]
                    Minor = [int]$matches[2]
                    Patch = [int]$matches[3]
                }
            }
        }
        
        if ($versionObjects.Count -eq 0) {
            Write-Info "No valid semantic versions found"
            return $null
        }
        
        # Sort by Major.Minor.Patch and get the latest
        $latest = $versionObjects | Sort-Object Major, Minor, Patch | Select-Object -Last 1
        Write-Info "Latest version found: $($latest.Original)"
        return $latest.Original
        
    } catch {
        Write-Warning "Error checking for latest version: $($_.Exception.Message)"
        return $null
    }
}

function Get-NextVersion {
    <#
    .SYNOPSIS
        Increments the patch version of a semantic version string
    
    .PARAMETER CurrentVersion
        The current version string (e.g., "0.0.1")
    
    .OUTPUTS
        String containing the next version (e.g., "0.0.2")
    #>
    param(
        [string]$CurrentVersion
    )
    
    if ($CurrentVersion -match '^(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3] + 1
        return "$major.$minor.$patch"
    } else {
        throw "Invalid version format: $CurrentVersion"
    }
}

function Get-ConfigVersion {
    <#
    .SYNOPSIS
        Reads the version from the bootstrap_config.yaml file
    
    .OUTPUTS
        String containing the version from config file, or $null if not found
    #>
    
    $configPath = Join-Path $PSScriptRoot "..\config\bootstrap_config.yaml"
    
    if (-not (Test-Path $configPath)) {
        Write-Warning "Config file not found: $configPath"
        return $null
    }
    
    try {
        Write-Info "Reading version from config file: $configPath"
        $configContent = Get-Content $configPath -Raw
        
        # Simple YAML parsing for version - look for bootstrap_script.version
        if ($configContent -match 'bootstrap_script:\s*\r?\n\s*version:\s*["\'']*([0-9]+\.[0-9]+\.[0-9]+)["\'']*') {
            $configVersion = $matches[1]
            Write-Info "Found version in config: $configVersion"
            return $configVersion
        } else {
            Write-Warning "Could not parse version from config file"
            return $null
        }
    } catch {
        Write-Warning "Error reading config file: $($_.Exception.Message)"
        return $null
    }
}

# Determine version if not provided
if (-not $Version) {
    Write-Header "Determining Version"
    
    # First try to get version from config file
    $configVersion = Get-ConfigVersion
    
    if ($configVersion) {
        # Check if this config version already exists in Azure DevOps
        Write-Info "Checking if config version $configVersion already exists in Azure DevOps..."
        $latestVersion = Get-LatestPackageVersion -Organization $Organization -Project $Project -Feed $Feed -PackageName $PackageName
        
        if ($latestVersion -and $latestVersion -eq $configVersion) {
            Write-Warning "Config version $configVersion already exists in Azure DevOps"
            Write-Info "Auto-incrementing from config version..."
            try {
                $Version = Get-NextVersion -CurrentVersion $configVersion
                Write-Info "Auto-incremented version from config $configVersion to $Version"
            } catch {
                Write-Warning "Failed to increment config version '$configVersion': $($_.Exception.Message)"
                $Version = "0.0.1"
            }
        } else {
            # Use config version as it doesn't exist yet
            $Version = $configVersion
            Write-Info "Using version from config file: $Version"
        }
    } else {
        # Fallback to Azure DevOps auto-increment logic
        Write-Info "Config version not available, checking Azure DevOps for latest version..."
        $latestVersion = Get-LatestPackageVersion -Organization $Organization -Project $Project -Feed $Feed -PackageName $PackageName
        
        if ($latestVersion) {
            try {
                $Version = Get-NextVersion -CurrentVersion $latestVersion
                Write-Info "Auto-incremented version from Azure DevOps $latestVersion to $Version"
            } catch {
                Write-Warning "Failed to increment version '$latestVersion': $($_.Exception.Message)"
                Write-Info "Falling back to default versioning"
                $Version = "0.0.1"
            }
        } else {
            # No existing package, start with 0.0.1
            $Version = "0.0.1"
            Write-Info "No existing package found, starting with version: $Version"
        }
    }
    
    if ($ForceStable) {
        Write-Info "Using auto-generated stable version: $Version (enables wildcard downloads)"
    } else {
        Write-Info "Using determined version: $Version"
    }
} else {
    Write-Info "Using provided version: $Version"
}

# Validate Azure CLI
Write-Header "Validating Prerequisites"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is required but not found"
    Write-Info "Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check Azure CLI authentication
try {
    $account = az account show --query "user.name" -o tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and $account) {
        Write-Success "Azure CLI authenticated as: $account"
    } else {
        Write-Error "Azure CLI not authenticated"
        Write-Info "Run: az login"
        exit 1
    }
} catch {
    Write-Error "Azure CLI authentication check failed"
    exit 1
}

# Check for Azure DevOps extension
try {
    az extension show --name azure-devops >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Installing Azure DevOps CLI extension..."
        az extension add --name azure-devops
        Write-Success "Azure DevOps extension installed"
    } else {
        Write-Success "Azure DevOps extension available"
    }
} catch {
    Write-Error "Failed to install Azure DevOps extension"
    exit 1
}

# Set working directory to bootstrap root
Write-Header "Setting Working Directory"

$bootstrapRoot = Split-Path $PSScriptRoot -Parent
Write-Info "Changing to bootstrap directory: $bootstrapRoot"
Push-Location $bootstrapRoot

try {
    # Validate source files
    Write-Header "Validating Source Files"

$requiredFiles = @(
    "entry-points/setup-wrapper.ps1",
    "entry-points/setup-wrapper.sh", 
    "core",
    "phases",
    "lib",
    "config",
    "tools"
)

$missingFiles = @()
foreach ($item in $requiredFiles) {
    if (-not (Test-Path $item)) {
        $missingFiles += $item
    } else {
        if (Test-Path $item -PathType Container) {
            Write-Success "Found directory: $item"
        } else {
            Write-Success "Found file: $item"
        }
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Error "Missing required items:"
    foreach ($item in $missingFiles) {
        Write-Error "  - $item"
    }
    exit 1
}

# Create temporary package directory
Write-Header "Creating Package"

$packageDir = Join-Path $env:TEMP "strangeloop-bootstrap-package-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Info "Package directory: $packageDir"

if ($WhatIf) {
    Write-Info "Would create package directory: $packageDir"
} else {
    New-Item -Path $packageDir -ItemType Directory -Force | Out-Null
    Write-Success "Created package directories"
}

# Copy files to package directory
Write-Info "Copying items to package..."

$itemsToCopy = @{
    "entry-points/setup-wrapper.ps1" = "entry-points/setup-wrapper.ps1"
    "entry-points/setup-wrapper.sh" = "entry-points/setup-wrapper.sh"
    "core" = "core"
    "phases" = "phases"
    "lib" = "lib"
    "config" = "config"
    "tools/uninstall-all-tools.ps1" = "tools/uninstall-all-tools.ps1"
    "hash.txt" = "hash.txt"
}

if ($WhatIf) {
    foreach ($source in $itemsToCopy.Keys) {
        $dest = $itemsToCopy[$source]
        if (Test-Path $source -PathType Container) {
            Write-Info "Would copy directory: $source -> bootstrap/$dest (recursive)"
        } else {
            Write-Info "Would copy file: $source -> bootstrap/$dest"
        }
    }
} else {
    foreach ($source in $itemsToCopy.Keys) {
        $dest = $itemsToCopy[$source]
        $destPath = Join-Path $packageDir $dest
        
        if (Test-Path $source) {
            # Ensure destination directory exists
            $destParent = Split-Path $destPath -Parent
            if (-not (Test-Path $destParent)) {
                New-Item -Path $destParent -ItemType Directory -Force | Out-Null
            }
            
            if (Test-Path $source -PathType Container) {
                # Copy directory recursively
                Copy-Item $source $destPath -Recurse -Force
                Write-Success "Copied directory: $dest (with all subdirectories)"
            } else {
                # Copy single file
                Copy-Item $source $destPath
                Write-Success "Copied file: $dest"
            }
        } else {
            Write-Warning "Skipped missing item: $source"
        }
    }
}

# Create package metadata
$metadata = @{
    PackageName = $PackageName
    Version = $Version
    CreatedDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    CreatedBy = $env:USERNAME
    Repository = "ai-microsoft/strangeloop-bootstrap"
    Contents = @{
        Scripts = @{
            EntryPoints = @("entry-points/setup-wrapper.ps1", "entry-points/setup-wrapper.sh")
            Core = @("core/main.ps1", "core/phase-orchestrator.ps1", "core/config.ps1", "core/phase-wrappers.ps1")
            Phases = @(
                "phases/01-core-prerequisites", 
                "phases/02-environment-setup",
                "phases/03-project-bootstrap",
                "phases/shared"
            )
            Libraries = @(
                "lib/auth", 
                "lib/display", 
                "lib/linux",
                "lib/package",
                "lib/platform", 
                "lib/pwsh",
                "lib/validation", 
                "lib/version"
            )
            Tools = @("tools/uninstall-all-tools.ps1", "tools/publish-bootstrap-artifacts.ps1")
            Configuration = @("config/bootstrap_config.yaml")
            Metadata = @("hash.txt")
        }
        Documentation = @("package-info.json", "USAGE.md")
    }
    Usage = @{
        DirectSetup = "az artifacts universal download ... ; .\entry-points\setup-wrapper.ps1"
        LinuxSetup = "az artifacts universal download ... ; ./entry-points/setup-wrapper.sh"
        WithLoopName = ".\entry-points\setup-wrapper.ps1 -LoopName 'python-mcp-server' -ProjectName 'MyApp'"
        CoreOnly = ".\entry-points\setup-wrapper.ps1 -Mode core"
        EnvironmentOnly = ".\entry-points\setup-wrapper.ps1 -Mode environment"
        ProjectOnly = ".\entry-points\setup-wrapper.ps1 -Mode bootstrap"
        NoWSL = ".\entry-points\setup-wrapper.ps1 -NoWSL"
        CheckMode = ".\entry-points\setup-wrapper.ps1 -CheckOnly"
        PreviewMode = ".\entry-points\setup-wrapper.ps1 -WhatIf"
        FromPhase = ".\entry-points\setup-wrapper.ps1 -StartFromPhase 2"
        SpecificStage = ".\entry-points\setup-wrapper.ps1 -OnlyStage tools"
        UninstallTools = ".\tools\uninstall-all-tools.ps1 All -SkipConfirmation"
    }
    Description = "Complete strangeloop-bootstrap package with all scripts and modules"
} | ConvertTo-Json -Depth 10

if ($WhatIf) {
    Write-Info "Would create metadata file with content:"
    Write-Host $metadata -ForegroundColor Gray
} else {
    $metadataPath = Join-Path $packageDir "package-info.json"
    $metadata | Out-File -FilePath $metadataPath -Encoding utf8
    Write-Success "Created package metadata"
}

# Create usage instructions
$usageInstructions = @"
# strangeloop Bootstrap Scripts Package

This package contains the complete strangeloop-bootstrap system with setup wrapper and all modules.

## Quick Start

### Download Complete Package
``````powershell
# Download complete package (includes all scripts and modules)
az artifacts universal download --organization "$Organization" --project "$Project" --scope project --feed "$Feed" --name "$PackageName" --version "$Version" --path "."

# Option 1: Run setup wrapper (PowerShell 5.1+ compatible)
.\entry-points\setup-wrapper.ps1

# Option 2: Run shell wrapper (for Linux/WSL environments)  
./entry-points/setup-wrapper.sh

# Option 3: Run with full mode explicitly (requires PowerShell 7+)
.\entry-points\setup-wrapper.ps1 -Mode full
``````

## Advanced Usage

### With Custom Parameters
``````powershell
# Setup with specific loop and project
.\entry-points\setup-wrapper.ps1 -LoopName "python-mcp-server" -ProjectName "MyApp" -ProjectPath "C:\Projects"

# Setup from Linux/WSL
./entry-points/setup-wrapper.sh -LoopName "python-mcp-server" -ProjectName "MyApp" -ProjectPath "/projects"

# Setup without WSL (Windows-only development)
.\entry-points\setup-wrapper.ps1 -NoWSL

# Core prerequisites only (Azure CLI + strangeloop CLI)
.\entry-points\setup-wrapper.ps1 -Mode core

# Environment setup only (Git, Docker, Python, etc.)
.\entry-points\setup-wrapper.ps1 -Mode environment

# Project bootstrap only (assumes environment ready)
.\entry-points\setup-wrapper.ps1 -Mode bootstrap

# Start from specific phase
.\entry-points\setup-wrapper.ps1 -StartFromPhase 2

# Start from specific stage within Phase 3
.\entry-points\setup-wrapper.ps1 -StartFromStage selection

# Run only specific stage within Phase 3
.\entry-points\setup-wrapper.ps1 -OnlyStage tools

# Skip specific stages
.\entry-points\setup-wrapper.ps1 -SkipStages "wsl","pipelines"

# Check mode (validate without changes)
.\entry-points\setup-wrapper.ps1 -CheckOnly

# Preview mode (show what would be done)
.\entry-points\setup-wrapper.ps1 -WhatIf

# Uninstall all development tools
.\tools\uninstall-all-tools.ps1 All -SkipConfirmation
``````

        ### Offline Usage
Once downloaded, the complete package works offline:
``````powershell
# No internet required after download
.\entry-points\setup-wrapper.ps1 -LoopName "python-mcp-server" -ProjectName "offline-project"
``````

## Package Contents

### 📁 Complete Directory Structure
- **Entry Points**: 
  - entry-points/setup-wrapper.ps1 (PowerShell 5.1+ compatible entry point)
  - entry-points/setup-wrapper.sh (Shell script entry point for Linux/WSL)
- **Core**: 
  - core/main.ps1 (PowerShell 7+ main setup orchestrator)
  - core/phase-orchestrator.ps1 (Phase execution coordination)
  - core/config.ps1 (Configuration management)
  - core/phase-wrappers.ps1 (Phase wrapper functions)
- **Configuration**: config/bootstrap_config.yaml (Bootstrap configuration)
- **Phase 1**: phases/01-core-prerequisites/ (Azure CLI, strangeloop CLI)
- **Phase 2**: phases/02-environment-setup/ (Git, Docker, Python, Poetry, WSL, Git LFS)
- **Phase 3**: phases/03-project-bootstrap/ (Loop selection, project creation, development tools)
- **Libraries**: 
  - lib/auth/ (Authentication utilities)
  - lib/display/ (Display and output functions)
  - lib/linux/ (Linux-specific utilities)
  - lib/package/ (Package management)
  - lib/platform/ (Platform detection and functions)
  - lib/pwsh/ (PowerShell installation)
  - lib/validation/ (Validation and testing functions)
  - lib/version/ (Version management)
- **Shared Functions**: phases/shared/ (Common phase utilities)
- **Tools**: 
  - tools/uninstall-all-tools.ps1 (Uninstall development tools)
  - tools/publish-bootstrap-artifacts.ps1 (Package publishing script)
- **Metadata**: hash.txt (Package integrity hash)### 🎯 Benefits of Complete Package
- ✅ **Cross-Platform**: Windows (PowerShell) and Linux/WSL (Shell) entry points
- ✅ **Self-Contained**: No additional downloads required
- ✅ **Offline Capable**: Works in air-gapped environments
- ✅ **Version Consistent**: All components guaranteed compatible
- ✅ **PowerShell 5.1+ Compatible**: Setup wrapper ensures PowerShell 7 availability
- ✅ **Enterprise Ready**: Single package for IT approval

## Package Information
- **Version**: $Version
- **Created**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Repository**: ai-microsoft/strangeloop-bootstrap
- **Organization**: $Organization
- **Project**: $Project
- **Feed**: $Feed

## Support
For questions or issues:
- **Feed URL**: $Organization$Project/_packaging?_a=feed&feed=$Feed
- **Repository**: https://dev.azure.com/ai-microsoft/strangeloop-bootstrap

"@

if ($WhatIf) {
    Write-Info "Would create USAGE.md with instructions"
} else {
    $usagePath = Join-Path $packageDir "USAGE.md"
    $usageInstructions | Out-File -FilePath $usagePath -Encoding utf8
    Write-Success "Created usage instructions"
}

# Validate Azure DevOps connectivity
Write-Header "Validating Azure DevOps Access"

if ($WhatIf) {
    Write-Info "Would validate access to: $Organization"
    Write-Info "Would validate project: $Project"
    Write-Info "Would validate feed: $Feed"
} else {
    try {
        # Test organization access
        $projects = az devops project list --organization $Organization --query "value[].name" -o tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Cannot access Azure DevOps organization: $Organization"
            Write-Info "Verify the organization URL and your permissions"
            exit 1
        }
        Write-Success "Organization access validated"
        
        # Test project access
        if ($projects -notcontains $Project) {
            Write-Warning "Project '$Project' not found in organization"
            Write-Info "Available projects: $($projects -join ', ')"
            Write-Info "The project will be created if it doesn't exist"
        } else {
            Write-Success "Project access validated"
        }
        
        # Test feed access (may not exist yet)
        try {
            az artifacts universal package list --organization $Organization --project $Project --scope project --feed $Feed >$null 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Feed access validated"
            } else {
                Write-Info "Feed '$Feed' not found - will be created during publish"
            }
        } catch {
            Write-Info "Feed '$Feed' not found - will be created during publish"
        }
        
    } catch {
        Write-Error "Azure DevOps validation failed: $($_.Exception.Message)"
        exit 1
    }
}

# Publish to Azure DevOps Artifacts
Write-Header "Publishing to Azure Artifacts"

if ($WhatIf) {
    Write-Info "Would publish package with the following command:"
    Write-Host "az artifacts universal publish --organization `"$Organization`" --project `"$Project`" --scope project --feed `"$Feed`" --name `"$PackageName`" --version `"$Version`" --path `"$packageDir`"" -ForegroundColor Gray
} else {
    try {
        Write-Info "Publishing package to Azure DevOps Artifacts..."
        Write-Info "  Organization: $Organization"
        Write-Info "  Project: $Project"
        Write-Info "  Feed: $Feed"
        Write-Info "  Package: $PackageName"
        Write-Info "  Version: $Version"
        
        $publishArgs = @(
            "artifacts", "universal", "publish"
            "--organization", $Organization
            "--project", $Project
            "--scope", "project"
            "--feed", $Feed
            "--name", $PackageName
            "--version", $Version
            "--description", "strangeloop Bootstrap CLI"
            "--path", $packageDir
        )
        
        $result = & az @publishArgs 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Package published successfully!"
        } else {
            Write-Error "Package publication failed:"
            # Output the detailed error results
            foreach ($line in ($result -split "`n")) {
                if (![string]::IsNullOrWhiteSpace($line)) {
                    Write-Error "  $line"
                }
            }
            exit 1
        }
        
    } catch {
        Write-Error "Publication failed: $($_.Exception.Message)"
        exit 1
    }
}

# Generate download URLs and instructions
Write-Header "Package Publication Complete"

# Create completion summary
$publishResults = @{
    "Package Name" = $PackageName
    "Version" = $Version
    "Organization" = $Organization
    "Project" = $Project
    "Feed" = $Feed
    "Artifacts Feed URL" = "$Organization$Project/_packaging?_a=feed&feed=$Feed"
}

Write-CompletionSummary -Results $publishResults -Title "Package Publication Summary"

Write-Info "🚀 USAGE COMMANDS"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Download Package:" -ForegroundColor Yellow
Write-Host "  az artifacts universal download --organization `"$Organization`" --project `"$Project`" --scope project --feed `"$Feed`" --name `"$PackageName`" --version `"$Version`" --path `".`"" -ForegroundColor Green
Write-Host ""
Write-Host "Setup Environment (PowerShell 5.1+ Compatible):" -ForegroundColor Yellow
Write-Host "  .\entry-points\setup-wrapper.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "Setup Environment (Linux/WSL):" -ForegroundColor Yellow
Write-Host "  ./entry-points/setup-wrapper.sh" -ForegroundColor Green
Write-Host ""
Write-Host "Setup Environment (PowerShell 7+ Direct):" -ForegroundColor Yellow
Write-Host "  .\entry-points\setup-wrapper.ps1 -Mode full" -ForegroundColor Green
Write-Host ""
Write-Host "Core Prerequisites Only:" -ForegroundColor Yellow  
Write-Host "  .\entry-points\setup-wrapper.ps1 -Mode core" -ForegroundColor Green
Write-Host ""
Write-Host "Environment Setup Only:" -ForegroundColor Yellow  
Write-Host "  .\entry-points\setup-wrapper.ps1 -Mode environment" -ForegroundColor Green
Write-Host ""
Write-Host "Project Bootstrap Only:" -ForegroundColor Yellow  
Write-Host "  .\entry-points\setup-wrapper.ps1 -Mode bootstrap" -ForegroundColor Green
Write-Host ""
Write-Host "Setup without WSL (Windows-only):" -ForegroundColor Yellow  
Write-Host "  .\entry-points\setup-wrapper.ps1 -NoWSL" -ForegroundColor Green
Write-Host ""
Write-Host "Uninstall All Tools:" -ForegroundColor Yellow  
Write-Host "  .\tools\uninstall-all-tools.ps1 All -SkipConfirmation" -ForegroundColor Green

# Cleanup
if (-not $WhatIf) {
    Write-Header "Cleaning Up"
    try {
        Remove-Item -Path $packageDir -Recurse -Force
        Write-Success "Cleaned up temporary files"
    } catch {
        Write-Warning "Could not clean up temporary directory: $packageDir"
    }
}

} finally {
    # Always restore the original directory
    Pop-Location
}

Write-Success "Package creation and publication completed successfully! 🎉"
