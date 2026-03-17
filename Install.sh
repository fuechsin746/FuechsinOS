#!/bin/zsh

# --- FüchsinOS Configuration & Branding ---
NAME_UTF8="FüchsinOS"
NAME_ASCII="FuechsinOS"
LOG_PATH="/mnt/var/log/install.log"

# --- Helper Functions ---
log_exec() {
    local cmd="$1"
    echo "\n--- [$(date +'%Y-%m-%d %H:%M:%S')] Executing: $cmd ---" >> "$LOG_PATH"
    eval "$cmd" 2>&1 | tee -a "$LOG_PATH"
}

setup_wifi() {
    echo "--- $NAME_UTF8: Wi-Fi Network Selector ---"
    systemctl start iwd
    local device="wlan0"
    iwctl station "$device" scan
    sleep 2

    # Parse networks into a Zsh array
    local -a networks
    networks=(${(f)"$(iwctl station "$device" get-networks | sed '1,4d' | awk '{print $1}' | tr -d '>|*')" })

    if [[ ${#networks} -eq 0 ]]; then
        echo "No networks found. Manual entry required."
        read "ssid?Enter SSID: "
    else
        echo "\nAvailable Networks:"
        for i in {1..${#networks}}; do
            echo " [$i] ${networks[$i]}"
        done
        read "choice?Select network (1-${#networks}) or enter SSID manually: "
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#networks} )); then
            ssid="${networks[$choice]}"
        else
            ssid="$choice"
        fi
    fi

    echo -n "Enter password for $ssid: "
    read -s password
    echo
    iwctl station "$device" connect "$ssid" --passphrase "$password"
    sleep 3
    echo "$ssid"
}

# --- Main Logic ---
SSID=$(setup_wifi)

echo "\n--- $NAME_UTF8: Deployment Configuration ---"
read "HOSTNAME?Enter Hostname [arch-dell]: "
HOSTNAME=${HOSTNAME:-arch-dell}
read "FULL_NAME?Enter Full Name: "
read "USERNAME?Enter Login Username: "
read -s "USER_PASS?Enter password for $USERNAME: "; echo
read -s "ROOT_PASS?Enter password for root: "; echo

DISK="/dev/nvme0n1"
PKGS=(base linux linux-firmware base-devel git neovim zsh amd-ucode btrfs-progs snapper zram-generator refind networkmanager sudo reflector openssh cpupower terminus-font iwd brightnessctl power-profiles-daemon nano-syntax-highlighting)

# 1. Disk Setup
log_exec "sgdisk -Z $DISK"
log_exec "sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI $DISK"
log_exec "sgdisk -n 2:0:0 -t 2:8300 -c 2:ROOT $DISK"
log_exec "mkfs.vfat -F32 ${DISK}p1"
log_exec "mkfs.btrfs -f -L ROOT ${DISK}p2"

log_exec "mount ${DISK}p2 /mnt"
for sub in @ @home @log @pkg @snapshots; do
    log_exec "btrfs subvolume create /mnt/$sub"
done
log_exec "umount /mnt"

OPTS="noatime,compress=zstd:3,ssd,discard=async"
log_exec "mount -o $OPTS,subvol=@ ${DISK}p2 /mnt"
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
log_exec "mount ${DISK}p1 /mnt/boot"
log_exec "mount -o $OPTS,subvol=@home ${DISK}p2 /mnt/home"
log_exec "mount -o $OPTS,subvol=@log ${DISK}p2 /mnt/var/log"
log_exec "mount -o $OPTS,subvol=@pkg ${DISK}p2 /mnt/var/cache/pacman/pkg"
log_exec "mount -o $OPTS,subvol=@snapshots ${DISK}p2 /mnt/.snapshots"

# 2. Pacstrap
log_exec "pacstrap -K /mnt $PKGS"
log_exec "genfstab -U /mnt >> /mnt/etc/fstab"

# 3. Chroot Configuration
cat <<EOF > /mnt/final_setup.sh
#!/bin/zsh
# Branding
cat <<EOR > /etc/os-release
NAME="$NAME_UTF8"
ID=fuechsinos
ID_LIKE=arch
ANSI_COLOR="38;2;203;166;247"
HOME_URL="https://github.com/fuechsin746/FuechsinOS"
EOR

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "$HOSTNAME" > /etc/hostname
echo -e "KEYMAP=us\\nFONT=ter-v22n" > /etc/vconsole.conf

# XDG & Zsh
sed -i 's/SHELL=\\/bin\\/bash/SHELL=\\/usr\\/bin\\/zsh/' /etc/default/useradd
mkdir -p /etc/zsh
echo 'export ZDOTDIR="\$HOME/.config/zsh"' > /etc/zsh/zshenv

# Users
usermod -s /usr/bin/zsh root
useradd -m -G wheel -s /usr/bin/zsh -c "$FULL_NAME" $USERNAME
echo "root:$ROOT_PASS" | chpasswd
echo "$USERNAME:$USER_PASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Skeleton & .zshrc
mkdir -p /etc/skel/.config/zsh /etc/skel/.local/{share,bin} /root/.config/zsh
cat <<EOR2 > /etc/skel/.config/zsh/.zshrc
export XDG_CONFIG_HOME=\$HOME/.config
export XDG_DATA_HOME=\$HOME/.local/share
export ZDOTDIR=\$HOME/.config/zsh
export RUSTUP_HOME=\$XDG_DATA_HOME/rustup
export CARGO_HOME=\$XDG_DATA_HOME/cargo
export PATH="\$HOME/.local/bin:\$CARGO_HOME/bin:\$PATH"
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f %# '
alias panic="snapper list | tail -n 5"
echo -e "\\\e[35m⚡ $NAME_UTF8 | Ryzen 3 7320U\\\e[0m"
EOR2
cp /etc/skel/.config/zsh/.zshrc /root/.config/zsh/.zshrc
cp /etc/skel/.config/zsh/.zshrc /home/$USERNAME/.config/zsh/.zshrc
chown -R $USERNAME:$USERNAME /home/$USERNAME

# User-Space (Rust/Paru)
sudo -i -u $USERNAME zsh <<EOR3
    export RUSTUP_HOME=\\\$HOME/.local/share/rustup
    export CARGO_HOME=\\\$HOME/.local/share/cargo
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    cd /tmp && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --noconfirm
EOR3

# Bootloader
refind-install
PARTUUID=\$(blkid -s PARTUUID -o value ${DISK}p2)
echo "\"Boot $NAME_ASCII\" \"rw root=PARTUUID=\$PARTUUID rootflags=subvol=@ quiet amd_pstate=active icon=/EFI/refind/icons/os_arch.png\"" > /boot/refind_linux.conf

systemctl enable NetworkManager sshd reflector.timer btrfs-scrub@-.timer power-profiles-daemon
EOF

log_exec "arch-chroot /mnt zsh /final_setup.sh"
rm /mnt/final_setup.sh

# Wi-Fi Migration
if [[ -n "$SSID" ]]; then
    mkdir -p /mnt/var/lib/iwd
    cp "/var/lib/iwd/$SSID.psk" "/mnt/var/lib/iwd/"
fi

echo "\n--- $NAME_UTF8 Installed Successfully ---"
