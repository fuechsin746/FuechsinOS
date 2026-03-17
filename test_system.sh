#!/usr/bin/env zsh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- FüchsinOS System Validation ---${NC}"

# 1. Check ZDOTDIR and XDG
echo -n "Checking ZDOTDIR: "
if [[ "$ZDOTDIR" == "$HOME/.config/zsh" ]]; then
    echo -e "${GREEN}PASS${NC} ($ZDOTDIR)"
else
    echo -e "${RED}FAIL${NC} (Value is: $ZDOTDIR)"
fi

# 2. Check for "Dotfolder" Pollution in $HOME
echo -n "Checking for home directory pollution: "
STRAY_DIRS=$(ls -ad $HOME/.* 2>/dev/null | grep -E "\.(cargo|rustup|nvme|ssh|bash|zsh_history)" | xargs)
if [[ -z "$STRAY_DIRS" ]]; then
    echo -e "${GREEN}PASS${NC} (Home is clean)"
else
    echo -e "${RED}WARN${NC} (Stray folders found: $STRAY_DIRS)"
fi

# 3. Verify Btrfs Subvolumes
echo -n "Verifying Btrfs mount points: "
if mount | grep -q "subvol=@home"; then
    echo -e "${GREEN}PASS${NC} (@home is mounted)"
else
    echo -e "${RED}FAIL${NC} (@home NOT found)"
fi

# 4. Check Rust/Cargo XDG Paths
echo -n "Verifying Cargo Location: "
if [[ "$CARGO_HOME" == *".local/share/cargo" ]]; then
    echo -e "${GREEN}PASS${NC} ($CARGO_HOME)"
else
    echo -e "${RED}FAIL${NC} ($CARGO_HOME)"
fi

# 5. Test Panic Alias
echo -n "Testing 'panic' alias: "
if alias panic > /dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} (Alias not found)"
fi

# 6. Check Pacman UI
echo -n "Checking Pacman ILoveCandy: "
if grep -q "ILoveCandy" /etc/pacman.conf; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

echo -e "${GREEN}--- Validation Complete ---${NC}"
