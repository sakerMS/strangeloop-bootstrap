#!/usr/bin/env bash

#
# strangeloop Bootstrap - PowerShell Installation Script
# Version: 3.0.0 - Simplified for Linux execution only
#
# SYNOPSIS
#     PowerShell 7+ installation script for Linux/WSL environments
#
# DESCRIPTION
#     This script installs PowerShell 7+ on Ubuntu-based Linux distributions using
#     the Microsoft package repository. It follows Microsoft's recommended installation
#     approach and includes proper error handling and verification.
#
# USAGE
#     chmod +x install-pwsh.sh
#     ./install-pwsh.sh
#
# REQUIREMENTS
#     - Ubuntu/Debian-based Linux distribution
#     - sudo privileges for package installation
#     - Internet connectivity for package downloads
#
# NOTES
#     - Uses Microsoft's official package repository
#     - Automatically detects existing PowerShell installations
#     - Installs dependencies and configures repository access
#     - Verifies installation after completion
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] [INFO] $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [ERROR] $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [OK] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [WARN] $1${NC}" >&2
}

log_step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] === $1 ===${NC}"
}

# Check if PowerShell is already installed
check_existing_powershell() {
    if command -v pwsh &> /dev/null; then
        local version
        version=$(pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
        if [[ -n "$version" ]]; then
            local major_version
            major_version=$(echo "$version" | cut -d. -f1)
            if [[ "$major_version" -ge 7 ]]; then
                log_info "PowerShell $version is already installed"
                log_success "PowerShell installation verification completed"
                pwsh -Command '$PSVersionTable.PSVersion' 2>/dev/null
                return 0
            else
                log_warning "PowerShell $version found but version 7.0+ is required"
                return 1
            fi
        fi
    fi
    return 1
}

# Install PowerShell via Microsoft repository
install_powershell_repository() {
    log_step "Installing PowerShell via Microsoft Repository"
    
    # Update package index
    log_info "Updating package index..."
    if ! sudo apt-get update -qq; then
        log_error "Failed to update package index"
        return 1
    fi
    
    # Install required dependencies
    log_info "Installing required dependencies..."
    if ! sudo apt-get install -y -qq wget apt-transport-https software-properties-common; then
        log_error "Failed to install dependencies"
        return 1
    fi
    
    # Download and install Microsoft repository configuration
    log_info "Configuring Microsoft package repository..."
    local temp_file="/tmp/packages-microsoft-prod.deb"
    
    if ! wget -q -O "$temp_file" "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb"; then
        log_error "Failed to download Microsoft repository configuration"
        return 1
    fi
    
    if ! sudo dpkg -i "$temp_file" > /dev/null 2>&1; then
        log_error "Failed to install Microsoft repository configuration"
        return 1
    fi
    
    # Clean up temporary file
    rm -f "$temp_file" 2>/dev/null || true
    
    # Update package index again with new repository
    log_info "Updating package index with Microsoft repository..."
    if ! sudo apt-get update -qq; then
        log_error "Failed to update package index after repository addition"
        return 1
    fi
    
    # Install PowerShell
    log_info "Installing PowerShell from Microsoft repository..."
    if ! sudo apt-get install -y -qq powershell; then
        log_error "Failed to install PowerShell package"
        return 1
    fi
    
    log_success "PowerShell installation completed"
    return 0
}

# Verify PowerShell installation
verify_installation() {
    log_step "Verifying PowerShell Installation"
    
    # Check if pwsh command is available
    if ! command -v pwsh &> /dev/null; then
        log_error "PowerShell command 'pwsh' not found in PATH"
        return 1
    fi
    
    # Test PowerShell execution and get version
    local version
    if ! version=$(pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null); then
        log_error "PowerShell installation appears corrupted - cannot execute"
        return 1
    fi
    
    # Verify version is 7.0+
    local major_version
    major_version=$(echo "$version" | cut -d. -f1)
    if [[ "$major_version" -ge 7 ]]; then
        log_success "PowerShell $version verified and working"
        
        # Display version information
        log_info "PowerShell version details:"
        pwsh -Command '$PSVersionTable | Format-Table -AutoSize' 2>/dev/null || true
        
        return 0
    else
        log_error "PowerShell version $version is too old (7.0+ required)"
        return 1
    fi
}

# Main installation function
main() {
    log_step "PowerShell 7+ Installation for Linux/WSL"
    
    # Check if PowerShell is already installed
    if check_existing_powershell; then
        return 0
    fi
    
    # Install PowerShell via Microsoft repository
    if ! install_powershell_repository; then
        log_error "PowerShell installation failed"
        echo
        echo -e "${YELLOW}Manual Installation Instructions:${NC}"
        echo "1. Visit: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux"
        echo "2. Follow the Ubuntu installation guide for your distribution"
        echo "3. Ensure PowerShell 7.0 or higher is installed"
        echo "4. Run 'pwsh' to verify the installation"
        return 1
    fi
    
    # Verify the installation
    if ! verify_installation; then
        log_error "PowerShell installation verification failed"
        return 1
    fi
    
    log_success "PowerShell 7+ installation completed successfully"
    echo
    log_info "You can now run 'pwsh' to start PowerShell"
    
    return 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi