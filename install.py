#!/usr/bin/env python3
import os
import subprocess
import getpass
import shutil

# --- FüchsinOS Configuration & Branding ---
NAME_UTF8 = "FüchsinOS"
NAME_ASCII = "FuechsinOS"

def run(cmd):
    """Helper to run shell commands and exit on failure"""
    subprocess.run(cmd, shell=True, check=True)

def setup_wifi():
    print(f"--- {NAME_UTF8}: Dual-Band Wi-Fi Setup ---")
    try:
        # Ensure iwd is active for scanning
        subprocess.run("systemctl start iwd", shell=True, capture_output=True)
        device = "wlan0"
        
        print(f"Scanning for 2.4G/5G networks on {device}...")
        run(f"iwctl station {device} scan")
        subprocess.run(f"iwctl station {device} get-networks", shell=True)
        
        ssid = input("Enter SSID: ")
        password = getpass.getpass(f"Enter password for {ssid}: ")
        
        print(f"Connecting to {ssid}...")
        run(f"iwctl station {device} connect '{ssid}' --passphrase '{password}'")
        
        print("Waiting for connection...")
        subprocess.run("sleep 5", shell=True)
        return ssid
    except Exception as e:
        print(f"Wi-Fi setup failed: {e}. Attempting to continue...")
        return None

def get_user_input():
    print(f"\n--- {NAME_UTF8}: Deployment Configuration ---")
    hostname = input("Enter Hostname [arch-dell]: ") or "arch-dell"
    locale = input("Enter Locale [en_US.UTF-8]: ") or "en_US.UTF-8"
    full_name = input("Enter Full Name: ")
    username = input("Enter Login Username: ")
    while not username:
        username = input("Username cannot be empty: ")
    
    user_pass = getpass.getpass(f"Enter password for {username}: ")
    root_pass = getpass.getpass("Enter password for root: ")
    
    return {
        "DISK": "/dev/nvme0n1",
        "HOSTNAME": hostname,
        "LOCALE": locale,
        "FULL_NAME": full_name,
        "USER": username,
        "USER_PASS": user_pass,
        "ROOT_PASS": root_pass,
        "TIMEZONE": "America/Chicago"
    }

# Core Packages
PKGS = [
    "base", "linux", "linux-firmware", "base-devel", "git", "neovim", 
    "zsh", "amd-ucode", "btrfs-progs", "snapper", "zram-generator", 
    "refind", "networkmanager", "sudo", "reflector", "openssh", 
    "cpupower", "terminus-font", "iwd", "brightnessctl", 
    "power-profiles-daemon", "nano-syntax-highlighting"
]

def setup_disk(disk):
    print(f"--- Partitioning {disk} ---")
    run(f"sgdisk -Z {disk}")
    run(f"sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI {disk}")
    run(f"sgdisk -n 2:0:0 -t 2:8300 -c 2:ROOT {disk}")
    
    run(f"mkfs.vfat -F32 {disk}p1")
    run(f"mkfs.btrfs -f -L ROOT {disk}p2")
    
    run(f"mount {disk}p2 /mnt")
    for sub in ["@", "@home", "@log", "@pkg", "@snapshots"]:
        run(f"btrfs subvolume create /mnt/{sub}")
    run("umount /mnt")
    
    # Mount with optimized Btrfs flags for NVMe/Ryzen
    opts = "noatime,compress=zstd:3,ssd,discard=async"
    run(f"mount -o {opts},subvol=@ {disk}p2 /mnt")
    
    os.makedirs("/mnt/boot", exist_ok=True)
    run(f"mount {disk}p1 /mnt/boot")
    
    for sub, path in {"@home":"/home", "@log":"/var/log", "@pkg":"/var/cache/pacman/pkg", "@snapshots":"/.snapshots"}.items():
        full_path = f"/mnt{path}"
        os.makedirs(full_path, exist_ok=True)
        run(f"mount -o {opts},subvol={sub} {disk}p2 {full_path}")

def unified_chroot_setup(config, ssid):
    chroot_script = f"""
# 1. Branding & Localization
cat <<EOF > /etc/os-release
NAME="{NAME_UTF8}"
PRETTY_NAME="{NAME_UTF8} (Rolling)"
ID=fuechsinos
ID_LIKE=arch
ANSI_COLOR="38;2;203;166;247"
HOME_URL="https://github.com/fuechsin746/FuechsinOS"
EOF

echo "{NAME_ASCII} (\l)" > /etc/issue

ln -sf /usr/share/zoneinfo/{config['TIMEZONE']} /etc/localtime
hwclock --systohc
echo "{config['LOCALE']} UTF-8" >> /etc/locale.gen
locale-gen
echo "{config['HOSTNAME']}" > /etc/hostname
echo -e "KEYMAP=us\\nFONT=ter-v22n" > /etc/vconsole.conf

# 2. Pacman & Nano UI
sed -i 's/^#Color/Color\\nILoveCandy/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
echo 'include "/usr/share/nano/*.nanorc"' >> /etc/nanorc
echo 'include "/usr/share/nano-syntax-highlighting/*.nanorc"' >> /etc/nanorc

# 3. mkinitcpio (Systemd Hooks)
sed -i 's/HOOKS=(base udev/HOOKS=(systemd sd-vconsole/' /etc/mkinitcpio.conf
mkinitcpio -P

# 4. User Creation & Perms
useradd -m -G wheel -s /usr/bin/zsh -c "{config['FULL_NAME']}" {config['USER']}
echo "root:{config['ROOT_PASS']}" | chpasswd
echo "{config['USER']}:{config['USER_PASS']}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Critical fix for XDG Permission Errors
chown -R {config['USER']}:{config['USER']} /home/{config['USER']}

# 5. User-Space Setup
sudo -i -u {config['USER']} bash <<USEREOF
    export HOME=/home/{config['USER']}
    export XDG_CONFIG_HOME=\\$HOME/.config
    export ZDOTDIR=\\$HOME/.config/zsh
    
    mkdir -p \\$XDG_CONFIG_HOME/{{zsh,nvim,npm,pip,paru,gnupg}}
    mkdir -p \\$HOME/.local/{{share/cargo,share/rustup,bin}}

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

    cat <<EOF2 > \\$ZDOTDIR/.zshrc
set -opt prompt_subst
function parse_git() {{ git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\\\\1)/' }}
PROMPT='%F{{green}}%n@%m%f:%F{{blue}}%~%f%F{{cyan}}\$(parse_git)%f %# '
export PATH="\\$HOME/.local/bin:\\$HOME/.local/share/cargo/bin:\\$PATH"
EOF2

    cd /tmp && git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin && makepkg -si --noconfirm
USEREOF

# 6. Boot & Hardware
systemctl enable NetworkManager sshd reflector.timer btrfs-scrub@-.timer power-profiles-daemon
refind-install
PARTUUID=\\$(blkid -s PARTUUID -o value {config['DISK']}p2)
cat <<EOF > /boot/refind_linux.conf
"Boot {NAME_ASCII}"  "rw root=PARTUUID=\\$PARTUUID rootflags=subvol=@ quiet amd_pstate=active"
"Boot {NAME_ASCII} (Terminal)" "rw root=PARTUUID=\\$PARTUUID rootflags=subvol=@ amd_pstate=active"
EOF

# 7. Wi-Fi Migration
echo -e "[device]\\nwifi.backend=iwd" >> /etc/NetworkManager/NetworkManager.conf
if [ -n "{ssid}" ]; then
    mkdir -p /var/lib/iwd
    cp /var/lib/iwd/{ssid}.psk /var/lib/iwd/ 2>/dev/null || true
fi
"""
    with open("/mnt/final_setup.sh", "w") as f:
        f.write(chroot_script)
    run("arch-chroot /mnt bash /final_setup.sh")
    os.remove("/mnt/final_setup.sh")

if __name__ == "__main__":
    current_ssid = setup_wifi()
    CONFIG = get_user_input()
    setup_disk(CONFIG['DISK'])
    run(f"pacstrap -K /mnt {' '.join(PKGS)}")
    run("genfstab -U /mnt >> /mnt/etc/fstab")
    unified_chroot_setup(CONFIG, current_ssid)
    print(f"\n--- {NAME_UTF8} Successfully Installed. Reboot and remove USB. ---")
