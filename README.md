# Arch Linux Installer with Python TUI

`install-arch.sh` is a modern, user-friendly installer built from scratch with a Python-based TUI (Text User Interface). It runs from the official Arch ISO and guides you through the installation process with interactive menus and progress bars. The installer auto-detects hardware (boot mode, CPU, GPU, memory, virtualization) and provides an intuitive workflow for configuring your system. Pair it with `install-desktop.sh` to add full desktop environments like GNOME, KDE Plasma, XFCE, Cinnamon, MATE, Budgie, LXQt, Sway, or i3.

## TUI Screenshots

📸 **See the TUI in action!** View example screenshots of all dialog types in [GUI-SCREENSHOTS.md](GUI-SCREENSHOTS.md) or check the [screenshots/](screenshots/) directory.

## What the Installer Does

The installer uses a Python-based TUI (using the dialog library) to provide a friendly, text-based installation experience with progress indicators:

1. **Welcome Screen** - Introduces the installer and its features
2. **Hardware Summary** - Displays detected boot mode, CPU, microcode, GPU, memory, and virtualization
3. **Disk Selection** - Interactive menu to choose installation disk with confirmation
4. **Filesystem Type** - Choose between ext4 (traditional) or Btrfs (modern with snapshots)
5. **Partition Layout** - Select layout:
   - Single partition (simple)
   - LVM (flexible volume management)
   - LVM with separate /home
   - Btrfs subvolumes (@, @home, @var_log, etc.)
6. **Disk Encryption** - Optional LUKS encryption with secure passphrase entry
7. **System Settings** - Configure hostname, timezone, locale, and keyboard layout via menus
8. **User Accounts** - Set up root and primary user with secure password prompts
9. **Mirror Selection** - Choose package mirror region for faster downloads (Worldwide, US, Europe, Asia, etc.)
10. **Desktop Environment** - Choose from 10 desktop options or minimal install
11. **Software Bundles** - Select optional bundles (dev tools, gaming, server, cloud, creative)
12. **Installation Summary** - Review all settings before proceeding
13. **Automated Installation** - Enhanced progress bars show installation stages with detailed feedback
14. **Completion** - Success message with next steps

All user interaction happens through Python-based TUI dialogs with progress bars, making the installation process intuitive and providing clear feedback on progress.

## Usage

1. Boot into the Arch ISO and ensure networking is up. The installer will check connectivity automatically.

2. Download or copy the installer scripts onto the live system:

   ```bash
   # Example: download directly
   curl -O https://raw.githubusercontent.com/speed1405/arch-install/main/install-arch.sh
   curl -O https://raw.githubusercontent.com/speed1405/arch-install/main/install-desktop.sh
   curl -O https://raw.githubusercontent.com/speed1405/arch-install/main/install-dependencies.sh
   curl -O https://raw.githubusercontent.com/speed1405/arch-install/main/installer_gui.py
   curl -O https://raw.githubusercontent.com/speed1405/arch-install/main/gui_wrapper.py
   
   # Or use scp, USB, etc.
   ```

3. Make the scripts executable:
   
   ```bash
   chmod +x install-arch.sh install-dependencies.sh installer_gui.py gui_wrapper.py
   ```

4. Run the installer:

   ```bash
   ./install-arch.sh
   ```

   The installer will automatically:
   - Install Python 3 if not already present
   - Install the dialog utility
   - Install pip (Python package manager)
   - Install the pythondialog library via pip
   - Verify all GUI components are ready

5. Follow the GUI prompts:
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

The installer is fully interactive through Python-based GUI dialogs - no manual configuration needed.

## Interactive TUI Features

The Python-based TUI interface provides:

- **Menu Navigation**: Arrow keys to select, Enter to confirm, Esc to cancel
- **Input Boxes**: Text entry for hostnames, usernames, etc.
- **Password Boxes**: Secure password entry (hidden characters)
- **Yes/No Dialogs**: Clear confirmation prompts
- **Checklists**: Multi-select for software bundles
- **Progress Gauge**: Real-time installation progress with detailed status messages
- **Enhanced Visual Design**: Clean TUI aesthetics with better readability
- **Color Support**: Optional color highlighting for better user experience
- **Info Boxes**: Quick status updates during operations

All menus use the dialog TUI through Python, which works in any terminal and is automatically installed from the Arch repositories with enhanced visual features.

## Storage Options

The installer provides interactive whiptail menus for all storage configuration:

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
- Secure passphrase entry through whiptail password boxes
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

Optional post-install bundles available:

### Core Bundles
- **dev.sh** - Developer tools (compilers, Docker, Podman, Git, language runtimes)
- **gaming.sh** - Gaming setup (Steam, Lutris, Wine, Gamemode, MangoHUD)
- **server.sh** - Server tools (SSH hardening, firewall, monitoring)
- **cloud.sh** - Cloud tools (kubectl, Helm, Terraform, cloud CLIs)
- **creative.sh** - Creative applications (GIMP, Blender, Kdenlive, Inkscape)
- **desktop-utilities.sh** - Desktop utilities (browsers, office suite, media players)

### Additional Bundles
- **aur-helper.sh** - AUR helper installation (yay or paru) for accessing Arch User Repository
- **optimization.sh** - System optimization (pacman config, zram, SSD TRIM, performance tuning)
- **security.sh** - Security hardening (firewall, ClamAV, AppArmor, kernel hardening, SSH hardening)
- **networking.sh** - Network tools (Wireshark, nmap, mtr, iftop, NetworkManager)
- **sysadmin.sh** - System administration (monitoring, backup tools, disk utilities, maintenance scripts)

Bundles can be selected via whiptail checklist during installation or run manually afterward. See **FEATURE-SUGGESTIONS.md** for even more enhancement ideas.

## Safety Notes

- The installer **completely erases** the selected disk - double-check your selection!
- All sensitive operations (disk erase, encryption setup) require explicit confirmation
- Passwords are entered through secure Python GUI password boxes (hidden input)
- Hardware detection runs automatically to select appropriate drivers and microcode
- The installer validates network connectivity before proceeding
- Progress is shown in real-time with a progress gauge

## Requirements

The installer requires:
- Arch Linux ISO (booted in live environment)
- Network connectivity (checked automatically)
- Root privileges

The following dependencies are **automatically installed** by the installer:
- Python 3
- `dialog` utility
- `pip` (Python package manager)
- `pythondialog` library (via pip)

All other required tools are checked automatically at startup.

## Technical Details

- Written in Bash with strict error handling (`set -euo pipefail`)
- Python-based GUI using the dialog library for an improved user experience
- Automatic dependency installation before GUI starts
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
