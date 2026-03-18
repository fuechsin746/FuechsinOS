#!/bin/bash
sudo pacman -S --needed \
    hyprland uwsm waybar rofi-wayland kitty \
    firefox firefox-i18n-en-us \
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
    polkit-kde-agent xdg-desktop-portal-hyprland \
    pavucontrol network-manager-applet libva-mesa-driver

mkdir -p "$XDG_CONFIG_HOME/hypr/conf"
cat <<EOF > "$XDG_CONFIG_HOME/hypr/conf/env.conf"
env = MOZ_ENABLE_WAYLAND,1
env = MOZ_USE_XDG_DESKTOP_PORTAL,1
EOF

# Firefox Wrapper
sudo tee /usr/local/bin/firefox-xdg <<EOF
#!/bin/bash
export MOZ_ENABLE_WAYLAND=1
exec /usr/bin/firefox "\$@"
EOF
sudo chmod +x /usr/local/bin/firefox-xdg

# Modular Hyprland Keybinds
cat <<EOF > "$XDG_CONFIG_HOME/hypr/conf/keybinds.conf"
\$mainMod = SUPER
bind = \$mainMod, RETURN, exec, kitty
bind = \$mainMod, B, exec, firefox-xdg
bind = \$mainMod, Q, killactive, 
bind = \$mainMod, R, exec, rofi -show drun
binde = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
binde = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind  = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
EOF

# Main Hyprland
cat <<EOF > "$XDG_CONFIG_HOME/hypr/hyprland.conf"
source = ~/.config/hypr/conf/env.conf
source = ~/.config/hypr/conf/keybinds.conf
exec-once = /usr/lib/polkit-kde-agent-1
exec-once = uwsm app -- nm-applet --indicator
exec-once = uwsm app -- wireplumber
exec-once = uwsm app -- waybar
general { border_size = 2; col.active_border = rgba(cba6f7ee); layout = dwindle }
decoration { rounding = 10 }
EOF

uwsm setup
