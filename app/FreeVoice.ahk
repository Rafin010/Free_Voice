#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================================
; FreeVoice - Windows Voice Typing via AutoHotkey v2
; Hotkey: ` / ~ key (SC029)
;   - Toggle mode (default): Press ` once to start Listening..., press again to stop and insert text
;   - Hold mode (optional): Hold ` to speak, release to insert text
;   - Literal ` key: Ctrl + `
;   - Literal ~ key: Shift + ` (works normally)
; ============================================================================

global ConfigFile := A_ScriptDir "\config.ini"
global Mode := IniRead(ConfigFile, "General", "Mode", "toggle")
global Language := IniRead(ConfigFile, "General", "Language", "auto")
global ModelName := IniRead(ConfigFile, "General", "Model", "base")
global SoundCue := Integer(IniRead(ConfigFile, "General", "SoundCue", "1"))
global Port := IniRead(ConfigFile, "General", "Port", "8765")
global AutoStartServer := Integer(IniRead(ConfigFile, "General", "AutoStartServer", "1"))

global BaseUrl := "http://127.0.0.1:" Port
global IsRecording := false
global IsBusy := false
global IsPaused := false
global PulseState := false
global CurrentStatusLabel := "Status: Ready"
global StartupRegKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
global StartupRegVal := "FreeVoice"

; Status pill GUI (non-activating, always on top)
global StatusGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Border")
StatusGui.BackColor := "111827"
StatusGui.MarginX := 14
StatusGui.MarginY := 8
StatusGui.SetFont("s9.5 cFFFFFF Norm", "Segoe UI")
global StatusText := StatusGui.AddText("Center w160", "Listening...")

SetupTray()
if (AutoStartServer) {
    EnsureServerRunning()
}
OnExit(CleanupOnExit)

; ----------------------------------------------------------------------------
; Hotkeys
; ----------------------------------------------------------------------------

; Primary voice typing key: ` / ~ (SC029)
#HotIf !IsPaused
SC029:: {
    global Mode, IsRecording, IsBusy
    if (IsBusy) {
        return
    }

    if (Mode = "hold") {
        if (!StartVoiceCapture()) {
            return
        }
        KeyWait("SC029")
        StopAndInsertText()
    } else {
        if (!IsRecording) {
            StartVoiceCapture()
        } else {
            StopAndInsertText()
        }
    }
}
#HotIf

; Fallback to type a literal backtick (`) when needed
^SC029:: {
    SendText("``")
}

; ----------------------------------------------------------------------------
; Core Voice Capture & Transcription
; ----------------------------------------------------------------------------

StartVoiceCapture() {
    global IsRecording, BaseUrl, SoundCue, PulseState
    if (!EnsureServerRunning()) {
        ShowPill("Server offline", 1500)
        return false
    }

    resp := HttpRequest("POST", BaseUrl "/start", "{}")
    if (resp = "") {
        ShowPill("Mic error", 1500)
        return false
    }

    IsRecording := true
    PulseState := true
    if (SoundCue) {
        SoundBeep(880, 65)
    }
    UpdateTrayStatus("Status: Listening...")
    ShowPill("● Listening...")
    SetTimer(PulseListeningDot, 500)
    return true
}

StopAndInsertText() {
    global IsRecording, IsBusy, Language, BaseUrl, SoundCue
    SetTimer(PulseListeningDot, 0)
    IsRecording := false
    IsBusy := true

    if (SoundCue) {
        SoundBeep(660, 65)
    }
    UpdateTrayStatus("Status: Transcribing...")
    ShowPill("Transcribing...")

    payload := '{"language":"' Language '"}'
    resp := HttpRequest("POST", BaseUrl "/stop", payload)
    HidePill()
    IsBusy := false
    UpdateTrayStatus(IsPaused ? "Status: Paused" : "Status: Ready")

    if (resp = "") {
        return
    }

    text := ExtractJsonText(resp)
    if (text != "") {
        InsertTextAtCursor(text)
    }
}

PulseListeningDot(*) {
    global IsRecording, PulseState, StatusText
    if (!IsRecording) {
        SetTimer(PulseListeningDot, 0)
        return
    }
    PulseState := !PulseState
    StatusText.Value := PulseState ? "● Listening..." : "○ Listening..."
}

InsertTextAtCursor(text) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := text
    if (ClipWait(1)) {
        Send("^v")
        Sleep(100)
    }
    A_Clipboard := savedClip
}

; ----------------------------------------------------------------------------
; Tray Menu
; ----------------------------------------------------------------------------

SetupTray() {
    global CurrentStatusLabel
    iconIco := A_ScriptDir "\icon.ico"
    iconPng := A_ScriptDir "\icon.png"
    if (FileExist(iconIco)) {
        TraySetIcon(iconIco)
    } else if (FileExist(iconPng)) {
        TraySetIcon(iconPng)
    }

    A_TrayMenu.Delete()
    A_TrayMenu.Add(CurrentStatusLabel, (*) => {})
    A_TrayMenu.Disable(CurrentStatusLabel)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Mode: Toggle (``)", (*) => SetMode("toggle"))
    A_TrayMenu.Add("Mode: Hold to Talk (``)", (*) => SetMode("hold"))
    A_TrayMenu.Add()
    A_TrayMenu.Add("Language: Auto", (*) => SetLanguage("auto"))
    A_TrayMenu.Add("Language: English", (*) => SetLanguage("en"))
    A_TrayMenu.Add("Language: Bengali", (*) => SetLanguage("bn"))
    A_TrayMenu.Add()
    A_TrayMenu.Add("Model: Tiny (Fastest)", (*) => SetModel("tiny"))
    A_TrayMenu.Add("Model: Base (Balanced)", (*) => SetModel("base"))
    A_TrayMenu.Add("Model: Small (High Accuracy)", (*) => SetModel("small"))
    A_TrayMenu.Add()
    A_TrayMenu.Add("Sound Cue on Start/Stop", ToggleSoundCue)
    A_TrayMenu.Add("Run at Windows Startup", ToggleStartup)
    A_TrayMenu.Add("Pause Hotkey", TogglePause)
    A_TrayMenu.Add("Open Settings (config.ini)", (*) => Run('notepad.exe "' ConfigFile '"'))
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit FreeVoice", (*) => ExitApp())

    A_IconTip := "FreeVoice - Press `` to toggle listening"
    UpdateTrayChecks()
}

UpdateTrayStatus(newLabel) {
    global CurrentStatusLabel
    if (newLabel = CurrentStatusLabel) {
        return
    }
    try {
        A_TrayMenu.Rename(CurrentStatusLabel, newLabel)
        A_TrayMenu.Disable(newLabel)
        CurrentStatusLabel := newLabel
    }
}

UpdateTrayChecks() {
    global Mode, Language, ModelName, SoundCue, IsPaused
    A_TrayMenu.Uncheck("Mode: Toggle (``)")
    A_TrayMenu.Uncheck("Mode: Hold to Talk (``)")
    if (Mode = "hold") {
        A_TrayMenu.Check("Mode: Hold to Talk (``)")
        A_IconTip := "FreeVoice - Hold `` to speak"
    } else {
        A_TrayMenu.Check("Mode: Toggle (``)")
        A_IconTip := "FreeVoice - Press `` to toggle listening"
    }

    A_TrayMenu.Uncheck("Language: Auto")
    A_TrayMenu.Uncheck("Language: English")
    A_TrayMenu.Uncheck("Language: Bengali")
    if (Language = "en") {
        A_TrayMenu.Check("Language: English")
    } else if (Language = "bn") {
        A_TrayMenu.Check("Language: Bengali")
    } else {
        A_TrayMenu.Check("Language: Auto")
    }

    A_TrayMenu.Uncheck("Model: Tiny (Fastest)")
    A_TrayMenu.Uncheck("Model: Base (Balanced)")
    A_TrayMenu.Uncheck("Model: Small (High Accuracy)")
    if (ModelName = "tiny") {
        A_TrayMenu.Check("Model: Tiny (Fastest)")
    } else if (ModelName = "small") {
        A_TrayMenu.Check("Model: Small (High Accuracy)")
    } else {
        A_TrayMenu.Check("Model: Base (Balanced)")
    }

    if (SoundCue) {
        A_TrayMenu.Check("Sound Cue on Start/Stop")
    } else {
        A_TrayMenu.Uncheck("Sound Cue on Start/Stop")
    }

    if (IsStartupEnabled()) {
        A_TrayMenu.Check("Run at Windows Startup")
    } else {
        A_TrayMenu.Uncheck("Run at Windows Startup")
    }

    if (IsPaused) {
        A_TrayMenu.Check("Pause Hotkey")
    } else {
        A_TrayMenu.Uncheck("Pause Hotkey")
    }
}

SetMode(newMode) {
    global Mode, ConfigFile
    Mode := newMode
    IniWrite(Mode, ConfigFile, "General", "Mode")
    UpdateTrayChecks()
}

SetLanguage(newLang) {
    global Language, ConfigFile
    Language := newLang
    IniWrite(Language, ConfigFile, "General", "Language")
    UpdateTrayChecks()
}

SetModel(newModel) {
    global ModelName, ConfigFile, BaseUrl
    ModelName := newModel
    IniWrite(ModelName, ConfigFile, "General", "Model")
    UpdateTrayChecks()
    HttpRequest("POST", BaseUrl "/reload", '{"model":"' ModelName '"}')
    ShowPill("Model: " ModelName, 1400)
}

ToggleSoundCue(*) {
    global SoundCue, ConfigFile
    SoundCue := SoundCue ? 0 : 1
    IniWrite(SoundCue, ConfigFile, "General", "SoundCue")
    UpdateTrayChecks()
}

IsStartupEnabled() {
    global StartupRegKey, StartupRegVal
    try {
        val := RegRead(StartupRegKey, StartupRegVal)
        return (val != "")
    } catch {
        return false
    }
}

ToggleStartup(*) {
    global StartupRegKey, StartupRegVal
    if (IsStartupEnabled()) {
        try {
            RegDelete(StartupRegKey, StartupRegVal)
        }
        ShowPill("Startup disabled", 1200)
    } else {
        cmd := A_IsCompiled
            ? '"' A_ScriptFullPath '"'
            : '"' A_AhkPath '" "' A_ScriptFullPath '"'
        RegWrite(cmd, "REG_SZ", StartupRegKey, StartupRegVal)
        ShowPill("Startup enabled", 1200)
    }
    UpdateTrayChecks()
}

TogglePause(*) {
    global IsPaused, IsRecording
    if (IsRecording) {
        StopAndInsertText()
    }
    IsPaused := !IsPaused
    UpdateTrayChecks()
    UpdateTrayStatus(IsPaused ? "Status: Paused" : "Status: Ready")
    ShowPill(IsPaused ? "FreeVoice Paused" : "FreeVoice Active", 1200)
}

; ----------------------------------------------------------------------------
; Status Pill Helpers
; ----------------------------------------------------------------------------

ShowPill(label, autoHideMs := 0) {
    global StatusGui, StatusText
    StatusText.Value := label
    MonitorGetWorkArea(1, &left, &top, &right, &bottom)
    pillW := 184
    pillH := 34
    x := left + ((right - left - pillW) // 2)
    y := bottom - pillH - 28
    StatusGui.Show("NoActivate x" x " y" y " w" pillW " h" pillH)
    if (autoHideMs > 0) {
        SetTimer(HidePill, -autoHideMs)
    }
}

HidePill(*) {
    global StatusGui
    SetTimer(PulseListeningDot, 0)
    StatusGui.Hide()
}

; ----------------------------------------------------------------------------
; Server Lifecycle & HTTP Helpers
; ----------------------------------------------------------------------------

EnsureServerRunning() {
    global BaseUrl
    if (HttpRequest("GET", BaseUrl "/health", "", 500) != "") {
        return true
    }

    venvPythonW := A_ScriptDir "\.venv\Scripts\pythonw.exe"
    venvPython := A_ScriptDir "\.venv\Scripts\python.exe"
    serverScript := A_ScriptDir "\stt_server.py"

    if (!FileExist(serverScript)) {
        return false
    }

    if (FileExist(venvPythonW)) {
        Run('"' venvPythonW '" "' serverScript '"', A_ScriptDir, "Hide")
    } else if (FileExist(venvPython)) {
        Run('"' venvPython '" "' serverScript '"', A_ScriptDir, "Hide")
    } else {
        Run('pythonw "' serverScript '"', A_ScriptDir, "Hide")
    }

    Loop 20 {
        Sleep(250)
        if (HttpRequest("GET", BaseUrl "/health", "", 500) != "") {
            return true
        }
    }
    return false
}

CleanupOnExit(ExitReason, ExitCode) {
    global BaseUrl
    SetTimer(PulseListeningDot, 0)
    HttpRequest("POST", BaseUrl "/shutdown", "{}", 500)
}

HttpRequest(method, url, body := "", timeoutMs := 30000) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        req.Open(method, url, false)
        if (method = "POST") {
            req.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            req.Send(body)
        } else {
            req.Send()
        }
        if (req.Status >= 200 && req.Status < 300) {
            return req.ResponseText
        }
    } catch {
        return ""
    }
    return ""
}

ExtractJsonText(jsonStr) {
    if (RegExMatch(jsonStr, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)) {
        val := m[1]
        val := StrReplace(val, '\"', '"')
        val := StrReplace(val, "\\", "\")
        val := StrReplace(val, "\n", "`n")
        val := StrReplace(val, "\r", "`r")
        val := StrReplace(val, "\t", "`t")
        return Trim(val)
    }
    return ""
}
