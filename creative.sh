#!/usr/bin/env bash
# Creative workstation (audio/video/graphics).
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing creative applications"
install_pkgs \
  gimp krita inkscape blender \
  darktable rawtherapee digikam \
  kdenlive shotcut obs-studio ardour audacity calf lsp-plugins \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack helvum qpwgraph \
  fontconfig-adobe-source-han-sans-jp

log_step "Creative bundle complete"
log_info "Launch 'pw-metadata -n settings 0 clock.force-quantum 256' if you need low-latency audio defaults."
