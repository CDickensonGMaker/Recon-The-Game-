@echo off
REM ============================================================================
REM THE PERF WALK. One action, run it once per state. Ship parity: the 0.75
REM render scale and the material budget are LIVE, exactly as the game ships.
REM Vsync is forced OFF by the printer, and every log states its own texture
REM compression state on line 2 - you cannot mislabel a run.
REM
REM THE WALK. Do it IDENTICALLY every time, seed is fixed:
REM   1. You start on the bunk inside the firebase. Stand, walk out the hooch door.
REM   2. Stop at the sandbag parapet on the wire, look ALONG it. Hold 15 seconds.
REM   3. Turn and face the treeline. Hold still 15 seconds looking into deep jungle.
REM   4. Walk 30 paces out the gate into the jungle, stop. Hold 15 seconds.
REM   Then close the window.
REM
REM ============================================================================
REM WHAT TO JUDGE ON THIS WALK (2026-09-09 - the far canopy is now real 3D)
REM
REM   THE POP. This is the one that matters. Walk SLOWLY out from the wire toward
REM   the treeline, then back. There used to be a line at about 65 metres where a
REM   solid plant turned into a flat picture. Both sides are real models now, so
REM   there should be nothing to see - trees should get simpler as they recede,
REM   never change shape or flip flat. If anything still snaps at a fixed
REM   distance, say WHERE you were standing and what snapped.
REM
REM   THE FAR RING. Standing on the wire looking into the deep jungle: does the
REM   distance still read as jungle, or has it thinned out or gone lumpy?
REM
REM   NIGHT. The demo turns night on its own. Vegetation must go properly dark
REM   with everything else - if the far trees stay lit or glow, that is a bug.
REM
REM   THE OTHER POP, and it is a separate thing: walking up to a hooch, its whole
REM   interior appears at once at about 40 metres. That one is NOT fixed and is
REM   waiting on your call - it costs draw calls to soften.
REM ============================================================================
REM ============================================================================
REM wmic was REMOVED in Windows 11 26200 - it wrote the log to a garbage
REM filename ("perf_walk_~0,8DT", 0 bytes) and the walk measured nothing.
set STAMP=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set STAMP=%STAMP: =0%
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." res://scenes/levels/demo_game.tscn -- --print-fps > "%~dp0perf_walk_%STAMP%.log" 2>&1
echo.
echo Walk written to perf_walk_%STAMP%.log
pause
