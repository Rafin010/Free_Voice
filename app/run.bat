@echo off
setlocal
cd /d "%~dp0"

set "AHK_EXE=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%AHK_EXE%" (
    set "AHK_EXE=C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe"
)

if not exist "%AHK_EXE%" (
    echo AutoHotkey v2 not found. Please run setup.bat or install AutoHotkey v2 from https://www.autohotkey.com/
    pause
    exit /b 1
)

start "" "%AHK_EXE%" "%~dp0FreeVoice.ahk"
