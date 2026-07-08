# Wait for the main overnight run to release the render slot, then finish the farmer.
$b = "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"
$stage = "C:\Users\caleb\RECONgame\art_source\characters\sprite_stage.blend"
$t = "C:\Users\caleb\RECONgame\tools"
$log = "C:\Users\caleb\RECONgame\art_source\characters\overnight_log.txt"

while (Get-Process blender -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 30 }

"--- CATCHUP vc1_farmer render (2 missing frames) $(Get-Date) ---" | Out-File $log -Append -Encoding utf8
& $b -b $stage -P "$t\render_sprite_sheets.py" -- vc1_farmer ak47 MixamoRig_VC1 `
  "US_Grunt_Rigged,M16A1_Rifle,VC2_MainForce,Mosin_Rifle_VC,VC5_NVA,PPSh41_Gun" 2>&1 |
  Select-String -Pattern "ALL FRAMES|Error|Traceback" | Out-File $log -Append -Encoding utf8

"--- CATCHUP vc1_farmer assemble $(Get-Date) ---" | Out-File $log -Append -Encoding utf8
& $b -b -P "$t\assemble_sheets.py" -- vc1_farmer ak47 "Vietcong and NVA" 2>&1 |
  Select-String -Pattern "ASSEMBLED|SKIP|DONE|Error|Traceback" | Out-File $log -Append -Encoding utf8

"=== CATCHUP COMPLETE $(Get-Date) ===" | Out-File $log -Append -Encoding utf8
