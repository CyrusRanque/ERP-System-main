@echo off
title ERP mobile — one start (server + USB + Flutter)
cd /d "%~dp0"

echo.
echo [1/3] Checking API on port 8000...
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/mobile/health' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }"
if errorlevel 1 (
  echo Starting erp-server in a new window — leave it open.
  start "erp-server" cmd /k "cd /d %~dp0erp-server && npm start"
  echo Waiting for API...
  timeout /t 6 /nobreak >nul
) else (
  echo API already running.
)

echo.
echo [2/3] USB port forward ^(phone 127.0.0.1:8000 -^> this PC^)...
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if exist "%ADB%" (
  "%ADB%" reverse tcp:8000 tcp:8000 2>nul
  "%ADB%" devices
) else (
  echo No adb — plug in phone with USB debugging or install Android SDK platform-tools.
)

echo.
echo [3/3] Launching Flutter app ^(auto-connects via USB, not 192.168.x^)...
cd /d "%~dp0erp-client"
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/mobile

pause
