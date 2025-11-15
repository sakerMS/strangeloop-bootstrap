#Requires -Version 7.0

<#
.SYNOPSIS
    Phase Orchestrator for strangeloop Bootstrap

.DESCRIPTION
    Handles the execution and orchestration of bootstrap phases,
    including phase validation, timing, and error handling.
#>

# Import phase wrapper functions
. (Join-Path $PSScriptRoot "phase-wrappers.ps1")

# Import shared display functions
$LibPath = Join-Path (Split-Path $PSScriptRoot -Parent) "lib"
. (Join-Path $LibPath "display\display-functions.ps1")

function Start-Setup {
    <#
    .SYNOPSIS
        Main setup orchestration function
    
    .PARAMETER StartFromPhase
        Phase number to start from (1-3)
    
    .PARAMETER EndAtPhase
        Phase number to end at (1-3)
    
    .PARAMETER StartFromStage
        Stage number to start from
    
    .PARAMETER EndAtStage
        Stage number to end at
    
    .PARAMETER SkipStages
        Array of stage names to skip
    
    .PARAMETER TargetStageInfo
        Specific stage information for targeted execution
    #>
    param(
        [int]$StartFromPhase = 1,
        [int]$EndAtPhase = 3,
        [int]$StartFromStage = 1,
        [int]$EndAtStage = 99,
        [string[]]$SkipStages = @(),
        [hashtable]$TargetStageInfo = $null
    )
    
    $startTime = Get-Date
    $phaseResults = @{}
    
    # Initialize global variable for CLI modules execution tracking
    $global:CliModulesExecuted = $null
    
    try {
        Show-Banner -Version (Get-BootstrapScriptVersion)
        
        # Determine execution mode and phase range
        $phaseRange = Get-PhaseRangeForMode -Mode $Global:BootstrapExecutionContext.Mode
        $minPhase = $phaseRange.MinPhase
        $maxPhase = $phaseRange.MaxPhase
        
        # Handle start-from-phase parameter
        if ($StartFromPhase -gt 1) {
            $minPhase = [math]::Max($minPhase, $StartFromPhase)
            Write-Host "⏭️  Starting from Phase $StartFromPhase" -ForegroundColor Yellow
        }

        # Handle target stage info - set phase boundaries to target only the specific phase
        if ($TargetStageInfo) {
            $targetPhase = $TargetStageInfo.Phase
            $minPhase = $targetPhase
            $maxPhase = $targetPhase
            Write-Host "🎯 Targeting only Phase $targetPhase for stage execution" -ForegroundColor Yellow
        }
        
        Write-Host ""
        
        # Set execution policy
        Set-PowerShellExecutionPolicy
        
        # Validate stage-specific prerequisites if targeting specific stages
        if ($TargetStageInfo) {
            Test-TargetStagePrerequisites -TargetStageInfo $TargetStageInfo
        }
        
        # Execute phases based on mode and parameters
        $phaseResults = Invoke-BootstrapPhases -MinPhase $minPhase -MaxPhase $maxPhase -StartFromPhase $StartFromPhase -EndAtPhase $EndAtPhase -StartFromStage $StartFromStage -EndAtStage $EndAtStage -SkipStages $SkipStages -TargetStageInfo $TargetStageInfo
        
        # Handle completion based on mode
        if ($Global:BootstrapExecutionContext.Mode -eq "setup-only") {
            Show-SetupOnlyCompletion -PhaseResults $phaseResults -StartTime $startTime
            return
        }
        
        # Show final summary
        Show-FinalSummary -PhaseResults $phaseResults -StartTime $startTime -Mode $Global:BootstrapExecutionContext.Mode
        
    } catch {
        Write-Error "Critical error during setup: $($_.Exception.Message)"
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        
        $endTime = Get-Date
        $totalDuration = $endTime - $startTime
        Write-Host "⏱️  Duration before failure: $([math]::Round($totalDuration.TotalMinutes, 1)) minutes" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

function Get-PhaseRangeForMode {
    <#
    .SYNOPSIS
        Gets the phase range for a given execution mode
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Mode
    )
    
    switch ($Mode) {
        "core" {
            Write-Host "📋 Core Prerequisites Mode" -ForegroundColor Cyan
            Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            Write-Host "Installing only core prerequisites (Phase 1 only)" -ForegroundColor White
            return @{ MinPhase = 1; MaxPhase = 1 }
        }
        "environment" {
            Write-Host "🔧 Environment Prerequisites Mode" -ForegroundColor Cyan
            Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            Write-Host "Setting up development environment only (Phase 2 only)" -ForegroundColor White
            return @{ MinPhase = 2; MaxPhase = 2 }
        }
        "bootstrap" {
            Write-Host "🚀 Project Bootstrap Mode" -ForegroundColor Cyan
            Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            Write-Host "Creating project only (Phase 3, assumes environment ready)" -ForegroundColor White
            return @{ MinPhase = 3; MaxPhase = 3 }
        }
        default {  # "full"
            Write-Host "🌟 Full Setup Mode" -ForegroundColor Cyan
            Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            Write-Host "Complete development environment and project setup (All phases)" -ForegroundColor White
            return @{ MinPhase = 1; MaxPhase = 3 }
        }
    }
}

function Set-PowerShellExecutionPolicy {
    <#
    .SYNOPSIS
        Sets the PowerShell execution policy if needed
    #>
    
    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
            Write-Host "🔐 Setting PowerShell execution policy..." -ForegroundColor Yellow
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "✓ PowerShell execution policy set to RemoteSigned for current user" -ForegroundColor Green
        } else {
            Write-Host "✓ PowerShell execution policy is already configured ($currentPolicy)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Could not set execution policy: $($_.Exception.Message)"
        Write-Warning "You may need to run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    }
    Write-Host ""
}

function Test-TargetStagePrerequisites {
    <#
    .SYNOPSIS
        Tests prerequisites for a targeted stage
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$TargetStageInfo
    )
    
    $stageParams = @{}
    if ($Global:BootstrapExecutionContext.LoopName) { 
        $stageParams['loop-name'] = $Global:BootstrapExecutionContext.LoopName 
    }
    
    # Check prerequisites for the targeted stage
    $stageName = if ($TargetStageInfo.Subtype) { $TargetStageInfo.Subtype } else { $TargetStageInfo.OriginalStageName }
    $prerequisitesValid = Test-StagePrerequisites -StageName $stageName -TargetStageInfo $TargetStageInfo -StageParams $stageParams
    if (-not $prerequisitesValid) {
        throw "❌ Prerequisites validation failed for '$stageName' stage"
    }
}

function Invoke-BootstrapPhases {
    <#
    .SYNOPSIS
        Executes the bootstrap phases based on the specified range
    #>
    param(
        [int]$MinPhase,
        [int]$MaxPhase,
        [int]$StartFromPhase,
        [int]$EndAtPhase,
        [int]$StartFromStage,
        [int]$EndAtStage,
        [string[]]$SkipStages,
        [hashtable]$TargetStageInfo
    )
    
    $phaseResults = @{}
    
    # Phase 1: Core Prerequisites
    if ($MinPhase -le 1 -and $MaxPhase -ge 1) {
        $phaseStartTime = Get-Date
        $phaseResults['Phase1_CorePrerequisites'] = Invoke-Phase1-CorePrerequisites -StartFromPhase $StartFromPhase -EndAtPhase $EndAtPhase -StartFromStage $StartFromStage -EndAtStage $EndAtStage -SkipStages $SkipStages -TargetStageInfo $TargetStageInfo
        $phaseEndTime = Get-Date
        $phaseResults['Phase1_CorePrerequisites'] = Add-PhaseTimingInfo -PhaseResult $phaseResults['Phase1_CorePrerequisites'] -StartTime $phaseStartTime -EndTime $phaseEndTime
        
        if ($phaseResults['Phase1_CorePrerequisites'] -and -not $phaseResults['Phase1_CorePrerequisites'].Success) {
            Write-Error "Core prerequisites failed - cannot continue"
            Show-PrerequisiteFailureGuidance
            exit 1
        }
    }
    
    # Phase 2: Environment Prerequisites
    if ($MinPhase -le 2 -and $MaxPhase -ge 2) {
        $phaseStartTime = Get-Date
        $phaseResults['Phase2_EnvironmentSetup'] = Invoke-Phase2-EnvironmentSetup -StartFromPhase $StartFromPhase -EndAtPhase $EndAtPhase -StartFromStage $StartFromStage -EndAtStage $EndAtStage -SkipStages $SkipStages -TargetStageInfo $TargetStageInfo
        $phaseEndTime = Get-Date
        $phaseResults['Phase2_EnvironmentSetup'] = Add-PhaseTimingInfo -PhaseResult $phaseResults['Phase2_EnvironmentSetup'] -StartTime $phaseStartTime -EndTime $phaseEndTime
        
        if ($phaseResults['Phase2_EnvironmentSetup'] -and -not $phaseResults['Phase2_EnvironmentSetup'].Success) {
            Write-Error "Environment prerequisites setup failed - cannot continue"
            Show-PrerequisiteFailureGuidance
            exit 1
        }
    }
    
    # Phase 3: Project Bootstrap
    if ($MinPhase -le 3 -and $MaxPhase -ge 3) {
        # Check if we should prompt for project creation continuation
        if (Test-ShouldPromptForProjectContinuation -Mode $Global:BootstrapExecutionContext.Mode -PhaseResults $phaseResults) {
            $shouldContinue = Get-ProjectContinuationChoice
            if (-not $shouldContinue) {
                Show-EnvironmentSetupCompletion
                return $phaseResults
            }
        }
        
        $phaseStartTime = Get-Date
        $phaseResults['Phase3_LoopBootstrap'] = Invoke-Phase3-LoopBootstrap -StartFromPhase $StartFromPhase -EndAtPhase $EndAtPhase -StartFromStage $StartFromStage -EndAtStage $EndAtStage -SkipStages $SkipStages -TargetStageInfo $TargetStageInfo
        $phaseEndTime = Get-Date
        $phaseResults['Phase3_LoopBootstrap'] = Add-PhaseTimingInfo -PhaseResult $phaseResults['Phase3_LoopBootstrap'] -StartTime $phaseStartTime -EndTime $phaseEndTime
        
        if ($phaseResults['Phase3_LoopBootstrap'] -and -not $phaseResults['Phase3_LoopBootstrap'].Success) {
            Write-Warning "Project Bootstrap had issues but continuing..."
        }
    }
    
    return $phaseResults
}

function Test-ShouldPromptForProjectContinuation {
    <#
    .SYNOPSIS
        Determines if we should prompt the user to continue with project creation
    #>
    param(
        [string]$Mode,
        [hashtable]$PhaseResults
    )
    
    # Prompt conditions:
    # 1. Must be in full mode
    # 2. No stage targeting parameters used
    # 3. Phase 2 completed successfully
    return ($Mode -eq "full" -and 
            -not $Global:BootstrapExecutionContext.StartFromPhase -and 
            -not $Global:BootstrapExecutionContext.OnlyStage -and 
            -not $Global:BootstrapExecutionContext.StartFromStage -and 
            (-not $Global:BootstrapExecutionContext.SkipStages -or @($Global:BootstrapExecutionContext.SkipStages).Count -eq 0) -and 
            $PhaseResults['Phase2_EnvironmentSetup'] -and 
            $PhaseResults['Phase2_EnvironmentSetup'].Success)
}

function Get-ProjectContinuationChoice {
    <#
    .SYNOPSIS
        Prompts the user to decide whether to continue with project creation
    #>
    
    Write-Host ""
    Write-Host "🎉 Environment Prerequisites Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your development environment is now configured." -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 Continue with Project Setup?" -ForegroundColor Cyan
    Write-Host "────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
    
    do {
        $response = Read-Host "Would you like to continue with project creation? (y/n)"
        $response = $response.Trim().ToLower()
    } while ($response -ne 'y' -and $response -ne 'n' -and $response -ne 'yes' -and $response -ne 'no')
    
    if ($response -eq 'n' -or $response -eq 'no') {
        return $false
    }
    
    Write-Host ""
    Write-Host "🚀 Continuing with Project Setup..." -ForegroundColor Green
    Write-Host ""
    return $true
}

function Show-EnvironmentSetupCompletion {
    <#
    .SYNOPSIS
        Shows completion message when user chooses not to continue with project creation
    #>
    
    Write-Host ""
    Write-Host "✅ Environment Prerequisites Complete!" -ForegroundColor Green
    Write-Host "─────────────────────────────────" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔗 To create a project later, run:" -ForegroundColor Cyan
    Write-Host "   .\main.ps1 -Mode project-only -loop-name <loop-name> -project-name <project-name>" -ForegroundColor Green
    Write-Host ""
}

function Add-PhaseTimingInfo {
    <#
    .SYNOPSIS
        Adds timing information to a phase result
    #>
    param(
        [hashtable]$PhaseResult,
        [datetime]$StartTime,
        [datetime]$EndTime
    )
    
    if (-not $PhaseResult) {
        $PhaseResult = @{}
    }
    
    $PhaseResult.StartTime = $StartTime
    $PhaseResult.EndTime = $EndTime
    $PhaseResult.Duration = $EndTime - $StartTime
    
    return $PhaseResult
}

function Show-PrerequisiteFailureGuidance {
    <#
    .SYNOPSIS
        Shows guidance when prerequisites fail
    #>
    
    Write-Host ""
    Write-Host "🚨 SETUP FAILED: Prerequisites Installation Failed" -ForegroundColor Red
    Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "❌ One or more required prerequisites failed to install." -ForegroundColor Yellow
    Write-Host "   The setup cannot continue without these essential tools." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔧 To resolve this issue:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   1. Review the error messages above for specific failed tools" -ForegroundColor White
    Write-Host "   2. Manually install any failed required tools" -ForegroundColor White
    Write-Host "   3. Restart your terminal/PowerShell session" -ForegroundColor White
    Write-Host "   4. Re-run this setup script" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Common fixes:" -ForegroundColor Cyan
    Write-Host "   • For WSL issues: wsl --install -d Ubuntu-24.04" -ForegroundColor White
    Write-Host "   • For Python issues: Download from python.org" -ForegroundColor White
    Write-Host "   • For Git issues: Download from git-scm.com" -ForegroundColor White
    Write-Host "   • For Docker issues: Download Docker Desktop" -ForegroundColor White
    Write-Host ""
    Write-Host "🏃‍♂️ Quick workaround:" -ForegroundColor Cyan
    Write-Host "   • Skip WSL temporarily: strangeloop cli prereqs --no-wsl" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Alternative: Try running with administrator privileges" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔄 Once tools are installed, restart this script:" -ForegroundColor Green
    Write-Host "   .\main.ps1" -ForegroundColor Green
    Write-Host ""
}
