# strangeloop Setup - Azure CLI Installation Module
# Version: 1.0.0


param(
    [string]$Version = "latest",
    [switch]${check-only},
    [switch]${what-if},
    [switch]${upgrade-only}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "platform\path-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")

function Test-AzureCLI {
    param(
        [switch]$Detailed,
        [switch]$PromptForUpgrade
    )
    
    Write-Info "Testing Azure CLI installation..."
    
    # First try normal command test
    if (-not (Test-Command "az")) {
        # If not found, try refreshing PATH and check common installation locations
        Write-Info "Azure CLI not found in current PATH, refreshing environment..."
        
        $refreshSuccess = Update-EnvironmentPath -ToolName "Azure CLI" -CommonPaths (Get-CommonToolPaths -ToolName "azure-cli")
        
        if (-not $refreshSuccess -or -not (Test-Command "az")) {
            Write-Warning "Azure CLI command 'az' not found"
            return $false
        } else {
            Write-Info "Azure CLI found after PATH refresh"
        }
    }
    
    $version = Get-ToolVersion "az"
    if (-not $version) {
        Write-Warning "Could not determine Azure CLI version"
        return $false
    }
    
    # Test version compliance
    $compliance = Test-ToolVersionCompliance -ToolName "azure_cli" -InstalledVersion $version
    $upgradeDecision = Write-VersionComplianceReport -ToolName "Azure CLI" -ComplianceResult $compliance -PromptForUpgrade:$PromptForUpgrade
    
    # Handle upgrade request if user chose to upgrade
    if ($upgradeDecision.ShouldUpgrade) {
        Write-Info "Initiating Azure CLI upgrade as requested..."
        $upgradeResult = Update-AzureCLI -Version $upgradeDecision.NewVersion
        if ($upgradeResult) {
            Write-Success "Azure CLI upgrade completed successfully"
            # Re-test compliance after upgrade
            $newVersion = Get-ToolVersion "az"
            $newCompliance = Test-ToolVersionCompliance -ToolName "azure_cli" -InstalledVersion $newVersion
            Write-VersionComplianceReport -ToolName "Azure CLI" -ComplianceResult $newCompliance
        } else {
            Write-Warning "Azure CLI upgrade failed, continuing with current version"
        }
    }
    
    if (-not $compliance.IsCompliant) {
        Write-Warning "Azure CLI version $version does not meet minimum requirements"
        if ($Detailed) {
            Write-Info "Action required: $($compliance.Action)"
        }
        return $false
    }
    
    Write-Success "Azure CLI $version is properly installed and compliant"
    
    # Test Azure CLI functionality
    try {
        $versionOutput = az version --output json 2>$null
        if ($versionOutput) {
            Write-Success "Azure CLI functionality test passed"
            
            if ($Detailed) {
                # Test Azure CLI extensions
                try {
                    $extensions = az extension list --output json 2>$null | ConvertFrom-Json
                    if ($extensions) {
                        Write-Info "Azure CLI extensions installed: $($extensions.Count)"
                        foreach ($ext in $extensions | Select-Object -First 3) {
                            Write-Info "  - $($ext.name) ($($ext.version))"
                        }
                        
                        # Check for Azure DevOps extension specifically
                        $azureDevOpsExt = $extensions | Where-Object { $_.name -eq "azure-devops" }
                        if ($azureDevOpsExt) {
                            Write-Success "Azure DevOps extension installed: $($azureDevOpsExt.version)"
                        } else {
                            Write-Warning "Azure DevOps extension not installed - installing now..."
                            try {
                                $installResult = az extension add --name azure-devops 2>&1
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "Azure DevOps extension installed successfully"
                                } else {
                                    Write-Warning "Failed to install Azure DevOps extension: $($installResult -join "`n")"
                                }
                            } catch {
                                Write-Warning "Error installing Azure DevOps extension: $($_.Exception.Message)"
                            }
                        }
                    } else {
                        Write-Info "No Azure CLI extensions installed - installing Azure DevOps extension..."
                        try {
                            $installResult = az extension add --name azure-devops 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success "Azure DevOps extension installed successfully"
                            } else {
                                Write-Warning "Failed to install Azure DevOps extension: $($installResult -join "`n")"
                            }
                        } catch {
                            Write-Warning "Error installing Azure DevOps extension: $($_.Exception.Message)"
                        }
                    }
                } catch {
                    Write-Info "Could not retrieve Azure CLI extensions"
                }
                
                # Test login status
                try {
                    $account = az account show --output json 2>$null | ConvertFrom-Json
                    if ($account) {
                        Write-Success "Azure CLI is logged in as: $($account.user.name)"
                        Write-Info "Current subscription: $($account.name)"
                        
                        # Test Azure DevOps authentication
                        Write-Info "Testing Azure DevOps authentication..."
                        try {
                            # Try to use Azure DevOps CLI to test authentication
                            $devopsTest = az devops project list --organization "https://msasg.visualstudio.com/" --query "value[0].name" --output tsv 2>$null
                            if ($LASTEXITCODE -eq 0 -and $devopsTest) {
                                Write-Success "Azure DevOps authentication working - can access projects"
                            } else {
                                Write-Warning "Azure DevOps authentication may not be working properly"
                                Write-Info "You may need to run 'az devops login' or ensure proper permissions for Azure DevOps"
                                Write-Info "This could cause issues when running tests that interact with Azure DevOps"
                            }
                        } catch {
                            Write-Warning "Could not test Azure DevOps authentication: $($_.Exception.Message)"
                            Write-Info "You may need to run 'az devops login' if using PAT token authentication"
                        }
                    } else {
                        Write-Info "Azure CLI is not currently logged in"
                    }
                } catch {
                    Write-Info "Azure CLI is not currently logged in"
                }
            }
            
            return $true
        } else {
            Write-Warning "Azure CLI functionality test failed"
            return $false
        }
    } catch {
        Write-Warning "Azure CLI functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-AzureAuthentication {
    param(
        [switch]${what-if}
    )
    
    Write-Step "Setting up Azure Authentication..."
    
    if (${what-if}) {
        Write-Host "what if: Would check current Azure login status with 'az account show'" -ForegroundColor Yellow
        Write-Host "what if: Would perform Azure login with 'az login' if not already logged in" -ForegroundColor Yellow
        Write-Host "what if: Would verify login and display account information" -ForegroundColor Yellow
        Write-Host "what if: Would install Azure DevOps extension if not present" -ForegroundColor Yellow
        Write-Host "what if: Would test Azure DevOps authentication and permissions" -ForegroundColor Yellow
        return $true
    }
    
    try {
        # Check current login status
        Write-Progress "Checking Azure login status..."
        
        try {
            $account = az account show --output json 2>$null | ConvertFrom-Json
            if ($account) {
                Write-Success "Already logged in to Azure as: $($account.user.name)"
                Write-Info "Current subscription: $($account.name)"
                return $true
            }
        } catch {
            Write-Info "Not currently logged in to Azure"
        }
        
        # Interactive Azure login
        Write-Progress "Initiating Azure login..."
        Write-Info "A browser window will open for Azure authentication..."
        
        try {
            # Run az login and capture output
            Write-Info "Running Azure CLI login..."
            $loginOutput = az login --allow-no-subscriptions --output json 2>&1
            $loginExitCode = $LASTEXITCODE
            
            if ($loginExitCode -eq 0) {
                Write-Success "Azure login completed successfully"
                
                # Parse the JSON output to see available subscriptions
                try {
                    # Filter output to extract only valid JSON content
                    $jsonContent = $null
                    
                    # Try to find lines that look like JSON array start
                    $jsonStartIndex = -1
                    for ($i = 0; $i -lt $loginOutput.Length; $i++) {
                        if ($loginOutput[$i] -match '^\s*\[') {
                            $jsonStartIndex = $i
                            break
                        }
                    }
                    
                    if ($jsonStartIndex -ge 0) {
                        # Extract from JSON start to end
                        $jsonLines = $loginOutput[$jsonStartIndex..($loginOutput.Length - 1)]
                        $jsonContent = $jsonLines -join "`n"
                        $subscriptions = $jsonContent | ConvertFrom-Json
                    } else {
                        # No JSON array found, skip parsing
                        $subscriptions = $null
                    }
                    if ($subscriptions -and $subscriptions.Count -gt 0) {
                        Write-Info "Found $($subscriptions.Count) accessible subscription(s):"
                        foreach ($sub in $subscriptions | Select-Object -First 3) {
                            $status = if ($sub.isDefault) { " (default)" } else { "" }
                            Write-Info "  • $($sub.name)$status"
                        }
                        
                        # Verify login by checking current account
                        $account = az account show --output json 2>$null | ConvertFrom-Json
                        if ($account) {
                            Write-Success "Azure login successful"
                            Write-Info "Logged in as: $($account.user.name)"
                            Write-Info "Current subscription: $($account.name)"
                            
                            # Install Azure DevOps extension if not present
                            Write-Info "Ensuring Azure DevOps extension is installed..."
                            try {
                                $extensions = az extension list --output json 2>$null | ConvertFrom-Json
                                $azureDevOpsExt = $extensions | Where-Object { $_.name -eq "azure-devops" }
                                
                                if (-not $azureDevOpsExt) {
                                    Write-Info "Installing Azure DevOps extension..."
                                    $installResult = az extension add --name azure-devops 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Success "Azure DevOps extension installed successfully"
                                    } else {
                                        Write-Warning "Failed to install Azure DevOps extension: $($installResult -join "`n")"
                                    }
                                } else {
                                    Write-Success "Azure DevOps extension already installed: $($azureDevOpsExt.version)"
                                }
                                
                                # Test Azure DevOps authentication
                                Write-Info "Testing Azure DevOps authentication..."
                                $devopsTest = az devops project list --organization "https://msasg.visualstudio.com/" --query "value[0].name" --output tsv 2>$null
                                if ($LASTEXITCODE -eq 0 -and $devopsTest) {
                                    Write-Success "Azure DevOps authentication confirmed - can access projects"
                                } else {
                                    Write-Warning "Azure DevOps authentication test failed"
                                    Write-Info "You may need to run 'az devops login' for PAT token authentication"
                                    Write-Info "Or ensure you have proper permissions for the Azure DevOps organization"
                                }
                            } catch {
                                Write-Warning "Error setting up Azure DevOps extension: $($_.Exception.Message)"
                            }
                            
                            return $true
                        } else {
                            Write-Warning "Login succeeded but could not verify current account"
                            Write-Info "You may need to select a subscription manually"
                            return $false
                        }
                    } else {
                        Write-Warning "Login succeeded but no accessible subscriptions found"
                        Write-Info "You may need tenant-level access or different permissions"
                        return $false
                    }
                } catch {
                    Write-Warning "Login output parsing failed: $($_.Exception.Message)"
                    Write-Info "Login may have succeeded - checking account status..."
                    
                    # Try to verify login anyway
                    $account = az account show --output json 2>$null | ConvertFrom-Json
                    if ($account) {
                        Write-Success "Azure login successful"
                        Write-Info "Logged in as: $($account.user.name)"
                        Write-Info "Current subscription: $($account.name)"
                        
                        # Install Azure DevOps extension if not present
                        Write-Info "Ensuring Azure DevOps extension is installed..."
                        try {
                            $extensions = az extension list --output json 2>$null | ConvertFrom-Json
                            $azureDevOpsExt = $extensions | Where-Object { $_.name -eq "azure-devops" }
                            
                            if (-not $azureDevOpsExt) {
                                Write-Info "Installing Azure DevOps extension..."
                                $installResult = az extension add --name azure-devops 2>&1
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "Azure DevOps extension installed successfully"
                                } else {
                                    Write-Warning "Failed to install Azure DevOps extension: $($installResult -join "`n")"
                                }
                            } else {
                                Write-Success "Azure DevOps extension already installed: $($azureDevOpsExt.version)"
                            }
                            
                            # Test Azure DevOps authentication
                            Write-Info "Testing Azure DevOps authentication..."
                            $devopsTest = az devops project list --organization "https://msasg.visualstudio.com/" --query "value[0].name" --output tsv 2>$null
                            if ($LASTEXITCODE -eq 0 -and $devopsTest) {
                                Write-Success "Azure DevOps authentication confirmed - can access projects"
                            } else {
                                Write-Warning "Azure DevOps authentication test failed"
                                Write-Info "You may need to run 'az devops login' for PAT token authentication"
                                Write-Info "Or ensure you have proper permissions for the Azure DevOps organization"
                            }
                        } catch {
                            Write-Warning "Error setting up Azure DevOps extension: $($_.Exception.Message)"
                        }
                        
                        return $true
                    } else {
                        Write-Warning "Could not verify login status"
                        return $false
                    }
                }
            } else {
                Write-Warning "Azure login failed with exit code: $loginExitCode"
                if ($loginOutput) {
                    Write-Info "Login output: $($loginOutput -join '; ')"
                }
                return $false
            }
            
        } catch {
            Write-Warning "Azure login failed: $($_.Exception.Message)"
            Write-Info "You can authenticate later by running 'az login'"
            return $false
        }
        
    } catch {
        Write-Warning "Authentication setup failed: $($_.Exception.Message)"
        return $false
    }
}

function Update-AzureCLI {
    param(
        [string]$Version = "latest",
        [switch]${what-if}
    )
    
    Write-Step "Upgrading Azure CLI..."
    
    # If what-if mode, show what would be done
    if (${what-if}) {
        Write-Host "what if: Would check current Azure CLI installation" -ForegroundColor Yellow
        Write-Host "what if: Would upgrade Azure CLI via winget" -ForegroundColor Yellow
        Write-Host "what if: Would refresh PATH environment variables" -ForegroundColor Yellow
        Write-Host "what if: Would verify upgraded installation and test functionality" -ForegroundColor Yellow
        return $true
    }
    
    try {
        # Check current installation
        $currentVersion = Get-ToolVersion "az"
        if (-not $currentVersion) {
            Write-Error "Azure CLI is not currently installed. Use install mode instead of upgrade."
            return $false
        }
        
        Write-Info "Current Azure CLI version: $currentVersion"
        
        # Check internet connection
        if (-not (Test-InternetConnection)) {
            Write-Error "Internet connection required for Azure CLI upgrade"
            return $false
        }
        
        # Check if winget is available
        if (-not (Test-Command "winget")) {
            Write-Error "winget is not available. Azure CLI upgrade requires Windows Package Manager (winget)."
            Write-Info "Please install winget from Microsoft Store or update Windows to get winget."
            return $false
        }
        
        Write-Progress "Upgrading Azure CLI via winget..."
        Write-Info "This may take several minutes. Please wait..."
        
        try {
            # Use winget to upgrade Azure CLI
            $process = Start-Process -FilePath "winget" -ArgumentList @(
                "upgrade", 
                "Microsoft.AzureCLI", 
                "--accept-package-agreements", 
                "--accept-source-agreements", 
                "--silent"
            ) -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Success "Azure CLI upgraded successfully via winget"
            } elseif ($process.ExitCode -eq -1978335189) {
                # This exit code often means "no updates available" in winget
                Write-Info "Azure CLI is already up to date (winget exit code: $($process.ExitCode))"
                Write-Success "No upgrade needed - Azure CLI is current"
                return $true
            } else {
                Write-Error "winget upgrade failed with exit code: $($process.ExitCode)"
                Write-Info "Please ensure winget is properly configured and try again."
                return $false
            }
        } catch {
            Write-Error "winget upgrade failed: $($_.Exception.Message)"
            return $false
        }
        
        # Update PATH and verify upgrade
        Write-Progress "Refreshing PATH and verifying Azure CLI upgrade..."
        
        # Comprehensive PATH refresh after upgrade
        Write-Info "Refreshing environment PATH after upgrade..."
        
        # Method 1: Refresh from environment variables
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + 
                   ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Method 2: Refresh from registry
        try {
            $machinePath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $userPath = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $env:PATH = $machinePath + ";" + $userPath
            Write-Info "PATH refreshed from registry"
        } catch {
            Write-Warning "Could not refresh PATH from registry: $($_.Exception.Message)"
        }
        
        # Wait for PATH changes to take effect
        Write-Info "Waiting for PATH changes to take effect..."
        Start-Sleep -Seconds 3
        
        # Verify upgrade using consolidated test function
        if (Test-AzureCLI -Detailed) {
            $newVersion = Get-ToolVersion "az"
            
            if ($newVersion -ne $currentVersion) {
                Write-Success "Azure CLI successfully upgraded from $currentVersion to $newVersion"
            } else {
                Write-Info "Azure CLI upgrade completed (version unchanged: $currentVersion)"
            }
            
            # Test Azure CLI functionality post-upgrade
            Write-Success "Azure CLI upgrade completed and verified successfully"
            return $true
        } else {
            Write-Warning "Azure CLI upgrade completed but verification failed"
            Write-Info "The upgrade may be successful but verification had issues"
            Write-Info "Try restarting your terminal or PowerShell session"
            return $false
        }
        
    } catch {
        Write-Error "Azure CLI upgrade failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-AzureCLI {
    param(
        [string]$Version = "latest",
        [switch]${check-only},
        [switch]${what-if},
        [switch]${upgrade-only}
    )
    
    # If upgrade-only mode, perform upgrade of existing installation
    if (${upgrade-only}) {
        return Update-AzureCLI -Version $Version -what-if:${what-if}
    }
    
    # If check-only mode, just test current installation with detailed output
    if (${check-only}) {
        $testResult = Test-AzureCLI -Detailed -PromptForUpgrade
        
        # If Azure CLI is installed, also check/setup authentication
        if ($testResult) {
            Write-Info "Azure CLI is installed. Checking authentication status..."
            if (${what-if}) {
                $authResult = Initialize-AzureAuthentication -what-if
            } else {
                $authResult = Initialize-AzureAuthentication
            }
            
            if ($authResult) {
                Write-Success "Azure CLI is installed and authenticated"
            } else {
                Write-Warning "Azure CLI is installed but authentication needs attention"
                Write-Info "You can complete authentication by running 'az login'"
            }
        }
        
        return $testResult
    }
    
    # If what-if mode, show what would be done
    if (${what-if}) {
        Write-Host "what if: Would test if Azure CLI is already installed" -ForegroundColor Yellow
        Write-Host "what if: Would check Azure CLI version compliance against requirements" -ForegroundColor Yellow
        Write-Host "what if: Would check and setup Azure authentication (az login)" -ForegroundColor Yellow
        Write-Host "what if: Would check internet connection" -ForegroundColor Yellow
        Write-Host "what if: Would install Azure CLI via winget (Windows Package Manager only)" -ForegroundColor Yellow
        Write-Host "what if: Would refresh PATH environment variables comprehensively" -ForegroundColor Yellow
        Write-Host "what if: Would verify installation and test Azure CLI functionality" -ForegroundColor Yellow
        Write-Host "what if: Would setup Azure authentication after installation" -ForegroundColor Yellow
        Write-Host "what if: Note: Installation will fail if winget is not available" -ForegroundColor Cyan
        return $true
    }
    
    Write-Step "Installing Azure CLI..."
    
    try {
        # Check if Azure CLI is already installed and compliant
        if (Test-AzureCLI) {
            Write-Success "Azure CLI installation confirmed and compliant"
            
            # Check and setup authentication for already installed Azure CLI
            Write-Info "Checking Azure authentication status..."
            if (${what-if}) {
                $authResult = Initialize-AzureAuthentication -what-if
            } else {
                $authResult = Initialize-AzureAuthentication
            }
            
            if ($authResult) {
                Write-Success "Azure CLI is installed and authenticated"
            } else {
                Write-Warning "Azure CLI is installed but authentication needs attention"
                Write-Info "You can complete authentication by running 'az login'"
            }
            
            return $true
        }
        
        # Check internet connection
        if (-not (Test-InternetConnection)) {
            Write-Error "Internet connection required for Azure CLI installation"
            return $false
        }
        
        Write-Progress "Attempting Azure CLI installation..."
        
        # Check if winget is available
        if (-not (Test-Command "winget")) {
            Write-Error "winget is not available. Azure CLI installation requires Windows Package Manager (winget)."
            Write-Info "Please install winget from Microsoft Store or update Windows to get winget."
            Write-Info "After installing winget, run this script again."
            return $false
        }
        
        # Install via winget only
        $installationSuccessful = $false
        
        try {
            Write-Info "Installing Azure CLI via winget..."
            Write-Info "This may take several minutes. Please wait..."
            
            # Use winget to install Azure CLI
            $process = Start-Process -FilePath "winget" -ArgumentList @(
                "install", 
                "Microsoft.AzureCLI", 
                "--accept-package-agreements", 
                "--accept-source-agreements", 
                "--silent"
            ) -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                $installationSuccessful = $true
                Write-Success "Azure CLI installed via winget"
            } elseif ($process.ExitCode -eq -1978335189) {
                # This exit code often means "already installed" in winget
                Write-Info "Azure CLI may already be installed (winget exit code: $($process.ExitCode))"
                Write-Info "Proceeding to verification..."
                $installationSuccessful = $true
            } else {
                Write-Error "winget installation failed with exit code: $($process.ExitCode)"
                Write-Info "Please ensure winget is properly configured and try again."
                return $false
            }
        } catch {
            Write-Error "winget installation failed: $($_.Exception.Message)"
            return $false
        }
        
        if (-not $installationSuccessful) {
            Write-Error "Azure CLI installation via winget failed"
            Write-Info "Please install Azure CLI manually: winget install Microsoft.AzureCLI"
            return $false
        }
        
        # Update PATH and verify installation
        Write-Progress "Refreshing PATH and verifying Azure CLI installation..."
        
        # Comprehensive PATH refresh after installation
        Write-Info "Refreshing environment PATH after installation..."
        
        # Method 1: Refresh from environment variables
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + 
                   ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Method 2: Refresh from registry
        try {
            $machinePath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $userPath = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment").GetValue("PATH", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $env:PATH = $machinePath + ";" + $userPath
            Write-Info "PATH refreshed from registry"
        } catch {
            Write-Warning "Could not refresh PATH from registry: $($_.Exception.Message)"
        }
        
        # Method 3: Check common Azure CLI installation locations and add to PATH if found
        $commonPaths = @(
            "${env:ProgramFiles}\Microsoft SDKs\Azure\CLI2\wbin",
            "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\CLI2\wbin",
            "${env:LOCALAPPDATA}\Programs\Azure CLI\wbin"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                Write-Info "Found Azure CLI installation at: $path"
                if ($env:PATH -notlike "*$path*") {
                    $env:PATH = $env:PATH + ";" + $path
                    Write-Info "Added to current session PATH: $path"
                }
            }
        }
        
        # Wait for PATH changes to take effect
        Write-Info "Waiting for PATH changes to take effect..."
        Start-Sleep -Seconds 5
        
        # Test if az command is now available
        Write-Info "Testing if 'az' command is available..."
        $azCommand = Get-Command "az" -ErrorAction SilentlyContinue
        if ($azCommand) {
            Write-Info "Found az command at: $($azCommand.Source)"
        } else {
            Write-Warning "az command not found in PATH after installation"
            Write-Info "Current PATH directories containing 'Azure' or 'CLI':"
            $env:PATH -split ';' | Where-Object { $_ -like '*Azure*' -or $_ -like '*CLI*' } | ForEach-Object { 
                if ($_.Trim()) { Write-Info "  - $_" }
            }
        }
        
        # Verify installation using consolidated test function
        if (Test-AzureCLI) {
            Write-Success "Azure CLI installation completed and verified successfully"
            
            # Initialize Azure authentication after successful installation
            Write-Info "Proceeding with Azure authentication setup..."
            if (${what-if}) {
                $authResult = Initialize-AzureAuthentication -what-if
            } else {
                $authResult = Initialize-AzureAuthentication
            }
            
            if ($authResult) {
                Write-Success "Azure CLI installation and authentication completed successfully"
            } else {
                Write-Warning "Azure CLI installed successfully but authentication setup had issues"
                Write-Info "You can complete authentication later by running 'az login'"
            }
            
            return $true
        } else {
            Write-Warning "Azure CLI was installed but verification failed"
            Write-Info "The installation may be successful but the 'az' command is not immediately available"
            Write-Info "Try one of the following:"
            Write-Info "1. Restart your terminal or PowerShell session"
            Write-Info "2. Run: refreshenv (if available)"
            Write-Info "3. Log out and log back in to Windows"
            Write-Info "4. Restart your computer"
            return $false
        }
        
    } catch {
        Write-Error "Azure CLI installation failed: $($_.Exception.Message)"
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
    if (${upgrade-only}) { $params['upgrade-only'] = $true }
    
    $result = Install-AzureCLI @params
    
    if ($result) {
        if (${check-only}) {
            Write-Success "Azure CLI test completed successfully"
        } elseif (${upgrade-only}) {
            Write-Success "Azure CLI upgrade completed successfully"
        } else {
            Write-CompletionSummary @{
                'Azure CLI Installation' = 'Completed Successfully'
                'Version' = (Get-ToolVersion "az")
                'Command Available' = if (Test-Command "az") { "Yes" } else { "No" }
            } -Title "Azure CLI Installation Summary"
        }
    } else {
        if (${check-only}) {
            Write-Error "Azure CLI test failed"
        } elseif (${upgrade-only}) {
            Write-Error "Azure CLI upgrade failed"
        } else {
            Write-Error "Azure CLI installation failed"
        }
    }
    
    # Return the result for the calling script
    return $result
}

# Export functions for module usage
Export-ModuleMember -Function @(
    'Install-AzureCLI',
    'Test-AzureCLI',
    'Initialize-AzureAuthentication',
    'Update-AzureCLI'
)

