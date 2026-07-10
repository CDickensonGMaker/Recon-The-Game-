@echo off
rem Re-export us_grunt_v2.glb (meshes + skeleton + sockets + clips).
rem Once the engine uses the shared anim_library.glb, set EXPORT_ANIMATIONS=False
rem in export_us_grunt_v2.py and this becomes a seconds-fast mesh export.
"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b "%~dp0..\art_source\characters\base_psx\us_grunt_v2.blend" -P "%~dp0export_us_grunt_v2.py"
pause
