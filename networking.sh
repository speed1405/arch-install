#!/usr/bin/env bash
# Network utilities and tools bundle
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing network analysis tools"
install_pkgs \
  wireshark-qt wireshark-cli \
  nmap \
  tcpdump \
  gnu-netcat \
  mtr \
  traceroute \
  iftop \
  nethogs \
  bandwhich \
  ethtool \
  bind-tools \
  inetutils \
  net-tools \
  iproute2 \
  iperf3 \
  speedtest-cli

log_step "Installing network management"
install_pkgs \
  networkmanager \
  networkmanager-openvpn \
  network-manager-applet \
  nm-connection-editor

log_step "Installing wireless tools"
install_pkgs \
  wireless_tools \
  wpa_supplicant \
  iwd \
  bluez \
  bluez-utils

log_step "Enabling network services"
systemctl enable --now NetworkManager.service
systemctl enable --now bluetooth.service

log_step "Configuring Wireshark"
# Add wireshark group for non-root packet capture
groupadd -f wireshark
log_info "Wireshark group created"
log_info "Add users to wireshark group: usermod -aG wireshark <username>"
log_info "Then run: setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap"

log_step "Network tools bundle complete"
log_info "Installed tools:"
log_info "  - wireshark: GUI/CLI packet analyzer"
log_info "  - nmap: Network scanner and security auditing"
log_info "  - tcpdump: Command-line packet analyzer"
log_info "  - mtr: Network diagnostic (traceroute + ping)"
log_info "  - iftop: Bandwidth monitoring by connection"
log_info "  - nethogs: Bandwidth monitoring by process"
log_info "  - bandwhich: Terminal bandwidth utilization"
log_info "  - speedtest-cli: Internet speed testing"
log_info "NetworkManager enabled for easy network configuration"
log_info "Bluetooth support enabled"
