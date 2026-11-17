; Inno Setup 6 Script for FreeVoice
; Compile with: iscc installer.iss (after compiling FreeVoice.ahk -> FreeVoice.exe with Ahk2Exe)

#define MyAppName "FreeVoice"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "FreeVoice"
#define MyAppExeName "FreeVoice.exe"

[Setup]
AppId={{8F3B9C12-4D7E-4A2B-9E15-2C8A4B7F1034}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=FreeVoice-Setup
SetupIconFile=icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "Launch FreeVoice at Windows startup"; GroupDescription: "Additional options:"; Flags: unchecked

[Files]
Source: "FreeVoice.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "FreeVoice.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "stt_server.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "config.ini"; DestDir: "{app}"; Flags: onlyifdoesntexist
Source: "requirements.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "setup.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "run.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "launch.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "icon.png"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\launch.bat"; IconFilename: "{app}\icon.ico"
Name: "{group}\Setup Dependencies"; Filename: "{app}\setup.bat"; IconFilename: "{app}\icon.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\launch.bat"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "FreeVoice"; ValueData: """{app}\launch.bat"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\setup.bat"; Description: "Install Python & AutoHotkey dependencies"; Flags: postinstall shellexec waituntilterminated
Filename: "{app}\launch.bat"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: postinstall nowait skipifsilent
