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

function Invoke-Phase2-EnvironmentSetup {
    param(
        [int]$StartFromPhase = 1,
        [int]$EndAtPhase = 3,
        [int]$StartFromStage = 1,
        [int]$EndAtStage = 99,
        [string[]]$SkipStages = @(),
        [hashtable]$TargetStageInfo = $null
    )
    
    Write-Host "🛠️ Phase 2: Environment Prerequisites" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    
    try {
        # Import and execute Phase 2 script  
        $phase2Script = Join-Path $PhasesPath "02-environment-setup\phase-environment-prerequisites.ps1"
        . $phase2Script
        
        # Prepare parameters
        $params = @{}
        if ($Global:BootstrapExecutionContext.CheckOnly) { $params['CheckOnly'] = $true }
        if ($Global:BootstrapExecutionContext.WhatIf) { $params['WhatIf'] = $true }
        if ($Global:BootstrapExecutionContext.NoWSL) { $params['NoWSL'] = $true }
        if ($Global:BootstrapExecutionContext.ExecutionEngine) { $params['ExecutionEngine'] = $Global:BootstrapExecutionContext.ExecutionEngine }
        
        # Execute environment setup
        $result = Invoke-EnvironmentPrerequisites @params
        
        if ($result -and $result.Success) {
            return @{
                Success = $true
                Phase = "Environment Prerequisites"
                Message = $result.Message
                Details = $result.Details
                StartTime = $result.Details.StartTime
                EndTime = $result.Details.EndTime
                Duration = $result.Details.Duration
            }
        } else {
            return @{
                Success = $false
                Phase = "Environment Prerequisites"
                Message = if ($result) { $result.Message } else { "Environment prerequisites setup failed" }
                Details = if ($result) { $result.Details } else { @{} }
            }
        }
    } catch {
        Write-Error "Phase 2 execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Phase = "Environment Setup"
            Message = "Phase 2 execution failed: $($_.Exception.Message)"
            Details = @{
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}

function Invoke-Phase3-LoopBootstrap {
    param(
        [int]$StartFromPhase = 1,
        [int]$EndAtPhase = 3,
        [int]$StartFromStage = 1,
        [int]$EndAtStage = 99,
        [string[]]$SkipStages = @(),
        [hashtable]$TargetStageInfo = $null
    )
    
    Write-Host "🚀 Phase 3: Project Bootstrap" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    
    try {
        # Phase 3 has multiple stages, need to orchestrate them
        $phase3Results = @{}
        
        # Stage 1: Loop Selection
        $selectionScript = Join-Path $PhasesPath "03-project-bootstrap\selection\setup-loop-and-platform.ps1"
        . $selectionScript
        
        # Stage 2: Project Setup
        $projectScript = Join-Path $PhasesPath "03-project-bootstrap\project\setup-platform-project.ps1"
        . $projectScript
        
        # Execute loop selection and platform decision
        $selectionParams = @{}
        if ($Global:BootstrapExecutionContext.LoopName) {
            $selectionParams['ProvidedLoopName'] = $Global:BootstrapExecutionContext.LoopName
        }
        if ($Global:BootstrapExecutionContext.WhatIf) {
            $selectionParams['WhatIf'] = $true
        }
        if ($Global:BootstrapExecutionContext.NoWSL) {
            $selectionParams['NoWSL'] = $true
        }
        
        $selectionResult = Invoke-LoopDiscoveryAndSelection @selectionParams
        if (-not $selectionResult.Success) {
            throw "Loop selection failed: $($selectionResult.Message)"
        }
        
        # Update global context with selected loop
        if ($selectionResult.SelectedLoop) {
            $Global:BootstrapExecutionContext.LoopName = $selectionResult.SelectedLoop
            $Global:BootstrapExecutionContext.TargetPlatform = $selectionResult.TargetPlatform
        }
        
        # Execute project setup if loop was selected
        if ($Global:BootstrapExecutionContext.LoopName) {
            Write-Host ""
            Write-Host "🏗️ Phase 3: Project Setup" -ForegroundColor Cyan
            Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            
            $projectParams = @{
                LoopName = $Global:BootstrapExecutionContext.LoopName
                TargetPlatform = $Global:BootstrapExecutionContext.TargetPlatform
            }
            if ($Global:BootstrapExecutionContext.ProjectName) { 
                $projectParams['ProjectName'] = $Global:BootstrapExecutionContext.ProjectName 
            }
            if ($Global:BootstrapExecutionContext.ProjectPath) { 
                $projectParams['ProjectPath'] = $Global:BootstrapExecutionContext.ProjectPath 
            }
            if ($Global:BootstrapExecutionContext.WhatIf) { 
                $projectParams['what-if'] = $true 
            }
            if ($Global:BootstrapExecutionContext.CheckOnly) { 
                $projectParams['check-only'] = $true 
            }
            
            $projectResult = Initialize-PlatformSpecificProject @projectParams
            if (-not $projectResult.Success) {
                throw "Project setup failed: $($projectResult.Message)"
            }
            
            # Stage 3: Development Tools Integration
            Write-Host ""
            Write-Host "🔧 Phase 3: Development Tools" -ForegroundColor Cyan
            Write-Host "──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
            
            $toolsScript = Join-Path $PhasesPath "03-project-bootstrap\tools\setup-development-tools.ps1"
            . $toolsScript
            
            $toolsParams = @{
                TargetPlatform = $Global:BootstrapExecutionContext.TargetPlatform
                ProjectSetupData = $projectResult
                ProjectPath = $projectResult.ProjectPath
                ProjectName = $Global:BootstrapExecutionContext.ProjectName
                LoopName = $Global:BootstrapExecutionContext.LoopName
            }
            if ($Global:BootstrapExecutionContext.WhatIf) { $toolsParams['what-if'] = $true }
            if ($Global:BootstrapExecutionContext.CheckOnly) { $toolsParams['check-only'] = $true }
            
            $toolsResult = Initialize-DevelopmentToolsIntegration @toolsParams
            if (-not $toolsResult.Success) {
                Write-Warning "Development tools setup had issues: $($toolsResult.Message)"
                # Don't fail the entire process for tools issues
            }
        } else {
            Write-Warning "No loop selected - skipping project setup"
        }
        
        return @{
            Success = $true
            Phase = "Project Bootstrap"
            Message = "Project Bootstrap completed successfully"
            Details = @{
                SelectionResult = $selectionResult
                ProjectResult = if ($Global:BootstrapExecutionContext.LoopName) { $projectResult } else { $null }
                ToolsResult = if ($Global:BootstrapExecutionContext.LoopName) { $toolsResult } else { $null }
            }
        }
    } catch {
        Write-Error "Phase 3 execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Phase = "Project Bootstrap"
            Message = "Phase 3 execution failed: $($_.Exception.Message)"
            Details = @{
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}
