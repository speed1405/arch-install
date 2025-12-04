#!/usr/bin/env bash
# Dependency installer for Arch Linux Installer GUI
# Downloads and installs required Python dependencies before starting the GUI

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

check_python() {
    log_info "Checking for Python 3..."
    if command -v python3 >/dev/null 2>&1; then
        local py_version=$(python3 --version 2>&1 | awk '{print $2}')
        log_info "Python 3 found: version $py_version"
        return 0
    else
        log_warn "Python 3 not found."
        return 1
    fi
}

install_python() {
    log_info "Installing Python 3..."
    local output
    if output=$(pacman -Sy --noconfirm python 2>&1); then
        log_info "Python 3 installed successfully."
        return 0
    else
        log_error "Failed to install Python 3"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

check_dialog() {
    log_info "Checking for dialog utility..."
    if command -v dialog >/dev/null 2>&1; then
        log_info "dialog utility found."
        return 0
    else
        log_warn "dialog utility not found."
        return 1
    fi
}

install_dialog() {
    log_info "Installing dialog utility..."
    local output
    if output=$(pacman -Sy --noconfirm dialog 2>&1); then
        log_info "dialog utility installed successfully."
        return 0
    else
        log_error "Failed to install dialog utility"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

check_python_dialog() {
    log_info "Checking for python-dialog library..."
    if python3 -c "import dialog" 2>/dev/null; then
        log_info "python-dialog library found."
        return 0
    else
        log_warn "python-dialog library not found."
        return 1
    fi
}

install_python_dialog() {
    log_info "Installing python-dialog library..."
    local output
    if output=$(pacman -Sy --noconfirm python-dialog 2>&1); then
        log_info "python-dialog library installed successfully."
        return 0
    else
        log_error "Failed to install python-dialog library"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

verify_gui_files() {
    log_info "Verifying GUI files..."
    local missing=()
    
    if [[ ! -f "${SCRIPT_DIR}/installer_gui.py" ]]; then
        missing+=("installer_gui.py")
    fi
    
    if [[ ! -f "${SCRIPT_DIR}/gui_wrapper.py" ]]; then
        missing+=("gui_wrapper.py")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing GUI files: ${missing[*]}"
        return 1
    fi
    
    # Make sure they're executable
    chmod +x "${SCRIPT_DIR}/installer_gui.py" 2>/dev/null || true
    chmod +x "${SCRIPT_DIR}/gui_wrapper.py" 2>/dev/null || true
    
    log_info "GUI files verified."
    return 0
}

update_package_database() {
    log_info "Updating package database..."
    local output
    if output=$(pacman -Sy 2>&1); then
        log_info "Package database updated."
    else
        log_warn "Package database update had issues (continuing anyway)"
        echo "$output" | grep -v "warning:" >&2 || true
    fi
}

main() {
    echo ""
    echo "============================================================"
    echo "  Arch Linux Installer - GUI Dependency Setup"
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
    
    # Update package database first
    update_package_database
    
    # Check and install Python if needed
    if ! check_python; then
        install_python || exit 1
    fi
    
    # Check and install dialog if needed
    if ! check_dialog; then
        install_dialog || exit 1
    fi
    
    # Check and install python-dialog if needed
    if ! check_python_dialog; then
        install_python_dialog || exit 1
    fi
    
    # Verify GUI files exist
    if ! verify_gui_files; then
        exit 1
    fi
    
    echo ""
    log_info "All dependencies installed successfully!"
    log_info "The installer GUI is ready to use."
    echo ""
    
    return 0
}

main "$@"
