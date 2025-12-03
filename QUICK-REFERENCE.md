# Quick Reference - New Features

## 🚀 Quick Install

```bash
# After Arch installation, run any of these bundles:

# 1. AUR Helper (recommended to run first)
sudo ./aur-helper.sh

# 2. System Optimization (recommended for all)
sudo ./optimization.sh

# 3. Security Hardening
sudo ./security.sh

# 4. Network Tools
sudo ./networking.sh

# 5. System Admin Tools
sudo ./sysadmin.sh

# Reboot to apply all changes
sudo reboot
```

## 📦 Bundle Overview

| Bundle | Size | Install Time | Purpose |
|--------|------|--------------|---------|
| **aur-helper.sh** | 20 MB | ~2 min | Install yay/paru for AUR |
| **optimization.sh** | 50 MB | ~3 min | Speed up system |
| **security.sh** | 100 MB | ~5 min | Harden security |
| **networking.sh** | 300 MB | ~5 min | Network analysis tools |
| **sysadmin.sh** | 500 MB | ~7 min | Admin & monitoring tools |

## 🎯 Recommended Setups

### Minimal System
```bash
aur-helper.sh + optimization.sh
```

### Desktop Workstation
```bash
aur-helper.sh + optimization.sh + desktop-utilities.sh + sysadmin.sh
```

### Developer Workstation
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

## 💻 New Commands

### Maintenance
```bash
sysmaint            # System maintenance check
security-check      # Security audit
```

### New Aliases
```bash
# Modern CLI tools (reload shell after sysadmin.sh)
ll                  # Better ls (exa)
lt                  # Tree view
df                  # Disk free (duf)
du                  # Disk usage (dust)
cat                 # Better cat (bat)
top                 # Better top (btop)

# Package management
pacclean            # Clean all caches
mirrors             # Update mirrors
sysup               # Full update (including AUR)
orphans             # List orphaned packages

# System status
failed              # Show failed services
services            # List running services
```

## ⚡ Performance Gains

After `optimization.sh`:
- ✅ 5x faster package downloads (parallel)
- ✅ Less swap usage (swappiness=10)
- ✅ Compressed RAM swap (zram)
- ✅ Optimized I/O schedulers
- ✅ Weekly SSD TRIM
- ✅ Better IRQ balancing
- ✅ Smaller journal size
- ✅ Laptop battery optimization (TLP)

## 🔒 Security Features

After `security.sh`:
- ✅ Firewall enabled (UFW)
- ✅ Antivirus (ClamAV)
- ✅ Rootkit detection (rkhunter)
- ✅ Mandatory access control (AppArmor)
- ✅ USB protection (USBGuard)
- ✅ Kernel hardening
- ✅ SSH hardening
- ✅ Daily security audits

## 🌐 Network Tools

After `networking.sh`:
- **Wireshark** - Packet analysis (GUI/CLI)
- **nmap** - Network scanning
- **mtr** - Traceroute + ping
- **iftop** - Bandwidth by connection
- **nethogs** - Bandwidth by process
- **NetworkManager** - Easy WiFi management

## 🛠️ Sysadmin Tools

After `sysadmin.sh`:
- **btop** - Modern system monitor
- **ncdu** - Disk usage analyzer
- **smartmontools** - Disk health
- **timeshift** - System snapshots
- **etckeeper** - /etc version control
- **reflector** - Mirror management

## 📖 Documentation Files

- **FEATURE-SUGGESTIONS.md** - 34+ enhancement ideas for future
- **ADDITIONS-SUMMARY.md** - Detailed summary of what was added
- **README.md** - Updated with new bundles
- **QUICK-REFERENCE.md** - This file

## ⚙️ Customization

### Change AUR Helper
```bash
# Install paru instead of yay
sudo AUR_HELPER=paru ./aur-helper.sh
```

### Configure Security Level
Edit `/etc/sysctl.d/99-security.conf` after running `security.sh`

### Adjust Optimization
Edit these after running `optimization.sh`:
- `/etc/pacman.conf` - Pacman settings
- `/etc/sysctl.d/99-swappiness.conf` - Swap behavior
- `/etc/systemd/zram-generator.conf` - zram size
- `/etc/tlp.conf` - Laptop power (if applicable)

## 🔍 Troubleshooting

### Check Service Status
```bash
systemctl --failed                    # Failed services
journalctl -xe                        # Recent logs
systemctl status <service>            # Specific service
```

### Security Issues
```bash
# If SSH becomes inaccessible:
# 1. Boot into rescue mode
# 2. Edit /etc/ssh/sshd_config.d/99-hardening.conf
# 3. Restart: systemctl restart sshd

# If firewall blocks needed service:
sudo ufw allow <port>
sudo ufw status
```

### Performance Issues
```bash
# Check zram status
swapon --show

# Check I/O scheduler
cat /sys/block/sda/queue/scheduler

# Monitor resources
btop
```

## 📊 Before & After

### Package Downloads
**Before:** Sequential (slow)  
**After:** 5 parallel downloads ⚡

### Swap Usage
**Before:** swappiness=60 (aggressive)  
**After:** swappiness=10 + zram (efficient)

### Security
**Before:** Open firewall  
**After:** Firewall + AppArmor + hardening 🔒

### System Monitoring
**Before:** Basic `top` command  
**After:** btop + glances + SMART monitoring 📊

## 🎓 Learning Path

1. Start with `optimization.sh` - Safe, immediate benefits
2. Add `aur-helper.sh` - Access to more software
3. Install `sysadmin.sh` - Better monitoring
4. Add `security.sh` - Harden system (test first!)
5. Explore `FEATURE-SUGGESTIONS.md` - Many more ideas

## 📞 Need More?

Check `FEATURE-SUGGESTIONS.md` for:
- 8 more bundle ideas
- Desktop customization
- Virtualization support
- Data science tools
- Home server features
- And 25+ more enhancements!

---

**Remember:** Always test bundles in a VM or non-critical system first!
