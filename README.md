# FüchsinOS | Arch Linux Technical Manual

A minimalist, **XDG-compliant** Arch Linux deployment optimized for **AMD Ryzen 7320U** hardware with **Btrfs**, **rEFInd**, **zram**, and **Power Management**.

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
* **zram:** `zram-generator` creates a `zstd` compressed swap in RAM (100% capacity).
* **Power Management:** `power-profiles-daemon` enables `power-saver`, `balanced`, and `performance` modes (interact via `powerprofilesctl`).

---

## 📂 XDG Base Directory Enforcement
Global variables are defined in `/etc/environment`.

* **Config:** `~/.config` (e.g., `ZDOTDIR` is `~/.config/zsh`)
* **Cache:** `~/.cache` (e.g., `paru` build artifacts)
* **Data:** `~/.local/share` (e.g., `cargo`, `rustup`)
* **State:** `~/.local/state` (e.g., `zsh_history`)

---

## 🛠️ Maintenance & Recovery

### Btrfs Health
* **Scrub:** Automated monthly via `btrfs-scrub@-.timer`.
* **Trim:** Automated weekly via `fstrim.timer`.
* **Cleanup:** `paccache.timer` keeps the last 3 versions of packages.

### Snapper Rollback Procedure
1.  **Reboot** and select **"Boot from Snapshot (ID 1)"** in rEFInd.
2.  Log in and run: `snapper list`.
3.  Execute rollback: `sudo snapper-rollback <ID>`.
4.  **Reboot**.

---

## 🚀 Terminal Environment
* **Shell:** `zsh` (XDG compliant).
* **Plugins:** `zsh-syntax-highlighting`, `zsh-autosuggestions`.
* **AUR Helper:** `paru` (Source builds, no-debug, CleanAfter).

---

### Useful Commands
* **Check Power Mode:** `powerprofilesctl`
* **Check Swap/zram:** `zramctl`
* **Take Snapshot:** `snapper -c root create -d "Description"`
