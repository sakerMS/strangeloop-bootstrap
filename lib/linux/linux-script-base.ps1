# Linux Script Base - Common functionality for Linux/WSL scripts
# Version: 1.0.0
# Purpose: Standardized base for all Linux scripts - assumes running inside Linux/WSL environment

<#
.SYNOPSIS
Common base functionality for Linux/WSL environment scripts

.DESCRIPTION
This script provides standardized functions and patterns for scripts that run
inside Linux/WSL environments. All execution context detection is handled by
the router - these scripts assume they are running in the target environment.

.NOTES
- Scripts using this base should run ONLY inside Linux/WSL
- Execution context detection is handled by the router script
- WSL distribution detection is handled by the calling Windows script
- All commands execute directly in the Linux environment
#>

# Import required modules
$BootstrapRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "auth\linux-sudo.ps1")
. (Join-Path $LibPath "package\package-manager.ps1")

function Initialize-LinuxScript {
    <#
    .SYNOPSIS
    Initialize a Linux script with standard validation
    
    .DESCRIPTION
    Performs standard initialization for Linux scripts including environment validation
    
    .PARAMETER ScriptName
    Name of the script for logging purposes
    
    .PARAMETER RequiredTools
    Array of tools that must be available (will use Test-Command to validate)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        
        [string[]]$RequiredTools = @()
    )
    
    Write-Step "Initializing $ScriptName (Linux/WSL)..."
    
    # Validate we're in a Linux environment
    if (-not (Test-Path "/proc/version")) {
        Write-Error "This script must run inside a Linux/WSL environment"
        return $false
    }
    
    # Validate required tools
    foreach ($tool in $RequiredTools) {
        if (-not (Test-Command $tool)) {
            Write-Warning "Required tool '$tool' not found"
            return $false
        }
    }
    
    Write-Info "$ScriptName initialized successfully in Linux environment"
    return $true
}

function Invoke-LinuxPackageInstall {
    <#
    .SYNOPSIS
    Install packages using the Linux package manager
    
    .DESCRIPTION
    Standardized package installation for Linux environments
    
    .PARAMETER Packages
    Array of package names to install
    
    .PARAMETER UpdateFirst
    Whether to update package lists first (default: true)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Packages,
        
        [bool]$UpdateFirst = $true
    )
    
    try {
        if ($UpdateFirst) {
            Write-Info "Updating package lists..."
            $updateResult = Install-BaseLinuxPackages
            if (-not $updateResult) {
                Write-Warning "Package list update had issues, continuing with installation..."
            }
        }
        
        foreach ($package in $Packages) {
            Write-Info "Installing package: $package"
            $installResult = Invoke-SudoCommand -Command "apt install -y $package"
            if (-not $installResult.Success) {
                Write-Error "Failed to install package '$package': $($installResult.Output)"
                return $false
            }
        }
        
        Write-Success "All packages installed successfully: $($Packages -join ', ')"
        return $true
        
    } catch {
        Write-Error "Package installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-LinuxToolVersion {
    <#
    .SYNOPSIS
    Test if a Linux tool meets version requirements
    
    .DESCRIPTION
    Standardized version testing for Linux tools
    
    .PARAMETER ToolName
    Name of the tool for compliance checking
    
    .PARAMETER VersionCommand
    Command to get the version (e.g., "git --version")
    
    .PARAMETER VersionRegex
    Regex to extract version from command output
    
    .PARAMETER Detailed
    Whether to show detailed compliance information
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        
        [Parameter(Mandatory = $true)]
        [string]$VersionCommand,
        
        [Parameter(Mandatory = $true)]
        [string]$VersionRegex,
        
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing $ToolName installation..."
        
        # Execute the version command directly in Linux
        $versionOutput = Invoke-Expression $VersionCommand 2>$null
        
        if (-not $versionOutput) {
            Write-Warning "$ToolName command not found"
            return $false
        }
        
        # Extract version using regex
        if ($versionOutput -match $VersionRegex) {
            $version = $matches[1]
            
            Write-Info "$ToolName found: $version"
            
            # Test version compliance
            $compliance = Test-ToolVersionCompliance -ToolName $ToolName.ToLower() -InstalledVersion $version
            Write-VersionComplianceReport -ToolName $ToolName -ComplianceResult $compliance
            
            if (-not $compliance.IsCompliant) {
                Write-Warning "$ToolName version $version does not meet minimum requirements"
                if ($Detailed) {
                    Write-Info "Action required: $($compliance.Action)"
                }
                return $false
            }
            
            Write-Success "$ToolName is properly installed and compliant: $version"
            return $true
        } else {
            Write-Warning "Could not parse $ToolName version from: $versionOutput"
            return $false
        }
        
    } catch {
        Write-Warning "Error testing $ToolName`: $($_.Exception.Message)"
        return $false
    }
}

function Set-LinuxEnvironmentVariable {
    <#
    .SYNOPSIS
    Set environment variable in Linux environment
    
    .DESCRIPTION
    Sets environment variables in the user's shell profile for persistence
    
    .PARAMETER Name
    Environment variable name
    
    .PARAMETER Value
    Environment variable value
    
    .PARAMETER Shell
    Target shell (bash, zsh, etc. - default: bash)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Value,
        
        [string]$Shell = "bash"
    )
    
    try {
        $profileFile = switch ($Shell) {
            "bash" { "~/.bashrc" }
            "zsh" { "~/.zshrc" }
            default { "~/.profile" }
        }
        
        # Check if variable is already set
        $existingVar = bash -c "grep '^export $Name=' $profileFile" 2>$null
        
        if ($existingVar) {
            Write-Info "Environment variable $Name is already set in $profileFile"
        } else {
            # Add the export statement
            $exportLine = "export $Name=$Value"
            bash -c "echo '$exportLine' >> $profileFile"
            
            # Also set for current session
            Set-Variable -Name $Name -Value $Value -Scope Global
            
            Write-Success "Environment variable $Name set in $profileFile"
        }
        
        return $true
        
    } catch {
        Write-Warning "Could not set environment variable $Name`: $($_.Exception.Message)"
        return $false
    }
}

function Add-LinuxPathEntry {
    <#
    .SYNOPSIS
    Add directory to Linux PATH
    
    .DESCRIPTION
    Adds a directory to the user's PATH in their shell profile
    
    .PARAMETER Directory
    Directory to add to PATH
    
    .PARAMETER Shell
    Target shell (bash, zsh, etc. - default: bash)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,
        
        [string]$Shell = "bash"
    )
    
    try {
        $profileFile = switch ($Shell) {
            "bash" { "~/.bashrc" }
            "zsh" { "~/.zshrc" }
            default { "~/.profile" }
        }
        
        # Check if directory is already in PATH
        $pathCheck = bash -c "grep 'export PATH.*$Directory' $profileFile" 2>$null
        
        if ($pathCheck) {
            Write-Info "Directory $Directory is already in PATH via $profileFile"
        } else {
            # Add the PATH export
            $pathLine = "export PATH=`"$Directory`:```$PATH`""
            bash -c "echo '$pathLine' >> $profileFile"
            
            # Also add to current session
            $env:PATH = "$Directory" + ":" + $env:PATH
            
            Write-Success "Added $Directory to PATH in $profileFile"
        }
        
        return $true
        
    } catch {
        Write-Warning "Could not add directory to PATH: $($_.Exception.Message)"
        return $false
    }
}

function Test-LinuxServiceStatus {
    <#
    .SYNOPSIS
    Test if a Linux service is running
    
    .DESCRIPTION
    Checks if a systemd service is active and running
    
    .PARAMETER ServiceName
    Name of the service to check
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )
    
    try {
        $serviceStatus = systemctl is-active $ServiceName 2>$null
        
        if ($serviceStatus -eq "active") {
            Write-Success "Service $ServiceName is running"
            return $true
        } else {
            Write-Info "Service $ServiceName is not active (status: $serviceStatus)"
            return $false
        }
        
    } catch {
        Write-Warning "Could not check service status for $ServiceName`: $($_.Exception.Message)"
        return $false
    }
}

function Start-LinuxService {
    <#
    .SYNOPSIS
    Start and enable a Linux service
    
    .DESCRIPTION
    Starts a systemd service and enables it for automatic startup
    
    .PARAMETER ServiceName
    Name of the service to start
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )
    
    try {
        Write-Info "Starting service: $ServiceName"
        $startResult = Invoke-SudoCommand -Command "systemctl start $ServiceName"
        
        if (-not $startResult.Success) {
            Write-Warning "Could not start service $ServiceName`: $($startResult.Output)"
            return $false
        }
        
        Write-Info "Enabling service: $ServiceName"
        $enableResult = Invoke-SudoCommand -Command "systemctl enable $ServiceName"
        
        if (-not $enableResult.Success) {
            Write-Warning "Could not enable service $ServiceName`: $($enableResult.Output)"
        }
        
        Write-Success "Service $ServiceName started and enabled"
        return $true
        
    } catch {
        Write-Error "Failed to start service $ServiceName`: $($_.Exception.Message)"
        return $false
    }
}

# Note: Functions are available for import when this script is dot-sourced