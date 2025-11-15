#Requires -Version 7.0

<#
.SYNOPSIS
    Configuration Management for strangeloop Bootstrap

.DESCRIPTION
    Handles loading and managing bootstrap configuration from YAML files
    and provides configuration access functions.
#>

function Initialize-BootstrapConfig {
    <#
    .SYNOPSIS
        Initializes the bootstrap configuration from config files
    
    .PARAMETER ConfigPath
        Path to the bootstrap configuration YAML file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )
    
    try {
        if (Test-Path $ConfigPath) {
            $yamlContent = Get-Content $ConfigPath -Raw
            $Global:BootstrapConfig = ConvertFrom-Yaml -YamlString $yamlContent
            Write-Verbose "Bootstrap configuration loaded from: $ConfigPath"
        } else {
            Write-Warning "Bootstrap configuration file not found: $ConfigPath"
            $Global:BootstrapConfig = @{}
        }
    } catch {
        Write-Warning "Failed to load bootstrap configuration: $($_.Exception.Message)"
        $Global:BootstrapConfig = @{}
    }
}

function Get-BootstrapConfig {
    <#
    .SYNOPSIS
        Gets a configuration value from the bootstrap config
    
    .PARAMETER Key
        Configuration key to retrieve
    
    .PARAMETER DefaultValue
        Default value if key is not found
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        
        [object]$DefaultValue = $null
    )
    
    if ($Global:BootstrapConfig -and $Global:BootstrapConfig.ContainsKey($Key)) {
        return $Global:BootstrapConfig[$Key]
    }
    
    return $DefaultValue
}

function Set-BootstrapConfig {
    <#
    .SYNOPSIS
        Sets a configuration value in the bootstrap config
    
    .PARAMETER Key
        Configuration key to set
    
    .PARAMETER Value
        Value to set
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        
        [Parameter(Mandatory)]
        [object]$Value
    )
    
    if (-not $Global:BootstrapConfig) {
        $Global:BootstrapConfig = @{}
    }
    
    $Global:BootstrapConfig[$Key] = $Value
}

function Show-CustomHelp {
    <#
    .SYNOPSIS
        Shows comprehensive help information for the bootstrap system
    #>
    
    Write-Host @"
strangeloop CLI Setup Script v3.0.0 - New 3-Phase Architecture

DESCRIPTION:
    A comprehensive setup script with simplified 3-phase execution model for strangeloop development environment setup.
    Features clear separation between core prerequisites, environment setup, and project bootstrap.

USAGE:
    .\main.ps1 [OPTIONS]

PARAMETERS:
    -loop-name          The name of the loop to set up (optional for environment-only mode)
    -project-name       The name of the project to create (optional)
    -project-path       The path where the project should be created (optional)
    -Mode              Setup mode: "core", "environment", "bootstrap", or "full" (default: "full")
    -start-from-phase  Start execution from this phase number (1-3) or name
    -start-from-stage  Start execution from this stage and continue through all subsequent stages
    -only-stage        Run only this specific stage (can be from any phase)
    -skip-stages       Skip specific stages across any phase (comma-separated)
    -what-if           Preview what actions would be performed without making any actual changes
    -execution-engine  Execution engine: "StrangeloopCLI" or "PowerShell" (default: "StrangeloopCLI")
    -check-only        Run in check mode without making permanent changes
    -no-wsl            Skip WSL installation and configuration on Windows
    -list-phases       Display available phases and their descriptions
    -list-stages       Display available stages across all phases with details
    -list-modes        Display available setup modes and their descriptions
    -Help              Show this help information

PHASES:
    Phase 1: Core Prerequisites
        • PowerShell Policy Configuration
        • Azure CLI Setup & Authentication
        • strangeloop CLI Installation

    Phase 2: Environment Prerequisites
        • Version Control Setup (Git)
        • Containerization Setup (Docker)
        • Python Environment Setup
        • Package Management Setup (Poetry)
        • WSL Environment Setup

    Phase 3: Project Bootstrap
        • Loop Selection & Target Platform Decision
        • Project Setup & Target Platform-Specific Configuration
        • Development Tools Integration

EXAMPLES:
    .\main.ps1
        Run the complete setup process

    .\main.ps1 -loop-name "python-mcp-server" -project-name "MyApp"
        Run setup with specific loop and project names

    .\main.ps1 -Mode bootstrap
        Bootstrap development environment only (skip core prerequisites)

    .\main.ps1 -what-if
        Preview what would be done

    .\main.ps1 -start-from-stage git
        Start from Git setup stage and continue through all subsequent stages

    .\main.ps1 -only-stage docker
        Run only the Docker setup stage

For more information, visit: https://github.com/strangeloop/cli
"@ -ForegroundColor Cyan
}

function Show-PhasesInfo {
    <#
    .SYNOPSIS
        Shows detailed information about all phases
    #>
    
    Write-Host @"
strangeloop Bootstrap Phases

Phase 1: Core Prerequisites
    Description: Essential tools and authentication required for all scenarios
    Stages:
        • PowerShell Policy Configuration
        • Azure CLI Setup & Authentication  
        • strangeloop CLI Installation

Phase 2: Environment Prerequisites
    Description: Development environment prerequisites and tooling
    Stages:
        • Version Control Setup (Git)
        • Containerization Setup (Docker)
        • Python Environment Setup
        • Package Management Setup (Poetry)
        • WSL Environment Setup (Windows only)

Phase 3: Project Bootstrap
    Description: Project-specific setup and development tool integration
    Stages:
        • Loop Selection & Target Platform Decision
        • Project Setup & Target Platform-Specific Configuration
        • Development Tools Integration
"@ -ForegroundColor Green
}

function Show-StagesInfo {
    <#
    .SYNOPSIS
        Shows detailed information about all stages
    #>
    
    Write-Host "strangeloop Bootstrap Stages" -ForegroundColor Green
    Write-Host ""
    
    # This will be populated from the actual stage definitions
    Write-Host "Phase 1 - Core Prerequisites:" -ForegroundColor Yellow
    Write-Host "  powershell, policy    - PowerShell Policy Configuration" -ForegroundColor White
    Write-Host "  azure-cli, azure      - Azure CLI Setup & Authentication" -ForegroundColor White
    Write-Host "  strangeloop-cli, cli  - strangeloop CLI Installation" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Phase 2 - Environment Prerequisites:" -ForegroundColor Yellow
    Write-Host "  git, version-control  - Version Control Setup" -ForegroundColor White
    Write-Host "  docker, containers    - Containerization Setup" -ForegroundColor White
    Write-Host "  python, language      - Python Environment Setup" -ForegroundColor White
    Write-Host "  poetry, packages      - Package Management Setup" -ForegroundColor White
    Write-Host "  wsl, linux           - WSL Environment Setup" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Phase 3 - Project Bootstrap:" -ForegroundColor Yellow
    Write-Host "  selection, loop-selection - Loop Selection & Target Platform Decision" -ForegroundColor White
    Write-Host "  project, project-setup    - Project Setup & Target Platform-Specific Configuration" -ForegroundColor White
    Write-Host "  tools, development-tools  - Development Tools Integration" -ForegroundColor White
    Write-Host "  pipelines                 - CI/CD Pipeline Setup" -ForegroundColor White
    Write-Host "  vscode                    - VS Code Integration" -ForegroundColor White
}

function Show-ModesInfo {
    <#
    .SYNOPSIS
        Shows detailed information about setup modes
    #>
    
    Write-Host @"
strangeloop Bootstrap Modes

core
    Description: Run only Phase 1 (Core Prerequisites)
    Use case: Install Azure CLI, strangeloop CLI, PowerShell execution policy

environment
    Description: Run only Phase 2 (Environment Prerequisites)
    Use case: Set up Git, Docker, Python, Poetry, WSL development environment

bootstrap
    Description: Run only Phase 3 (Project Bootstrap)
    Use case: Create and configure project (assumes environment is ready)

full
    Description: Run all phases (1, 2, and 3)
    Use case: Complete setup from scratch (default)
"@ -ForegroundColor Cyan
}
