# Pass units as ONE comma-separated string; we split here. Passing a PowerShell
# array through `& blender ... -- $u` collapses it into a single argument, which
# silently fed "a,b,c" to the script as one unit name.
param([string]$UnitList)
$Units = $UnitList -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
"units: $($Units -join ' | ')"

$b = "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"
$stage = "C:\Users\caleb\RECONgame\art_source\characters\sprite_stage.blend"
$t = "C:\Users\caleb\RECONgame\tools"
$log = "C:\Users\caleb\RECONgame\art_source\characters\overnight_log.txt"

foreach ($u in $Units) {
  "--- RENDER $u $(Get-Date) ---" | Out-File $log -Append -Encoding utf8
  & $b -b $stage -P "$t\render_sprite_sheets.py" -- $u 2>&1 |
    Select-String -Pattern "UNIT=|muzzle local|FRAMES DONE|SKIPPED|ALL FRAMES|Error|Traceback" |
    Tee-Object -Append -FilePath $log

  "--- ASSEMBLE $u $(Get-Date) ---" | Out-File $log -Append -Encoding utf8
  & $b -b -P "$t\assemble_sheets.py" -- $u 2>&1 |
    Select-String -Pattern "ASSEMBLED|SKIP|DONE|WARNING|Error|Traceback" |
    Tee-Object -Append -FilePath $log
}
"=== FINISH_UNITS COMPLETE $(Get-Date) ===" | Out-File $log -Append -Encoding utf8
