#!/usr/bin/env bash
# Server utilities: SSH hardening, firewalls, monitoring.
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing server packages"
install_pkgs \
  openssh fail2ban ufw nftables \
  cockpit cockpit-pcp cockpit-machines \
  prometheus-node-exporter grafana-agent \
  logrotate smartmontools hdparm lm_sensors

log_step "Enabling services"
systemctl enable --now sshd.service
systemctl enable --now fail2ban.service
systemctl enable --now ufw.service
systemctl enable cockpit.socket
systemctl enable --now prometheus-node-exporter.service || log_info "node-exporter not available"

log_info "Use 'ufw enable' to activate firewall rules, then customize /etc/fail2ban jail configs as needed."
