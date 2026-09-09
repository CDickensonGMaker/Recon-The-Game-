@echo off
REM PERF: BEFORE. Full-resolution frames and the as-imported foliage/sandbag materials.
REM NOTE (2026-09-08): --perf-before does NOT revert texture compression - that is baked
REM into the import and is switched by tools/perf_phase1_vram.py. For the VRAM-compression
REM A/B use perf_walk.bat, whose log states its own texture state.
REM
REM YOU are the camera: normal controls, walk where you like. Do the SAME walk in both.
REM Every 5 seconds a line lands in perf_before.log with fps, GPU ms and the render scale
REM the frame was actually drawn at.
REM
REM THE WALK (do it identically in both runs):
REM   1. You start on the bunk inside the firebase. Stand, walk out the hooch door.
REM   2. Stop at the sandbag parapet on the wire and look ALONG it - that is the sandbag fix.
REM   3. Turn and face the treeline. Hold still 15 seconds looking into the deep jungle -
REM      that is the foliage fix and the render scale.
REM   4. Walk 30 paces out the gate into the jungle and stop. Hold 15 seconds.
REM Close the window when done.
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0." res://scenes/levels/demo_game.tscn -- --perf-before --print-fps > "%~dp0perf_before.log" 2>&1
echo.
echo BEFORE run written to perf_before.log
pause
