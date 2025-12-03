#!/usr/bin/env bash
# Arch Linux installer with whiptail GUI interface
# Built from scratch for a modern, user-friendly installation experience
# Run from an Arch ISO live session with networking enabled

set -euo pipefail
IFS=$'\n\t'

# --- Global Configuration Variables ------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="2.0.0"
BACKTITLE="Arch Linux Installer v${SCRIPT_VERSION}"

# Installation configuration (populated by GUI)
INSTALL_DISK=""
INSTALL_HOSTNAME="archlinux"
INSTALL_TIMEZONE="UTC"
INSTALL_LOCALE="en_US.UTF-8"
INSTALL_KEYMAP="us"
INSTALL_ROOT_PASSWORD=""
INSTALL_USER=""
INSTALL_USER_PASSWORD=""
INSTALL_PACKAGES=""
INSTALL_FILESYSTEM="ext4"
INSTALL_USE_LVM=false
INSTALL_VG_NAME="archvg"
INSTALL_LV_ROOT_NAME="root"
INSTALL_LV_HOME_NAME="home"
INSTALL_LV_ROOT_SIZE="70%FREE"
INSTALL_LV_HOME_SIZE="100%FREE"
INSTALL_LAYOUT="single"
INSTALL_USE_LUKS=false
INSTALL_LUKS_NAME="cryptroot"
INSTALL_LUKS_PASSPHRASE=""
INSTALL_BOOT_MODE="auto"
INSTALL_BOOTLOADER="auto"
INSTALL_DESKTOP_CHOICE="none"
INSTALL_BUNDLE_CHOICE=""
BTRFS_MOUNT_OPTS="compress=zstd,autodefrag"
BTRFS_SUBVOLUMES="@:/ @home:/home @var_log:/var/log @var_cache:/var/cache @snapshots:/.snapshots"

# Runtime state
MOUNTED=false
BOOT_MODE=""
DETECTED_BOOT_MODE=""
SELECTED_BOOTLOADER=""
TARGET_DISK=""
PART_SUFFIX=""
PART_BOOT=""
PART_ROOT=""
FILESYSTEM_TYPE=""
ROOT_DEVICE=""
ENCRYPTED_DEVICE=""
OPENED_LUKS=false
CRYPT_DEVICE_NAME=""
CRYPT_UUID=""
HOME_DEVICE=""
MICROCODE=""
MICROCODE_IMG=""
GPU_DRIVER=""

# Required commands
REQUIRED_TOOLS=(lsblk awk sed grep parted sgdisk mkfs.fat mkfs.ext4 cryptsetup pacstrap genfstab arch-chroot timedatectl lspci ping systemd-detect-virt blkid whiptail)

# --- Whiptail Helper Functions -----------------------------------------------
wt_msgbox() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-60}"
    whiptail --title "$title" --backtitle "$BACKTITLE" --msgbox "$message" "$height" "$width"
}

wt_yesno() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-60}"
    whiptail --title "$title" --backtitle "$BACKTITLE" --yesno "$message" "$height" "$width"
}

wt_inputbox() {
    local title="$1"
    local message="$2"
    local default="${3:-}"
    local height="${4:-10}"
    local width="${5:-60}"
    whiptail --title "$title" --backtitle "$BACKTITLE" --inputbox "$message" "$height" "$width" "$default" 3>&1 1>&2 2>&3
}

wt_passwordbox() {
    local title="$1"
    local message="$2"
    local height="${3:-10}"
    local width="${4:-60}"
    whiptail --title "$title" --backtitle "$BACKTITLE" --passwordbox "$message" "$height" "$width" 3>&1 1>&2 2>&3
}

wt_menu() {
    local title="$1"
    local message="$2"
    local height="$3"
    local width="$4"
    local menu_height="$5"
    shift 5
    whiptail --title "$title" --backtitle "$BACKTITLE" --menu "$message" "$height" "$width" "$menu_height" "$@" 3>&1 1>&2 2>&3
}

wt_checklist() {
    local title="$1"
    local message="$2"
    local height="$3"
    local width="$4"
    local list_height="$5"
    shift 5
    whiptail --title "$title" --backtitle "$BACKTITLE" --checklist "$message" "$height" "$width" "$list_height" "$@" 3>&1 1>&2 2>&3
}

wt_gauge() {
    local title="$1"
    local message="$2"
    local height="${3:-8}"
    local width="${4:-60}"
    whiptail --title "$title" --backtitle "$BACKTITLE" --gauge "$message" "$height" "$width" 0
}

# --- Logging Functions -------------------------------------------------------
log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }
log_error() { printf 'ERROR: %s\n' "$1" >&2; }
fail() { 
    log_error "$1"
    wt_msgbox "Error" "$1" 10 60 || true
    exit 1
}

# --- Pre-flight Checks -------------------------------------------------------
require_root() {
    [[ ${EUID} -eq 0 ]] || fail "This installer must be run as root."
}

ensure_commands() {
    local missing=()
    for bin in "${REQUIRED_TOOLS[@]}"; do
        command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing required tools: ${missing[*]}\n\nInstall them with: pacman -Sy ${missing[*]}"
    fi
}

require_online() {
    if ! ping -c 1 -W 2 archlinux.org >/dev/null 2>&1; then
        wt_msgbox "Network Required" "No network connectivity detected.\n\nPlease configure networking before running this installer.\n\nYou can use: iwctl, nmcli, or check your Ethernet connection." 12 70
        return 1
    fi
    return 0
}

# --- Hardware Detection ------------------------------------------------------
detect_boot_mode() {
    [[ -d /sys/firmware/efi/efivars ]] && echo uefi || echo bios
}

cpu_vendor() {
    awk -F': ' '/vendor_id/{print $2; exit}' /proc/cpuinfo
}

microcode_package() {
    case "$(cpu_vendor)" in
        GenuineIntel) echo "intel-ucode" ;;
        AuthenticAMD) echo "amd-ucode" ;;
        *) echo "" ;;
    esac
}

microcode_image() {
    case "$1" in
        intel-ucode) echo "intel-ucode.img" ;;
        amd-ucode) echo "amd-ucode.img" ;;
        *) echo "" ;;
    esac
}

detect_gpu_driver() {
    local gpu
    gpu=$(lspci | grep -i 'vga\|3d' || true)
    case "$gpu" in
        *NVIDIA*|*GeForce*) echo "nvidia" ;;
        *AMD*|*ATI*) echo "xf86-video-amdgpu" ;;
        *Intel*) echo "mesa" ;;
        *) echo "" ;;
    esac
}

detect_virtualization() {
    systemd-detect-virt 2>/dev/null || echo "bare-metal"
}

memory_gb() {
    awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo
}

auto_swap_size_gb() {
    local mem_kb swap_gb
    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    if (( mem_kb <= 4 * 1024 * 1024 )); then
        swap_gb=4
    elif (( mem_kb <= 16 * 1024 * 1024 )); then
        swap_gb=2
    else
        swap_gb=1
    fi
    echo "$swap_gb"
}

# --- Disk Utilities ----------------------------------------------------------
partition_suffix_for() {
    local disk="$1"
    if [[ $disk =~ (nvme|mmcblk|loop) ]]; then
        echo "p"
    else
        echo ""
    fi
}

get_disks() {
    lsblk -dno NAME,SIZE,TYPE | awk '$3=="disk" {print "/dev/"$1" "$2}'
}

# --- GUI Workflow Functions --------------------------------------------------
show_welcome() {
    local message="Welcome to the Arch Linux Installer!\n\n"
    message+="This installer will guide you through setting up Arch Linux with a graphical whiptail interface.\n\n"
    message+="Features:\n"
    message+="• Hardware auto-detection\n"
    message+="• Multiple filesystem options (ext4, Btrfs)\n"
    message+="• Optional LVM and LUKS encryption\n"
    message+="• Desktop environment selection\n"
    message+="• Post-install bundle options\n\n"
    message+="Press OK to begin."
    
    wt_msgbox "Welcome" "$message" 20 70
}

show_hardware_summary() {
    local cpu_info
    cpu_info=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
    
    local gpu_info
    gpu_info=$(lspci | grep -i 'vga\|3d' | head -1 | cut -d: -f3 | sed 's/^ *//' || echo "Not detected")
    
    local mem_info
    mem_info="$(memory_gb) GB"
    
    local virt_info
    virt_info=$(detect_virtualization)
    
    local message="Hardware Detection Summary:\n\n"
    message+="Boot Mode: ${DETECTED_BOOT_MODE^^}\n"
    message+="CPU: ${cpu_info}\n"
    message+="Microcode: ${MICROCODE:-none}\n"
    message+="GPU: ${gpu_info}\n"
    message+="GPU Driver: ${GPU_DRIVER:-none}\n"
    message+="Memory: ${mem_info}\n"
    message+="Virtualization: ${virt_info}\n\n"
    message+="Press OK to continue with disk selection."
    
    wt_msgbox "Hardware Summary" "$message" 18 75
}

select_disk() {
    local disk_list=()
    local idx=1
    
    while IFS= read -r line; do
        disk_list+=("$idx" "$line")
        ((idx++))
    done < <(get_disks)
    
    if [[ ${#disk_list[@]} -eq 0 ]]; then
        fail "No disks detected on this system."
    fi
    
    local selection
    selection=$(wt_menu "Disk Selection" "Select the disk to install Arch Linux:\n\n⚠️  WARNING: Selected disk will be completely erased!" 20 75 10 "${disk_list[@]}")
    
    if [[ -z $selection ]]; then
        fail "No disk selected. Installation cancelled."
    fi
    
    # Get the actual disk path from the selection
    local selected_idx=$((selection - 1))
    local disk_line
    disk_line=$(get_disks | sed -n "$((selected_idx + 1))p")
    INSTALL_DISK=$(echo "$disk_line" | awk '{print $1}')
    
    # Confirm disk selection
    local confirm_msg="You have selected:\n\n${INSTALL_DISK}\n\n"
    confirm_msg+="⚠️  ALL DATA ON THIS DISK WILL BE PERMANENTLY ERASED!\n\n"
    confirm_msg+="Are you absolutely sure you want to continue?"
    
    if ! wt_yesno "Confirm Disk Erase" "$confirm_msg" 15 70; then
        fail "Disk selection cancelled by user."
    fi
}

select_filesystem() {
    local fs_choice
    fs_choice=$(wt_menu "Filesystem Type" "Select the root filesystem type:" 15 70 4 \
        "1" "ext4 - Traditional Linux filesystem (recommended)" \
        "2" "btrfs - Modern CoW filesystem with snapshots" \
        3>&1 1>&2 2>&3)
    
    case "$fs_choice" in
        1) INSTALL_FILESYSTEM="ext4" ;;
        2) INSTALL_FILESYSTEM="btrfs" ;;
        *) INSTALL_FILESYSTEM="ext4" ;;
    esac
}

select_layout() {
    local layout_choice
    layout_choice=$(wt_menu "Partition Layout" "Select partition layout:" 18 75 5 \
        "1" "Single partition - Simple root partition only" \
        "2" "LVM - Logical Volume Management for flexibility" \
        "3" "LVM with separate /home - Split root and home volumes" \
        "4" "Btrfs subvolumes - Btrfs with @, @home, etc." \
        3>&1 1>&2 2>&3)
    
    case "$layout_choice" in
        1)
            INSTALL_LAYOUT="single"
            INSTALL_USE_LVM=false
            ;;
        2)
            INSTALL_LAYOUT="lvm-single"
            INSTALL_USE_LVM=true
            ;;
        3)
            INSTALL_LAYOUT="lvm-home"
            INSTALL_USE_LVM=true
            ;;
        4)
            if [[ $INSTALL_FILESYSTEM != "btrfs" ]]; then
                wt_msgbox "Notice" "Btrfs subvolumes require Btrfs filesystem.\n\nFilesystem will be set to Btrfs." 10 60
                INSTALL_FILESYSTEM="btrfs"
            fi
            INSTALL_LAYOUT="btrfs-subvols"
            INSTALL_USE_LVM=false
            ;;
        *)
            INSTALL_LAYOUT="single"
            INSTALL_USE_LVM=false
            ;;
    esac
}

select_encryption() {
    if wt_yesno "Disk Encryption" "Enable LUKS disk encryption?\n\nThis will encrypt your root partition for security.\nYou will need to enter a passphrase at boot." 12 70; then
        INSTALL_USE_LUKS=true
        
        while true; do
            local pass1 pass2
            pass1=$(wt_passwordbox "Encryption Passphrase" "Enter LUKS encryption passphrase:" 10 60)
            
            if [[ -z $pass1 ]]; then
                wt_msgbox "Error" "Passphrase cannot be empty." 8 50
                continue
            fi
            
            pass2=$(wt_passwordbox "Confirm Passphrase" "Re-enter passphrase to confirm:" 10 60)
            
            if [[ $pass1 == "$pass2" ]]; then
                INSTALL_LUKS_PASSPHRASE="$pass1"
                break
            else
                wt_msgbox "Error" "Passphrases do not match. Please try again." 8 50
            fi
        done
    else
        INSTALL_USE_LUKS=false
    fi
}

configure_system_settings() {
    # Hostname
    INSTALL_HOSTNAME=$(wt_inputbox "Hostname" "Enter system hostname:" "$INSTALL_HOSTNAME" 10 60)
    [[ -n $INSTALL_HOSTNAME ]] || INSTALL_HOSTNAME="archlinux"
    
    # Timezone selection
    local tz_choice
    tz_choice=$(wt_menu "Timezone" "Select your timezone region:" 20 70 10 \
        "1" "America" \
        "2" "Europe" \
        "3" "Asia" \
        "4" "Pacific" \
        "5" "Africa" \
        "6" "UTC (default)" \
        3>&1 1>&2 2>&3)
    
    case "$tz_choice" in
        1) INSTALL_TIMEZONE="America/New_York" ;;
        2) INSTALL_TIMEZONE="Europe/London" ;;
        3) INSTALL_TIMEZONE="Asia/Tokyo" ;;
        4) INSTALL_TIMEZONE="Pacific/Auckland" ;;
        5) INSTALL_TIMEZONE="Africa/Cairo" ;;
        6|*) INSTALL_TIMEZONE="UTC" ;;
    esac
    
    # Locale selection
    local locale_choice
    locale_choice=$(wt_menu "Locale" "Select system locale:" 18 70 8 \
        "1" "en_US.UTF-8 (US English)" \
        "2" "en_GB.UTF-8 (British English)" \
        "3" "de_DE.UTF-8 (German)" \
        "4" "fr_FR.UTF-8 (French)" \
        "5" "es_ES.UTF-8 (Spanish)" \
        "6" "ja_JP.UTF-8 (Japanese)" \
        3>&1 1>&2 2>&3)
    
    case "$locale_choice" in
        1) INSTALL_LOCALE="en_US.UTF-8" ;;
        2) INSTALL_LOCALE="en_GB.UTF-8" ;;
        3) INSTALL_LOCALE="de_DE.UTF-8" ;;
        4) INSTALL_LOCALE="fr_FR.UTF-8" ;;
        5) INSTALL_LOCALE="es_ES.UTF-8" ;;
        6) INSTALL_LOCALE="ja_JP.UTF-8" ;;
        *) INSTALL_LOCALE="en_US.UTF-8" ;;
    esac
    
    # Keyboard layout
    local keymap_choice
    keymap_choice=$(wt_menu "Keyboard Layout" "Select keyboard layout:" 18 70 8 \
        "1" "us (US English)" \
        "2" "uk (British)" \
        "3" "de (German)" \
        "4" "fr (French)" \
        "5" "es (Spanish)" \
        3>&1 1>&2 2>&3)
    
    case "$keymap_choice" in
        1) INSTALL_KEYMAP="us" ;;
        2) INSTALL_KEYMAP="uk" ;;
        3) INSTALL_KEYMAP="de" ;;
        4) INSTALL_KEYMAP="fr" ;;
        5) INSTALL_KEYMAP="es" ;;
        *) INSTALL_KEYMAP="us" ;;
    esac
}

configure_users() {
    # Root password
    while true; do
        local pass1 pass2
        pass1=$(wt_passwordbox "Root Password" "Enter root password:" 10 60)
        
        if [[ -z $pass1 ]]; then
            wt_msgbox "Error" "Root password cannot be empty." 8 50
            continue
        fi
        
        pass2=$(wt_passwordbox "Confirm Root Password" "Re-enter root password:" 10 60)
        
        if [[ $pass1 == "$pass2" ]]; then
            INSTALL_ROOT_PASSWORD="$pass1"
            break
        else
            wt_msgbox "Error" "Passwords do not match. Please try again." 8 50
        fi
    done
    
    # User account
    INSTALL_USER=$(wt_inputbox "User Account" "Enter username for primary user account:" "archer" 10 60)
    [[ -n $INSTALL_USER ]] || INSTALL_USER="archer"
    
    while true; do
        local pass1 pass2
        pass1=$(wt_passwordbox "User Password" "Enter password for ${INSTALL_USER}:" 10 60)
        
        if [[ -z $pass1 ]]; then
            wt_msgbox "Error" "User password cannot be empty." 8 50
            continue
        fi
        
        pass2=$(wt_passwordbox "Confirm User Password" "Re-enter password for ${INSTALL_USER}:" 10 60)
        
        if [[ $pass1 == "$pass2" ]]; then
            INSTALL_USER_PASSWORD="$pass1"
            break
        else
            wt_msgbox "Error" "Passwords do not match. Please try again." 8 50
        fi
    done
}

select_desktop() {
    local desktop_choice
    desktop_choice=$(wt_menu "Desktop Environment" "Select a desktop environment to install:" 20 75 11 \
        "none" "No desktop (server/minimal install)" \
        "gnome" "GNOME - Modern, feature-rich desktop" \
        "kde" "KDE Plasma - Customizable and powerful" \
        "xfce" "XFCE - Lightweight and fast" \
        "cinnamon" "Cinnamon - Traditional desktop experience" \
        "mate" "MATE - Classic GNOME 2 desktop" \
        "budgie" "Budgie - Clean and elegant" \
        "lxqt" "LXQt - Lightweight Qt desktop" \
        "sway" "Sway - Tiling Wayland compositor" \
        "i3" "i3 - Tiling window manager" \
        3>&1 1>&2 2>&3)
    
    INSTALL_DESKTOP_CHOICE="${desktop_choice:-none}"
}

select_bundles() {
    local bundle_dir="${SCRIPT_DIR}"
    local bundles=()
    
    # Check for available bundle scripts
    if [[ -f "${bundle_dir}/dev.sh" ]]; then
        bundles+=("dev" "Developer tools (compilers, Docker, etc.)" OFF)
    fi
    if [[ -f "${bundle_dir}/gaming.sh" ]]; then
        bundles+=("gaming" "Gaming setup (Steam, Lutris, Wine)" OFF)
    fi
    if [[ -f "${bundle_dir}/server.sh" ]]; then
        bundles+=("server" "Server tools (SSH, firewall)" OFF)
    fi
    if [[ -f "${bundle_dir}/cloud.sh" ]]; then
        bundles+=("cloud" "Cloud tools (kubectl, terraform)" OFF)
    fi
    if [[ -f "${bundle_dir}/creative.sh" ]]; then
        bundles+=("creative" "Creative apps (GIMP, Blender)" OFF)
    fi
    if [[ -f "${bundle_dir}/desktop-utilities.sh" ]]; then
        bundles+=("utilities" "Desktop utilities (browsers, office)" OFF)
    fi
    
    if [[ ${#bundles[@]} -eq 0 ]]; then
        return
    fi
    
    local selected
    selected=$(wt_checklist "Additional Software" "Select optional software bundles:" 20 75 10 "${bundles[@]}" || echo "")
    
    if [[ -n $selected ]]; then
        # Convert selected items to bundle choice (just take first for now)
        INSTALL_BUNDLE_CHOICE=$(echo "$selected" | tr -d '"' | awk '{print $1}')
    fi
}

show_installation_summary() {
    local summary="Installation Configuration Summary:\n\n"
    summary+="Disk: ${INSTALL_DISK}\n"
    summary+="Filesystem: ${INSTALL_FILESYSTEM}\n"
    summary+="Layout: ${INSTALL_LAYOUT}\n"
    summary+="Encryption: $(is_true "$INSTALL_USE_LUKS" && echo "Enabled (LUKS)" || echo "Disabled")\n"
    summary+="LVM: $(is_true "$INSTALL_USE_LVM" && echo "Enabled" || echo "Disabled")\n"
    summary+="Boot Mode: ${BOOT_MODE}\n"
    summary+="Bootloader: ${SELECTED_BOOTLOADER}\n\n"
    summary+="Hostname: ${INSTALL_HOSTNAME}\n"
    summary+="Timezone: ${INSTALL_TIMEZONE}\n"
    summary+="Locale: ${INSTALL_LOCALE}\n"
    summary+="Keymap: ${INSTALL_KEYMAP}\n"
    summary+="User: ${INSTALL_USER}\n\n"
    summary+="Desktop: ${INSTALL_DESKTOP_CHOICE}\n"
    summary+="Bundle: ${INSTALL_BUNDLE_CHOICE:-none}\n\n"
    summary+="Proceed with installation?"
    
    if ! wt_yesno "Installation Summary" "$summary" 24 75; then
        fail "Installation cancelled by user."
    fi
}

# --- Utility Functions -------------------------------------------------------
is_true() {
    local value="${1:-}"
    [[ "${value,,}" == "true" ]]
}

resolve_boot_mode() {
    local detected="$1"
    case "${INSTALL_BOOT_MODE,,}" in
        auto|"")
            echo "$detected"
            ;;
        uefi)
            [[ $detected == "uefi" ]] || fail "UEFI boot requested but system is in BIOS mode."
            echo "uefi"
            ;;
        bios|legacy)
            echo "bios"
            ;;
        *)
            fail "Unknown boot mode: ${INSTALL_BOOT_MODE}"
            ;;
    esac
}

resolve_bootloader() {
    local boot_mode="$1"
    case "$boot_mode" in
        uefi)
            case "${INSTALL_BOOTLOADER,,}" in
                auto|""|systemd-boot)
                    echo "systemd-boot"
                    ;;
                grub)
                    echo "grub"
                    ;;
                *)
                    fail "Unknown bootloader: ${INSTALL_BOOTLOADER}"
                    ;;
            esac
            ;;
        bios)
            echo "grub"
            ;;
        *)
            fail "Unknown boot mode for bootloader resolution: ${boot_mode}"
            ;;
    esac
}

# --- Installation Functions --------------------------------------------------
partition_disk() {
    local disk="$1"
    log_step "Partitioning ${disk} (${BOOT_MODE^^})"
    
    # Wipe disk
    wipefs -af "$disk" >/dev/null 2>&1 || true
    sgdisk --zap-all "$disk" >/dev/null 2>&1 || true
    parted -s "$disk" mklabel gpt
    
    if [[ $BOOT_MODE == "uefi" ]]; then
        # UEFI: 512MB EFI partition + root
        parted -s "$disk" mkpart ESP fat32 1MiB 513MiB
        parted -s "$disk" set 1 esp on
        parted -s "$disk" mkpart arch-root 513MiB 100%
        PART_BOOT="${disk}${PART_SUFFIX}1"
        PART_ROOT="${disk}${PART_SUFFIX}2"
    else
        # BIOS: 1MB BIOS boot + root
        parted -s "$disk" mkpart biosboot 1MiB 3MiB
        parted -s "$disk" set 1 bios_grub on
        parted -s "$disk" mkpart arch-root 3MiB 100%
        PART_BOOT=""
        PART_ROOT="${disk}${PART_SUFFIX}2"
    fi
}

format_boot_partition() {
    if [[ $BOOT_MODE != "uefi" ]]; then
        return
    fi
    log_step "Formatting EFI partition"
    mkfs.fat -F32 "$PART_BOOT" >/dev/null 2>&1
}

setup_luks_container() {
    if ! is_true "$INSTALL_USE_LUKS"; then
        ENCRYPTED_DEVICE="$PART_ROOT"
        return
    fi
    
    log_step "Setting up LUKS encryption"
    printf '%s' "$INSTALL_LUKS_PASSPHRASE" | cryptsetup luksFormat "$PART_ROOT" --batch-mode -
    printf '%s' "$INSTALL_LUKS_PASSPHRASE" | cryptsetup open "$PART_ROOT" "$INSTALL_LUKS_NAME" -
    
    ENCRYPTED_DEVICE="/dev/mapper/${INSTALL_LUKS_NAME}"
    OPENED_LUKS=true
    CRYPT_DEVICE_NAME="$INSTALL_LUKS_NAME"
    CRYPT_UUID=$(blkid -s UUID -o value "$PART_ROOT")
}

setup_storage_stack() {
    local base_device="${ENCRYPTED_DEVICE}"
    ROOT_DEVICE="$base_device"
    HOME_DEVICE=""
    
    if is_true "$INSTALL_USE_LVM"; then
        log_step "Setting up LVM"
        pvcreate -ff -y "$base_device" >/dev/null 2>&1
        vgcreate "$INSTALL_VG_NAME" "$base_device" >/dev/null 2>&1
        
        if [[ $INSTALL_LAYOUT == "lvm-home" ]]; then
            lvcreate -l "$INSTALL_LV_ROOT_SIZE" -n "$INSTALL_LV_ROOT_NAME" "$INSTALL_VG_NAME" >/dev/null 2>&1
            lvcreate -l "$INSTALL_LV_HOME_SIZE" -n "$INSTALL_LV_HOME_NAME" "$INSTALL_VG_NAME" >/dev/null 2>&1
            HOME_DEVICE="/dev/${INSTALL_VG_NAME}/${INSTALL_LV_HOME_NAME}"
        else
            lvcreate -l 100%FREE -n "$INSTALL_LV_ROOT_NAME" "$INSTALL_VG_NAME" >/dev/null 2>&1
        fi
        
        ROOT_DEVICE="/dev/${INSTALL_VG_NAME}/${INSTALL_LV_ROOT_NAME}"
    fi
}

format_filesystems() {
    log_step "Formatting filesystems"
    
    case "$INSTALL_FILESYSTEM" in
        ext4)
            mkfs.ext4 -F "$ROOT_DEVICE" >/dev/null 2>&1
            ;;
        btrfs)
            mkfs.btrfs -f "$ROOT_DEVICE" >/dev/null 2>&1
            ;;
    esac
    
    if [[ -n $HOME_DEVICE ]]; then
        case "$INSTALL_FILESYSTEM" in
            ext4)
                mkfs.ext4 -F "$HOME_DEVICE" >/dev/null 2>&1
                ;;
            btrfs)
                mkfs.btrfs -f "$HOME_DEVICE" >/dev/null 2>&1
                ;;
        esac
    fi
}

prepare_btrfs_subvolumes() {
    [[ $INSTALL_FILESYSTEM == "btrfs" && $INSTALL_LAYOUT == "btrfs-subvols" ]] || return
    
    log_step "Creating Btrfs subvolumes"
    mount "$ROOT_DEVICE" /mnt
    
    IFS=' ' read -ra subvol_entries <<< "$BTRFS_SUBVOLUMES"
    for entry in "${subvol_entries[@]}"; do
        local subvol="${entry%%:*}"
        [[ -n $subvol ]] && btrfs subvolume create "/mnt/${subvol}" >/dev/null 2>&1
    done
    
    umount /mnt
}

mount_filesystems() {
    log_step "Mounting filesystems"
    
    if [[ $INSTALL_FILESYSTEM == "btrfs" && $INSTALL_LAYOUT == "btrfs-subvols" ]]; then
        IFS=' ' read -ra subvol_entries <<< "$BTRFS_SUBVOLUMES"
        local root_entry="${subvol_entries[0]}"
        local root_subvol="${root_entry%%:*}"
        
        mount -o "subvol=${root_subvol},${BTRFS_MOUNT_OPTS}" "$ROOT_DEVICE" /mnt
        
        for entry in "${subvol_entries[@]:1}"; do
            local subvol="${entry%%:*}"
            local target="${entry#*:}"
            [[ -n $subvol && -n $target ]] || continue
            mkdir -p "/mnt${target}"
            mount -o "subvol=${subvol},${BTRFS_MOUNT_OPTS}" "$ROOT_DEVICE" "/mnt${target}"
        done
    else
        if [[ $INSTALL_FILESYSTEM == "btrfs" ]]; then
            mount -o "$BTRFS_MOUNT_OPTS" "$ROOT_DEVICE" /mnt
        else
            mount "$ROOT_DEVICE" /mnt
        fi
    fi
    
    mkdir -p /mnt/boot
    if [[ $BOOT_MODE == "uefi" ]]; then
        mount "$PART_BOOT" /mnt/boot
    fi
    
    if [[ -n $HOME_DEVICE ]]; then
        mkdir -p /mnt/home
        if [[ $INSTALL_FILESYSTEM == "btrfs" ]]; then
            mount -o "$BTRFS_MOUNT_OPTS" "$HOME_DEVICE" /mnt/home
        else
            mount "$HOME_DEVICE" /mnt/home
        fi
    fi
    
    MOUNTED=true
}

install_base_system() {
    log_step "Installing base system"
    
    local packages=(base linux linux-firmware networkmanager)
    
    [[ -n $MICROCODE ]] && packages+=("$MICROCODE")
    [[ -n $GPU_DRIVER ]] && packages+=("$GPU_DRIVER")
    [[ $INSTALL_FILESYSTEM == "btrfs" ]] && packages+=("btrfs-progs")
    is_true "$INSTALL_USE_LVM" && packages+=("lvm2")
    is_true "$INSTALL_USE_LUKS" && packages+=("cryptsetup")
    
    if [[ $SELECTED_BOOTLOADER == "grub" ]]; then
        packages+=(grub)
        [[ $BOOT_MODE == "uefi" ]] && packages+=(efibootmgr)
    fi
    
    packages+=(nano vim git sudo)
    
    pacstrap -K /mnt "${packages[@]}" 2>&1 | \
        stdbuf -oL tr '\r' '\n' | \
        grep -v "^$" | \
        while IFS= read -r line; do
            echo "# Installing packages... $line" >&2
        done
}

generate_fstab() {
    log_step "Generating fstab"
    genfstab -U /mnt >> /mnt/etc/fstab
}

configure_system() {
    log_step "Configuring system"
    
    # Timezone
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/${INSTALL_TIMEZONE}" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    # Locale
    if ! grep -q "^${INSTALL_LOCALE}" /mnt/etc/locale.gen; then
        echo "${INSTALL_LOCALE} UTF-8" >> /mnt/etc/locale.gen
    else
        sed -i "s/^#${INSTALL_LOCALE}/${INSTALL_LOCALE}/" /mnt/etc/locale.gen
    fi
    arch-chroot /mnt locale-gen >/dev/null 2>&1
    echo "LANG=${INSTALL_LOCALE}" > /mnt/etc/locale.conf
    
    # Keymap
    echo "KEYMAP=${INSTALL_KEYMAP}" > /mnt/etc/vconsole.conf
    
    # Hostname
    echo "${INSTALL_HOSTNAME}" > /mnt/etc/hostname
    cat > /mnt/etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${INSTALL_HOSTNAME}.localdomain ${INSTALL_HOSTNAME}
EOF
    
    # Users
    arch-chroot /mnt bash -c "echo 'root:${INSTALL_ROOT_PASSWORD}' | chpasswd"
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$INSTALL_USER"
    arch-chroot /mnt bash -c "echo '${INSTALL_USER}:${INSTALL_USER_PASSWORD}' | chpasswd"
    arch-chroot /mnt sed -i 's/^# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers
    
    # NetworkManager
    arch-chroot /mnt systemctl enable NetworkManager >/dev/null 2>&1
    
    # Initramfs hooks
    local need_mkinit=false
    if is_true "$INSTALL_USE_LUKS"; then
        arch-chroot /mnt sed -i 's/filesystems/encrypt filesystems/' /etc/mkinitcpio.conf
        need_mkinit=true
    fi
    if is_true "$INSTALL_USE_LVM"; then
        arch-chroot /mnt sed -i 's/filesystems/lvm2 filesystems/' /etc/mkinitcpio.conf
        need_mkinit=true
    fi
    [[ $need_mkinit == true ]] && arch-chroot /mnt mkinitcpio -P >/dev/null 2>&1
}

setup_swapfile() {
    log_step "Creating swapfile"
    
    local size_gb
    size_gb=$(auto_swap_size_gb)
    
    if [[ $INSTALL_FILESYSTEM == "btrfs" ]]; then
        arch-chroot /mnt truncate -s 0 /swapfile
        arch-chroot /mnt chattr +C /swapfile
        arch-chroot /mnt btrfs property set /swapfile compression none
    fi
    
    arch-chroot /mnt fallocate -l "${size_gb}G" /swapfile
    arch-chroot /mnt chmod 600 /swapfile
    arch-chroot /mnt mkswap /swapfile >/dev/null 2>&1
    echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
}

setup_bootloader() {
    log_step "Installing bootloader"
    
    local root_uuid
    root_uuid=$(blkid -s UUID -o value "$ROOT_DEVICE")
    
    if [[ $BOOT_MODE == "uefi" ]]; then
        if [[ $SELECTED_BOOTLOADER == "systemd-boot" ]]; then
            arch-chroot /mnt bootctl install
            
            cat > /mnt/boot/loader/loader.conf <<'EOF'
default arch
timeout 3
console-mode auto
editor no
EOF
            
            cat > /mnt/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
EOF
            [[ -n $MICROCODE_IMG ]] && echo "initrd  /${MICROCODE_IMG}" >> /mnt/boot/loader/entries/arch.conf
            cat >> /mnt/boot/loader/entries/arch.conf <<EOF
initrd  /initramfs-linux.img
EOF
            
            if is_true "$INSTALL_USE_LUKS"; then
                echo "options cryptdevice=UUID=${CRYPT_UUID}:${INSTALL_LUKS_NAME} root=UUID=${root_uuid} rw quiet" >> /mnt/boot/loader/entries/arch.conf
            else
                echo "options root=UUID=${root_uuid} rw quiet" >> /mnt/boot/loader/entries/arch.conf
            fi
        else
            # GRUB on UEFI
            if is_true "$INSTALL_USE_LUKS"; then
                arch-chroot /mnt sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
                arch-chroot /mnt sed -i "/^GRUB_CMDLINE_LINUX=/ s/\"$/ cryptdevice=UUID=${CRYPT_UUID}:${INSTALL_LUKS_NAME}\"/" /etc/default/grub
            fi
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
        fi
    else
        # GRUB on BIOS
        if is_true "$INSTALL_USE_LUKS"; then
            arch-chroot /mnt sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
            arch-chroot /mnt sed -i "/^GRUB_CMDLINE_LINUX=/ s/\"$/ cryptdevice=UUID=${CRYPT_UUID}:${INSTALL_LUKS_NAME}\"/" /etc/default/grub
        fi
        arch-chroot /mnt grub-install --target=i386-pc "${TARGET_DISK}"
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    fi
}

install_desktop() {
    [[ $INSTALL_DESKTOP_CHOICE == "none" ]] && return
    
    local desktop_script="${SCRIPT_DIR}/install-desktop.sh"
    [[ -f $desktop_script ]] || return
    
    log_step "Installing desktop environment"
    
    local target_path="/root/install-desktop.sh"
    cp "$desktop_script" "/mnt${target_path}"
    chmod +x "/mnt${target_path}"
    
    arch-chroot /mnt env "DESKTOP_ENV=${INSTALL_DESKTOP_CHOICE}" "$target_path" 2>&1 | \
        while IFS= read -r line; do
            echo "# Desktop: $line" >&2
        done
}

run_bundle() {
    [[ -z $INSTALL_BUNDLE_CHOICE ]] && return
    
    local bundle_script="${SCRIPT_DIR}/${INSTALL_BUNDLE_CHOICE}.sh"
    [[ -f $bundle_script ]] || return
    
    log_step "Running bundle: ${INSTALL_BUNDLE_CHOICE}"
    
    local target_path="/root/bundle.sh"
    cp "$bundle_script" "/mnt${target_path}"
    chmod +x "/mnt${target_path}"
    
    arch-chroot /mnt "$target_path" 2>&1 | \
        while IFS= read -r line; do
            echo "# Bundle: $line" >&2
        done
}

cleanup() {
    if [[ $MOUNTED == true ]]; then
        umount -R /mnt 2>/dev/null || true
    fi
    if is_true "$INSTALL_USE_LVM"; then
        vgchange -an "$INSTALL_VG_NAME" >/dev/null 2>&1 || true
    fi
    if [[ $OPENED_LUKS == true ]]; then
        cryptsetup close "$CRYPT_DEVICE_NAME" >/dev/null 2>&1 || true
    fi
}

# --- Main Installation Flow -------------------------------------------------
main() {
    require_root
    ensure_commands
    
    if ! require_online; then
        exit 1
    fi
    
    # Detect hardware
    DETECTED_BOOT_MODE=$(detect_boot_mode)
    MICROCODE=$(microcode_package)
    MICROCODE_IMG=$(microcode_image "$MICROCODE")
    GPU_DRIVER=$(detect_gpu_driver)
    
    # GUI workflow
    show_welcome
    show_hardware_summary
    
    select_disk
    select_filesystem
    select_layout
    select_encryption
    configure_system_settings
    configure_users
    select_desktop
    select_bundles
    
    # Finalize boot configuration
    BOOT_MODE=$(resolve_boot_mode "$DETECTED_BOOT_MODE")
    SELECTED_BOOTLOADER=$(resolve_bootloader "$BOOT_MODE")
    
    show_installation_summary
    
    TARGET_DISK="$INSTALL_DISK"
    PART_SUFFIX=$(partition_suffix_for "$TARGET_DISK")
    FILESYSTEM_TYPE="$INSTALL_FILESYSTEM"
    
    trap cleanup EXIT
    
    # Installation progress
    {
        echo "0"
        echo "# Partitioning disk..."
        partition_disk "$TARGET_DISK"
        
        echo "5"
        echo "# Formatting boot partition..."
        format_boot_partition
        
        echo "10"
        echo "# Setting up encryption..."
        setup_luks_container
        
        echo "15"
        echo "# Configuring storage..."
        setup_storage_stack
        
        echo "20"
        echo "# Formatting filesystems..."
        format_filesystems
        
        echo "25"
        echo "# Preparing Btrfs subvolumes..."
        prepare_btrfs_subvolumes
        
        echo "30"
        echo "# Mounting filesystems..."
        mount_filesystems
        
        echo "35"
        echo "# Installing base system (this may take a while)..."
        install_base_system
        
        echo "60"
        echo "# Generating fstab..."
        generate_fstab
        
        echo "65"
        echo "# Configuring system..."
        configure_system
        
        echo "75"
        echo "# Creating swapfile..."
        setup_swapfile
        
        echo "80"
        echo "# Installing bootloader..."
        setup_bootloader
        
        echo "85"
        echo "# Installing desktop environment..."
        install_desktop
        
        echo "95"
        echo "# Running post-install bundle..."
        run_bundle
        
        echo "100"
        echo "# Installation complete!"
        sleep 2
    } | wt_gauge "Installing Arch Linux" "Please wait while the installation completes..." 8 70
    
    # Success message
    local success_msg="Installation completed successfully!\n\n"
    success_msg+="System configuration:\n"
    success_msg+="• Hostname: ${INSTALL_HOSTNAME}\n"
    success_msg+="• User: ${INSTALL_USER}\n"
    success_msg+="• Desktop: ${INSTALL_DESKTOP_CHOICE}\n\n"
    success_msg+="Next steps:\n"
    success_msg+="1. Review the installation\n"
    success_msg+="2. Unmount: umount -R /mnt\n"
    success_msg+="3. Reboot: reboot\n\n"
    success_msg+="Remove the installation media and boot into your new Arch Linux system!"
    
    wt_msgbox "Installation Complete" "$success_msg" 20 75
}

# --- Entry Point -------------------------------------------------------------
main "$@"
