@echo off
setlocal
cd /d "%~dp0"

echo ============================================
echo  Building FreeVoice-Setup.exe
echo ============================================

if not exist "dist" mkdir "dist"

:: 1. Optional: Compile FreeVoice.ahk -> FreeVoice.exe if Ahk2Exe is installed
set "AHK2EXE=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
if exist "%AHK2EXE%" (
    echo [1/4] Compiling FreeVoice.ahk to FreeVoice.exe...
    "%AHK2EXE%" /in "FreeVoice.ahk" /out "FreeVoice.exe" /icon "icon.ico"
) else (
    echo [1/4] Ahk2Exe not found; packaging FreeVoice.ahk + launcher scripts.
)

:: 2. If Inno Setup 6 is installed, prefer it; otherwise use built-in Windows .NET csc.exe
set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist "%ISCC%" (
    echo [2/4] Building installer with Inno Setup 6...
    "%ISCC%" "installer.iss"
    if exist "dist\FreeVoice-Setup.exe" goto :copy_to_web
)

echo [2/4] Creating payload archive...
set "STAGE_DIR=%TEMP%\FreeVoiceStage"
if exist "%STAGE_DIR%" rmdir /S /Q "%STAGE_DIR%"
mkdir "%STAGE_DIR%"

copy /Y "FreeVoice.ahk" "%STAGE_DIR%\" >nul
if exist "FreeVoice.exe" copy /Y "FreeVoice.exe" "%STAGE_DIR%\" >nul
copy /Y "stt_server.py" "%STAGE_DIR%\" >nul
copy /Y "config.ini" "%STAGE_DIR%\" >nul
copy /Y "requirements.txt" "%STAGE_DIR%\" >nul
copy /Y "setup.bat" "%STAGE_DIR%\" >nul
copy /Y "run.bat" "%STAGE_DIR%\" >nul
copy /Y "launch.bat" "%STAGE_DIR%\" >nul
copy /Y "icon.ico" "%STAGE_DIR%\" >nul
copy /Y "icon.png" "%STAGE_DIR%\" >nul

powershell -NoProfile -Command "Compress-Archive -Path '%STAGE_DIR%\*' -DestinationPath '%~dp0dist\payload.zip' -Force"
rmdir /S /Q "%STAGE_DIR%"

echo [3/4] Compiling FreeVoice-Setup.exe with Windows .NET compiler...
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
    echo [ERROR] csc.exe not found at %CSC%
    exit /b 1
)

"%CSC%" /nologo /target:winexe /optimize+ ^
  /out:"dist\FreeVoice-Setup.exe" ^
  /win32icon:"icon.ico" ^
  /reference:System.dll ^
  /reference:System.Drawing.dll ^
  /reference:System.Windows.Forms.dll ^
  /reference:System.IO.Compression.dll ^
  /reference:System.IO.Compression.FileSystem.dll ^
  /resource:"dist\payload.zip",FreeVoice.payload.zip ^
  "InstallerWizard.cs"

if errorlevel 1 (
    echo [ERROR] Failed to compile FreeVoice-Setup.exe
    exit /b 1
)

if exist "dist\payload.zip" del /F /Q "dist\payload.zip"

:copy_to_web
echo [4/4] Copying FreeVoice-Setup.exe to ..\website\FreeVoice-Setup.exe...
copy /Y "dist\FreeVoice-Setup.exe" "..\website\FreeVoice-Setup.exe" >nul
echo Done! Output: d:\Free_Voice\app\dist\FreeVoice-Setup.exe
