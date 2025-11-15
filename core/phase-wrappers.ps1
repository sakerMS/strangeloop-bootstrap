# Phase Wrapper Functions
# This file contains the main phase orchestration functions that coordinate
# the execution of individual phase scripts and stages

# Import shared functions first
$LibPath = Join-Path (Split-Path $PSScriptRoot) "lib"
$PhasesPath = Join-Path (Split-Path $PSScriptRoot) "phases"

# Import shared validation and display functions - check if files exist before importing
$validationFunctionsPath = Join-Path $LibPath "validation\validation-functions.ps1"
$displayFunctionsPath = Join-Path $LibPath "display\display-functions.ps1"
$writeFunctionsPath = Join-Path $LibPath "display\write-functions.ps1"

if (Test-Path $validationFunctionsPath) {
    . $validationFunctionsPath
}
if (Test-Path $displayFunctionsPath) {
    . $displayFunctionsPath  
}
if (Test-Path $writeFunctionsPath) {
    . $writeFunctionsPath
}

function Invoke-Phase1-CorePrerequisites {
    param(
        [int]$StartFromPhase = 1,
        [int]$EndAtPhase = 3,
        [int]$StartFromStage = 1,
        [int]$EndAtStage = 99,
        [string[]]$SkipStages = @(),
        [hashtable]$TargetStageInfo = $null
    )
    
    Write-Host "📋 Phase 1: Core Prerequisites" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    
    try {
        # Import and execute Phase 1 script
        $phase1Script = Join-Path $PhasesPath "01-core-prerequisites\setup-core-prerequisites.ps1"
        . $phase1Script
        
        # Prepare parameters
        $params = @{}
        if ($Global:BootstrapExecutionContext.CheckOnly) { $params['check-only'] = $true }
        if ($Global:BootstrapExecutionContext.WhatIf) { $params['what-if'] = $true }
        
        # Execute core prerequisites installation
        $result = Install-CorePrerequisites @params
        
        if ($result -and $result.Success) {
            return @{
                Success = $true
                Phase = "Core Prerequisites"
                Message = $result.Message
                Details = $result.Details
                Skipped = if ($result.Skipped) { $result.Skipped } else { $false }
                StartTime = $result.Details.StartTime
                EndTime = $result.Details.EndTime
                Duration = $result.Details.Duration
            }
        } else {
            return @{
                Success = $false
                Phase = "Core Prerequisites" 
                Message = if ($result) { $result.Message } else { "Core prerequisites setup failed" }
                Details = if ($result) { $result.Details } else { @{} }
            }
        }
    } catch {
        Write-Error "Phase 1 execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Phase = "Core Prerequisites"
            Message = "Phase 1 execution failed: $($_.Exception.Message)"
            Details = @{
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}