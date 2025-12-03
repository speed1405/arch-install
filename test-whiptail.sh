#!/usr/bin/env bash
# Test script to demonstrate whiptail menus from the installer

set -euo pipefail

BACKTITLE="Arch Linux Installer v2.0.0 - Demo Mode"

echo "==> Testing Whiptail Menus"
echo ""
echo "This will demonstrate the whiptail interface used in the installer."
echo "Each menu will be shown sequentially. Press ENTER to continue..."
read -r

# Test 1: Welcome message
whiptail --title "Welcome" --backtitle "$BACKTITLE" --msgbox "Welcome to the Arch Linux Installer!\n\nThis is a demonstration of the whiptail GUI interface.\n\nFeatures:\n• Hardware auto-detection\n• Multiple filesystem options\n• Optional LVM and LUKS encryption\n• Desktop environment selection\n\nPress OK to continue." 18 70

# Test 2: Menu selection
CHOICE=$(whiptail --title "Filesystem Type" --backtitle "$BACKTITLE" --menu "Select the root filesystem type:" 15 70 4 \
    "1" "ext4 - Traditional Linux filesystem (recommended)" \
    "2" "btrfs - Modern CoW filesystem with snapshots" \
    3>&1 1>&2 2>&3) || CHOICE=""

if [ -n "$CHOICE" ]; then
    case "$CHOICE" in
        1) FS="ext4" ;;
        2) FS="btrfs" ;;
    esac
    whiptail --title "Selection Confirmed" --backtitle "$BACKTITLE" --msgbox "You selected: $FS" 8 50
fi

# Test 3: Yes/No dialog
if whiptail --title "Disk Encryption" --backtitle "$BACKTITLE" --yesno "Enable LUKS disk encryption?\n\nThis will encrypt your root partition for security.\nYou will need to enter a passphrase at boot." 12 70; then
    whiptail --title "Encryption" --backtitle "$BACKTITLE" --msgbox "Encryption enabled! In the real installer, you would now enter a passphrase." 10 60
else
    whiptail --title "Encryption" --backtitle "$BACKTITLE" --msgbox "Encryption disabled. Installation will proceed without encryption." 10 60
fi

# Test 4: Input box
HOSTNAME=$(whiptail --title "Hostname" --backtitle "$BACKTITLE" --inputbox "Enter system hostname:" 10 60 "archlinux" 3>&1 1>&2 2>&3) || HOSTNAME="archlinux"
whiptail --title "Hostname Set" --backtitle "$BACKTITLE" --msgbox "Hostname will be: $HOSTNAME" 8 50

# Test 5: Checklist
BUNDLES=$(whiptail --title "Software Bundles" --backtitle "$BACKTITLE" --checklist "Select optional software bundles:" 20 75 10 \
    "dev" "Developer tools (compilers, Docker, etc.)" OFF \
    "gaming" "Gaming setup (Steam, Lutris, Wine)" OFF \
    "server" "Server tools (SSH, firewall)" OFF \
    "cloud" "Cloud tools (kubectl, terraform)" OFF \
    "creative" "Creative apps (GIMP, Blender)" OFF \
    3>&1 1>&2 2>&3) || BUNDLES=""

if [ -n "$BUNDLES" ]; then
    whiptail --title "Bundles Selected" --backtitle "$BACKTITLE" --msgbox "Selected bundles:\n$BUNDLES\n\nThese would be installed after the base system." 12 60
else
    whiptail --title "Bundles" --backtitle "$BACKTITLE" --msgbox "No bundles selected. Only base system will be installed." 10 60
fi

# Test 6: Progress gauge
{
    for i in {0..100..10}; do
        echo "$i"
        echo "# Installing packages... ($i%)"
        sleep 0.3
    done
} | whiptail --title "Installing" --backtitle "$BACKTITLE" --gauge "Please wait while packages are installed..." 8 70 0

whiptail --title "Demo Complete" --backtitle "$BACKTITLE" --msgbox "Whiptail interface demonstration complete!\n\nThis shows how the installer provides an interactive, user-friendly experience.\n\nAll menus work with:\n• Arrow keys for navigation\n• Enter to confirm\n• Esc to cancel\n• Tab to switch between buttons" 16 70

echo ""
echo "==> Demo completed successfully!"
echo "The actual installer uses these same whiptail menus throughout the installation process."
