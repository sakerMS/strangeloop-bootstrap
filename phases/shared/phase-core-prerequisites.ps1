# strangeloop Bootstrap - Phase 1: Core Prerequisites Module
# Version: 2.0.0
# Purpose: Consolidated Core Prerequisites setup for the new 3-phase architecture

# Import required modules
$BootstrapRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "platform\config-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

function Invoke-CorePrerequisites {
    <#
    .SYNOPSIS
    Executes Phase 1: Core Prerequisites setup in the new 3-phase architecture
    
    .DESCRIPTION
    Installs and configures essential tools required for all strangeloop development workflows:
    - Azure CLI (for Azure resource management and conditional access)
    - strangeloop CLI (core command-line interface)
    - PowerShell execution policy (Windows only)
    
    This function always performs the same execution flow regardless of how it's called.
    
    .PARAMETER CheckOnly
    Only validate current setup without making changes
    
    .PARAMETER WhatIf
    Show what would be performed without making any changes
    
    .OUTPUTS
    Hashtable with Success, Phase, Message, and Details properties
    
    .EXAMPLE
    Invoke-CorePrerequisites
    Run complete Phase 1 setup
    
    .EXAMPLE
    Invoke-CorePrerequisites -CheckOnly
    Validate Phase 1 prerequisites without installing
    
    .EXAMPLE
    Invoke-CorePrerequisites -WhatIf
    Show what would be performed without making any changes
    #>
    param(
        [switch]$CheckOnly,
        [switch]$WhatIf
    )
    
    try {
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
                Phase = "Core Prerequisites"
                Message = "Phase 1 skipped - only runs on Windows execution platform"
                Details = @{
                    CurrentPlatform = $currentPlatform
                    SkipReason = "Windows-only phase"
                    StartTime = Get-Date
                    EndTime = Get-Date
                    Duration = 0
                }
            }
        }
        
        Write-Step "Phase 1: Core Prerequisites Setup..."
        Write-Info "Installing essential tools required for all strangeloop development workflows"
        
        # Initialize result tracking
        $results = @{}
        $overallSuccess = $true
        $startTime = Get-Date
        
        # Get phase configuration
        $phaseConfig = Get-BootstrapPhases
        $phase1Config = $phaseConfig["1"]
        
        if ($WhatIf) {
            Write-Host ""
            Write-Host "=== PHASE 1: CORE PREREQUISITES (WHAT-IF MODE) ===" -ForegroundColor Yellow
            Write-Host "what if: Would process the following core prerequisite steps:" -ForegroundColor Yellow
            Write-Host "what if:   1. Azure CLI Setup" -ForegroundColor Yellow
            Write-Host "what if:      - Check current installation and version" -ForegroundColor Yellow
            Write-Host "what if:      - Install via winget/chocolatey/direct if missing" -ForegroundColor Yellow
            Write-Host "what if:      - Verify with 'az --version'" -ForegroundColor Yellow
            Write-Host "what if:      - Prompt for 'az login' if not authenticated" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if:   2. strangeloop CLI Setup" -ForegroundColor Yellow
            Write-Host "what if:      - Check current installation and version" -ForegroundColor Yellow
            Write-Host "what if:      - Install via package manager if missing" -ForegroundColor Yellow
            Write-Host "what if:      - Verify with 'strangeloop --version'" -ForegroundColor Yellow
            Write-Host "what if:      - Configure strangeloop CLI settings" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if:   3. PowerShell Execution Policy Setup (Windows only)" -ForegroundColor Yellow
            Write-Host "what if:      - Check current execution policy" -ForegroundColor Yellow
            Write-Host "what if:      - Set to 'RemoteSigned' if needed" -ForegroundColor Yellow
            Write-Host "what if:      - Verify policy change" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: Estimated duration: $($phase1Config.EstimatedDurationMinutes) minutes" -ForegroundColor Yellow
            Write-Host "what if: All steps can be executed independently" -ForegroundColor Yellow
            
            return @{
                Success = $true
                Phase = "Core Prerequisites"
                Message = "What-if completed for Phase 1: Core Prerequisites"
                Details = @{
                    EstimatedDuration = "$($phase1Config.EstimatedDurationMinutes) minutes"
                    Steps = @("Azure CLI", "strangeloop CLI", "PowerShell Policy")
                    StartTime = $startTime
                    EndTime = Get-Date
                    Duration = ((Get-Date) - $startTime).TotalSeconds
                }
            }
        }
        
        Write-Host ""
        Write-Host "=== PHASE 1: CORE PREREQUISITES ===" -ForegroundColor Cyan
        Write-Info "Essential tools for all strangeloop workflows"
        Write-Info "Estimated duration: $($phase1Config.EstimatedDurationMinutes) minutes"
        Write-Host ""
        
        # Step 1: Azure CLI Setup
        Write-Step "Step 1.1: Azure CLI Setup"
        Write-Info "Azure CLI is required for Azure resource management and conditional access compliance"
        
        try {
            $azureCliPath = Join-Path $BootstrapRoot "phases\01-core-prerequisites\azure-cli\install-azure-cli.ps1"
            
            if (Test-Path $azureCliPath) {
                $azureParams = @{
                    'check-only' = $CheckOnly
                }
                if ($WhatIf) { $azureParams['what-if'] = $WhatIf }
                
                $azureResult = & $azureCliPath @azureParams
                $azureSuccess = ($azureResult -eq $true) -or ($LASTEXITCODE -eq 0)
                
                if ($azureSuccess) {
                    Write-Success "Azure CLI setup completed successfully"
                    $results["Azure CLI"] = @{ Success = $true; Message = "Setup completed successfully" }
                } else {
                    Write-Warning "Azure CLI setup failed"
                    $results["Azure CLI"] = @{ Success = $false; Message = "Setup failed" }
                    $overallSuccess = $false
                }
            } else {
                Write-Warning "Azure CLI installation script not found: $azureCliPath"
                $results["Azure CLI"] = @{ Success = $false; Message = "Installation script not found" }
                $overallSuccess = $false
            }
        } catch {
            Write-Warning "Azure CLI setup failed: $($_.Exception.Message)"
            $results["Azure CLI"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
            $overallSuccess = $false
        }
        
        # Step 2: strangeloop CLI Setup
        Write-Step "Step 1.2: strangeloop CLI Setup"
        Write-Info "strangeloop CLI is the core command-line interface for project scaffolding and management"
        
        try {
            $strangeloopCliPath = Join-Path $BootstrapRoot "phases\01-core-prerequisites\strangeloop-cli\install-strangeloop-cli.ps1"
            
            if (Test-Path $strangeloopCliPath) {
                $strangeloopParams = @{
                    'check-only' = $CheckOnly
                }
                if ($WhatIf) { $strangeloopParams['what-if'] = $WhatIf }
                
                $strangeloopResult = & $strangeloopCliPath @strangeloopParams
                $strangeloopSuccess = ($strangeloopResult -eq $true) -or ($LASTEXITCODE -eq 0)
                
                if ($strangeloopSuccess) {
                    Write-Success "strangeloop CLI setup completed successfully"
                    $results["strangeloop CLI"] = @{ Success = $true; Message = "Setup completed successfully" }
                } else {
                    Write-Warning "strangeloop CLI setup failed"
                    $results["strangeloop CLI"] = @{ Success = $false; Message = "Setup failed" }
                    $overallSuccess = $false
                }
            } else {
                Write-Warning "strangeloop CLI installation script not found: $strangeloopCliPath"
                $results["strangeloop CLI"] = @{ Success = $false; Message = "Installation script not found" }
                $overallSuccess = $false
            }
        } catch {
            Write-Warning "strangeloop CLI setup failed: $($_.Exception.Message)"
            $results["strangeloop CLI"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
            $overallSuccess = $false
        }
        
        # Step 3: PowerShell Execution Policy Setup (Windows only)
        Write-Step "Step 1.3: PowerShell Execution Policy Setup"
        Write-Info "Configuring PowerShell execution policy for script execution (Windows only)"
        
        try {
            if ($IsWindows -or $env:OS -eq "Windows_NT") {
                if (-not $CheckOnly -and -not $WhatIf) {
                    # Check current execution policy
                    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
                    Write-Info "Current execution policy (CurrentUser): $currentPolicy"
                    
                    if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
                        Write-Info "Setting execution policy to RemoteSigned for current user..."
                        try {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                            $newPolicy = Get-ExecutionPolicy -Scope CurrentUser
                            Write-Success "PowerShell execution policy set to: $newPolicy"
                            $results["PowerShell Policy"] = @{ Success = $true; Message = "Set to $newPolicy" }
                        } catch {
                            Write-Warning "Failed to set execution policy: $($_.Exception.Message)"
                            $results["PowerShell Policy"] = @{ Success = $false; Message = "Failed to set policy" }
                        }
                    } else {
                        Write-Success "PowerShell execution policy is already properly configured: $currentPolicy"
                        $results["PowerShell Policy"] = @{ Success = $true; Message = "Already configured ($currentPolicy)" }
                    }
                } else {
                    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
                    Write-Success "PowerShell execution policy check completed: $currentPolicy"
                    $results["PowerShell Policy"] = @{ Success = $true; Message = "Current policy: $currentPolicy" }
                }
            } else {
                Write-Info "PowerShell execution policy setup not needed on this platform"
                $results["PowerShell Policy"] = @{ Success = $true; Message = "Not needed on this platform" }
            }
        } catch {
            Write-Warning "PowerShell execution policy setup failed: $($_.Exception.Message)"
            $results["PowerShell Policy"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
        }
        
        # Calculate timing
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        # Display summary
        Write-Host ""
        Write-Step "Phase 1: Core Prerequisites Summary"
        Write-Info "Execution time: $($duration.TotalSeconds.ToString("F1")) seconds"
        Write-Host ""
        
        foreach ($result in $results.GetEnumerator()) {
            $status = if ($result.Value.Success) { "✓ Success" } else { "✗ Failed" }
            $color = if ($result.Value.Success) { "Green" } else { "Red" }
            Write-Host "  $($result.Key): " -NoNewline
            Write-Host $status -ForegroundColor $color
            if ($result.Value.Message) {
                Write-Host "    $($result.Value.Message)" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        
        if ($overallSuccess) {
            if ($CheckOnly) {
                Write-Success "Phase 1 validation completed successfully - all core prerequisites are ready"
            } else {
                Write-Success "Phase 1 completed successfully - all core prerequisites are ready"
            }
        } else {
            if ($CheckOnly) {
                Write-Error "Phase 1 validation failed - some core prerequisites are missing or misconfigured"
            } else {
                Write-Error "Phase 1 failed - some core prerequisites could not be installed or configured"
            }
        }
        
        return @{
            Success = $overallSuccess
            Phase = "Core Prerequisites"
            Message = if ($overallSuccess) { 
                "Phase 1 completed successfully" 
            } else { 
                "Phase 1 failed - check individual step results" 
            }
            Details = @{
                Results = $results
                Duration = $duration.TotalSeconds
                StartTime = $startTime
                EndTime = $endTime
                CheckOnly = $CheckOnly.IsPresent
                StepsExecuted = $results.Keys.Count
            }
        }
        
    } catch {
        Write-Error "Phase 1 (Core Prerequisites) failed with error: $($_.Exception.Message)"
        return @{
            Success = $false
            Phase = "Core Prerequisites"
            Message = "Phase 1 failed with error: $($_.Exception.Message)"
            Details = @{
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}

function Test-CorePrerequisites {
    <#
    .SYNOPSIS
    Tests if all core prerequisites are properly installed and configured
    
    .DESCRIPTION
    Validates Phase 1 components without making any changes
    
    .OUTPUTS
    Hashtable with validation results
    #>
    param()
    
    return Invoke-CorePrerequisites -CheckOnly
}

function Get-CorePrerequisitesStatus {
    <#
    .SYNOPSIS
    Gets the current status of all core prerequisites
    
    .DESCRIPTION
    Returns detailed status information about each core prerequisite component
    
    .OUTPUTS
    Hashtable with detailed status information
    #>
    param()
    
    $status = @{
        AzureCLI = @{ Installed = $false; Version = $null; Authenticated = $false }
        StrangeloopCLI = @{ Installed = $false; Version = $null }
        PowerShellPolicy = @{ Current = $null; Adequate = $false }
    }
    
    try {
        # Check Azure CLI
        try {
            $azVersion = az --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $azVersion) {
                $status.AzureCLI.Installed = $true
                if ($azVersion -match "azure-cli\s+(\d+\.\d+\.\d+)") {
                    $status.AzureCLI.Version = $matches[1]
                }
                
                # Check authentication
                $azAccount = az account show 2>$null
                $status.AzureCLI.Authenticated = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($azAccount))
            }
        } catch {
            # Azure CLI not available
        }
        
        # Check strangeloop CLI
        try {
            $slVersion = strangeloop --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $slVersion) {
                $status.StrangeloopCLI.Installed = $true
                if ($slVersion -match "(\d+\.\d+\.\d+)") {
                    $status.StrangeloopCLI.Version = $matches[1]
                }
            }
        } catch {
            # strangeloop CLI not available
        }
        
        # Check PowerShell execution policy (Windows only)
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            try {
                $policy = Get-ExecutionPolicy -Scope CurrentUser
                $status.PowerShellPolicy.Current = $policy
                $status.PowerShellPolicy.Adequate = ($policy -ne "Restricted" -and $policy -ne "Undefined")
            } catch {
                $status.PowerShellPolicy.Current = "Unknown"
            }
        } else {
            $status.PowerShellPolicy.Current = "Not applicable"
            $status.PowerShellPolicy.Adequate = $true
        }
        
    } catch {
        Write-Warning "Error checking core prerequisites status: $($_.Exception.Message)"
    }
    
    return $status
}

# Export functions when used as a module
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Invoke-CorePrerequisites',
        'Test-CorePrerequisites', 
        'Get-CorePrerequisitesStatus'
    )
}
