#Requires -Version 7.0

<#
.SYNOPSIS
    strangeloop Bootstrap Main Orchestrator

.DESCRIPTION
    Main entry point for the bootstrap system. Handles parameter processing,
    imports required modules, and orchestrates the execution flow.
#>

param(
    [string]${loop-name},
    [string]${project-name}, 
    [string]${project-path},
    [ValidateSet("core", "environment", "bootstrap", "full")]
    [string]$Mode = "full",
    [string]${start-from-phase},
    [string]${start-from-stage},
    [string]${only-stage},
    [string[]]${skip-stages} = @(),
    [switch]${what-if},
    [ValidateSet("StrangeloopCLI", "PowerShell")]
    [string]${execution-engine} = "StrangeloopCLI",
    [switch]${check-only},
    [switch]${no-wsl},
    [switch]${list-phases},
    [switch]${list-stages},
    [switch]${list-modes},
    [switch]$Help
)

# Import required modules
$BootstrapRoot = Split-Path $PSScriptRoot -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
$ConfigPath = Join-Path $BootstrapRoot "config"

# Import core libraries
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "display\display-functions.ps1") 
. (Join-Path $LibPath "platform\platform-functions.ps1")
. (Join-Path $BootstrapRoot "core\config.ps1")
. (Join-Path $BootstrapRoot "core\phase-orchestrator.ps1")

# Import configuration
$ConfigFile = Join-Path $ConfigPath "bootstrap_config.yaml"

# Initialize global variables
$Global:BootstrapConfig = @{}
$Global:BootstrapExecutionContext = @{
    Mode = $Mode
    WhatIf = ${what-if}
    CheckOnly = ${check-only}
    NoWSL = ${no-wsl}
    ExecutionEngine = ${execution-engine}
    LoopName = ${loop-name}
    ProjectName = ${project-name}
    ProjectPath = ${project-path}
}

# Handle help and informational parameters
if ($Help) {
    Show-CustomHelp
    return
}

if (${list-phases}) {
    Show-PhasesInfo
    return
}

if (${list-stages}) {
    Show-StagesInfo
    return
}

if (${list-modes}) {
    Show-ModesInfo
    return
}

# Load configuration
Initialize-BootstrapConfig -ConfigPath $ConfigFile

# Process execution parameters
$ExecutionParams = @{
    StartFromPhase = 1
    EndAtPhase = 3
    StartFromStage = 1
    EndAtStage = 99
    SkipStages = @()
    TargetStageInfo = $null
}

# Process stage parameters
if (${only-stage}) {
    $targetStageInfo = Get-StageInfo ${only-stage}
    if ($targetStageInfo) {
        $targetStageInfo.OriginalStageName = ${only-stage}
        $targetStageInfo.DirectTarget = $true
        $ExecutionParams.StartFromPhase = $targetStageInfo.Phase
        $ExecutionParams.EndAtPhase = $targetStageInfo.Phase
        $ExecutionParams.StartFromStage = $targetStageInfo.Stage
        $ExecutionParams.EndAtStage = $targetStageInfo.Stage
        $ExecutionParams.TargetStageInfo = $targetStageInfo
        
        if ($targetStageInfo.Subtype) {
            Write-Host "🎯 Direct targeting stage: ${only-stage} (Phase $($targetStageInfo.Phase), Stage $($targetStageInfo.Stage) - $($targetStageInfo.Subtype) only)" -ForegroundColor Cyan
        } else {
            Write-Host "🎯 Direct targeting stage: ${only-stage} (Phase $($targetStageInfo.Phase), Stage $($targetStageInfo.Stage): $($targetStageInfo.Name))" -ForegroundColor Cyan
        }
    }
} elseif (${start-from-stage}) {
    $targetStageInfo = Get-StageInfo ${start-from-stage}
    if ($targetStageInfo) {
        $ExecutionParams.StartFromPhase = $targetStageInfo.Phase
        $ExecutionParams.StartFromStage = $targetStageInfo.Stage
        $ExecutionParams.TargetStageInfo = $targetStageInfo
        
        if ($targetStageInfo.Subtype) {
            Write-Host "▶️  Starting from stage: ${start-from-stage} (Phase $($targetStageInfo.Phase), Stage $($targetStageInfo.Stage) - $($targetStageInfo.Subtype) only)" -ForegroundColor Yellow
        } else {
            Write-Host "▶️  Starting from stage: ${start-from-stage} (Phase $($targetStageInfo.Phase), Stage $($targetStageInfo.Stage): $($targetStageInfo.Name))" -ForegroundColor Yellow
        }
    }
}

# Process start-from-phase parameter
if (${start-from-phase}) {
    try {
        $phaseNumber = [int]${start-from-phase}
        if ($phaseNumber -ge 1 -and $phaseNumber -le 3) {
            $ExecutionParams.StartFromPhase = $phaseNumber
            Write-Host "▶️  Starting from phase: ${start-from-phase}" -ForegroundColor Yellow
        } else {
            Write-Error "Invalid phase number: ${start-from-phase}. Must be 1, 2, or 3."
            exit 1
        }
    } catch {
        Write-Error "Invalid phase number: ${start-from-phase}. Must be a valid integer (1, 2, or 3)."
        exit 1
    }
}

if (${skip-stages} -and @(${skip-stages}).Count -gt 0) {
    $ExecutionParams.SkipStages = ${skip-stages}
    Write-Host "⏭️  Skipping stages: $(${skip-stages} -join ', ')" -ForegroundColor Yellow
}

# Execute bootstrap process
if (${only-stage} -and $ExecutionParams.TargetStageInfo) {
    # Direct stage execution
    Invoke-DirectStageExecution -TargetStageInfo $ExecutionParams.TargetStageInfo
} else {
    # Normal phase-based execution
    Start-Setup @ExecutionParams
}

# Force exit to ensure process terminates (required when child processes may still be running)
[System.Environment]::Exit(0)
