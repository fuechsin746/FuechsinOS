#!/bin/bash

# Configuration Variables
DISK="/dev/nvme0n1"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"

# Prompt for User details
read -p "Enter username: " USERNAME
read -s -p "Enter password for $USERNAME: " USER_PASS
echo
read -s -p "Enter root password: " ROOT_PASS
echo

echo "--- Starting Minimal Arch Installation ---"

# 1. Partitioning & Formatting
sgdisk -Z $DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI $DISK
sgdisk -n 2:0:0     -t 2:8300 -c 2:ARCH $DISK

mkfs.fat -F 32 "${DISK}p1"
mkfs.btrfs -L ARCH -f "${DISK}p2"

# 2. Btrfs Subvolumes
mount "${DISK}p2" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
umount /mnt

# 3. Mounting with Optimization
SV_OPTS="noatime,compress=zstd,ssd,discard=async,subvol="
mount -o ${SV_OPTS}@ "${DISK}p2" /mnt
mkdir -p /mnt/{home,.snapshots,var/log,efi,boot}
mount -o ${SV_OPTS}@home "${DISK}p2" /mnt/home
mount -o ${SV_OPTS}@snapshots "${DISK}p2" /mnt/.snapshots
mount -o ${SV_OPTS}@var_log "${DISK}p2" /mnt/var/log

# 4. EFI and Bind Mount
mount "${DISK}p1" /mnt/efi
mkdir -p /mnt/efi/EFI/archlinux
mount --bind /mnt/efi/EFI/archlinux /mnt/boot

# 5. Pacstrap (Added zram-generator)
pacstrap -K /mnt base base-devel linux linux-firmware amd-ucode btrfs-progs \
    nano networkmanager refind git pacman-contrib zsh zsh-completions \
    zsh-syntax-highlighting zsh-autosuggestions sudo xdg-user-dirs zram-generator

# 6. Fstab
genfstab -U /mnt >> /mnt/etc/fstab
echo "/efi/EFI/archlinux /boot none defaults,bind 0 0" >> /mnt/etc/fstab

# 7. Chroot Configuration
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "arch-minimal" > /etc/hostname

# Enable Services
systemctl enable NetworkManager
systemctl enable paccache.timer
systemctl enable btrfs-scrub@-.timer
systemctl enable fstrim.timer

# 8. zram-generator Configuration
# Setup zram0 with zstd compression and 100% of RAM capacity
cat <<ZRAM > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAM

# 9. XDG Base Directory Enforcement (Global)
cat <<XDG >> /etc/environment
XDG_CONFIG_HOME=\$HOME/.config
XDG_CACHE_HOME=\$HOME/.cache
XDG_DATA_HOME=\$HOME/.local/share
XDG_STATE_HOME=\$HOME/.local/state
ZDOTDIR=\$HOME/.config/zsh
XDG >> /etc/environment

# 10. User and Sudo Configuration
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
useradd -m -G wheel -s /usr/bin/zsh $USERNAME
echo "$USERNAME:$USER_PASS" | chpasswd
echo "root:$ROOT_PASS" | chpasswd
chsh -s /usr/bin/zsh root

# 11. Zsh XDG Template Setup
mkdir -p /etc/skel/.config/zsh
cat <<ZSH > /etc/skel/.config/zsh/.zshrc
# XDG User Dirs Initialization
[ -f /usr/bin/xdg-user-dirs-update ] && xdg-user-dirs-update

# Basic Zsh Config
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
setopt autocd nomatch
HISTFILE=\$XDG_STATE_HOME/zsh/history
mkdir -p "\$(dirname "\$HISTFILE")"
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory

# Basic Prompt
PROMPT='%n@%m %1~ %# '

# Plugins (Manual sourcing)
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH

# Distribute Zsh config
mkdir -p /root/.config/zsh
cp /etc/skel/.config/zsh/.zshrc /root/.config/zsh/.zshrc
mkdir -p /home/$USERNAME/.config/zsh
cp /etc/skel/.config/zsh/.zshrc /home/$USERNAME/.config/zsh/.zshrc
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# 12. rEFInd Installation & Config
refind-install --usedefault "${DISK}p1" --alldrivers
cat <<CONF > /boot/refind_linux.conf
"Boot with standard options"  "rw root=PARTLABEL=ARCH rootflags=subvol=@ initrd=\amd-ucode.img initrd=\initramfs-linux.img"
"Boot to terminal"            "rw root=PARTLABEL=ARCH rootflags=subvol=@ initrd=\amd-ucode.img initrd=\initramfs-linux.img systemd.unit=multi-user.target"
CONF
EOF

echo "--- Installation Complete ---"
