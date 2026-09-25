# CS2 BenchLoop

Loop-runner for the Steam Workshop FPS benchmark map
[CS2 FPS BENCHMARK DUST2 (3240880604)](https://steamcommunity.com/sharedfiles/filedetails/?id=3240880604).

[中文](READMECN.md)

Launch CS2 into the benchmark round after round, verify each mount via the
engine console log, stop the instant a round finishes, and (optionally) log
GPU sensors from MSI Afterburner's shared memory every 5 s. Built to chase
GPU instability: every round's timing in `benchloop.log` lines up with the
sensor curves in `gpu-log.csv`.

```
C:\CS2-BenchLoop\
├── Run-BenchLoop.bat    console UI: enter round count, live status, Q to stop
├── benchloop.ahk        main script (AutoHotkey v2)
├── AutoHotkey64.exe     NOT included - download AHK v2 portable (see below)
└── README.txt
```

## Usage

1. Get [AutoHotkey v2.0.19 (zip)](https://www.autohotkey.com/download/ahk-v2.zip),
   extract, and drop `AutoHotkey64.exe` next to `benchloop.ahk`.
2. Double-click `Run-BenchLoop.bat`, enter the number of rounds (Enter = 5).
3. The console refreshes a live status line every 2 s. Press `Q` at any time
   for a graceful stop (the current phase finishes, CS2 is closed cleanly).
4. Outputs land in the same folder:
   - `benchloop.log` - full per-round history (launch, mount check, timings)
   - `gpu-log.csv`   - GPU sensors @ 5 s (only if Afterburner is running)

## How it works

- Each round restarts CS2 with
  `-applaunch 730 +map_workshop 3240880604 de_dust2 -condebug` - the startup
  parameter is the most reliable way into a workshop map (console typing is
  flaky and focus-hungry alternatives were rejected on purpose).
- A round only counts as started when the engine console log shows
  `Map: "de_dust2"` (rolling-window read of the new content only, immune to
  stale markers from previous rounds).
- A round ends when the log shows a `NETWORK_DISCONNECT` marker - CS2 is
  closed immediately, so main-menu idle time drops from ~30 s to ~2 s.
- Paths are auto-detected: Steam registry keys plus
  `libraryfolders.vdf` parsing for multi-library installs. No hardcoded
  drive letters.
- GPU sensors are read from the `MAHMSharedMemory` block that MSI
  Afterburner publishes (read-only DllCall, no plugins). Without Afterburner
  the loop still runs, just without the sensor CSV.

## Requirements

- Windows 10/11
- Steam running and logged in
- CS2 installed + the workshop map above subscribed/downloaded
- AutoHotkey v2 (portable exe is enough)
- MSI Afterburner (optional, for the sensor log)

## Notes on VAC

The script does **not** inject into or modify the game process, does not
touch game memory, and only reads Afterburner's own shared memory block.
It launches the game the same way a user would, with documented launch
parameters. That said, use at your own risk - no anti-cheat guarantee is
given or implied.

The benchmark map itself is the work of its workshop author - this repo only
automates launching it.

## License

MIT - see [LICENSE](LICENSE). AutoHotkey itself is GPLv2 and is not
redistributed in this repository.
