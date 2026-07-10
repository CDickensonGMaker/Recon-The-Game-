@echo off
rem Re-export the shared PSXRig animation library (rig-only, all clips).
rem Run after adding/fixing animations in anim_library.blend.
"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b "%~dp0..\art_source\characters\base_psx\anim_library.blend" -P "%~dp0export_anim_library.py"
pause
