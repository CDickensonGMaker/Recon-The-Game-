@echo off
rem Re-export vc_guerilla.glb (body + rice hat + AK + all 73 reel clips).
"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b "%~dp0..\art_source\characters\base_psx\vc_guerilla_v2.blend" -P "%~dp0export_vc_guerilla.py"
pause
