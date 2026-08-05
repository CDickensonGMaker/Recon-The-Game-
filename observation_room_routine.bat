@echo off
rem OBSERVATION ROOM - ROUTINE (dev): the populated AO (village/camp/civilians on schedule +
rem patrols) with the day compressed, plus the observation instrument. --test-save protects
rem the real campaign. O observer | I overlay | \ pause | [ ] motion | - = day speed | 0 reset
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --path "%~dp0" res://scenes/levels/observation_room_routine.tscn -- --test-save
