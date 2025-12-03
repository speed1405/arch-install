#!/usr/bin/env bash
# System optimization bundle
# Applies common performance and efficiency improvements
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

if [[ $EUID -ne 0 ]]; then
  fail "This script must be run as root (use sudo)"
fi

log_step "Optimizing pacman configuration"

# Enable parallel downloads
if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
  log_info "Enabling parallel downloads (5 concurrent)"
  sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
fi

# Enable color output
if ! grep -q "^Color" /etc/pacman.conf; then
  log_info "Enabling colored output"
  sed -i 's/^#Color/Color/' /etc/pacman.conf
fi

# Enable VerbosePkgLists
if ! grep -q "^VerbosePkgLists" /etc/pacman.conf; then
  log_info "Enabling verbose package lists"
  sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
fi

# Add ILoveCandy for Pac-Man progress bar
if ! grep -q "ILoveCandy" /etc/pacman.conf; then
  log_info "Adding Pac-Man style progress bar"
  sed -i '/^VerbosePkgLists/a ILoveCandy' /etc/pacman.conf
fi

log_step "Configuring system performance"

# Adjust swappiness for better performance
if [[ -f /etc/sysctl.d/99-swappiness.conf ]] && grep -q "vm.swappiness" /etc/sysctl.d/99-swappiness.conf; then
  log_info "Swappiness already configured"
else
  log_info "Setting swappiness to 10 (prefer RAM over swap)"
  mkdir -p /etc/sysctl.d
  echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
  sysctl -p /etc/sysctl.d/99-swappiness.conf
fi

# Enable zram for compressed swap in RAM
log_step "Installing zram-generator for compressed swap"
install_pkgs zram-generator

log_info "Configuring zram"
mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

systemctl daemon-reload
systemctl start systemd-zram-setup@zram0.service

# Enable SSD TRIM support
log_step "Enabling SSD TRIM support"
if systemctl list-unit-files | grep -q fstrim.timer; then
  systemctl enable fstrim.timer
  log_info "Weekly SSD TRIM scheduled"
else
  log_info "fstrim.timer not available (may not have SSD)"
fi

# Optimize I/O scheduler for SSDs
log_step "Optimizing I/O scheduler"
cat > /etc/udev/rules.d/60-ioschedulers.rules <<EOF
# Set deadline scheduler for SSDs
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# Set BFQ scheduler for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
log_info "I/O schedulers configured (mq-deadline for SSD, BFQ for HDD)"

# Install and configure irqbalance
log_step "Installing IRQ balancing daemon"
install_pkgs irqbalance
systemctl enable --now irqbalance.service
log_info "IRQ balancing enabled for better multi-core performance"

# Journal size management
log_step "Configuring systemd journal limits"
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/00-journal-size.conf <<EOF
[Journal]
SystemMaxUse=500M
SystemMaxFileSize=50M
MaxRetentionSec=1month
EOF
systemctl restart systemd-journald
log_info "Journal size limited to 500MB"

# Install power management tools for laptops
has_battery=false
for battery_path in /sys/class/power_supply/BAT* /sys/class/power_supply/battery; do
  if [[ -d "$battery_path" ]]; then
    has_battery=true
    break
  fi
done

if [[ "$has_battery" == "true" ]]; then
  log_step "Laptop battery detected, installing TLP"
  install_pkgs tlp tlp-rdw
  systemctl enable tlp.service
  systemctl mask systemd-rfkill.service systemd-rfkill.socket
  log_info "TLP power management enabled"
  log_info "Configure /etc/tlp.conf for advanced settings"
else
  log_info "No battery detected, skipping laptop power tools"
fi

# Enable microcode updates
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
  if ! pacman -Q intel-ucode &>/dev/null; then
    log_step "Installing Intel microcode"
    install_pkgs intel-ucode
    log_info "Intel microcode installed (bootloader should be regenerated)"
  fi
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
  if ! pacman -Q amd-ucode &>/dev/null; then
    log_step "Installing AMD microcode"
    install_pkgs amd-ucode
    log_info "AMD microcode installed (bootloader should be regenerated)"
  fi
fi

log_step "System optimization complete"
log_info "Recommendations:"
log_info "  - Reboot to apply all changes"
log_info "  - Check 'swapon' to verify zram is active"
log_info "  - Monitor performance with 'htop' or 'btop'"
log_info "  - For laptops, review /etc/tlp.conf settings"
