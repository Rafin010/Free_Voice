@echo off
setlocal
cd /d "%~dp0"

echo ============================================
echo  FreeVoice Setup (Windows)
echo ============================================
echo.

:: 1. Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3 is not installed or not in PATH.
    echo Please install Python 3.10+ from https://www.python.org/downloads/
    pause
    exit /b 1
)

:: 2. Create virtual environment if missing
if not exist ".venv\Scripts\python.exe" (
    echo [1/3] Creating Python virtual environment...
    python -m venv .venv
) else (
    echo [1/3] Virtual environment already exists.
)

:: 3. Install Python dependencies
echo [2/3] Installing speech-to-text dependencies...
".venv\Scripts\python.exe" -m pip install --upgrade pip --quiet
".venv\Scripts\pip.exe" install -r requirements.txt

:: 4. Check AutoHotkey v2
echo [3/3] Checking AutoHotkey v2...
if exist "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" (
    echo AutoHotkey v2 found.
) else (
    echo AutoHotkey v2 not found at default path.
    where winget >nul 2>&1
    if not errorlevel 1 (
        echo Installing AutoHotkey v2 via winget...
        winget install --id AutoHotkey.AutoHotkey -e --source winget
    ) else (
        echo Please download and install AutoHotkey v2 from:
        echo https://www.autohotkey.com/
    )
)

echo.
echo Setup complete! Run "run.bat" to start FreeVoice.
pause
