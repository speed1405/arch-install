# GUI Type Options

The Arch Linux installer supports two different GUI (dialog) utilities for the text-based interface.

## Available GUI Types

### 1. whiptail (Default)
- **Availability**: Included in Arch ISO by default
- **Installation**: None required - always available
- **Features**: Basic dialog boxes with simple aesthetics
- **Use case**: Default choice, works out of the box

### 2. dialog (Enhanced)
- **Availability**: Available in Arch repositories
- **Installation**: `pacman -S dialog`
- **Features**: Enhanced visuals with colors, shadows, and better styling
- **Use case**: Optional upgrade for better user experience

## Auto-Detection

By default, the installer automatically detects which GUI utility to use:

1. **Checks for dialog** - If installed, uses dialog for better visuals
2. **Falls back to whiptail** - Always available in Arch ISO

This ensures the installer always works, even without internet connectivity to install additional packages.

## Manual Selection

You can force a specific GUI type using an environment variable:

### Use dialog (if installed)
```bash
INSTALLER_GUI_TYPE=dialog ./install-arch.sh
```

### Use whiptail (default)
```bash
INSTALLER_GUI_TYPE=whiptail ./install-arch.sh
```

### Auto-detect (default behavior)
```bash
INSTALLER_GUI_TYPE=auto ./install-arch.sh
# or simply:
./install-arch.sh
```

## Installing dialog (Optional)

If you want the enhanced dialog experience, install it before running the installer:

```bash
# Update package database
pacman -Sy

# Install dialog
pacman -S --noconfirm dialog

# Run installer (will auto-detect and use dialog)
./install-arch.sh
```

## Visual Differences

### whiptail
- Clean, simple interface
- Basic borders and text
- Works in any terminal
- Lightweight and fast

### dialog
- Enhanced colors and styling
- Shadow effects for depth
- Better visual hierarchy
- More polished appearance

Both provide the same functionality - the difference is purely aesthetic.

## Compatibility

Both GUI types support all installer features:
- Message boxes
- Yes/No confirmations
- Input boxes
- Password boxes (hidden input)
- Selection menus
- Checklists
- Progress gauges

## Troubleshooting

### "No GUI utility found" error
This means neither whiptail nor dialog is available. This should never happen in a standard Arch ISO, but if it does:

```bash
# Install whiptail (if needed)
pacman -S libnewt

# Or install dialog
pacman -S dialog
```

### Preference not working
Make sure to set the environment variable before running the script:
```bash
# Correct
INSTALLER_GUI_TYPE=dialog ./install-arch.sh

# Incorrect (won't work)
./install-arch.sh INSTALLER_GUI_TYPE=dialog
```

## Recommendations

- **Default users**: Just run `./install-arch.sh` - auto-detection works great
- **Better visuals**: Install dialog first with `pacman -S dialog`
- **Minimal setup**: Use whiptail (already included, no installation needed)
- **Offline installation**: Use whiptail (doesn't require network/packages)
