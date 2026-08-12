# Playtest Findings — 2026-08-11 (Caleb, demo build)

Source: Caleb's own playtest of the demo version, reported verbatim same day.
Context: playing while waiting on the next firebase export. Overall read: "lots of great
stuff happening" — these are the defects, not the verdict.

## What worked
- Huey flybys land well as a spectacle.
- Dropped-off troops each ran a DIFFERENT idle animation — variety pass is visibly paying off.

## Defects (unverified in code — diagnose before budgeting)

| # | Finding | First read | Sev |
|---|---------|-----------|-----|
| 1 | Huey flyby audio so loud it compressed the speakers — audible crunching/clipping | Mix bug: stacked loud sources (rotor + engine + doppler?) with no limiter or per-bus ceiling. Check master bus limiter and Huey source volumes/attenuation. | P1 — hurts the best moment in the demo |
| 2 | Dropoff troops stack on top of each other at the LZ edge, then idle in a pile | Dropoff pipeline gives them one shared destination (or none). They need dispersal points / spread-out move targets after unload. Idle variety itself is GOOD. | P1 — flagship sequence looks broken |
| 3 | Player left the base; squad never caught up | Follow logic loses the player at range. Caleb's own suggested fix: invisible teleport/catch-up when squad falls too far behind (standard genre solution — he has pre-approved this direction). | P1 — strands the core companion fantasy |
| 4 | Villagers AND VC getting stuck inside buildings | Navmesh vs. building interiors/doorways, or nav agent radius. Note the new firebase export will change nav geometry — retest after. | P1 |
| 5 | On death, bodies fall down then SNAP BACK UP into a standing pose while dead | Death anim finishes then something re-poses the rig (idle state re-entry? pose reset on anim end? ragdoll → animator fight). | P1 — visibly breaks every kill |
| 6 | A dead body's belt came off / detached weird | Gear attachment vs. death pose — likely a bone-attached prop whose parent bone moves oddly in the death anim, or gear not following ragdoll. | P2 |
| 7 | AK fire SFX has a bolt-racking noise after EVERY shot | Rack/charging-handle tail baked into (or chained after) the fire sample. AKs don't rack per shot — strip the tail or gate it to reload only. | P2 — cheap fix, constant irritant |

## Rulings implied
- #3: teleport catch-up for the squad is Caleb's own proposal — treat as approved direction, not an open design question.

## FIX STATUS — all 7 built 2026-08-11, same day (War Room full ritual; see war_room/synthesis.md)

| # | Status | Where |
|---|--------|-------|
| 1 | FIXED | `helicopter.gd:90-92,107,123` (levels, unit_size, per-ship pitch jitter); `default_bus_layout.tres:3-4` HardLimiter swap, `:91` Vehicles −6 dB |
| 2 | FIXED | `seat_system.gd:379-398` passenger-only fanned unseat; `:401-427` boarding stick line; pilots no longer ejected (bonus bug found by council) |
| 3 | FIXED | `squad_system.gd:561-632` guarded teleport catch-up; `demo_game.gd:342-351` gate order releases when player exits perimeter (gate OR berm) |
| 4 | FIXED* | `nav_router.gd:56-74` guarded `nearest_mesh_point`; `civilian.gd` target clamps + stuck watchdog + rescue snap; same escalation on enemy/ally. *RETEST at firebase after the pending export (doorway erosion is geometry-dependent) |
| 5 | FIXED | `model_actor.gd:708-718` per-frame ragdoll→bone-pose bake (root cause: simulator is a SkeletonModifier; poses never tracked the fall). Also fixes corpse hitzones tracking the standing ghost |
| 6 | FIXED | Same fix as #5 — BoneAttachment3D gear now follows the fall. Civilian death double-lay fossil also replaced (`civilian.gd` settle_flat_corpse) |
| 7 | FIXED | `mech_ak47.wav` → `bolt_ak47.wav` (miscast real rack recording out of the per-shot slot; recording preserved). `mech_car15.wav` probed: same batch but front-loaded — left alone |

**Before the verification playtest:** open the editor once so the renamed `bolt_ak47.wav`
reimports. Verify: flyby with no crunch; troops fan out at the LZ; jump the berm and the
squad appears behind you; kills stay down with belts on; AK has no shk-shk.

## Process
- War Room ritual ran in full: 3 architects + Devil's Advocate (3 landmines caught pre-build,
  incl. an unguarded nav-clamp that would have teleported the squad TO the firebase).
- #4 interacts with the pending firebase export — retest after it lands.
