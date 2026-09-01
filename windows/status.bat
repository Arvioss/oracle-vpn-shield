@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0oracle-vpn.ps1" status
pause
