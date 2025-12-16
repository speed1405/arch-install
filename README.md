# Arch Linux Installer with Gum TUI

`install-arch.sh` is a modern, user-friendly installer built from scratch with a gum-based TUI (Text User Interface). It runs from the official Arch ISO and guides you through the installation process with interactive menus and progress indicators. The installer auto-detects hardware (boot mode, CPU, GPU, memory, virtualization) and provides an intuitive workflow for configuring your system. **Now with Beginner Mode** for first-time Linux users! Pair it with `install-desktop.sh` to add full desktop environments like GNOME, KDE Plasma, XFCE, Cinnamon, MATE, Budgie, LXQt, Sway, or i3.

## ✨ New: Beginner Mode

The installer now features a **Beginner Mode** designed specifically for new Linux users:

- **📚 Simplified Options**: Recommended choices clearly marked with ⭐ symbols
- **📖 Clear Explanations**: Technical terms explained in plain language
- **💡 Helpful Tips**: Guidance throughout the installation process
- **✅ Pre-Installation Checklist**: Ensure you're ready before starting
- **🔒 Encryption Guide**: Understand pros/cons before deciding
- **👤 User-Friendly Prompts**: Step-by-step account and system setup

Beginner Mode provides the same powerful installation capabilities but with extra guidance and explanations to help you make informed decisions.

## TUI Tool

The installer uses **gum** - a modern, glamorous TUI tool for shell scripts:

- **gum** - Beautiful TUI with colors, styles, and interactive components (install from Arch repos: `pacman -S gum`)

Gum provides an enhanced user experience with:
- Colorful, styled prompts and menus
- Interactive input fields with placeholders
- Multi-select checklists
- Progress indicators
- Better keyboard navigation

The installer will check for gum at startup and guide you to install it if needed.

## TUI Screenshots

📸 **See the TUI in action!** View example screenshots of all dialog types in [GUI-SCREENSHOTS.md](GUI-SCREENSHOTS.md) or check the [screenshots/](screenshots/) directory.

## What the Installer Does

The installer uses a gum-based TUI to provide a friendly, text-based installation experience with progress indicators:

1. **Welcome Screen** - Introduces the installer and its features
2. **Mode Selection** - Choose between Beginner Mode (with extra guidance) or Advanced Mode
3. **Pre-Installation Checklist** - (Beginner Mode) Ensure you're prepared for installation
4. **Hardware Summary** - Displays detected boot mode, CPU, microcode, GPU, memory, and virtualization
5. **Disk Selection** - Interactive menu to choose installation disk with confirmation
6. **Filesystem Type** - Choose between ext4 (traditional) or Btrfs (modern with snapshots)
7. **Partition Layout** - Select layout:
   - Single partition (simple) ⭐ Recommended for beginners
   - LVM (flexible volume management)
   - LVM with separate /home
   - Btrfs subvolumes (@, @home, @var_log, etc.)
8. **Disk Encryption** - Optional LUKS encryption with detailed explanation and secure passphrase entry
9. **System Settings** - Configure hostname, timezone, locale, and keyboard layout via menus
10. **User Accounts** - Set up root and primary user with secure password prompts
11. **Mirror Selection** - Choose package mirror region for faster downloads (Worldwide, US, Europe, Asia, etc.)
12. **Desktop Environment** - Choose from 10 desktop options or minimal install
13. **Software Bundles** - Select optional bundles (dev tools, gaming, server, cloud, creative, utilities, optimization, security, networking, sysadmin)
14. **AUR Helper** - Choose AUR helper (yay, paru, or none) for accessing community packages
15. **Installation Summary** - Review all settings before proceeding
16. **Automated Installation** - Enhanced progress bars show installation stages with detailed feedback
    - All selected packages (base, desktop, bundles) installed together in one efficient operation
    - Post-installation configuration for services and settings
    - AUR helper installation (if selected)
17. **Completion** - Success message with next steps

All user interaction happens through gum TUI menus with progress indicators, making the installation process intuitive and providing clear feedback on progress.

## Usage

1. Boot into the Arch ISO and ensure networking is up. The installer will check connectivity automatically.

2. Download or copy the installer scripts onto the live system:

   ```bash
   # Example: download directly
   curl -O https://raw.githubusercontent.com/speed1405/arch-install/main/install-arch.sh
   curl -O https://raw.githubusercontent.com/speed1405/arch-install/main/install-desktop.sh
   
   # Or use scp, USB, etc.
   ```

3. Make the scripts executable:
   
   ```bash
   chmod +x install-arch.sh
   ```

4. Run the installer:

   ```bash
   ./install-arch.sh
   ```

   The installer will automatically verify that gum is available (install with `pacman -S gum` if needed).

5. Follow the TUI prompts:
   - Select your installation disk
   - Choose filesystem and layout options
   - Configure encryption if desired
   - Set system settings (hostname, timezone, locale)
   - Create user accounts
   - Select desktop environment
   - Choose optional software bundles

6. Review the installation summary and confirm

7. Wait for the automated installation to complete

8. Reboot into your new Arch Linux system!

The installer is fully interactive through gum TUI dialogs - no manual configuration needed.

## Interactive TUI Features

The gum-based TUI interface provides:

- **Menu Navigation**: Arrow keys to select, Enter to confirm
- **Input Fields**: Text entry with placeholders for hostnames, usernames, etc.
- **Password Fields**: Secure password entry (hidden characters)
- **Confirmation Prompts**: Clear yes/no dialogs
- **Multi-Select Lists**: Interactive checklists for software bundles
- **Progress Indicators**: Real-time installation progress with status messages
- **Modern Styling**: Clean TUI aesthetics with colors and better readability
- **Styled Output**: Enhanced colors and formatting throughout

The TUI works in any terminal and provides a beautiful, modern interface for the installation process.

## Storage Options

The installer provides interactive gum TUI menus for all storage configuration:

### Filesystem Types
- **ext4**: Traditional, stable Linux filesystem (recommended for most users)
- **Btrfs**: Modern copy-on-write filesystem with snapshot support and compression

### Partition Layouts
- **Single Partition**: Simple root partition only - easiest option
- **LVM**: Logical Volume Management for flexible storage management
- **LVM with /home**: Separate root and home logical volumes
- **Btrfs Subvolumes**: Automatic creation of @ (root), @home, @var_log, @var_cache, @snapshots

### Disk Encryption
- Optional LUKS encryption for root partition
- Secure passphrase entry through gum password prompts
- Confirmation prompt to prevent typos

### Boot Modes
- Automatic detection of UEFI or BIOS/Legacy mode
- **UEFI**: 512 MB EFI partition, defaults to systemd-boot
- **BIOS**: 1 MB BIOS boot partition, uses GRUB

## Desktop Environments

Select from popular desktop environments during installation:

- **GNOME** - Modern, feature-rich desktop with GDM
- **KDE Plasma** - Customizable and powerful with SDDM
- **XFCE** - Lightweight and fast with LightDM
- **Cinnamon** - Traditional desktop experience with LightDM
- **MATE** - Classic GNOME 2 desktop with LightDM
- **Budgie** - Clean and elegant with GDM
- **LXQt** - Lightweight Qt desktop with SDDM
- **Sway** - Tiling Wayland compositor with greetd
- **i3** - Tiling window manager with LightDM
- **None** - Minimal install (server/headless)

The `install-desktop.sh` script can also be run post-installation to add a desktop environment later.

## Software Bundles

Software bundles are collections of related packages that can be selected during installation. **All selected packages are installed together with the base system** for efficiency.

### Core Bundles
- **dev.sh** - Developer tools (compilers, Docker, Podman, Git, language runtimes)
- **gaming.sh** - Gaming setup (Steam, Lutris, Wine, Gamemode, MangoHUD)
- **server.sh** - Server tools (SSH hardening, firewall, monitoring)
- **cloud.sh** - Cloud tools (kubectl, Helm, Terraform, cloud CLIs)
- **creative.sh** - Creative applications (GIMP, Blender, Kdenlive, Inkscape)
- **desktop-utilities.sh** - Desktop utilities (browsers, office suite, media players)

### Additional Bundles
- **optimization.sh** - System optimization (pacman config, zram, SSD TRIM, performance tuning)
- **security.sh** - Security hardening (firewall, ClamAV, AppArmor, kernel hardening, SSH hardening)
- **networking.sh** - Network tools (Wireshark, nmap, mtr, iftop, NetworkManager)
- **sysadmin.sh** - System administration (monitoring, backup tools, disk utilities, maintenance scripts)

### AUR Helper

The AUR (Arch User Repository) helper is selected separately from bundles:
- **yay** - Popular, user-friendly AUR helper (recommended for beginners)
- **paru** - Feature-rich, modern AUR helper
- **none** - Skip AUR helper installation (can be installed later)

AUR helpers are installed after the base system and configured for the primary user account.

Bundles can be selected via gum TUI checklist during installation. See **FEATURE-SUGGESTIONS.md** for even more enhancement ideas.

## Safety Notes

- The installer **completely erases** the selected disk - double-check your selection!
- All sensitive operations (disk erase, encryption setup) require explicit confirmation
- Passwords are entered through secure gum password prompts (hidden input)
- Hardware detection runs automatically to select appropriate drivers and microcode
- The installer validates network connectivity before proceeding
- Progress is shown in real-time with progress indicators

## Requirements

The installer requires:
- Arch Linux ISO (booted in live environment)
- Network connectivity (checked automatically)
- Root privileges

**TUI Dependencies**:
- **gum** - Modern TUI tool (install from Arch repos with `pacman -S gum`)

All other required tools (lsblk, parted, mkfs, cryptsetup, etc.) are checked automatically at startup.

## Technical Details

- Written in Bash with strict error handling (`set -euo pipefail`)
- Modern gum-based TUI with beautiful, colorful interface
- Modular design with separate functions for each installation stage
- Automatic hardware detection (CPU vendor, GPU, memory, virtualization)
- Supports both UEFI and BIOS/Legacy boot modes
- Intelligent bootloader selection (systemd-boot for UEFI, GRUB for BIOS)
- Automatic microcode installation (Intel or AMD)
- Smart swap size calculation based on available RAM
- Proper LUKS/LVM integration when encryption or LVM is enabled
- Btrfs-aware swapfile creation (disables CoW)

## License

This project is provided as-is for the Arch Linux community. Use at your own risk.
