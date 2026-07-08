# run_all_tests.ps1 - W88: full headless suite, pass/fail table.
# Usage: powershell -File run_all_tests.ps1 [-Filter name] [-Verbose1]
#
# AUDIT-FIX (Step 1): this script used to do `2>&1 | Out-Null` and judge PASS
# purely on exit code. Every push_error, SCRIPT ERROR, and "call on previously
# freed instance" was thrown away. That is how R16 (navmesh) shipped as a no-op
# with a green suite. Output is now captured and scanned.
#
# It also used to run against the player's real user://campaign.cfg -- five test
# files call reset_campaign(), and test_full_loop runs three missions to debrief.
# Running the suite wiped your campaign. We now pass `-- --test-save`, which
# CampaignState._ready() honours by redirecting to user://campaign_test.cfg.
param([string]$Filter = "", [switch]$Verbose1)

$ErrorActionPreference = 'Continue'

$godot = "C:\Users\caleb\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
$root = $PSScriptRoot
$tests = Get-ChildItem "$root\tests" -Filter "test_*.tscn" | Sort-Object Name
if ($Filter) { $tests = $tests | Where-Object { $_.BaseName -like "*$Filter*" } }

# Tests known to fail against current code. A KNOWN-RED test that FAILS reports
# XFAIL and does not break the build. A KNOWN-RED test that PASSES reports XPASS
# and DOES break the build -- that forces you to delete it from this list the
# moment the underlying bug is fixed. The list is the scoreboard, not an excuse.
$KnownRed = @(
    # test_nav_path graduated: NavBaker bakes per-site navmesh, enemies path
    # around structures. Kept empty rather than deleted so the next known-red
    # test has a home.
)

# Substrings that mean "the engine complained". Any hit = FAIL, regardless of exit code.
#
# Two traps, both verified empirically against Godot 4.6.2 rather than assumed:
#  1. Matched with .Contains() (ordinal), NOT -like. PowerShell wildcards treat
#     "[NAV]" as a character class matching any N, A, or V -- it matched everything.
#  2. Godot does NOT print "SCRIPT ERROR" or "USER ERROR" here. push_error() and
#     engine errors both emit "ERROR: <msg>" on stderr. Patterns that never fire
#     are the exact bug class this harness exists to catch.
$ErrorPatterns = @(
    "ERROR:"           # push_error, SCRIPT ERROR, engine errors -- all match
    "previously freed" # "Attempt to call function ... in base 'previously freed instance'"
    "[NAV]"            # NavBaker's own bake-time invariant guards (Step 6)
)

# Known-benign engine chatter. These are NOT whitelisted into silence: a test whose
# only error lines are these reports LEAK (loud, tracked in Beads), not PASS.
# Anything not on this list is FATAL. Never add to this list to make a build green.
$BenignPatterns = @(
    "resources still in use at exit"     # GunFX combat_sting.wav outlives teardown (AUDIT-12)
    "ObjectDB instances leaked at exit"  # same root cause
    "Leaked instance:"
    "Resource still in use:"
    "Hint: Leaked instances typically happen"
)

Write-Host "=== RECONgame test suite ($($tests.Count) tests) ==="
$failed = 0
$results = @()
foreach ($t in $tests) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $raw = & $godot --headless --path $root "res://tests/$($t.Name)" -- --test-save 2>&1
    $exit = $LASTEXITCODE
    $sw.Stop()
    $out = ($raw | Out-String)

    # Scan line-by-line so a benign leak line can be told apart from a real error
    # that happens to share the "ERROR:" prefix.
    $fatalLines = @()
    $benignLines = @()
    foreach ($line in ($out -split "`n")) {
        $hit = $false
        foreach ($p in $ErrorPatterns) { if ($line.Contains($p)) { $hit = $true; break } }
        if (-not $hit) { continue }
        $benign = $false
        foreach ($b in $BenignPatterns) { if ($line.Contains($b)) { $benign = $true; break } }
        # PowerShell's NativeCommandError wrapper echoes the godot line; ignore the wrapper itself.
        if ($line.Contains("FullyQualifiedErrorId") -or $line.Contains("CategoryInfo")) { $benign = $true }
        if ($benign) { $benignLines += $line.Trim() } else { $fatalLines += $line.Trim() }
    }

    $ok = ($exit -eq 0) -and ($fatalLines.Count -eq 0)
    $engineErrors = $fatalLines
    $isKnownRed = $KnownRed -contains $t.BaseName

    if ($isKnownRed) {
        if ($ok) {
            $verdict = "XPASS"   # fixed! remove from $KnownRed
            $failed++
        } else {
            $verdict = "XFAIL"   # expected, not counted
        }
    } else {
        if (-not $ok) { $verdict = "FAIL"; $failed++ }
        elseif ($benignLines.Count -gt 0) { $verdict = "LEAK" }   # green, but not clean
        else { $verdict = "PASS" }
    }

    $note = ""
    if ($fatalLines.Count -gt 0) { $note = "<- " + (($fatalLines | Select-Object -First 1)) }
    elseif ($verdict -eq "LEAK") { $note = "<- resources leaked at exit (AUDIT-12)" }
    if ($verdict -eq "XPASS") { $note = "<- FIXED: remove from `$KnownRed" }

    $results += [pscustomobject]@{ Test = $t.BaseName; Result = $verdict }
    Write-Host ("{0,-28} {1,-6} {2,6}s {3}" -f $t.BaseName, $verdict, [math]::Round($sw.Elapsed.TotalSeconds, 1), $note)

    if ($Verbose1 -and -not $ok) {
        $out -split "`n" | Where-Object { $_ -match "ERROR|freed|FAIL|\[NAV\]" } | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    }
}

$xfail  = @($results | Where-Object { $_.Result -eq "XFAIL" }).Count
$passed = @($results | Where-Object { $_.Result -eq "PASS" }).Count
$leaked = @($results | Where-Object { $_.Result -eq "LEAK" }).Count
Write-Host "=== $passed PASS / $leaked LEAK / $failed FAIL / $xfail XFAIL (of $($tests.Count)) ==="
if ($xfail -gt 0)  { Write-Host "known-red: $($KnownRed -join ', ')" -ForegroundColor DarkGray }
if ($leaked -gt 0) { Write-Host "leaks: $(@($results | Where-Object { $_.Result -eq 'LEAK' } | ForEach-Object { $_.Test }) -join ', ')" -ForegroundColor DarkYellow }
exit $failed
