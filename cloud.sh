#!/usr/bin/env bash
# Cloud/devops toolkit.
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing cloud tooling"
install_pkgs \
  ansible terraform packer \
  kubectl helm k9s kind minikube \
  aws-cli-v2 azure-cli google-cloud-cli \
  podman podman-compose skopeo buildah \
  direnv age sops jq yq

log_info "Cloud bundle complete. Configure provider credentials (aws configure, az login, gcloud init) after first boot."
