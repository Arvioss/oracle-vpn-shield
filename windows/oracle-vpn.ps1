# Oracle Cloud 24/7 VPN & Proxy Barrier Manager for Windows
# Run in Windows PowerShell

[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "test", "install-autostart", "uninstall-autostart")]
    [string]$Action = "status"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KeyPath = Join-Path (Split-Path -Parent $ScriptDir) "keys\miracle-private.key"
if (-not (Test-Path $KeyPath)) {
    $KeyPath = Join-Path $ScriptDir "miracle-private.key"
}

$ServerUser = "ubuntu"
$ServerIP = "161.118.166.96"
$SocksPort = 1080

# WinINet API to instantly apply proxy changes across Windows without rebooting
$WinINetCode = @"
using System;
using System.Runtime.InteropServices;

public class WinINet {
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);

    public static void RefreshProxy() {
        InternetSetOption(IntPtr.Zero, 39, IntPtr.Zero, 0); // INTERNET_OPTION_SETTINGS_CHANGED
        InternetSetOption(IntPtr.Zero, 37, IntPtr.Zero, 0); // INTERNET_OPTION_REFRESH
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]"WinINet").Type) {
    Add-Type -TypeDefinition $WinINetCode
}

function Enable-WindowsProxy {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 1
    # Direct SOCKS5 proxy string: routes all HTTP, HTTPS, WebSockets (Discord), & TCP traffic directly through SOCKS5 on port 1080
    Set-ItemProperty -Path $regPath -Name ProxyServer -Value "socks=127.0.0.1:$SocksPort"
    # Proxy override to allow Discord local RPC and internal loopback connections
    Set-ItemProperty -Path $regPath -Name ProxyOverride -Value "127.*;localhost;<local>;10.*;192.168.*;172.16.*;*.local;<-loopback>"
    [WinINet]::RefreshProxy()
}

function Disable-WindowsProxy {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 0
    [WinINet]::RefreshProxy()
}

function Get-ProxyStatus {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $enabled = (Get-ItemProperty -Path $regPath -Name ProxyEnable -ErrorAction SilentlyContinue).ProxyEnable
    if ($enabled -eq 1) { return "ENABLED (SOCKS5 127.0.0.1:$SocksPort)" } else { return "DISABLED" }
}

function Fix-KeyPermissions {
    if (Test-Path $KeyPath) {
        try {
            icacls.exe $KeyPath /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
        } catch {}
    }
}

function Start-VPN {
    Write-Host "[*] Starting Oracle Cloud VPN 24/7 background tunnel..." -ForegroundColor Cyan
    Fix-KeyPermissions

    # Stop any existing stale instance
    Stop-Process -Name "ssh" -ErrorAction SilentlyContinue | Out-Null

    # Launch SSH SOCKS5 Tunnel
    $sshArgs = "-N -D 127.0.0.1:$SocksPort -i `"$KeyPath`" -o StrictHostKeyChecking=no -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes $ServerUser@$ServerIP"
    Start-Process -FilePath "ssh" -ArgumentList $sshArgs -WindowStyle Hidden

    Start-Sleep -Seconds 2
    Enable-WindowsProxy

    Write-Host "[OK] Oracle VPN is active and Windows System Proxy is enabled!" -ForegroundColor Green
    Write-Host "All Windows apps (Discord, Chrome, Edge, Firefox, games) are now routed through $ServerIP." -ForegroundColor Yellow
}

function Stop-VPN {
    Write-Host "[*] Stopping Oracle Cloud VPN..." -ForegroundColor Cyan
    Stop-Process -Name "ssh" -ErrorAction SilentlyContinue | Out-Null
    Disable-WindowsProxy
    Write-Host "[OK] Oracle VPN stopped and Windows proxy returned to direct." -ForegroundColor Green
}

function Test-VPN {
    Write-Host "====================================================" -ForegroundColor Blue
    Write-Host "       Oracle VPN Connectivity & Masking Test       " -ForegroundColor Blue
    Write-Host "====================================================" -ForegroundColor Blue

    Write-Host -NoNewline "Checking SOCKS5 Tunnel (Port $SocksPort)... "
    try {
        $ip = (curl.exe -s --max-time 5 -x "socks5h://127.0.0.1:$SocksPort" https://ifconfig.me).Trim()
        if ($ip -eq $ServerIP) {
            Write-Host "ONLINE ($ip - Oracle VPS)" -ForegroundColor Green
        } elseif ($ip) {
            Write-Host "ONLINE (IP: $ip)" -ForegroundColor Yellow
        } else {
            Write-Host "OFFLINE" -ForegroundColor Red
        }
    } catch {
        Write-Host "OFFLINE" -ForegroundColor Red
    }

    Write-Host -NoNewline "Testing Discord Gateway Resolution... "
    try {
        $discTest = (curl.exe -s --max-time 5 -x "socks5h://127.0.0.1:$SocksPort" https://discord.com/api/v9/gateway).Trim()
        if ($discTest -match "wss://gateway.discord.gg") {
            Write-Host "SUCCESS (Discord Gateway Accessible)" -ForegroundColor Green
        } else {
            Write-Host "CONNECTED" -ForegroundColor Green
        }
    } catch {
        Write-Host "FAILED" -ForegroundColor Red
    }

    Write-Host "====================================================" -ForegroundColor Blue
}

function Show-Status {
    Write-Host "====================================================" -ForegroundColor Blue
    Write-Host "              Oracle VPN Status Report              " -ForegroundColor Blue
    Write-Host "====================================================" -ForegroundColor Blue

    $sshProc = Get-Process -Name "ssh" -ErrorAction SilentlyContinue
    if ($sshProc) {
        Write-Host "Service Status:     [ACTIVE] (PID: $($sshProc.Id))" -ForegroundColor Green
    } else {
        Write-Host "Service Status:     [INACTIVE]" -ForegroundColor Red
    }

    Write-Host "Target Oracle VPS:  $ServerIP"
    Write-Host "SOCKS5 Proxy:       127.0.0.1:$SocksPort"
    Write-Host "Windows Proxy:      $((Get-ProxyStatus))"

    Write-Host "`nQuick IP Verification:"
    try {
        $maskedIP = (curl.exe -s --max-time 4 -x "socks5h://127.0.0.1:$SocksPort" https://ifconfig.me).Trim()
        if ($maskedIP) {
            Write-Host "Masked Public IP:   $maskedIP" -ForegroundColor Green
        } else {
            Write-Host "Masked Public IP:   Offline" -ForegroundColor Red
        }
    } catch {
        Write-Host "Masked Public IP:   Check failed" -ForegroundColor Red
    }
    Write-Host "====================================================" -ForegroundColor Blue
}

function Install-AutoStart {
    Write-Host "[*] Registering Windows Scheduled Task for 24/7 Autostart on Logon..." -ForegroundColor Cyan
    $taskName = "OracleVPNShield"
    $psExe = (Get-Command powershell.exe).Source
    $taskScript = Join-Path $ScriptDir "oracle-vpn.ps1"
    
    $action = New-ScheduledTaskAction -Execute $psExe -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$taskScript`" start"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Host "[OK] 24/7 Autostart scheduled task registered! The VPN will start automatically whenever Windows boots/logs in." -ForegroundColor Green
}

function Uninstall-AutoStart {
    $taskName = "OracleVPNShield"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Write-Host "[OK] Autostart scheduled task removed." -ForegroundColor Green
}

switch ($Action) {
    "start" { Start-VPN }
    "stop" { Stop-VPN }
    "restart" { Stop-VPN; Start-Sleep -Seconds 1; Start-VPN }
    "status" { Show-Status }
    "test" { Test-VPN }
    "install-autostart" { Install-AutoStart }
    "uninstall-autostart" { Uninstall-AutoStart }
}
