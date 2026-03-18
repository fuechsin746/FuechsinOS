# FüchsinOS | Arch Linux Technical Manual

A minimalist, **XDG-compliant** Arch Linux deployment optimized for **AMD Ryzen 7320U** hardware. Built with **Btrfs**, **rEFInd**, **zram**, and the **Catppuccin Mocha Mauve** aesthetic.

---

## 🏗️ System Architecture

### Partition & Mount Layout
| Mount Point | Device/Subvolume | Options | Description |
| :--- | :--- | :--- | :--- |
| `/` | `subvol=@` | `zstd, ssd, discard=async` | Root Filesystem |
| `/home` | `subvol=@home` | `zstd, ssd, discard=async` | User Data |
| `/.snapshots` | `subvol=@snapshots` | `zstd, ssd, discard=async` | Snapper Snapshots |
| `/var/log` | `subvol=@var_log` | `zstd, ssd, discard=async` | Persistent Logs |
| `/efi` | `/dev/nvme0n1p1` | `umask=0077` | EFI System Partition (ESP) |
| `/boot` | `bind:/efi/EFI/archlinux` | `bind` | Kernel & Initramfs Storage |

### Memory & Power Optimization
* **zram:** Managed by `zram-generator`. Uses `zstd` compression at 100% RAM capacity with Priority 100.
* **Power Management:** `power-profiles-daemon` (Use `powerprofilesctl` to switch modes).
* **Audio:** Full **PipeWire** stack (PipeWire-Pulse, PipeWire-Alsa, Wireplumber).

---

## 📂 XDG Base Directory Enforcement
This system strictly follows the XDG specification to keep `$HOME` clean. Environment variables are defined in `/etc/environment`.

* **Config:** `~/.config` (e.g., `ZDOTDIR` is `~/.config/zsh`)
* **Cache:** `~/.cache` (e.g., `paru` build artifacts)
* **Data:** `~/.local/share` (e.g., `cargo`, `rustup`)
* **State:** `~/.local/state` (e.g., `zsh_history`)

---

## 🛠️ Maintenance & Recovery

### Btrfs Health
* **Scrub:** Automated monthly via `btrfs-scrub@-.timer`.
* **Trim:** Automated weekly via `fstrim.timer`.
* **Cleanup:** `paccache.timer` keeps only the last 3 versions of installed packages.

### Snapper Rollback Procedure
If the system becomes unstable:
1.  **Reboot** and select **"Snapshot (ID 1)"** in the rEFInd menu.
2.  Log in and identify the target snapshot: `snapper list`.
3.  Execute rollback: `sudo snapper-rollback <ID>`.
4.  **Reboot** into the restored `@` subvolume.

---

## 🚀 Desktop Environment (Hyprland + UWSM)
* **Session Manager:** `uwsm` (Universal Wayland Session Manager).
* **Login Manager:** `greetd` + `tuigreet`.
* **Status Bar:** `Waybar` with custom **zram** and **Btrfs** modules.
* **Colors:** Catppuccin Mocha with **Mauve** accents.

### Core Keybindings (`SUPER` = Windows Key)
| Keybind | Action |
| :--- | :--- |
| `SUPER + RETURN` | Launch Kitty Terminal |
| `SUPER + B` | Launch Firefox (Wayland Native) |
| `SUPER + R` | App Launcher (Rofi) |
| `SUPER + Q` | Close Active Window |
| `SUPER + 1-3` | Switch Workspaces |
| `Volume Keys` | Adjust Audio via Wireplumber |

---

### Useful Commands
* **Check zram Status:** `zramctl`
* **AUR Management:** `paru -S <package>` (No-debug builds)
* **Permission Requests:** Handled by `polkit-kde-agent` (GUI prompt).
* **Firefox XDG:** Launched via `firefox-xdg` wrapper to ensure Wayland/XDG compliance.
