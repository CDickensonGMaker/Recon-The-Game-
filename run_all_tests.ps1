# run_all_tests.ps1 - W88: full headless suite, pass/fail table.
# Usage: powershell -File run_all_tests.ps1 [-Filter name]
param([string]$Filter = "")

$godot = "C:\Users\caleb\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
$root = $PSScriptRoot
$tests = Get-ChildItem "$root\tests" -Filter "test_*.tscn" | Sort-Object Name
if ($Filter) { $tests = $tests | Where-Object { $_.BaseName -like "*$Filter*" } }

Write-Host "=== RECONgame test suite ($($tests.Count) tests) ==="
$failed = 0
$results = @()
foreach ($t in $tests) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $godot --headless --path $root "res://tests/$($t.Name)" 2>&1 | Out-Null
    $ok = ($LASTEXITCODE -eq 0)
    $sw.Stop()
    if (-not $ok) { $failed++ }
    $results += [pscustomobject]@{
        Test = $t.BaseName
        Result = if ($ok) { "PASS" } else { "FAIL" }
        Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    }
    Write-Host ("{0,-28} {1,-5} {2,6}s" -f $t.BaseName, $results[-1].Result, $results[-1].Seconds)
}
Write-Host "=== $($tests.Count - $failed)/$($tests.Count) PASS ==="
exit $failed
