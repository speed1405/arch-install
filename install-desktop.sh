#!/usr/bin/env bash
# Post-install desktop environment bootstrapper.
# Run from the installed system (not the live ISO) as root.

set -euo pipefail
IFS=$'\n\t'

: "${DESKTOP_ENV:=gnome}"                   # gnome, kde, xfce, cinnamon, mate, budgie, lxqt, sway, i3
: "${DESKTOP_EXTRAS:=}"                    # Additional packages to install
: "${PACMAN_FLAGS:=--needed --noconfirm}"   # Extra flags for pacman -Syu

log_step() { printf '\n==> %s\n' "$1"; }
log_info() { printf '    - %s\n' "$1"; }
log_error() { printf 'ERROR: %s\n' "$1" >&2; }
fail() { log_error "$1"; exit 1; }

require_root() { [[ ${EUID} -eq 0 ]] || fail "Run this script as root on the target system."; }

pacman_install() {
  read -ra pacman_args <<< "$PACMAN_FLAGS"
  pacman "${pacman_args[@]}" -Syu "$@"
}

desktop_profile() {
  local env="${1,,}"
  case "$env" in
    gnome)
      DESKTOP_PACKAGES=(gnome gnome-shell-extensions gdm gnome-console gnome-tweaks)
      DISPLAY_MANAGER="gdm"
      ;;
    kde|plasma)
      DESKTOP_PACKAGES=(plasma-desktop konsole dolphin sddm)
      DISPLAY_MANAGER="sddm"
      ;;
    xfce)
      DESKTOP_PACKAGES=(xfce4 xfce4-goodies lightdm lightdm-gtk-greeter)
      DISPLAY_MANAGER="lightdm"
      ;;
    cinnamon)
      DESKTOP_PACKAGES=(cinnamon nemo gnome-terminal lightdm lightdm-slick-greeter)
      DISPLAY_MANAGER="lightdm"
      ;;
    mate)
      DESKTOP_PACKAGES=(mate mate-extra lightdm lightdm-gtk-greeter)
      DISPLAY_MANAGER="lightdm"
      ;;
    budgie)
      DESKTOP_PACKAGES=(budgie-desktop budgie-desktop-view gnome-terminal gdm)
      DISPLAY_MANAGER="gdm"
      ;;
    lxqt)
      DESKTOP_PACKAGES=(lxqt breeze-icons sddm)
      DISPLAY_MANAGER="sddm"
      ;;
    sway)
      DESKTOP_PACKAGES=(sway swayidle swaylock waybar foot grim slurp greetd tuigreet)
      DISPLAY_MANAGER="greetd"
      ;;
    i3)
      DESKTOP_PACKAGES=(i3-wm i3status i3lock dmenu lightdm lightdm-gtk-greeter)
      DISPLAY_MANAGER="lightdm"
      ;;
    *)
      fail "Unsupported desktop environment: ${DESKTOP_ENV}."
      ;;
  esac
}

enable_display_manager() {
  case "$DISPLAY_MANAGER" in
    gdm|sddm|lightdm)
      systemctl enable "$DISPLAY_MANAGER"
      ;;
    greetd)
      mkdir -p /etc/greetd
      if [[ ! -s /etc/greetd/config.toml ]]; then
        cat <<'EOF' > /etc/greetd/config.toml
[terminal]
shell = "/usr/bin/tuigreet"
args = ["--cmd", "sway"]
EOF
      fi
      systemctl enable greetd
      ;;
    *)
      fail "Unknown display manager: ${DISPLAY_MANAGER}"
      ;;
  esac
}

append_extras() {
  if [[ -n ${DESKTOP_EXTRAS// /} ]]; then
    read -ra extra_pkgs <<< "$DESKTOP_EXTRAS"
    DESKTOP_PACKAGES+=("${extra_pkgs[@]}")
  fi
}

main() {
  require_root
  desktop_profile "$DESKTOP_ENV"
  append_extras
  log_step "Installing ${DESKTOP_ENV} desktop"
  pacman_install "${DESKTOP_PACKAGES[@]}"
  log_step "Enabling display/login manager"
  enable_display_manager
  log_step "Desktop setup complete"
  log_info "Reboot or log out, then log in via ${DISPLAY_MANAGER}."
}

main "$@"
