#!/usr/bin/env bash
# Modular Arch Linux installer script with basic auto-detection.
# Run from an Arch ISO live session with networking enabled.

set -euo pipefail
IFS=$'\n\t'

# --- User-tweakable defaults -------------------------------------------------
: "${INSTALL_DISK:=}"                           # e.g. /dev/nvme0n1. Leave empty for auto-pick.
: "${INSTALL_HOSTNAME:=archlinux}"              # Hostname for the new system.
: "${INSTALL_TIMEZONE:=UTC}"                    # Timezone name from /usr/share/zoneinfo.
: "${INSTALL_LOCALE:=en_US.UTF-8}"              # Locale to enable during install.
: "${INSTALL_KEYMAP:=us}"                       # Console keymap.
: "${INSTALL_ROOT_PASSWORD:=changeme}"          # Root password; change after install.
: "${INSTALL_USER:=archer}"                     # Non-root user to create.
: "${INSTALL_USER_PASSWORD:=changeme}"          # Password for the user above.
: "${INSTALL_PACKAGES:=nano vim git networkmanager}" # Extra packages to install.
: "${INSTALL_FILESYSTEM:=ext4}"                 # Supported: ext4, btrfs.
: "${INSTALL_USE_LVM:=false}"                   # true to place root on LVM.
: "${INSTALL_VG_NAME:=archvg}"                  # Volume group name when LVM is enabled.
: "${INSTALL_LV_ROOT_NAME:=root}"               # Logical volume name for the root filesystem.
: "${INSTALL_LV_HOME_NAME:=home}"               # Logical volume for /home when using split layout.
: "${INSTALL_LV_ROOT_SIZE:=70%FREE}"            # Root LV size when using split layout.
: "${INSTALL_LV_HOME_SIZE:=100%FREE}"           # Home LV size when using split layout.
: "${BTRFS_MOUNT_OPTS:=compress=zstd,autodefrag}" # Mount options applied when using Btrfs.
: "${BTRFS_SUBVOL_PROFILE:=standard}"           # Btrfs subvolume preset (standard|minimal|server|custom).
: "${INSTALL_LAYOUT:=single}"                   # Layout preset: single, btrfs-subvols, lvm-home.
: "${BTRFS_SUBVOLUMES:=@:/ @home:/home @var_log:/var/log @var_cache:/var/cache @snapshots:/.snapshots}" # name:mountpoint pairs.
: "${NETWORK_BOOTSTRAP_ENABLE:=false}"          # true to configure networking from the script.
: "${NETWORK_TYPE:=wifi}"                       # wifi, ethernet, or static.
: "${NETWORK_INTERFACE:=}"                      # Optional interface (e.g., wlan0).
: "${NETWORK_WIFI_SSID:=}"                      # SSID for wifi bootstrap.
: "${NETWORK_WIFI_PSK:=}"                       # Pre-shared key for wifi bootstrap.
: "${NETWORK_STATIC_IP:=}"                      # Static IP in CIDR (e.g., 192.168.1.50/24).
: "${NETWORK_STATIC_GATEWAY:=}"                 # Static gateway address.
: "${NETWORK_STATIC_DNS:=8.8.8.8}"              # DNS servers for static config.
: "${INSTALL_USE_LUKS:=false}"                  # Encrypt root partition with LUKS.
: "${INSTALL_LUKS_NAME:=cryptroot}"             # Name for the opened LUKS mapper device.
: "${INSTALL_LUKS_CIPHER:=aes-xts-plain64}"     # Cipher passed to cryptsetup.
: "${INSTALL_LUKS_KEY_SIZE:=512}"               # Key size in bits.
: "${INSTALL_LUKS_HASH:=sha512}"                # Hash function for cryptsetup.
: "${INSTALL_LUKS_PASSPHRASE:=}"                # Optional inline passphrase (use with caution).
: "${INSTALL_LUKS_PASSFILE:=}"                  # Path to a file containing the passphrase.
: "${INSTALL_LUKS_PROMPT:=true}"                # Prompt for passphrase if none provided.
: "${INSTALL_BOOT_MODE:=auto}"                  # auto, uefi, bios.
: "${INSTALL_BOOTLOADER:=auto}"                # auto, systemd-boot, grub.
: "${INSTALL_DESKTOP_PROMPT:=true}"             # Prompt to install a desktop inside the target system.
: "${INSTALL_DESKTOP_CHOICE:=}"                 # Pre-select desktop (none, gnome, kde, xfce, sway).
: "${INSTALL_DESKTOP_SCRIPT:=install-desktop.sh}" # Path to install-desktop helper script.
: "${INSTALL_DESKTOP_EXTRAS:=}"                 # Extra packages passed to the desktop script.
: "${INSTALL_POST_SCRIPT:=}"                   # Optional post-install provisioning script.
: "${INSTALL_POST_SCRIPT_ARGS:=}"              # Space-delimited args for the provisioning script.
: "${INSTALL_BUNDLE_DIR:=bundles}"             # Directory containing bundle scripts.
: "${INSTALL_BUNDLE_PROMPT:=false}"            # Prompt to choose a bundle when available.
: "${INSTALL_BUNDLE_CHOICE:=}"                 # Pre-select bundle by name or number.
: "${INSTALL_BUNDLE_ARGS:=}"                   # Args for the selected bundle when post-script args are unset.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH_MIRROR="https://mirror.rackspace.com/archlinux"
REQUIRED_TOOLS=(lsblk awk sed grep parted sgdisk mkfs.fat mkfs.ext4 cryptsetup pacstrap genfstab arch-chroot timedatectl lspci ping systemd-detect-virt blkid)
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
BTRFS_SUBVOL_SET=""
HOME_DEVICE=""
MICROCODE=""
MICROCODE_IMG=""
GPU_DRIVER=""

# --- Logging helpers ---------------------------------------------------------
log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }
log_error() { printf 'ERROR: %s\n' "$1" >&2; }
fail() { log_error "$1"; exit 1; }

# --- Guardrails --------------------------------------------------------------
require_root() { [[ ${EUID} -eq 0 ]] || fail "Run this installer as root."; }

ensure_commands() {
  local missing=()
  for bin in "${REQUIRED_TOOLS[@]}"; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  [[ ${#missing[@]} -eq 0 ]] || fail "Missing required tools: ${missing[*]}"
}

require_online() {
  ping -c 1 archlinux.org >/dev/null 2>&1 || fail "Network unreachable."
}

is_true() {
  local value="${1:-}"
  [[ "${value,,}" == "true" ]]
}

get_luks_passphrase() {
  if [[ -n $INSTALL_LUKS_PASSPHRASE ]]; then
    printf '%s' "$INSTALL_LUKS_PASSPHRASE"
    return
  fi
  if [[ -n $INSTALL_LUKS_PASSFILE ]]; then
    [[ -r $INSTALL_LUKS_PASSFILE ]] || fail "LUKS passfile '${INSTALL_LUKS_PASSFILE}' not readable."
    cat "$INSTALL_LUKS_PASSFILE"
    return
  fi
  if is_true "$INSTALL_LUKS_PROMPT"; then
    local pass1 pass2
    while true; do
      read -rsp "Enter LUKS passphrase: " pass1; echo
      read -rsp "Confirm LUKS passphrase: " pass2; echo
      if [[ -n $pass1 && $pass1 == "$pass2" ]]; then
        printf '%s' "$pass1"
        unset pass1 pass2
        return
      fi
      echo "Passphrases did not match. Try again."
    done
  fi
  fail "No LUKS passphrase provided. Set INSTALL_LUKS_PASSPHRASE, INSTALL_LUKS_PASSFILE, or enable prompts."
}

setup_luks_container() {
  if ! is_true "$INSTALL_USE_LUKS"; then
    ENCRYPTED_DEVICE="$PART_ROOT"
    return
  fi
  log_step "Configuring LUKS container (${INSTALL_LUKS_NAME})"
  local passphrase
  passphrase=$(get_luks_passphrase)
  printf '%s' "$passphrase" | cryptsetup luksFormat "$PART_ROOT" --batch-mode --cipher "$INSTALL_LUKS_CIPHER" --key-size "$INSTALL_LUKS_KEY_SIZE" --hash "$INSTALL_LUKS_HASH"
  printf '%s' "$passphrase" | cryptsetup open "$PART_ROOT" "$INSTALL_LUKS_NAME"
  unset passphrase
  ENCRYPTED_DEVICE="/dev/mapper/${INSTALL_LUKS_NAME}"
  OPENED_LUKS=true
  CRYPT_DEVICE_NAME="$INSTALL_LUKS_NAME"
  CRYPT_UUID=$(blkid -s UUID -o value "$PART_ROOT")
}

resolve_btrfs_subvolumes() {
  case "${BTRFS_SUBVOL_PROFILE,,}" in
    minimal) echo "@:/ @home:/home" ;;
    server) echo "@:/ @home:/home @var:/var @var_log:/var/log @srv:/srv @snapshots:/.snapshots" ;;
    standard|default|"") echo "@:/ @home:/home @var_log:/var/log @var_cache:/var/cache @snapshots:/.snapshots" ;;
    custom) echo "$BTRFS_SUBVOLUMES" ;;
    *)
      log_error "Unknown BTRFS_SUBVOL_PROFILE '${BTRFS_SUBVOL_PROFILE}', defaulting to custom list."
      echo "$BTRFS_SUBVOLUMES"
      ;;
  esac
}

bootstrap_networking() {
  is_true "$NETWORK_BOOTSTRAP_ENABLE" || return
  command -v nmcli >/dev/null 2>&1 || fail "nmcli is required for network bootstrapping."
  log_step "Bootstrapping network (${NETWORK_TYPE})"
  systemctl start NetworkManager >/dev/null 2>&1 || true
  case "${NETWORK_TYPE,,}" in
    wifi)
      [[ -n $NETWORK_WIFI_SSID && -n $NETWORK_WIFI_PSK ]] || fail "NETWORK_WIFI_SSID and NETWORK_WIFI_PSK must be set for wifi bootstrap."
      if [[ -n $NETWORK_INTERFACE ]]; then
        nmcli device wifi connect "$NETWORK_WIFI_SSID" password "$NETWORK_WIFI_PSK" ifname "$NETWORK_INTERFACE"
      else
        nmcli device wifi connect "$NETWORK_WIFI_SSID" password "$NETWORK_WIFI_PSK"
      fi
      ;;
    ethernet)
      if [[ -n $NETWORK_INTERFACE ]]; then
        nmcli device set "$NETWORK_INTERFACE" managed yes
        nmcli device connect "$NETWORK_INTERFACE"
      else
        nmcli networking on
      fi
      ;;
    static)
      [[ -n $NETWORK_INTERFACE && -n $NETWORK_STATIC_IP && -n $NETWORK_STATIC_GATEWAY ]] || fail "Static networking requires NETWORK_INTERFACE, NETWORK_STATIC_IP, and NETWORK_STATIC_GATEWAY."
      local con_name="install-static"
      if nmcli -t -f NAME connection show | grep -qx "$con_name"; then
        nmcli connection delete "$con_name"
      fi
      nmcli connection add type ethernet ifname "$NETWORK_INTERFACE" con-name "$con_name" autoconnect yes ip4 "$NETWORK_STATIC_IP" gw4 "$NETWORK_STATIC_GATEWAY"
      nmcli connection modify "$con_name" ipv4.dns "$NETWORK_STATIC_DNS" ipv4.method manual ipv4.may-fail no
      nmcli connection up "$con_name"
      ;;
    *)
      fail "Unknown NETWORK_TYPE: ${NETWORK_TYPE}."
      ;;
  esac
}

prompt_desktop_selection() {
  local prompt="Install desktop environment now? (none/gnome/kde/xfce/sway) [none]: "
  local response
  read -r -p "$prompt" response || true
  response=${response:-none}
  echo "${response,,}"
}

resolve_desktop_script() {
  local candidate="$INSTALL_DESKTOP_SCRIPT"
  if [[ -z $candidate ]]; then
    echo ""
    return
  fi
  if [[ -f $candidate ]]; then
    printf '%s\n' "$candidate"
    return
  fi
  if [[ -f "$SCRIPT_DIR/$candidate" ]]; then
    printf '%s\n' "$SCRIPT_DIR/$candidate"
    return
  fi
  echo ""
}

resolve_post_install_script() {
  local candidate="$INSTALL_POST_SCRIPT"
  if [[ -z $candidate ]]; then
    echo ""
    return
  fi
  if [[ -f $candidate ]]; then
    printf '%s\n' "$candidate"
    return
  fi
  if [[ -f "$SCRIPT_DIR/$candidate" ]]; then
    printf '%s\n' "$SCRIPT_DIR/$candidate"
    return
  fi
  echo ""
}

resolve_bundle_dir() {
  local dir="$INSTALL_BUNDLE_DIR"
  if [[ -z $dir ]]; then
    echo ""
    return
  fi
  if [[ -d $dir ]]; then
    printf '%s\n' "$dir"
    return
  fi
  if [[ -d "$SCRIPT_DIR/$dir" ]]; then
    printf '%s\n' "$SCRIPT_DIR/$dir"
    return
  fi
  echo ""
}

maybe_install_desktop() {
  local choice="${INSTALL_DESKTOP_CHOICE,,}"
  if [[ -z $choice ]] && is_true "$INSTALL_DESKTOP_PROMPT"; then
    choice=$(prompt_desktop_selection)
  fi
  choice=${choice:-none}
  if [[ $choice == "none" ]]; then
    log_info "Desktop install skipped."
    return
  fi
  case "$choice" in
    gnome|kde|xfce|sway) ;;
    none) return ;;
    *)
      log_error "Unknown desktop option '${choice}'. Skipping desktop installation."
      return
      ;;
  esac
  local script_path
  script_path=$(resolve_desktop_script)
  if [[ -z $script_path ]]; then
    log_error "Desktop script '${INSTALL_DESKTOP_SCRIPT}' not found. Skipping desktop installation."
    return
  fi
  local target_path="/root/$(basename "$script_path")"
  log_step "Copying desktop installer to target (${script_path} -> ${target_path})"
  mkdir -p "/mnt$(dirname "$target_path")"
  cp "$script_path" "/mnt${target_path}"
  chmod +x "/mnt${target_path}"
  local env_args=(DESKTOP_ENV="$choice")
  if [[ -n ${INSTALL_DESKTOP_EXTRAS// /} ]]; then
    env_args+=(DESKTOP_EXTRAS="$INSTALL_DESKTOP_EXTRAS")
  fi
  log_step "Running desktop installer (${choice})"
  arch-chroot /mnt /usr/bin/env "${env_args[@]}" "$target_path" || log_error "Desktop installation failed (choice: ${choice})."
}

run_post_install_script() {
  local script_path
  script_path=$(resolve_post_install_script)
  if [[ -z $script_path ]]; then
    if [[ -n $INSTALL_POST_SCRIPT ]]; then
      log_error "Post-install script '${INSTALL_POST_SCRIPT}' not found."
    fi
    return
  fi
  local target_path="/root/$(basename "$script_path")"
  log_step "Copying post-install script (${script_path} -> ${target_path})"
  mkdir -p "/mnt$(dirname "$target_path")"
  cp "$script_path" "/mnt${target_path}"
  chmod +x "/mnt${target_path}"
  local args=()
  if [[ -n ${INSTALL_POST_SCRIPT_ARGS// /} ]]; then
    read -ra args <<< "$INSTALL_POST_SCRIPT_ARGS"
  fi
  log_step "Running post-install script"
  if ! arch-chroot /mnt "$target_path" "${args[@]}"; then
    log_error "Post-install script failed (path: ${script_path})."
  fi
}

select_bundle_script() {
  [[ -z $INSTALL_POST_SCRIPT ]] || return
  local dir
  dir=$(resolve_bundle_dir)
  [[ -n $dir ]] || return
  local -a bundle_paths
  mapfile -t bundle_paths < <(find "$dir" -maxdepth 1 -type f -name '*.sh' -print 2>/dev/null | sort)
  local count=${#bundle_paths[@]}
  [[ $count -gt 0 ]] || return

  local choice="$INSTALL_BUNDLE_CHOICE"
  if [[ -z $choice ]]; then
    if ! is_true "$INSTALL_BUNDLE_PROMPT"; then
      return
    fi
    log_step "Available bundle scripts"
    local idx
    for idx in "${!bundle_paths[@]}"; do
      log_info "$((idx + 1)). $(basename "${bundle_paths[$idx]}")"
    done
    read -r -p "Select bundle (name/number/none) [none]: " choice || true
  fi
  choice=${choice:-none}
  if [[ ${choice,,} == none ]]; then
    return
  fi

  local selected=""
  if [[ $choice =~ ^[0-9]+$ ]]; then
    local num=$((choice - 1))
    if (( num >= 0 && num < count )); then
      selected="${bundle_paths[$num]}"
    fi
  fi
  if [[ -z $selected ]]; then
    local lowered_choice=${choice,,}
    local path
    for path in "${bundle_paths[@]}"; do
      local base=$(basename "$path")
      if [[ ${base,,} == $lowered_choice ]]; then
        selected="$path"
        break
      fi
    done
  fi
  if [[ -z $selected ]]; then
    log_error "Bundle selection '${choice}' not found under ${dir}."
    return
  fi
  INSTALL_POST_SCRIPT="$selected"
  if [[ -z ${INSTALL_POST_SCRIPT_ARGS// /} && -n ${INSTALL_BUNDLE_ARGS// /} ]]; then
    INSTALL_POST_SCRIPT_ARGS="$INSTALL_BUNDLE_ARGS"
  fi
  log_info "Selected bundle script: $(basename "$selected")"
}

validate_storage_inputs() {
  case "$FILESYSTEM_TYPE" in
    ext4|btrfs) ;;
    *) fail "Unsupported filesystem: ${INSTALL_FILESYSTEM}. Choose ext4 or btrfs." ;;
  esac
  case "${INSTALL_LAYOUT,,}" in
    single) ;;
    btrfs-subvols)
      [[ $FILESYSTEM_TYPE == "btrfs" ]] || fail "INSTALL_LAYOUT=btrfs-subvols requires INSTALL_FILESYSTEM=btrfs."
      is_true "$INSTALL_USE_LVM" && fail "INSTALL_LAYOUT=btrfs-subvols is incompatible with INSTALL_USE_LVM=true."
      ;;
    lvm-home)
      is_true "$INSTALL_USE_LVM" || fail "INSTALL_LAYOUT=lvm-home requires INSTALL_USE_LVM=true."
      ;;
    *)
      fail "Unknown INSTALL_LAYOUT preset: ${INSTALL_LAYOUT}."
      ;;
  esac
  if [[ $FILESYSTEM_TYPE == "btrfs" ]]; then
    for bin in mkfs.btrfs btrfs; do
      command -v "$bin" >/dev/null 2>&1 || fail "Required tool '$bin' not found for Btrfs installs."
    done
  fi
  if [[ ${INSTALL_LAYOUT,,} == "btrfs-subvols" ]]; then
    BTRFS_SUBVOL_SET=$(resolve_btrfs_subvolumes)
    [[ -n $BTRFS_SUBVOL_SET ]] || fail "BTRFS subvolume list is empty."
    read -ra _subvol_entries <<< "$BTRFS_SUBVOL_SET"
    local first_target=${_subvol_entries[0]#*:}
    [[ $first_target == "/" ]] || fail "First BTRFS subvolume entry must mount at /."
    unset _subvol_entries
  fi
  if is_true "$INSTALL_USE_LVM"; then
    [[ -n $INSTALL_VG_NAME && -n $INSTALL_LV_ROOT_NAME ]] || fail "INSTALL_VG_NAME and INSTALL_LV_ROOT_NAME must be set when INSTALL_USE_LVM=true."
    for bin in pvcreate vgcreate lvcreate vgchange; do
      command -v "$bin" >/dev/null 2>&1 || fail "Required tool '$bin' not found for LVM installs."
    done
  fi
  if is_true "$INSTALL_USE_LUKS"; then
    command -v cryptsetup >/dev/null 2>&1 || fail "cryptsetup is required for LUKS installs."
    [[ -n $INSTALL_LUKS_NAME ]] || fail "INSTALL_LUKS_NAME cannot be empty when encryption is enabled."
  fi
}

# --- Hardware detection ------------------------------------------------------
detect_boot_mode() { [[ -d /sys/firmware/efi/efivars ]] && echo uefi || echo bios; }

resolve_boot_mode() {
  local detected="$1" requested="${INSTALL_BOOT_MODE,,}"
  case "$requested" in
    auto|"")
      echo "$detected"
      ;;
    uefi)
      [[ $detected == "uefi" ]] || fail "INSTALL_BOOT_MODE=uefi requested but firmware is in BIOS mode."
      echo "uefi"
      ;;
    bios|legacy)
      if [[ $detected == "uefi" ]]; then
        log_info "Firmware is UEFI but INSTALL_BOOT_MODE=${INSTALL_BOOT_MODE} requested; proceeding with legacy GRUB."
      fi
      echo "bios"
      ;;
    *)
      fail "Unknown INSTALL_BOOT_MODE '${INSTALL_BOOT_MODE}'. Use auto, uefi, or bios."
      ;;
  esac
}

resolve_bootloader() {
  local boot_mode="$1" requested="${INSTALL_BOOTLOADER,,}"
  case "$boot_mode" in
    uefi)
      case "$requested" in
        auto|""|systemd-boot)
          echo "systemd-boot"
          ;;
        grub|grub-efi)
          echo "grub"
          ;;
        bios|legacy)
          fail "INSTALL_BOOTLOADER=${INSTALL_BOOTLOADER} is invalid for UEFI installs."
          ;;
        *)
          fail "Unknown INSTALL_BOOTLOADER '${INSTALL_BOOTLOADER}'."
          ;;
      esac
      ;;
    bios)
      case "$requested" in
        auto|""|grub|grub-bios|legacy)
          echo "grub"
          ;;
        systemd-boot)
          fail "systemd-boot is not supported in BIOS mode."
          ;;
        *)
          fail "Unknown INSTALL_BOOTLOADER '${INSTALL_BOOTLOADER}'."
          ;;
      esac
      ;;
    *)
      fail "Unknown boot mode '${boot_mode}' for bootloader resolution."
      ;;
  esac
}

cpu_vendor() { awk -F': ' '/vendor_id/{print $2; exit}' /proc/cpuinfo; }

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

detect_virtualization() { systemd-detect-virt 2>/dev/null || echo "bare metal"; }

memory_summary() { awk '/MemTotal/ {printf "%.1f GiB", $2/1024/1024}' /proc/meminfo; }

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

print_hardware_summary() {
  log_step "Hardware summary"
  log_info "Boot target: ${BOOT_MODE^^} (detected: ${DETECTED_BOOT_MODE^^})"
  log_info "Bootloader: ${SELECTED_BOOTLOADER}"
  log_info "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')"
  log_info "Microcode pkg: ${MICROCODE:-none}"
  log_info "GPU: $(lspci | grep -i 'vga\|3d' || echo 'not detected')"
  log_info "GPU driver pkg: ${GPU_DRIVER:-none}"
  log_info "Virtualization: $(detect_virtualization)"
  log_info "Memory: $(memory_summary)"
  log_info "Layout preset: ${INSTALL_LAYOUT}"
  log_info "Bootloader: ${SELECTED_BOOTLOADER} (${BOOT_MODE^^})"
  if is_true "$INSTALL_USE_LUKS"; then
    log_info "Disk encryption: LUKS (${INSTALL_LUKS_NAME})"
  else
    log_info "Disk encryption: disabled"
  fi
  if is_true "$INSTALL_USE_LVM"; then
    log_info "Target filesystem: ${INSTALL_FILESYSTEM} on LVM (${INSTALL_VG_NAME}/${INSTALL_LV_ROOT_NAME})"
  else
    log_info "Target filesystem: ${INSTALL_FILESYSTEM}"
  fi
  log_info "Swap target: $(auto_swap_size_gb) GiB"
  log_info "Disks:"
  lsblk -dno NAME,SIZE,MODEL | sed 's/^/      /'
}

# --- Disk helpers ------------------------------------------------------------
partition_suffix_for() {
  local disk="$1"
  if [[ $disk =~ (nvme|mmcblk|loop) ]]; then
    echo "p"
  else
    echo ""
  fi
}

auto_select_disk() {
  local largest_disk="" largest_size=0
  while read -r name size_bytes; do
    if (( size_bytes > largest_size )); then
      largest_size=$size_bytes
      largest_disk="$name"
    fi
  done < <(lsblk -bndo NAME,SIZE,TYPE,RM | awk '$3=="disk" && $4==0 {print "/dev/"$1" "$2}')
  [[ -n $largest_disk ]] || fail "No suitable disks detected."
  echo "$largest_disk"
}

confirm_disk() {
  local disk="$1"
  log_step "Target disk"
  lsblk "$disk"
  read -r -p "Erase and use ${disk}? Type YES to continue: " answer
  [[ $answer == "YES" ]] || fail "Disk confirmation failed"
}

partition_disk() {
  local disk="$1"
  log_step "Partitioning ${disk} (${BOOT_MODE^^})"
  wipefs -af "$disk"
  sgdisk --zap-all "$disk" >/dev/null 2>&1 || true
  parted -s "$disk" mklabel gpt
  if [[ $BOOT_MODE == "uefi" ]]; then
    parted -s "$disk" mkpart ESP fat32 1MiB 513MiB
    parted -s "$disk" set 1 esp on
    parted -s "$disk" mkpart arch-root 513MiB 100%
    PART_BOOT="${disk}${PART_SUFFIX}1"
    PART_ROOT="${disk}${PART_SUFFIX}2"
  else
    parted -s "$disk" mkpart biosboot 1MiB 3MiB
    parted -s "$disk" set 1 bios_grub on
    parted -s "$disk" mkpart arch-root 3MiB 100%
    PART_BOOT=""
    PART_ROOT="${disk}${PART_SUFFIX}2"
  fi
}

format_boot_partition() {
  if [[ $BOOT_MODE != "uefi" ]]; then
    log_info "Skipping EFI partition format for BIOS install."
    return
  fi
  log_step "Formatting EFI system partition"
  mkfs.fat -F32 "$PART_BOOT"
}

lvcreate_with_size() {
  local vg="$1" name="$2" size="$3"
  if [[ $size == *%* ]]; then
    lvcreate -l "$size" -n "$name" "$vg"
  else
    lvcreate -L "$size" -n "$name" "$vg"
  fi
}

setup_storage_stack() {
  local base_device="${ENCRYPTED_DEVICE:-$PART_ROOT}"
  ROOT_DEVICE="$base_device"
  HOME_DEVICE=""
  if is_true "$INSTALL_USE_LVM"; then
    log_step "Provisioning LVM volumes (${INSTALL_VG_NAME}/${INSTALL_LV_ROOT_NAME})"
    pvcreate -ff -y "$base_device"
    vgcreate "$INSTALL_VG_NAME" "$base_device"
    if [[ ${INSTALL_LAYOUT,,} == "lvm-home" ]]; then
      lvcreate_with_size "$INSTALL_VG_NAME" "$INSTALL_LV_ROOT_NAME" "$INSTALL_LV_ROOT_SIZE"
      lvcreate_with_size "$INSTALL_VG_NAME" "$INSTALL_LV_HOME_NAME" "$INSTALL_LV_HOME_SIZE"
      HOME_DEVICE="/dev/${INSTALL_VG_NAME}/${INSTALL_LV_HOME_NAME}"
    else
      lvcreate -l 100%FREE -n "$INSTALL_LV_ROOT_NAME" "$INSTALL_VG_NAME"
    fi
    ROOT_DEVICE="/dev/${INSTALL_VG_NAME}/${INSTALL_LV_ROOT_NAME}"
  fi
}

format_root_device() {
  log_step "Formatting root filesystem (${FILESYSTEM_TYPE})"
  case "$FILESYSTEM_TYPE" in
    ext4) mkfs.ext4 -F "$ROOT_DEVICE" ;;
    btrfs) mkfs.btrfs -f "$ROOT_DEVICE" ;;
    *) fail "Unknown filesystem type $FILESYSTEM_TYPE" ;;
  esac
}

kernel_root_param() {
  if [[ $ROOT_DEVICE == /dev/mapper/* ]]; then
    echo "root=${ROOT_DEVICE}"
    return
  fi
  local root_uuid
  root_uuid=$(blkid -s UUID -o value "$ROOT_DEVICE")
  echo "root=UUID=${root_uuid}"
}

format_home_device() {
  [[ -n $HOME_DEVICE ]] || return
  log_step "Formatting /home (${FILESYSTEM_TYPE})"
  case "$FILESYSTEM_TYPE" in
    ext4) mkfs.ext4 -F "$HOME_DEVICE" ;;
    btrfs) mkfs.btrfs -f "$HOME_DEVICE" ;;
    *) fail "Unknown filesystem type $FILESYSTEM_TYPE for home" ;;
  esac
}

prepare_btrfs_subvolumes() {
  [[ $FILESYSTEM_TYPE == "btrfs" && ${INSTALL_LAYOUT,,} == "btrfs-subvols" ]] || return
  log_step "Creating Btrfs subvolumes"
  mount "$ROOT_DEVICE" /mnt
  read -ra subvol_entries <<< "$BTRFS_SUBVOL_SET"
  local entry subvol
  for entry in "${subvol_entries[@]}"; do
    subvol=${entry%%:*}
    [[ -n $subvol ]] || continue
    btrfs subvolume create "/mnt/${subvol}"
  done
  umount /mnt
}

mount_layout() {
  log_step "Mounting target"
  if [[ $FILESYSTEM_TYPE == "btrfs" && ${INSTALL_LAYOUT,,} == "btrfs-subvols" ]]; then
    read -ra subvol_entries <<< "$BTRFS_SUBVOL_SET"
    local root_entry=${subvol_entries[0]:-}
    local root_subvol=${root_entry%%:*}
    local root_mount=${root_entry#*:}
    [[ $root_mount == "/" ]] || fail "First BTRFS_SUBVOLUMES entry must target /."
    local root_opts="$BTRFS_MOUNT_OPTS"
    if [[ -n $root_opts ]]; then
      root_opts="${root_opts},subvol=${root_subvol}"
    else
      root_opts="subvol=${root_subvol}"
    fi
    mount -o "$root_opts" "$ROOT_DEVICE" /mnt
    local entry subvol target subvol_opts
    for entry in "${subvol_entries[@]:1}"; do
      subvol=${entry%%:*}
      target=${entry#*:}
      [[ -n $subvol && -n $target ]] || continue
      mkdir -p "/mnt${target}"
      subvol_opts="$BTRFS_MOUNT_OPTS"
      if [[ -n $subvol_opts ]]; then
        subvol_opts="${subvol_opts},subvol=${subvol}"
      else
        subvol_opts="subvol=${subvol}"
      fi
      mount -o "$subvol_opts" "$ROOT_DEVICE" "/mnt${target}"
    done
  else
    local mount_args=()
    if [[ $FILESYSTEM_TYPE == "btrfs" && -n ${BTRFS_MOUNT_OPTS// /} ]]; then
      mount_args=(-o "$BTRFS_MOUNT_OPTS")
    fi
    mount "${mount_args[@]}" "$ROOT_DEVICE" /mnt
  fi
  mkdir -p /mnt/boot
  if [[ $BOOT_MODE == "uefi" ]]; then
    mount "$PART_BOOT" /mnt/boot
  fi
  if [[ -n $HOME_DEVICE ]]; then
    mkdir -p /mnt/home
    local home_opts=()
    if [[ $FILESYSTEM_TYPE == "btrfs" && -n ${BTRFS_MOUNT_OPTS// /} ]]; then
      home_opts=(-o "$BTRFS_MOUNT_OPTS")
    fi
    mount "${home_opts[@]}" "$HOME_DEVICE" /mnt/home
  fi
  MOUNTED=true
}

cleanup() {
  if [[ $MOUNTED == true && -d /mnt ]]; then
    umount -R /mnt 2>/dev/null || true
  fi
  if is_true "$INSTALL_USE_LVM"; then
    vgchange -an "$INSTALL_VG_NAME" >/dev/null 2>&1 || true
  fi
  if [[ $OPENED_LUKS == true ]]; then
    cryptsetup close "$CRYPT_DEVICE_NAME" >/dev/null 2>&1 || true
  fi
}

configure_mirror() {
  log_step "Configuring mirror"
  printf 'Server = %s/$repo/os/$arch\n' "$ARCH_MIRROR" > /etc/pacman.d/mirrorlist
}

# --- Base installation -------------------------------------------------------
install_base_system() {
  log_step "Installing Arch base packages"
  local packages=(base linux linux-firmware)
  packages+=(networkmanager)
  [[ -n $MICROCODE ]] && packages+=("$MICROCODE")
  [[ -n $GPU_DRIVER ]] && packages+=("$GPU_DRIVER")
  if [[ $FILESYSTEM_TYPE == "btrfs" ]]; then
    packages+=("btrfs-progs")
  fi
  if is_true "$INSTALL_USE_LVM"; then
    packages+=("lvm2")
  fi
  if is_true "$INSTALL_USE_LUKS"; then
    packages+=("cryptsetup")
  fi
  if [[ $SELECTED_BOOTLOADER == "grub" ]]; then
    packages+=(grub)
    if [[ $BOOT_MODE == "uefi" ]]; then
      packages+=(efibootmgr)
    fi
  fi
  if [[ -n ${INSTALL_PACKAGES// /} ]]; then
    read -ra extra_pkgs <<< "$INSTALL_PACKAGES"
    packages+=("${extra_pkgs[@]}")
  fi
  pacstrap -K /mnt "${packages[@]}"
}

generate_fstab() {
  log_step "Generating fstab"
  genfstab -U /mnt >> /mnt/etc/fstab
}

run_in_chroot() { arch-chroot /mnt /bin/bash -c "$*"; }

configure_system() {
  log_step "Applying system configuration"
  run_in_chroot "ln -sf /usr/share/zoneinfo/${INSTALL_TIMEZONE} /etc/localtime"
  run_in_chroot "hwclock --systohc"

  if ! grep -q "^${INSTALL_LOCALE}" /mnt/etc/locale.gen; then
    echo "${INSTALL_LOCALE} UTF-8" >> /mnt/etc/locale.gen
  else
    sed -i "s/^#${INSTALL_LOCALE}/${INSTALL_LOCALE}/" /mnt/etc/locale.gen
  fi
  run_in_chroot "locale-gen"
  echo "LANG=${INSTALL_LOCALE}" > /mnt/etc/locale.conf
  echo "KEYMAP=${INSTALL_KEYMAP}" > /mnt/etc/vconsole.conf

  echo "${INSTALL_HOSTNAME}" > /mnt/etc/hostname
  cat <<EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${INSTALL_HOSTNAME}.localdomain ${INSTALL_HOSTNAME}
EOF

  run_in_chroot "echo 'root:${INSTALL_ROOT_PASSWORD}' | chpasswd"
  run_in_chroot "useradd -m -G wheel -s /bin/bash ${INSTALL_USER}"
  run_in_chroot "echo '${INSTALL_USER}:${INSTALL_USER_PASSWORD}' | chpasswd"
  run_in_chroot "sed -i 's/^# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers"
  run_in_chroot "systemctl enable NetworkManager"

  local need_mkinit=false
  if is_true "$INSTALL_USE_LUKS"; then
    run_in_chroot "if ! grep -q 'encrypt' /etc/mkinitcpio.conf; then sed -i 's/filesystems/encrypt filesystems/' /etc/mkinitcpio.conf; fi"
    need_mkinit=true
  fi
  if is_true "$INSTALL_USE_LVM"; then
    run_in_chroot "if ! grep -q 'lvm2' /etc/mkinitcpio.conf; then sed -i 's/filesystems/lvm2 filesystems/' /etc/mkinitcpio.conf; fi"
    need_mkinit=true
  fi
  if [[ $need_mkinit == true ]]; then
    run_in_chroot "mkinitcpio -P"
  fi
}

setup_swapfile() {
  log_step "Creating swapfile"
  local size_gb
  size_gb=$(auto_swap_size_gb)
  if [[ $FILESYSTEM_TYPE == "btrfs" ]]; then
    run_in_chroot "truncate -s 0 /swapfile"
    run_in_chroot "chattr +C /swapfile"
    run_in_chroot "btrfs property set /swapfile compression none"
  fi
  run_in_chroot "fallocate -l ${size_gb}G /swapfile"
  run_in_chroot "chmod 600 /swapfile"
  run_in_chroot "mkswap /swapfile"
  echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
}

setup_bootloader() {
  log_step "Installing bootloader (${SELECTED_BOOTLOADER})"
  local crypt_opt=""
  if is_true "$INSTALL_USE_LUKS"; then
    crypt_opt="cryptdevice=UUID=${CRYPT_UUID}:${INSTALL_LUKS_NAME}"
  fi

  if [[ $BOOT_MODE == "uefi" ]]; then
    case "$SELECTED_BOOTLOADER" in
      systemd-boot)
        run_in_chroot "bootctl install"
        local root_param
        root_param=$(kernel_root_param)
        cat <<'EOF' > /mnt/boot/loader/loader.conf
default arch
timeout 3
console-mode auto
editor no
EOF
        {
          echo "title   Arch Linux"
          echo "linux   /vmlinuz-linux"
          [[ -n $MICROCODE_IMG ]] && echo "initrd  /${MICROCODE_IMG}"
          echo "initrd  /initramfs-linux.img"
          if [[ -n $crypt_opt ]]; then
            echo "options ${crypt_opt} ${root_param} rw quiet"
          else
            echo "options ${root_param} rw quiet"
          fi
        } > /mnt/boot/loader/entries/arch.conf
        ;;
      grub)
        if [[ -n $crypt_opt ]]; then
          run_in_chroot "sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub"
          run_in_chroot "cat <<'EOF' >/tmp/update-grub-cmdline.sh
#!/bin/bash
set -euo pipefail
opt=\"$CRYPT_OPT\"
cfg='/etc/default/grub'
if [[ -z \$opt ]]; then
  exit 0
fi
if ! grep -q \"\$opt\" \"\$cfg\"; then
  sed -i \"/^GRUB_CMDLINE_LINUX=/ s/\"$/ \$opt\"/\" \"\$cfg\"
fi
EOF
CRYPT_OPT='${crypt_opt}' bash /tmp/update-grub-cmdline.sh
rm /tmp/update-grub-cmdline.sh"
        fi
        run_in_chroot "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux --recheck"
        run_in_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
        ;;
      *)
        fail "Unsupported bootloader '${SELECTED_BOOTLOADER}' for UEFI mode."
        ;;
    esac
  else
    if [[ -n $crypt_opt ]]; then
      run_in_chroot "sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub"
      run_in_chroot "cat <<'EOF' >/tmp/update-grub-cmdline.sh
#!/bin/bash
set -euo pipefail
opt=\"$CRYPT_OPT\"
cfg='/etc/default/grub'
    if [[ -z \$opt ]]; then
  exit 0
fi
if ! grep -q \"\$opt\" \"\$cfg\"; then
  sed -i \"/^GRUB_CMDLINE_LINUX=/ s/\"$/ \$opt\"/\" \"\$cfg\"
fi
EOF
CRYPT_OPT='${crypt_opt}' bash /tmp/update-grub-cmdline.sh
rm /tmp/update-grub-cmdline.sh"
    fi
    run_in_chroot "grub-install --target=i386-pc ${TARGET_DISK}"
    run_in_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
  fi
}

post_install_summary() {
  log_step "Installation complete"
  log_info "Hostname: ${INSTALL_HOSTNAME}"
  log_info "User created: ${INSTALL_USER} (wheel)"
  log_info "Layout preset: ${INSTALL_LAYOUT}"
  if is_true "$INSTALL_USE_LUKS"; then
    log_info "Disk encryption: LUKS (${INSTALL_LUKS_NAME})"
  else
    log_info "Disk encryption: disabled"
  fi
  if is_true "$INSTALL_USE_LVM"; then
    log_info "Root filesystem: ${INSTALL_FILESYSTEM} on ${INSTALL_VG_NAME}/${INSTALL_LV_ROOT_NAME}"
  else
    log_info "Root filesystem: ${INSTALL_FILESYSTEM}"
  fi
  log_info "Extra packages: ${INSTALL_PACKAGES}"
  log_info "Next steps: update passwords, review /etc/locale.gen, reboot"
}

# --- Main orchestration ------------------------------------------------------
main() {
  FILESYSTEM_TYPE="${INSTALL_FILESYSTEM,,}"
  require_root
  ensure_commands
  bootstrap_networking
  validate_storage_inputs
  require_online
  configure_mirror

  DETECTED_BOOT_MODE=$(detect_boot_mode)
  BOOT_MODE=$(resolve_boot_mode "$DETECTED_BOOT_MODE")
  SELECTED_BOOTLOADER=$(resolve_bootloader "$BOOT_MODE")
  MICROCODE=$(microcode_package)
  MICROCODE_IMG=$(microcode_image "$MICROCODE")
  GPU_DRIVER=$(detect_gpu_driver)

  print_hardware_summary

  TARGET_DISK=${INSTALL_DISK:-$(auto_select_disk)}
  confirm_disk "$TARGET_DISK"
  PART_SUFFIX=$(partition_suffix_for "$TARGET_DISK")
  PART_BOOT=""
  PART_BIOSBOOT=""
  PART_ROOT=""

  trap cleanup EXIT

  partition_disk "$TARGET_DISK"
  format_boot_partition
  setup_luks_container
  setup_storage_stack
  format_root_device
  format_home_device
  prepare_btrfs_subvolumes
  mount_layout

  install_base_system
  generate_fstab
  configure_system
  setup_swapfile
  setup_bootloader
  maybe_install_desktop
  select_bundle_script
  run_post_install_script
  post_install_summary
}

main "$@"
