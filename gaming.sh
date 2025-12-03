#!/usr/bin/env bash
# Gaming and graphics stack.
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing gaming packages"
install_pkgs \
  steam lutris \
  wine-staging winetricks \
  gamemode lib32-gamemode \
  mangohud lib32-mangohud goverlay \
  vkbasalt lib32-vkbasalt \
  pipewire wireplumber pipewire-alsa pipewire-pulse pipewire-jack

log_step "Configuring services"
systemctl enable --now gamemoded.service

log_info "Consider enabling the multilib repo if not already active to keep 32-bit libraries updated."
