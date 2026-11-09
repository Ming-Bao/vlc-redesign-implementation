@echo off
rem Completely uninstall the portable VLC Redesign: this folder, settings, media library and caches.
rem (For the installer version use Settings > Apps > VLC Redesign > Uninstall instead.)
echo This removes VLC Redesign and ALL its settings, media library and caches:
echo   %~dp0
echo   %APPDATA%\vlc
echo   %LOCALAPPDATA%\vlc
echo Note: regular VLC on this computer shares these settings folders.
set /p ans=Continue? [y/N]
if /i not "%ans%"=="y" (echo Cancelled.& exit /b 1)
taskkill /im vlc.exe /f >nul 2>&1
rd /s /q "%APPDATA%\vlc" 2>nul
rd /s /q "%LOCALAPPDATA%\vlc" 2>nul
echo VLC Redesign is uninstalled.
rem The folder holding this script is removed after it exits.
cd /d "%TEMP%"
start "" /b cmd /c "timeout /t 2 /nobreak >nul & rd /s /q "%~dp0""
