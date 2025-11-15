# strangeloop Bootstrap - Package Manager Module
# Version: 1.0.0
# Provides centralized package management with update tracking

# Import required modules once at module level
$BootstrapRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"

# Import display functions
if (-not (Get-Command "Write-Info" -ErrorAction SilentlyContinue)) {
    . (Join-Path $LibPath "display\write-functions.ps1")
}

# Import sudo authentication module
$AuthPath = Join-Path $LibPath "auth\linux-sudo.ps1"
if (-not (Get-Command "Invoke-SudoCommand" -ErrorAction SilentlyContinue)) {
    . $AuthPath
}

# Global variable to track if package lists have been updated in this session
$Global:AptUpdateCompleted = $false

function Invoke-AptUpdate {
    <#
    .SYNOPSIS
    Ensures apt package lists are updated, but only once per session
    
    .DESCRIPTION
    Runs 'apt update' only if it hasn't been run already in this session.
    This prevents redundant package list updates across multiple tool installations.
    
    .PARAMETER Force
    Force update even if already completed in this session
    
    .PARAMETER WSLMode
    Execute in WSL context
    
    .PARAMETER DistributionName
    Specific WSL distribution to use
    
    .OUTPUTS
    Boolean indicating success of the update operation
    #>
    param(
        [switch]$Force,
        [switch]$WSLMode,
        [string]$DistributionName
    )
    
    try {
        # Check if update already completed and not forcing
        if ($Global:AptUpdateCompleted -and (-not $Force)) {
            Write-Info "Package lists already updated in this session, skipping apt update"
            return $true
        }
        
        Write-Info "Updating package lists..."
        
        # Run apt update (authentication module already imported at module level)
        $updateResult = Invoke-SudoCommand -Command "apt update" -WSLMode:$WSLMode -DistributionName $DistributionName
        
        if ($updateResult.Success) {
            $Global:AptUpdateCompleted = $true
            Write-Success "Package lists updated successfully"
            return $true
        } else {
            Write-Warning "Package update had issues: $($updateResult.Output)"
            return $false
        }
        
    } catch {
        Write-Warning "Error updating package lists: $($_.Exception.Message)"
        return $false
    }
}

function Reset-AptUpdateStatus {
    <#
    .SYNOPSIS
    Resets the apt update status, forcing next update to run
    
    .DESCRIPTION
    Useful for testing or when you want to force a fresh package list update
    #>
    
    $Global:AptUpdateCompleted = $false
    Write-Info "Apt update status reset - next update will run"
}

function Test-AptUpdateStatus {
    <#
    .SYNOPSIS
    Returns whether apt update has been completed in this session
    
    .OUTPUTS
    Boolean indicating if apt update has been completed
    #>
    
    return $Global:AptUpdateCompleted
}

function Install-BaseLinuxPackages {
    <#
    .SYNOPSIS
    Installs base development packages needed for tool installation in WSL
    
    .DESCRIPTION
    Installs essential packages like apt-transport-https, curl, software-properties-common,
    pipx, and other prerequisites needed by development tool routers
    
    .PARAMETER DistributionName
    Name of the WSL distribution to install packages in (only used when WSLMode is true)
    
    .PARAMETER WSLMode
    Execute in WSL context from Windows host
    
    .PARAMETER Force
    Force reinstallation of packages even if they appear to be installed
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [string]$DistributionName,
        [switch]$WSLMode,
        [switch]$Force
    )
    
    try {
        # Detect execution context
        $isRunningInWSL = Test-Path /proc/version -ErrorAction SilentlyContinue
        
        # Determine execution mode and validate parameters
        if ($WSLMode -and $isRunningInWSL) {
            Write-Warning "WSLMode specified but already running inside WSL - will execute directly"
            $useWSLMode = $false
        } elseif ($WSLMode -and -not $isRunningInWSL) {
            $useWSLMode = $true
            if ([string]::IsNullOrWhiteSpace($DistributionName)) {
                Write-Warning "WSLMode requires DistributionName parameter"
                return $false
            }
        } else {
            $useWSLMode = $false
        }
        
        # Display execution context
        if ($useWSLMode) {
            Write-Info "Installing base development packages in WSL distribution: $DistributionName"
        } elseif ($isRunningInWSL) {
            Write-Info "Installing base development packages (running inside WSL)"
        } else {
            Write-Info "Installing base development packages (direct execution)"
        }
        
        # Install essential base packages using sudo authentication
        Write-Info "Checking and installing essential development packages..."
        $basePackages = @(
            "curl",
            "wget", 
            "gnupg",
            "lsb-release",
            "ca-certificates",
            "apt-transport-https",
            "software-properties-common",
            "build-essential",
            "python3-pip",
            "python3-venv",
            "pipx"
        )
        
        # Check which packages are already installed
        Write-Info "Checking package installation status..."
        $packagesToInstall = @()
        
        foreach ($package in $basePackages) {
            if ($useWSLMode) {
                $checkResult = wsl -d $DistributionName -- bash -c "dpkg -l $package 2>/dev/null | grep '^ii'" 2>$null
            } else {
                $checkResult = bash -c "dpkg -l $package 2>/dev/null | grep '^ii'" 2>$null
            }
            
            if ($checkResult -and -not $Force) {
                Write-Info "✓ $package is already installed"
            } else {
                if ($Force -and $checkResult) {
                    Write-Info "◦ $package will be reinstalled (forced)"
                } else {
                    Write-Info "◦ $package needs to be installed"
                }
                $packagesToInstall += $package
            }
        }
        
        if ($packagesToInstall.Count -eq 0) {
            Write-Success "All base packages are already installed"
            
            # Still ensure pipx is properly set up
            Write-Info "Configuring pipx..."
            if ($useWSLMode) {
                $pipxSetupResult = wsl -d $DistributionName -- bash -c "pipx ensurepath" 2>&1
            } else {
                $pipxSetupResult = bash -c "pipx ensurepath" 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Info "pipx ensurepath had issues (this is normal on first run): $pipxSetupResult"
            }
            
            Write-Success "Base WSL development packages verification completed"
            return $true
        }
        
        # Update package lists using centralized function before installing
        if ($useWSLMode) {
            Invoke-AptUpdate -WSLMode -DistributionName $DistributionName
        } else {
            Invoke-AptUpdate
        }
        
        # Install only the packages that are missing
        $packageList = $packagesToInstall -join " "
        Write-Info "Installing missing packages: $packageList"
        
        if ($useWSLMode) {
            $installResult = Invoke-SudoCommand -Command "apt install -y $packageList" -WSLMode -DistributionName $DistributionName
        } else {
            $installResult = Invoke-SudoCommand -Command "apt install -y $packageList"
        }
        
        if (-not $installResult.Success) {
            Write-Warning "Some packages failed to install: $($installResult.Output)"
            
            # Try installing core packages individually
            Write-Info "Attempting individual package installation for critical packages..."
            $corePackages = @("curl", "wget", "python3-pip", "python3-venv")
            $criticalPackagesToInstall = $packagesToInstall | Where-Object { $_ -in $corePackages }
            
            foreach ($package in $criticalPackagesToInstall) {
                Write-Info "Installing $package individually..."
                if ($useWSLMode) {
                    $result = Invoke-SudoCommand -Command "apt install -y $package" -WSLMode -DistributionName $DistributionName
                } else {
                    $result = Invoke-SudoCommand -Command "apt install -y $package"
                }
                
                if ($result.Success) {
                    Write-Info "✓ $package installed successfully"
                } else {
                    Write-Warning "✗ $package installation failed: $($result.Output)"
                }
            }
        } else {
            Write-Success "Missing packages installed successfully"
        }
        
        # Ensure pipx is properly set up
        Write-Info "Configuring pipx..."
        if ($useWSLMode) {
            $pipxSetupResult = wsl -d $DistributionName -- bash -c "pipx ensurepath" 2>&1
        } else {
            $pipxSetupResult = bash -c "pipx ensurepath" 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Info "pipx ensurepath had issues (this is normal on first run): $pipxSetupResult"
        }
        
        Write-Success "Base WSL development packages installation completed"
        return $true
        
    } catch {
        Write-Warning "Error installing base WSL packages: $($_.Exception.Message)"
        return $false
    }
}

# Export functions for use by other modules when imported as a module
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Install-BaseLinuxPackages'
    )
}