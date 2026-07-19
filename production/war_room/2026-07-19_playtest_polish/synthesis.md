# DECREE — Playtest Polish Pass (2026-07-19)

Council: systems-designer, technical-director, devil's-advocate. Arbiter: Overseer.
Briefing: `briefing.md`. Analyses: `analysis/`.

## THE COUNCIL OVERTURNED THE PREMISE

The task read "wire civilian damage." Three architects independently found the damage path does not
exist at all:

- `civilian.gd:234 take_damage()` takes **3 params**; every caller passes **4**
  (`bullet_system.gd:147`, `weapon_holder.gd:634`). `has_method()` checks the name, not the arity —
  so the first civilian hit was always going to be a runtime error, on any collision layer.
- `take_damage()` has **zero callers project-wide**. `CombatManager.apply_explosion_damage`
  (`combat_manager.gd:138-207`) iterates player/allies/enemies only. Civilians are immune to
  **everything**, not just bullets.
- Therefore F1 is not "extend the damage path to civilians." It is "build it." The layer question
  was an arity question in a layer costume.

## THREE LIVE P0s FOUND, NONE OF THEM ON THE TASK LIST

**P0-1 — civilians freeze permanently past 305m.** `civilian.gd:361` calls
`set_physics_process(new_tier != LOD_FAR)`, but `_update_lod()` only runs *from* `_physics_process`
(`:127`). Once a civilian tiers to FAR it can never tier back — the function that would restore it
is the one that was just switched off. Villages generate while the player is still at the firebase,
so **most villagers in the AO are frozen statues before the player ever arrives**. The comment at
`:129-131` promises a "SimClock.hour_advanced listener below" that **does not exist**.
This alone would have made the Batch B animation work read as a failure.

**P0-2 — the armed-idle chain.** `civilian.gd:217 play_first(["idle", ...])` returns on `idle`,
which is the **rifle** idle; `idle_unarmed_*` is never reached. `:209` COWER →
`idle_crouching` = a rifleman weapon crouch. Gunfire within 60m flips the whole village to
FLEE/COWER (`:116-121`). **This is the "crouched aiming poses" the owner saw** — the village read as
an ambush because every villager was posed as a rifleman. Zero new art required.

**P0-3 — the corpse headshot ghost.** `civilian.gd:240 rotation_degrees.x = 90` rotates child
hitzones with the body. A HEAD zone at local y≈1.65 lands **1.65m horizontally, at chest height,
invisible, for 30 seconds** (`:244`) — eating rounds and reporting headshots. A hard prerequisite
for giving civilians hitzones at all.

## RULINGS

**F1 — a dedicated civilian hurtbox layer (512), player fire masks only.** Unanimous on (b).
Rejected (a)/layer-64: it is a semantic lie, it makes villagers valid over-penetration targets
(`bullet_system.gd:163`), it arms rockets (`projectile_base.gd:97`), and — the briefing was wrong
here — it does *not* avoid AI-kills-villagers, because all three shooters share mask `1|32|64`.
Layer 512 added to the player's fire masks only keeps the safety valve: AI strays pass through
villagers. **Sacrificed:** AI rounds passing through a body is unrealistic and visible. Accepted as
the cheap, reversible half — widening to AI masks is one line when the Summoner wants it, and that
is a fun-lever needing his eyes.

**F2 — delete the player's hand-placed hitzone set now** (`player.gd:880-924`). Unanimous. The
Devil's Advocate measured the geometry: Godot clamps capsule height to 2×radius, so the two sets are
effectively identical and **no balance depends on the bug**. But the real defect is worse than
duplication: `_build_static` sets `region` meta (`hitzone_builder.gd:576`) and `_create_hitzone`
does not, so region reporting is a **coin-flip between a real region and `""`** — an ADR-010
determinism hole. Fossil law applies; delete, do not bead.

**F3 — ship the pose fix, bead the art.** Strip `idle`/`idle_crouching` from the chain heads and
give the scheduled actions distinct unarmed poses from the 100 shipped clips. Per-action
differentiation beyond that is **not** honest — WORK/COOK/FISH/TALK/REST have no clip, and the
authored ones already exist unmerged in `tools/make_civilian_anims.py`. A convincing placeholder
makes that debt permanent, so the merge bead ships **in the same commit** or it never happens.

**F4 — probe now, Blender fix behind a measurement.** The offset is baked
(`tools/make_civilians.py:166 HAT_NUDGE`, `:170-174 HAT_DZ`); Caleb's two prior fixes are `0abdf2fb`
and `32ccc84f`. A headless probe *can* do this — `tools/probe_worn_gear.gd` is the precedent.
Measure in head-bone rest space as a fraction of the skull span (the same measure
`hitzone_builder.gd:114` uses) so it is scale-invariant across the 1.28–1.65m units. Gotcha: stale
globals — `force_update_all_bone_transforms()` plus two frames.

**F5 — straps: re-author the `.blend`, do not runtime-tint.** `GruntDresser.dress()` has zero game
call sites (bead 37mj), so tinting there fixes nothing and ships a fossil on arrival. **Deferred
this session** — re-exporting `us_base_v3.blend` touches every US model and is not a budget-safe
move alongside a new damage cohort.

**F6 — traps: DEFER.** Unanimous. `punji_trap.gd` is a plain `Node3D` with no collision body at all;
destructibility is new geometry plus a fourth damage-receiver pattern, and explosions could not
reach it anyway (`combat_manager.gd:138-208` iterates three hardcoded registries). That is a
feature, not polish, and this session already carries a new damage cohort.

**PERF — the gate is not `set_physics_process`.** `HitzoneBuilder.build()` connects `sync()` to
`skeleton_updated` (`hitzone_builder.gd:160-166`), so disabling physics does **not** stop zone sync.
Measured scale: 8–10 villages/AO (`location_planner.gd:59`) × 2–4 civilians
(`mission_generator.gd:559`) = **16–40 civilians**; ~160µs/actor/tick (PERF_LEDGER 10.43ms ÷ 65
units) = **6.4ms/frame ungated, ~38% of budget on a 28.8fps game.** Civilians use the 7-capsule
`_build_static` path, not 11 convex hulls, and zones are freed at death.

**The ROE hook** is a *called, empty function* — `_record_noncombatant_death()` — not a signal and
not an uncalled function, either of which turns `test_fossils.gd` red. It replaces the existing
`civ_casualties` flag and the **"CIVILIAN DOWN. THAT FOLLOWS YOU HOME."** toast, which is a promise
the game does not keep — a false felt-consequence poisons the channel before the ledger exists
(ADR-019 §4). Report, do not threaten.

## WHAT IS SACRIFICED
- AI bullets still pass through civilians. Visible, unrealistic, deliberate.
- Villagers get distinct poses that are still not *working* poses. The art debt is real and beaded.
- Straps stay white and traps stay indestructible this session.
- Killable civilians ship with no consequence ledger — by explicit owner decree.

## ORDER OF WORK
P0-1 → P0-3 → arity → F1 → explosion loop → toast/header truth → F2 → P0-2/F3 → probes.
