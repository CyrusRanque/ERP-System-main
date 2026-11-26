@echo off
title ERP — LAN dev (Node API + Flutter on Wi-Fi phone)
cd /d "%~dp0"

echo Classic field-app flow:
echo   1. MySQL running locally (WAMP or other) with database rts_system
echo   2. This script starts Node on 0.0.0.0:8000 and opens firewall once (Admin)
echo   3. On phone: same Wi-Fi, Server field = your PC IP:8000 e.g. 192.168.1.60:8000
echo.

powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/mobile/health' -UseBasicParsing -TimeoutSec 2).StatusCode | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  start "erp-server" cmd /k "cd /d %~dp0erp-server && npm start"
  timeout /t 6 /nobreak >nul
)

if not exist "%~dp0erp-server\scripts\open-firewall-windows-admin.bat" goto flutter
echo.
echo Allowing port 8000 from your phone (UAC prompt — click Yes once)...
call "%~dp0erp-server\scripts\open-firewall-windows-admin.bat"

:flutter
echo.
echo Starting Flutter on connected device...
cd /d "%~dp0erp-client"
flutter run
pause
