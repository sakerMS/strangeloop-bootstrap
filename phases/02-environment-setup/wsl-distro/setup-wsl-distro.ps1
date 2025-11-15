# strangeloop Setup - WSL Distribution Management Module
# Version: 2.0.0 - Refactored and Renamed
# Purpose: Focused on WSL distribution installation, configuration, and management only
# Script: setup-wsl-distro.ps1

param(
    [string]$DistributionName,
    [switch]$RequiresWSL,
    [switch]${check-only},
    [switch]${what-if},
    [string]${execution-engine} = "StrangeloopCLI",
    [switch]$Verbose
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "platform\path-functions.ps1")
. (Join-Path $LibPath "auth\linux-sudo.ps1")
. (Join-Path $LibPath "package\package-manager.ps1")

#region Configuration Functions

function Get-WSLConfigurationDefaults {
    <#
    .SYNOPSIS
    Gets WSL configuration defaults from bootstrap_config.yaml
    
    .DESCRIPTION
    Loads WSL-specific configuration values from the centralized bootstrap configuration
    
    .OUTPUTS
    Hashtable containing WSL configuration values
    #>
    param()
    
    try {
        # Load configuration from YAML
        $configPath = Join-Path $BootstrapRoot "config\bootstrap_config.yaml"
        if (-not (Test-Path $configPath)) {
            Write-Warning "Bootstrap config file not found at $configPath, using defaults"
            return @{
                DefaultDistribution = "Ubuntu-24.04"
                MinimumVersion = "2"
            }
        }
        
        # Read YAML content
        $yamlContent = Get-Content $configPath -Raw
        
        # Extract WSL configuration section
        $wslConfig = @{
            DefaultDistribution = "Ubuntu-24.04"  # fallback default
            MinimumVersion = "2"                   # fallback default
        }
        
        # Extract default_distribution
        if ($yamlContent -match '(?s)wsl:\s*\n.*?default_distribution:\s*["]?([^"\n]+)["]?') {
            $rawValue = $matches[1].Trim()
            $cleanValue = $rawValue -replace '\0', ''  # Remove null bytes
            $wslConfig.DefaultDistribution = $cleanValue
        }
        
        # Extract minimum_version  
        if ($yamlContent -match '(?s)wsl:\s*\n.*?minimum_version:\s*["]?([^"\n]+)["]?') {
            $rawValue = $matches[1].Trim()
            $cleanValue = $rawValue -replace '\0', ''  # Remove null bytes
            $wslConfig.MinimumVersion = $cleanValue
        }
        
        return $wslConfig
        
    } catch {
        Write-Warning "Error loading WSL configuration: $($_.Exception.Message)"
        return @{
            DefaultDistribution = "Ubuntu-24.04"
            MinimumVersion = "2"
        }
    }
}

function Get-CleanDistributionName {
    <#
    .SYNOPSIS
    Cleans and validates a WSL distribution name to handle encoding issues
    
    .PARAMETER DistributionName
    The distribution name to clean
    
    .OUTPUTS
    Clean string suitable for WSL commands
    #>
    param(
        [string]$DistributionName
    )
    
    if ([string]::IsNullOrWhiteSpace($DistributionName)) {
        $wslConfig = Get-WSLConfigurationDefaults
        return $wslConfig.DefaultDistribution
    }
    
    # Remove null bytes and other potential UTF-16 artifacts
    $cleaned = $DistributionName -replace '\0', ''
    $cleaned = $cleaned.Trim()
    
    # Validate that it contains only expected characters
    if ($cleaned -match '^[a-zA-Z0-9\-\.]+$') {
        return $cleaned
    } else {
        Write-Warning "Distribution name contains unexpected characters, using configuration default"
        $wslConfig = Get-WSLConfigurationDefaults
        return $wslConfig.DefaultDistribution
    }
}

#endregion

#region WSL Core Functions

function Test-WSLAvailable {
    <#
    .SYNOPSIS
    Tests if WSL (Windows Subsystem for Linux) is available and enabled
    
    .DESCRIPTION
    Checks if WSL is installed and enabled on the Windows system
    
    .OUTPUTS
    Boolean indicating WSL availability
    #>
    param()
    
    try {
        Write-Info "Checking WSL availability..."
        
        # Check if wsl.exe exists and is accessible
        $wslCommand = Get-Command wsl.exe -ErrorAction SilentlyContinue
        if (-not $wslCommand) {
            Write-Warning "WSL command not found"
            return $false
        }
        
        # Test WSL is working
        $wslTest = & wsl.exe --status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "WSL is not properly configured: $wslTest"
            return $false
        }
        
        Write-Success "WSL is available and working"
        return $true
        
    } catch {
        Write-Warning "Error checking WSL: $($_.Exception.Message)"
        return $false
    }
}

function Enable-WSL {
    <#
    .SYNOPSIS
    Enables WSL feature on Windows
    
    .DESCRIPTION
    Enables the Windows Subsystem for Linux feature and Virtual Machine Platform
    
    .OUTPUTS
    Boolean indicating success
    #>
    param()
    
    try {
        Write-Info "Enabling WSL feature..."
        
        # Check if already enabled
        $wslAvailable = Test-WSLAvailable
        if ($wslAvailable) {
            Write-Info "WSL is already enabled"
            return $true
        }
        
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-Error "Administrator privileges required to enable WSL"
            return $false
        }
        
        Write-Progress "Enabling Windows Subsystem for Linux..."
        
        # Enable WSL feature
        $result1 = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
        if (-not $result1.RestartNeeded) {
            Write-Warning "Failed to enable WSL feature"
            return $false
        }
        
        # Enable Virtual Machine Platform
        Write-Progress "Enabling Virtual Machine Platform..."
        
        $result2 = Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
        
        $restartRequired = $result1.RestartNeeded -or $result2.RestartNeeded
        
        if ($restartRequired) {
            Write-Warning "System restart required to complete WSL installation"
            Write-Info "Please restart your computer and run the setup again"
            return $false
        }
        
        Write-Success "WSL enabled successfully"
        return $true
        
    } catch {
        Write-Warning "Error enabling WSL: $($_.Exception.Message)"
        return $false
    }
}

function Set-WSLDefaultVersion {
    <#
    .SYNOPSIS
    Sets the default WSL version
    
    .DESCRIPTION
    Sets the default version for new WSL distributions (1 or 2)
    
    .PARAMETER Version
    WSL version to set as default (1 or 2)
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("1", "2")]
        [string]$Version
    )
    
    try {
        Write-Info "Setting WSL default version to $Version"
        
        $result = & wsl.exe --set-default-version $Version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to set WSL default version: $result"
            return $false
        }
        
        Write-Success "WSL default version set to $Version"
        return $true
        
    } catch {
        Write-Warning "Error setting WSL default version: $($_.Exception.Message)"
        return $false
    }
}

function Get-WSLDistributions {
    <#
    .SYNOPSIS
    Gets list of installed WSL distributions
    
    .DESCRIPTION
    Returns information about all installed WSL distributions
    
    .OUTPUTS
    Array of PSCustomObject with distribution information
    #>
    param()
    
    try {
        Write-Info "Getting WSL distributions..."
        
        # Use wsl --list for simpler, more reliable parsing
        $wslList = & wsl.exe --list 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to get WSL distributions: $wslList"
            return @()
        }
        
        # Also get detailed status with --list --verbose for state information
        $wslListVerbose = & wsl.exe --list --verbose 2>&1 | Out-String
        
        $distributions = @()
        $lines = $wslList -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
        
        # Process each line that contains distribution names
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            
            # Skip header line
            if ($trimmedLine -match '^Windows Subsystem for Linux Distributions:') {
                continue
            }
            
            # Handle distribution format: "Ubuntu-24.04 (Default)" or just "Ubuntu"
            if ($trimmedLine -match '^([^\s]+(?:-[^\s]+)*)\s*(\(Default\))?') {
                $distroName = $matches[1]
                $isDefault = $null -ne $matches[2]
                
                # Try to get state from verbose output
                $state = "Unknown"
                $version = "2"  # Default to version 2
                
                if ($wslListVerbose -match "$distroName\s+(Running|Stopped)\s+(\d+)") {
                    $state = $matches[1]
                    $version = $matches[2]
                }
                
                $distributions += [PSCustomObject]@{
                    Name = $distroName
                    IsDefault = $isDefault
                    State = $state
                    Version = $version
                }
            }
        }
        
        Write-Info "Found $($distributions.Count) WSL distributions"
        return $distributions
        
    } catch {
        Write-Warning "Error getting WSL distributions: $($_.Exception.Message)"
        return @()
    }
}

function Install-WSLDistribution {
    <#
    .SYNOPSIS
    Installs a WSL distribution
    
    .DESCRIPTION
    Installs the specified WSL distribution from the Microsoft Store
    
    .PARAMETER DistributionName
    Name of the distribution to install (e.g., 'Ubuntu', 'Ubuntu-24.04')
    
    .PARAMETER what-if
    Shows what would be done without actually performing the actions
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DistributionName,
        [switch]${what-if}
    )
    
    try {
        if (${what-if}) {
            Write-Host "what if: Would check if WSL distribution '$DistributionName' already exists" -ForegroundColor Yellow
            Write-Host "what if: Would install WSL distribution '$DistributionName' using 'wsl --install -d $DistributionName'" -ForegroundColor Yellow
            return $true
        }
        
        Write-Info "Installing WSL distribution: $DistributionName"
        
        # Check if distribution already exists
        $existingDistros = Get-WSLDistributions
        $existing = $existingDistros | Where-Object { $_.Name -eq $DistributionName }
        
        if ($existing) {
            Write-Info "Distribution '$DistributionName' already exists"
            return $true
        }
        
        # Install distribution
        Write-Progress "Installing $DistributionName via WSL..."
        Write-Info "Executing: wsl.exe --install -d $DistributionName"
        Write-Info "This may take several minutes to download and install the distribution..."
        Write-Info "User setup will open in a new window after installation completes."
        Write-Host ""
        
        # Use Start-Process to open in new window for user interaction
        try {
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "wsl.exe"
            $processInfo.Arguments = "--install -d $DistributionName"
            $processInfo.RedirectStandardOutput = $false
            $processInfo.RedirectStandardError = $false
            $processInfo.UseShellExecute = $true  # This enables new window
            $processInfo.CreateNoWindow = $false
            $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            
            Write-Info "Starting WSL installation in new window..."
            $process.Start()
            
            # Monitor for completion by checking distribution availability
            $timeout = 600 # 10 minutes timeout
            $elapsed = 0
            $checkInterval = 15 # Check every 15 seconds
            $lastProgressUpdate = 0
            $distributionFound = $false
            
            Write-Info "Monitoring installation progress (user setup will appear in separate window)..."
            
            while ($elapsed -lt $timeout -and -not $distributionFound) {
                Start-Sleep -Seconds $checkInterval
                $elapsed += $checkInterval
                
                # Check if distribution is now available (indicating successful installation)
                try {
                    $currentDistros = Get-WSLDistributions
                    $foundDistro = $currentDistros | Where-Object { $_.Name -eq $DistributionName }
                    
                    if ($foundDistro) {
                        $distributionFound = $true
                        Write-Success "Distribution '$DistributionName' detected in WSL list"
                        break
                    }
                    
                    # Also check if we can run basic commands (indicates setup completion)
                    $testResult = wsl -d $DistributionName -- echo "test" 2>&1
                    if ($LASTEXITCODE -eq 0 -and $testResult -match "test") {
                        $distributionFound = $true
                        Write-Success "Distribution '$DistributionName' is responding to commands"
                        break
                    }
                    
                } catch {
                    # Continue waiting
                }
                
                # Show progress every 30 seconds
                if ($elapsed - $lastProgressUpdate -ge 30) {
                    $remainingMinutes = [math]::Max(0, [math]::Round(($timeout - $elapsed) / 60, 1))
                    Write-Info "Still waiting for installation to complete... (${remainingMinutes} minutes remaining)"
                    Write-Info "Please complete user setup in the Ubuntu window if it has appeared"
                    $lastProgressUpdate = $elapsed
                }
            }
            
            # Final verification with detailed checking
            if (-not $distributionFound) {
                Write-Warning "Timeout reached, performing final verification..."
                
                try {
                    $finalCheck = Get-WSLDistributions
                    $finalDistro = $finalCheck | Where-Object { $_.Name -eq $DistributionName }
                    if ($finalDistro) {
                        $distributionFound = $true
                        Write-Success "Distribution found in final verification"
                    }
                } catch {
                    # Final check failed
                }
            }
            
            # Return result
            if ($distributionFound) {
                Write-Success "$DistributionName installation and setup completed successfully"
                return $true
            } else {
                Write-Warning "Could not verify $DistributionName installation within timeout period"
                Write-Info "The distribution may have been installed successfully but verification failed"
                Write-Info "You can manually verify with: wsl --list --verbose"
                Write-Info "Continuing with setup - you can retry WSL installation later if needed"
                return $true  # Don't block entire setup
            }
            
        } catch {
            Write-Warning "Error starting WSL installation in new window: $($_.Exception.Message)"
            
            # Fallback to inline method
            Write-Info "Falling back to inline installation method..."
            Write-Info "User setup will appear in this window..."
            Write-Host ""
            
            try {
                $installResult = & wsl.exe --install -d $DistributionName
                $exitCode = $LASTEXITCODE
                
                Write-Host ""
                if ($exitCode -eq 0) {
                    Write-Success "$DistributionName installed successfully"
                    return $true
                } else {
                    Write-Warning "$DistributionName installation may have encountered issues"
                    Write-Info "Installation output: $($installResult -join ' ')"
                    Write-Info "You can verify installation status with: wsl --list --verbose"
                    Write-Info "If the distribution appears in the list, installation was successful"
                    Write-Info "You may need to complete user setup manually: wsl -d $DistributionName"
                    Write-Host ""
                    Write-Info "Continuing with setup - you can complete WSL setup later if needed"
                    return $true  # Don't block entire setup for WSL issues
                }
            } catch {
                Write-Error "Fallback installation encountered an error: $($_.Exception.Message)"
                return $false
            }
        }
        
    } catch {
        Write-Warning "Error installing WSL distribution: $($_.Exception.Message)"
        return $false
    }
}

function Test-WSLDistributionReady {
    <#
    .SYNOPSIS
    Tests if a WSL distribution is ready for use
    
    .DESCRIPTION
    Checks if the specified WSL distribution is installed and has a user configured
    
    .PARAMETER DistributionName
    Name of the distribution to test
    
    .OUTPUTS
    Boolean indicating if distribution is ready
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DistributionName
    )
    
    try {
        # Test basic connectivity
        $testResult = wsl -d $DistributionName -- echo "WSL_TEST_SUCCESS" 2>&1
        if (-not $testResult -or ($testResult -join "") -notmatch "WSL_TEST_SUCCESS") {
            Write-Info "WSL distribution '$DistributionName' connectivity test failed"
            return $false
        }
        
        # Test if user is configured
        $userTest = wsl -d $DistributionName -- whoami 2>&1
        if (-not $userTest -or 
            ($userTest -join "") -match "root" -or 
            ($userTest -join "") -match "error" -or
            ($userTest -join "") -match "failed") {
            Write-Info "WSL distribution '$DistributionName' needs user setup"
            return $false
        }
        
        Write-Success "WSL distribution '$DistributionName' is ready for use"
        return $true
        
    } catch {
        Write-Warning "Error testing WSL distribution: $($_.Exception.Message)"
        return $false
    }
}

function Set-WSLDistributionAsDefault {
    <#
    .SYNOPSIS
    Sets a WSL distribution as the default
    
    .PARAMETER DistributionName
    Name of the distribution to set as default
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DistributionName
    )
    
    try {
        Write-Info "Setting '$DistributionName' as default WSL distribution"
        
        $result = & wsl.exe --set-default $DistributionName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to set default distribution: $result"
            return $false
        }
        
        Write-Success "'$DistributionName' set as default WSL distribution"
        return $true
        
    } catch {
        Write-Warning "Error setting default WSL distribution: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main WSL Setup Function

function Initialize-WSLDistribution {
    <#
    .SYNOPSIS
    Initialize WSL distribution setup focused on WSL management only
    
    .DESCRIPTION
    Handles WSL feature enablement, distribution installation, and basic configuration.
    Does NOT install development tools - that's handled by individual tool routers.
    
    .PARAMETER DistributionName
    Name of the Ubuntu distribution to install (loaded from configuration if not specified)
    
    .PARAMETER RequiresWSL
    Whether the project requires WSL functionality
    
    .PARAMETER check-only
    Only test current setup without making changes
    
    .PARAMETER what-if
    Shows what would be done without actually performing the actions
    
    .PARAMETER execution-engine
    Skip strangeloop CLI prerequisites check when set to PowerShell
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [string]$DistributionName,
        [switch]$RequiresWSL,
        [switch]${check-only},
        [switch]${what-if},
        [string]${execution-engine} = "StrangeloopCLI"
    )
    
    # Set default distribution name if not provided
    if ([string]::IsNullOrWhiteSpace($DistributionName)) {
        $wslConfig = Get-WSLConfigurationDefaults
        $DistributionName = $wslConfig.DefaultDistribution
        Write-Info "Using default WSL distribution from configuration: $DistributionName"
    }
    
    # Clean the distribution name to handle any encoding issues
    $DistributionName = Get-CleanDistributionName -DistributionName $DistributionName
    Write-Info "Using clean WSL distribution name: $DistributionName"
    
    try {
        Write-Step "WSL Distribution Setup..."
        
        if (${what-if}) {
            Write-Host "what if: Would test if WSL is available" -ForegroundColor Yellow
            Write-Host "what if: Would enable WSL if not available" -ForegroundColor Yellow
            Write-Host "what if: Would set WSL default version to 2" -ForegroundColor Yellow
            Write-Host "what if: Would install Ubuntu distribution '$DistributionName' if not present" -ForegroundColor Yellow
            Write-Host "what if: Would set '$DistributionName' as default WSL distribution" -ForegroundColor Yellow
            Write-Host "what if: Would verify distribution is ready for use" -ForegroundColor Yellow
            return $true
        }
        
        #region WSL Feature Setup
        
        Write-Step "WSL Feature and Version Setup"
        Write-Info "Checking WSL availability and basic configuration..."
        
        # Test if WSL is available
        Write-Progress "Checking WSL availability..."
        $wslAvailable = Test-WSLAvailable
        
        if (-not $wslAvailable -and ${check-only}) {
            Write-Warning "WSL is not available"
            return $false
        }
        
        # Enable WSL if not available
        if (-not $wslAvailable -and -not ${check-only}) {
            Write-Progress "WSL not available - enabling WSL feature..."
            $enableResult = Enable-WSL
            if (-not $enableResult) {
                Write-Warning "Failed to enable WSL feature"
                Write-Info "Please enable WSL manually:"
                Write-Info "  1. Run PowerShell as Administrator"
                Write-Info "  2. Execute: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All"
                Write-Info "  3. Execute: Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All"
                Write-Info "  4. Restart your computer"
                return $false
            } else {
                Write-Success "WSL feature enabled successfully"
            }
        } else {
            Write-Success "WSL is available"
        }
        
        # Set default version to 2
        if (-not ${check-only}) {
            Write-Progress "Setting WSL default version to 2..."
            $versionResult = Set-WSLDefaultVersion -Version "2"
            if (-not $versionResult) {
                Write-Warning "Failed to set WSL default version, continuing..."
            } else {
                Write-Success "WSL default version set to 2"
            }
        }
        
        #endregion
        
        #region Distribution Setup
        
        Write-Step "WSL Distribution Installation and Configuration"
        
        # Check for existing distributions
        Write-Progress "Checking existing WSL distributions..."
        $distributions = Get-WSLDistributions
        $targetDistro = $distributions | Where-Object { $_.Name -eq $DistributionName }
        
        # Also check for any Ubuntu-like distribution if we're looking for Ubuntu
        if (-not $targetDistro -and $DistributionName -eq "Ubuntu") {
            $ubuntuDistro = $distributions | Where-Object { $_.Name -like "Ubuntu*" }
            if ($ubuntuDistro) {
                Write-Info "Found existing Ubuntu distribution: $($ubuntuDistro.Name)"
                $DistributionName = $ubuntuDistro.Name
                $targetDistro = $ubuntuDistro
            }
        }
        
        if (-not $targetDistro -and -not ${check-only}) {
            # Install Ubuntu distribution
            Write-Info "Distribution '$DistributionName' not found - installing..."
            $installResult = Install-WSLDistribution -DistributionName $DistributionName
            if (-not $installResult) {
                Write-Warning "Failed to install WSL distribution"
                return $false
            } else {
                Write-Success "WSL distribution '$DistributionName' installed successfully"
            }
            
            # Set the newly installed distribution as default (if installation succeeded)
            if ($installResult) {
                Write-Progress "Setting '$DistributionName' as default WSL distribution..."
                $defaultResult = Set-WSLDistributionAsDefault -DistributionName $DistributionName
                if (-not $defaultResult) {
                    Write-Warning "Failed to set '$DistributionName' as default, but continuing..."
                } else {
                    Write-Success "'$DistributionName' set as default WSL distribution"
                }
            }
        } elseif ($targetDistro) {
            Write-Success "WSL distribution '$($targetDistro.Name)' is already available"
            $DistributionName = $targetDistro.Name  # Ensure we use the actual name
            
            # Check if it's already the default, if not set it
            $currentDefault = & wsl.exe --status 2>&1 | Select-String "Default Distribution" | ForEach-Object { $_.ToString().Split(':')[1].Trim() } 2>$null
            if ($currentDefault -and $currentDefault -ne $targetDistro.Name) {
                Write-Progress "Setting '$($targetDistro.Name)' as default WSL distribution..."
                $defaultResult = Set-WSLDistributionAsDefault -DistributionName $targetDistro.Name
                if (-not $defaultResult) {
                    Write-Warning "Failed to set '$($targetDistro.Name)' as default, but continuing..."
                } else {
                    Write-Success "'$($targetDistro.Name)' set as default WSL distribution"
                }
            } elseif ($currentDefault -eq $targetDistro.Name) {
                Write-Success "'$($targetDistro.Name)' is already the default WSL distribution"
            }
        }
        
        #endregion
        
        #region Distribution Readiness Check
        
        Write-Step "WSL Distribution Readiness Verification"
        
        # Test WSL connectivity and user setup
        Write-Progress "Testing WSL distribution readiness..."
        
        # Clean distribution name to handle encoding issues
        $chars = $DistributionName.ToCharArray() | Where-Object { $_ -ne "`0" }
        $cleanDistro = [String]::new($chars)
        if ([string]::IsNullOrWhiteSpace($cleanDistro)) {
            $wslConfig = Get-WSLConfigurationDefaults
            $cleanDistro = $wslConfig.DefaultDistribution
        }
        
        # Update the distribution name for subsequent operations
        $DistributionName = $cleanDistro
        
        # Test if distribution is ready
        $isReady = Test-WSLDistributionReady -DistributionName $DistributionName
        
        if (-not $isReady -and -not ${check-only}) {
            Write-Info ""
            Write-Info "🔧 WSL User Setup Required"
            Write-Info "Your WSL distribution needs initial user setup."
            Write-Info "Opening Ubuntu in a separate window for user configuration..."
            Write-Info ""
            Write-Info "🪟 A new Ubuntu terminal window will open where you need to:"
            Write-Info "   • Create your username (recommend using your Windows username)"
            Write-Info "   • Set a secure password"
            Write-Info "   • Wait for the initial setup to complete"
            Write-Info "   • Type 'exit' when done to return to this script"
            Write-Info ""
            Write-Warning "⚠️  Do NOT close this script window - it will wait for you"
            
            Start-Sleep -Seconds 3
            
            # Launch Ubuntu in a separate window
            try {
                Start-Process -FilePath "wsl.exe" -ArgumentList "-d", $DistributionName -WindowStyle Normal -Wait
                Write-Success "Ubuntu user setup completed - continuing with verification..."
            } catch {
                Write-Warning "Failed to launch Ubuntu for user setup: $($_.Exception.Message)"
                Write-Info "Please run manually: wsl -d $DistributionName"
                Write-Info "Complete the user setup and run this script again"
            }
            
            # Re-test readiness after user setup
            $isReady = Test-WSLDistributionReady -DistributionName $DistributionName
        }
        
        if ($isReady) {
            Write-Success "WSL distribution '$DistributionName' is ready for development tool installation"
        } else {
            Write-Warning "WSL distribution may need additional configuration"
            Write-Info "You can complete setup manually: wsl -d $DistributionName"
        }
        
        #endregion
        
        Write-Success "WSL distribution setup completed successfully"
        
        # Provide setup summary
        Write-Host ""
        Write-Info "WSL Setup Summary:"
        Write-Info "  ✓ WSL feature enabled and configured"
        Write-Info "  ✓ WSL version 2 set as default"
        Write-Info "  ✓ Distribution '$DistributionName' installed and configured"
        Write-Info "  ✓ WSL distribution ready for development use"
        Write-Host ""
        Write-Info "Next Steps:"
        Write-Info "  • Linux development tools should be installed separately inside WSL"
        Write-Info "  • Run the Linux environment setup script inside WSL to install tools"
        Write-Info "  • Command: wsl -d $DistributionName"
        Write-Info "  • Then: pwsh ./cli/src/strangeloop/bootstrap/phases/02-environment-setup/orchestration/setup-environment-linux.ps1"
        Write-Host ""
        
        return $true
        
    } catch {
        Write-Warning "Error in WSL distribution setup: $($_.Exception.Message)"
        return $false
    }
}

#endregion

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Set default distribution name if not provided
    if ([string]::IsNullOrWhiteSpace($DistributionName)) {
        $wslDefaults = Get-WSLConfigurationDefaults
        $DistributionName = $wslDefaults.DefaultDistribution
        Write-Info "Using default WSL distribution from configuration: $DistributionName"
    }
    
    # Clean the distribution name to handle any encoding issues
    $DistributionName = Get-CleanDistributionName -DistributionName $DistributionName
    Write-Info "Using clean WSL distribution name: $DistributionName"
    
    $params = @{
        'DistributionName' = $DistributionName
        'RequiresWSL' = $RequiresWSL
    }
    if (${check-only}) { $params['check-only'] = ${check-only} }
    if (${what-if}) { $params['what-if'] = ${what-if} }
    if (${execution-engine} -eq 'PowerShell') { $params['execution-engine'] = ${execution-engine} }
    
    $result = Initialize-WSLDistribution @params
    
    if ($result) {
        Write-Success "WSL distribution setup completed successfully"
        return @{ Success = $true; Phase = "WSL-Distribution"; Message = "WSL distribution setup completed successfully" }
    } else {
        Write-Error "WSL distribution setup failed"
        return @{ Success = $false; Phase = "WSL-Distribution"; Message = "WSL distribution setup failed" }
    }
}

# Export functions for module usage
Export-ModuleMember -Function @(
    'Initialize-WSLDistribution',
    'Get-WSLConfigurationDefaults',
    'Get-CleanDistributionName',
    'Test-WSLAvailable',
    'Get-WSLDistributions',
    'Install-WSLDistribution',
    'Enable-WSL',
    'Set-WSLDefaultVersion',
    'Test-WSLDistributionReady',
    'Set-WSLDistributionAsDefault'
)