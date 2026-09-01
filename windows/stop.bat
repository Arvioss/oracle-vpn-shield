@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0oracle-vpn.ps1" stop
pause
