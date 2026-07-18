# overnight_suite_chunk.ps1 - resumable per-test suite driver for the overnight run.
# Usage: powershell -File tools\overnight_suite_chunk.ps1 -From 0 -To 11
# Appends one verdict line per test to test_results\overnight_suite.log; skips
# tests already logged (resume after a chunk timeout).
param([int]$From = 0, [int]$To = 11)
$root = Split-Path $PSScriptRoot -Parent
$log = "$root\test_results\overnight_suite.log"
New-Item -ItemType Directory -Force "$root\test_results" | Out-Null
if (-not (Test-Path $log)) { New-Item -ItemType File $log | Out-Null }
$done = @{}
Get-Content $log | ForEach-Object { $n = ($_ -split '\|')[0].Trim(); if ($n) { $done[$n] = $true } }
$tests = (Get-ChildItem "$root\tests" -Filter "test_*.tscn" | Sort-Object Name).BaseName
$slice = $tests[$From..([Math]::Min($To, $tests.Count - 1))]
foreach ($t in $slice) {
    if ($done.ContainsKey($t)) { continue }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = powershell -File "$root\run_all_tests.ps1" -Filter $t 2>&1 | Out-String
    $sw.Stop()
    $line = ($out -split "`n" | Where-Object { $_ -match "PASS|FAIL|XFAIL|TIMEOUT|LEAK" } | Select-Object -First 2) -join " ; "
    Add-Content $log ("{0} | {1:F0}s | {2}" -f $t, $sw.Elapsed.TotalSeconds, $line.Trim())
}
Write-Output "CHUNK $From-$To COMPLETE"
Get-Content $log | Select-Object -Last ($slice.Count + 2)
