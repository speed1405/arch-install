# Arch Install Script Architecture

## Overview

The installer is a Bash script with a Python-based GUI that guides users through installing Arch Linux. The GUI uses Python's dialog library for an improved user experience.

## Script Structure

### 1. Configuration & Globals (Lines 1-80)
- Script metadata and version
- Global configuration variables
- Runtime state variables
- Required tools list (includes Python 3 and dialog)

### 2. Python GUI Helper Functions (Lines 82-130)
Wrapper functions for Python-based dialogs:
- `wt_msgbox()` - Display information
- `wt_yesno()` - Yes/No confirmations
- `wt_inputbox()` - Text input
- `wt_passwordbox()` - Password input
- `wt_menu()` - Selection menus
- `wt_checklist()` - Multi-select lists
- `wt_gauge()` - Progress bars

All GUI functions call the Python wrapper (`gui_wrapper.py`) which uses the `installer_gui.py` module.

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
  │   ├── Install GUI dependencies (install-dependencies.sh)
  │   ├── ensure_commands()
  │   └── require_online()
  │
  ├── Hardware detection
  │   ├── detect_boot_mode()
  │   ├── microcode_package()
  │   └── detect_gpu_driver()
  │
  ├── Interactive Python GUI workflow
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
Python GUI Dialogs → Global Variables → Installation Functions
```

### Examples:
- Disk menu → `$INSTALL_DISK` → `partition_disk()`
- Filesystem menu → `$INSTALL_FILESYSTEM` → `format_filesystems()`
- User input → `$INSTALL_USER` → `configure_system()`

## Error Handling

1. **Pre-flight**: Check requirements before starting
2. **Dependency Installation**: Automatically install Python and dialog dependencies
3. **Validation**: Validate user input at each step
4. **Confirmation**: Require explicit confirmation for destructive operations
5. **Cleanup**: `trap cleanup EXIT` ensures proper cleanup
6. **Error Messages**: GUI error dialogs via `fail()` function

## Progress Tracking

Installation progress is shown via dialog gauge:

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

### 1. Main Script with Python GUI
- Bash for system operations and installation logic
- Python-based GUI for user interaction
- Modular design with separate GUI components

### 2. Python Dialog for GUI
- Automatically installed from Arch repositories
- Lightweight and fast
- Consistent across terminals
- More flexible than whiptail

### 3. Automatic Dependency Management
- Dependencies installed automatically before GUI starts
- Python 3, dialog utility, and python-dialog library
- No manual setup required

### 4. Modular Functions
- Each installation stage is a separate function
- Easy to test and modify
- Clear separation of concerns

### 5. Interactive First
- GUI menus for all configuration
- No complex environment variables needed
- Guided workflow reduces errors

### 6. Safe Defaults
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
python3 -m py_compile installer_gui.py gui_wrapper.py
```

### Dependency Installation Test
```bash
./install-dependencies.sh
```

### Dry Run (requires root in live environment)
```bash
# Not fully implemented, but could add:
export DRY_RUN=true
./install-arch.sh
```

## Dependencies

### Automatically Installed
- `python3` - Python interpreter for GUI
- `dialog` - Dialog utility
- `python-dialog` - Python dialog library

### Required (Pre-installed or checked)
- `bash` - Shell interpreter
- `lsblk`, `parted`, `sgdisk` - Disk operations
- `pacstrap`, `arch-chroot` - Arch tools
- `mkfs.*` - Filesystem tools
- `cryptsetup` - LUKS encryption (if used)
- `lvm2` - LVM tools (if used)

### Optional
- `install-desktop.sh` - Desktop installation
- Bundle scripts (`*.sh`) - Post-install bundles

## Security Considerations

1. **Password Input**: Uses Python dialog passwordbox (hidden)
2. **Confirmation**: Multiple confirmations for destructive ops
3. **Root Check**: Requires root privileges
4. **LUKS**: Strong encryption when enabled
5. **Sudo**: Wheel group properly configured
6. **Dependency Verification**: Python and dialog libraries installed from official repositories

## Performance

- Dependency installation: ~30-60 seconds (first run only)
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
