# FüchsinOS | Arch Linux Technical Manual

A minimalist, **XDG-compliant** Arch Linux deployment optimized for **AMD Ryzen 7320U** hardware with **Btrfs** and **rEFInd**.

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

---

## 📂 XDG Base Directory Enforcement
This system strictly follows the XDG specification to keep `$HOME` clean. Global variables are defined in `/etc/environment`.

* **Config:** `~/.config` (e.g., `ZDOTDIR` is `~/.config/zsh`)
* **Cache:** `~/.cache` (e.g., `paru` build artifacts)
* **Data:** `~/.local/share` (e.g., `cargo`, `rustup`)
* **State:** `~/.local/state` (e.g., `zsh_history`)

---

## 🛠️ Maintenance & Recovery

### Btrfs Health
* **Scrub:** Automated monthly via `btrfs-scrub@-.timer`. Checks for data silent corruption.
* **Trim:** Automated weekly via `fstrim.timer`. Maintains NVMe performance.
* **Cleanup:** `paccache.timer` (from `pacman-contrib`) keeps only the last 3 versions of installed packages.

### Snapper Rollback Procedure
If the system becomes unstable or
