#!/usr/bin/env bash
# System administration tools bundle
set -euo pipefail
IFS=$'\n\t'

PACMAN_FLAGS=${PACMAN_FLAGS:---needed --noconfirm}
install_pkgs() {
  read -ra args <<< "$PACMAN_FLAGS"
  pacman "${args[@]}" -Syu "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }

log_step "Installing system monitoring tools"
install_pkgs \
  htop \
  btop \
  glances \
  iotop \
  sysstat \
  dstat \
  lsof \
  strace

log_step "Installing disk and filesystem tools"
install_pkgs \
  ncdu \
  dust \
  duf \
  gdu \
  smartmontools \
  hdparm \
  testdisk \
  ddrescue \
  lvm2 \
  cryptsetup

log_step "Installing system utilities"
install_pkgs \
  rsync \
  rclone \
  tree \
  tmux \
  screen \
  mc \
  ranger \
  fzf \
  ripgrep \
  fd \
  bat \
  exa

log_step "Installing backup tools"
install_pkgs \
  timeshift \
  rsnapshot \
  restic \
  borg

log_step "Installing system management"
install_pkgs \
  etckeeper \
  pacman-contrib \
  reflector \
  pkgfile \
  downgrade

log_step "Installing stress testing tools"
install_pkgs \
  stress \
  s-tui \
  cpupower

log_step "Configuring services"

# Enable smartd for disk health monitoring
systemctl enable --now smartd.service
log_info "SMART monitoring enabled for disk health"

# Enable sysstat for system statistics
systemctl enable --now sysstat.service
log_info "Sysstat enabled for performance statistics"

# Initialize etckeeper (git for /etc)
if [[ -d /etc/.git ]]; then
  log_info "etckeeper already initialized"
else
  log_info "Initializing etckeeper for /etc version control"
  etckeeper init
  etckeeper commit "Initial commit after sysadmin bundle installation"
fi

# Update pkgfile database
log_step "Updating pkgfile database"
pkgfile --update
log_info "pkgfile ready (use 'pkgfile <command>' to find which package provides a file)"

# Configure reflector for mirror management
log_step "Configuring reflector for automatic mirror updates"
mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf <<EOF
# Reflector configuration
--save /etc/pacman.d/mirrorlist
--protocol https
--country US,Canada,Germany
--latest 10
--sort rate
EOF

# Enable reflector timer
systemctl enable reflector.timer
log_info "Reflector will update mirrors weekly"

# Create useful aliases script
log_step "Creating system administration aliases"
cat > /etc/profile.d/sysadmin-aliases.sh <<'EOF'
# System administration aliases
alias ll='exa -la --git --icons 2>/dev/null || ls -lah'
alias lt='exa --tree --level=2 --icons 2>/dev/null || tree -L 2'
alias df='duf 2>/dev/null || df -h'
alias du='dust 2>/dev/null || du -h'
alias cat='bat --style=plain 2>/dev/null || cat'
alias top='btop 2>/dev/null || htop 2>/dev/null || top'
alias find='fd 2>/dev/null || find'
alias grep='rg 2>/dev/null || grep --color=auto'
alias pacclean='sudo pacman -Sc && paccache -r && paccache -ruk0'
alias pacdiff='sudo DIFFPROG=meld pacdiff'
alias mirrors='sudo reflector --verbose --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist'
alias sysup='sudo pacman -Syu && paru -Sua 2>/dev/null || yay -Sua 2>/dev/null || true'
alias orphans='pacman -Qtdq || echo "No orphan packages"'
alias failed='systemctl --failed'
alias services='systemctl list-units --type=service --state=running'
EOF
log_info "System aliases added to /etc/profile.d/sysadmin-aliases.sh"

# Create system maintenance script
log_step "Creating system maintenance script"
cat > /usr/local/bin/sysmaint <<'EOF'
#!/bin/bash
# System maintenance script

echo "==> System Maintenance <=="
echo ""

echo "==> Updating package database..."
pacman -Sy

echo ""
echo "==> Checking for updates..."
checkupdates || echo "System is up to date"

echo ""
echo "==> Orphaned packages:"
orphans=$(pacman -Qtdq)
if [[ -n "$orphans" ]]; then
  echo "$orphans"
  echo ""
  read -p "Remove orphaned packages? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo pacman -Rns $(pacman -Qtdq)
  fi
else
  echo "No orphaned packages found"
fi

echo ""
echo "==> Pacman cache size:"
du -sh /var/cache/pacman/pkg
echo ""
read -p "Clean pacman cache? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo paccache -r
  sudo paccache -ruk0
fi

echo ""
echo "==> Failed systemd services:"
systemctl --failed

echo ""
echo "==> Disk usage:"
duf 2>/dev/null || df -h

echo ""
echo "==> Large directories in /var:"
sudo du -h --max-depth=1 /var 2>/dev/null | sort -h | tail -10

echo ""
echo "==> System journal size:"
journalctl --disk-usage

echo ""
echo "==> SMART status (if available):"
for disk in /dev/sd? /dev/nvme?n?; do
  if [[ -e "$disk" ]]; then
    echo "  $disk: $(sudo smartctl -H "$disk" 2>/dev/null | grep -i "overall-health" || echo "N/A")"
  fi
done

echo ""
echo "Maintenance check complete!"
EOF

chmod +x /usr/local/bin/sysmaint
log_info "Created /usr/local/bin/sysmaint maintenance script"

log_step "Sysadmin bundle complete"
log_info ""
log_info "Useful commands:"
log_info "  sysmaint          - Run system maintenance checks"
log_info "  htop/btop         - Process monitoring"
log_info "  ncdu /            - Disk usage analyzer"
log_info "  smartctl -a /dev/sda - Check disk health"
log_info "  etckeeper commit  - Save /etc changes to git"
log_info "  pkgfile <file>    - Find package providing a file"
log_info "  reflector         - Update mirror list"
log_info "  paccache -r       - Clean pacman cache"
log_info ""
log_info "New aliases available (reload shell):"
log_info "  ll, lt, df, du, cat, top, find, grep"
log_info "  pacclean, mirrors, sysup, orphans, failed, services"
