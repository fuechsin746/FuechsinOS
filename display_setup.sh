#!/bin/bash
sudo mkdir -p /etc/greetd
cat <<EOF | sudo tee /etc/greetd/config.toml
[terminal]
vt = 1
[default_session]
command = "tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop' --theme 'border=magenta;text=cyan'"
user = "greeter"
EOF
sudo systemctl enable greetd.service
