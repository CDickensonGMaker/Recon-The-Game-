# SYNTHESIS — the nav-truth wave

**Arbiter, 2026-08-13 day session.** Analyses in `analysis/` (systems_designer,
devils_advocate). The godot-specialist seat went silent past its siblings and was killed
per standing practice; its verification role was covered by the DA's independent mechanism
check and by probe-gating every change. The Summoner ruled mid-council, verbatim: **"make
the ai walk all the real geometry in the game"** — FIX A shipped by decree, probe-gated.

## What shipped, and its evidence (all in `scratchpad bunker_entry3.log`, repo-verifiable)

1. **FIX A — the navmesh walks the real ground** (`nav_baker.gd`): where physics is
   double-sided (`backface_collision=true`, the repair marker for the GLB's inward
   winding), the nav source now carries winding-flipped faces too. Ground sheets
   (`NAV_GROUND_PREFIXES`: fb_terrain_mound, fb_berm_ring) flip in full; every other
   family's flipped faces still respect the 1.9 m roof line (`_cull_above_base`, shared
   with the listed roof cull) — a tower top or chow-hall roof was never walkable and did
   not become so. `agent_max_slope` 50→45 closes the inverse-fiction band against the
   physics default. The dead bake-cost print is replaced by per-bake `ms=` on the
   bake-done line.
   **Measured:** path heights 175.4–178.3 (was fictional flat 174.00), polys 4272→9557,
   capsule-blocked routes **19→4**, zero blocks by the mound, FSB bake **1970 ms async**
   (first number this instrument has ever produced), `test_nav_path` PASS,
   interior baseline identical (30/5 of 35), compound identical (8/8, 0 CUT).
2. **FIX B — casualty figures are flesh, not sandbags** (`site_planner.gd`
   FSB_SOFT_PREFIXES + counter): the audit's "548 colliders" was **refuted by measurement
   — 144** (18 figures × 8 parts). Boot line now reads `589 soft (…144 casualty-figure
   parts), 1901 hard` — exactly −144 from hard. No scoring/intel/litter path reads them
   (verified by systems). Priced costs accepted: one figure can eat the 2-layer soft
   budget; blasts always reach through figures. **NOT fixed:** the +6.5 m floating parts —
   placement, Blender-side, queued.
3. **The 81st parapet segment is killable** (`site_planner.gd` stray pass): a stray with
   no manifest entry is now HANDLED — co-located = duplicate hidden, offset = adopted.
   Measured: `fb_sbg_seg_046_001` was an export **rename** (its manifest twin absent from
   the GLB); adopted with twin kind/hp — **81 segments on the blast bus**. Sappers can no
   longer spend charges on a wall that cannot die. The manifest loop and stray pass share
   ONE adoption definition (`_wire_parapet_segment`).
4. **Chinook seats measured and keyed** (`seat_system.gd` FALLBACK_LAYOUTS,
   `heli_lift.gd` keying off the scene's own `tandem_rotor`): CH-47 layout authored from
   the GLB's measured envelope (`tools/probe_chinook_dims.gd`: fuselage 8.1 m ALONG X,
   nose −X, walls z ±0.9, floor 0.75). `test_seat_system` PASS with a new envelope guard
   plus a discriminator proving the UH-1 layout cannot silently return.
5. Drift corrected on touch: `siege_director.gd` "nothing re-bakes the navmesh" (false
   since BREACHING); bake-ms comment.

## PARKED (deliberate, with its landing plan)

**Cover-seek snap-to-face** — DA's objection sustained: the cover path is SHARED with the
player's own squad (`ally_base.gd:1759-1782`), and the raw `hit.position` snap is at eye
height 1.3 against a 3D arrival check — unflattened it makes cover unreachable. It re-tunes
his squad on a day he cannot watch, and his original ruling was "do it while I can watch."
The one-hour landing plan (Y-flatten, clamp, ring fallback, SFR --cover-probe numbers) is
in `analysis/devils_advocate.md`. **Next watched session.**

## Honest losses and open ends (named, not smoothed)

- **1 post OFF-MESH** (was fictionally "reachable"): one bunker interior genuinely fails
  the honest bake — clearance or doorway slope. Named in the probe log. His-eye or
  geometry follow-up.
- **4 routes CAPSULE-BLOCKED by `fb_bunker_revet_*`** at chord −0.4..−0.5 m — the probe's
  straight-line band clipping honest revetment lips, or genuinely tight lips. Posts 0, 6,
  14, 35. Verify in-game at his next playtest.
- Breach re-bakes now cost a measured ~2 s async mid-siege — fine on paper; watch the
  first siege.
- The demo gate RE-OPENS: the validated siege night ran on the fictional mesh. His
  re-play is the wave's real price (systems' verdict).

## FOR THE SUMMONER (added to the decision queue)

5. **Should assault squads use sapper breaches?** Breach re-bakes exist now — a satchel
   hole becomes walkable — but the siege still converges on the gate by design
   (`siege_director.gd`). Ruling wanted.
6. The off-mesh post and the four revetment posts: eyeball at next playtest (the probe
   names them).

## Water (scoped, not fixed — recorded here so the register is one place)

`test_height_authority` water check: **systemic, 2668 of 3365 wet channel points >2.5 m
off their bed** (worst 26.71 m at (786,1198)) — the flat-ribbon river level model vs
carved descending beds, full-world scale, no demo-square exposure (the wade gate has never
fired). A designed fix (stepped ribbon levels), queued post-demo. The test now prints the
distribution and worst point permanently.
