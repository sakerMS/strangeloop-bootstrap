#!/bin/bash

#
# strangeloop Setup Wrapper - Shell Script Compatible Entry Point
# 
# SYNOPSIS
#     strangeloop Setup Wrapper for Linux/WSL environments
#
# DESCRIPTION
#     This wrapper script ensures PowerShell 7 is available on Linux/WSL and then executes 
#     the main setup script. It uses a dedicated install-pwsh.sh script for PowerShell
#     installation with a manual fallback method for compatibility.
#
# USAGE
#     First make executable: chmod +x setup-wrapper.sh
#     Then run: ./setup-wrapper.sh [OPTIONS]
#
# PARAMETERS
#     --loop-name          The name of the loop to set up (optional)
#     --project-name       The name of the project to create (optional)
#     --mode              Setup mode: "core", "environment", "bootstrap", or "full"
#     --start-from-phase  Start execution from this phase number (1-3) or name
#     --start-from-stage  Start execution from this stage within Phase 3
#     --only-stage        Run only this specific stage within Phase 3
#     --skip-stages       Skip specific stages (comma-separated)
#     --list-phases       List all available phases and their descriptions
#     --list-stages       List all available stages across all phases
#     --list-modes        List all available setup modes
#     --help              Display comprehensive help information
#     --execution-engine  Execution engine: "StrangeloopCLI" or "PowerShell"
#     --verbose           Enable verbose output
#     --what-if           Show what would be performed without making changes
#     --check-only        Run in check mode without making permanent changes
#     --no-wsl            Skip WSL-specific configurations
#
# EXAMPLES
#     ./setup-wrapper.sh
#     Run the complete setup process
#
#     ./setup-wrapper.sh --loop-name "python-mcp-server" --project-name "MyApp"
#     Run setup with specific loop and project names
#
#     ./setup-wrapper.sh --mode bootstrap
#     Bootstrap development environment only
#
#     ./setup-wrapper.sh --what-if
#     Preview what would be done
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/../core/main.ps1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
WHAT_IF=false

# Logging functions
log_info() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[$(date '+%H:%M:%S')] [WRAPPER] $1${NC}" >&2
    fi
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [ERROR] $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
}

# Check if PowerShell 7+ is available
check_powershell7() {
    log_info "Checking for PowerShell 7+ availability..."
    
    if command -v pwsh >/dev/null 2>&1; then
        local version
        version=$(pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        if [[ -n "$version" ]]; then
            local major_version
            major_version=$(echo "$version" | cut -d. -f1)
            if [[ "$major_version" -ge 7 ]]; then
                log_info "PowerShell $version found"
                return 0
            else
                log_error "PowerShell $version found but version 7.0 or higher is required"
                return 1
            fi
        fi
    fi
    
    log_error "PowerShell 7+ not found on system"
    return 1
}

# Install PowerShell 7 using dedicated install script
install_powershell7() {
    log_info "Installing PowerShell 7 using install-pwsh.sh..."
    
    local install_script="$SCRIPT_DIR/../lib/pwsh/install-pwsh.sh"
    
    if [[ ! -f "$install_script" ]]; then
        log_error "PowerShell installation script not found: $install_script"
        log_error "Please ensure the install-pwsh.sh script exists and try again"
        return 1
    fi
    
    # Execute the install script (using bash directly to avoid permission issues)
    if bash "$install_script"; then
        log_success "PowerShell 7 installed via install-pwsh.sh"
        return 0
    else
        log_error "install-pwsh.sh failed"
        log_error "Please install PowerShell 7 manually and run this script again"
        echo
        echo -e "${YELLOW}Manual installation instructions:${NC}"
        echo "1. Visit: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux"
        echo "2. Follow the instructions for your Linux distribution"
        echo "3. Run this script again"
        return 1
    fi
}

# Check if PowerShell 7 is working after installation
verify_powershell7() {
    if command -v pwsh >/dev/null 2>&1; then
        local version
        version=$(pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        if [[ -n "$version" ]]; then
            local major_version
            major_version=$(echo "$version" | cut -d. -f1)
            if [[ "$major_version" -ge 7 ]]; then
                return 0
            fi
        fi
    fi
    return 1
}

# Ensure PowerShell is available before proceeding
ensure_powershell() {
    if ! check_powershell7; then
        log_info "PowerShell 7+ is required but not available"
        
        if [[ "$WHAT_IF" == "true" ]]; then
            log_warning "WHAT-IF: Would install PowerShell 7"
            return 0
        fi
        
        if install_powershell7; then
            # Verify installation
            sleep 2
            if ! verify_powershell7; then
                log_error "PowerShell 7 installation appears to have failed"
                log_error "Please install PowerShell 7 manually and run this script again"
                echo
                echo -e "${YELLOW}Manual installation instructions:${NC}"
                echo "1. Visit: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux"
                echo "2. Follow the instructions for your Linux distribution"
                echo "3. Run this script again"
                return 1
            fi
        else
            log_error "Failed to install PowerShell 7"
            return 1
        fi
    fi
    return 0
}

# Now that PowerShell is ensured, get the version
get_wrapper_version() {
    if command -v pwsh >/dev/null 2>&1; then
        pwsh -Command ". $SCRIPT_DIR/../lib/version/version-functions.ps1; Get-BootstrapScriptVersion" 2>/dev/null || echo "1.0.0"
    else
        echo "1.0.0"
    fi
}

# Help function
show_help() {
    cat << 'EOF'

===============================================================================
                       strangeloop Setup Wrapper (Shell)
                    Linux/WSL Compatible Entry Point v1.0.0
===============================================================================

DESCRIPTION:
  Shell script wrapper that ensures PowerShell 7 is available on Linux/WSL
  and executes the main strangeloop setup script. Uses install-pwsh.sh for
  PowerShell installation with manual fallback support.

USAGE:
  ./setup-wrapper.sh [OPTIONS]

KEY PARAMETERS:
  --loop-name <string>         strangeloop template to use
  --project-name <string>      Name for the new project
  --project-path <string>      Parent directory where project folder will be created
  --mode <string>              Setup mode: full, core, environment, bootstrap
  --start-from-phase <string>  Start from specific phase (1-3)
  --start-from-stage <string>  Start from specific stage
  --only-stage <string>        Run only specific stage
  --skip-stages <string>       Skip specific stages (comma-separated)
  --execution-engine <string>  StrangeloopCLI or PowerShell
  --list-phases               List all available phases
  --list-stages               List all available stages
  --list-modes                List all available modes
  --what-if                   Preview actions without changes
  --check-only                Validate environment only
  --no-wsl                    Skip WSL-specific configurations
  --verbose                   Enable verbose output
  --help                      Show this help message

EXAMPLES:
  ./setup-wrapper.sh
    → Complete setup with interactive prompts

  ./setup-wrapper.sh --mode environment
    → Setup environment only (Phase 2)

  ./setup-wrapper.sh --loop-name 'python-fast-api-linux' --project-name 'MyAPI'
    → Create specific project

  ./setup-wrapper.sh --what-if
    → Preview what would be done

  ./setup-wrapper.sh --start-from-phase 2
    → Start from environment setup

  ./setup-wrapper.sh --only-stage pipelines --loop-name 'python-cli'
    → Run only pipelines setup

NOTES:
  • This wrapper uses install-pwsh.sh for PowerShell 7 installation
  • Manual installation fallback available for unsupported scenarios
  • WSL environments are fully supported
  • All parameters are forwarded to the main PowerShell setup script

For more information, visit the repository documentation.

EOF
}

# Execute main setup script
execute_main_setup() {
    local -a params=()
    
    log_info "Executing main setup script with PowerShell 7..."
    
    if [[ ! -f "$SETUP_SCRIPT" ]]; then
        log_error "Main setup script not found: $SETUP_SCRIPT"
        return 1
    fi
    
    # Build parameter array
    for param in "${MAIN_SCRIPT_PARAMS[@]}"; do
        params+=("$param")
    done
    
    # Execute with PowerShell 7
    log_info "Launching: pwsh -ExecutionPolicy Bypass -File $SETUP_SCRIPT ${params[*]}"
    
    if pwsh -ExecutionPolicy Bypass -File "$SETUP_SCRIPT" "${params[@]}"; then
        return 0
    else
        local exit_code=$?
        log_error "Setup failed with exit code: $exit_code"
        return $exit_code
    fi
}

# Parse command line arguments
MAIN_SCRIPT_PARAMS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --loop-name)
            MAIN_SCRIPT_PARAMS+=("-loop-name" "$2")
            shift 2
            ;;
        --project-name)
            MAIN_SCRIPT_PARAMS+=("-project-name" "$2")
            shift 2
            ;;
        --project-path)
            MAIN_SCRIPT_PARAMS+=("-project-path" "$2")
            shift 2
            ;;
        --mode)
            MAIN_SCRIPT_PARAMS+=("-Mode" "$2")
            shift 2
            ;;
        --start-from-phase)
            MAIN_SCRIPT_PARAMS+=("-start-from-phase" "$2")
            shift 2
            ;;
        --start-from-stage)
            MAIN_SCRIPT_PARAMS+=("-start-from-stage" "$2")
            shift 2
            ;;
        --only-stage)
            MAIN_SCRIPT_PARAMS+=("-only-stage" "$2")
            shift 2
            ;;
        --skip-stages)
            MAIN_SCRIPT_PARAMS+=("-skip-stages" "$2")
            shift 2
            ;;
        --execution-engine)
            MAIN_SCRIPT_PARAMS+=("-execution-engine" "$2")
            shift 2
            ;;
        --list-phases)
            MAIN_SCRIPT_PARAMS+=("-list-phases")
            shift
            ;;
        --list-stages)
            MAIN_SCRIPT_PARAMS+=("-list-stages")
            shift
            ;;
        --list-modes)
            MAIN_SCRIPT_PARAMS+=("-list-modes")
            shift
            ;;
        --what-if)
            MAIN_SCRIPT_PARAMS+=("-what-if")
            WHAT_IF=true
            shift
            ;;
        --check-only)
            MAIN_SCRIPT_PARAMS+=("-check-only")
            shift
            ;;
        --no-wsl)
            MAIN_SCRIPT_PARAMS+=("-no-wsl")
            shift
            ;;
        --verbose)
            MAIN_SCRIPT_PARAMS+=("-Verbose")
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution function
main() {
    # Ensure PowerShell is available first
    if ! ensure_powershell; then
        return 1
    fi
    
    # Now get the wrapper version since PowerShell is available
    WRAPPER_VERSION=$(get_wrapper_version)
    
    echo
    echo -e "${BLUE}===============================================================================${NC}"
    echo -e "${BLUE}                       strangeloop Setup Wrapper v$WRAPPER_VERSION${NC}"  
    echo -e "${BLUE}                    Linux/WSL Compatible Entry Point${NC}"
    echo -e "${BLUE}===============================================================================${NC}"
    echo
    
    # Execute main setup script
    if execute_main_setup; then
        log_success "strangeloop setup completed successfully"
        return 0
    else
        log_error "strangeloop setup failed"
        return 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
