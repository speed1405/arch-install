#!/usr/bin/env bash
# AUR helper installation bundle
# Installs yay or paru for accessing Arch User Repository
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }
fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# Detect if we're running as root
if [[ $EUID -ne 0 ]]; then
  fail "This script must be run as root (use sudo)"
fi

# Get the first non-root user to build AUR packages
INSTALL_USER="${INSTALL_USER:-$(getent passwd 1000 | cut -d: -f1)}"
if [[ -z "$INSTALL_USER" ]]; then
  log_info "No regular user found, skipping AUR helper installation"
  exit 0
fi

log_step "Installing AUR helper prerequisites"
install_pkgs base-devel git

# Choose AUR helper (can be set via environment variable)
AUR_HELPER="${AUR_HELPER:-yay}"

case "$AUR_HELPER" in
  yay)
    log_step "Installing yay (Yet Another Yogurt)"
    AUR_URL="https://aur.archlinux.org/yay-bin.git"
    HELPER_NAME="yay"
    ;;
  paru)
    log_step "Installing paru (Feature-rich AUR helper)"
    AUR_URL="https://aur.archlinux.org/paru-bin.git"
    HELPER_NAME="paru"
    ;;
  *)
    log_info "Unknown AUR helper: $AUR_HELPER, defaulting to yay"
    AUR_URL="https://aur.archlinux.org/yay-bin.git"
    HELPER_NAME="yay"
    ;;
esac

# Build directory in user's home
BUILD_DIR="/tmp/aur-install-$$"
mkdir -p "$BUILD_DIR"
chown "$INSTALL_USER:$INSTALL_USER" "$BUILD_DIR"

# Clone and build as user (not root)
log_info "Cloning $HELPER_NAME repository..."
sudo -u "$INSTALL_USER" git clone "$AUR_URL" "$BUILD_DIR/$HELPER_NAME"

log_info "Building $HELPER_NAME package..."
cd "$BUILD_DIR/$HELPER_NAME"
sudo -u "$INSTALL_USER" makepkg -si --noconfirm

# Cleanup
log_info "Cleaning up build files..."
cd /
rm -rf "$BUILD_DIR"

# Configure AUR helper
if [[ "$HELPER_NAME" == "yay" ]]; then
  log_step "Configuring yay"
  sudo -u "$INSTALL_USER" yay --save --answerclean None --answerdiff None --removemake
elif [[ "$HELPER_NAME" == "paru" ]]; then
  log_step "Configuring paru"
  # paru config is in ~/.config/paru/paru.conf, created on first run
  sudo -u "$INSTALL_USER" mkdir -p "/home/$INSTALL_USER/.config/paru"
  cat > "/home/$INSTALL_USER/.config/paru/paru.conf" <<EOF
[options]
BottomUp
RemoveMake
CleanAfter
EOF
  chown "$INSTALL_USER:$INSTALL_USER" "/home/$INSTALL_USER/.config/paru/paru.conf"
fi

log_step "AUR helper installation complete"
log_info "$HELPER_NAME is now available for user '$INSTALL_USER'"
log_info "To use: sudo -u $INSTALL_USER $HELPER_NAME -S <package>"
log_info "Or login as $INSTALL_USER and run: $HELPER_NAME -S <package>"
