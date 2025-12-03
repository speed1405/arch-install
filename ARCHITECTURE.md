# Arch Install Script Architecture

## Overview

The installer is a single-file Bash script with whiptail GUI that guides users through installing Arch Linux.

## Script Structure

### 1. Configuration & Globals (Lines 1-80)
- Script metadata and version
- Global configuration variables
- Runtime state variables
- Required tools list

### 2. Whiptail Helper Functions (Lines 82-130)
Wrapper functions for whiptail dialogs:
- `wt_msgbox()` - Display information
- `wt_yesno()` - Yes/No confirmations
- `wt_inputbox()` - Text input
- `wt_passwordbox()` - Password input
- `wt_menu()` - Selection menus
- `wt_checklist()` - Multi-select lists
- `wt_gauge()` - Progress bars

### 3. Utility Functions (Lines 132-180)
- `log_step()`, `log_info()`, `log_error()` - Logging
- `fail()` - Error handling with GUI
- `require_root()` - Root privilege check
- `ensure_commands()` - Dependency verification
- `require_online()` - Network connectivity check

### 4. Hardware Detection (Lines 182-240)
- `detect_boot_mode()` - UEFI vs BIOS
- `cpu_vendor()` - Intel vs AMD
- `microcode_package()` - Appropriate microcode
- `detect_gpu_driver()` - GPU driver selection
- `detect_virtualization()` - VM detection
- `memory_gb()` - RAM detection
- `auto_swap_size_gb()` - Swap size calculation

### 5. Disk Utilities (Lines 242-260)
- `partition_suffix_for()` - nvme vs sda naming
- `get_disks()` - List available disks

### 6. GUI Workflow Functions (Lines 262-460)
Interactive menus for user configuration:
- `show_welcome()` - Welcome screen
- `show_hardware_summary()` - Hardware info
- `select_disk()` - Disk selection menu
- `select_filesystem()` - ext4 vs btrfs
- `select_layout()` - Partition layout
- `select_encryption()` - LUKS setup
- `configure_system_settings()` - Hostname, timezone, locale
- `configure_users()` - Root and user accounts
- `select_mirror_region()` - Package mirror selection
- `select_desktop()` - Desktop environment
- `select_bundles()` - Software bundles
- `show_installation_summary()` - Review settings

### 7. Resolution Functions (Lines 462-490)
- `is_true()` - Boolean helper
- `resolve_boot_mode()` - Finalize boot mode
- `resolve_bootloader()` - Select bootloader

### 8. Installation Functions (Lines 492-700)
Core installation operations:
- `partition_disk()` - Create GPT partitions
- `format_boot_partition()` - Format EFI/boot
- `setup_luks_container()` - LUKS encryption
- `setup_storage_stack()` - LVM configuration
- `format_filesystems()` - Format root/home
- `prepare_btrfs_subvolumes()` - Btrfs setup
- `mount_filesystems()` - Mount all filesystems
- `update_mirrorlist()` - Update package mirrors
- `install_base_system()` - Pacstrap base packages
- `generate_fstab()` - Create fstab
- `configure_system()` - System configuration
- `setup_swapfile()` - Create swap
- `setup_bootloader()` - Install bootloader
- `install_desktop()` - Run desktop script
- `run_bundle()` - Run bundle scripts
- `cleanup()` - Cleanup on exit

### 9. Main Flow (Lines 702-780)
The `main()` function orchestrates the installation:

```
main()
  ├── Pre-flight checks
  │   ├── require_root()
  │   ├── ensure_commands()
  │   └── require_online()
  │
  ├── Hardware detection
  │   ├── detect_boot_mode()
  │   ├── microcode_package()
  │   └── detect_gpu_driver()
  │
  ├── Interactive GUI workflow
  │   ├── show_welcome()
  │   ├── show_hardware_summary()
  │   ├── select_disk()
  │   ├── select_filesystem()
  │   ├── select_layout()
  │   ├── select_encryption()
  │   ├── configure_system_settings()
  │   ├── configure_users()
  │   ├── select_mirror_region()
  │   ├── select_desktop()
  │   ├── select_bundles()
  │   └── show_installation_summary()
  │
  ├── Configuration finalization
  │   ├── resolve_boot_mode()
  │   └── resolve_bootloader()
  │
  └── Installation (with progress gauge)
      ├── partition_disk()
      ├── format_boot_partition()
      ├── setup_luks_container()
      ├── setup_storage_stack()
      ├── format_filesystems()
      ├── prepare_btrfs_subvolumes()
      ├── mount_filesystems()
      ├── update_mirrorlist()
      ├── install_base_system()
      ├── generate_fstab()
      ├── configure_system()
      ├── setup_swapfile()
      ├── setup_bootloader()
      ├── install_desktop()
      └── run_bundle()
```

## Data Flow

### User Input → Configuration
```
Whiptail Menus → Global Variables → Installation Functions
```

### Examples:
- Disk menu → `$INSTALL_DISK` → `partition_disk()`
- Filesystem menu → `$INSTALL_FILESYSTEM` → `format_filesystems()`
- User input → `$INSTALL_USER` → `configure_system()`

## Error Handling

1. **Pre-flight**: Check requirements before starting
2. **Validation**: Validate user input at each step
3. **Confirmation**: Require explicit confirmation for destructive operations
4. **Cleanup**: `trap cleanup EXIT` ensures proper cleanup
5. **Error Messages**: GUI error dialogs via `fail()` function

## Progress Tracking

Installation progress is shown via whiptail gauge:

```bash
{
  echo "0"; echo "# Partitioning disk..."
  partition_disk()
  
  echo "25"; echo "# Formatting filesystems..."
  format_filesystems()
  
  echo "50"; echo "# Installing base system..."
  install_base_system()
  
  echo "100"; echo "# Installation complete!"
} | wt_gauge "Installing Arch Linux" "Please wait..." 8 70
```

## Key Design Decisions

### 1. Single File
- Easier distribution
- No external dependencies (except whiptail)
- Self-contained

### 2. Whiptail for GUI
- Included in Arch ISO
- Lightweight and fast
- Consistent across terminals
- Easy to use

### 3. Modular Functions
- Each installation stage is a separate function
- Easy to test and modify
- Clear separation of concerns

### 4. Interactive First
- GUI menus for all configuration
- No complex environment variables needed
- Guided workflow reduces errors

### 5. Safe Defaults
- Automatic hardware detection
- Sensible default selections
- Multiple confirmation steps

## Extension Points

To add new features:

### Add a New Desktop Environment
Edit `select_desktop()` to add menu option, then update `install-desktop.sh`

### Add a New Bundle
1. Create `mybundle.sh` script
2. It will automatically appear in bundle checklist

### Add Storage Option
1. Add menu item in `select_layout()`
2. Implement logic in `setup_storage_stack()`
3. Update `format_filesystems()` if needed

### Customize Hardware Detection
Edit detection functions in hardware detection section

## Testing

### Syntax Check
```bash
bash -n install-arch.sh
```

### Demo GUI
```bash
./test-whiptail.sh
```

### Dry Run (requires root in live environment)
```bash
# Not fully implemented, but could add:
export DRY_RUN=true
./install-arch.sh
```

## Dependencies

### Required
- `bash` - Shell interpreter
- `whiptail` - GUI dialogs
- `lsblk`, `parted`, `sgdisk` - Disk operations
- `pacstrap`, `arch-chroot` - Arch tools
- `mkfs.*` - Filesystem tools
- `cryptsetup` - LUKS encryption (if used)
- `lvm2` - LVM tools (if used)

### Optional
- `install-desktop.sh` - Desktop installation
- Bundle scripts (`*.sh`) - Post-install bundles

## Security Considerations

1. **Password Input**: Uses whiptail passwordbox (hidden)
2. **Confirmation**: Multiple confirmations for destructive ops
3. **Root Check**: Requires root privileges
4. **LUKS**: Strong encryption when enabled
5. **Sudo**: Wheel group properly configured

## Performance

- Hardware detection: < 1 second
- User interaction: Depends on user
- Installation: 5-15 minutes (depends on network and packages)
  - Partitioning: ~10 seconds
  - Base system: 3-8 minutes
  - Desktop: 2-7 minutes (if selected)

## Future Improvements

1. Network configuration menu
2. Custom package selection
3. Multi-disk support
4. RAID configuration
5. Advanced partitioning options
6. Installation profile save/load
7. Logging to file
8. Recovery options
