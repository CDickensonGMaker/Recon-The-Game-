@echo off
REM PERF: AFTER. The demo with the 2026-09-08 performance decree live - the ratified
REM 0.75 render scale actually shipping, cutout foliage, vertex-lit vegetation, no
REM specular on the ground, opaque sandbags. Same scene, same seed as perf_before.bat.
REM
REM YOU are the camera. Do the SAME walk you did in the BEFORE run (it is written at the
REM top of perf_before.bat). Lines land in perf_after.log.
REM
REM THIS IS ALSO THE LOOK CHECK. The numbers are only half of it - the jungle has to
REM still read as jungle. If it does not, say so and the whole material half reverses by
REM deleting one call; the render scale reverses in the settings screen.
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." res://scenes/levels/demo_game.tscn -- --print-fps > "%~dp0perf_after.log" 2>&1
echo.
echo AFTER run written to perf_after.log
pause
