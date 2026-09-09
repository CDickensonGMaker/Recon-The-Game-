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
REM      THIS IS THE ONE THAT MATTERS - it is the canopy card ring.
REM   4. Walk 30 paces out the gate into the jungle, stop. Hold 15 seconds.
REM   Then close the window.
REM
REM ALSO LOOK AT THE JUNGLE while you do it. The textures are now lossy-compressed.
REM If the vines and leaf edges have gone blocky or crunchy, say so - it reverses.
REM ============================================================================
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set DT=%%I
set STAMP=%DT:~0,8%_%DT:~8,6%
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." res://scenes/levels/demo_game.tscn -- --print-fps > "%~dp0perf_walk_%STAMP%.log" 2>&1
echo.
echo Walk written to perf_walk_%STAMP%.log
pause
