@echo off
REM ============================================================================
REM THE PERF WALK, ON DIRECT3D 12. Same walk as perf_walk.bat, same seed, same
REM renderer (Forward+), same scale. ONE flag apart: --rendering-driver d3d12.
REM
REM WHY (PERF_AUDIT_2026-09-10.md section 3.2). Every log so far boots
REM "Vulkan 1.3 - Intel UHD". Godot made D3D12 the Windows default in 4.6 because
REM Intel's Vulkan driver is slow - 60 vs 40 fps on one Intel iGPU in their own
REM tracker. Some Intel parts glitch on D3D12 instead, which is why this is a
REM test and not a switch. Compare [FPS] gpu ms against a Vulkan walk from the
REM same day. If the screen tears, goes black or shakes, that IS the result.
REM ============================================================================
set STAMP=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set STAMP=%STAMP: =0%
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." --rendering-driver d3d12 res://scenes/levels/demo_game.tscn -- --print-fps > "%~dp0perf_walk_D3D12_%STAMP%.log" 2>&1
echo.
echo Walk written to perf_walk_D3D12_%STAMP%.log
pause
