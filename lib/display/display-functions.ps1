# strangeloop Setup - Shared Display Functions
# Version: 1.0.0


# UI and display functions for consistent branding and help system

function Show-Banner {
    <#
    .SYNOPSIS
        Displays the strangeloop Setup banner with version information
    
    .PARAMETER Version
        The version number to display (defaults to bootstrap script version from YAML)
    
    .PARAMETER Title
        Custom title text (defaults to "strangeloop Setup")
    #>
    param(
        [string]$Version = "",
        [string]$Title = "strangeloop Setup"
    )
    
    # Use centralized version if not provided
    if ([string]::IsNullOrEmpty($Version)) {
        try {
            $Version = Get-BootstrapScriptVersion
        } catch {
            $Version = "1.0.0"  # Fallback if version functions not available
        }
    }
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║                                                 _                             ║" -ForegroundColor Blue
    Write-Host "║               _                                | |                            ║" -ForegroundColor Blue
    Write-Host "║         ___ _| |_  ____ _____ ____   ____ _____| | ___   ___  ____            ║" -ForegroundColor Blue
    Write-Host "║        /___|_   _)/ ___|____ |  _ \ / _  | ___ | |/ _ \ / _ \|  _ \           ║" -ForegroundColor Blue
    Write-Host "║       |___ | | |_| |   / ___ | | | ( (_| | ____| | |_| | |_| | |_| |          ║" -ForegroundColor Blue
    Write-Host "║       (___/   \__)_|   \_____|_| |_|\___ |_____)\_)___/ \___/|  __/           ║" -ForegroundColor Blue
    Write-Host "║                                    (_____|                   |_|              ║" -ForegroundColor Blue
    Write-Host "║  $($Title.PadRight(75))  ║" -ForegroundColor Blue
    Write-Host "║  Version: $($Version.PadRight(67)) ║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
}

function Show-Phases {
    <#
    .SYNOPSIS
        Displays all available phases with descriptions
    
    .PARAMETER ShowDependencies
        Whether to show phase dependencies
    
    .PARAMETER ShowOrder
        Whether to show execution order numbers
    #>
    param(
        [switch]$ShowDependencies,
        [switch]$ShowOrder
    )
    
    # Import phase functions to get phase information
    $phaseFunctionsPath = Join-Path $PSScriptRoot "phase-functions.ps1"
    if (Test-Path $phaseFunctionsPath) {
        . $phaseFunctionsPath
        
        $phaseInfo = Get-PhaseInfo
        $phaseOrder = Get-PhaseOrder
        
        Write-Host ""
        Write-Host "Available Phases:" -ForegroundColor Green
        Write-Host "=================" -ForegroundColor Green
        Write-Host ""
        
        foreach ($phase in $phaseOrder) {
            $info = $phaseInfo[$phase]
            
            # Build phase display line
            $displayLine = ""
            
            if ($ShowOrder) {
                $displayLine += "[$($info.Order.ToString().PadLeft(2))] "
            }
            
            $displayLine += "$($phase.PadRight(15)) - $($info.Description)"
            
            Write-Host $displayLine -ForegroundColor Cyan
            
            if ($ShowDependencies -and $info.Dependencies.Count -gt 0) {
                Write-Host "     Dependencies: $($info.Dependencies -join ', ')" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "Usage Examples:" -ForegroundColor Yellow
        Write-Host "  -from-phase environment                     # Start from environment and run subsequent phases" -ForegroundColor Gray
        Write-Host "  -only-phase pipelines                       # Run only the pipelines phase" -ForegroundColor Gray
        Write-Host "  -skip-phases wsl,authentication             # Skip specific phases" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Warning "Phase information not available - phase-functions.ps1 not found"
    }
}

function Show-Help {
    <#
    .SYNOPSIS
        Displays comprehensive help information for the setup script
    
    .PARAMETER ScriptName
        The name of the script (for display purposes)
    
    .PARAMETER ShowExamples
        Whether to show usage examples
    
    .PARAMETER ShowPhases
        Whether to show available phases
    #>
    param(
        [string]$ScriptName = "setup-strangeloop.ps1",
        [switch]$ShowExamples,
        [switch]$ShowPhases
    )
    
    Write-Host ""
    Write-Host "strangeloop Setup Help" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Automated setup script for strangeloop development environments" -ForegroundColor Gray
    Write-Host "  Supports both Windows and WSL environments with modular architecture" -ForegroundColor Gray
    Write-Host ""
    Write-Host "SYNTAX:" -ForegroundColor Yellow
    Write-Host "  .\$ScriptName [parameters]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -loop-name <string>         strangeloop template to use" -ForegroundColor Gray
    Write-Host "  -project-name <string>      Name for the new project" -ForegroundColor Gray
    Write-Host "  -project-path <string>      Parent directory where project folder will be created" -ForegroundColor Gray
    Write-Host "  -from-phase <string>        Start from this phase and run all subsequent phases" -ForegroundColor Gray
    Write-Host "  -only-phase <string>        Run only this specific phase" -ForegroundColor Gray
    Write-Host "  -skip-phases <string[]>     Skip specific phases (comma-separated)" -ForegroundColor Gray
    Write-Host "  -list-phases                List all available phases and exit" -ForegroundColor Gray
    Write-Host "  -help                       Show this help message" -ForegroundColor Gray
    Write-Host ""
    
    if ($ShowExamples) {
        Write-Host "EXAMPLES:" -ForegroundColor Yellow
        Write-Host "  .\$ScriptName" -ForegroundColor Gray
        Write-Host "    Run full setup with interactive prompts" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  .\$ScriptName -only-phase pipelines -project-name 'MyApp' -project-path '/parent/dir'" -ForegroundColor Gray
        Write-Host "    Run only the pipelines phase with specific project details" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  .\$ScriptName -from-phase environment" -ForegroundColor Gray
        Write-Host "    Start from environment phase and run all subsequent phases" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  .\$ScriptName -skip-phases wsl,pipelines" -ForegroundColor Gray
        Write-Host "    Run all phases except WSL and pipelines" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  .\$ScriptName -project-name 'MyApp' -loop-name 'python-cli'" -ForegroundColor Gray
        Write-Host "    Create project with specific parameters" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  .\$ScriptName -list-phases" -ForegroundColor Gray
        Write-Host "    Show all available phases and exit" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($ShowPhases) {
        Show-Phases -ShowOrder
    }
    
    Write-Host "For more information, visit: https://msasg.visualstudio.com/Bing_Ads/_git/Strangeloop" -ForegroundColor Cyan
    Write-Host ""
}

function Show-FinalSummary {
    <#
    .SYNOPSIS
        Displays available loops organized by platform for user selection
    #>
    
    # Import loop functions to get loop information
    $loopFunctionsPath = Join-Path $PSScriptRoot "loop-functions.ps1"
    if (Test-Path $loopFunctionsPath) {
        . $loopFunctionsPath
        
        $loopsByPlatform = Get-LoopsByPlatform
        
        Write-Host ""
        Write-Host "Available strangeloop Templates:" -ForegroundColor Green
        Write-Host "================================" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "  Windows Loops:" -ForegroundColor Cyan
        foreach ($loop in $loopsByPlatform['Windows']) {
            $loopInfo = Get-LoopRequirements -LoopName $loop
            Write-Host "    $($loop.PadRight(30)) - $($loopInfo.Description)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "  WSL Loops:" -ForegroundColor Cyan
        foreach ($loop in $loopsByPlatform['WSL']) {
            $loopInfo = Get-LoopRequirements -LoopName $loop
            Write-Host "    $($loop.PadRight(30)) - $($loopInfo.Description)" -ForegroundColor Gray
        }
    } else {
        Write-Warning "Loop information not available - loop-functions.ps1 not found"
    }
    
    Write-Host ""
    Write-Host "NOTES:" -ForegroundColor Yellow
    Write-Host "  • WSL loops require Windows Subsystem for Linux to be available" -ForegroundColor Gray
    Write-Host "  • Windows loops run natively on Windows" -ForegroundColor Gray
    Write-Host "  • Project paths should match the loop's platform requirements" -ForegroundColor Gray
    Write-Host "  • Use absolute paths for best compatibility" -ForegroundColor Gray
    Write-Host "  • Use 'platform dual' option to set up both Windows and WSL environments" -ForegroundColor Gray
    Write-Host ""
}

function Show-InteractiveLoopSelection {
    <#
    .SYNOPSIS
        Shows an interactive menu for loop selection with enhanced presentation
    
    .PARAMETER AvailableLoops
        Array of available loop names to display
    
    .RETURNS
        Selected loop name or $null if user cancels
    #>
    param(
        [Parameter(Mandatory)]
        [array]$AvailableLoops
    )
    
    # Import loop functions to get loop information
    $BootstrapRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $loopFunctionsPath = Join-Path $BootstrapRoot "phases\shared\loop-functions.ps1"
    $platformFunctionsPath = Join-Path $BootstrapRoot "lib\platform\platform-functions.ps1"
    
    if (-not (Test-Path $loopFunctionsPath)) {
        Write-Warning "Loop functions not available - using basic selection"
        return Show-BasicLoopSelection -AvailableLoops $AvailableLoops
    }
    
    # Import required dependencies for loop functions
    if (Test-Path $platformFunctionsPath) {
        . $platformFunctionsPath
    }
    
    . $loopFunctionsPath    Write-Host ""
    Write-Host "📋 Available strangeloop Templates:" -ForegroundColor Cyan
    Write-Host ""
    
    # Group loops by platform for better presentation
    $windowsLoops = @()
    $wslLoops = @()
    $bothLoops = @()
    
    foreach ($loop in $AvailableLoops) {
        $platform = Get-PlatformForLoop -LoopName $loop
        switch ($platform) {
            "Windows" { $windowsLoops += $loop }
            "WSL" { $wslLoops += $loop }
            default { $bothLoops += $loop }
        }
    }
    
    $index = 1
    $loopIndex = @{}
    
    if ($windowsLoops.Count -gt 0) {
        Write-Host "  Windows Templates:" -ForegroundColor Yellow
        foreach ($loop in $windowsLoops | Sort-Object) {
            $metadata = Get-LoopMetadata -LoopName $loop
            $description = if ($metadata) { " - $($metadata.Description)" } else { "" }
            Write-Host "    $index. $loop$description" -ForegroundColor White
            $loopIndex[$index] = $loop
            $index++
        }
        Write-Host ""
    }
    
    if ($wslLoops.Count -gt 0) {
        Write-Host "  WSL Templates:" -ForegroundColor Yellow
        foreach ($loop in $wslLoops | Sort-Object) {
            $metadata = Get-LoopMetadata -LoopName $loop
            $description = if ($metadata) { " - $($metadata.Description)" } else { "" }
            Write-Host "    $index. $loop$description" -ForegroundColor White
            $loopIndex[$index] = $loop
            $index++
        }
        Write-Host ""
    }
    
    if ($bothLoops.Count -gt 0) {
        Write-Host "  Cross-Platform Templates:" -ForegroundColor Yellow
        foreach ($loop in $bothLoops | Sort-Object) {
            $metadata = Get-LoopMetadata -LoopName $loop
            $description = if ($metadata) { " - $($metadata.Description)" } else { "" }
            Write-Host "    $index. $loop$description" -ForegroundColor White
            $loopIndex[$index] = $loop
            $index++
        }
        Write-Host ""
    }
    
    # Get user selection
    do {
        Write-Host "Please select a template (1-$($AvailableLoops.Count)) or 'q' to quit: " -NoNewline -ForegroundColor Cyan
        $userInput = Read-Host
        
        if ($userInput -eq 'q' -or $userInput -eq 'quit') {
            return $null
        }
        
        $selection = $null
        if ([int]::TryParse($userInput, [ref]$selection) -and $loopIndex.ContainsKey($selection)) {
            return $loopIndex[$selection]
        }
        
        Write-Host "Invalid selection. Please enter a number between 1 and $($AvailableLoops.Count), or 'q' to quit." -ForegroundColor Red
        Write-Host ""
    } while ($true)
}

function Show-BasicLoopSelection {
    <#
    .SYNOPSIS
        Fallback basic loop selection when loop functions are not available
    
    .PARAMETER AvailableLoops
        Array of available loop names to display
    
    .RETURNS
        Selected loop name or $null if user cancels
    #>
    param(
        [Parameter(Mandatory)]
        [array]$AvailableLoops
    )
    
    Write-Host ""
    Write-Host "Available Templates:" -ForegroundColor Cyan
    Write-Host ""
    
    $index = 1
    $loopIndex = @{}
    
    foreach ($loop in $AvailableLoops | Sort-Object) {
        Write-Host "    $index. $loop" -ForegroundColor White
        $loopIndex[$index] = $loop
        $index++
    }
    Write-Host ""
    
    # Get user selection
    do {
        Write-Host "Please select a template (1-$($AvailableLoops.Count)) or 'q' to quit: " -NoNewline -ForegroundColor Cyan
        $userInput = Read-Host
        
        if ($userInput -eq 'q' -or $userInput -eq 'quit') {
            return $null
        }
        
        $selection = $null
        if ([int]::TryParse($userInput, [ref]$selection) -and $loopIndex.ContainsKey($selection)) {
            return $loopIndex[$selection]
        }
        
        Write-Host "Invalid selection. Please enter a number between 1 and $($AvailableLoops.Count), or 'q' to quit." -ForegroundColor Red
        Write-Host ""
    } while ($true)
}

function Show-FinalSummary {
    <#
    .SYNOPSIS
        Displays the final setup summary with phase results and timing
    
    .PARAMETER PhaseResults
        Hashtable containing results from all phases
    
    .PARAMETER StartTime
        DateTime when setup started
    
    .PARAMETER Mode
        Setup mode (full, setup-only, etc.)
    #>
    param(
        [hashtable]$PhaseResults,
        [datetime]$StartTime,
        [string]$Mode
    )
    
    $endTime = Get-Date
    $totalDuration = $endTime - $StartTime
    
    Write-Host ""
    Write-Host "🎯 Setup Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $phaseNames = @{
        "Phase1_CorePrerequisites" = "Phase 1: Core Prerequisites"
        "Phase2_EnvironmentSetup" = "Phase 2: Environment Setup"
        "Phase3_LoopBootstrap" = "Phase 3: Project Bootstrap"
    }
    
    # Define the correct order for phases
    $phaseOrder = @(
        "Phase1_CorePrerequisites",
        "Phase2_EnvironmentSetup", 
        "Phase3_LoopBootstrap"
    )
    
    foreach ($phaseKey in $phaseOrder) {
        if ($PhaseResults.ContainsKey($phaseKey)) {
            $result = $PhaseResults[$phaseKey]
            $displayName = $phaseNames[$phaseKey]
            
            if ($result.ContainsKey('Skipped') -and $result['Skipped']) {
                Write-Host "⏭️  $displayName`: Skipped ($($result['Reason']))" -ForegroundColor Yellow
            } elseif ($result.ContainsKey('Success') -and $result['Success']) {
                $duration = if ($result.ContainsKey('Duration')) { " ($([math]::Round($result.Duration.TotalSeconds, 1))s)" } else { "" }
                Write-Host "✅ $displayName`: Success$duration" -ForegroundColor Green
            } else {
                Write-Host "❌ $displayName`: Failed" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
    Write-Host "⏱️  Total duration: $([math]::Round($totalDuration.TotalMinutes, 1)) minutes" -ForegroundColor Gray
    Write-Host ""
    
    $successResults = @($PhaseResults.Values | Where-Object { 
        $_.ContainsKey('Success') -and $_['Success'] -and 
        -not ($_.ContainsKey('Skipped') -and $_['Skipped']) 
    })
    $successCount = $successResults.Count
    
    $totalResults = @($PhaseResults.Values | Where-Object { 
        -not ($_.ContainsKey('Skipped') -and $_['Skipped']) 
    })
    $totalCount = $totalResults.Count
    
    if ($totalCount -eq 0 -or $successCount -eq $totalCount) {
        Write-Host "🎉 All phases completed successfully!" -ForegroundColor Green
        
        if ($Mode -eq "full" -and $PhaseResults.ContainsKey('Phase3_LoopBootstrap')) {
            $projectResult = $PhaseResults['Phase3_LoopBootstrap']
            if ($projectResult.ProjectPath -and $projectResult.ProjectName) {
                Write-Host ""
                Write-Host "🚀 Your project is ready!" -ForegroundColor Green
                Write-Host "  Project: $($projectResult.ProjectName)" -ForegroundColor White
                Write-Host "  Location: $($projectResult.ProjectPath)" -ForegroundColor White
                Write-Host "  Target Platform: $($projectResult.Platform)" -ForegroundColor White
            }
        }
    } else {
        Write-Host "⚠️  Some phases had issues. Please review the output above." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Export functions for module usage only
if ($MyInvocation.MyCommand.ModuleName) {
    Export-ModuleMember -Function @(
        'Show-Banner',
        'Show-Phases',
        'Show-Help',
        'Show-FinalSummary'
    )
}


