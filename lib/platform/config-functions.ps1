# Configuration Functions Module
# Provides centralized configuration loading from bootstrap_config.yaml

function Get-BootstrapConfig {
    <#
    .SYNOPSIS
    Loads the complete bootstrap configuration from YAML file.
    
    .RETURNS
    Hashtable: Complete configuration data
    #>
    
    $configPath = Join-Path (Split-Path (Split-Path $PSScriptRoot)) "config\bootstrap_config.yaml"
    if (-not (Test-Path $configPath)) {
        Write-Warning "Bootstrap config file not found at $configPath"
        return @{}
    }
    
    try {
        $yamlContent = Get-Content $configPath -Raw
        return @{
            YamlContent = $yamlContent
            ConfigPath = $configPath
        }
    }
    catch {
        Write-Warning "Error reading bootstrap configuration: $($_.Exception.Message)"
        return @{}
    }
}

function Get-BootstrapPhases {
    <#
    .SYNOPSIS
    Gets the phase configuration from bootstrap_config.yaml.
    
    .RETURNS
    Hashtable: Phase configuration with phase numbers as keys
    #>
    
    $config = Get-BootstrapConfig
    if (-not $config.YamlContent) {
        return Get-DefaultPhases
    }
    
    try {
        $phases = @{}
        $lines = $config.YamlContent -split '\n'
        
        # Find the phases section
        $inPhasesSection = $false
        $currentPhase = $null
        $currentPhaseData = @{}
        $inAliases = $false
        
        foreach ($line in $lines) {
            if ($line -match '^\s*phases:\s*$') {
                $inPhasesSection = $true
                continue
            }
            
            # Exit phases section if we hit another top-level section
            if ($inPhasesSection -and $line -match '^[a-zA-Z_][a-zA-Z0-9_]*:\s*$') {
                # Save current phase if exists
                if ($currentPhase -and $currentPhaseData.Count -gt 0) {
                    $phases[$currentPhase] = $currentPhaseData
                }
                break
            }
            
            if (-not $inPhasesSection) { continue }
            
            # Parse phase number (e.g., "1":)
            if ($line -match '^\s*"?(\d+)"?:\s*$') {
                # Save previous phase if exists
                if ($currentPhase -and $currentPhaseData.Count -gt 0) {
                    $phases[$currentPhase] = $currentPhaseData
                }
                
                # Start new phase
                $currentPhase = $matches[1]
                $currentPhaseData = @{
                    Number = $currentPhase
                    Aliases = @()
                }
                $inAliases = $false
                continue
            }
            
            # Parse aliases section
            if ($currentPhase -and $line -match '^\s+aliases:\s*\[(.*?)\]') {
                $aliasContent = $matches[1]
                $currentPhaseData.Aliases = $aliasContent -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ }
                $inAliases = $false
                continue
            }
            
            if ($currentPhase -and $line -match '^\s+aliases:\s*$') {
                $inAliases = $true
                $currentPhaseData.Aliases = @()
                continue
            }
            
            if ($inAliases -and $line -match '^\s+-\s*"?([^"]+)"?') {
                $currentPhaseData.Aliases += $matches[1].Trim()
                continue
            }
            
            # Parse phase properties
            if ($currentPhase -and -not $inAliases) {
                if ($line -match '^\s+name:\s*"?([^"]+)"?') {
                    $currentPhaseData.Name = $matches[1].Trim()
                }
                elseif ($line -match '^\s+title:\s*"?([^"]+)"?') {
                    $currentPhaseData.Title = $matches[1].Trim()
                }
                elseif ($line -match '^\s+description:\s*"?([^"]+)"?') {
                    $currentPhaseData.Description = $matches[1].Trim()
                }
                elseif ($line -match '^\s+required:\s*(true|false)') {
                    $currentPhaseData.Required = $matches[1] -eq 'true'
                }
                elseif ($line -match '^\s+estimated_duration_minutes:\s*(\d+)') {
                    $currentPhaseData.EstimatedDurationMinutes = [int]$matches[1]
                }
            }
        }
        
        # Save the last phase
        if ($currentPhase -and $currentPhaseData.Count -gt 0) {
            $phases[$currentPhase] = $currentPhaseData
        }
        
        if ($phases.Count -eq 0) {
            return Get-DefaultPhases
        }
        
        return $phases
    }
    catch {
        Write-Warning "Error parsing phases configuration: $($_.Exception.Message)"
        return Get-DefaultPhases
    }
}

function Get-BootstrapModes {
    <#
    .SYNOPSIS
    Gets the mode configuration from bootstrap_config.yaml.
    
    .RETURNS
    Hashtable: Mode configuration with mode names as keys
    #>
    
    $config = Get-BootstrapConfig
    if (-not $config.YamlContent) {
        return Get-DefaultModes
    }
    
    try {
        $modes = @{}
        $lines = $config.YamlContent -split '\n'
        
        # Find the modes section
        $inModesSection = $false
        $currentMode = $null
        $currentModeData = @{}
        
        foreach ($line in $lines) {
            if ($line -match '^\s*modes:\s*$') {
                $inModesSection = $true
                continue
            }
            
            # Exit modes section if we hit another top-level section
            if ($inModesSection -and $line -match '^[a-zA-Z_][a-zA-Z0-9_]*:\s*$') {
                # Save current mode if exists
                if ($currentMode -and $currentModeData.Count -gt 0) {
                    $modes[$currentMode] = $currentModeData
                }
                break
            }
            
            if (-not $inModesSection) { continue }
            
            # Parse mode name (e.g., "full":)
            if ($line -match '^\s*"?([a-zA-Z0-9_-]+)"?:\s*$') {
                # Save previous mode if exists
                if ($currentMode -and $currentModeData.Count -gt 0) {
                    $modes[$currentMode] = $currentModeData
                }
                
                # Start new mode
                $currentMode = $matches[1]
                $currentModeData = @{
                    Name = $currentMode
                    Aliases = @()
                    Phases = @()
                }
                continue
            }
            
            # Parse mode properties
            if ($currentMode) {
                if ($line -match '^\s+title:\s*"?([^"]+)"?') {
                    $currentModeData.Title = $matches[1].Trim()
                }
                elseif ($line -match '^\s+description:\s*"?([^"]+)"?') {
                    $currentModeData.Description = $matches[1].Trim()
                }
                elseif ($line -match '^\s+default:\s*(true|false)') {
                    $currentModeData.Default = $matches[1] -eq 'true'
                }
                elseif ($line -match '^\s+execution_mode:\s*(true|false)') {
                    $currentModeData.ExecutionMode = $matches[1] -eq 'true'
                }
                elseif ($line -match '^\s+phases:\s*\[(.*?)\]') {
                    $phaseContent = $matches[1]
                    $currentModeData.Phases = $phaseContent -split ',' | ForEach-Object { [int]$_.Trim() } | Where-Object { $_ -ne 0 }
                }
                elseif ($line -match '^\s+aliases:\s*\[(.*?)\]') {
                    $aliasContent = $matches[1]
                    $currentModeData.Aliases = $aliasContent -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ }
                }
            }
        }
        
        # Save the last mode
        if ($currentMode -and $currentModeData.Count -gt 0) {
            $modes[$currentMode] = $currentModeData
        }
        
        if ($modes.Count -eq 0) {
            return Get-DefaultModes
        }
        
        return $modes
    }
    catch {
        Write-Warning "Error parsing modes configuration: $($_.Exception.Message)"
        return Get-DefaultModes
    }
}

function Convert-PhaseNameToNumber {
    <#
    .SYNOPSIS
    Convert phase names to phase numbers using configuration.
    
    .PARAMETER PhaseName
    The phase name or number to convert.
    
    .RETURNS
    String: The phase number
    #>
    param([string]$PhaseName)
    
    # If it's already a number, return as-is
    if ($PhaseName -match '^\d+$') {
        return $PhaseName
    }
    
    # Get phase configuration
    $phases = Get-BootstrapPhases
    $lowerName = $PhaseName.ToLower()
    
    # Check primary name and aliases
    foreach ($phaseNumber in $phases.Keys) {
        $phase = $phases[$phaseNumber]
        
        # Check primary name
        if ($phase.Name -and $phase.Name.ToLower() -eq $lowerName) {
            return $phaseNumber
        }
        
        # Check aliases
        if ($phase.Aliases) {
            foreach ($alias in $phase.Aliases) {
                if ($alias.ToLower() -eq $lowerName) {
                    return $phaseNumber
                }
            }
        }
    }
    
    # If no match found, return original value
    return $PhaseName
}

function Get-ValidPhaseValues {
    <#
    .SYNOPSIS
    Gets all valid phase values (numbers, names, and aliases) for ValidateSet.
    
    .RETURNS
    Array: All valid phase identifiers
    #>
    
    $phases = Get-BootstrapPhases
    $validValues = @()
    
    foreach ($phaseNumber in $phases.Keys) {
        $phase = $phases[$phaseNumber]
        
        # Add phase number
        $validValues += $phaseNumber
        
        # Add primary name
        if ($phase.Name) {
            $validValues += $phase.Name
        }
        
        # Add aliases
        if ($phase.Aliases) {
            $validValues += $phase.Aliases
        }
    }
    
    return $validValues | Sort-Object
}

function Get-ValidModeValues {
    <#
    .SYNOPSIS
    Gets all valid mode values (names and aliases) for ValidateSet.
    
    .RETURNS
    Array: All valid mode identifiers
    #>
    
    $modes = Get-BootstrapModes
    $validValues = @()
    
    foreach ($modeName in $modes.Keys) {
        $mode = $modes[$modeName]
        
        # Add mode name
        $validValues += $modeName
        
        # Add aliases
        if ($mode.Aliases) {
            $validValues += $mode.Aliases
        }
    }
    
    return $validValues | Sort-Object
}

function Get-DefaultPhases {
    <#
    .SYNOPSIS
    Returns default phase configuration as fallback.
    #>
    
    return @{
        "1" = @{
            Number = "1"
            Name = "core"
            Title = "Core Prerequisites"
            Description = "Azure CLI installation/verification, strangeloop CLI installation/verification, PowerShell execution policy setup"
            Aliases = @("core", "core-prerequisites")
            Required = $true
            EstimatedDurationMinutes = 3
        }
        "2" = @{
            Number = "2"
            Name = "prerequisites"
            Title = "Environment Prerequisites"
            Description = "Git installation/configuration, Docker Desktop installation, Python & Poetry (Windows), Git-LFS setup"
            Aliases = @("prerequisites", "additional-prerequisites", "deps")
            Required = $true
            EstimatedDurationMinutes = 10
        }
        "3" = @{
            Number = "3"
            Name = "bootstrap"
            Title = "Project Bootstrap"
            Description = "Loop selection, project initialization, and development tool integration (strangeloop init, recurse, pipelines)"
            Aliases = @("bootstrap", "project", "init", "selection", "loop-selection", "tools", "integration")
            Required = $true
            EstimatedDurationMinutes = 12
        }
    }
}

function Get-BootstrapExecutionModifiers {
    <#
    .SYNOPSIS
    Gets the execution modifier configuration from bootstrap_config.yaml.
    
    .RETURNS
    Hashtable: Execution modifier configuration with modifier names as keys
    #>
    
    $config = Get-BootstrapConfig
    if (-not $config.YamlContent) {
        return Get-DefaultExecutionModifiers
    }
    
    try {
        $modifiers = @{}
        $lines = $config.YamlContent -split '\n'
        
        # Find the execution_modifiers section
        $inModifiersSection = $false
        $currentModifier = $null
        $currentModifierData = @{}
        
        foreach ($line in $lines) {
            if ($line -match '^\s*execution_modifiers:\s*$') {
                $inModifiersSection = $true
                continue
            }
            
            # Exit section if we hit another top-level section
            if ($inModifiersSection -and $line -match '^[a-zA-Z_][a-zA-Z0-9_]*:\s*$') {
                # Save current modifier if exists
                if ($currentModifier -and $currentModifierData.Count -gt 0) {
                    $modifiers[$currentModifier] = $currentModifierData
                }
                break
            }
            
            if (-not $inModifiersSection) { continue }
            
            # Parse modifier name
            if ($line -match '^\s*"?([a-zA-Z0-9_-]+)"?:\s*$') {
                # Save previous modifier if exists
                if ($currentModifier -and $currentModifierData.Count -gt 0) {
                    $modifiers[$currentModifier] = $currentModifierData
                }
                
                # Start new modifier
                $currentModifier = $matches[1]
                $currentModifierData = @{
                    Name = $currentModifier
                    Aliases = @()
                }
                continue
            }
            
            # Parse modifier properties
            if ($currentModifier) {
                if ($line -match '^\s+title:\s*"?([^"]+)"?') {
                    $currentModifierData.Title = $matches[1].Trim()
                }
                elseif ($line -match '^\s+description:\s*"?([^"]+)"?') {
                    $currentModifierData.Description = $matches[1].Trim()
                }
                elseif ($line -match '^\s+parameter:\s*"?([^"]+)"?') {
                    $currentModifierData.Parameter = $matches[1].Trim()
                }
                elseif ($line -match '^\s+aliases:\s*\[(.*?)\]') {
                    $aliasContent = $matches[1]
                    $currentModifierData.Aliases = $aliasContent -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ }
                }
            }
        }
        
        # Save the last modifier
        if ($currentModifier -and $currentModifierData.Count -gt 0) {
            $modifiers[$currentModifier] = $currentModifierData
        }
        
        if ($modifiers.Count -eq 0) {
            return Get-DefaultExecutionModifiers
        }
        
        return $modifiers
    }
    catch {
        Write-Warning "Error parsing execution modifiers configuration: $($_.Exception.Message)"
        return Get-DefaultExecutionModifiers
    }
}

function Get-DefaultExecutionModifiers {
    <#
    .SYNOPSIS
    Returns default execution modifier configuration as fallback.
    #>
    
    return @{
        "check-only" = @{
            Name = "check-only"
            Title = "Check Mode"
            Description = "Validate environment and prerequisites without making changes"
            Aliases = @("check", "validate", "verify")
            Parameter = "CheckOnly"
        }
        "what-if" = @{
            Name = "what-if"
            Title = "Preview Mode"
            Description = "Preview what actions would be performed without making changes"
            Aliases = @("preview", "dry-run", "simulate")
            Parameter = "WhatIf"
        }
    }
}

function Get-DefaultModes {
    <#
    .SYNOPSIS
    Returns default mode configuration as fallback.
    #>
    
    return @{
        "core" = @{
            Name = "core"
            Title = "Core Prerequisites"
            Description = "Install only core prerequisites (Azure CLI, strangeloop CLI, PowerShell policy)"
            Phases = @(1)
            Default = $false
            Aliases = @("core-only")
        }
        "full" = @{
            Name = "full"
            Title = "Complete Setup"
            Description = "Complete development environment and project setup (All phases)"
            Phases = @(1, 2, 3)
            Default = $true
            Aliases = @()
        }
        "bootstrap" = @{
            Name = "bootstrap"
            Title = "Project Bootstrap"
            Description = "Create and configure project only (requires existing environment)"
            Phases = @(3)
            Default = $false
            Aliases = @("project-only", "bootstrap-only")
        }
        "environment" = @{
            Name = "environment"
            Title = "Environment Setup"
            Description = "Set up development environment tools only (Git, Docker, Python, Poetry, WSL)"
            Phases = @(2)
            Default = $false
            Aliases = @("env-only", "env", "setup-only")
        }
    }
}

function Get-ValidExecutionModifierValues {
    <#
    .SYNOPSIS
    Gets all valid execution modifier values including aliases for validation.
    
    .RETURNS
    Array: All valid execution modifier names and aliases
    #>
    
    $modifiers = Get-BootstrapExecutionModifiers
    $validValues = @()
    
    foreach ($modifier in $modifiers.Values) {
        $validValues += $modifier.Name
        if ($modifier.Aliases) {
            $validValues += $modifier.Aliases
        }
    }
    
    return $validValues | Sort-Object
}

function Resolve-ExecutionModifierToParameter {
    <#
    .SYNOPSIS
    Resolves an execution modifier name or alias to its corresponding parameter name.
    
    .PARAMETER ModifierName
    The execution modifier name or alias to resolve
    
    .RETURNS
    String: The parameter name, or $null if not found
    #>
    param(
        [string]$ModifierName
    )
    
    $modifiers = Get-BootstrapExecutionModifiers
    
    foreach ($modifier in $modifiers.Values) {
        if ($modifier.Name -eq $ModifierName -or $modifier.Aliases -contains $ModifierName) {
            return $modifier.Parameter
        }
    }
    
    return $null
}

function Get-ExecutionModifierSummary {
    <#
    .SYNOPSIS
    Gets a formatted summary of available execution modifiers for display.
    
    .RETURNS
    String: Formatted list of execution modifiers with descriptions
    #>
    
    $modifiers = Get-BootstrapExecutionModifiers
    $output = @()
    
    $output += "Available Execution Modifiers:"
    $output += "==============================="
    
    foreach ($modifierName in ($modifiers.Keys | Sort-Object)) {
        $modifier = $modifiers[$modifierName]
        
        $line = "• $($modifier.Name)"
        if ($modifier.Title) {
            $line += " ($($modifier.Title))"
        }
        $output += $line
        
        if ($modifier.Description) {
            $output += "  $($modifier.Description)"
        }
        
        if ($modifier.Aliases -and $modifier.Aliases.Count -gt 0) {
            $aliasText = $modifier.Aliases -join ", "
            $output += "  Aliases: $aliasText"
        }
        
        $output += ""
    }
    
    return $output -join "`n"
}

# Export functions for use by other modules when imported as a module
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Get-BootstrapConfig',
        'Get-BootstrapPhases',
        'Get-BootstrapModes',
        'Get-BootstrapExecutionModifiers',
        'Convert-PhaseNameToNumber',
        'Get-ValidPhaseValues',
        'Get-ValidModeValues',
        'Get-ValidExecutionModifierValues',
        'Resolve-ExecutionModifierToParameter',
        'Get-ExecutionModifierSummary',
        'Get-DefaultPhases',
        'Get-DefaultModes',
        'Get-DefaultExecutionModifiers'
    )
}
