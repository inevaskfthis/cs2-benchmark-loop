@echo off
setlocal EnableExtensions
title CS2 BenchLoop
cd /d "%~dp0"

if not exist "%~dp0AutoHotkey64.exe" (
    echo [!] AutoHotkey64.exe not found beside this .bat
    pause
    exit /b 1
)

echo ================================================
echo   CS2 BenchLoop    workshop map: 3240880604
echo   de_dust2 FPS benchmark, restart-per-round
echo ================================================
set "ROUNDS=5"
set /p "ROUNDS=  rounds [1-50] (enter = 5): "
echo %ROUNDS%| findstr /r "^[1-9][0-9]*$" >nul || set "ROUNDS=5"
if %ROUNDS% GTR 50 set "ROUNDS=50"

if exist stop.flag  del stop.flag  >nul 2>&1
if exist status.txt del status.txt >nul 2>&1

echo.
echo   starting %ROUNDS% round(s)...
echo   - CS2 will steal focus when it launches (normal)
echo   - live status is shown below, refreshed every 2s
echo   - press Q to stop the loop gracefully
echo.
start "" "%~dp0AutoHotkey64.exe" "%~dp0benchloop.ahk" %ROUNDS%

:show
timeout /t 2 /nobreak >nul
cls
echo   CS2 BenchLoop    rounds=%ROUNDS%
echo   ------------------------------------------------
type status.txt 2>nul
echo.
echo   [Q] quit loop        benchloop.log = full history
find /i "ALL ROUNDS DONE" status.txt >nul 2>&1 && goto finished
find /i "PREFLIGHT FAILED" status.txt >nul 2>&1 && goto finished
find /i "LOOP ABORTED" status.txt >nul 2>&1 && goto finished
choice /t 2 /c qn /d n /n >nul
if errorlevel 2 goto show
goto quit

:quit
echo stop> stop.flag
echo   stop requested - waiting up to 15s for graceful exit...
timeout /t 15 /nobreak >nul
taskkill /im cs2.exe /f >nul 2>&1
taskkill /im AutoHotkey64.exe /f >nul 2>&1

:finished
if exist stop.flag del stop.flag >nul 2>&1
echo.
echo   loop ended. outputs in this folder:
echo     benchloop.log   full round history
echo     gpu-log.csv     GPU sensors (needs Afterburner)
pause
