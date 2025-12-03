#!/usr/bin/env bash
# Security and privacy hardening bundle
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

log_step "Installing security packages"
install_pkgs \
  ufw \
  clamav freshclam \
  rkhunter \
  apparmor \
  firejail \
  veracrypt \
  keepassxc \
  arch-audit \
  usbguard

log_step "Configuring firewall (UFW)"
systemctl enable --now ufw.service
ufw default deny incoming
ufw default allow outgoing
ufw limit ssh
ufw --force enable
log_info "Firewall enabled with default deny incoming"
log_info "SSH limited (rate limiting enabled)"

log_step "Configuring ClamAV antivirus"
log_info "Updating virus definitions (this may take a while)..."
freshclam || log_info "Initial freshclam update may fail, will retry on timer"
systemctl enable --now clamav-freshclam.service
log_info "ClamAV configured with automatic definition updates"
log_info "Run 'clamscan -r /home' to scan home directories"

log_step "Configuring rkhunter (rootkit detection)"
rkhunter --update || log_info "rkhunter update skipped"
rkhunter --propupd || log_info "rkhunter property update skipped"
log_info "Run 'rkhunter --check' to scan for rootkits"

log_step "Enabling AppArmor"
systemctl enable --now apparmor.service
log_info "AppArmor enabled for mandatory access control"
log_info "Check status with 'aa-status'"

log_step "Configuring USBGuard"
# Generate initial policy based on currently connected devices
usbguard generate-policy > /etc/usbguard/rules.conf || log_info "Failed to generate USBGuard policy"
systemctl enable --now usbguard.service
log_info "USBGuard enabled to protect against malicious USB devices"
log_info "Manage with 'usbguard' commands"

log_step "Applying kernel security hardening"
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-security.conf <<EOF
# IP forwarding (disable unless needed for routing/NAT)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Syncookies (protection against SYN flood attacks)
net.ipv4.tcp_syncookies = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable ICMP redirect acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable ICMP redirect sending
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log Martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests (optional, may break some network diagnostics)
# net.ipv4.icmp_echo_ignore_all = 1

# Disable IPv6 if not needed (uncomment to disable)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# Kernel hardening
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# Disable kexec (prevents replacing running kernel)
kernel.kexec_load_disabled = 1

# Restrict ptrace to only parent processes
kernel.yama.ptrace_scope = 1
EOF

sysctl -p /etc/sysctl.d/99-security.conf
log_info "Kernel security parameters applied"

log_step "Configuring SSH hardening (if sshd is installed)"
if pacman -Q openssh &>/dev/null; then
  if [[ -f /etc/ssh/sshd_config ]]; then
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Ensure sshd_config.d directory exists
    mkdir -p /etc/ssh/sshd_config.d
    
    # Apply hardening settings
    cat > /etc/ssh/sshd_config.d/99-hardening.conf <<EOF
# Security hardening
PermitRootLogin no
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2

# Use strong ciphers and MACs
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256

# Key-based authentication (recommended to set PasswordAuthentication no after setting up keys)
PubkeyAuthentication yes
EOF
    
    log_info "SSH hardening applied"
    log_info "IMPORTANT: Set up SSH keys and then disable password auth"
    log_info "Edit /etc/ssh/sshd_config.d/99-hardening.conf"
    systemctl reload sshd || log_info "sshd not running, changes will apply on start"
  fi
else
  log_info "OpenSSH not installed, skipping SSH hardening"
fi

log_step "Configuring automatic security updates monitoring"
# Install arch-audit for CVE monitoring
log_info "Use 'arch-audit' to check for vulnerable packages"

# Create a systemd timer for arch-audit
cat > /etc/systemd/system/arch-audit.service <<EOF
[Unit]
Description=Check for security updates

[Service]
Type=oneshot
ExecStart=/usr/bin/arch-audit
EOF

cat > /etc/systemd/system/arch-audit.timer <<EOF
[Unit]
Description=Daily security audit

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable arch-audit.timer
log_info "Daily security audit scheduled (check with 'systemctl status arch-audit')"

log_step "Creating security maintenance script"
cat > /usr/local/bin/security-check <<'EOF'
#!/bin/bash
# Security maintenance script
echo "==> Running security checks..."

echo "==> Checking for vulnerable packages..."
arch-audit

echo ""
echo "==> Checking for rootkits..."
rkhunter --check --skip-keypress --report-warnings-only

echo ""
echo "==> Firewall status..."
ufw status verbose

echo ""
echo "==> Failed login attempts..."
journalctl -u sshd -u systemd-logind --since "1 day ago" | grep -i "failed\|failure" | tail -20

echo ""
echo "==> USB device log (last 10)..."
usbguard list-devices | tail -10 || echo "USBGuard not active"

echo ""
echo "Security check complete!"
EOF

chmod +x /usr/local/bin/security-check
log_info "Created /usr/local/bin/security-check script"

log_step "Security hardening complete"
log_info "Next steps:"
log_info "  1. Review firewall rules: ufw status"
log_info "  2. Set up SSH keys and disable password auth"
log_info "  3. Run security check: security-check"
log_info "  4. Scan for viruses: clamscan -r /home"
log_info "  5. Check for rootkits: rkhunter --check"
log_info "  6. Review AppArmor status: aa-status"
log_info "  7. Monitor USB devices: usbguard list-devices"
log_info "  8. Check for CVEs: arch-audit"
log_info "Important: Test your system to ensure services work correctly"
log_info "Some restrictions may break functionality - adjust as needed"
