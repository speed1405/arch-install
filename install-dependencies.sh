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
    # Use -S (not -Sy) since database was already refreshed in update_package_database()
    if output=$(pacman -S --noconfirm python 2>&1); then
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
    if output=$(pacman -S --noconfirm dialog 2>&1); then
        log_info "dialog utility installed successfully."
        return 0
    else
        log_error "Failed to install dialog utility"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

check_pip() {
    log_info "Checking for pip..."
    if python3 -m pip --version >/dev/null 2>&1; then
        log_info "pip found."
        return 0
    else
        log_warn "pip not found."
        return 1
    fi
}

install_pip() {
    log_info "Installing pip..."
    local output
    if output=$(pacman -S --noconfirm python-pip 2>&1); then
        log_info "pip installed successfully."
        return 0
    else
        log_error "Failed to install pip"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

check_python_dialog() {
    log_info "Checking for pythondialog library..."
    if python3 -c "import dialog" 2>/dev/null; then
        log_info "pythondialog library found."
        return 0
    else
        log_warn "pythondialog library not found."
        return 1
    fi
}

install_python_dialog() {
    log_info "Installing pythondialog library via pip..."
    local output
    # --break-system-packages is required in Arch ISO live environment because:
    # 1. Newer pip versions (PEP 668) prevent system-wide installations by default
    # 2. This protects against conflicts with system package managers
    # 3. Safe in the live ISO since it's a temporary, isolated environment
    if output=$(python3 -m pip install --break-system-packages pythondialog 2>&1); then
        log_info "pythondialog library installed successfully."
        return 0
    else
        log_error "Failed to install pythondialog library"
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
    # Refresh package database once at startup with -Sy
    # Individual package installations use -S (no refresh) to avoid redundant syncs
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
    
    # Check and install pip if needed
    if ! check_pip; then
        install_pip || exit 1
    fi
    
    # Check and install pythondialog if needed
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
