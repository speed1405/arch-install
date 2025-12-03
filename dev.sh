#!/usr/bin/env bash
# Developer workstation bundle: toolchains, runtimes, containers.
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing developer toolchain packages"
install_pkgs \
  base-devel git github-cli \
  clang gcc gdb lldb cmake ninja ccache \
  go rustup nodejs npm yarn python python-pipx python-virtualenv \
  docker docker-buildx docker-compose podman podman-docker buildah skopeo \
  direnv just ripgrep fd neovim tmux starship

log_step "Enabling container services"
systemctl enable --now docker.service
systemctl enable --now podman.socket || log_info "Podman socket enable failed (not available)."

log_step "Developer bundle complete"
log_info "Consider adding your user to the docker group (usermod -aG docker <user>)."
