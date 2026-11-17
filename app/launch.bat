@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    call "%~dp0setup.bat"
)

if exist "%~dp0FreeVoice.exe" (
    start "" "%~dp0FreeVoice.exe"
    exit /b 0
)

call "%~dp0run.bat"
