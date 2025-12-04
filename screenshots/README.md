# GUI Screenshots

This directory contains visual examples of the Python-based GUI dialogs used in the Arch Linux installer.

## Screenshot Files

Each `.txt` file contains an ASCII art representation of a dialog type:

1. **01-welcome-screen.txt** - Welcome message box
2. **02-hardware-summary.txt** - Hardware detection display
3. **03-disk-selection.txt** - Disk selection menu
4. **04-password-entry.txt** - Secure password input
5. **05-software-bundles.txt** - Multi-select checklist
6. **06-installation-progress.txt** - Installation progress gauge

## Viewing Screenshots

You can view these ASCII art representations directly in your terminal:

```bash
cat screenshots/01-welcome-screen.txt
```

Or view all of them:

```bash
for file in screenshots/*.txt; do 
    echo "=== $file ==="
    cat "$file"
    echo
done
```

## Actual Appearance

These ASCII representations show the structure and layout of each dialog. The actual installer running in a terminal will display:

- Color-highlighted backgrounds (typically blue/cyan)
- Smooth box-drawing characters
- Dynamic sizing based on terminal dimensions
- Button highlighting and selection indicators
- Real-time progress animations for the gauge

## Live Demo

To see the actual GUI in action:

1. Boot from an Arch Linux ISO
2. Run the installer: `./install-arch.sh`
3. The installer will automatically install Python and dialog dependencies
4. All user interactions will use these Python-based dialogs

## Documentation

For complete GUI documentation, see [GUI-SCREENSHOTS.md](../GUI-SCREENSHOTS.md) in the repository root.
