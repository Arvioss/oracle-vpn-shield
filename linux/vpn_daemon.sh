#!/usr/bin/env bash
# Oracle Cloud 24/7 VPN & Proxy Daemon
# Maintained for arvioss

SERVER_USER="ubuntu"
SERVER_IP="161.118.166.96"
SSH_KEY="/home/arvioss/Downloads/miracle-private.key"
SOCKS_PORT=1080
HTTP_PORT=8080
BRIDGE_SCRIPT="/home/arvioss/.oracle-vpn/http_socks_bridge.py"

SSH_PID=""
BRIDGE_PID=""

cleanup() {
    echo "[VPN Daemon] Shutting down services..."
    if [ -n "$SSH_PID" ] && kill -0 "$SSH_PID" 2>/dev/null; then
        kill "$SSH_PID" 2>/dev/null
    fi
    if [ -n "$BRIDGE_PID" ] && kill -0 "$BRIDGE_PID" 2>/dev/null; then
        kill "$BRIDGE_PID" 2>/dev/null
    fi
    pkill -f "ssh -N -D 127.0.0.1:${SOCKS_PORT}" 2>/dev/null || true
    pkill -f "$BRIDGE_SCRIPT" 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

echo "[VPN Daemon] Starting Oracle Cloud VPN services..."

while true; do
    # 1. Start SSH SOCKS5 Tunnel if not running
    if [ -z "$SSH_PID" ] || ! kill -0 "$SSH_PID" 2>/dev/null; then
        echo "[VPN Daemon] Launching SSH SOCKS5 Tunnel on 127.0.0.1:${SOCKS_PORT} -> ${SERVER_IP}..."
        ssh -N -D "127.0.0.1:${SOCKS_PORT}" \
            -i "$SSH_KEY" \
            -o StrictHostKeyChecking=no \
            -o ServerAliveInterval=15 \
            -o ServerAliveCountMax=3 \
            -o ExitOnForwardFailure=yes \
            -o TCPKeepAlive=yes \
            -o Compression=yes \
            "${SERVER_USER}@${SERVER_IP}" &
        SSH_PID=$!
        sleep 1
    fi

    # 2. Start HTTP Bridge if not running
    if [ -z "$BRIDGE_PID" ] || ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
        echo "[VPN Daemon] Launching HTTP/HTTPS Proxy Bridge on 127.0.0.1:${HTTP_PORT}..."
        python3 "$BRIDGE_SCRIPT" &
        BRIDGE_PID=$!
        sleep 1
    fi

    sleep 5
done
