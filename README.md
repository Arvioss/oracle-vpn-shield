# 🛡️ Oracle Cloud 24/7 VPN & Privacy Shield

A 24/7 high-speed background VPN and proxy barrier that routes all internet and DNS traffic through your Oracle Cloud VPS (`161.118.166.96`), masking your real IP address and preventing leaks across both **Windows Host** and **Linux VMs**.

---

## 🚀 Quick Setup for Windows PowerShell (Host Computer)

Clone this private repository in your Windows PowerShell terminal and run the 1-click installer:

```powershell
# 1. Clone repository
git clone https://github.com/Arvioss/oracle-vpn-shield.git
cd oracle-vpn-shield\windows

# 2. Run 1-Click Installer (starts VPN + registers 24/7 autostart on boot)
powershell.exe -ExecutionPolicy Bypass -File .\install-windows.ps1
```

### Windows Management Commands

Run these inside `oracle-vpn-shield\windows`:

```powershell
# Check VPN status and verify masked IP
powershell.exe -ExecutionPolicy Bypass -File .\oracle-vpn.ps1 status

# Run connectivity and DNS leak test
powershell.exe -ExecutionPolicy Bypass -File .\oracle-vpn.ps1 test

# Stop VPN (reverts Windows proxy to direct)
powershell.exe -ExecutionPolicy Bypass -File .\oracle-vpn.ps1 stop

# Start VPN
powershell.exe -ExecutionPolicy Bypass -File .\oracle-vpn.ps1 start

# Remove autostart on boot
powershell.exe -ExecutionPolicy Bypass -File .\oracle-vpn.ps1 uninstall-autostart
```

---

## 🐧 Setup for Linux (VM / Server)

```bash
git clone https://github.com/Arvioss/oracle-vpn-shield.git
cd oracle-vpn-shield/linux
chmod +x install-linux.sh
./install-linux.sh
```

### Linux Management Commands

```bash
oracle-vpn status   # View active status and IP
oracle-vpn test     # Run full connectivity test
oracle-vpn stop     # Stop VPN daemon
oracle-vpn start    # Start VPN daemon
oracle-vpn logs     # View live background logs
```

---

## 🔒 Security Features & Safe Barrier

- **24/7 Persistence**: Starts automatically upon boot/login and auto-reconnects if network connection drops.
- **Fail-Closed Barrier**: If the remote tunnel drops, requests reject immediately without leaking your real ISP IP.
- **DNS Leak Prevention**: All DNS queries are resolved remotely by the Oracle Cloud server via `socks5h`.
- **System-Wide Masking**: Automatically configures Windows WinINet Proxy / GNOME Proxy so all web browsers (Chrome, Edge, Firefox, Brave), apps, games, and terminal commands are masked.
- **Dedicated Private Key**: Uses the pre-configured Oracle VPS key in `keys/miracle-private.key`.
