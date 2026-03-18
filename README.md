# FüchsinOS | Arch Linux Technical Manual

A minimalist, **XDG-compliant** Arch Linux deployment optimized for **AMD Ryzen 7320U** hardware with **Btrfs**, **rEFInd**, and **zram**.

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

### Memory Optimization (zram)
To maximize the 8GB RAM on the Ryzen 7320U, the system utilizes `zram-generator`:
* **Device:** `/dev/zram0`
* **Algorithm:** `zstd` (high compression ratio)
* **Size:** 100% of available RAM (dynamic compression)
* **Priority:** 100 (ensures zram is used before disk-based swap)

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
* **Cleanup:** `paccache.timer` keeps only the last 3 versions of installed packages.

### Snapper Rollback Procedure
If the system becomes unstable or fails to boot:
1.  **Reboot** and select **"Boot from Snapshot (ID 1)"** in the rEFInd menu.
2.  Log in and identify the snapshot ID you wish to restore:
    ```bash
    snapper list
    ```
3.  Execute the rollback (replaces current `@` with selected snapshot):
    ```bash
    sudo snapper-rollback <ID>
    ```
4.  **Reboot** into the restored system.

---

## 🚀 Terminal Environment
* **Shell:** `zsh` (Default for Root and User).
* **Plugins:** `zsh-syntax-highlighting`, `zsh-autosuggestions` (Sourced via `/usr/share/zsh/plugins/`).
* **AUR Helper:** `paru` (Configured for standard source builds, no-debug symbols, and XDG compliance).
* **User Dirs:** Standard folders (`Downloads`, `Documents`, etc.) are managed by `xdg-user-dirs`.

---

### Useful Commands
* **Check Swap/zram:** `zramctl` or `swapon --show`
* **Take Snapshot:** `snapper -c root create -d "Before major change"`
* **Search AUR:** `paru -Ss <package>`
* **Check Btrfs Space:** `sudo btrfs filesystem usage /`
