#!/bin/bash

# Ensure XDG variables are defined
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

echo "--- Setting up Standard Paru (AUR Helper) ---"

# 1. Ensure Rust is installed and configured for XDG
# This avoids ~/.cargo and ~/.rustup in the home root
if ! command -v rustup &> /dev/null; then
    sudo pacman -S --needed rustup
    rustup default stable
fi

# Add Cargo to PATH if not already there
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export PATH="$CARGO_HOME/bin:$PATH"

# 2. Build Standard Paru (from source, not -bin)
BUILD_DIR="$XDG_CACHE_HOME/paru-build"
mkdir -p "$BUILD_DIR"
git clone https://aur.archlinux.org/paru.git "$BUILD_DIR/paru"
cd "$BUILD_DIR/paru"

# Build and Install
# This uses your system's /etc/makepkg.conf flags
makepkg -si --noconfirm

# 3. Configure Paru for XDG and Clean Operation
mkdir -p "$XDG_CONFIG_HOME/paru"
cat <<CONF > "$XDG_CONFIG_HOME/paru/paru.conf"
[options]
PgpFetch
Devel
Provides
PamacSubstitute
# Keep AUR clones in Cache, not Home
CloneDir = $XDG_CACHE_HOME/paru/clone
# Remove build dependencies after install to save space
CleanAfter
# Use the standard 'sudo' for privilege escalation
SudoLoop
CONF

# 4. Disable Debug Packages (Global Makepkg Change)
# This prevents Arch from creating '-debug' versions of AUR packages
if grep -q "options=(debug strip" /etc/makepkg.conf; then
    sudo sed -i 's/options=(debug strip/options=(!debug strip/' /etc/makepkg.conf
    echo "Disabled debug package generation in /etc/makepkg.conf"
fi

echo "--- AUR Setup Complete ---"
echo "Paru is now installed and configured for standard builds."
