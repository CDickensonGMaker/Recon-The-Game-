@echo off
REM ============================================================================
REM THE BEHAVIOURAL LOD CORRECTNESS PROBE. Headless, ~25 seconds, no window.
REM Twelve assertions: the 80/105 band, the demote dwell, the hysteresis walked
REM in both directions, the sapper exemption, sticky promotion and its 160 m
REM ceiling, that a far man still advances and still holds a front, that the
REM census counts what it claims, and that --ai-lod-off really restores the old
REM behaviour.
REM
REM This proves the LOD is CORRECT. perf_stress_lod_off.bat + perf_stress.bat
REM prove what it BOUGHT. Run this one first - a wrong LOD makes a fast log
REM meaningless.
REM ============================================================================
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --headless --path "%~dp0." res://tools/probe_ai_lod.tscn > "%~dp0probe_ai_lod.log" 2>&1
echo.
type "%~dp0probe_ai_lod.log" | findstr /C:"[LODPROBE]"
echo.
echo Full log: probe_ai_lod.log
pause
