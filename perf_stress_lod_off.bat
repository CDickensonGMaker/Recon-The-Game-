@echo off
REM ============================================================================
REM THE **BEFORE** SIDE OF THE BEHAVIOURAL LOD A/B.
REM
REM Identical to perf_stress.bat in every way except one flag: --ai-lod-off puts
REM every man in the 45-man assault back on the full thinking brain, which is
REM exactly how the fight ran at ~2.7 fps on 2026-09-09. One build, one flag
REM apart - so the before and the after cannot be two different games.
REM
REM RUN THIS ONE FIRST, then perf_stress.bat. Same start, same route, same fight.
REM Both logs carry an [AILOD] row beside every [FPS] row:
REM
REM   [AILOD] near N (window peak P, mean M) of L live enemies | hot slots H/50 | lod ON/OFF
REM
REM   - the BEFORE log must read `lod OFF` and near == live enemies
REM   - the AFTER log's `window peak` is THE number: how many men are thinking at
REM     once. If it is not far below the live count, the LOD is not doing its job
REM     and no frame-time gain from it should be believed.
REM
REM Compare on WALL fps and on median/p95/p99, never on the avg alone.
REM ============================================================================
set STAMP=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set STAMP=%STAMP: =0%
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." res://scenes/levels/demo_game.tscn -- --print-fps --stress --ai-lod-off > "%~dp0perf_stress_lodoff_%STAMP%.log" 2>&1
echo.
echo BEFORE walk written to perf_stress_lodoff_%STAMP%.log
echo Now run perf_stress.bat for the AFTER side.
pause
