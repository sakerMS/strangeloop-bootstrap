# strangeloop Setup - strangeloop CLI Installation Module
# Version: 1.1.0 - Simplified

param(
    [string]$Version = "latest",
    [switch]${check-only},
    [switch]${what-if}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "platform\path-functions.ps1")

function Test-StrangeloopUpgradeNeeded {
    <#
    .SYNOPSIS
        Checks if strangeloop CLI upgrade is needed by testing compliance
    
    .OUTPUTS
        Returns $true if upgrade is needed, $false otherwise
    #>
    
    try {
        Write-Info "Checking if strangeloop CLI upgrade is needed..."
        
        # First check if CLI is installed and functional
        if (-not (Test-Command "strangeloop")) {
            # If not found, try refreshing PATH and check common installation locations
            Write-Info "strangeloop CLI not found in current PATH, refreshing environment..."
            
            $refreshSuccess = Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths (Get-CommonToolPaths -ToolName "strangeloop")
            
            if (-not $refreshSuccess -or -not (Test-Command "strangeloop")) {
                Write-Info "strangeloop CLI not found even after PATH refresh - upgrade needed"
                return $true
            } else {
                Write-Info "strangeloop CLI found after PATH refresh"
            }
        }
        
        # Get current version
        $currentVersion = Get-ToolVersion "strangeloop"
        if (-not $currentVersion) {
            # Try alternative version detection
            try {
                $versionOutput = strangeloop version 2>&1
                if ($versionOutput -and $versionOutput -match "strangeloop ([0-9]+\.[0-9]+\.[0-9]+)") {
                    $currentVersion = $matches[1]
                } else {
                    # Version detection failed but CLI might be functional
                    $helpOutput = strangeloop --help 2>&1
                    if ($helpOutput -and $helpOutput -match "strangeloop|loops|init") {
                        Write-Info "Version detection failed but CLI appears functional - checking with built-in upgrade"
                        return $true
                    } else {
                        Write-Info "CLI not functional - upgrade needed"
                        return $true
                    }
                }
            } catch {
                Write-Info "Version check failed - upgrade needed"
                return $true
            }
        }
        
        # Check version compliance
        $compliance = Test-ToolVersionCompliance -ToolName "strangeloop_cli" -InstalledVersion $currentVersion
        
        if (-not $compliance.IsCompliant) {
            Write-Info "Current version $currentVersion does not meet requirements - upgrade needed"
            return $true
        }
        
        # Check if recommended version is "latest" - if so, always check for upgrades
        if ($compliance.RecommendedVersion -eq "latest") {
            Write-Info "Current version $currentVersion meets requirements, but recommended version is 'latest' - checking for newer version"
            Write-Info "Using built-in 'strangeloop cli upgrade' command for latest version check"
            return $true  # Always check for upgrades when "latest" is recommended
        }
        
        Write-Info "Current version $currentVersion meets requirements and no upgrade policy specified"
        return $false
        
    } catch {
        Write-Warning "Error checking upgrade status: $($_.Exception.Message)"
        return $true  # Default to upgrade attempt on error
    }
}

function Test-strangeloopCLI {
    param(
        [switch]$Detailed
    )
    
    try {
        Write-Info "Testing strangeloop CLI installation..."
        
        # Check if strangeloop CLI command is available
        if (-not (Test-Command "strangeloop")) {
            # If not found, try refreshing PATH and check common installation locations
            Write-Info "strangeloop CLI not found in current PATH, refreshing environment..."
            
            $refreshSuccess = Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths (Get-CommonToolPaths -ToolName "strangeloop")
            
            if (-not $refreshSuccess -or -not (Test-Command "strangeloop")) {
                Write-Warning "strangeloop CLI command 'strangeloop' not found even after PATH refresh"
                return $false
            } else {
                Write-Info "strangeloop CLI found after PATH refresh"
            }
        }
        
        # Check strangeloop CLI version - this is required for proper validation
        $strangeloopVersion = Get-ToolVersion "strangeloop"
        if (-not $strangeloopVersion) {
            Write-Warning "Could not get strangeloop CLI version - this indicates an installation issue"
            
            # Try alternative version detection methods
            try {
                Write-Info "Attempting alternative version detection..."
                
                # Method 1: Try strangeloop version command with error handling
                $versionOutput = strangeloop version 2>&1
                if ($versionOutput -and $versionOutput -match "strangeloop ([0-9]+\.[0-9]+\.[0-9]+)") {
                    $strangeloopVersion = $matches[1]
                    Write-Info "Version detected via 'strangeloop version': $strangeloopVersion"
                } else {
                    Write-Info "Version output from 'strangeloop version': $versionOutput"
                    
                    # Method 2: Try --version flag
                    $versionOutput2 = strangeloop --version 2>&1
                    if ($versionOutput2 -and $versionOutput2 -match "([0-9]+\.[0-9]+\.[0-9]+)") {
                        $strangeloopVersion = $matches[1]
                        Write-Info "Version detected via 'strangeloop --version': $strangeloopVersion"
                    } else {
                        Write-Info "Version output from 'strangeloop --version': $versionOutput2"
                        
                        # Method 3: Check if CLI is functional despite version detection failure
                        $helpOutput = strangeloop --help 2>&1
                        if ($helpOutput -and $helpOutput -match "strangeloop|loops|init") {
                            Write-Warning "CLI appears functional but version detection failed"
                            Write-Info "Proceeding with functionality test only"
                            $strangeloopVersion = "unknown-but-functional"
                        } else {
                            Write-Warning "Alternative version detection also failed"
                            Write-Info "Help output: $helpOutput"
                            return $false
                        }
                    }
                }
            } catch {
                Write-Warning "Alternative version detection failed: $($_.Exception.Message)"
                
                # Last resort: test if CLI is at least functional
                try {
                    $helpOutput = strangeloop --help 2>&1
                    if ($helpOutput -and $helpOutput -match "strangeloop|loops|init") {
                        Write-Warning "CLI appears functional but version detection completely failed"
                        $strangeloopVersion = "unknown-but-functional"
                    } else {
                        return $false
                    }
                } catch {
                    return $false
                }
            }
        }
        
        # Test version compliance - version is required for proper validation
        if ($strangeloopVersion -eq "unknown-but-functional") {
            Write-Warning "Version unknown but CLI appears functional - marking as compliant"
            $compliance = @{
                IsCompliant = $true
                CurrentVersion = $strangeloopVersion
                RequiredVersion = "unknown"
                IsLatest = $false
            }
        } else {
            $compliance = Test-ToolVersionCompliance -ToolName "strangeloop_cli" -InstalledVersion $strangeloopVersion
        }
        Write-VersionComplianceReport -ToolName "strangeloop CLI" -ComplianceResult $compliance
        
        if (-not $compliance.IsCompliant) {
            Write-Warning "strangeloop CLI version $strangeloopVersion does not meet minimum requirements"
            if ($Detailed) {
                Write-Info "Action required: $($compliance.Action)"
            }
            return $false
        }
        
        # Test basic functionality
        try {
            $helpOutput = strangeloop --help 2>$null
            if (-not $helpOutput) {
                Write-Warning "strangeloop CLI functionality test failed"
                return $false
            }
        } catch {
            Write-Warning "strangeloop CLI functionality test failed: $($_.Exception.Message)"
            return $false
        }
        
        Write-Success "strangeloop CLI is properly installed and compliant: $strangeloopVersion"
        return $true
        
    } catch {
        Write-Warning "Error testing strangeloop CLI: $($_.Exception.Message)"
        return $false
    }
}

function Install-strangeloopCLI {
    param(
        [string]$Version = "latest",
        [switch]${check-only},
        [switch]${what-if}
    )
    
    # If what-if mode, show what would be done
    if (${what-if}) {
        Write-Host "what if: Would check for strangeloop CLI installation" -ForegroundColor Yellow
        Write-Host "what if: Would check for available upgrades if already installed" -ForegroundColor Yellow
        Write-Host "what if: Would download and install strangeloop CLI from Azure Artifacts if not found or upgrade needed" -ForegroundColor Yellow
        Write-Host "what if: Would verify strangeloop CLI functionality" -ForegroundColor Yellow
        return $true
    }
    
    # If check-only mode, just test current installation
    if (${check-only}) {
        return Test-strangeloopCLI -Detailed
    }
    
    # Check if already installed and working
    $currentlyInstalled = Test-strangeloopCLI
    if ($currentlyInstalled) {
        Write-Success "strangeloop CLI is already installed and working"
        
        # Check for available upgrades
        $currentVersion = Get-ToolVersion "strangeloop"
        if (-not $currentVersion) {
            # Try alternative version detection
            try {
                $versionOutput = strangeloop version 2>&1
                if ($versionOutput -and $versionOutput -match "strangeloop ([0-9]+\.[0-9]+\.[0-9]+)") {
                    $currentVersion = $matches[1]
                } else {
                    # Check if CLI is functional even if version detection fails
                    $helpOutput = strangeloop --help 2>&1
                    if ($helpOutput -and $helpOutput -match "strangeloop|loops|init") {
                        $currentVersion = "unknown-but-functional"
                    }
                }
            } catch {
                Write-Warning "Could not determine current version for upgrade check"
            }
        }
        
        if ($currentVersion) {
            Write-Info "Current installed version: $currentVersion"
            
            # Always attempt upgrade using built-in strangeloop cli upgrade command
            if (Test-StrangeloopUpgradeNeeded) {
                Write-Info "Attempting to upgrade strangeloop CLI using built-in upgrade command..."
                
                try {
                    # Get baseline of running MSI installer processes before upgrade
                    $preUpgradeMsiProcesses = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id
                    
                    # Use the strangeloop CLI's built-in upgrade functionality
                    Write-Info "Running: strangeloop cli upgrade"
                    $upgradeResult = & strangeloop cli upgrade 2>&1
                    $upgradeExitCode = $LASTEXITCODE
                    
                    if ($upgradeExitCode -eq 0) {
                        Write-Success "strangeloop CLI upgrade command completed successfully"
                        Write-Info "Upgrade output: $($upgradeResult -join '; ')"
                        
                        # Check if the CLI was already up to date
                        $upgradeOutput = $upgradeResult -join ' '
                        if ($upgradeOutput -match "CLI is up to date" -or 
                            $upgradeOutput -match "already up to date" -or
                            $upgradeOutput -match "up to date" -or
                            $upgradeOutput -match "no upgrade available" -or
                            $upgradeOutput -match "latest version") {
                            Write-Success "strangeloop CLI is already up to date - no upgrade necessary"
                            
                            # Verify the installation is still working
                            Write-Info "Verifying installation..."
                            $verifyTest = Test-strangeloopCLI -Detailed
                            
                            if ($verifyTest) {
                                Write-Success "strangeloop CLI verification successful"
                                return $true
                            } else {
                                Write-Warning "strangeloop CLI verification failed after up-to-date check"
                                return $false
                            }
                        } else {
                            # An actual upgrade occurred, wait for MSI installer
                            Write-Info "strangeloop CLI upgrade initiated..."
                            Write-Info "An MSI installer may have been launched to complete the upgrade."
                            
                            Write-Host ""
                            Write-Host "🔄 Please wait for the MSI installer to complete, then press any key to continue..." -ForegroundColor Yellow
                            Write-Host "   (The installer window may appear separately)" -ForegroundColor Gray
                            Write-Host ""
                            
                            # Wait for user input
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            Write-Info "Continuing with installation verification..."
                        }
                        
                        # Verify the installation after upgrade
                        Write-Info "Verifying installation after upgrade..."
                        
                        # Wait a bit for the system to update
                        Start-Sleep -Seconds 5
                        
                        # Comprehensive PATH refresh after upgrade
                        Write-Info "Refreshing environment PATH after upgrade..."
                        Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths (Get-CommonToolPaths -ToolName "strangeloop") -WaitSeconds 0
                        
                        $postUpgradeTest = Test-strangeloopCLI -Detailed
                        
                        if ($postUpgradeTest) {
                            # Get the final version after upgrade
                            $finalVersion = Get-ToolVersion "strangeloop"
                            if (-not $finalVersion) {
                                try {
                                    $versionOutput = strangeloop version 2>&1
                                    if ($versionOutput -and $versionOutput -match "strangeloop ([0-9]+\.[0-9]+\.[0-9]+)") {
                                        $finalVersion = $matches[1]
                                    } else {
                                        # Check if CLI is functional even if version detection fails
                                        $helpOutput = strangeloop --help 2>&1
                                        if ($helpOutput -and $helpOutput -match "strangeloop|loops|init") {
                                            $finalVersion = "unknown-but-functional"
                                        } else {
                                            $finalVersion = "unknown"
                                        }
                                    }
                                } catch {
                                    $finalVersion = "unknown"
                                }
                            }
                            
                            # Check if we actually got an upgraded version
                            if ($finalVersion -ne $currentVersion -and $finalVersion -ne "unknown" -and $finalVersion -ne "unknown-but-functional") {
                                Write-Success "Upgrade verification successful - final version: $finalVersion"
                                return $true
                            } else {
                                Write-Warning "Version did not change after upgrade attempt ($currentVersion -> $finalVersion)"
                                Write-Info "Proceeding with manual installation as fallback..."
                            }
                        } else {
                            Write-Warning "Post-upgrade verification failed"
                            Write-Info "Proceeding with manual installation as fallback..."
                        }
                    } else {
                        Write-Warning "strangeloop CLI upgrade returned exit code $upgradeExitCode"
                        Write-Info "Upgrade output: $($upgradeResult -join '; ')"
                        # Continue with installation as fallback
                        Write-Info "Proceeding with manual installation as fallback..."
                    }
                } catch {
                    Write-Warning "Error running strangeloop CLI upgrade: $($_.Exception.Message)"
                    Write-Info "Proceeding with manual installation as fallback..."
                }
            }
        } else {
            Write-Info "Could not determine current version, but strangeloop CLI is working"
            return $true
        }
    }
    
    if ($currentlyInstalled) {
        Write-Step "Upgrading strangeloop CLI..."
        Write-Info "Proceeding with strangeloop CLI upgrade"
    } else {
        Write-Step "Installing strangeloop CLI..."
        Write-Info "strangeloop CLI not found or not working properly - proceeding with installation"
    }
    
    try {
        # Check prerequisites
        if (-not (Test-InternetConnection)) {
            Write-Error "Internet connection required for strangeloop CLI installation"
            return $false
        }
        
        if (-not (Test-Command "az")) {
            Write-Error "Azure CLI is required for strangeloop CLI installation"
            return $false
        }
        
        # Check Azure CLI authentication
        try {
            $account = az account show --output json 2>$null | ConvertFrom-Json
            if (-not $account) {
                Write-Error "Azure CLI is not authenticated. Please run 'az login' first."
                return $false
            }
            Write-Info "Azure CLI authenticated as: $($account.user.name)"
        } catch {
            Write-Warning "Could not verify Azure CLI authentication"
        }
        
        # Download and install strangeloop CLI
        $tempDir = Join-Path $env:TEMP "strangeloop-install-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        try {
            Push-Location $tempDir
            
            Write-Info "Downloading strangeloop CLI from Azure Artifacts..."
            $azArgs = @(
                "artifacts", "universal", "download",
                "--organization", "https://msasg.visualstudio.com/",
                "--project", "Bing_Ads",
                "--scope", "project",
                "--feed", "strangeloop",
                "--name", "strangeloop-x86",
                "--version", "*",
                "--path", ".",
                "--only-show-errors"
            )
            
            $azResult = & az @azArgs 2>&1
            $azExitCode = $LASTEXITCODE
            
            if ($azExitCode -ne 0) {
                Write-Error "Download failed with exit code: $azExitCode"
                Write-Error "Output: $($azResult -join '; ')"
                return $false
            }
            
            # Find and install MSI
            $msiFiles = @(Get-ChildItem -Path "." -Filter "*.msi" -ErrorAction SilentlyContinue)
            if ($msiFiles.Count -eq 0) {
                Write-Error "No MSI file found after download"
                return $false
            }
            
            $msiPath = $msiFiles[0].FullName
            Write-Info "Installing from: $msiPath"
            
            $installArgs = @("/i", "`"$msiPath`"", "/quiet", "/norestart")
            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -Verb RunAs
            
            if ($process.ExitCode -ne 0) {
                Write-Error "Installation failed with exit code: $($process.ExitCode)"
                return $false
            }
            
            Write-Success "strangeloop CLI installed successfully"
            
        } finally {
            Pop-Location
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Comprehensive PATH refresh after installation
        Write-Info "Refreshing environment PATH after installation..."
        Update-EnvironmentPath -ToolName "strangeloop CLI" -CommonPaths (Get-CommonToolPaths -ToolName "strangeloop") -WaitSeconds 3
        
        if (Test-strangeloopCLI) {
            if ($currentlyInstalled) {
                Write-Success "strangeloop CLI upgrade completed and verified"
            } else {
                Write-Success "strangeloop CLI installation completed and verified"
            }
            return $true
        } else {
            if ($currentlyInstalled) {
                Write-Warning "Upgrade completed but verification failed"
            } else {
                Write-Warning "Installation completed but verification failed"
            }
            Write-Info "You may need to restart your terminal"
            return $false
        }
        
    } catch {
        Write-Error "strangeloop CLI installation failed: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Build parameters dynamically to avoid syntax errors
    $params = @{
        'Version' = $Version
    }
    if (${check-only}) { $params['check-only'] = $true }
    if (${what-if}) { $params['what-if'] = $true }
    
    $result = Install-strangeloopCLI @params
    
    if ($result) {
        if (${check-only}) {
            Write-Success "strangeloop CLI test completed successfully"
        } else {
            # Get version for summary with fallback handling
            $summaryVersion = Get-ToolVersion "strangeloop"
            if (-not $summaryVersion) {
                try {
                    $versionOutput = strangeloop version 2>&1
                    if ($versionOutput -and $versionOutput -match "strangeloop ([0-9]+\.[0-9]+\.[0-9]+)") {
                        $summaryVersion = $matches[1]
                    } else {
                        $summaryVersion = "Installed (version detection failed)"
                    }
                } catch {
                    $summaryVersion = "Installed (version unknown)"
                }
            }
            
            Write-CompletionSummary @{
                'strangeloop CLI Installation/Upgrade' = 'Completed Successfully'
                'Version' = $summaryVersion
                'Command Available' = if (Test-Command "strangeloop") { "Yes" } else { "No" }
            } -Title "strangeloop CLI Installation Summary"
        }
    } else {
        if (${check-only}) {
            Write-Error "strangeloop CLI test failed"
        } else {
            Write-Error "strangeloop CLI installation/upgrade failed"
        }
    }
    
    # Return the result for the calling script
    return $result
}
