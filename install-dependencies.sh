#!/usr/bin/env bash
# Dependency installer for Arch Linux Installer TUI
# Downloads and installs gum TUI tool before starting the installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}==>${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

log_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

check_network() {
    log_info "Checking network connectivity..."
    if ! ping -c 1 -W 2 archlinux.org >/dev/null 2>&1; then
        log_error "No network connectivity detected."
        log_error "Please configure networking before running this installer."
        log_error "You can use: iwctl, nmcli, or check your Ethernet connection."
        return 1
    fi
    log_info "Network connectivity confirmed."
    return 0
}

check_gum() {
    log_info "Checking for gum TUI tool..."
    if command -v gum >/dev/null 2>&1; then
        local gum_version
        gum_version=$(gum --version 2>&1 | head -1) || gum_version="unknown"
        log_info "gum found: $gum_version"
        return 0
    else
        log_warn "gum not found."
        return 1
    fi
}

install_gum() {
    log_info "Installing gum from Arch repos..."
    local output
    # Use -S (not -Sy) since database was already refreshed in update_package_database()
    if output=$(pacman -S --noconfirm gum 2>&1); then
        log_info "gum installed successfully."
        return 0
    else
        log_error "Failed to install gum"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

verify_installer_files() {
    log_info "Verifying installer files..."
    
    if [[ ! -f "${SCRIPT_DIR}/install-arch.sh" ]]; then
        log_error "Missing installer file: install-arch.sh"
        return 1
    fi
    
    # Make sure it's executable
    chmod +x "${SCRIPT_DIR}/install-arch.sh" 2>/dev/null || true
    
    log_info "Installer files verified."
    return 0
}

update_package_database() {
    log_info "Updating package database..."
    local output
    # Refresh package database once at startup with -Sy
    # Individual package installations use -S (no refresh) to avoid redundant syncs
    if output=$(pacman -Sy 2>&1); then
        log_info "Package database updated."
        return 0
    else
        log_error "Failed to update package database"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

main() {
    echo ""
    echo "============================================================"
    echo "  Arch Linux Installer - TUI Dependency Setup"
    echo "============================================================"
    echo ""
    
    # Check if running as root
    if [[ ${EUID} -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
    
    # Check network connectivity
    if ! check_network; then
        exit 1
    fi
    
    # Total steps for progress calculation
    current_step=0
    local total_steps=2
    
    # Update package database first
    ((current_step++))
    log_info "[${current_step}/${total_steps}] Updating package database..."
    update_package_database || exit 1
    
    # Check and install gum if needed
    ((current_step++))
    log_info "[${current_step}/${total_steps}] Checking gum TUI tool..."
    if ! check_gum; then
        install_gum || exit 1
    fi
    
    # Verify installer files exist
    if ! verify_installer_files; then
        exit 1
    fi
    
    echo ""
    log_info "✓ All ${total_steps} dependency checks completed successfully!"
    log_info "✓ The installer TUI is ready to use."
    echo ""
    
    return 0
}

main "$@"
