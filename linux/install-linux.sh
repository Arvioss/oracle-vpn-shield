#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "▶ Installing Oracle VPN Shield for Linux..."

mkdir -p /home/arvioss/.oracle-vpn
mkdir -p /home/arvioss/.config/systemd/user
mkdir -p /home/arvioss/bin

cp "$SCRIPT_DIR/http_socks_bridge.py" /home/arvioss/.oracle-vpn/
cp "$SCRIPT_DIR/vpn_daemon.sh" /home/arvioss/.oracle-vpn/
cp "$SCRIPT_DIR/oracle-vpn.service" /home/arvioss/.config/systemd/user/
cp "$SCRIPT_DIR/oracle-vpn" /home/arvioss/bin/

chmod +x /home/arvioss/.oracle-vpn/http_socks_bridge.py
chmod +x /home/arvioss/.oracle-vpn/vpn_daemon.sh
chmod +x /home/arvioss/bin/oracle-vpn

loginctl enable-linger arvioss 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now oracle-vpn.service

echo "✔ Installation complete! Use 'oracle-vpn status' or 'oracle-vpn test' to verify."
