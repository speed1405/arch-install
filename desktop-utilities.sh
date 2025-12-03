#!/usr/bin/env bash
# Desktop essentials bundle: browsers, media, office, printing.
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing desktop applications"
install_pkgs \
  firefox chromium thunderbird \
  vlc mpv celluloid \
  libreoffice-fresh hunspell-en_us \
  gnome-keyring seahorse keepassxc \
  flatpak gnome-software-packagekit-plugin \
  cups cups-pdf system-config-printer sane airscan \
  printer-support brlaser simplescan

log_step "Enabling desktop services"
systemctl enable --now cups.socket
systemctl enable --now avahi-daemon.service

log_info "Run 'flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo' after reboot if you plan to use Flatpak apps."
