# Arch Linux Installer - Python GUI Screenshots

This document shows examples of the Python-based GUI dialogs used in the Arch Linux installer.

## Overview

The installer uses Python's `dialog` library to create text-based user interface (TUI) dialogs. All dialogs run in the terminal and provide a user-friendly, menu-driven experience.

---

## 1. Welcome Screen (Message Box)

The welcome screen introduces the installer and its features.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│                         Welcome                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Welcome to the Arch Linux Installer!                            │
│                                                                  │
│ This installer will guide you through setting up Arch Linux     │
│ with a Python-based graphical interface.                        │
│                                                                  │
│ Features:                                                        │
│ • Hardware auto-detection                                       │
│ • Multiple filesystem options (ext4, Btrfs)                     │
│ • Optional LVM and LUKS encryption                              │
│ • Desktop environment selection                                 │
│ • Post-install bundle options                                   │
│                                                                  │
│ Press OK to begin.                                              │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                           <  OK  >                               │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Message Box (`wt_msgbox`)  
**Function:** Displays information with an OK button

---

## 2. Hardware Summary (Message Box)

Shows detected hardware configuration.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│                    Hardware Summary                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Hardware Detection Summary:                                      │
│                                                                  │
│ Boot Mode: UEFI                                                  │
│ CPU: Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz                   │
│ Microcode: intel-ucode                                           │
│ GPU: NVIDIA GeForce RTX 2070                                     │
│ GPU Driver: nvidia                                               │
│ Memory: 16 GB                                                    │
│ Virtualization: bare-metal                                       │
│                                                                  │
│ Press OK to continue with disk selection.                       │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│                           <  OK  >                               │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Message Box (`wt_msgbox`)  
**Function:** Displays auto-detected hardware information

---

## 3. Disk Selection (Menu)

Interactive menu to select installation disk.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│                     Disk Selection                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Select the disk to install Arch Linux:                          │
│                                                                  │
│ ⚠️  WARNING: Selected disk will be completely erased!            │
│                                                                  │
│    ┌────────────────────────────────────────────────────────┐   │
│    │  1  /dev/sda (238.5G Samsung SSD 860 EVO 250GB)       │   │
│    │  2  /dev/sdb (931.5G WDC WD10EZEX-08WN4A0)            │   │
│    │  3  /dev/nvme0n1 (476.9G Samsung SSD 970 EVO 500GB)   │   │
│    └────────────────────────────────────────────────────────┘   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│              <  OK  >           < Cancel >                       │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Menu (`wt_menu`)  
**Function:** Select from a list of options using arrow keys

---

## 4. Filesystem Type Selection (Menu)

Choose the root filesystem type.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│                   Filesystem Type                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Select the root filesystem type:                                │
│                                                                  │
│    ┌────────────────────────────────────────────────────────┐   │
│    │  1  ext4 - Traditional Linux filesystem (recommended) │   │
│    │  2  btrfs - Modern CoW filesystem with snapshots      │   │
│    └────────────────────────────────────────────────────────┘   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│              <  OK  >           < Cancel >                       │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Menu (`wt_menu`)  
**Function:** Select filesystem type

---

## 5. Encryption Confirmation (Yes/No Dialog)

Confirm whether to enable disk encryption.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│                   Disk Encryption                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Enable LUKS disk encryption?                                     │
│                                                                  │
│ This will encrypt your root partition for security.             │
│ You will need to enter a passphrase at boot.                    │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│              < Yes  >           <  No  >                         │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Yes/No Dialog (`wt_yesno`)  
**Function:** Binary choice confirmation

---

## 6. Hostname Input (Input Box)

Enter the system hostname.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│                      Hostname                                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Enter system hostname:                                           │
│                                                                  │
│    ┌────────────────────────────────────────────────────────┐   │
│    │ archlinux_____________________________________         │   │
│    └────────────────────────────────────────────────────────┘   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│              <  OK  >           < Cancel >                       │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Input Box (`wt_inputbox`)  
**Function:** Text input for configuration values

---

## 7. Password Entry (Password Box)

Secure password entry with hidden characters.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│                   Root Password                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Enter root password:                                             │
│                                                                  │
│    ┌────────────────────────────────────────────────────────┐   │
│    │ **************_________________________________        │   │
│    └────────────────────────────────────────────────────────┘   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│              <  OK  >           < Cancel >                       │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Password Box (`wt_passwordbox`)  
**Function:** Secure password input (characters are hidden)

---

## 8. Desktop Environment Selection (Menu)

Choose a desktop environment to install.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│               Desktop Environment                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Select a desktop environment to install:                        │
│                                                                  │
│    ┌────────────────────────────────────────────────────────┐   │
│    │ none      No desktop (server/minimal install)          │   │
│    │ gnome     GNOME - Modern, feature-rich desktop         │   │
│    │ kde       KDE Plasma - Customizable and powerful       │   │
│    │ xfce      XFCE - Lightweight and fast                  │   │
│    │ cinnamon  Cinnamon - Traditional desktop experience    │   │
│    │ mate      MATE - Classic GNOME 2 desktop               │   │
│    │ budgie    Budgie - Clean and elegant                   │   │
│    │ lxqt      LXQt - Lightweight Qt desktop                │   │
│    │ sway      Sway - Tiling Wayland compositor             │   │
│    │ i3        i3 - Tiling window manager                   │   │
│    └────────────────────────────────────────────────────────┘   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│              <  OK  >           < Cancel >                       │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Menu (`wt_menu`)  
**Function:** Select desktop environment from list

---

## 9. Software Bundle Selection (Checklist)

Multi-select optional software bundles.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│              Software Bundles                                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Select optional software bundles to install:                    │
│ (Use SPACE to select/deselect, ENTER to confirm)                │
│                                                                  │
│    ┌────────────────────────────────────────────────────────┐   │
│    │ [X] aur-helper        AUR helper (yay/paru)            │   │
│    │ [ ] dev               Developer tools & languages      │   │
│    │ [X] gaming            Gaming (Steam, Lutris, Wine)     │   │
│    │ [ ] server            Server tools & services          │   │
│    │ [ ] cloud             Cloud tools (kubectl, terraform) │   │
│    │ [ ] creative          Creative apps (GIMP, Blender)    │   │
│    │ [X] desktop-utilities Desktop utilities & browsers     │   │
│    │ [ ] optimization      System optimization tweaks       │   │
│    │ [ ] security          Security hardening tools         │   │
│    │ [ ] networking        Network diagnostic tools         │   │
│    └────────────────────────────────────────────────────────┘   │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│              <  OK  >           < Cancel >                       │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Checklist (`wt_checklist`)  
**Function:** Multi-select from list of options

---

## 10. Installation Progress (Gauge)

Real-time installation progress indicator.

```
┌──────────────────────────────────────────────────────────────────┐
│ Arch Linux Installer v2.0.0                                      │
├──────────────────────────────────────────────────────────────────┤
│             Installing Arch Linux                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Installing base system (this will take several minutes)...      │
│                                                                  │
│    ┌────────────────────────────────────────────────────────┐   │
│    │████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│   │
│    └────────────────────────────────────────────────────────┘   │
│                          35%                                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Type:** Gauge (`wt_gauge`)  
**Function:** Progress bar showing installation status

---

## 11. Dependency Installation Output

When the installer first runs, it automatically installs required dependencies:

```
============================================================
  Arch Linux Installer - GUI Dependency Setup
============================================================

==> Checking network connectivity...
==> Network connectivity confirmed.
==> Updating package database...
==> Package database updated.
==> Checking for Python 3...
==> Python 3 found: version 3.11.5
==> Checking for dialog utility...
Warning: dialog utility not found.
==> Installing dialog utility...
==> dialog utility installed successfully.
==> Checking for python-dialog library...
Warning: python-dialog library not found.
==> Installing python-dialog library...
==> python-dialog library installed successfully.
==> Verifying GUI files...
==> GUI files verified.

==> All dependencies installed successfully!
==> The installer GUI is ready to use.
```

**Type:** Console Output  
**Function:** Shows automatic dependency installation progress

---

## Dialog Types Summary

| Dialog Type | Function | Example Use |
|-------------|----------|-------------|
| **Message Box** | Display information | Welcome screen, hardware summary |
| **Yes/No** | Binary choice | Encryption enable, reboot confirmation |
| **Input Box** | Text entry | Hostname, username |
| **Password Box** | Secure text entry | Root password, user password, encryption passphrase |
| **Menu** | Single selection | Disk selection, filesystem type, desktop environment |
| **Checklist** | Multiple selection | Software bundles |
| **Gauge** | Progress display | Installation progress |

---

## Navigation

All dialogs support standard keyboard navigation:

- **Arrow Keys** (↑↓) - Navigate between options
- **Tab** - Move between buttons
- **Space** - Select/deselect in checklists
- **Enter** - Confirm selection
- **Esc** - Cancel/Go back

---

## Technical Details

### Python Implementation

The GUI is implemented using:
- **installer_gui.py** - InstallerGUI class wrapping the dialog library
- **gui_wrapper.py** - CLI wrapper for bash script integration
- **Dialog Library** - Python bindings for the `dialog` utility

### Example Code

```python
from installer_gui import InstallerGUI

gui = InstallerGUI("Arch Linux Installer v2.0.0")

# Display message
gui.msgbox("Welcome", "Welcome to the installer!", 10, 60)

# Get yes/no response
if gui.yesno("Confirm", "Continue?", 10, 60):
    print("User confirmed")

# Get text input
hostname = gui.inputbox("Hostname", "Enter hostname:", "archlinux", 10, 60)

# Show menu
choices = [("1", "Option 1"), ("2", "Option 2")]
selection = gui.menu("Menu", "Choose:", 15, 60, 5, choices)
```

---

## Screenshots Note

The ASCII representations above show the structure of each dialog type. The actual terminal display uses:
- Box-drawing characters (─ │ ┌ ┐ └ ┘ ├ ┤)
- Color highlighting (typically blue/cyan backgrounds)
- Dynamic sizing based on terminal dimensions
- Anti-aliased text rendering in modern terminals

For actual visual appearance, run the installer in an Arch Linux live environment with a terminal supporting UTF-8 and box-drawing characters.
