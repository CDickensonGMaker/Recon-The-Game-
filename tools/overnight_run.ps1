$b = "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"
$stage = "C:\Users\caleb\RECONgame\art_source\characters\sprite_stage.blend"
$t = "C:\Users\caleb\RECONgame\tools"
$log = "C:\Users\caleb\RECONgame\art_source\characters\overnight_log.txt"

"=== OVERNIGHT SPRITE RUN start $(Get-Date) ===" | Out-File $log -Encoding utf8

$units = @(
  @("us_grunt",      "m16a1",  "MixamoRig",     "VC1_Farmer,AK47_Rifle,VC2_MainForce,Mosin_Rifle_VC,VC5_NVA,PPSh41_Gun", "US Army and Co"),
  @("vc1_farmer",    "ak47",   "MixamoRig_VC1", "US_Grunt_Rigged,M16A1_Rifle,VC2_MainForce,Mosin_Rifle_VC,VC5_NVA,PPSh41_Gun", "Vietcong and NVA"),
  @("vc2_mainforce", "mosin",  "RigVC2",        "US_Grunt_Rigged,M16A1_Rifle,VC1_Farmer,AK47_Rifle,VC5_NVA,PPSh41_Gun", "Vietcong and NVA"),
  @("vc5_nva",       "ppsh41", "RigVC5",        "US_Grunt_Rigged,M16A1_Rifle,VC1_Farmer,AK47_Rifle,VC2_MainForce,Mosin_Rifle_VC", "Vietcong and NVA")
)
foreach ($u in $units) {
  "--- RENDER $($u[0]) / $($u[1]) $(Get-Date) ---" | Out-File $log -Append -Encoding utf8
  & $b -b $stage -P "$t\render_sprite_sheets.py" -- $u[0] $u[1] $u[2] $u[3] 2>&1 |
    Select-String -Pattern "UNIT=|FRAMES DONE|ALL FRAMES|Error|Traceback" | Out-File $log -Append -Encoding utf8
  "--- ASSEMBLE $($u[0]) / $($u[1]) $(Get-Date) ---" | Out-File $log -Append -Encoding utf8
  & $b -b -P "$t\assemble_sheets.py" -- $u[0] $u[1] $u[4] 2>&1 |
    Select-String -Pattern "ASSEMBLED|SKIP|DONE|Error|Traceback" | Out-File $log -Append -Encoding utf8
}
"=== OVERNIGHT RUN COMPLETE $(Get-Date) ===" | Out-File $log -Append -Encoding utf8
