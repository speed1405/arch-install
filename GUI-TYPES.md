# TUI Tool - Gum

The Arch Linux installer uses **gum** for the modern text-based user interface.

## About Gum

**gum** is a modern, glamorous tool for shell scripts created by Charm (charmbracelet).

- **Repository**: https://github.com/charmbracelet/gum
- **Availability**: Available in Arch repositories
- **Installation**: `pacman -S gum`
- **Features**: Beautiful TUI with colors, styling, and interactive components
- **Use case**: Modern, user-friendly interface for the installer

## Installation

Install gum before running the installer:

```bash
# Update package database
pacman -Sy

# Install gum
pacman -S --noconfirm gum

# Run installer (will check for gum)
./install-arch.sh
```

Or use the provided dependency installer:

```bash
# Automatically installs gum if not present
./install-dependencies.sh
```

## Features

Gum provides a modern TUI experience with:

### Interactive Components
- **Styled messages** - Colorful, formatted text output
- **Confirmations** - Yes/No prompts with custom buttons
- **Input fields** - Text entry with placeholders
- **Password fields** - Hidden password input
- **Menus** - Single-select from options
- **Checklists** - Multi-select from options
- **Progress indicators** - Visual feedback for operations

### Visual Enhancements
- Enhanced colors and styling
- Better visual hierarchy
- Modern, clean appearance
- Improved readability

## Usage in Installer

The installer uses gum for all user interactions:

- **Welcome screens** - Styled introductions
- **Hardware detection** - Clear summary displays
- **Disk selection** - Interactive menus
- **Configuration** - Input fields for hostname, users, etc.
- **Software selection** - Checklists for bundles
- **Progress** - Real-time status updates

## Compatibility

All installer features work with gum:
- Message boxes
- Yes/No confirmations
- Input boxes
- Password boxes (hidden input)
- Selection menus
- Multi-select checklists
- Progress indicators

## Troubleshooting

### "gum not found" error

If gum is not installed:

```bash
# Install gum from Arch repos
pacman -S gum

# Verify installation
gum --version
```

### Dependencies

Gum is the only TUI dependency. The installer will check for it at startup and provide clear error messages if it's not available.

## Recommendations

- **First-time users**: Run `./install-dependencies.sh` to automatically install gum
- **Manual installation**: Install with `pacman -S gum` before running the installer
- **Arch ISO**: gum must be installed from repos (requires network connectivity)
