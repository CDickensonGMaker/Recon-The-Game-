@echo off
REM ============================================================================
REM THE STRESS TEST WITH THE PHYSICS CATCH-UP CAPPED AT 3. Same fight as
REM perf_stress.bat, one flag apart: --phys-steps=3 (engine default is 8).
REM
REM WHY (PERF_AUDIT_2026-09-10.md). Headless, the 45-man siege runs at 19-40 fps of
REM pure CPU. Windowed on the Intel UHD it collapses to ~3 fps - far below what
REM GPU (25-35 ms) plus CPU would add up to. The difference is the catch-up
REM spiral: a slow frame is allowed to run up to 8 physics ticks of 45-man AI on
REM the next frame to make up the clock, which makes THAT frame slower still.
REM Capping it at 3 lets the sim run a little slow under load instead of
REM freezing. Compare the [FPS] rows in the assault against a same-day
REM perf_stress_*.log. If the fight FEELS slower (men moving in slow motion)
REM that is the trade, and it is yours to judge.
REM ============================================================================
set STAMP=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set STAMP=%STAMP: =0%
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." res://scenes/levels/demo_game.tscn -- --print-fps --stress --phys-steps=3 > "%~dp0perf_stress_PHYS3_%STAMP%.log" 2>&1
echo.
echo Walk written to perf_stress_PHYS3_%STAMP%.log
pause
