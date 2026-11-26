@echo off
title ADB reverse — phone uses 127.0.0.1:8000 to reach erp-server on PC
set "ADB=adb"
where adb >nul 2>&1
if %errorLevel% neq 0 (
  if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  ) else (
    echo adb not found. Install Android SDK platform-tools or use PHONE-CANNOT-REACH-PC.txt Option B.
    pause
    exit /b 1
  )
)

"%ADB%" devices
echo.
"%ADB%" reverse tcp:8000 tcp:8000
if %errorLevel% neq 0 (
  echo Failed. Enable USB debugging and authorize this PC on the phone.
  pause
  exit /b 1
)

echo.
echo OK. On the phone:
echo   Browser: http://127.0.0.1:8000/api/mobile/health
echo   App Server: 127.0.0.1:8000  then Save ^& connect
echo.
echo Keep USB connected. Re-run this after unplugging.
pause
