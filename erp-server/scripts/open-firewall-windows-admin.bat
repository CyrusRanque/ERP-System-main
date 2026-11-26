@echo off
title Allow phone to reach ERP server (port 8000)
:: Double-click this file, click Yes on the UAC prompt, then retry health URL on your phone.

net session >nul 2>&1
if %errorLevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-firewall-windows.ps1"
echo.
echo If rules were added, on your phone open:
echo   http://192.168.1.60:8000/api/mobile/health
echo Same Wi-Fi as this PC. Turn off mobile data on the phone while testing.
echo.
pause
