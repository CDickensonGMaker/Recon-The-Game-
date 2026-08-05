@echo off
REM THE NIGHT-JUNGLE FIREFIGHT BENCH - boot, play, and read what eats frames.
REM Dense jungle at night, US vs VC firefight, with the live targeted profiling
REM overlay (CPU-vs-GPU split, draw calls, frame graph, spike catcher, per-system
REM buckets, F1-F6 attribution toggles). Double-click to play.
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0" res://scenes/levels/ai_stress_arena.tscn
