@echo off
REM ============================================================================
REM THE PERF WALK, ON THE COMPATIBILITY RENDERER. Same walk as perf_walk.bat -
REM bunk, hooch door, parapet 15 s, treeline 15 s, 30 paces out, 15 s - same
REM seed, same 0.75 scale. ONE flag apart: --rendering-method gl_compatibility.
REM
REM WHY THIS EXISTS (PERF_AUDIT_2026-09-10.md section 3.1). Godot's own docs put
REM Forward+ at the "highest base cost" and name Compatibility for older desktop
REM hardware; this scene uses nothing Forward+ adds (1 light, no GI, no fog volume,
REM 3 particle systems). It has NEVER been measured here. The 2026-07-17 decree
REM ratifies Forward+ for the SHIPPED game - this flag changes nothing in the
REM project, it measures. Compare the [FPS] gpu ms and draw calls against a
REM perf_walk_*.log taken the same day.
REM
REM ALSO LOOK: custom shaders (terrain, vegetation sway, PSX post) may refuse to
REM compile under GL - if the jungle is pink or the ground is flat grey, the run
REM measures nothing and says so in the log as SHADER ERROR lines.
REM ============================================================================
set STAMP=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set STAMP=%STAMP: =0%
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." --rendering-method gl_compatibility res://scenes/levels/demo_game.tscn -- --print-fps > "%~dp0perf_walk_COMPAT_%STAMP%.log" 2>&1
echo.
echo Walk written to perf_walk_COMPAT_%STAMP%.log
pause
