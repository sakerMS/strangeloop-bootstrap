# strangeloop Setup - Core Prerequisites Installation
# Version: 1.0.0
# Phase 1: Core Prerequisites Setup
# Purpose: Install essential tools required for strangeloop CLI functionality

param(
    [switch]${check-only},
    [switch]${what-if},
    [switch]${cli}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

function Install-CorePrerequisites {
    param(
        [switch]${check-only},
        [switch]${what-if},
        [switch]${cli}
    )
    
    # Check execution platform - Phase 1 only runs on Windows
    $currentPlatform = Get-CurrentPlatform
    if ($currentPlatform -ne "Windows") {
        Write-Host "ℹ️ Skipping Phase 1 (Core Prerequisites)" -ForegroundColor Yellow
        Write-Host "   Phase 1 'Core Prerequisites' is only executed on Windows execution platform." -ForegroundColor Gray
        Write-Host "   Current platform: $currentPlatform" -ForegroundColor Gray
        Write-Host "   This phase installs Windows-specific tools like Azure CLI via winget/chocolatey." -ForegroundColor Gray
        Write-Host "" -ForegroundColor Gray
        
        return @{
            Success = $true
            Skipped = $true
            Message = "Phase 1 skipped - only runs on Windows execution platform"
            Details = @{
                CurrentPlatform = $currentPlatform
                SkipReason = "Windows-only phase"
                StartTime = Get-Date
                EndTime = Get-Date
                Duration = "0 seconds (skipped)"
            }
        }
    }
    
    Write-Step "Setting up Core Prerequisites (Phase 1)..."
    Write-Info "Installing essential tools required for strangeloop CLI functionality"
    
    if (${what-if}) {
        Write-Host "what if: Would process the following core prerequisite tools:" -ForegroundColor Yellow
        if (-not ${cli}) {
            Write-Host "what if:   - Azure CLI (Required)" -ForegroundColor Yellow
            Write-Host "what if:   - strangeloop CLI (Required)" -ForegroundColor Yellow
        } else {
            Write-Host "what if:   - Azure CLI (Skipped - CLI mode)" -ForegroundColor Yellow
            Write-Host "what if:   - strangeloop CLI (Skipped - CLI mode)" -ForegroundColor Yellow
        }
        Write-Host "what if: Would test each tool and install if missing" -ForegroundColor Yellow
        return @{
            Success = $true
            Message = "Core prerequisites validation completed (what-if mode)"
            Details = @{
                Mode = "what-if"
                StartTime = Get-Date
                EndTime = Get-Date
                Duration = "0 seconds"
            }
        }
    }
    
    $results = @{}
    $overallSuccess = $true
    
    try {
        # Define core prerequisite tools (only essential for strangeloop CLI)
        $corePrerequisites = @()
        
        # Conditionally add Azure CLI and strangeloop CLI (skip if in CLI mode)
        if (-not ${cli}) {
            $corePrerequisites += @(
                @{
                    Name = "Azure CLI"
                    InstallScript = "azure-cli\install-azure-cli.ps1"
                    Required = $true
                    Description = "Required for Azure resource management"
                },
                @{
                    Name = "strangeloop CLI"
                    InstallScript = "strangeloop-cli\install-strangeloop-cli.ps1"
                    Required = $true
                    Description = "Core strangeloop command-line interface"
                }
            )
        } else {
            Write-Info "CLI mode detected - skipping Azure CLI and strangeloop CLI installation"
        }
        
        if ($corePrerequisites.Count -eq 0) {
            Write-Success "CLI mode: All core prerequisites are already available"
            return $true
        }
        
        Write-Info "Processing $($corePrerequisites.Count) core prerequisite tools..."
        
        foreach ($prereq in $corePrerequisites) {
            Write-Host ""
            Write-Progress "Processing $($prereq.Name)..."
            Write-Info $prereq.Description
            
            $toolSuccess = $false
            
            # Test current installation
            $installPath = Join-Path $PSScriptRoot $prereq.InstallScript
            if (Test-Path $installPath) {
                try {
                    Write-Info "Testing $($prereq.Name) installation..."
                    
                    # Prepare test parameters
                    $testParams = @{
                        'check-only' = $true
                    }
                    
                    # Add what-if parameter if supported
                    if (${what-if}) {
                        $testParams['what-if'] = $true
                    }
                    
                    $testResult = & $installPath @testParams
                    $testExitCode = $LASTEXITCODE
                    
                    # Check both return value and exit code
                    if ($testResult -eq $true -or ($testExitCode -eq 0 -and [string]::IsNullOrEmpty($testResult))) {
                        Write-Success "$($prereq.Name) is already installed and working"
                        $toolSuccess = $true
                        
                        # For tools with recommended_version: "latest", check for upgrades
                        if (-not ${check-only}) {
                            try {
                                $toolConfigName = $prereq.Name -replace ' ', '_' -replace '-', '_' | ForEach-Object { $_.ToLower() }
                                $versionConfig = Get-PrereqVersionConfig
                                
                                if ($versionConfig -and $versionConfig.ContainsKey($toolConfigName) -and 
                                    $versionConfig[$toolConfigName].ContainsKey('recommended_version') -and 
                                    $versionConfig[$toolConfigName]['recommended_version'] -eq 'latest') {
                                    
                                    Write-Info "Checking for $($prereq.Name) upgrades (recommended version is 'latest')..."
                                    
                                    # Call installation script without check-only for upgrade check
                                    $upgradeParams = @{}
                                    if (${what-if}) { $upgradeParams['what-if'] = $true }
                                    
                                    $upgradeResult = & $installPath @upgradeParams
                                    if ($upgradeResult -eq $true -or $LASTEXITCODE -eq 0) {
                                        Write-Success "$($prereq.Name) upgrade check completed"
                                    } else {
                                        Write-Warning "$($prereq.Name) upgrade check had issues but continuing"
                                    }
                                }
                            } catch {
                                Write-Warning "$($prereq.Name) upgrade check failed: $($_.Exception.Message)"
                            }
                        }
                    } else {
                        Write-Info "$($prereq.Name) test failed or not found (return: $testResult, exit: $testExitCode)"
                    }
                } catch {
                    Write-Warning "$($prereq.Name) test failed: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "Installation script not found for $($prereq.Name): $installPath"
            }
            
            # Install if not found and not in check-only mode
            if (-not $toolSuccess -and -not ${check-only}) {
                $installPath = Join-Path $PSScriptRoot $prereq.InstallScript
                if (Test-Path $installPath) {
                    try {
                        Write-Info "Installing $($prereq.Name)..."
                        
                        # Prepare installation parameters
                        $installParams = @{}
                        
                        # Add what-if parameter if supported
                        if (${what-if}) {
                            $installParams['what-if'] = $true
                        }
                        
                        $installResult = & $installPath @installParams
                        $installExitCode = $LASTEXITCODE
                        
                        # Check both return value and exit code
                        if ($installResult -eq $true -or ($installExitCode -eq 0 -and ($installResult -eq $null -or $installResult -eq ""))) {
                            Write-Success "$($prereq.Name) installed successfully"
                            $toolSuccess = $true
                        } else {
                            Write-Warning "$($prereq.Name) installation returned unexpected result (result: '$installResult', exit: $installExitCode)"
                        }
                    } catch {
                        Write-Warning "$($prereq.Name) installation failed: $($_.Exception.Message)"
                    }
                } else {
                    Write-Warning "Installation script not found for $($prereq.Name): $installPath"
                }
            }
            
            # Record result
            $results[$prereq.Name] = $toolSuccess
            
            # Check if required tool failed
            if ($prereq.Required -and -not $toolSuccess) {
                Write-Error "$($prereq.Name) is required but installation failed"
                $overallSuccess = $false
            }
        }
        
        # Summary
        Write-Host ""
        Write-Step "Core Prerequisites Installation Summary"
        
        if ($results.Count -gt 0) {
            foreach ($result in $results.GetEnumerator()) {
                $status = if ($result.Value) { "✓ Success" } else { "✗ Failed" }
                $color = if ($result.Value) { "Green" } else { "Red" }
                Write-Host "  $($result.Key): " -NoNewline
                Write-Host $status -ForegroundColor $color
            }
        } else {
            Write-Host "  No tools processed (CLI mode)" -ForegroundColor Yellow
        }
        
        if ($overallSuccess) {
            Write-Success "All required core prerequisites are ready"
            return @{
                Success = $true
                Message = "Core prerequisites setup completed successfully"
                Details = @{
                    Results = $results
                    StartTime = Get-Date
                    EndTime = Get-Date
                    Duration = "Setup completed"
                }
            }
        } else {
            Write-Error "Some required core prerequisites failed to install"
            return @{
                Success = $false
                Message = "Some required core prerequisites failed to install"
                Details = @{
                    Results = $results
                }
            }
        }
        
    } catch {
        Write-Error "Core prerequisites setup failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "Core prerequisites setup failed: $($_.Exception.Message)"
            Details = @{
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Build parameters dynamically
    $params = @{}
    if (${check-only}) { $params['check-only'] = $true }
    if (${what-if}) { $params['what-if'] = $true }
    if (${cli}) { $params['cli'] = $true }
    
    $result = Install-CorePrerequisites @params
    
    if ($result) {
        Write-Success "Core prerequisites setup completed successfully"
        return @{ Success = $true; Phase = "Core Prerequisites"; Message = "Core prerequisites setup completed successfully" }
    } else {
        Write-Error "Core prerequisites setup failed"
        return @{ Success = $false; Phase = "Core Prerequisites"; Message = "Core prerequisites setup failed" }
    }
}
