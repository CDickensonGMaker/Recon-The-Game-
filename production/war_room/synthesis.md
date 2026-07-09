# THE DECREE — Full Game Audit (2026-07-09)

Five architects audited the whole game independently (analyses in `analysis/`). The Arbiter weaves.

## The one-line diagnosis (all five converged on it)
**The simulation is built; the presentation and verification are skipped.** The mission loop, detection
ladder, squad XP, fire support, terrain destruction, and campaign persistence genuinely work — and the player
can't hear, see, or trust most of it. The game is better than it feels.

## Pillar scorecard (council average)
| Pillar | Score | Verdict |
|---|---|---|
| 1. Outstanding gunplay | **3.0** | feedback loops good; 19-25 FPS + two damage grammars + fixed hitzones undercut it |
| 2. Atmosphere | **2.8** | LOWEST. 162 finished VO files unwired; ambience is a global 2D loop; the war is silent |
| 3. Freedom | **3.4** | strongest. Open AO + escalation real; kill-count gates + RTO-death fail-state fight it |
| 4. Squad is the RPG | **3.2** | XP/learn-by-doing is the best new system; squad controls reportedly broken (r4bk); loss is costless |
| 5. Fail forward | **3.4** | escalation yes; death=restart, capture unbuilt |

## What is genuinely strong (keep building on these)
1. **The mission-loop skeleton** — probe-proven MissionScope resets, seeded determinism, versioned saves, 34-scene headless test suite.
2. **The stealth-escalation economy design** — tiers, noise, finite QRF pools, heat-weighted exfil.
3. **Squad XP / learn-by-doing** — the best-designed new system in the game (mis-priced, not mis-designed).
4. **Fire-support ladder** — budgets, RTO gating, the on-the-net ritual.
5. **One coherent UI language** + in-fiction toast writing.

## The wounds, ranked (with owners)
1. **BUGS IN THIS WEEK'S CODE (fix TODAY, mine):** danger-close confirm is unreachable (menu closes before the
   pend — 2nd press switches weapons); stale `_pending_danger_close` never expires; **key 6 double-bound**
   (cbu_strike + place_claymore, physical 54); Y-mortar/supply-drop bypass the 10m RTO leash; point-scan runs
   at 60Hz (unused throttle var). *Status: fixed same-day as this decree — see addendum.*
2. **SILENCE (the #1 felt absence):** 162 DSP-processed VO wavs + role casting sit with zero .gd references
   while every bark already fires as a toast. **THE ONE BUILD: a VOManager autoload routing existing
   `toast`/bark hooks to the vo library** (text stays as subtitles). Compounds atmosphere + squad + ritual at once.
3. **PERF (gates gunplay):** 19-25 FPS likely renderer-level — `rendering_method` never set (Forward+ on Intel
   UHD); scar decals uncapped past the deform ceiling; an OmniLight per muzzle flash; no AI frame budget.
   **One measured perf-spike day** before any M6 work.
4. **STEALTH IS VOIDED BY ONE LINE:** `take_damage()` unconditionally stamps COMBAT contact — an unwitnessed
   silent kill still triggers "YOU'VE BEEN MADE". One-line class of fix; re-activates the whole ghost economy.
5. **TWO DAMAGE GRAMMARS:** RECON dice (M16 5d10≈27.5) vs HoD legacy flat (Thompson 1d6+45≈48.5) — and the
   **Thompson is still the hardcoded default primary**. Unify on RECON dice; default M16; kill dead .tres.
6. **PLAYTEST DEBT:** ~30 commits since the last human playtest; its 3 P1 bugs still open (a2qb Huey seating,
   r4bk squad controls, e6qc). **Council law adopted: no new system ships while a P1 playtest bug is open.**
7. **THE CAMPAIGN IS FLAT:** nothing scales with missions_played; offer labels ("ENEMY: HEAVY") never read by
   the generator; nothing to win; squad loss costless (instant free rookies). M8 work, but cheap partials exist
   (read the label, scale populations, wound-not-dead rookies pipeline).

## Scope decree (Summoner holds final authority — these are recommendations)
- **KILL:** the sprite render matrix (9xd/j8o, 15-20h) — 3D models are the renderer now. A/B far-LOD with the
  3 existing sheets before deleting anything.
- **FREEZE (post-core):** coop, interior mode, driveable vehicles, RPG shop, capture epic, battle director,
  ride-or-walk. They're good epics *later*; they're scope-rot *now*.
- **SHRINK:** 100 bios → 20 great ones; HQ tent → menu-first version.
- **KEEP HOT:** VO wiring, perf spike, playtest-bug gate, stealth fix, damage unification, detection pip (#46's
  other half), EnemySquad/detection keystones, M6 generator depth.

## Build order (the decree)
1. TODAY: fire-support bug cluster (item 1) ✅ same-day
2. Playtest gate: fix a2qb + r4bk + e6qc, then a real human playtest session
3. **VO wiring (VOManager)** — the ONE build
4. Perf-spike day → close 8pbo with measurements
5. Stealth witnessed-contact fix + detection "being noticed" pip
6. Damage-grammar unification (RECON dice everywhere, M16 default)
7. Cheap campaign-scaling partials, then M6 generator depth

## Tradeoffs named
Freezing epics trades breadth for a shippable core. Killing sprites abandons sunk render work (~600 frames) in
exchange for one renderer path. The playtest gate slows feature velocity deliberately. VO-first beats new
mechanics because atmosphere is the lowest pillar and the assets already exist. No free lunches.
