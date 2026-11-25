# FreeVoice

Lightweight Windows voice typing powered by **AutoHotkey v2** and local **Whisper** (`faster-whisper`).

## Structure

- `app/` : Windows voice typing application (`FreeVoice.ahk`, `stt_server.py`, `config.ini`, `installer.iss`, `InstallerWizard.cs`, `build_installer.bat`, `setup.bat`, `run.bat`, `launch.bat`)
- `website/` : Minimal, pure-white download landing page (`index.html`, `style.css`, `script.js`, `FreeVoice-Setup.exe`)

## Quick Start (Windows) -----

1. Run `website\FreeVoice-Setup.exe` (or `app\dist\FreeVoice-Setup.exe`) to install FreeVoice with the standard Windows setup wizard.
2. Launch **FreeVoice** from your Desktop or Start Menu.
3. Press the `` ` `` / `~` key (`SC029`) **once** in any Windows app to start `Listening...`.
4. Speak naturally, then press `` ` `` **a second time** to stop and insert text at your cursor.
   - Press `Ctrl + ` `` to type a literal backtick (`` ` ``).
   - Press `Shift + ` `` to type a literal tilde (`~`).

## Building the Installer

Run `app\build_installer.bat` on Windows to package `app\dist\FreeVoice-Setup.exe` and copy it to `website\FreeVoice-Setup.exe`.

