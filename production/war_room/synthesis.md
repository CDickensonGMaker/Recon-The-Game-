# Synthesis — 2026-08-11 Playtest Defect Sweep (DECREE — DA amendments folded in)

## Decree amendments from the Devil's Advocate (binding; see analysis/devils_advocate.md)
1. **Nav-clamp guard (W2/W3/W5):** never call `map_get_closest_point` unguarded — only
   clamp when `NavBaker.box_index_at(dest) >= 0`, cap the correction at ~12 m, copy the
   guard pattern at `nav_router.gd:37,67-69,87`. Unguarded, it snaps unbaked-ground targets
   to the FIREBASE mesh (teleports the squad back to base / drags villager homes 100+ m).
2. **W3 gate release stays COLLECTIVE** (`demo_game.gd:334-349` unchanged); add ONLY a
   release-all when the player himself passes the gate radius. Individual release would
   have men FOLLOWing back to the player on his bunk — beat destroyed.
3. **W3 path:** `scripts/squad/squad_system.gd` (not scripts/allies/). Add
   `GameManager.can_player_act()` to the teleport gate.
4. **W4 bake:** use `Skeleton3D.set_bone_global_pose` (4.4+) writing ascending bone-index
   order; skip unbound bones (`model_actor.gd:763-766`); DELETE the now-no-op
   `sleep_ragdoll` bake (`:706-716`, Fossil Law); gate the new `_physics_process` with
   `set_physics_process(false)` by default (hundreds of ModelActors live).
5. **W4→W5 civilian fossil:** replace the 90° pitch (`civilian.gd:712-713`) with
   `actor.settle_flat_corpse()` — the pitch was the only prone guarantee; bare delete
   leaves civilians dying standing. (Executed in W5, which owns civilian.gd.)
6. **W1:** `AudioEffectHardLimiter` has NO `threshold_db` — drop that line in the swap.
   Pitch jitter must be stored per-ship at build and applied inside `_drive_rotor_audio`
   (`helicopter.gd:121` re-stamps pitch_scale every frame). Rename must update
   `source_file=` inside the renamed `.import`; `bolt_ak47.wav` will be DORMANT (AK is
   auto; `play_bolt_player` fires only for BOLT_ACTION) — that is accepted, it parks the
   recording. One editor-open reimport owed before the playtest.
7. **W5 rescue snap:** `_self_out` is NavRouter-private and empty for direct-steerers —
   expose a guarded `nearest_mesh_point()` on NavRouter instead.
8. **W2 fan spacing:** real load is 6 pax (max fan 6.9 m — fits the pad); boarding stick
   stays at 1.4 m spacing (0.6 m margin under `BOARD_NEAR_M`) — do not widen.

DA confirmed safe: W4 body_offset inverse math matches the engine, no sim feedback, cap
path clean; sole `unseat_all` caller is `heli_lift.gd:280`; `_single` has no fallback bank;
`player.gd:1901-1906` lowpass append is index-safe; no test goes red from any wave.

Arbiter's weave of the three analyses (`analysis/audio_architect.md`,
`analysis/systems_architect.md`, `analysis/ai_anim_architect.md`). All seven defects have
confirmed root causes with pointers. The council converged with no conflicts; the one
structural finding is that defects 5 and 6 are ONE bug (ragdoll poses never written back to
the skeleton), and fixing it also repairs corpse hitzones tracking a standing ghost.

## Fix waves (independent files — can run in parallel)

### W1 — Audio (defects 1, 7)
- `scripts/vehicles/helicopter.gd`: `ROTOR_DB_FULL` 2.0→−8.0, `ROTOR_DB_IDLE` −14→−22,
  `max_db` 0→−6, `unit_size` 55→30, per-ship pitch jitter ±0.03 in `_build_rotor_audio`.
- `assets/audio/default_bus_layout.tres`: Vehicles bus `volume_db` 0→−6; Master's deprecated
  `AudioEffectLimiter` → `AudioEffectHardLimiter` (ceiling −0.8).
- Rename `assets/audio/sfx/weapons/mech_ak47.wav` → `bolt_ak47.wav` (empty slot; per-shot
  mech layer then skips cleanly at `audio_manager.gd:330`; rack recording preserved in the
  reload/bolt slot). Rename its `.import` sidecar in the same change. Audit `mech_car15.wav`
  (same Jul-29 batch, same size class) for the same miscast.
- NOT doing: synth-regen of a short AK mech layer (needs the landmine tool; defer to a
  deliberate session with Caleb's ears).

### W2 — LZ dispersal (defect 2)
- `scripts/vehicles/seat_system.gd` `unseat_all`: iterate `PASSENGER_SEATS` only (pilots
  stay aboard — honours `heli_lift.gd:119` contract, kills the pilot-blink bug); per-index
  fan on the door side (radius 2.5+0.9·i, ~140° arc on door normal), each point through
  `_exit_ground`.
- `seat_system.gd` `board_squad`: per-man staging slots (`staging + side·1.4·i`) so the
  extraction queue is a stick line, not one point (`BOARD_NEAR_M` 8 m already tolerates it).
- `heli_lift.gd:294-300`: clamp each bunk target via `NavigationServer3D.map_get_closest_point`
  (precedent `nav_router.gd:86`).
- Fix the `heli_lift.gd:119` comment if any wording is now stale (drift law).

### W3 — Squad catch-up (defect 3, direction pre-approved by the Summoner)
- `scripts/allies/squad_system.gd`: `_catchup_tick()` on 1 s cadence in `_physics_process`.
  Teleport a member when ALL: FOLLOW mode + squad_member; out of combat (no target, last
  seen >5 s); distance >40 m OR (>25 m AND behind camera plane via `is_position_behind`);
  player not seated in a vehicle; ally not seated. Placement: behind player
  (6.0+1.5·slot m), nav-clamped, ground ray, `reset_physics_interpolation()`, invalidate
  slot smoothing. Stagger members across ticks.
- `scripts/levels/demo_game.gd:301-353`: release each man to FOLLOW individually on his own
  gate arrival; release-all the moment the PLAYER passes the gate radius. Keep the M-4
  arrival print as the regression canary.

### W4 — Ragdoll pose bake (defects 5 AND 6, + corpse hitzones)
- `scripts/visuals/model_actor.gd`: while `_ragdoll_sim.is_simulating_physics()`, copy each
  `PhysicalBone3D` global transform into its bone pose every physics frame
  (`skel.global_transform.affine_inverse() * pb.global_transform * pb.body_offset.affine_inverse()`);
  active only during the ≤4 s window, ≤12 concurrent (`MAX_ACTIVE_RAGDOLLS`). `sleep_ragdoll`
  then stops simulation with poses already true — no bake-from-`get_bone_global_pose()`
  (which reads pre-modifier poses by 4.3+ contract and was the whole bug).
- Fixes for free: BoneAttachment3D gear (NVA/VC belts/headgear/packs) follows the fall;
  corpse hitzones stop tracking the standing ghost.
- Small adjacent fossil (flagged for DA): `civilian.gd:712-713` pitches the CharacterBody 90°
  on death WHILE a death clip plays — double-lay. Proposed: delete the pitch (capsule-era).

### W5 — Civilian/VC nav unstick (defect 4)
- `scripts/world/civilian.gd`: clamp teleport targets (`place_for_current_hour`,
  `_resolve_target`, `_bt_settle` jitter) to the navmesh when a region covers them, else
  reject points inside `nav_blockers` boxes; clamp FLEE targets the same way.
- Port the enemy 1 s stuck watchdog to Civilian; escalation for all three NPC bases: stuck
  after ~3 alternations AND off-mesh AND not perceivable → snap to cached nearest-mesh point.
- RETEST DEPENDENCY: firebase doorway-width erosion is geometry-dependent — re-verify
  defect 4 at the firebase after the pending export lands.

## Named sacrifices (Law 2)
- W1: the flyby loses raw loudness (its emotional weapon) for clean level; HardLimiter adds
  tiny full-mix lookahead latency; final ±2 dB belongs to Caleb's ears.
- W2: future crew-bailout needs its own explicit unseat; wider fan risks off-navbox
  placement (bounded by ground-cast + clamp); stick line adds a few metres walk in the
  35 s ground window.
- W3: teleport hides the real off-navbox pathing failure (nav_router direct steering) —
  it stays broken for non-teleporting walkers; a rear-view player can catch a 25 m-tier pop.
- W4: per-frame pose writes for ≤12 corpses × ~50 bones × 4 s — real but bounded cost.
- W5: interior work markers drift to the nearest walkable point (villages); rescue snap is a
  simulation lie gated on non-perceivability; villagers stop cutting through their own homes.

## Out of scope (recorded, not fixed now)
- `settle_flat_corpse()` picks the first alphabetical death clip, not the one that played —
  minor pose pop on capped-ragdoll kills.
- Synth mech layer for the AK (landmine-tool session).
- Off-navmesh direct-steering architecture (nav_router box coverage) — the teleport is the
  approved bandage; the road needs its own council.
