# Arch Linux Modular Installer

`install-arch.sh` is a single-file, modular installer meant to be run from the official Arch ISO. It auto-detects hardware (boot mode, CPU, GPU, memory, virtualization, candidate disks) and assembles a predictable install flow so you can focus on the few inputs that really matter. Pair it with `install-desktop.sh` once the base system is ready to add full desktops like GNOME, KDE Plasma, XFCE, Cinnamon, MATE, Budgie, LXQt, Sway, or i3 in one shot.

## What the script does

1. Verifies root privileges, required tooling, and connectivity.
2. Prints a hardware summary (boot mode, CPU + microcode, GPU driver suggestion, memory, disks).
3. (Optional) Brings up Wi-Fi or Ethernet using `nmcli` when `NETWORK_BOOTSTRAP_ENABLE=true` so you can run the installer unattended.
4. Picks the largest non-removable disk when `INSTALL_DISK` is unset and asks for a destructive confirmation.
5. Partitions GPT with either an EFI system partition (UEFI installs) or a tiny BIOS boot stub (legacy installs) before carving the root volume, plus optional LVM layering and advanced layouts (Btrfs subvolumes or split LVM root/home LVs).
6. Builds a base system with `pacstrap`, adding detected microcode/GPU drivers plus any extra packages you list.
7. Applies localization, hostname, network, user, sudo settings, and injects the `lvm2` initramfs hook when needed.
8. Creates a right-sized swapfile and fstab entry (with Btrfs-friendly swapfile prep when needed).
9. Installs the bootloader you request: systemd-boot or GRUB on UEFI systems, GRUB (i386-pc) on BIOS/legacy, honoring `INSTALL_BOOT_MODE` and `INSTALL_BOOTLOADER` overrides.
10. Optionally copies `install-desktop.sh` into the target, prompts you to pick a desktop (GNOME, KDE Plasma, XFCE, Cinnamon, MATE, Budgie, LXQt, Sway, i3, or none), and runs the desktop installer in the chroot when requested.
11. Optionally stages and runs your own provisioning script inside the chroot (great for dotfiles, services, or additional automation).
12. Prints a short post-install checklist.

Each logical step lives in its own function (`partition_disk`, `install_base_system`, `setup_bootloader`, etc.), making it easy to reorder or override pieces as your workflow evolves.

## Usage

1. Boot into the Arch ISO and ensure networking is up (`iwctl`, `nmcli`, or Ethernet).
2. Copy the script onto the live system (USB, `scp`, `curl`, etc.) and make it executable:

   ```bash
   chmod +x install-arch.sh
   ```

   Keep `install-desktop.sh` in the same directory (or set `INSTALL_DESKTOP_SCRIPT` to its path) if you want the installer to offer desktop bootstrapping right away.

3. (Optional) Export any overrides before running. Example:
   
   ```bash
   export INSTALL_HOSTNAME=atlas \
          INSTALL_USER=neo \
          INSTALL_PACKAGES="nano vim git htop"
   ```

4. Run the installer:

   ```bash
   ./install-arch.sh
   ```

5. Review the hardware summary and type `YES` when prompted to wipe the chosen disk.
6. When prompted, pick a desktop to install (or type `none`).
7. Wait for the script to finish, then `reboot`.

## Storage profiles

- **ext4 (default):** simple root partition on bare metal. Leave `INSTALL_FILESYSTEM` unset.
- **Btrfs:** export `INSTALL_FILESYSTEM=btrfs` to format the root as Btrfs and mount it with `BTRFS_MOUNT_OPTS` (defaults to `compress=zstd,autodefrag`). The swapfile helper automatically disables CoW.
- **LVM:** export `INSTALL_USE_LVM=true` to convert the root partition into an LVM PV + VG/LV (`INSTALL_VG_NAME`/`INSTALL_LV_ROOT_NAME`). Combine with either filesystem choice above (e.g., Btrfs on an LV).
- **Layout presets:** set `INSTALL_LAYOUT=single` (default) for a monolithic root, `INSTALL_LAYOUT=btrfs-subvols` to auto-create the `BTRFS_SUBVOLUMES` map (e.g., `@:/`, `@home:/home`, ...), or `INSTALL_LAYOUT=lvm-home` to carve separate root/home LVs sized via `INSTALL_LV_ROOT_SIZE` and `INSTALL_LV_HOME_SIZE`.

## Boot mode selection

By default the installer inspects `/sys/firmware/efi` to decide whether to treat the machine as UEFI or BIOS. Set `INSTALL_BOOT_MODE=uefi`, `INSTALL_BOOT_MODE=bios` (alias: `legacy`), or leave it at `auto` to accept the detection result. Pair it with `INSTALL_BOOTLOADER` to explicitly request `systemd-boot` or `grub` (`auto` chooses the sensible default for the selected mode).

- **UEFI:** the script creates a 512 MiB FAT32 EFI system partition, mounts it at `/boot`, and installs your chosen bootloader. The default (`INSTALL_BOOTLOADER=auto`) resolves to systemd-boot, but you can set `INSTALL_BOOTLOADER=grub` to install `grub-install --target=x86_64-efi` instead. Forcing `INSTALL_BOOT_MODE=uefi` while booted in legacy mode is blocked since UEFI tooling needs firmware support.
- **BIOS/Legacy:** a 1 MiB BIOS boot partition (type `bios_grub`) is created so GRUB can embed its core image on GPT disks, while `/boot` simply lives on the root filesystem. GRUB is the only supported bootloader in this mode, so `INSTALL_BOOTLOADER` must be `auto` or `grub`. Use this when installing on older machines or when you want to force a legacy GRUB install even if the firmware currently exposes UEFI. Make sure the target hardware actually supports legacy boot before setting this.

## Post-install provisioning

Set `INSTALL_POST_SCRIPT` to a shell script on the live system (absolute path or relative to the installer directory) to have it copied into the new installation and executed via `arch-chroot /mnt`. Provide additional arguments with `INSTALL_POST_SCRIPT_ARGS="arg1 arg2"`. The script runs after optional desktop installation, so you can use it for dotfiles, service enablement, language runtime installs, etc. If the file cannot be found, the installer logs an error but continues.

## Network bootstrapping

Set `NETWORK_BOOTSTRAP_ENABLE=true` when running from the ISO if you want the script to bring the link up via `nmcli` before it checks connectivity. Supported profiles:

- **Wi-Fi (`NETWORK_TYPE=wifi`):** provide `NETWORK_WIFI_SSID` and `NETWORK_WIFI_PSK`, plus `NETWORK_INTERFACE` if you need to pin a specific adapter.
- **Ethernet DHCP (`NETWORK_TYPE=ethernet`):** optionally set `NETWORK_INTERFACE` to force a port; otherwise the script simply ensures NetworkManager is running.
- **Static IPv4 (`NETWORK_TYPE=static`):** set `NETWORK_INTERFACE`, `NETWORK_STATIC_IP` (CIDR), `NETWORK_STATIC_GATEWAY`, and optionally override `NETWORK_STATIC_DNS`.

Leave `NETWORK_BOOTSTRAP_ENABLE=false` when you prefer to configure networking manually (iwctl, ip, etc.).

## Customization knobs

| Variable | Purpose | Default |
| --- | --- | --- |
| `INSTALL_DISK` | Target disk (e.g. `/dev/nvme0n1`). Leave empty for auto-selection. | *largest disk* |
| `INSTALL_HOSTNAME` | Hostname + `/etc/hosts` entry. | `archlinux` |
| `INSTALL_TIMEZONE` | Timezone for `/etc/localtime`. | `UTC` |
| `INSTALL_LOCALE` | Locale enabled in `locale.gen`. | `en_US.UTF-8` |
| `INSTALL_KEYMAP` | Console keymap. | `us` |
| `INSTALL_ROOT_PASSWORD` | Sets root password via `chpasswd`. | `changeme` |
| `INSTALL_USER` / `INSTALL_USER_PASSWORD` | Creates a wheel user with sudo. | `archer` / `changeme` |
| `INSTALL_PACKAGES` | Space-separated extra packages. | `nano vim git networkmanager` |
| `INSTALL_FILESYSTEM` | `ext4` or `btrfs` root filesystem. | `ext4` |
| `INSTALL_BOOT_MODE` | Bootloader target: `auto`, `uefi`, or `bios` (legacy GRUB). | `auto` |
| `INSTALL_BOOTLOADER` | Preferred bootloader: `auto`, `systemd-boot`, or `grub`. | `auto` |
| `BTRFS_MOUNT_OPTS` | Mount options when using Btrfs. | `compress=zstd,autodefrag` |
| `INSTALL_USE_LVM` | `true` to build an LVM stack for root. | `false` |
| `INSTALL_VG_NAME` / `INSTALL_LV_ROOT_NAME` | VG/LV identifiers when LVM is enabled. | `archvg` / `root` |
| `INSTALL_LAYOUT` | `single`, `btrfs-subvols`, or `lvm-home` presets. | `single` |
| `BTRFS_SUBVOLUMES` | Space-delimited `subvol:mountpoint` pairs for the subvol preset. | `@:/ @home:/home …` |
| `INSTALL_LV_HOME_NAME` | LV name for `/home` when using `lvm-home`. | `home` |
| `INSTALL_LV_ROOT_SIZE` / `INSTALL_LV_HOME_SIZE` | Sizing strings for split LVs (e.g., `70%FREE`, `40G`). | `70%FREE` / `100%FREE` |
| `NETWORK_BOOTSTRAP_ENABLE` | `true` to let the installer run `nmcli` before `ping` checks. | `false` |
| `NETWORK_TYPE` | `wifi`, `ethernet`, or `static` when bootstrapping. | `wifi` |
| `NETWORK_INTERFACE` | Optional interface hint (e.g., `wlan0`, `enp0s25`). | *empty* |
| `NETWORK_WIFI_SSID` / `NETWORK_WIFI_PSK` | Credentials for Wi-Fi bootstrap. | *empty* |
| `NETWORK_STATIC_IP` / `NETWORK_STATIC_GATEWAY` | CIDR IP and gateway for static mode. | *empty* |
| `NETWORK_STATIC_DNS` | DNS servers for static mode. | `8.8.8.8` |
| `INSTALL_DESKTOP_PROMPT` | `true` to ask which desktop to install at the end. | `true` |
| `INSTALL_DESKTOP_CHOICE` | Preselect `gnome`, `kde`, `xfce`, `sway`, or `none` (skip prompt). | *empty* |
| `INSTALL_DESKTOP_SCRIPT` | Path to the desktop helper script the installer should run. | `install-desktop.sh` |
| `INSTALL_DESKTOP_EXTRAS` | Extra packages passed to `install-desktop.sh`. | *empty* |
| `INSTALL_POST_SCRIPT` | Path to a post-install provisioning script executed inside the chroot. | *empty* |
| `INSTALL_POST_SCRIPT_ARGS` | Arguments passed to the provisioning script. | *empty* |

Adjust the functions in `install-arch.sh` if you need LVM, Btrfs, custom partitioning, or different bootloader behavior—the script is structured so each concern stays isolated.

## Desktop add-on script

If `install-desktop.sh` sits next to `install-arch.sh` (or you point `INSTALL_DESKTOP_SCRIPT` at it), the installer will ask whether to run it immediately and copy it into the chroot for you. Select `none` to skip or set `INSTALL_DESKTOP_PROMPT=false` / `INSTALL_DESKTOP_CHOICE=none` to keep things headless.

After rebooting into the installed system, you can rerun `install-desktop.sh` manually whenever you like to pull in a desktop environment + display manager combo. Examples:

```bash
chmod +x install-desktop.sh
DESKTOP_ENV=gnome ./install-desktop.sh             # GNOME + GDM
DESKTOP_ENV=kde DESKTOP_EXTRAS="firefox flatpak" ./install-desktop.sh
```

Supported values for `DESKTOP_ENV` today: `gnome`, `kde` (Plasma), `xfce`, `cinnamon`, `mate`, `budgie`, `lxqt`, `sway` (Wayland + greetd), and `i3`. Add extra packages via `DESKTOP_EXTRAS` or tweak `PACMAN_FLAGS` if you prefer to confirm each install.

## Safety notes

- The script **wipes** the chosen disk. Double-check the `lsblk` output and confirmation prompt before typing `YES`.
- Swapfile creation only prepares the file and fstab entry; it is not activated inside the live ISO to keep cleanup simple.
- Always rotate the default passwords immediately after the first boot.
