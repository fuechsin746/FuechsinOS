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
* **Size:** 100% of available RAM (dynamic compression
