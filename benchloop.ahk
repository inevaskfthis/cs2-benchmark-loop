; ================================================================
; CS2 BenchLoop v3 - console-driven workshop benchmark loop
;
;   usage : AutoHotkey64.exe benchloop.ahk [rounds|syntaxcheck|dryrun]
;   flow  : preflight -> per round:
;             launch CS2 (+map_workshop <id> <map> -condebug)
;             -> wait window -> confirm map mount via console.log
;             -> wait for benchmark to finish (NETWORK_DISCONNECT marker)
;             -> kill CS2 immediately (minimal main-menu idle time)
;   files : benchloop.log  full history (UTF-8)
;           status.txt     single-line live status (read by the .bat)
;           stop.flag      create this file to request a graceful stop
;           gpu-log.csv    GPU sensors @5s (only if Afterburner is running)
;   deps  : Steam running + logged in, CS2 installed, workshop addon
;           3240880604 downloaded. Afterburner optional.
;   ports : everything auto-detected (registry + libraryfolders.vdf),
;           no hardcoded library paths.
; ================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2

; ---------------- syntax-check sentinel ----------------
if (A_Args.Length > 0 && A_Args[1] = "syntaxcheck") {
    try FileAppend("OK " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n", A_ScriptDir "\__syntax_ok.txt", "UTF-8")
    ExitApp 0
}

; ---------------- config ----------------
gWorkshopId  := "3240880604"
gWorkshopMap := "de_dust2"
gWinWaitMaxS   := 120     ; CS2 main window
gMountWaitMaxS := 75      ; 'Map: "<map>"' marker in console.log
gLoadBufferS   := 10      ; extra settle after mount marker
gBenchMaxS     := 150     ; hard cap for benchmark phase
gPollMs        := 1000

; ---------------- globals ----------------
gLogFile    := A_ScriptDir "\benchloop.log"
gStatusFile := A_ScriptDir "\status.txt"
gStopFlag   := A_ScriptDir "\stop.flag"
gCsvPath    := A_ScriptDir "\gpu-log.csv"
gRounds     := 5
gLogCharPos := 0          ; rolling read position in console.log (chars)

if (A_Args.Length > 0 && A_Args[1] = "dryrun") {
    gRounds := 0
} else if (A_Args.Length > 0) {
    v := A_Args[1] + 0
    if (v >= 1 && v <= 50)
        gRounds := Integer(v)
}
try FileDelete(gStopFlag)

; ---------------- logging ----------------
Log(msg) {
    global gLogFile, gStatusFile
    line := FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " msg
    try FileAppend(line "`r`n", gLogFile, "UTF-8")
    try FileDelete(gStatusFile)
    try FileAppend(msg, gStatusFile, "UTF-8")   ; live status, English only (console safe)
}

; ---------------- helpers ----------------
StopRequested() {
    global gStopFlag
    return FileExist(gStopFlag)
}

SleepInterruptible(ms) {
    end := A_TickCount + ms
    while (A_TickCount < end) {
        if StopRequested()
            return false
        Sleep 500
    }
    return true
}

KillCs2() {
    if ProcessExist("cs2.exe") {
        ProcessClose("cs2.exe")
        ProcessWaitClose("cs2.exe", 10)
        Sleep 1500
    }
}

; rolling-window search: only the part of console.log added since the last
; call, so stale markers from previous rounds can never match again.
LogSliceHas(logPath, needle) {
    global gLogCharPos
    try txt := FileRead(logPath, "UTF-8")
    catch {
        try txt := FileRead(logPath)
        catch
            return false
    }
    total := StrLen(txt)
    if (gLogCharPos > total)          ; file was truncated/rewritten by CS2
        gLogCharPos := 0
    seg := SubStr(txt, gLogCharPos + 1)
    found := InStr(seg, needle) ? true : false
    gLogCharPos := (total > 200) ? total - 200 : 0   ; keep a 200-char overlap
    return found
}

; ---------------- discovery (cross-device) ----------------
ResolveSteamDir() {
    for pair in [["HKCU\Software\Valve\Steam", "SteamPath"],
                 ["HKLM\SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath"]] {
        try {
            val := StrReplace(Trim(RegRead(pair[1], pair[2]), ' "'), "/", "\")
            val := RTrim(val, "\")
            if (val != "")
                return val
        }
    }
    return "C:\Program Files (x86)\Steam"
}

ResolveCs2Root(steamDir) {
    cs2Rel := "steamapps\common\Counter-Strike Global Offensive"
    libs := []
    vdf := steamDir "\steamapps\libraryfolders.vdf"
    if FileExist(vdf) {
        try txt := FileRead(vdf, "UTF-8")
        catch
            txt := ""
        pos := 1
        while (pos := RegExMatch(txt, '"path"\s+"([^"]+)"', &m, pos)) {
            p := StrReplace(m[1], "\\", "\")
            libs.Push(RTrim(p, "\"))
            pos += m.Len
        }
    }
    libs.Push(steamDir)   ; default library last
    for _, lib in libs {
        if FileExist(lib "\" cs2Rel "\game\csgo")
            return lib "\" cs2Rel
    }
    return ""
}

; ---------------- GPU sensor sampling (MAHM, optional) ----------------
gCols := ""
gWant := ["temperature", "core clock", "memory clock", "memory used", "power", "fan", "usage"]
gMahmWarned := false

SampleGpu() {
    global gCsvPath, gCols, gWant, gMahmWarned
    h := DllCall("OpenFileMapping", "UInt", 4, "Int", 0, "Str", "MAHMSharedMemory", "Ptr")
    if !h {
        if !gMahmWarned {
            gMahmWarned := true
            Log("[warn] MSI Afterburner not detected - no GPU sensor log this run")
        }
        return
    }
    p := DllCall("MapViewOfFile", "Ptr", h, "UInt", 4, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
    if !p {
        DllCall("CloseHandle", "Ptr", h)
        return
    }
    hdrSize := NumGet(p, 8, "UInt")
    cnt     := NumGet(p, 12, "UInt")
    stride  := NumGet(p, 16, "UInt")
    snap := Map()
    Loop cnt {
        b := hdrSize + (A_Index - 1) * stride
        nm := StrGet(p + b, 260, "cp0")
        if (nm = "")
            continue
        v := NumGet(p, b + 1300, "Float")
        if (v != v || Abs(v) > 1e30)   ; v!=v detects NaN
            continue
        snap[nm] := v
    }
    DllCall("UnmapViewOfFile", "Ptr", p)
    DllCall("CloseHandle", "Ptr", h)
    if (snap.Count = 0)
        return

    if (gCols = "") {
        cols := []
        for name, _ in snap
            for _, w in gWant
                if InStr(name, w) {
                    cols.Push(name)
                    break
                }
        gCols := "|" JoinStr(cols, "|") "|"
        hdr := "time,"
        for i, name in cols
            hdr .= (i > 1 ? "," : "") StrReplace(name, " ", "_")
        try FileAppend(hdr "`r`n", gCsvPath, "UTF-8")
        Log("  gpu-log: " cols.Length " sensor channels -> gpu-log.csv")
    }

    row := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    for i, name in StrSplit(Trim(gCols, "|"), "|") {
        v := snap.Has(name) ? snap[name] : ""
        v := (v = "") ? "" : Round(v, 1)
        row .= "," v
    }
    try FileAppend(row "`r`n", gCsvPath, "UTF-8")
}

JoinStr(arr, sep) {
    s := ""
    for i, v in arr
        s .= (i > 1 ? sep : "") v
    return s
}

SetTimer SampleGpu, 5000

; ---------------- one benchmark round ----------------
; returns "ok" | "fail" | "stop"
LaunchRound(r) {
    global gRounds, gWorkshopId, gWorkshopMap, gSteamExe, gConsoleLog
    global gWinWaitMaxS, gMountWaitMaxS, gLoadBufferS, gBenchMaxS, gPollMs

    Log("===== ROUND " r "/" gRounds " START =====")
    KillCs2()

    Run('"' gSteamExe '" -applaunch 730 +map_workshop ' gWorkshopId ' ' gWorkshopMap ' -condebug')
    Log("  launched: +map_workshop " gWorkshopId " " gWorkshopMap)

    ; phase 1: game window
    tEnd := A_TickCount + gWinWaitMaxS * 1000
    winUp := false
    while (A_TickCount < tEnd) {
        if StopRequested()
            return "stop"
        if WinExist("Counter-Strike 2") {
            winUp := true
            break
        }
        Sleep gPollMs
    }
    if !winUp {
        Log("  !! CS2 window not seen within " gWinWaitMaxS "s - round aborted")
        KillCs2()
        return "fail"
    }

    ; phase 2: map mount confirmed via console.log (rolling window)
    Log("  window up; waiting for map mount marker...")
    needleMap := 'Map: "' gWorkshopMap '"'
    tEnd := A_TickCount + gMountWaitMaxS * 1000
    inMap := false
    while (A_TickCount < tEnd) {
        if StopRequested()
            return "stop"
        if LogSliceHas(gConsoleLog, needleMap) {
            inMap := true
            break
        }
        Sleep gPollMs
    }
    if !inMap {
        Log("  !! no '" needleMap "' within " gMountWaitMaxS "s - stuck at main menu?")
        KillCs2()
        return "fail"
    }
    Log("  map mount confirmed; load buffer " gLoadBufferS "s")
    if !SleepInterruptible(gLoadBufferS * 1000)
        return "stop"

    ; phase 3: benchmark runs; finish = any NETWORK_DISCONNECT marker
    benchTick := A_TickCount
    tEnd := A_TickCount + gBenchMaxS * 1000
    sawDisc := false
    while (A_TickCount < tEnd) {
        if StopRequested()
            return "stop"
        if LogSliceHas(gConsoleLog, "NETWORK_DISCONNECT") {
            sawDisc := true
            break
        }
        Sleep gPollMs
    }
    el := Round((A_TickCount - benchTick) / 1000)
    if sawDisc
        Log("  benchmark finished in ~" el "s (disconnect marker seen)")
    else
        Log("  benchmark phase hit " gBenchMaxS "s cap - killing anyway")

    KillCs2()
    Log("  round " r " done")
    return "ok"
}

; ---------------- preflight ----------------
Log("CS2 BenchLoop v3 - " gRounds " round(s) requested" (gRounds = 0 ? " (dryrun)" : ""))

gSteamDir := ResolveSteamDir()
gSteamExe := gSteamDir "\steam.exe"
if !FileExist(gSteamExe) {
    Log("[fatal] steam.exe not found under '" gSteamDir "' - install Steam or check registry")
    Log("PREFLIGHT FAILED")
    ExitApp 1
}
Log("  steam : " gSteamDir)

gCs2Root := ResolveCs2Root(gSteamDir)
if (gCs2Root = "") {
    Log("[fatal] CS2 install not found in any steam library (checked libraryfolders.vdf)")
    Log("PREFLIGHT FAILED")
    ExitApp 1
}
Log("  cs2   : " gCs2Root)
gConsoleLog := gCs2Root "\game\csgo\console.log"

libRoot := SubStr(gCs2Root, 1, InStr(gCs2Root, "\steamapps\common") - 1)
vpkProbe := libRoot "\steamapps\workshop\content\730\" gWorkshopId "\" gWorkshopId "_dir.vpk"
if FileExist(vpkProbe)
    Log("  addon : workshop " gWorkshopId " present")
else
    Log("[warn] workshop addon " gWorkshopId " not found in library - rounds will likely fail to mount")

if !FileExist(gConsoleLog)
    Log("  note  : console.log not created yet (appears after first -condebug launch)")

; ---------------- main loop ----------------
okRounds := 0
aborted := false
Loop gRounds {
    r := A_Index
    st := LaunchRound(r)
    if (st = "stop") {
        aborted := true
        break
    }
    if (st = "ok")
        okRounds++
    if (r < gRounds) {
        Log("  cooldown 3s")
        if !SleepInterruptible(3000) {
            aborted := true
            break
        }
    }
}
KillCs2()

if aborted {
    Log(">>> LOOP ABORTED BY USER after " okRounds " completed round(s)")
    Log("LOOP ABORTED")
} else {
    Log("===== ALL " gRounds " ROUNDS DONE (" okRounds " ok) =====")
    Log("ALL ROUNDS DONE")
}
ExitApp
