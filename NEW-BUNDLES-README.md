# New Bundles - Quick Start Guide

This guide covers the 5 new bundles added to enhance your Arch Linux installation.

## 🎯 Quick Installation

Run any bundle after your base Arch installation:

```bash
# Download if needed
git clone https://github.com/speed1405/arch-install
cd arch-install

# Make executable (if not already)
chmod +x *.sh

# Install bundles (recommended order)
sudo ./aur-helper.sh      # 1. AUR access (2 min)
sudo ./optimization.sh    # 2. Performance (3 min)
sudo ./security.sh        # 3. Security (5 min)
sudo ./networking.sh      # 4. Network tools (5 min)
sudo ./sysadmin.sh        # 5. Admin tools (7 min)

# Reboot to apply all changes
sudo reboot
```

## 📦 Bundle Details

### 1. aur-helper.sh

**What it does:** Installs an AUR helper (yay or paru) to access the Arch User Repository

**Why you need it:**
- Access to 70,000+ community packages
- One-command installation instead of manual building
- Essential for most Arch users

**Installation:**
```bash
# Install yay (default)
sudo ./aur-helper.sh

# Or install paru instead
sudo AUR_HELPER=paru ./aur-helper.sh
```

**After installation:**
```bash
# Search AUR
yay -Ss <package>

# Install from AUR
yay -S <package>

# Update everything (official + AUR)
yay -Syu
```

### 2. optimization.sh

**What it does:** Optimizes system performance and efficiency

**Features:**
- ✅ Parallel pacman downloads (5x faster)
- ✅ Colored pacman output
- ✅ zram compressed swap (saves RAM)
- ✅ SSD TRIM automation
- ✅ Optimized I/O schedulers
- ✅ Journal size limits
- ✅ TLP for laptops (auto-detected)
- ✅ Microcode updates

**Installation:**
```bash
sudo ./optimization.sh
```

**Verify results:**
```bash
# Check parallel downloads
grep ParallelDownloads /etc/pacman.conf

# Check zram
swapon --show

# Check I/O scheduler
cat /sys/block/sda/queue/scheduler
```

### 3. security.sh

**What it does:** Hardens system security with multiple layers of protection

**Features:**
- ✅ UFW firewall (enabled with default deny)
- ✅ ClamAV antivirus
- ✅ rkhunter rootkit detection
- ✅ AppArmor access control
- ✅ USBGuard protection
- ✅ Kernel hardening
- ✅ SSH hardening
- ✅ Daily security audits

**Installation:**
```bash
sudo ./security.sh
```

**Post-install:**
```bash
# Run security check
security-check

# Check firewall status
sudo ufw status

# Scan for viruses
clamscan -r /home

# Check for rootkits
sudo rkhunter --check

# Monitor CVEs
arch-audit
```

**Important:** Test in a VM first! Some settings are restrictive.

### 4. networking.sh

**What it does:** Installs network analysis and management tools

**Features:**
- ✅ Wireshark (packet analysis)
- ✅ nmap (network scanning)
- ✅ tcpdump (packet capture)
- ✅ mtr (traceroute + ping)
- ✅ iftop (bandwidth by connection)
- ✅ nethogs (bandwidth by process)
- ✅ NetworkManager (WiFi GUI)
- ✅ Bluetooth support

**Installation:**
```bash
sudo ./networking.sh
```

**Usage:**
```bash
# Analyze network traffic
sudo wireshark

# Scan network
nmap -sn 192.168.1.0/24

# Monitor bandwidth
sudo iftop
sudo nethogs

# Network diagnostics
mtr google.com
```

### 5. sysadmin.sh

**What it does:** Installs system administration and maintenance tools

**Features:**
- ✅ Modern monitoring (btop, glances)
- ✅ Disk utilities (ncdu, smartmontools)
- ✅ Backup tools (timeshift, restic, borg)
- ✅ Modern CLI tools (fzf, ripgrep, fd, bat, exa)
- ✅ Maintenance scripts (sysmaint)
- ✅ 15+ useful aliases
- ✅ etckeeper (/etc version control)
- ✅ Automatic mirror updates

**Installation:**
```bash
sudo ./sysadmin.sh
```

**New commands:**
```bash
# Run system maintenance
sysmaint

# Use modern aliases (reload shell first)
ll              # Better ls
df              # Better disk free
top             # Better top (btop)
cat myfile      # Better cat (bat)

# Package management
pacclean        # Clean all caches
mirrors         # Update mirror list
sysup           # Full system update
orphans         # List orphaned packages
```

## 🎨 Recommended Combinations

### Desktop Workstation
```bash
aur-helper.sh + optimization.sh + desktop-utilities.sh + sysadmin.sh
```

### Developer Machine
```bash
aur-helper.sh + optimization.sh + dev.sh + sysadmin.sh + networking.sh
```

### Secure Server
```bash
optimization.sh + security.sh + server.sh + sysadmin.sh
```

### Gaming PC
```bash
aur-helper.sh + optimization.sh + gaming.sh + desktop-utilities.sh
```

### Minimal Setup (Essential)
```bash
aur-helper.sh + optimization.sh
```

## 📊 Resource Usage

| Bundle | RAM | Disk Space | Install Time |
|--------|-----|------------|--------------|
| aur-helper.sh | +50 MB | +20 MB | ~2 min |
| optimization.sh | -100 MB* | +50 MB | ~3 min |
| security.sh | +150 MB | +100 MB | ~5 min |
| networking.sh | +200 MB | +300 MB | ~5 min |
| sysadmin.sh | +300 MB | +500 MB | ~7 min |

*optimization.sh actually saves RAM via zram

## 🔧 Customization

### AUR Helper Choice
```bash
# Install yay (default)
sudo ./aur-helper.sh

# Install paru instead
sudo AUR_HELPER=paru ./aur-helper.sh
```

### Adjust Pacman Settings
Edit `/etc/pacman.conf` after running optimization.sh:
```ini
# Change number of parallel downloads
ParallelDownloads = 10

# Disable ILoveCandy if you prefer regular progress bar
#ILoveCandy
```

### Modify Security Level
Edit `/etc/sysctl.d/99-security.conf` to adjust kernel parameters

### Configure Firewall
```bash
# Allow specific port
sudo ufw allow 8080

# Check rules
sudo ufw status numbered

# Delete rule
sudo ufw delete <number>
```

## 🐛 Troubleshooting

### AUR Helper Issues
```bash
# If build fails, install dependencies
sudo pacman -S base-devel git

# Check which user was detected
echo $INSTALL_USER

# Manually set user
sudo INSTALL_USER=yourusername ./aur-helper.sh
```

### Performance Issues
```bash
# Check if zram is active
swapon --show
zramctl

# Restart zram if needed
sudo systemctl restart systemd-zram-setup@zram0.service
```

### Security Issues
```bash
# If SSH becomes inaccessible:
# 1. Use console/VNC to login
# 2. Check SSH config
sudo systemctl status sshd
sudo journalctl -u sshd -n 50

# Temporarily disable firewall if needed
sudo ufw disable
# (Don't forget to re-enable!)
```

### Network Tools Issues
```bash
# If Wireshark can't capture packets:
sudo usermod -aG wireshark $USER
sudo setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap
# Logout and login again
```

## 📚 Documentation

For more details, see:
- **QUICK-REFERENCE.md** - Quick reference guide
- **ADDITIONS-SUMMARY.md** - Comprehensive feature overview
- **FEATURE-SUGGESTIONS.md** - 34+ more enhancement ideas
- **BEFORE-AFTER.md** - Impact comparison

## ⚠️ Important Notes

1. **Always backup** before running scripts that modify system configuration
2. **Test in VM first** especially for security.sh
3. **Read script contents** to understand what changes will be made
4. **One at a time** - Install bundles incrementally, not all at once
5. **Reboot after** - Many optimizations require reboot to take effect

## 🎓 Learning

Each bundle is a learning resource for:
- Bash scripting best practices
- System administration
- Security hardening
- Performance optimization
- Package management

Feel free to read the scripts and adapt them for your needs!

## 🤝 Contributing

Found an issue or have suggestions? See **FEATURE-SUGGESTIONS.md** for ideas or open an issue on GitHub.

---

**Happy optimizing! 🚀**
