#!/bin/bash
# FüchsinOS - Core Installation

DISK="/dev/nvme0n1"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"

read -p "Enter username: " USERNAME
read -s -p "Enter password for $USERNAME: " USER_PASS; echo
read -s -p "Enter root password: " ROOT_PASS; echo

echo "--- Partitioning & Formatting ---"
sgdisk -Z $DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI $DISK
sgdisk -n 2:0:0     -t 2:8300 -c 2:ARCH $DISK

mkfs.fat -F 32 "${DISK}p1"
mkfs.btrfs -L ARCH -f "${DISK}p2"

echo "--- Creating Btrfs Subvolumes ---"
mount "${DISK}p2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
umount /mnt

echo "--- Mounting Optimized Filesystem ---"
SV_OPTS="noatime,compress=zstd,ssd,discard=async,subvol="
mount -o ${SV_OPTS}@ "${DISK}p2" /mnt
mkdir -p /mnt/{home,.snapshots,var/log,efi,boot}
mount -o ${SV_OPTS}@home "${DISK}p2" /mnt/home
mount -o ${SV_OPTS}@snapshots "${DISK}p2" /mnt/.snapshots
mount -o ${SV_OPTS}@var_log "${DISK}p2" /mnt/var/log
mount "${DISK}p1" /mnt/efi
mkdir -p /mnt/efi/EFI/archlinux
mount --bind /mnt/efi/EFI/archlinux /mnt/boot

echo "--- Pacstrap & Chroot ---"
pacstrap -K /mnt base base-devel linux linux-firmware amd-ucode btrfs-progs \
    nano networkmanager refind git pacman-contrib zsh zsh-completions \
    zsh-syntax-highlighting zsh-autosuggestions sudo xdg-user-dirs \
    zram-generator power-profiles-daemon greetd greetd-tuigreet

genfstab -U /mnt >> /mnt/etc/fstab
echo "/efi/EFI/archlinux /boot none defaults,bind 0 0" >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "arch-minimal" > /etc/hostname

systemctl enable NetworkManager paccache.timer btrfs-scrub@-.timer fstrim.timer power-profiles-daemon

# zram Config
cat <<ZRAM > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
ZRAM

# Global XDG Environment
cat <<XDG >> /etc/environment
XDG_CONFIG_HOME=\$HOME/.config
XDG_CACHE_HOME=\$HOME/.cache
XDG_DATA_HOME=\$HOME/.local/share
XDG_STATE_HOME=\$HOME/.local/state
ZDOTDIR=\$HOME/.config/zsh
XDG

# User & Sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
useradd -m -G wheel -s /usr/bin/zsh $USERNAME
echo "$USERNAME:$USER_PASS" | chpasswd
echo "root:$ROOT_PASS" | chpasswd

# Zsh Skeleton
mkdir -p /etc/skel/.config/zsh
cat <<ZSH > /etc/skel/.config/zsh/.zshrc
[ -f /usr/bin/xdg-user-dirs-update ] && xdg-user-dirs-update
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
HISTFILE=\$XDG_STATE_HOME/zsh/history
mkdir -p "\$(dirname "\$HISTFILE")"
PROMPT='%n@%m %1~ %# '
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH
cp -r /etc/skel/.config /root/.config

# rEFInd
refind-install --usedefault "${DISK}p1" --alldrivers
cat <<CONF > /boot/refind_linux.conf
"Standard"  "rw root=PARTLABEL=ARCH rootflags=subvol=@ initrd=\amd-ucode.img initrd=\initramfs-linux.img"
"Terminal"  "rw root=PARTLABEL=ARCH rootflags=subvol=@ initrd=\amd-ucode.img initrd=\initramfs-linux.img systemd.unit=multi-user.target"
CONF
EOF
