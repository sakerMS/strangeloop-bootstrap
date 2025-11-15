# strangeloop Setup - Shared Phase Functions
# Version: 1.0.0


# Phase management and execution functions

function Invoke-Phase {
    <#
    .SYNOPSIS
        Generic phase execution with standardized error handling and result processing
    
    .PARAMETER PhaseName
        The name of the phase to execute
    
    .PARAMETER PhaseModule
        The module that contains the phase function
    
    .PARAMETER Arguments
        Arguments to pass to the phase function
    
    .PARAMETER Context
        The execution context (session settings, results, etc.)
    
    .RETURNS
        Hashtable with execution results
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PhaseName,
        
        [Parameter(Mandatory)]
        [string]$PhaseModule,
        
        [hashtable]$Arguments = @{},
        
        [hashtable]$Context = @{}
    )
    
    Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "  EXECUTING PHASE: $($PhaseName.ToUpper())" -ForegroundColor Blue
    Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
    
    if ($Arguments -and $Arguments.Count -gt 0) {
        Write-Host "   Arguments passed to phase:" -ForegroundColor Yellow
        foreach ($key in $Arguments.Keys) {
            $value = $Arguments[$key]
            # Handle potentially sensitive values or complex objects
            if ($value -is [string] -or $value -is [int] -or $value -is [bool]) {
                Write-Host "     $key = $value" -ForegroundColor Gray
            } elseif ($value -is [switch]) {
                Write-Host "     $key = $($value.IsPresent)" -ForegroundColor Gray
            } elseif ($value -is [hashtable]) {
                Write-Host "     $key = [Hashtable with $($value.Count) items]" -ForegroundColor Gray
                if ($value.Count -le 5) {
                    foreach ($subKey in $value.Keys) {
                        Write-Host "       $subKey = $($value[$subKey])" -ForegroundColor DarkGray
                    }
                }
            } elseif ($value -is [array]) {
                Write-Host "     $key = [Array with $($value.Count) items: $($value -join ', ')]" -ForegroundColor Gray
            } else {
                Write-Host "     $key = [$($value.GetType().Name)] $value" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   No arguments passed to phase" -ForegroundColor Yellow
    }
    
    if ($Context -and $Context.Count -gt 0) {
        Write-Host "   Context items available:" -ForegroundColor Yellow
        foreach ($key in $Context.Keys) {
            Write-Host "     Context.$key" -ForegroundColor Gray
        }
    }
    Write-Host "" # Empty line for readability
    
    try {
        # Import the phase module
        $moduleBasePath = $PSScriptRoot.Replace('\shared', '')
        $modulePath = Join-Path $moduleBasePath $PhaseModule "Invoke-$PhaseName.ps1"
        
        if (-not (Test-Path $modulePath)) {
            throw "Phase module not found: $modulePath"
        }
        
        # Dot source the phase module
        . $modulePath
        
        # Execute the phase function
        $functionName = "Invoke-$PhaseName"
        $phaseResult = & $functionName @Arguments
        
        # Validate result structure
        if ($phaseResult -is [hashtable] -and $phaseResult.ContainsKey('Success')) {
            if ($phaseResult.Success) {
                Write-Host "✓ Phase '$PhaseName' completed successfully" -ForegroundColor Green
                
                # Store result in context for next phases
                if ($Context.ContainsKey('Results')) {
                    $Context.Results[$PhaseName] = $phaseResult
                }
                
                return $phaseResult
            } else {
                Write-Error "Phase '$PhaseName' failed: $($phaseResult.Message)"
                throw "Phase execution failed"
            }
        } else {
            Write-Warning "Phase '$PhaseName' returned unexpected result format"
            return @{ Success = $true; Phase = $PhaseName; Result = $phaseResult }
        }
    } catch {
        Write-Error "Error executing phase '$PhaseName': $($_.Exception.Message)"
        Write-Error "Stack trace: $($_.ScriptStackTrace)"
        
        return @{
            Success = $false
            Phase = $PhaseName
            Error = $_.Exception.Message
            StackTrace = $_.ScriptStackTrace
        }
    }
}

function Test-ShouldRunPhase {
    <#
    .SYNOPSIS
        Tests if a phase should be executed based on targeting parameters
    
    .PARAMETER PhaseName
        The name of the phase to test
    
    .PARAMETER OnlyPhase
        Run only this specific phase
    
    .PARAMETER FromPhase
        Start execution from this phase and continue through the end
    
    .PARAMETER SkipPhases
        Array of phases to skip
    
    .PARAMETER TargetPhases
        Legacy parameter - array of phases to target (empty means all phases)
    
    .RETURNS
        Boolean indicating if the phase should run
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PhaseName,
        
        [string]$OnlyPhase = '',
        
        [string]$FromPhase = '',
        
        [string[]]$SkipPhases = @(),
        
        [string[]]$TargetPhases = @()
    )
    
    # Get all phases for range validation
    $allPhases = @(
        'prerequisites', 'authentication', 'loop-selection', 'environment', 
        'wsl', 'project', 'git', 'pipelines', 'vscode', 'completion'
    )
    
    # First, check if this phase should be skipped
    if ($SkipPhases -and $SkipPhases.Count -gt 0 -and $PhaseName -in $SkipPhases) {
        return $false
    }
    
    # If only-phase is specified, run only that phase
    if (-not [string]::IsNullOrEmpty($OnlyPhase)) {
        return $PhaseName -eq $OnlyPhase
    }
    
    # If from-phase is specified, run from that phase onwards
    if (-not [string]::IsNullOrEmpty($FromPhase)) {
        $phaseIndex = $allPhases.IndexOf($PhaseName)
        $fromIndex = $allPhases.IndexOf($FromPhase)
        
        if ($phaseIndex -eq -1) {
            Write-Warning "Unknown phase: $PhaseName"
            return $false
        }
        
        if ($fromIndex -eq -1) {
            Write-Warning "Unknown from-phase: $FromPhase"
            return $false
        }
        
        return $phaseIndex -ge $fromIndex
    }
    
    # Legacy support: If specific phases are targeted, only run those
    if ($TargetPhases -and $TargetPhases.Count -gt 0) {
        return $PhaseName -in $TargetPhases
    }
    
    # Default: run all phases (that aren't skipped)
    return $true
}

function Get-PhaseOrder {
    <#
    .SYNOPSIS
        Returns the ordered list of all phases
    
    .RETURNS
        Array of phase names in execution order
    #>
    
    return @(
        'prerequisites',
        'authentication', 
        'loop-selection',
        'environment',
        'wsl',
        'project',
        'git',
        'pipelines',
        'vscode',
        'completion'
    )
}

function Get-PhaseInfo {
    <#
    .SYNOPSIS
        Gets information about all phases
    
    .RETURNS
        Hashtable with phase information
    #>
    
    return @{
        'prerequisites' = @{
            Order = 1
            Description = 'Check and install required tools and dependencies'
            RequiredFor = @('All subsequent phases')
            Dependencies = @()
        }
        'authentication' = @{
            Order = 2
            Description = 'Set up authentication for Git, Azure DevOps, and other services'
            RequiredFor = @('git', 'pipelines')
            Dependencies = @('prerequisites')
        }
        'loop-selection' = @{
            Order = 3
            Description = 'Discover available loops and determine environment requirements'
            RequiredFor = @('environment', 'wsl', 'project')
            Dependencies = @('prerequisites')
        }
        'environment' = @{
            Order = 4
            Description = 'Set up environment variables and configuration'
            RequiredFor = @('wsl', 'project', 'git', 'pipelines', 'vscode')
            Dependencies = @('loop-selection')
        }
        'wsl' = @{
            Order = 5
            Description = 'Set up Windows Subsystem for Linux if required'
            RequiredFor = @('project')
            Dependencies = @('loop-selection', 'environment')
        }
        'project' = @{
            Order = 6
            Description = 'Create project structure and initialize loop'
            RequiredFor = @('git', 'pipelines', 'vscode')
            Dependencies = @('loop-selection', 'environment')
        }
        'git' = @{
            Order = 7
            Description = 'Initialize Git repository and set up remote'
            RequiredFor = @('pipelines')
            Dependencies = @('authentication', 'project')
        }
        'pipelines' = @{
            Order = 8
            Description = 'Set up CI/CD pipelines'
            RequiredFor = @()
            Dependencies = @('authentication', 'git')
        }
        'vscode' = @{
            Order = 9
            Description = 'Configure VS Code workspace and extensions'
            RequiredFor = @()
            Dependencies = @('project')
        }
        'completion' = @{
            Order = 10
            Description = 'Final setup steps and validation'
            RequiredFor = @()
            Dependencies = @('All previous phases')
        }
    }
}

function Test-PhaseExists {
    <#
    .SYNOPSIS
        Tests if a phase name is valid
    
    .PARAMETER PhaseName
        The phase name to validate
    
    .RETURNS
        Boolean indicating if the phase exists
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PhaseName
    )
    
    $validPhases = Get-PhaseOrder
    return $PhaseName -in $validPhases
}

function Get-PhaseDependencies {
    <#
    .SYNOPSIS
        Gets the dependencies for a specific phase
    
    .PARAMETER PhaseName
        The phase to get dependencies for
    
    .RETURNS
        Array of dependency phase names
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PhaseName
    )
    
    $phaseInfo = Get-PhaseInfo
    if ($phaseInfo.ContainsKey($PhaseName)) {
        return $phaseInfo[$PhaseName].Dependencies
    }
    
    return @()
}

function Test-PhaseDependenciesCompleted {
    <#
    .SYNOPSIS
        Tests if all dependencies for a phase have been completed
    
    .PARAMETER PhaseName
        The phase to check dependencies for
    
    .PARAMETER CompletedPhases
        Array of completed phase names
    
    .RETURNS
        Boolean indicating if all dependencies are met
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PhaseName,
        
        [string[]]$CompletedPhases = @()
    )
    
    $dependencies = Get-PhaseDependencies -PhaseName $PhaseName
    
    foreach ($dependency in $dependencies) {
        if ($dependency -notin $CompletedPhases) {
            return $false
        }
    }
    
    return $true
}
