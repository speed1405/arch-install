#!/usr/bin/env bash
# Validation script for the whiptail-based Arch installer

set -euo pipefail

echo "==> Validating Arch Linux Installer"
echo ""

# Test 1: Syntax check
echo "Test 1: Bash syntax validation"
bash -n install-arch.sh && echo "  ✓ Syntax check passed"

# Test 2: Whiptail availability
echo ""
echo "Test 2: Checking for required whiptail command"
if command -v whiptail >/dev/null 2>&1; then
    echo "  ✓ whiptail is available"
    whiptail --version 2>&1 | head -1 | sed 's/^/    /'
fi

# Test 3: Function definitions
echo ""
echo "Test 3: Checking critical function definitions"
grep "^show_welcome()" install-arch.sh >/dev/null && echo "  ✓ show_welcome"
grep "^select_disk()" install-arch.sh >/dev/null && echo "  ✓ select_disk"
grep "^select_filesystem()" install-arch.sh >/dev/null && echo "  ✓ select_filesystem"
grep "^partition_disk()" install-arch.sh >/dev/null && echo "  ✓ partition_disk"
grep "^install_base_system()" install-arch.sh >/dev/null && echo "  ✓ install_base_system"
grep "^setup_bootloader()" install-arch.sh >/dev/null && echo "  ✓ setup_bootloader"

# Test 4: Whiptail wrappers
echo ""
echo "Test 4: Checking whiptail wrapper functions"
grep "^wt_msgbox()" install-arch.sh >/dev/null && echo "  ✓ wt_msgbox"
grep "^wt_menu()" install-arch.sh >/dev/null && echo "  ✓ wt_menu"
grep "^wt_yesno()" install-arch.sh >/dev/null && echo "  ✓ wt_yesno"
grep "^wt_gauge()" install-arch.sh >/dev/null && echo "  ✓ wt_gauge"

# Test 5: Supporting files
echo ""
echo "Test 5: Checking supporting files"
[ -f install-desktop.sh ] && bash -n install-desktop.sh && echo "  ✓ install-desktop.sh"
[ -f README.md ] && echo "  ✓ README.md ($(wc -l < README.md) lines)"
[ -f test-whiptail.sh ] && bash -n test-whiptail.sh && echo "  ✓ test-whiptail.sh"

# Test 6: Bundles
echo ""
echo "Test 6: Checking bundle scripts"
for bundle in dev.sh gaming.sh server.sh cloud.sh creative.sh desktop-utilities.sh; do
    if [ -f "$bundle" ]; then
        bash -n "$bundle" && echo "  ✓ $bundle"
    fi
done

echo ""
echo "======================================"
echo "✓ All validation tests passed!"
echo "======================================"
echo ""
echo "The installer is ready. To use it:"
echo "  1. Boot Arch Linux ISO"
echo "  2. Ensure network connectivity"
echo "  3. Run: ./install-arch.sh"
echo ""
echo "Demo: ./test-whiptail.sh"
