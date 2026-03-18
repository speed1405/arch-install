#!/usr/bin/env bash
# Arch Linux installer with gum TUI interface
# Built from scratch for a modern, user-friendly installation experience
# Run from an Arch ISO live session with networking enabled

set -euo pipefail
IFS=$'\n\t'

# --- Global Configuration Variables ------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TUI Configuration - Using gum for modern interface
TUI_AVAILABLE=false

# Installation configuration (populated by GUI)
INSTALL_DISK=""
INSTALL_HOSTNAME="archlinux"
INSTALL_TIMEZONE="UTC"
INSTALL_LOCALE="en_US.UTF-8"
INSTALL_KEYMAP="us"
INSTALL_ROOT_PASSWORD=""
INSTALL_USER=""
INSTALL_USER_PASSWORD=""
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
INSTALL_BUNDLE_CHOICES=()
INSTALL_AUR_HELPER="none"
INSTALL_MIRROR_REGION="Worldwide"
BTRFS_MOUNT_OPTS="compress=zstd,autodefrag"
BTRFS_SUBVOLUMES="@:/ @home:/home @var_log:/var/log @var_cache:/var/cache @snapshots:/.snapshots"
BEGINNER_MODE=false
INSTALL_LAPTOP_MODE=false

# Performance tuning configuration
INSTALL_CPU_GOVERNOR="schedutil"
INSTALL_IO_SCHEDULER="mq-deadline"
INSTALL_SWAPPINESS=10
INSTALL_ZRAM=true
INSTALL_IRQBALANCE=true
INSTALL_THERMALD=false

# Backup solution configuration
INSTALL_BACKUP_SOLUTION="none"

# Runtime state
MOUNTED=false
BOOT_MODE=""
DETECTED_BOOT_MODE=""
SELECTED_BOOTLOADER=""
TARGET_DISK=""
PART_SUFFIX=""
PART_BOOT=""
PART_ROOT=""
ROOT_DEVICE=""
ENCRYPTED_DEVICE=""
OPENED_LUKS=false
CRYPT_DEVICE_NAME=""
CRYPT_UUID=""
HOME_DEVICE=""
MICROCODE=""
MICROCODE_IMG=""
GPU_DRIVER=""

# Required commands (gum will be checked separately)
REQUIRED_TOOLS=(lsblk awk sed grep parted sgdisk mkfs.fat mkfs.ext4 cryptsetup pacstrap genfstab arch-chroot timedatectl lspci ping systemd-detect-virt blkid)

# --- TUI Detection and Setup -------------------------------------------------
check_gum() {
    # Check if gum is available
    if command -v gum >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

install_gum() {
    log_step "Installing gum TUI tool..."
    local output
    
    # Check network connectivity first
    if ! ping -c 1 -W 2 archlinux.org >/dev/null 2>&1; then
        log_error "No network connectivity detected."
        log_error "Please configure networking before running this installer."
        log_error "You can use: iwctl, nmcli, or check your Ethernet connection."
        return 1
    fi
    
    # Update package database and install gum
    # Using -Sy is safe here as we're on a fresh Arch ISO live environment
    # Individual package installations use -S to avoid redundant syncs
    log_info "Updating package database..."
    if output=$(pacman -Sy 2>&1); then
        log_info "Package database updated."
    else
        log_error "Failed to update package database"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
    
    # Using --noconfirm is necessary for automation and is safe here
    # as we're installing a single, known package from official repos
    log_info "Installing gum from Arch repos..."
    if output=$(pacman -S --noconfirm gum 2>&1); then
        log_info "gum installed successfully."
        return 0
    else
        log_error "Failed to install gum"
        echo "$output" | grep -v "warning:" >&2
        return 1
    fi
}

# --- TUI Helper Functions with gum -------------------------------------------
# Wrapper functions using gum for modern TUI interface
wt_msgbox() {
    local title="$1"
    local message="$2"
    # height and width params ignored - gum handles sizing automatically
    
    # Display message and wait for user to press Enter
    echo -e "$message" | gum format
    gum confirm "Press Enter to continue" --affirmative "OK" --negative "" --default=true 2>/dev/null || true
}

wt_yesno() {
    local title="$1"
    local message="$2"
    # height and width params ignored - gum handles sizing automatically
    
    # Show title if provided
    if [[ -n "$title" ]]; then
        gum style --bold --foreground 212 "$title"
    fi
    
    # Ask yes/no question
    gum confirm "$message"
}

wt_inputbox() {
    local title="$1"
    local message="$2"
    local default="${3:-}"
    local _height="${4:-}"
    local _width="${5:-}"
    
    # Show title if provided
    if [[ -n "$title" ]]; then
        gum style --bold --foreground 212 "$title"
    fi
    
    # Get input with optional default value
    if [[ -n "$default" ]]; then
        gum input --placeholder "$message" --value "$default"
    else
        gum input --placeholder "$message"
    fi
}

wt_passwordbox() {
    local title="$1"
    local message="$2"
    local _height="${3:-}"
    local _width="${4:-}"
    
    # Show title if provided
    if [[ -n "$title" ]]; then
        gum style --bold --foreground 212 "$title"
    fi
    
    # Get password input (hidden)
    gum input --password --placeholder "$message"
}

wt_menu() {
    local title="$1"
    local message="$2"
    local _height="$3"
    local _width="$4"
    local _menu_height="$5"
    shift 5
    
    # Show title if provided
    if [[ -n "$title" ]]; then
        gum style --bold --foreground 212 "$title"
    fi
    
    # Show message/prompt if provided
    if [[ -n "$message" ]]; then
        echo "$message"
    fi
    
    # Build menu items from tag/description pairs
    local items=()
    while [[ $# -gt 0 ]]; do
        local tag="$1"
        local desc="$2"
        # Combine tag and description for display
        items+=("$tag - $desc")
        shift 2
    done
    
    # Show menu and extract the tag from selection
    local selection
    selection=$(printf '%s\n' "${items[@]}" | gum choose --header "$message" 2>/dev/null) || return 1
    
    # Extract just the tag (before the " - ")
    echo "${selection%% - *}"
}

wt_checklist() {
    local title="$1"
    local message="$2"
    local _height="$3"
    local _width="$4"
    local _list_height="$5"
    shift 5
    
    # Show title if provided
    if [[ -n "$title" ]]; then
        gum style --bold --foreground 212 "$title"
    fi
    
    # Build checklist items from tag/description/status triples
    local items=()
    local selected=()
    while [[ $# -gt 0 ]]; do
        local tag="$1"
        local desc="$2"
        local status="$3"
        # Combine tag and description for display
        items+=("$tag - $desc")
        # Track pre-selected items
        if [[ "$status" == "on" || "$status" == "ON" ]]; then
            selected+=("$tag - $desc")
        fi
        shift 3
    done
    
    # Show multi-select checklist
    local selections
    
    if [[ ${#selected[@]} -gt 0 ]]; then
        # With pre-selected items
        selections=$(printf '%s\n' "${items[@]}" | gum choose --no-limit --header "$message" --selected "${selected[@]}" 2>/dev/null || echo "")
    else
        # No pre-selected items
        selections=$(printf '%s\n' "${items[@]}" | gum choose --no-limit --header "$message" 2>/dev/null || echo "")
    fi
    
    # Extract just the tags (before the " - ") and format like whiptail output
    # Process: 1) Remove descriptions, 2) Join lines with spaces, 3) Trim trailing space, 4) Quote each tag
    if [[ -n "$selections" ]]; then
        echo "$selections" | sed 's/ - .*//' | tr '\n' ' ' | sed 's/ *$//' | awk '{for(i=1;i<=NF;i++) printf "\"%s\" ", $i}'
    fi
}

wt_infobox() {
    # Display info without waiting for user input
    local title="$1"
    local message="$2"
    # height and width params ignored - gum handles sizing automatically
    
    # Show title if provided
    if [[ -n "$title" ]]; then
        gum style --bold --foreground 212 "$title"
    fi
    
    # Display message (non-blocking)
    echo "$message"
}

wt_gauge() {
    # Display a progress indicator using gum spin
    # Note: gum doesn't have a traditional gauge, so we use spin for long operations
    # Usage is different from dialog/whiptail gauge - this wrapper provides compatibility
    local title="$1"
    local message="$2"
    # height and width params ignored - gum handles sizing automatically
    
    # For gauge operations, read and discard stdin (gauge input format is different from gum)
    # This maintains API compatibility with original dialog/whiptail gauge
    while IFS= read -r line; do
        : # Discard each line
    done
    
    # Show a simple message instead
    echo "$message"
}

# --- Logging Functions -------------------------------------------------------
log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }
log_error() { printf 'ERROR: %s\n' "$1" >&2; }

# fail_early: For errors that occur before TUI dependencies (gum) are installed
fail_early() {
    log_error "$1"
    exit 1
}

# fail: For errors after TUI is available
fail() { 
    log_error "$1"
    if [[ "$TUI_AVAILABLE" == "true" ]]; then
        wt_msgbox "Error" "$1" 10 60 || true
    fi
    exit 1
}

# --- Pre-flight Checks -------------------------------------------------------
require_root() {
    [[ ${EUID} -eq 0 ]] || fail_early "This installer must be run as root."
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
        if [[ "$TUI_AVAILABLE" == "true" ]]; then
            wt_msgbox "Network Required" "No network connectivity detected.\n\nPlease configure networking before running this installer.\n\nYou can use: iwctl, nmcli, or check your Ethernet connection." 12 70
        else
            log_error "No network connectivity detected."
            log_error "Please configure networking before running this installer."
        fi
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

get_disk_layout() {
    # Display detailed layout for a specific disk
    local disk="$1"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk" 2>/dev/null || echo "Unable to read disk layout"
}

show_all_disks_layout() {
    # Show layout of all disks in the system
    local output=""
    output+="Current Disk Layout:\n\n"
    # Limit to 50 lines to prevent overwhelming TUI dialog with systems that have many partitions
    output+="$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | head -50)\n\n"
    output+="This shows all available disks and their partitions.\n"
    output+="Select a disk to install Arch Linux."
    echo "$output"
}

# --- GUI Workflow Functions --------------------------------------------------
show_welcome() {
    local message="Welcome to the Arch Linux Installer!\n\n"
    message+="This installer will guide you through setting up Arch Linux with an enhanced TUI (Text User Interface).\n\n"
    message+="Features:\n"
    message+="• Hardware auto-detection\n"
    message+="• Multiple filesystem options (ext4, Btrfs)\n"
    message+="• Optional LVM and LUKS encryption\n"
    message+="• Desktop environment selection\n"
    message+="• Post-install bundle options\n"
    message+="• Progress indicators throughout installation\n\n"
    message+="Press OK to begin."
    
    # Allow user to cancel - if they do, exit gracefully
    if ! wt_msgbox "Welcome" "$message" 20 70; then
        log_info "Installation cancelled by user at welcome screen."
        exit 0
    fi
    
    # Ask if user wants beginner mode
    local mode_message="Would you like to use Beginner Mode?\n\n"
    mode_message+="📚 BEGINNER MODE (Recommended for new users):\n"
    mode_message+="• Simplified options with recommended choices\n"
    mode_message+="• Clear explanations for technical terms\n"
    mode_message+="• Safe, tested defaults pre-selected\n"
    mode_message+="• Step-by-step guidance\n\n"
    mode_message+="🔧 ADVANCED MODE:\n"
    mode_message+="• Full control over all options\n"
    mode_message+="• Advanced partitioning schemes\n"
    mode_message+="• Custom configurations\n\n"
    mode_message+="Select 'Yes' for Beginner Mode, 'No' for Advanced Mode."
    
    if wt_yesno "Installation Mode" "$mode_message" 20 75; then
        BEGINNER_MODE=true
        log_info "Beginner mode enabled"
        wt_msgbox "Beginner Mode" "Beginner mode activated! ✓\n\nYou'll see:\n• Recommended options marked clearly\n• Detailed explanations\n• Simpler choices\n\nYou can still customize your installation!" 14 70 || true
    else
        BEGINNER_MODE=false
        log_info "Advanced mode selected"
    fi
}

show_requirements_checklist() {
    if [[ "$BEGINNER_MODE" != "true" ]]; then
        return  # Skip for advanced users
    fi
    
    local checklist="Pre-Installation Checklist\n\n"
    checklist+="Before we begin, please ensure you have:\n\n"
    checklist+="✓ Booted from Arch Linux ISO\n"
    checklist+="✓ Active internet connection (will be verified)\n"
    checklist+="✓ Backed up any important data\n"
    checklist+="✓ At least 20 GB of free disk space\n"
    checklist+="✓ Know which disk to install on\n\n"
    checklist+="⚠️ IMPORTANT WARNINGS:\n\n"
    checklist+="• The selected disk will be COMPLETELY ERASED\n"
    checklist+="• Double-check disk selection carefully\n"
    checklist+="• Installation takes 15-30 minutes\n"
    checklist+="• Do not power off during installation\n\n"
    checklist+="📝 What you'll need to decide:\n\n"
    checklist+="• Disk encryption (yes/no)\n"
    checklist+="• Computer name (hostname)\n"
    checklist+="• Your timezone\n"
    checklist+="• User account name and passwords\n"
    checklist+="• Desktop environment preference\n\n"
    checklist+="Ready to continue?"
    
    if ! wt_yesno "Ready to Install?" "$checklist" 28 70; then
        log_info "Installation cancelled by user at requirements check."
        exit 0
    fi
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
    
    # Allow cancellation on informational dialogs - don't exit if user presses ESC
    if ! wt_msgbox "Hardware Summary" "$message" 18 75; then
        # User cancelled - ask if they want to exit
        if wt_yesno "Exit Installer?" "Do you want to exit the installer?" 10 60; then
            log_info "Installation cancelled by user at hardware summary."
            exit 0
        fi
        # If they don't want to exit, show the summary again
        wt_msgbox "Hardware Summary" "$message" 18 75 || true
    fi
}

select_laptop_mode() {
    # Detect if system has a battery
    local has_battery=false
    for battery_path in /sys/class/power_supply/BAT* /sys/class/power_supply/battery; do
        if [[ -d "$battery_path" ]]; then
            has_battery=true
            break
        fi
    done
    
    local laptop_message=""
    
    if [[ "$has_battery" == true ]]; then
        # Battery detected - recommend laptop mode
        if [[ "$BEGINNER_MODE" == "true" ]]; then
            laptop_message="💻 Laptop Detected!\n\n"
            laptop_message+="A battery was found on your system, which means this is likely a laptop.\n\n"
            laptop_message+="🔋 LAPTOP OPTIMIZATIONS include:\n"
            laptop_message+="• TLP - Advanced power management for better battery life\n"
            laptop_message+="• CPU frequency scaling - Balances performance and battery\n"
            laptop_message+="• Display brightness optimization\n"
            laptop_message+="• USB power management\n"
            laptop_message+="• Disk power management\n"
            laptop_message+="• WiFi power saving\n\n"
            laptop_message+="⭐ RECOMMENDATION: Enable laptop optimizations for better battery life.\n\n"
            laptop_message+="Enable laptop optimizations?"
        else
            laptop_message="Battery detected on your system.\n\n"
            laptop_message+="Enable laptop optimizations?\n\n"
            laptop_message+="This will install and configure:\n"
            laptop_message+="• TLP for power management\n"
            laptop_message+="• Battery threshold settings\n"
            laptop_message+="• Power-saving features\n\n"
            laptop_message+="Recommended for laptops."
        fi
        
        if wt_yesno "Laptop Optimizations" "$laptop_message" 22 75; then
            INSTALL_LAPTOP_MODE=true
            log_info "Laptop optimizations enabled"
        else
            INSTALL_LAPTOP_MODE=false
            log_info "Laptop optimizations disabled"
        fi
    else
        # No battery detected - ask if this is still a laptop
        if [[ "$BEGINNER_MODE" == "true" ]]; then
            laptop_message="💻 Is this a laptop?\n\n"
            laptop_message+="No battery was detected, but you might still be using a laptop\n"
            laptop_message+="(e.g., battery not connected, virtual machine, etc.).\n\n"
            laptop_message+="🔋 LAPTOP OPTIMIZATIONS include:\n"
            laptop_message+="• Better battery life and power management\n"
            laptop_message+="• Automatic CPU frequency scaling\n"
            laptop_message+="• Display and USB power saving\n"
            laptop_message+="• WiFi power management\n\n"
            laptop_message+="💡 TIP:\n"
            laptop_message+="• Choose 'Yes' if installing on a laptop\n"
            laptop_message+="• Choose 'No' for desktop computers\n\n"
            laptop_message+="Is this a laptop?"
        else
            laptop_message="No battery detected.\n\n"
            laptop_message+="Enable laptop optimizations anyway?\n\n"
            laptop_message+="Select 'Yes' if:\n"
            laptop_message+="• Installing on a laptop without connected battery\n"
            laptop_message+="• Testing in a VM but targeting laptop deployment\n\n"
            laptop_message+="Select 'No' for desktop systems."
        fi
        
        if wt_yesno "Laptop Mode" "$laptop_message" 22 75; then
            INSTALL_LAPTOP_MODE=true
            log_info "Laptop optimizations enabled (manual selection)"
        else
            INSTALL_LAPTOP_MODE=false
            log_info "Laptop optimizations disabled (desktop mode)"
        fi
    fi
}

select_disk() {
    # First, show the current disk layout to the user
    local layout_message
    layout_message=$(show_all_disks_layout)
    wt_msgbox "Disk Layout" "$layout_message" 25 80 || true
    
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
    
    # Validate that selection is a valid positive number
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        fail "Invalid disk selection: '$selection'. Please try again."
    fi
    
    # Validate selection is within valid range (1 to number of disks)
    local num_disks=$((${#disk_list[@]} / 2))
    if (( selection < 1 || selection > num_disks )); then
        fail "Invalid disk selection: '$selection'. Please select a number between 1 and $num_disks."
    fi
    
    # Get the actual disk path from the selection
    local selected_idx=$((selection - 1))
    local disk_line
    disk_line=$(get_disks | sed -n "$((selected_idx + 1))p")
    INSTALL_DISK=$(echo "$disk_line" | awk '{print $1}')
    
    # Show detailed layout of the selected disk
    local selected_disk_layout
    selected_disk_layout=$(get_disk_layout "$INSTALL_DISK")
    local detail_message="Selected Disk Layout:\n\n${selected_disk_layout}\n\n"
    detail_message+="Disk: ${INSTALL_DISK}\n\n"
    detail_message+="⚠️  Current partitions and data shown above will be ERASED!"
    wt_msgbox "Selected Disk Details" "$detail_message" 20 80 || true
    
    # Confirm disk selection
    local confirm_msg="You have selected:\n\n${INSTALL_DISK}\n\n"
    confirm_msg+="⚠️  ALL DATA ON THIS DISK WILL BE PERMANENTLY ERASED!\n\n"
    confirm_msg+="Are you absolutely sure you want to continue?"
    
    if ! wt_yesno "Confirm Disk Erase" "$confirm_msg" 15 70; then
        fail "Disk selection cancelled by user."
    fi
}

select_filesystem() {
    # Show filesystem information first
    local fs_info="Filesystem Information:\n\n"
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        fs_info+="A filesystem determines how your data is stored on disk.\n"
        fs_info+="For most users, ext4 is the best choice.\n\n"
    fi
    
    fs_info+="• ext4 ⭐ RECOMMENDED:\n"
    fs_info+="  - Traditional, stable, and well-tested\n"
    fs_info+="  - Best for: General use, maximum compatibility\n"
    fs_info+="  - Features: Journaling, proven reliability\n"
    fs_info+="  - Used by millions of Linux systems worldwide\n\n"
    fs_info+="• Btrfs (Advanced):\n"
    fs_info+="  - Modern copy-on-write filesystem\n"
    fs_info+="  - Best for: Advanced users, snapshot needs\n"
    fs_info+="  - Features: Snapshots, compression, subvolumes\n"
    fs_info+="  - Newer technology, more complex setup\n\n"
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        fs_info+="💡 TIP: If unsure, choose ext4. It's reliable and proven."
    else
        fs_info+="Choose the filesystem that best fits your needs."
    fi
    
    wt_msgbox "Filesystem Information" "$fs_info" 22 75 || true
    
    local fs_choice
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        fs_choice=$(wt_menu "Filesystem Type" "Select the root filesystem type:" 15 75 4 \
            "1" "ext4 - Traditional Linux filesystem ⭐ RECOMMENDED" \
            "2" "btrfs - Modern CoW filesystem (Advanced)")
    else
        fs_choice=$(wt_menu "Filesystem Type" "Select the root filesystem type:" 15 70 4 \
            "1" "ext4 - Traditional Linux filesystem (recommended)" \
            "2" "btrfs - Modern CoW filesystem with snapshots")
    fi
    
    case "$fs_choice" in
        1) INSTALL_FILESYSTEM="ext4" ;;
        2) INSTALL_FILESYSTEM="btrfs" ;;
        *) INSTALL_FILESYSTEM="ext4" ;;
    esac
}

select_layout() {
    # Show partition layout information first
    local layout_info="Partition Layout Information:\n\n"
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        layout_info+="This determines how your disk is organized.\n"
        layout_info+="For beginners, 'Single Partition' is simplest and works great.\n\n"
    fi
    
    layout_info+="• Single Partition ⭐ RECOMMENDED:\n"
    layout_info+="  - One partition for everything - simplest option\n"
    layout_info+="  - Easy to understand and maintain\n"
    layout_info+="  - Best for: Beginners, simple setups\n"
    layout_info+="  - Perfect for most desktop/laptop users\n\n"
    layout_info+="• LVM - Logical Volume Management (Advanced):\n"
    layout_info+="  - Flexible volume sizing and management\n"
    layout_info+="  - Can resize partitions later\n"
    layout_info+="  - Best for: Users wanting future flexibility\n"
    layout_info+="  - More complex to manage\n\n"
    layout_info+="• LVM with /home (Advanced):\n"
    layout_info+="  - Keeps user data separate from system\n"
    layout_info+="  - Easier to reinstall OS without losing data\n"
    layout_info+="  - Best for: Multi-user systems, data safety\n"
    layout_info+="  - Requires understanding of partitions\n\n"
    
    if [[ "$INSTALL_FILESYSTEM" == "btrfs" ]]; then
        layout_info+="• Btrfs Subvolumes (Advanced Btrfs users):\n"
        layout_info+="  - Automatic snapshots support\n"
        layout_info+="  - System rollback capability\n"
        layout_info+="  - Best for: Advanced users, system rollback needs\n"
        layout_info+="  - Requires Btrfs knowledge\n\n"
    fi
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        layout_info+="💡 TIP: Choose 'Single Partition' for a simple, reliable setup."
    else
        layout_info+="Choose the layout that best fits your needs."
    fi
    
    wt_msgbox "Layout Information" "$layout_info" 26 78 || true
    
    local layout_choice
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        if [[ "$INSTALL_FILESYSTEM" == "btrfs" ]]; then
            layout_choice=$(wt_menu "Partition Layout" "Select partition layout:" 18 78 5 \
                "1" "Single partition ⭐ RECOMMENDED" \
                "2" "LVM - Flexible storage (Advanced)" \
                "3" "LVM with /home - Separate user data (Advanced)" \
                "4" "Btrfs subvolumes (Advanced)")
        else
            layout_choice=$(wt_menu "Partition Layout" "Select partition layout:" 18 78 4 \
                "1" "Single partition ⭐ RECOMMENDED" \
                "2" "LVM - Flexible storage (Advanced)" \
                "3" "LVM with /home - Separate user data (Advanced)")
        fi
    else
        layout_choice=$(wt_menu "Partition Layout" "Select partition layout:" 18 75 5 \
            "1" "Single partition - Simple root partition only" \
            "2" "LVM - Logical Volume Management for flexibility" \
            "3" "LVM with separate /home - Split root and home volumes" \
            "4" "Btrfs subvolumes - Btrfs with @, @home, etc.")
    fi
    
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
    local encrypt_message=""
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        encrypt_message="Enable disk encryption?\n\n"
        encrypt_message+="🔒 WHAT IS DISK ENCRYPTION?\n"
        encrypt_message+="Encryption scrambles your data so only someone with your\n"
        encrypt_message+="passphrase can read it. This protects your data if your\n"
        encrypt_message+="computer is lost or stolen.\n\n"
        encrypt_message+="✅ PROS:\n"
        encrypt_message+="• Strong protection for your personal data\n"
        encrypt_message+="• Peace of mind for laptops\n"
        encrypt_message+="• Industry-standard security (LUKS)\n\n"
        encrypt_message+="⚠️ CONS:\n"
        encrypt_message+="• Must enter passphrase every boot\n"
        encrypt_message+="• Slight performance overhead (usually unnoticeable)\n"
        encrypt_message+="• Cannot recover data if passphrase is forgotten\n\n"
        encrypt_message+="💡 RECOMMENDATION:\n"
        encrypt_message+="• Laptops: Yes (recommended)\n"
        encrypt_message+="• Desktops: Optional (your choice)\n"
        encrypt_message+="• Shared computers: No (inconvenient for multiple users)\n\n"
        encrypt_message+="Enable encryption now?"
    else
        encrypt_message="Enable LUKS disk encryption?\n\n"
        encrypt_message+="This will encrypt your root partition for security.\n"
        encrypt_message+="You will need to enter a passphrase at boot."
    fi
    
    if wt_yesno "Disk Encryption" "$encrypt_message" 24 75; then
        INSTALL_USE_LUKS=true
        
        if [[ "$BEGINNER_MODE" == "true" ]]; then
            wt_msgbox "Encryption Tips" "Creating a strong passphrase:\n\n• Use at least 12-15 characters\n• Mix letters, numbers, and symbols\n• Avoid common words or patterns\n• Don't use personal information\n• Consider a passphrase like: 'correct-horse-battery-staple'\n\n⚠️ IMPORTANT: Write down your passphrase!\nIf you forget it, your data cannot be recovered." 18 75 || true
        fi
        
        while true; do
            local pass1 pass2
            pass1=$(wt_passwordbox "Encryption Passphrase" "Enter LUKS encryption passphrase:" 10 60)
            
            if [[ -z $pass1 ]]; then
                wt_msgbox "Error" "Passphrase cannot be empty." 8 50
                continue
            fi
            
            # Enforce minimum 8 characters for security (all users)
            if [[ ${#pass1} -lt 8 ]]; then
                if [[ "$BEGINNER_MODE" == "true" ]]; then
                    wt_msgbox "Passphrase Too Short" "Error: Your passphrase is too short (${#pass1} characters).\n\nMinimum required: 8 characters\nRecommended: 12+ characters for better security\n\nPlease enter a longer passphrase." 12 65
                else
                    wt_msgbox "Passphrase Too Short" "Passphrase must be at least 8 characters.\nCurrent length: ${#pass1}\n\nPlease enter a longer passphrase." 10 60
                fi
                continue
            fi
            
            # Warn about weak but acceptable passphrases (8-11 chars) in beginner mode
            if [[ "$BEGINNER_MODE" == "true" ]] && [[ ${#pass1} -ge 8 ]] && [[ ${#pass1} -lt 12 ]]; then
                if ! wt_yesno "Weak Passphrase" "Warning: Your passphrase is acceptable but weak (${#pass1} characters).\n\nFor better security, use at least 12 characters.\n\nDo you want to continue with this passphrase?" 12 70; then
                    continue
                fi
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
        
        if [[ "$BEGINNER_MODE" == "true" ]]; then
            wt_msgbox "No Encryption" "Disk encryption disabled.\n\nYour data will not be encrypted.\n\nYou can always reinstall later with encryption if needed." 10 60 || true
        fi
    fi
}

configure_system_settings() {
    # Hostname
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        wt_msgbox "Hostname" "The hostname is your computer's name on the network.\n\n💡 Examples: 'my-laptop', 'arch-desktop', 'workstation'\n\nRules:\n• Use lowercase letters, numbers, and hyphens\n• No spaces or special characters\n• Keep it simple and memorable" 14 70 || true
    fi
    
    INSTALL_HOSTNAME=$(wt_inputbox "Hostname" "Enter system hostname:" "$INSTALL_HOSTNAME" 10 60)
    [[ -n $INSTALL_HOSTNAME ]] || INSTALL_HOSTNAME="archlinux"
    
    # Timezone selection
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        wt_msgbox "Timezone" "Select your timezone to ensure correct time display.\n\nThis affects:\n• System clock\n• File timestamps\n• Scheduled tasks\n\nChoose the timezone closest to your location." 14 70 || true
    fi
    
    local tz_choice
    tz_choice=$(wt_menu "Timezone" "Select your timezone region:" 22 70 11 \
        "1" "America/New_York (US East)" \
        "2" "America/Los_Angeles (US West)" \
        "3" "Europe/London (UK)" \
        "4" "Europe/Paris (Central Europe)" \
        "5" "Asia/Tokyo (Japan)" \
        "6" "Asia/Shanghai (China)" \
        "7" "Australia/Sydney (Australia East)" \
        "8" "Australia/Perth (Australia West)" \
        "9" "Pacific/Auckland (New Zealand)" \
        "10" "Africa/Cairo (Egypt)" \
        "11" "UTC (default)" \
)
    
    case "$tz_choice" in
        1) INSTALL_TIMEZONE="America/New_York" ;;
        2) INSTALL_TIMEZONE="America/Los_Angeles" ;;
        3) INSTALL_TIMEZONE="Europe/London" ;;
        4) INSTALL_TIMEZONE="Europe/Paris" ;;
        5) INSTALL_TIMEZONE="Asia/Tokyo" ;;
        6) INSTALL_TIMEZONE="Asia/Shanghai" ;;
        7) INSTALL_TIMEZONE="Australia/Sydney" ;;
        8) INSTALL_TIMEZONE="Australia/Perth" ;;
        9) INSTALL_TIMEZONE="Pacific/Auckland" ;;
        10) INSTALL_TIMEZONE="Africa/Cairo" ;;
        11|*) INSTALL_TIMEZONE="UTC" ;;
    esac
    
    # Locale selection
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        wt_msgbox "Locale" "The locale determines:\n• Language for system messages\n• Date and time formats\n• Number formats\n• Currency symbols\n\nSelect your preferred language and region." 14 70 || true
    fi
    
    local locale_choice
    locale_choice=$(wt_menu "Locale" "Select system locale:" 18 70 8 \
        "1" "en_US.UTF-8 (US English)" \
        "2" "en_GB.UTF-8 (British English)" \
        "3" "de_DE.UTF-8 (German)" \
        "4" "fr_FR.UTF-8 (French)" \
        "5" "es_ES.UTF-8 (Spanish)" \
        "6" "ja_JP.UTF-8 (Japanese)" \
)
    
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
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        wt_msgbox "Keyboard Layout" "Select the keyboard layout that matches your physical keyboard.\n\nThis ensures keys produce the correct characters.\n\nMost users in the US should choose 'us'." 12 70 || true
    fi
    
    local keymap_choice
    keymap_choice=$(wt_menu "Keyboard Layout" "Select keyboard layout:" 18 70 8 \
        "1" "us (US English)" \
        "2" "uk (British)" \
        "3" "de (German)" \
        "4" "fr (French)" \
        "5" "es (Spanish)" \
)
    
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
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        wt_msgbox "User Accounts" "You need to create two accounts:\n\n1. ROOT account - System administrator\n   • Has full control over the system\n   • Use only when needed for system tasks\n\n2. USER account - Your daily account\n   • For everyday use\n   • Safer than using root\n\nYou'll create passwords for both accounts." 16 70 || true
    fi
    
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
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        wt_msgbox "User Account" "Now create your everyday user account.\n\n💡 Username tips:\n• Use lowercase letters only\n• No spaces or special characters\n• Examples: 'john', 'alice', 'myname'\n\nThis is the account you'll use for daily tasks." 14 70 || true
    fi
    
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
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        local desktop_info="Desktop Environment Selection\n\n"
        desktop_info+="A desktop environment provides the graphical interface\n"
        desktop_info+="(windows, menus, taskbar, etc.) for your system.\n\n"
        desktop_info+="💡 RECOMMENDATIONS FOR BEGINNERS:\n\n"
        desktop_info+="• GNOME - Modern, polished, easy to use\n"
        desktop_info+="• KDE Plasma - Windows-like, highly customizable\n"
        desktop_info+="• XFCE - Fast, simple, uses less resources\n\n"
        desktop_info+="Advanced users may choose i3 or Sway (keyboard-focused)\n"
        desktop_info+="or 'No desktop' for servers."
        wt_msgbox "Desktop Environments" "$desktop_info" 20 70 || true
    fi
    
    local desktop_choice
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        desktop_choice=$(wt_menu "Desktop Environment" "Select a desktop environment to install:" 20 78 11 \
            "gnome" "GNOME - Modern, polished ⭐ BEGINNER FRIENDLY" \
            "kde" "KDE Plasma - Customizable, Windows-like ⭐ BEGINNER FRIENDLY" \
            "xfce" "XFCE - Lightweight, simple ⭐ BEGINNER FRIENDLY" \
            "cinnamon" "Cinnamon - Traditional layout, familiar" \
            "mate" "MATE - Classic desktop, stable" \
            "budgie" "Budgie - Clean and elegant" \
            "lxqt" "LXQt - Very lightweight Qt desktop" \
            "sway" "Sway - Tiling Wayland (Advanced)" \
            "i3" "i3 - Tiling window manager (Advanced)" \
            "none" "No desktop (Server/Minimal install)" \
        )
    else
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
        )
    fi
    
    INSTALL_DESKTOP_CHOICE="${desktop_choice:-none}"
}

select_bundles() {
    local bundle_dir="${SCRIPT_DIR}"
    local bundles=()
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        local bundle_info="Additional Software Bundles\n\n"
        bundle_info+="Bundles are collections of related software.\n"
        bundle_info+="Select bundles based on what you plan to do:\n\n"
        bundle_info+="💡 RECOMMENDATIONS FOR BEGINNERS:\n\n"
        bundle_info+="• Desktop Utilities - Web browser, office, etc.\n"
        bundle_info+="  (Recommended for most desktop users)\n\n"
        bundle_info+="• Optimization - Better performance\n"
        bundle_info+="  (Recommended for all users)\n\n"
        bundle_info+="You can always install more software later!\n\n"
        bundle_info+="Note: AUR helper will be selected in the next step."
        wt_msgbox "Software Bundles" "$bundle_info" 22 70 || true
    fi
    
    # Check for available bundle scripts
    # Core/Essential bundles first
    if [[ -f "${bundle_dir}/optimization.sh" ]]; then
        if [[ "$BEGINNER_MODE" == "true" ]]; then
            bundles+=("optimization" "System optimization ⭐ RECOMMENDED" OFF)
        else
            bundles+=("optimization" "System optimization (zram, pacman, performance)" OFF)
        fi
    fi
    if [[ -f "${bundle_dir}/security.sh" ]]; then
        bundles+=("security" "Security hardening (firewall, antivirus, AppArmor)" OFF)
    fi
    if [[ -f "${bundle_dir}/sysadmin.sh" ]]; then
        bundles+=("sysadmin" "System admin tools (monitoring, backups, maintenance)" OFF)
    fi
    if [[ -f "${bundle_dir}/networking.sh" ]]; then
        bundles+=("networking" "Network tools (Wireshark, nmap, monitoring)" OFF)
    fi
    # Desktop/Application bundles
    if [[ -f "${bundle_dir}/desktop-utilities.sh" ]]; then
        if [[ "$BEGINNER_MODE" == "true" ]]; then
            bundles+=("desktop-utilities" "Desktop utilities (browser, office) ⭐ RECOMMENDED" OFF)
        else
            bundles+=("desktop-utilities" "Desktop utilities (browsers, office)" OFF)
        fi
    fi
    if [[ -f "${bundle_dir}/dev.sh" ]]; then
        bundles+=("dev" "Developer tools (compilers, Docker, etc.)" OFF)
    fi
    if [[ -f "${bundle_dir}/gaming.sh" ]]; then
        bundles+=("gaming" "Gaming setup (Steam, Lutris, Wine)" OFF)
    fi
    if [[ -f "${bundle_dir}/creative.sh" ]]; then
        bundles+=("creative" "Creative apps (GIMP, Blender)" OFF)
    fi
    # Server/Cloud bundles
    if [[ -f "${bundle_dir}/server.sh" ]]; then
        bundles+=("server" "Server tools (SSH, firewall)" OFF)
    fi
    if [[ -f "${bundle_dir}/cloud.sh" ]]; then
        bundles+=("cloud" "Cloud tools (kubectl, terraform)" OFF)
    fi
    
    if [[ ${#bundles[@]} -eq 0 ]]; then
        return
    fi
    
    local selected
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        selected=$(wt_checklist "Additional Software" "Select optional software bundles (use space to select):" 22 80 10 "${bundles[@]}" || echo "")
    else
        selected=$(wt_checklist "Additional Software" "Select optional software bundles:" 20 75 10 "${bundles[@]}" || echo "")
    fi
    
    if [[ -n $selected ]]; then
        # Parse all selected bundles (whiptail returns space-separated quoted items)
        # Safer parsing without eval - remove quotes and split by space
        INSTALL_BUNDLE_CHOICES=()
        while IFS= read -r bundle; do
            [[ -n $bundle ]] && INSTALL_BUNDLE_CHOICES+=("$bundle")
        done < <(echo "$selected" | tr -d '"' | tr ' ' '\n')
    fi
}

select_mirror_region() {
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        local mirror_info="Package Mirror Selection\n\n"
        mirror_info+="Mirrors are servers that host Arch Linux packages.\n"
        mirror_info+="Choosing a mirror close to you makes downloads faster.\n\n"
        mirror_info+="💡 TIP: Select your country or region for best speed.\n"
        mirror_info+="If unsure, 'Worldwide' works but may be slower.\n"
        wt_msgbox "Mirror Information" "$mirror_info" 14 70 || true
    fi
    
    local region_choice
    region_choice=$(wt_menu "Package Mirror Region" "Select your preferred mirror region for faster downloads:" 22 75 12 \
        "1" "Worldwide (use all mirrors)" \
        "2" "United States" \
        "3" "Canada" \
        "4" "United Kingdom" \
        "5" "Germany" \
        "6" "France" \
        "7" "Australia" \
        "8" "Japan" \
        "9" "China" \
        "10" "India" \
        "11" "Brazil" \
        "12" "Skip (use default mirrors)")
    
    case "$region_choice" in
        1) INSTALL_MIRROR_REGION="Worldwide" ;;
        2) INSTALL_MIRROR_REGION="United States" ;;
        3) INSTALL_MIRROR_REGION="Canada" ;;
        4) INSTALL_MIRROR_REGION="United Kingdom" ;;
        5) INSTALL_MIRROR_REGION="Germany" ;;
        6) INSTALL_MIRROR_REGION="France" ;;
        7) INSTALL_MIRROR_REGION="Australia" ;;
        8) INSTALL_MIRROR_REGION="Japan" ;;
        9) INSTALL_MIRROR_REGION="China" ;;
        10) INSTALL_MIRROR_REGION="India" ;;
        11) INSTALL_MIRROR_REGION="Brazil" ;;
        12|*) INSTALL_MIRROR_REGION="Skip" ;;
    esac
}

select_aur_helper() {
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        local aur_info="AUR Helper Selection\n\n"
        aur_info+="The AUR (Arch User Repository) contains community packages\n"
        aur_info+="not in the official repositories.\n\n"
        aur_info+="An AUR helper makes it easy to install these packages.\n\n"
        aur_info+="💡 OPTIONS:\n\n"
        aur_info+="• yay - Popular, user-friendly ⭐ RECOMMENDED\n"
        aur_info+="• paru - Feature-rich, modern alternative\n"
        aur_info+="• None - Skip (install manually later if needed)\n\n"
        aur_info+="Note: AUR helpers are installed after the base system."
        wt_msgbox "AUR Helper Information" "$aur_info" 20 70 || true
    fi
    
    local aur_choice
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        aur_choice=$(wt_menu "AUR Helper" "Select an AUR helper to install:" 14 75 4 \
            "yay" "yay - User-friendly AUR helper ⭐ RECOMMENDED" \
            "paru" "paru - Feature-rich AUR helper" \
            "none" "None - Skip AUR helper installation")
    else
        aur_choice=$(wt_menu "AUR Helper" "Select an AUR helper to install:" 14 70 4 \
            "none" "None - Skip AUR helper installation" \
            "yay" "yay - Yet Another Yogurt (popular)" \
            "paru" "paru - Feature-rich AUR helper")
    fi
    
    INSTALL_AUR_HELPER="${aur_choice:-none}"
}

select_performance_tuning() {
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        local perf_info="Performance Tuning\n\n"
        perf_info+="These settings optimize how your system uses hardware resources.\n"
        perf_info+="The defaults work well for most users - feel free to keep them!\n\n"
        perf_info+="• CPU Governor - Controls how the CPU adjusts speed\n"
        perf_info+="• I/O Scheduler - Controls how disk reads/writes are queued\n"
        perf_info+="• Swappiness - How eagerly the kernel moves RAM contents to disk\n"
        perf_info+="• Zram - Compressed swap space in RAM (saves disk writes)\n\n"
        perf_info+="💡 TIP: The recommended defaults are suitable for most systems."
        wt_msgbox "Performance Tuning" "$perf_info" 18 72 || true
    fi

    # CPU Governor selection
    local governor_choice
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        governor_choice=$(wt_menu "CPU Governor" "Select CPU frequency scaling governor:" 16 78 4 \
            "schedutil" "schedutil - Smart, responsive scaling ⭐ RECOMMENDED" \
            "performance" "performance - Maximum speed (uses more power)" \
            "powersave" "powersave - Always low frequency (battery saving)" \
            "skip" "skip - Keep kernel default (no change)")
    else
        governor_choice=$(wt_menu "CPU Governor" "Select CPU frequency scaling governor:" 16 75 4 \
            "schedutil" "schedutil - scheduler-driven, efficient ⭐ RECOMMENDED" \
            "performance" "performance - Always max frequency" \
            "powersave" "powersave - Always min frequency" \
            "skip" "skip - Don't configure governor")
    fi
    INSTALL_CPU_GOVERNOR="${governor_choice:-schedutil}"

    # I/O Scheduler selection
    local io_choice
    io_choice=$(wt_menu "I/O Scheduler" "Select disk I/O scheduler (applied via udev):" 16 75 4 \
        "mq-deadline" "mq-deadline - Best for SSDs and NVMe ⭐ RECOMMENDED" \
        "bfq" "bfq - Budget Fair Queueing, better for HDDs/desktops" \
        "kyber" "kyber - Low latency for very fast NVMe storage" \
        "skip" "skip - Keep kernel default")
    INSTALL_IO_SCHEDULER="${io_choice:-mq-deadline}"

    # Swappiness selection
    local swap_choice
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        swap_choice=$(wt_menu "Swappiness" "How eagerly should the kernel swap RAM to disk? (lower = prefer RAM):" 18 75 5 \
            "10" "10 - Prefer RAM, swap only when necessary ⭐ RECOMMENDED" \
            "0" "0 - Avoid swap entirely (ideal for 16 GB+ RAM)" \
            "30" "30 - Moderate swap usage" \
            "60" "60 - Kernel default" \
            "100" "100 - Aggressive swap (low RAM systems)")
    else
        swap_choice=$(wt_menu "Swappiness" "Select vm.swappiness value (0=avoid swap, 100=aggressive swap):" 18 75 5 \
            "10" "10 - Low swappiness, prefer RAM ⭐ RECOMMENDED" \
            "0" "0 - Never swap (requires sufficient RAM)" \
            "30" "30 - Moderate swappiness" \
            "60" "60 - Kernel default (balanced)" \
            "100" "100 - High swappiness")
    fi
    INSTALL_SWAPPINESS="${swap_choice:-10}"

    # Additional optimizations checklist
    local extra_selected
    extra_selected=$(wt_checklist "Additional Optimizations" "Select additional performance features:" 14 75 3 \
        "zram" "zram - Compressed swap in RAM (reduces disk I/O)" ON \
        "irqbalance" "irqbalance - Distribute hardware interrupts across CPU cores" ON \
        "thermald" "thermald - Intel CPU thermal management daemon (Intel only)" OFF \
        || echo "")

    # Parse checklist output (process substitution keeps vars in current shell)
    INSTALL_ZRAM=false
    INSTALL_IRQBALANCE=false
    INSTALL_THERMALD=false
    if [[ -n "$extra_selected" ]]; then
        while IFS= read -r item; do
            [[ -n "$item" ]] || continue
            case "$item" in
                zram)       INSTALL_ZRAM=true ;;
                irqbalance) INSTALL_IRQBALANCE=true ;;
                thermald)   INSTALL_THERMALD=true ;;
            esac
        done < <(echo "$extra_selected" | tr -d '"' | tr ' ' '\n')
    fi
}

select_backup_solution() {
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        local backup_info="Backup Solution\n\n"
        backup_info+="A backup solution protects your data from loss.\n"
        backup_info+="You can always set one up after installation too.\n\n"
        backup_info+="• Timeshift - Easy system snapshot tool (like System Restore)\n"
        backup_info+="  Works with ext4 (rsync) and Btrfs. Has a friendly GUI.\n\n"
        backup_info+="• Snapper - Automatic snapshots, best with Btrfs filesystem\n\n"
        backup_info+="• Restic / Borg / rsnapshot - Command-line backup tools\n\n"
        backup_info+="💡 TIP: Timeshift is great for beginners. Choose 'None' to decide later."
        wt_msgbox "Backup Solution" "$backup_info" 20 72 || true
    fi

    local snapper_note=""
    if [[ "$INSTALL_FILESYSTEM" != "btrfs" ]]; then
        snapper_note=" (limited ext4 support - manual config needed)"
    fi

    local backup_choice
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        backup_choice=$(wt_menu "Backup Solution" "Select a backup solution to install and configure:" 18 78 6 \
            "none"      "None - Skip backup setup (configure later)" \
            "timeshift" "Timeshift - Easy system snapshots ⭐ RECOMMENDED" \
            "snapper"   "Snapper - Automatic Btrfs/ext4 snapshots${snapper_note}" \
            "restic"    "Restic - Encrypted deduplicating backup" \
            "borg"      "Borg + Borgmatic - Efficient encrypted backup" \
            "rsnapshot" "rsnapshot - Simple incremental backups (rsync)")
    else
        backup_choice=$(wt_menu "Backup Solution" "Select a backup solution to install and configure:" 18 75 6 \
            "none"      "none - Skip backup setup" \
            "timeshift" "Timeshift - System snapshot tool (rsync/Btrfs)" \
            "snapper"   "Snapper - Btrfs/ext4 snapshots + pacman hooks${snapper_note}" \
            "restic"    "Restic - Encrypted backup with deduplication" \
            "borg"      "Borg + Borgmatic - Deduplicating encrypted backup" \
            "rsnapshot" "rsnapshot - Incremental backups via rsync + hard links")
    fi
    INSTALL_BACKUP_SOLUTION="${backup_choice:-none}"
}

show_installation_summary() {
    local summary=""
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        summary="🎯 Installation Summary - Please Review\n\n"
        summary+="This is your last chance to review before installation begins.\n"
        summary+="⚠️ The disk will be permanently erased after you confirm!\n\n"
    else
        summary="Installation Configuration Summary:\n\n"
    fi
    
    summary+="Disk: ${INSTALL_DISK}\n"
    summary+="Filesystem: ${INSTALL_FILESYSTEM}\n"
    summary+="Layout: ${INSTALL_LAYOUT}\n"
    summary+="Encryption: $(is_true "$INSTALL_USE_LUKS" && echo "Enabled (LUKS)" || echo "Disabled")\n"
    summary+="LVM: $(is_true "$INSTALL_USE_LVM" && echo "Enabled" || echo "Disabled")\n"
    summary+="Boot Mode: ${BOOT_MODE}\n"
    summary+="Bootloader: ${SELECTED_BOOTLOADER}\n\n"
    
    # Show planned partition layout
    summary+="Planned Partition Layout:\n"
    if [[ $BOOT_MODE == "uefi" ]]; then
        summary+="  • EFI Partition: 512 MB (FAT32)\n"
        summary+="  • Root Partition: Remaining space (${INSTALL_FILESYSTEM})\n"
    else
        summary+="  • BIOS Boot: 1 MB\n"
        summary+="  • Root Partition: Remaining space (${INSTALL_FILESYSTEM})\n"
    fi
    
    if is_true "$INSTALL_USE_LUKS"; then
        summary+="  • LUKS Encryption: Enabled on root\n"
    fi
    
    if is_true "$INSTALL_USE_LVM"; then
        if [[ $INSTALL_LAYOUT == "lvm-home" ]]; then
            summary+="  • LVM: ${INSTALL_LV_ROOT_NAME} (${INSTALL_LV_ROOT_SIZE}), ${INSTALL_LV_HOME_NAME} (${INSTALL_LV_HOME_SIZE})\n"
        else
            summary+="  • LVM: ${INSTALL_LV_ROOT_NAME} (100%)\n"
        fi
    fi
    
    if [[ $INSTALL_FILESYSTEM == "btrfs" && $INSTALL_LAYOUT == "btrfs-subvols" ]]; then
        summary+="  • Btrfs Subvolumes: @, @home, @var_log, @var_cache, @snapshots\n"
    fi
    summary+="\n"
    
    summary+="Hostname: ${INSTALL_HOSTNAME}\n"
    summary+="Timezone: ${INSTALL_TIMEZONE}\n"
    summary+="Locale: ${INSTALL_LOCALE}\n"
    summary+="Keymap: ${INSTALL_KEYMAP}\n"
    summary+="User: ${INSTALL_USER}\n"
    summary+="Laptop Mode: $([[ "$INSTALL_LAPTOP_MODE" == "true" ]] && echo "Enabled" || echo "Disabled")\n\n"
    summary+="Mirror Region: ${INSTALL_MIRROR_REGION}\n"
    summary+="Desktop: ${INSTALL_DESKTOP_CHOICE}\n"
    if [[ ${#INSTALL_BUNDLE_CHOICES[@]} -gt 0 ]]; then
        summary+="Bundles: ${INSTALL_BUNDLE_CHOICES[*]}\n"
    else
        summary+="Bundles: none\n"
    fi
    summary+="AUR Helper: ${INSTALL_AUR_HELPER}\n"
    local perf_extras=""
    is_true "$INSTALL_ZRAM"       && perf_extras+=", Zram"
    is_true "$INSTALL_IRQBALANCE" && perf_extras+=", irqbalance"
    is_true "$INSTALL_THERMALD"   && perf_extras+=", thermald"
    summary+="Performance: CPU=${INSTALL_CPU_GOVERNOR}, I/O=${INSTALL_IO_SCHEDULER}, Swappiness=${INSTALL_SWAPPINESS}${perf_extras}\n"
    summary+="Backup: ${INSTALL_BACKUP_SOLUTION}\n\n"
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        summary+="⏱️ Estimated time: 15-30 minutes\n"
        summary+="🔒 Keep this window open - don't close it!\n\n"
    fi
    
    summary+="Proceed with installation?"
    
    if ! wt_yesno "Installation Summary" "$summary" 28 75; then
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
    
    # Validate ROOT_DEVICE is set
    [[ -n $ROOT_DEVICE ]] || fail "ROOT_DEVICE not set, cannot create subvolumes"
    [[ -b $ROOT_DEVICE ]] || fail "ROOT_DEVICE ($ROOT_DEVICE) is not a block device"
    
    # Mount root device
    mount "$ROOT_DEVICE" /mnt || fail "Failed to mount $ROOT_DEVICE for subvolume creation"
    
    # Create subvolumes with error checking
    local subvol entry subvol_entries
    IFS=' ' read -ra subvol_entries <<< "$BTRFS_SUBVOLUMES"
    for entry in "${subvol_entries[@]}"; do
        subvol="${entry%%:*}"
        if [[ -n $subvol ]]; then
            if ! btrfs subvolume create "/mnt/${subvol}" >/dev/null 2>&1; then
                # Attempt cleanup before failing (cleanup failure is non-critical since we're already failing)
                if ! umount /mnt 2>/dev/null; then
                    log_error "Failed to unmount /mnt during error cleanup"
                fi
                fail "Failed to create Btrfs subvolume: ${subvol}"
            fi
        fi
    done
    
    # Unmount with error checking
    umount /mnt || fail "Failed to unmount /mnt after creating subvolumes"
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

update_mirrorlist() {
    [[ $INSTALL_MIRROR_REGION == "Skip" ]] && return
    
    log_step "Updating mirrorlist for ${INSTALL_MIRROR_REGION}"
    
    # Create backup of original mirrorlist
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    # Use reflector if available, otherwise use manual filtering
    if command -v reflector >/dev/null 2>&1; then
        local reflector_args=(--verbose --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist)
        
        case "$INSTALL_MIRROR_REGION" in
            "United States")
                reflector_args+=(--country "United States")
                ;;
            "Canada")
                reflector_args+=(--country Canada)
                ;;
            "United Kingdom")
                reflector_args+=(--country "United Kingdom")
                ;;
            "Germany")
                reflector_args+=(--country Germany)
                ;;
            "France")
                reflector_args+=(--country France)
                ;;
            "Australia")
                reflector_args+=(--country Australia)
                ;;
            "Japan")
                reflector_args+=(--country Japan)
                ;;
            "China")
                reflector_args+=(--country China)
                ;;
            "India")
                reflector_args+=(--country India)
                ;;
            "Brazil")
                reflector_args+=(--country Brazil)
                ;;
            "Worldwide"|*)
                # Use all countries for worldwide
                ;;
        esac
        
        reflector "${reflector_args[@]}" || {
            log_error "Reflector failed, keeping default mirrors"
            cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
        }
    else
        # Fallback: use simple awk-based filtering by region
        log_info "Reflector not available, using basic mirror filtering"
        
        # Extract mirrors for the selected region
        local search_term
        case "$INSTALL_MIRROR_REGION" in
            "United States") search_term="United States" ;;
            "Canada") search_term="Canada" ;;
            "United Kingdom") search_term="United Kingdom" ;;
            "Germany") search_term="Germany" ;;
            "France") search_term="France" ;;
            "Australia") search_term="Australia" ;;
            "Japan") search_term="Japan" ;;
            "China") search_term="China" ;;
            "India") search_term="India" ;;
            "Brazil") search_term="Brazil" ;;
            *) 
                # For Worldwide, use all mirrors
                return
                ;;
        esac
        
        # Uncomment mirrors matching the region (using index for safe substring search)
        if [[ -n $search_term ]]; then
            awk -v region="$search_term" '
                BEGIN { in_region=0 }
                /^## / && index($0, region) > 0 { in_region=1; print; next }
                /^##/ { in_region=0; print; next }
                /^#Server/ && in_region { sub(/^#/, ""); print; next }
                { print }
            ' /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist || {
                log_error "Mirror filtering failed, keeping default mirrors"
                cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
            }
        fi
    fi
}

get_desktop_packages() {
    # Returns package list for selected desktop environment
    local desktop="${1,,}"
    local packages=()
    
    case "$desktop" in
        gnome)
            packages=(gnome gnome-shell-extensions gdm gnome-console gnome-tweaks)
            ;;
        kde|plasma)
            packages=(plasma-desktop konsole dolphin sddm)
            ;;
        xfce)
            packages=(xfce4 xfce4-goodies lightdm lightdm-gtk-greeter)
            ;;
        cinnamon)
            packages=(cinnamon nemo gnome-terminal lightdm lightdm-slick-greeter)
            ;;
        mate)
            packages=(mate mate-extra lightdm lightdm-gtk-greeter)
            ;;
        budgie)
            packages=(budgie-desktop budgie-desktop-view gnome-terminal gdm)
            ;;
        lxqt)
            packages=(lxqt breeze-icons sddm)
            ;;
        sway)
            packages=(sway swayidle swaylock waybar foot grim slurp greetd tuigreet)
            ;;
        i3)
            packages=(i3-wm i3status i3lock dmenu lightdm lightdm-gtk-greeter)
            ;;
        none|*)
            packages=()
            ;;
    esac
    
    echo "${packages[@]}"
}

get_bundle_packages() {
    # Returns package list for a specific bundle
    local bundle="$1"
    local packages=()
    
    case "$bundle" in
        desktop-utilities)
            packages=(firefox chromium thunderbird vlc mpv celluloid libreoffice-fresh hunspell-en_us gnome-keyring seahorse keepassxc flatpak gnome-software-packagekit-plugin cups cups-pdf system-config-printer sane airscan printer-support brlaser simplescan)
            ;;
        dev)
            packages=(base-devel git github-cli clang gcc gdb lldb cmake ninja ccache go rustup nodejs npm yarn python python-pipx python-virtualenv docker docker-buildx docker-compose podman podman-docker buildah skopeo direnv just ripgrep fd neovim tmux starship)
            ;;
        gaming)
            packages=(steam lutris wine-staging winetricks gamemode lib32-gamemode mangohud lib32-mangohud goverlay vkbasalt lib32-vkbasalt pipewire wireplumber pipewire-alsa pipewire-pulse pipewire-jack)
            ;;
        server)
            packages=(openssh fail2ban ufw nftables cockpit cockpit-pcp cockpit-machines prometheus-node-exporter grafana-agent logrotate smartmontools hdparm lm_sensors)
            ;;
        cloud)
            packages=(ansible terraform packer kubectl helm k9s kind minikube aws-cli-v2 azure-cli google-cloud-cli podman podman-compose skopeo buildah direnv age sops jq yq)
            ;;
        creative)
            packages=(gimp krita inkscape blender darktable rawtherapee digikam kdenlive shotcut obs-studio ardour audacity calf lsp-plugins pipewire pipewire-alsa pipewire-pulse pipewire-jack helvum qpwgraph)
            ;;
        optimization)
            packages=(zram-generator irqbalance tlp tlp-rdw)
            ;;
        security)
            packages=(ufw clamav freshclam rkhunter apparmor firejail veracrypt keepassxc arch-audit usbguard)
            ;;
        networking)
            packages=(wireshark-qt wireshark-cli nmap tcpdump gnu-netcat mtr traceroute iftop nethogs bandwhich ethtool bind-tools inetutils net-tools iproute2 iperf3 speedtest-cli networkmanager networkmanager-openvpn network-manager-applet nm-connection-editor wireless_tools wpa_supplicant iwd bluez bluez-utils)
            ;;
        sysadmin)
            packages=(htop btop glances iotop sysstat dstat lsof strace ncdu dust duf gdu smartmontools hdparm testdisk ddrescue lvm2 cryptsetup rsync rclone tree tmux screen mc ranger fzf ripgrep fd bat exa timeshift rsnapshot restic borg etckeeper pacman-contrib reflector pkgfile downgrade stress s-tui cpupower)
            ;;
        *)
            packages=()
            ;;
    esac
    
    echo "${packages[@]}"
}

install_base_system() {
    log_step "Installing base system and user selections"
    
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

    # Add performance tuning packages based on user selections
    [[ "$INSTALL_CPU_GOVERNOR" != "skip" ]] && packages+=(cpupower)
    is_true "$INSTALL_ZRAM"       && packages+=(zram-generator)
    is_true "$INSTALL_IRQBALANCE" && packages+=(irqbalance)
    is_true "$INSTALL_THERMALD"   && packages+=(thermald)

    # Add backup solution packages
    case "$INSTALL_BACKUP_SOLUTION" in
        timeshift) packages+=(timeshift cronie) ;;
        snapper)   packages+=(snapper snap-pac) ;;
        restic)    packages+=(restic) ;;
        borg)      packages+=(borg borgmatic) ;;
        rsnapshot) packages+=(rsnapshot) ;;
    esac
    
    # Add desktop environment packages if selected
    if [[ $INSTALL_DESKTOP_CHOICE != "none" ]]; then
        local desktop_pkgs
        desktop_pkgs=$(get_desktop_packages "$INSTALL_DESKTOP_CHOICE")
        if [[ -n $desktop_pkgs ]]; then
            log_info "Including ${INSTALL_DESKTOP_CHOICE} desktop packages"
            read -ra desktop_array <<< "$desktop_pkgs"
            packages+=("${desktop_array[@]}")
        fi
    fi
    
    # Add bundle packages if selected
    if [[ ${#INSTALL_BUNDLE_CHOICES[@]} -gt 0 ]]; then
        log_info "Including ${#INSTALL_BUNDLE_CHOICES[@]} bundle package(s)"
        for bundle in "${INSTALL_BUNDLE_CHOICES[@]}"; do
            local bundle_pkgs
            bundle_pkgs=$(get_bundle_packages "$bundle")
            if [[ -n $bundle_pkgs ]]; then
                log_info "Including $bundle packages"
                read -ra bundle_array <<< "$bundle_pkgs"
                packages+=("${bundle_array[@]}")
            fi
        done
    fi
    
    # Show pacstrap output for visibility
    log_info "Installing ${#packages[@]} packages..."
    pacstrap -K /mnt "${packages[@]}"
}

generate_fstab() {
    log_step "Generating fstab"
    genfstab -U /mnt >> /mnt/etc/fstab
}

configure_system() {
    log_step "Configuring system"
    
    # Timezone
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/${INSTALL_TIMEZONE}" /etc/localtime
    arch-chroot /mnt hwclock --systohc || log_info "hwclock failed (normal in VMs/containers)"
    
    # Locale
    # Check if locale is already uncommented
    if ! grep -q "^${INSTALL_LOCALE} " /mnt/etc/locale.gen; then
        # Try to uncomment the locale if it exists as a commented line
        if grep -q "^#${INSTALL_LOCALE} " /mnt/etc/locale.gen; then
            sed -i "s/^#${INSTALL_LOCALE} /${INSTALL_LOCALE} /" /mnt/etc/locale.gen
        else
            # Locale doesn't exist at all, add it
            echo "${INSTALL_LOCALE} UTF-8" >> /mnt/etc/locale.gen
        fi
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
    
    # Configure sudo for wheel group using sudoers.d (safer than modifying /etc/sudoers directly)
    mkdir -p /mnt/etc/sudoers.d
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/10-wheel
    chmod 440 /mnt/etc/sudoers.d/10-wheel
    
    # NetworkManager
    arch-chroot /mnt systemctl enable NetworkManager >/dev/null 2>&1
    
    # Initramfs hooks
    local need_mkinit=false
    if is_true "$INSTALL_USE_LUKS"; then
        sed -i '/^HOOKS=/ s/\(block\)/\1 encrypt/' /mnt/etc/mkinitcpio.conf
        need_mkinit=true
    fi
    if is_true "$INSTALL_USE_LVM"; then
        sed -i '/^HOOKS=/ s/\(filesystems\)/lvm2 \1/' /mnt/etc/mkinitcpio.conf
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
        arch-chroot /mnt fallocate -l "${size_gb}G" /swapfile
    else
        arch-chroot /mnt fallocate -l "${size_gb}G" /swapfile
    fi
    
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
                sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /mnt/etc/default/grub
                # Add cryptdevice parameter before closing quote
                sed -i "/^GRUB_CMDLINE_LINUX=/ s/\"\$/cryptdevice=UUID=${CRYPT_UUID}:${INSTALL_LUKS_NAME}\"/" /mnt/etc/default/grub
                # Add space if there were existing params
                sed -i "/^GRUB_CMDLINE_LINUX=/ s/\(=.*[^ \"]\)cryptdevice/\1 cryptdevice/" /mnt/etc/default/grub
            fi
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
        fi
    else
        # GRUB on BIOS
        if is_true "$INSTALL_USE_LUKS"; then
            sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /mnt/etc/default/grub
            # Add cryptdevice parameter before closing quote
            sed -i "/^GRUB_CMDLINE_LINUX=/ s/\"\$/cryptdevice=UUID=${CRYPT_UUID}:${INSTALL_LUKS_NAME}\"/" /mnt/etc/default/grub
            # Add space if there were existing params
            sed -i "/^GRUB_CMDLINE_LINUX=/ s/\(=.*[^ \"]\)cryptdevice/\1 cryptdevice/" /mnt/etc/default/grub
        fi
        arch-chroot /mnt grub-install --target=i386-pc "${INSTALL_DISK}"
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    fi
}

configure_desktop() {
    [[ $INSTALL_DESKTOP_CHOICE == "none" ]] && return
    
    log_step "Configuring desktop environment: ${INSTALL_DESKTOP_CHOICE}"
    
    # Determine display manager based on desktop choice
    local display_manager=""
    case "${INSTALL_DESKTOP_CHOICE,,}" in
        gnome|budgie)
            display_manager="gdm"
            ;;
        kde|plasma|lxqt)
            display_manager="sddm"
            ;;
        xfce|cinnamon|mate|i3)
            display_manager="lightdm"
            ;;
        sway)
            display_manager="greetd"
            # Configure greetd for sway
            arch-chroot /mnt mkdir -p /etc/greetd
            if [[ ! -s /mnt/etc/greetd/config.toml ]]; then
                cat <<'EOF' > /mnt/etc/greetd/config.toml
[terminal]
shell = "/usr/bin/tuigreet"
args = ["--cmd", "sway"]
EOF
            fi
            ;;
    esac
    
    # Enable display manager
    if [[ -n $display_manager ]]; then
        log_info "Enabling ${display_manager} display manager"
        arch-chroot /mnt systemctl enable "$display_manager" >/dev/null 2>&1
    fi
}

configure_bundles() {
    [[ ${#INSTALL_BUNDLE_CHOICES[@]} -eq 0 ]] && return
    
    log_step "Configuring ${#INSTALL_BUNDLE_CHOICES[@]} software bundle(s)"
    
    for bundle in "${INSTALL_BUNDLE_CHOICES[@]}"; do
        log_info "Configuring bundle: ${bundle}"
        
        case "$bundle" in
            desktop-utilities)
                # Enable desktop services
                arch-chroot /mnt systemctl enable cups.socket >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable avahi-daemon.service >/dev/null 2>&1 || true
                ;;
            dev)
                # Enable container services
                arch-chroot /mnt systemctl enable docker.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable podman.socket >/dev/null 2>&1 || true
                log_info "Add user to docker group: usermod -aG docker ${INSTALL_USER}"
                ;;
            gaming)
                # Enable gaming services
                arch-chroot /mnt systemctl enable gamemoded.service >/dev/null 2>&1 || true
                ;;
            server)
                # Enable server services
                arch-chroot /mnt systemctl enable sshd.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable fail2ban.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable ufw.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable cockpit.socket >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable prometheus-node-exporter.service >/dev/null 2>&1 || true
                ;;
            cloud)
                # No post-configuration needed for cloud bundle
                ;;
            creative)
                # No post-configuration needed for creative bundle
                ;;
            optimization)
                # Configure optimization settings
                # Pacman config enhancements (parallel downloads, color, verbose, ILoveCandy)
                arch-chroot /mnt sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf || true
                arch-chroot /mnt sed -i 's/^#Color/Color/' /etc/pacman.conf || true
                arch-chroot /mnt sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf || true
                arch-chroot /mnt bash -c "grep -q 'ILoveCandy' /etc/pacman.conf || sed -i '/^VerbosePkgLists/a ILoveCandy' /etc/pacman.conf" || true

                # Enable TLP if laptop mode is enabled
                if [[ "$INSTALL_LAPTOP_MODE" == "true" ]]; then
                    log_info "Enabling TLP for laptop power management"
                    arch-chroot /mnt systemctl enable tlp.service >/dev/null 2>&1 || true
                    arch-chroot /mnt systemctl mask systemd-rfkill.service systemd-rfkill.socket >/dev/null 2>&1 || true
                fi
                ;;
            security)
                # Enable security services
                arch-chroot /mnt systemctl enable ufw.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable clamav-freshclam.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable apparmor.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable usbguard.service >/dev/null 2>&1 || true
                
                # Basic firewall config
                arch-chroot /mnt ufw default deny incoming >/dev/null 2>&1 || true
                arch-chroot /mnt ufw default allow outgoing >/dev/null 2>&1 || true
                arch-chroot /mnt ufw limit ssh >/dev/null 2>&1 || true
                arch-chroot /mnt ufw --force enable >/dev/null 2>&1 || true
                ;;
            networking)
                # Enable network services
                arch-chroot /mnt systemctl enable NetworkManager.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable bluetooth.service >/dev/null 2>&1 || true
                
                # Configure wireshark group
                arch-chroot /mnt groupadd -f wireshark >/dev/null 2>&1 || true
                ;;
            sysadmin)
                # Enable sysadmin services
                arch-chroot /mnt systemctl enable smartd.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable sysstat.service >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable reflector.timer >/dev/null 2>&1 || true
                
                # Initialize etckeeper
                arch-chroot /mnt bash -c 'if [[ ! -d /etc/.git ]]; then etckeeper init && etckeeper commit "Initial commit after installation"; fi' >/dev/null 2>&1 || true
                
                # Update pkgfile database
                arch-chroot /mnt pkgfile --update >/dev/null 2>&1 || true
                
                # Create reflector config
                arch-chroot /mnt mkdir -p /etc/xdg/reflector
                cat > /mnt/etc/xdg/reflector/reflector.conf <<'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--latest 10
--sort rate
EOF
                ;;
        esac
    done
}

install_aur_helper() {
    [[ $INSTALL_AUR_HELPER == "none" ]] && return
    
    local aur_script="${SCRIPT_DIR}/aur-helper.sh"
    [[ -f $aur_script ]] || {
        log_error "AUR helper script not found: ${aur_script}"
        return
    }
    
    log_step "Installing AUR helper: ${INSTALL_AUR_HELPER}"
    
    local target_path="/root/aur-helper-install.sh"
    cp "$aur_script" "/mnt${target_path}"
    chmod +x "/mnt${target_path}"
    
    # Run AUR helper installation with selected helper
    arch-chroot /mnt env "AUR_HELPER=${INSTALL_AUR_HELPER}" "INSTALL_USER=${INSTALL_USER}" "$target_path"
    
    # Clean up the copied script
    rm -f "/mnt${target_path}"
}

configure_performance_tuning() {
    log_step "Applying performance tuning settings"

    # CPU Governor via cpupower
    if [[ "$INSTALL_CPU_GOVERNOR" != "skip" ]]; then
        log_info "Setting CPU governor: ${INSTALL_CPU_GOVERNOR}"
        printf "governor='%s'\n" "${INSTALL_CPU_GOVERNOR}" > /mnt/etc/default/cpupower
        arch-chroot /mnt systemctl enable cpupower.service >/dev/null 2>&1 || true
    fi

    # I/O Scheduler via udev rules
    if [[ "$INSTALL_IO_SCHEDULER" != "skip" ]]; then
        log_info "Setting I/O scheduler: ${INSTALL_IO_SCHEDULER}"
        mkdir -p /mnt/etc/udev/rules.d
        cat > /mnt/etc/udev/rules.d/60-ioschedulers.rules <<EOF
# Set ${INSTALL_IO_SCHEDULER} scheduler for NVMe and SSDs
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="${INSTALL_IO_SCHEDULER}"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="${INSTALL_IO_SCHEDULER}"
# Set BFQ for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
    fi

    # Swappiness
    log_info "Setting vm.swappiness=${INSTALL_SWAPPINESS}"
    arch-chroot /mnt bash -c "mkdir -p /etc/sysctl.d && printf 'vm.swappiness=%s\n' '${INSTALL_SWAPPINESS}' > /etc/sysctl.d/99-swappiness.conf"

    # Zram compressed swap
    if is_true "$INSTALL_ZRAM"; then
        log_info "Configuring zram compressed swap"
        cat > /mnt/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
    fi

    # SSD TRIM (always beneficial for SSD/NVMe users)
    arch-chroot /mnt systemctl enable fstrim.timer >/dev/null 2>&1 || true

    # irqbalance - distribute hardware interrupts across CPU cores
    if is_true "$INSTALL_IRQBALANCE"; then
        log_info "Enabling irqbalance"
        arch-chroot /mnt systemctl enable irqbalance.service >/dev/null 2>&1 || true
    fi

    # thermald - Intel thermal management
    if is_true "$INSTALL_THERMALD"; then
        log_info "Enabling thermald"
        arch-chroot /mnt systemctl enable thermald.service >/dev/null 2>&1 || true
    fi
}

configure_backup_solution() {
    [[ "$INSTALL_BACKUP_SOLUTION" == "none" ]] && return

    log_step "Configuring backup solution: ${INSTALL_BACKUP_SOLUTION}"

    case "$INSTALL_BACKUP_SOLUTION" in
        timeshift)
            # Enable cronie for scheduled Timeshift snapshots
            arch-chroot /mnt systemctl enable cronie.service >/dev/null 2>&1 || true
            log_info "Timeshift installed - run 'timeshift-gtk' (GUI) or 'timeshift --help' after first boot"
            ;;
        snapper)
            if [[ "$INSTALL_FILESYSTEM" == "btrfs" ]]; then
                # Create snapper config for root
                # If @snapshots subvolume was set up, /.snapshots is already a mount point
                # and snapper's create-config must not recreate it - pass --no-dbus flag
                arch-chroot /mnt bash -c "
                    if mountpoint -q /.snapshots 2>/dev/null; then
                        # .snapshots is a separate subvolume mount; create config without recreating the dir
                        snapper --no-dbus -c root create-config / >/dev/null 2>&1 || true
                    else
                        snapper -c root create-config / >/dev/null 2>&1 || true
                    fi
                "
                # Enable automatic snapshot timers
                arch-chroot /mnt systemctl enable snapper-timeline.timer >/dev/null 2>&1 || true
                arch-chroot /mnt systemctl enable snapper-cleanup.timer >/dev/null 2>&1 || true
                log_info "Snapper configured for Btrfs root with automatic timeline snapshots"
                log_info "snap-pac will create pre/post snapshots on pacman operations"
            else
                # Snapper has limited ext4 support; notify the user to configure manually
                log_info "Snapper installed (ext4 support is limited - manual configuration required)"
                log_info "Run 'snapper -c root create-config /' after first boot to configure"
            fi
            ;;
        restic)
            log_info "Restic installed - initialize a repository after first boot"
            log_info "Example: restic -r /mnt/backup init && restic -r /mnt/backup backup /home"
            ;;
        borg)
            # Create a sample borgmatic configuration using direct file write
            arch-chroot /mnt mkdir -p /etc/borgmatic.d
            cat > /mnt/etc/borgmatic.d/config.yaml <<'EOF'
location:
    source_directories:
        - /home
        - /etc
    repositories:
        - /backup/borg
retention:
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 6
EOF
            log_info "Borg + Borgmatic installed with sample config at /etc/borgmatic.d/config.yaml"
            log_info "Initialize a repo with: borg init --encryption=repokey /backup/borg"
            ;;
        rsnapshot)
            # Set a sensible snapshot root - handle both tab and space separators in rsnapshot.conf
            arch-chroot /mnt bash -c "sed -i 's|^snapshot_root[[:space:]].*|snapshot_root\t/backup/rsnapshot/|' /etc/rsnapshot.conf" >/dev/null 2>&1 || true
            log_info "rsnapshot installed - customize /etc/rsnapshot.conf then test with: rsnapshot configtest"
            ;;
    esac
}

perform_cleanup() {
    # Common cleanup logic for both error and success cases
    local show_error="${1:-false}"
    
    if [[ $show_error == true ]] && [[ $MOUNTED == true ]]; then
        log_error "Installation failed or interrupted - cleaning up..."
    fi
    
    if [[ $MOUNTED == true ]]; then
        umount -R /mnt 2>/dev/null || true
        MOUNTED=false
    fi
    if is_true "$INSTALL_USE_LVM"; then
        vgchange -an "$INSTALL_VG_NAME" >/dev/null 2>&1 || true
    fi
    if [[ $OPENED_LUKS == true ]]; then
        cryptsetup close "$CRYPT_DEVICE_NAME" >/dev/null 2>&1 || true
        OPENED_LUKS=false
    fi
}

cleanup() {
    # This cleanup runs on EXIT trap (errors, interrupts, etc.)
    # Successful installation already cleaned up explicitly and set MOUNTED=false
    # So if MOUNTED is still true here, something went wrong
    perform_cleanup true
}

# --- Main Installation Flow -------------------------------------------------
main() {
    require_root
    
    # Check for gum TUI
    log_step "Checking for gum TUI..."
    if ! check_gum; then
        log_info "gum not found, installing automatically..."
        if ! install_gum; then
            fail_early "Failed to install gum TUI tool. Please install it manually with: pacman -S gum"
        fi
        # Verify installation
        if ! check_gum; then
            fail_early "gum installation completed but gum command not found. Please check your PATH."
        fi
    fi
    log_info "Using gum TUI"
    
    # TUI is now available
    TUI_AVAILABLE=true
    
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
    show_requirements_checklist
    show_hardware_summary
    select_laptop_mode
    
    select_disk
    select_filesystem
    select_layout
    select_encryption
    configure_system_settings
    configure_users
    select_mirror_region
    select_desktop
    select_bundles
    select_aur_helper
    select_performance_tuning
    select_backup_solution
    
    # Finalize boot configuration
    BOOT_MODE=$(resolve_boot_mode "$DETECTED_BOOT_MODE")
    SELECTED_BOOTLOADER=$(resolve_bootloader "$BOOT_MODE")
    
    show_installation_summary
    
    TARGET_DISK="$INSTALL_DISK"
    PART_SUFFIX=$(partition_suffix_for "$TARGET_DISK")
    
    trap cleanup EXIT
    
    # Installation progress with enhanced TUI progress bars
    log_step "Starting installation process..."
    
    (
        echo "0" ; echo "XXX"
        echo "Partitioning disk..."
        echo "Creating partition table and partitions on ${TARGET_DISK}"
        echo "XXX"
        partition_disk "$TARGET_DISK"
        
        echo "5" ; echo "XXX"
        echo "Formatting boot partition..."
        echo "Creating boot filesystem"
        echo "XXX"
        format_boot_partition
        
        echo "10" ; echo "XXX"
        echo "Setting up encryption..."
        if is_true "$INSTALL_USE_LUKS"; then
            echo "Configuring LUKS encryption for security"
        else
            echo "Skipping encryption (not enabled)"
        fi
        echo "XXX"
        setup_luks_container
        
        echo "15" ; echo "XXX"
        echo "Configuring storage..."
        if is_true "$INSTALL_USE_LVM"; then
            echo "Setting up LVM volumes"
        else
            echo "Using standard partitioning"
        fi
        echo "XXX"
        setup_storage_stack
        
        echo "20" ; echo "XXX"
        echo "Formatting filesystems..."
        echo "Creating ${INSTALL_FILESYSTEM} filesystem(s)"
        echo "XXX"
        format_filesystems
        
        if [[ $INSTALL_FILESYSTEM == "btrfs" && $INSTALL_LAYOUT == "btrfs-subvols" ]]; then
            echo "25" ; echo "XXX"
            echo "Preparing Btrfs subvolumes..."
            echo "Creating @, @home, @var_log, @var_cache, @snapshots"
            echo "XXX"
            prepare_btrfs_subvolumes
        fi
        
        echo "30" ; echo "XXX"
        echo "Mounting filesystems..."
        echo "Mounting all partitions to /mnt"
        echo "XXX"
        mount_filesystems
        
        echo "32" ; echo "XXX"
        echo "Updating package mirrors..."
        echo "Configuring mirrors for ${INSTALL_MIRROR_REGION}"
        echo "XXX"
        update_mirrorlist
        
        echo "35" ; echo "XXX"
        echo "Installing base system and selected packages..."
        echo "This will take several minutes - installing system, desktop, and bundles"
        echo "XXX"
        install_base_system 2>&1 >/dev/null || true
        
        echo "75" ; echo "XXX"
        echo "Generating fstab..."
        echo "Creating filesystem table configuration"
        echo "XXX"
        generate_fstab
        
        echo "77" ; echo "XXX"
        echo "Configuring system..."
        echo "Setting up timezone, locale, hostname, and users"
        echo "XXX"
        configure_system

        echo "79" ; echo "XXX"
        echo "Applying performance tuning..."
        echo "CPU governor, I/O scheduler, swappiness, zram"
        echo "XXX"
        configure_performance_tuning

        echo "81" ; echo "XXX"
        echo "Creating swapfile..."
        echo "Setting up swap space for memory management"
        echo "XXX"
        setup_swapfile
        
        echo "81" ; echo "XXX"
        echo "Installing bootloader..."
        echo "Configuring ${SELECTED_BOOTLOADER} for ${BOOT_MODE^^} mode"
        echo "XXX"
        setup_bootloader
        
        if [[ $INSTALL_DESKTOP_CHOICE != "none" ]]; then
            echo "85" ; echo "XXX"
            echo "Configuring desktop environment..."
            echo "Enabling ${INSTALL_DESKTOP_CHOICE} desktop services"
            echo "XXX"
            configure_desktop
        fi
        
        if [[ ${#INSTALL_BUNDLE_CHOICES[@]} -gt 0 ]]; then
            echo "90" ; echo "XXX"
            echo "Configuring bundles..."
            echo "Setting up ${#INSTALL_BUNDLE_CHOICES[@]} bundle service(s)"
            echo "XXX"
            configure_bundles
        fi

        if [[ $INSTALL_BACKUP_SOLUTION != "none" ]]; then
            echo "93" ; echo "XXX"
            echo "Configuring backup solution..."
            echo "Setting up ${INSTALL_BACKUP_SOLUTION} backup"
            echo "XXX"
            configure_backup_solution
        fi
        
        if [[ $INSTALL_AUR_HELPER != "none" ]]; then
            echo "95" ; echo "XXX"
            echo "Installing AUR helper..."
            echo "Setting up ${INSTALL_AUR_HELPER} for AUR package access"
            echo "XXX"
            install_aur_helper 2>&1 >/dev/null || true
        fi
        
        echo "100" ; echo "XXX"
        echo "Installation complete!"
        echo "All tasks completed successfully"
        echo "XXX"
    ) | wt_gauge "Arch Linux Installation Progress" "Initializing..." 12 75
    
    log_step "Installation completed successfully!"
    
    # Cleanup before showing completion message
    log_step "Unmounting filesystems..."
    perform_cleanup false
    
    # Success message
    local success_msg=""
    
    if [[ "$BEGINNER_MODE" == "true" ]]; then
        success_msg="🎉 Congratulations! Installation Complete!\n\n"
        success_msg+="Your Arch Linux system is ready to use!\n\n"
        success_msg+="System configuration:\n"
        success_msg+="• Hostname: ${INSTALL_HOSTNAME}\n"
        success_msg+="• User: ${INSTALL_USER}\n"
        success_msg+="• Desktop: ${INSTALL_DESKTOP_CHOICE}\n\n"
        success_msg+="📝 NEXT STEPS:\n\n"
        success_msg+="1. Remove the USB/DVD installation media\n"
        success_msg+="2. Reboot your computer\n"
        success_msg+="3. Log in with your username and password\n"
        success_msg+="4. Enjoy your new Arch Linux system!\n\n"
        success_msg+="💡 TIP: After first login, run 'sudo pacman -Syu'\n"
        success_msg+="to check for system updates."
    else
        success_msg="Installation completed successfully!\n\n"
        success_msg+="System configuration:\n"
        success_msg+="• Hostname: ${INSTALL_HOSTNAME}\n"
        success_msg+="• User: ${INSTALL_USER}\n"
        success_msg+="• Desktop: ${INSTALL_DESKTOP_CHOICE}\n\n"
        success_msg+="The system is ready to boot.\n"
        success_msg+="Remove the installation media before rebooting."
    fi
    
    wt_msgbox "Installation Complete" "$success_msg" 22 75 || true
    
    # Ask user if they want to reboot now
    if wt_yesno "Reboot System" "Would you like to reboot now?\n\nMake sure to remove the installation media." 10 60; then
        log_step "Rebooting system..."
        sleep 2
        reboot
    else
        wt_msgbox "Manual Reboot" "Remember to reboot your system when ready:\n\n  reboot\n\nRemove the installation media before rebooting." 12 60 || true
    fi
}

# --- Entry Point -------------------------------------------------------------
main "$@"
