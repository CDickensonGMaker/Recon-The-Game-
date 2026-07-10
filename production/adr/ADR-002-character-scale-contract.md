# ADR-002: Character scale contract: 1.7132m + instance-space AABB normalization
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Amends `production/GAME_SCALE_STANDARD.md` (the "won't break" auto-normalize promise at lines 10-13 is now conditional on the instance-space fix); ratifies the Full Game Audit #2 decree, build-order item 2 (trust-restoration day).

## Context
RECONgame renders characters through `ModelActor` (3D GLB, the default renderer per the locked decision in
`scripts/visuals/model_actor.gd:1-11`), which normalizes any loaded character to the canonical height
`TARGET_HEIGHT_M = 1.7132` (`model_actor.gd:16`) — the number the sprite manifests, the hitzone bands, and
the 1.70m player eye height were all authored against. `production/GAME_SCALE_STANDARD.md` promised that
this auto-normalization made off-scale exports safe: "a 1.9m export won't *break*."

The promise failed in playtest R2 (bead n2ij: "character models render as specs in-world though glbs
measure ~1.9m"). Root cause, confirmed in the player's own `[MODEL]` diagnostic logs: `_aabb_of()`
(`model_actor.gd:138-152`) merges each `MeshInstance3D.get_aabb()` — a **mesh-space** box — and corrects
only by `a.position += mi.position`. It ignores the mesh instance's own basis/scale and every intermediate
node transform, most importantly the **armature compensation scale** that glTF exporters bake for cm-unit
rigs (Mixamo-style: vertices at ×100, armature node scaled 0.01). The GLBs therefore *render* at ~1.9m,
but `_aabb_of()` measures the raw 8-87m vertex data, and `setup()` (`model_actor.gd:45-50`) divides by
that — shrinking already-correct models a second time, by 5-50x.

Observed k values (logs, technical_director.md §A4): vc2_mainforce k=0.020, us_grunt k=0.028, vc3_sapper
k=0.028, vc5_nva k=0.046, vc1_farmer k=0.162, vc6_heavy k=0.204 — against the expected ~0.9 the
diagnostic's own hint names (`model_actor.gd:50`). The k spread also reveals every model was exported at a
different internal unit scale; a correct instance-space measurement would have silently absorbed that,
which is exactly why the drift stayed invisible until a human looked at the screen. This is doc-vs-code
drift of the audit's signature kind: the standard document described behavior the code never had.

## Decision
- **Canonical character height is 1.7132m** (`ModelActor.TARGET_HEIGHT_M`), top of helmet. All hitzone
  bands, eye lines, and sprite manifests derive from it. No other height constant may be introduced.
- **Export contract** (per `production/GAME_SCALE_STANDARD.md`): 1 Blender unit = 1 meter; feet at world
  origin (0,0,0); face **-Z**; author AT 1.7132m tall; Mixamo rig with named animations; sockets
  `MuzzlePoint / HandR / HandL / Head / Chest`; ~3-6k tris.
- **ModelActor normalization MUST measure the instantiated model in instance space** — transform each
  `MeshInstance3D` AABB by its transform relative to `_inst` (after `add_child`, so armature/export
  compensation scale is included). Raw mesh-space AABBs corrected by `mi.position` alone are forbidden.
- **Acceptance band: k in [0.8, 1.0]** for every character, where k = TARGET_HEIGHT_M / measured instance
  height. k outside the band = bad export or bad measurement; either fails.
- **A headless probe asserts the band per character.** The `[MODEL]` log line stays; the probe is the
  gate. No character GLB ships, and n2ij item 1 does not close, without a green probe run (Verification
  law, ADR-015: "likely fixed" never closes a bead).
- After the fix, verify the second-order risk named in analysis: Mixamo clips that key scale on
  hips/armature can re-break a normalized unit mid-animation; the probe should sample a playing clip.

## Consequences
**Buys:** the tiny-units P0 (playtest R2's worst visual) is fixed at the root, not per-model; artists get
a single pass/fail number instead of eyeballing; heterogeneous export scales are absorbed permanently; the
capsule-fallback sightings (guarded path when setup fails on an empty AABB) likely resolve with it.

**Costs (named — no free lunches):** instance-space measurement is slightly more code and must run
post-`add_child`, coupling normalization to scene-tree state; the [0.8, 1.0] band **rejects** wildly
off-scale exports the old promise claimed to tolerate — export discipline is now mandatory, and a hot
asset that fails the band blocks until re-exported; the headless probe adds suite runtime and one more
gate to feature velocity (that is its purpose).

**Work created:** the `_aabb_of` fix + probe land in the trust-restoration day (decree build-order item 2;
closes bead n2ij item 1 with before/after k values, alongside 8pbo's perf measurements); scale probe joins
the test-suite-eyes mandate (ADR-015); GAME_SCALE_STANDARD.md gets the band and the instance-space wording.

## Evidence
- `scripts/visuals/model_actor.gd:16` — `TARGET_HEIGHT_M: float = 1.7132` (verified).
- `scripts/visuals/model_actor.gd:45-50` — `setup()` scales by `TARGET_HEIGHT_M / aabb.size.y`, seats
  feet, prints the `[MODEL]` k diagnostic with the "~0.9 or bad export" hint (verified).
- `scripts/visuals/model_actor.gd:138-152` — `_aabb_of()` merges `mi.get_aabb()` corrected only by
  `mi.position`; ignores basis/scale and intermediate transforms — the bug (verified).
- `production/GAME_SCALE_STANDARD.md:6-17` — the 1.7132 canon, the export contract, and the amended
  "won't break" promise (verified).
- `production/war_room/analysis/technical_director.md` §A4 — root cause, observed k table
  (0.020-0.204), fix shape, second-order animation-scale risk.
- `production/war_room/synthesis.md` — wound #2 (three visual P0s) and build-order item 2.
- Beads: **n2ij** (P1, playtest R2 tiny units — item 1 closed by this fix + probe), **8pbo** (P2, perf
  baseline shares the trust-restoration day).
- Ground truth: `%APPDATA%/Godot/app_userdata/RECONgame/logs/recon*.log` `[MODEL]` lines from R2.

## Related
- ADR-001 (3D is the renderer; sprites far-LOD/fallback, capsule the guarded floor) — this contract is
  what makes that renderer trustworthy at range.
- ADR-015 (mechanical process laws) — the probe is this decision's Verification-law instrument.
- Beads n2ij, 8pbo; playtest R3 (ida9) verifies on-screen.
- Pillars served: **2 (Atmosphere)** — soldiers at human scale in the world; **1 (Outstanding gunplay)** —
  hitzone bands (HEAD 1.65, CHEST 1.30) only land on a correctly scaled body.
