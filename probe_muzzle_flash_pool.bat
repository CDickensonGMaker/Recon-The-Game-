@echo off
REM ============================================================================
REM THE MUZZLE FLASH POOL. Headless, ~4 seconds, no window.
REM
REM Every round fired used to BUILD a muzzle flash from nothing - a node, two
REM quads, two mesh resources and a timer, seven objects a shot, thrown away
REM 90 ms later. At 45 men that is hundreds of constructions a second inside
REM the physics step. It now builds at most 96 for the whole mission and
REM reuses them.
REM
REM This probe fires 32 rounds, lets them die, fires 32 MORE, and counts every
REM object that did not exist before. ZERO is the pass. It is written to FAIL
REM against the pre-pool code, and it carries a negative control that builds an
REM old-style flash by hand to prove the counter can see one.
REM
REM It also guards the LOOK - that the size jitter still lives in the mesh and
REM not in node scale (a billboard discards node scale, so that swap would have
REM silently flattened every flash to one size) - and that a reused flash still
REM falls back to the billboard roll when its caller passes no direction.
REM
REM This proves the pool is CORRECT and that it allocates nothing. It says
REM NOTHING about frame time. perf_stress.bat is what buys that number.
REM ============================================================================
"C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64.exe" --headless --path "%~dp0." res://tools/probe_muzzle_flash_pool.tscn > "%~dp0probe_muzzle_flash_pool.log" 2>&1
echo.
type "%~dp0probe_muzzle_flash_pool.log" | findstr /C:"FLASH POOL" /C:"wave " /C:"burst:" /C:"FAIL"
echo.
echo Full log: probe_muzzle_flash_pool.log
pause
