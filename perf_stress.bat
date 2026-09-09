@echo off
REM ============================================================================
REM THE PERF WALK. One action, run it once per state. Ship parity: the 0.75
REM render scale and the material budget are LIVE, exactly as the game ships.
REM Vsync is forced OFF by the printer, and every log states its own texture
REM compression state on line 2 - you cannot mislabel a run.
REM
REM THE STRESS TEST. The 45-man assault normally opens 24 MINUTES in, which is
REM why it has never been walked by hand. --stress brings it to 45 seconds AND
REM jumps the clock to 20:10, the hour the real arc reaches at its own assault.
REM IT IS A NIGHT FIGHT. If you are standing in daylight, the clock jump failed -
REM say so, because then nothing you see about the fight can be trusted.
REM
REM   1. You start on the bunk. Stand, get out, get on the wire.
REM   2. ~20s a probe hits the wire. ~45s the full 45-man assault opens.
REM   3. FIGHT IT. Stay out until it resolves or you die.
REM   4. Watch for: models popping in, the canopy at distance, and any LURCH
REM      when a shell lands or a tree comes down - those are the measured stalls.
REM   5. NEW 2026-09-09, judge these: do sappers reach the WALL and blow holes in
REM      it, do men come through those holes, does the garrison arm up (including
REM      the men the resupply Huey drops mid-fight), and is anyone on a roof.
REM   Then close the window.
REM
REM ALSO LOOK AT THE JUNGLE while you do it. The textures are now lossy-compressed.
REM If the vines and leaf edges have gone blocky or crunchy, say so - it reverses.
REM ============================================================================
REM wmic was REMOVED in Windows 11 26200 - it wrote the log to a garbage
REM filename ("perf_walk_~0,8DT", 0 bytes) and the walk measured nothing.
set STAMP=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set STAMP=%STAMP: =0%
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." res://scenes/levels/demo_game.tscn -- --print-fps --stress > "%~dp0perf_stress_%STAMP%.log" 2>&1
echo.
echo Walk written to perf_stress_%STAMP%.log
pause
