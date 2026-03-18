#!/bin/bash
sudo pacman -S --needed ttf-fira-code ttf-firacode-nerd

# Kitty Theme
mkdir -p "$XDG_CONFIG_HOME/kitty"
cat <<EOF > "$XDG_CONFIG_HOME/kitty/kitty.conf"
font_family Fira Code Nerd Font
font_size 11.0
window_padding_width 10
foreground #CDD6F4
background #1E1E2E
active_tab_background #CBA6F7
color5 #CBA6F7
EOF

# Rofi Theme (Minimal snippet)
mkdir -p "$XDG_CONFIG_HOME/rofi"
cat <<EOF > "$XDG_CONFIG_HOME/rofi/config.rasi"
configuration { modi: "drun"; show-icons: true; terminal: "kitty"; }
@theme "/dev/null"
* { bg: #1e1e2e; fg: #cdd6f4; mauve: #cba6f7; font: "Fira Code Nerd Font 12"; }
window { border: 2px; border-color: @mauve; background-color: @bg; }
element selected { text-color: @mauve; }
EOF
