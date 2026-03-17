#!/usr/bin/env python3
import os
import subprocess
import getpass
import shutil

# --- FüchsinOS Configuration & Branding ---
NAME_UTF8 = "FüchsinOS"
NAME_ASCII = "FuechsinOS"

def run(cmd):
    subprocess.run(cmd, shell=True, check=True)

def setup_wifi():
    print(f"--- {NAME_UTF8}: Dual-Band Wi-Fi Setup ---")
    try:
        subprocess.run("systemctl start iwd", shell=True, capture_output=True)
        device = "wlan0"
        run(f"iwctl station {device} scan")
        subprocess.run(f"iwctl station {device} get-networks", shell=True)
        ssid = input("Enter SSID: ")
        password = getpass.getpass(f"Enter password for {ssid}: ")
        run(f"iwctl station {device} connect '{ssid}' --passphrase '{password}'")
        subprocess.run("sleep 3", shell=True)
        return ssid
    except Exception as e:
        print(f"Wi-Fi setup failed: {e}")
        return None

def get_user_input():
    print(f"\n--- {NAME_UTF8}: Deployment Configuration ---")
    hostname = input("Enter Hostname [arch-dell]: ") or "arch-dell"
    locale = input("Enter Locale [en_US.UTF-8]: ") or "en_US.UTF-8"
    full_name = input("Enter Full Name: ")
    username = input("Enter Login Username: ")
    while not username:
        username = input("Username cannot be empty: ")

    while True:
        user_pass = getpass.getpass(f"Enter password for {username}: ")
        confirm_user = getpass.getpass("Confirm user password: ")
        if user_pass == confirm_user: break
        print("\033[31mPasswords do not match.\033[0m")

    while True:
        root_pass = getpass.getpass("Enter password for root: ")
        confirm_root = getpass.getpass("Confirm root password: ")
        if root_pass == confirm_root: break
        print("\033[31mPasswords do not match.\033[0m")
    
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
echo "{NAME_ASCII} (\\\\l)" > /etc/issue
ln -sf /usr/share/zoneinfo/{config['TIMEZONE']} /etc/localtime
hwclock --systohc
echo "{config['LOCALE']} UTF-8" >> /etc/locale.gen
locale-gen
echo "{config['HOSTNAME']}" > /etc/hostname
echo -e "KEYMAP=us\\nFONT=ter-v22n" > /etc/vconsole.conf

# 2. Pacman & Nano
sed -i 's/^#Color/Color\\nILoveCandy/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
echo 'include "/usr/share/nano/*.nanorc"' >> /etc/nanorc
echo 'include "/usr/share/nano-syntax-highlighting/*.nanorc"' >> /etc/nanorc

# 3. mkinitcpio
sed -i 's/HOOKS=(base udev/HOOKS=(systemd sd-vconsole/' /etc/mkinitcpio.conf
mkinitcpio -P

# 4. User
useradd -m -G wheel -s /usr/bin/zsh -c "{config['FULL_NAME']}" {config['USER']}
echo "root:{config['ROOT_PASS']}" | chpasswd
echo "{config['USER']}:{config['USER_PASS']}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
chown -R {config['USER']}:{config['USER']} /home/{config['USER']}

# 5. User-Space
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
alias panic="snapper list | tail -n 5"
echo -e "\\e[35m⚡ {NAME_UTF8} | Ryzen 3 7320U\\e[0m"
echo -n "● Snapshots: " && snapper list | tail -n +3 | wc -l | tr -d '\\n' && echo " entries"
echo -e "\\e[32m------------------------------------------\\e[0m"
EOF2
    cd /tmp && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --noconfirm
USEREOF

# 6. Boot & Hardware (rEFInd with Arch Icon)
systemctl enable NetworkManager sshd reflector.timer btrfs-scrub@-.timer power-profiles-daemon
refind-install
PARTUUID=\$(blkid -s PARTUUID -o value {config['DISK']}p2)
echo "\\"Boot {NAME_ASCII}\\" \\"rw root=PARTUUID=\$PARTUUID rootflags=subvol=@ quiet amd_pstate=active icon=/EFI/refind/icons/os_arch.png\\"" > /boot/refind_linux.conf

# 7. Wi-Fi
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
    print(f"\n--- {NAME_UTF8} Successfully Installed ---")
