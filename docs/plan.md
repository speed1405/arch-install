# Beginner Arch Installer — Project Plan

## Goal
Build an Arch Linux installer that a user with basic computer experience can
run without reading the Arch Wiki.

## Core Principles
- Safe defaults over configurability.
- Guided steps; hide advanced options by default.
- Clear warnings before destructive actions.
- Automatic hardware detection.
- Post-install first-run guidance.

## Proposed Repo Structure
```
arch-install/
├── docs/
│   ├── plan.md
│   └── testing.md
├── scripts/
│   ├── build-iso.sh
│   └── run-local.sh
├── iso-profile/
│   ├── airootfs/
│   └── packages.x86_64
├── calamares/
│   ├── settings.conf
│   └── modules/
├── install.sh
└── README.md
```

## Install Flow (Beginner Path)
1. Boot ISO and choose installer:
   - Graphical (Calamares)
   - Text (install.sh)
2. Pre-flight checks:
   - UEFI mode
   - Internet connection
   - Minimum disk space
3. Partitioning:
   - Guided layout: 512 MB EFI, 4 GB swap, rest root
   - Explicit confirmation before formatting
4. User setup:
   - Username + password
   - Password strength check
   - sudo enabled automatically
5. Desktop selection (curated list):
   - GNOME
   - KDE Plasma
   - Xfce
   - Hyprland
6. Automatic install:
   - Microcode (intel-ucode / amd-ucode)
   - Base system
   - Graphics stack
   - NetworkManager
   - AUR helper (yay)
7. Bootloader:
   - GRUB EFI install + detection
   - Boot check before reboot
8. First boot:
   - Welcome MOTD / checklist

## Guardrails
- Require two confirmation clicks before disk wipe.
- Block install if target disk has mounted partitions.
- Validate password length >= 8.
- Verify GRUB install succeeded.
- Rollback: preserve logs in `/var/log/arch-install/`.

## Phases
### Phase 0: Repo scaffold + local build
### Phase 1: Text installer with beginner flow
### Phase 2: Calamares graphical installer
### Phase 3: ISO CI + GitHub Actions release

## Success Criteria
- Bootable ISO under 1.5 GB.
- Desktop to login screen in under 15 minutes.
- No ArchWiki lookup required for GNOME/KDE installs.
