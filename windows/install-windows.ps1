# 1-Click Installer for Windows Host
# Run in Windows PowerShell

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VpnScript = Join-Path $ScriptDir "oracle-vpn.ps1"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "     Oracle Cloud 24/7 VPN Installer for Windows    " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Check OpenSSH Client
Write-Host "Checking OpenSSH client on Windows..."
$ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue
if (-not $ssh) {
    Write-Host "Installing OpenSSH Client..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -ErrorAction SilentlyContinue
} else {
    Write-Host "✔ OpenSSH is installed." -ForegroundColor Green
}

# 2. Register Autostart Task
& powershell.exe -ExecutionPolicy Bypass -File "$VpnScript" install-autostart

# 3. Start VPN Immediately
& powershell.exe -ExecutionPolicy Bypass -File "$VpnScript" start

Start-Sleep -Seconds 3

# 4. Status Check
& powershell.exe -ExecutionPolicy Bypass -File "$VpnScript" status

Write-Host "`n✔ Setup Complete! Your Windows host computer is now protected." -ForegroundColor Green
Write-Host "Management commands:" -ForegroundColor Yellow
Write-Host "  powershell -File .\oracle-vpn.ps1 status"
Write-Host "  powershell -File .\oracle-vpn.ps1 stop"
Write-Host "  powershell -File .\oracle-vpn.ps1 start"
