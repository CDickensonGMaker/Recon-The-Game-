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
# TimeoutSec is a BOX, not a hang detector. The sim-loop tests legitimately run for
# minutes (test_hub_loop measured 167s; test_full_loop drives three missions to debrief
# with waits bounded at 200s each). A 120s box reported both as hung -- slow is not hung.
param([string]$Filter = "", [switch]$Verbose1, [int]$TimeoutSec = 420)

$ErrorActionPreference = 'Continue'

# The exe moved to _tools\godot47 on 2026-08-04. All 12 root .bat launchers were repointed that
# day; THIS FILE WAS MISSED, so the suite was unrunnable and its last artefact is 2026-07-17.
# A dead interpreter path is a silent gate: nothing fails, the suite simply never runs.
$godot = "C:\Users\caleb\_tools\godot47\Godot_v4.7-stable_win64_console.exe"
if (-not (Test-Path $godot)) { throw "Godot not found at $godot - the suite cannot run. Fix this path, do not skip the suite." }
$root = $PSScriptRoot
$tests = Get-ChildItem "$root\tests" -Filter "test_*.tscn" | Sort-Object Name
if ($Filter) { $tests = $tests | Where-Object { $_.BaseName -like "*$Filter*" } }

# Tests known to fail against current code. A KNOWN-RED test that FAILS reports
# XFAIL and does not break the build. A KNOWN-RED test that PASSES reports XPASS
# and DOES break the build -- that forces you to delete it from this list the
# moment the underlying bug is fixed. The list is the scoreboard, not an excuse.
$KnownRed = @(
    # test_nav_path graduated: NavBaker bakes per-site navmesh, enemies path
    # around structures.
    #
    # test_viewmodel_contract is red on FOUR guns that are all the Summoner's
    # own export/bench work (2026-08-13 register audit): m72_law + rpg7 have no
    # viewmodel GLB at all (model_path ""), rpd + rpg2 ship only rifle_idle
    # until re-exported. With the test as a bare FAIL, a NEW break in the
    # contract was scoreboard-invisible among the expected reds. XPASS forces
    # this entry out the moment his exports land.
    "test_viewmodel_contract"
)

# The other half of the ratchet. $KnownRed catches a red test going green (XPASS);
# without this list, a GREEN test going red was just one FAIL among many and read
# as "never passed". test_nav_path graduated on 2026-07-16 and silently
# un-graduated; nothing noticed, because nothing was watching for it.
#
# A test on this list that fails reports REGRESS, not FAIL. Removing a name here
# to quiet the board is the forbidden move - it is the same move as regenerating
# the fossil baseline.
$Graduated = @(
    "test_nav_path"
    "test_terrain_desync"
    "test_height_authority"
    "test_flat_damage"
    "test_smoke_all"
    "test_squad_break"
    "test_squad_invariants"
    "test_gib_contract_all"
    "test_firefight_len"
)
# DELISTED 2026-07-27 (Summoner: "remove the ai stress test from the probes"):
# test_arena_patrol. The stress arena is a sterile hand-wired debugging bench,
# not shipping world-build code, so its AI reaching COMBAT must not gate the
# build. It still RUNS and still reports - it just cannot mark a REGRESSION on a
# bench that answers to nothing the player sees.

# Line-start prefixes that mean "the engine complained". Any hit = FAIL, regardless
# of exit code.
#
# ANCHORED, and matched with .StartsWith() (ordinal), NOT -like: PowerShell wildcards
# treat "[NAV]" as a character class matching any N, A or V, which matched everything.
#
# The anchor is the whole point. The old rule was an unanchored `.Contains("[NAV]")`,
# so a test REPORTING its nav-warning count -- `print("[NAV] warnings counted: 0")` --
# failed itself by saying zero. Godot writes diagnostics at column 0; a test speaks
# mid-line on stdout. Measured 2026-07-19: that rule alone falsely failed
# test_ai_stress_arena and test_arena_patrol, and only those two.
#
# Nothing is lost by retiring the bare "[NAV]" pattern: nav_baker.gd:166,194 emit via
# push_error (caught by "ERROR:") and enemy_base.gd:1687 via push_warning (caught by
# the anchored WARNING form).
$ErrorPrefixes = @(
    "ERROR:"
    "SCRIPT ERROR:"        # Godot DOES print this -- measured 4x on 2026-07-19
    "USER ERROR:"
    "WARNING: [NAV]"       # NavBaker's bake-time invariant guards
    "USER WARNING: [NAV]"
)
# Unanchored, because this one appears mid-sentence inside a longer engine message.
$ErrorSubstrings = @(
    "previously freed" # "Attempt to call function ... in base 'previously freed instance'"
)

# Known-benign engine chatter. These are NOT whitelisted into silence: a test whose
# only error lines are these reports LEAK (loud, tracked in the tracking docs;
# the column is FLAKY at single-run resolution - measured LEAK/LEAK/PASS on
# byte-identical code 2026-08-13 - so never convict a change on one reading), not PASS.
# Anything not on this list is FATAL. Never add to this list to make a build green.
$BenignPatterns = @(
    "resources still in use at exit"     # GunFX combat_sting.wav outlives teardown (AUDIT-12)
    "ObjectDB instances leaked at exit"  # same root cause
    "Leaked instance:"
    "Resource still in use:"
    "Hint: Leaked instances typically happen"
    # A real leak, and the SAME severity class as the two AUDIT-12 lines above -- it
    # stays loud and tracked as LEAK instead of breaking the build. Measured
    # 2026-07-19: this gap was the single largest source of false FAILs (5 of 18),
    # larger than the "[NAV]" rule everyone blamed.
    "were leaked at exit"
    # Headless-only. The DUMMY rasterizer has no material storage, so this cannot
    # occur under a real renderer -- servers/rendering/dummy/storage/material_storage.cpp.
    'Parameter "material" is null'
    # Same family: the dummy rasterizer's own teardown. Deliberately matched on the
    # DUMMY type name rather than on "Pages in use exist at exit", so a real
    # PagedAllocator leak still fails the build. If Godot changes this mangled name the
    # test goes red and someone looks -- that is the correct direction to fail.
    "PagedAllocator: N20RasterizerSceneDummy"
)

Write-Host "=== RECONgame test suite ($($tests.Count) tests) ==="
$failed = 0
$results = @()
foreach ($t in $tests) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $tmpOut = [IO.Path]::GetTempFileName()
    $tmpErr = [IO.Path]::GetTempFileName()
    $timedOut = $false
    $proc = Start-Process -FilePath $godot -PassThru -NoNewWindow `
        -ArgumentList @('--headless', '--path', $root, "res://tests/$($t.Name)", '--', '--test-save') `
        -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
    # Touching Handle forces the object to cache it. Without this, Start-Process
    # -PassThru leaves ExitCode NULL, ($exit -eq 0) is false, and every test on the
    # board reports FAIL regardless of what it did.
    $null = $proc.Handle
    if ($proc.WaitForExit($TimeoutSec * 1000)) {
        $exit = $proc.ExitCode
    } else {
        $timedOut = $true
        try { $proc.Kill(); $proc.WaitForExit(5000) | Out-Null } catch { }
        $exit = 124
    }
    $sw.Stop()
    $out = (Get-Content $tmpOut -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue)
    Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue

    # Scan line-by-line so a benign leak line can be told apart from a real error
    # that happens to share the "ERROR:" prefix.
    $fatalLines = @()
    $benignLines = @()
    foreach ($line in ($out -split "`n")) {
        $hit = $false
        # NOT $t -- that is the outer loop's test FileInfo, and clobbering it blanks
        # every name on the board and silently breaks the $KnownRed lookup.
        $trimmed = $line.TrimStart()
        foreach ($p in $ErrorPrefixes)    { if ($trimmed.StartsWith($p)) { $hit = $true; break } }
        if (-not $hit) {
            foreach ($p in $ErrorSubstrings) { if ($line.Contains($p)) { $hit = $true; break } }
        }
        if (-not $hit) { continue }
        $benign = $false
        foreach ($b in $BenignPatterns) { if ($line.Contains($b)) { $benign = $true; break } }
        # PowerShell's NativeCommandError wrapper echoes the godot line; ignore the wrapper itself.
        if ($line.Contains("FullyQualifiedErrorId") -or $line.Contains("CategoryInfo")) { $benign = $true }
        if ($benign) { $benignLines += $line.Trim() } else { $fatalLines += $line.Trim() }
    }

    $ok = (-not $timedOut) -and ($exit -eq 0) -and ($fatalLines.Count -eq 0)
    $engineErrors = $fatalLines
    $isKnownRed = $KnownRed -contains $t.BaseName

    if ($timedOut) {
        $verdict = "TIMEOUT"
        $failed++
    } elseif ($isKnownRed) {
        if ($ok) {
            $verdict = "XPASS"   # fixed! remove from $KnownRed
            $failed++
        } else {
            $verdict = "XFAIL"   # expected, not counted
        }
    } else {
        if (-not $ok) {
            $verdict = if ($Graduated -contains $t.BaseName) { "REGRESS" } else { "FAIL" }
            $failed++
        }
        elseif ($benignLines.Count -gt 0) { $verdict = "LEAK" }   # green, but not clean
        else { $verdict = "PASS" }
    }

    $note = ""
    if ($timedOut) { $note = "<- exceeded the ${TimeoutSec}s box: hung, or slower than the box. Check before calling it hung." }
    elseif ($fatalLines.Count -gt 0) { $note = "<- " + (($fatalLines | Select-Object -First 1)) }
    elseif ($verdict -eq "LEAK") { $note = "<- resources leaked at exit (AUDIT-12)" }
    if ($verdict -eq "XPASS") { $note = "<- FIXED: remove from `$KnownRed" }
    if ($verdict -eq "REGRESS") { $note = "<- REGRESSION: this test was GREEN. " + $note.TrimStart('<', '-', ' ') }

    $results += [pscustomobject]@{ Test = $t.BaseName; Result = $verdict }
    Write-Host ("{0,-28} {1,-6} {2,6}s {3}" -f $t.BaseName, $verdict, [math]::Round($sw.Elapsed.TotalSeconds, 1), $note)

    if ($Verbose1 -and -not $ok) {
        $out -split "`n" | Where-Object { $_ -match "ERROR|freed|FAIL|\[NAV\]" } | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    }
}

$xfail  = @($results | Where-Object { $_.Result -eq "XFAIL" }).Count
$passed = @($results | Where-Object { $_.Result -eq "PASS" }).Count
$leaked = @($results | Where-Object { $_.Result -eq "LEAK" }).Count
$hung   = @($results | Where-Object { $_.Result -eq "TIMEOUT" }).Count
$regress = @($results | Where-Object { $_.Result -eq "REGRESS" })
Write-Host "=== $passed PASS / $leaked LEAK / $failed FAIL / $xfail XFAIL / $hung TIMEOUT (of $($tests.Count)) ==="
if ($regress.Count -gt 0) {
    Write-Host "REGRESSED (these were green): $(@($regress | ForEach-Object { $_.Test }) -join ', ')" -ForegroundColor Red
}
# A graduated test that vanished from the suite is a regression that hid by not running.
$ranNames = @($results | ForEach-Object { $_.Test })
$missing = @($Graduated | Where-Object { $ranNames -notcontains $_ })
if (-not $Filter -and $missing.Count -gt 0) {
    Write-Host "GRADUATED TEST MISSING FROM SUITE: $($missing -join ', ')" -ForegroundColor Red
    $failed += $missing.Count
}
if ($hung -gt 0) { Write-Host "hung: $(@($results | Where-Object { $_.Result -eq 'TIMEOUT' } | ForEach-Object { $_.Test }) -join ', ')" -ForegroundColor Red }
if ($xfail -gt 0)  { Write-Host "known-red: $($KnownRed -join ', ')" -ForegroundColor DarkGray }
if ($leaked -gt 0) { Write-Host "leaks: $(@($results | Where-Object { $_.Result -eq 'LEAK' } | ForEach-Object { $_.Test }) -join ', ')" -ForegroundColor DarkYellow }
exit $failed
