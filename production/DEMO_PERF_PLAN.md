# DEMO GAME PERF PLAN — the siege frame, ranked (2026-07-29)

Scope: `scenes/levels/demo_game.tscn` → `scripts/levels/demo_game.gd` — 512m slice
(`game_flow.gd:412` `DEMO_MAP_SIZE = 512.0`), seed 29072026 (`demo_game.gd:14`), arc: probe
strength 11 at 600s, **main siege `open_siege(40)` at 720s** (`demo_game.gd:26-30`), dawn 1080s.
Renderer is Forward+ by ratified decree (ADR-026 Amendment A, `ADR-026:144-147`) — no renderer
proposal appears anywhere in this plan. Tri cuts measured ~0 FPS (`PERF_LEDGER.md:95-104`); the
targets are CPU and draw calls only.

**POINTER LAW compliance:** every measured number below carries its ledger or code pointer. Numbers
from the 18v18 arena / 65-unit headless bench are the nearest measured proxy — **the demo scene
itself has NEVER been measured** (it is new; no ledger row exists for it). That is finding #0.

---

## 0. Corrections to the briefing's own premises (verified against code)

1. **`MAX_THINK_TIME` is NOT in `enemy_base.gd` — it was already deleted.** Zero `.gd` hits
   repo-wide; only prose survives (`GAME_GUIDE.md:163` confirms "the symbol does not exist anywhere
   in `scripts/` or `tests/`"). Nothing to wire, nothing to delete. Do not schedule work against it.
2. **The `world_config` "ladder nothing reads" claim is STALE.** `VEGETATION_DENSITY_MULT`
   (`world_config.gd:16`) IS read — `terrain/vegetation/vegetation_manager.gd:291`. `NAV_ENABLED`
   (`world_config.gd:34`) is read at `enemy_base.gd:2523`, `ally_base.gd:1445`, `nav_router.gd:33,44`,
   `mission_generator.gd:809`. The destruction throttles are read at
   `terrain/systems/damage_system.gd:178,181`. The ladder is wired; it is just a GPU/geometry dial,
   and geometry is not the limiter. The old audit (`war_room/analysis/audit_dead_code.md:376`)
   described a codebase that no longer exists.
3. **The hot-set is no longer a throttle at siege scale.** `HOT_CAP = 50, HOT_CEILING = 64`
   (`enemy_squad.gd:42-43`), raised 12→50 by Summoner ruling 2026-07-28 on the ledger's own
   attribution (comment at `enemy_squad.gd:37-41`). A 40-strength siege never fills the cap: every
   attacker in COMBAT runs `_think_full_combat()` (`enemy_base.gd:602-604`). Tiering is effectively
   OFF during the demo climax — by design, and the measured think cost says that is affordable
   (see §1).
4. **LANDMINE (correctness, not perf): the demo never overrides the siege's assault geometry for
   the 512m map.** `siege_director.gd:68-76` says a host with a smaller map must override
   `ring_min/ring_max/rally_m/mortar_standoff_m` after `setup()` — the arena does
   (`ai_stress_arena.gd:1433-1437`); `demo_game.gd:77-93` (`_open_siege` → `_attach_siege`,
   `field_director.gd:1260-1267`) does not. On a 512m map, cells spawn 300–500m from `fsb_center`
   (`siege_director.gd:20-21,186`) — off the heightmap — and march at 2.2 m/s
   (`marching_cell.gd:16`), so the "minute-12 siege" first materializes bodies ~100–190s later and
   the mortar tube stands 700m out (`siege_director.gd:51`). Fix before any bench: the bench must
   measure the fight the demo actually fields.

---

## 1. Expected worst-frame composition at the siege

**Bodies at peak** (~730–900s): up to **40 attackers** (strength 40; `LIVE_CAP = 50` at
`siege_director.gd:36` never binds), arriving as 3–6-man cells that materialize at 80m
(`marching_cell.gd:15,108-126`) — plus the **promoted garrison** (`field_director.gd:1228-1236`,
fired from `_on_siege_began`, `field_director.gd:1271`), the player's squad, and the player.
Call it **~50–65 live combatants**, all in COMBAT tier, all with the WA-A2 body gate OPEN
(`enemy_base.gd:539` — COMBAT pins the gate), all hot (§0.3).

**Per-body cost paths, every physics tick** (`enemy_base.gd:_physics_process`, 455-531):

| path | pointer | measured proxy (65–71 live, headless, per physics frame) |
|---|---|---|
| `HitzoneBuilder.sync` | `enemy_base.gd:463-470` → `hitzone_builder.gd:188-225` | ~3.7–4.3 ms (`PERF_LEDGER.md:335-339`) — **and it is an undercount, see §2.1** |
| `move_and_slide` + steps | `enemy_base.gd:524-529` | ~3.0–3.2 ms |
| `_execute` + `_update_sprite` + decay ("anim" bucket — behaviour, NOT skeletal animation, `PERF_LEDGER.md:1055-1057`) | `enemy_base.gd:499-513, 1265-1302, 389-438` | ~7.0–7.5 ms |
| `_think` at 0.15s (→0.3s past 80m, 0.6s past 150m LOD) | `enemy_base.gd:31, 37-52, 504-509` | ~0.43–0.45 ms — **the cheap term** |
| perception ray, 1/think/man | `enemy_base.gd:878-881` | rays are ~2.6/frame level-wide = microseconds (`PERF_LEDGER.md:290-304`) |

Sum ≈ **14–15 ms per physics tick at ~65 live** (`PERF_LEDGER.md:335-339`, the honest per-unit
figure is **~0.22 ms/unit/tick**). At 60 physics ticks/s that demands ~900 ms/s of CPU — the tick
saturates (8-step clamp observed, `PERF_LEDGER.md:292`), which is itself the death spiral.

**Counted NOWHERE (the blind spots):**
- **Skeletal animation** — one `AnimationPlayer` per body (`model_actor.gd:105,126`), advancing
  every render frame; **there is no animation LOD anywhere in the project**
  (`PERF_LEDGER.md:1050-1051`), and the `ai_usec_anim` bucket contains zero animation time
  (`PERF_LEDGER.md:1055`).
- **The render-frame hitzone re-sync** via `skeleton_updated` (`hitzone_builder.gd:164-166`) —
  outside every usec bucket (`PERF_LEDGER.md:1052-1057`: "true hitzone cost is HIGHER than 10.43ms").
- Transients: mortar volleys every 20–25s (`siege_director.gd:270`, 3 shells ×
  `apply_explosion_damage`'s 8-ray multipoint checks per victim, `combat_manager.gd:210-241`),
  blood `CPUParticles3D` pairs per hit capped at 12 concurrent (`gun_fx.gd:67,549-607`), bullets,
  ragdolls (capped, `model_actor.gd:551,562`).

**Instrumentation that proves it, already live:** `CombatManager.ai_usec_think/move/hitzone/anim`,
`rays_*`, `bodies_run/bodies_gated` (`combat_manager.gd:16-32`) — accumulated by every enemy tick.
**But only `ai_stress_arena._report_ai_buckets` reads them (1 Hz)** — the demo scene reports
nothing. Wiring a 1 Hz delta-print of those counters plus
`Performance.get_monitor(TIME_PHYSICS_PROCESS)` and
`RenderingServer.viewport_get_measured_render_time_gpu/cpu` into `demo_game.gd` is the
prerequisite for everything below (~20 lines; the arena code is the template).

---

## 2. THE RANKED LIST — expected ms recovered vs effort

Detectability floor on this hardware: **~2.4 ms / ~3 FPS** (A/B/A floors 1.1/1.4/2.8 FPS,
`PERF_LEDGER.md:977-979`). Anything promising less ships only with a counter that moves.

### #1 — Physics tick 60→30 (`physics_ticks_per_second`), riding the already-ON interpolation
- **What:** one line in `project.godot`. `physics_interpolation=true` is already enabled and
  unexploited (`PERF_LEDGER.md:1052-1054`, `project.godot:300`).
- **Why it is #1:** the entire measured AI wall — sync, move_and_slide, execute, think — is
  per-physics-tick (`enemy_base.gd:455-531`). Halving the tick halves the per-second cost of all
  of it at once: the only lever that touches all ~14–15 ms/tick × N ticks in one move.
- **Expected:** up to ~half the AI-CPU share of the frame at the siege — plausibly **5–15 ms/frame**
  at 50+ bodies. The single biggest candidate on the board.
- **Gates:** `ballistics.gd:37` derives `dt` from the tick rate (verify bullets still fly true);
  hitzone staleness doubles to ~33 ms between syncs (acceptable — corpses already re-sync at 6 Hz,
  `enemy_base.gd:462-468`); **Summoner feel call** on 30 Hz movement/aim (interpolation should hide
  it — that is what the flag is for). Ledger already names this "a one-line candidate — a Summoner
  feel call" (`PERF_LEDGER.md:1052-1054`).
- **Validates by:** A/B/A at the siege; `ai_usec_*` per-second deltas must halve; FPS delta above
  floor; bullets/ADS look-check.

### #2 — Kill the hitzone DOUBLE-SYNC (the WA-A2 leak)
- **What:** `hitzone_builder.gd:164-166` connects an **ungated** closure to
  `Skeleton3D.skeleton_updated`, so every body pays `sync()` once per render frame **on top of**
  the physics-tick call at `enemy_base.gd:463-470`. Known defect (`PERF_LEDGER.md:1023-1025`).
  Fix: stamp a frame-id in `sync()` and skip the second call in the same frame, or gate the signal
  path on `_body_hot` and drop the physics-tick call for models whose skeleton fired this frame.
- **Expected:** hitzone bucket was ~10.4 ms/pf at 65 live on W0 (`PERF_LEDGER.md:297`) and the
  render-frame half is uncounted on top; de-duping should bank **~3–6 ms/frame** at siege scale.
- **Also in the same file, same pass:** `hitzone_builder.gd:225` writes `hz.global_transform`
  → 11 parent-inverse computations per man per sync where 1 would do
  (`PERF_LEDGER.md:1026-1027`); compute the body-inverse once per sync and set local transforms.
- **Validates by:** `ai_usec_hitzone` delta at 1 Hz (physics side) + whole-frame CPU ms (render
  side — the uncounted half only shows there). Sign check: hit registration probe
  (`tests/test_body_gate` contract) stays green; shoot a running man in the limbs.

### #3 — Animation/skeleton LOD by distance (build the missing system, small)
- **What:** no anim LOD exists (`PERF_LEDGER.md:1050-1051`). Add a distance tier in `ModelActor`:
  beyond ~70m (ADR-026 A.2's own unit-LOD line, `ADR-026:50-52`) set the `AnimationPlayer` to
  manual advance at ~10 Hz; beyond 140m (past `SIGHT_CAP_OPEN`, `enemy_base.gd:80`) ~5 Hz.
  Mirror the existing think-LOD ladder (`enemy_base.gd:37-52`) so there is one distance grammar.
- **Expected:** UNKNOWN — skeletal anim cost has never been measured (that is the point). At the
  siege most attackers close to <80m, so the win is mid-fight and pre-materialize; could be
  2–8 ms, could be noise. **Measure before building** (§4 counter list makes it visible as
  "frame CPU minus every ai_usec bucket").
- **Fairness guard:** display-only. Perception, witness and the fire telegraph never key on
  animation rate. Hard snaps are on-aesthetic (PS2 had no smooth LOD, `ADR-026:50`).
- **Validates by:** A/B/A with the tier forced on/off; whole-frame CPU ms; eyes (no 1.6fps
  moonwalkers inside 70m — the `_update_sprite` comment at `enemy_base.gd:386-388` names the
  failure mode).

### #4 — Fix the canteen duplicate-mesh regex (free draw calls, 5 minutes)
- **What:** `model_actor.gd:405` compiles `^(.+)\.(\d+)$` (dot-suffix) but the six shipping grunts
  export `canteen_l_002…_006` (underscores) — **every US grunt renders 5 stacked canteens**,
  ~4 calls/body × every garrison/ally body (`PERF_LEDGER.md:1017-1021`, verified still unfixed at
  `model_actor.gd:401-421`). Extend the pattern to `^(.+)[._](\d+)$` (keep lowest, hide rest).
- **Expected:** ~40–100 draw calls at the siege pose. Likely near the FPS floor on its own —
  ship it anyway: it is a bug, the `[MODEL] hid N duplicate gear meshes` print (`model_actor.gd:424`)
  proves it fired, and calls are the ratified chase (not tris).
- **Validates by:** draw-call delta in the overlay + the boot print; look-check one grunt's hip.

### #5 — Spawn-burst amortization: warm the caches at demo boot
- **What:** first cell to materialize pays, in one frame: `EnemyData`/`WeaponData` `.tres` loads,
  the model GLB instantiation, and the per-unit-type hitzone **hull harvest**
  (`hitzone_builder.gd:233-237` — cached per unit type after first build). Pre-spawn one
  `vc_sapper` + one `nva_regular` (`siege_director.gd:24-25`) during phase 0 (the explore window,
  `demo_game.gd:62-64`), sync once, free them — the caches stay warm.
- **Expected:** kills the **hitch** at first contact, not steady-state FPS. Cells already stagger
  arrival (3–6 men per materialize, `marching_cell.gd:113-126`; different ring radii), so per-wave
  burst is naturally amortized — no further spawn-queue machinery is warranted.
- **Validates by:** worst-frame-ms (not avg) around the first `materialize()` print, before/after.

### #6 — Blood FX: pool the materials, keep CPUParticles
- **What:** `GunFX.blood` builds **2 new `CPUParticles3D` + 2 new `StandardMaterial3D` + 2 new
  `QuadMesh` per hit** (`gun_fx.gd:548-607`) — material construction forces shader/pipeline setup
  churn under massed fire. Cache the two materials/meshes as statics (the `_btex` cache at
  `gun_fx.gd:542-545` is the precedent). Concurrency is already capped at 12
  (`gun_fx.gd:67,549`), so a full GPUParticles rewrite is **REJECTED** — bounded cost, and
  per-emitter GPUParticles carry their own per-node overhead; the win is the allocation churn,
  not the simulation.
- **Expected:** small, hitch-shaped (sub-ms steady-state). Do it as hygiene alongside #4.

### REJECTED — with the measurement that rejects them
- **Hot-set size tuning for the siege (shrink HOT_CAP):** think is **1.2 ms of a 37.5 ms wall at
  65+ live** (`PERF_LEDGER.md:295-304` — "the throttle was on the cheapest term in the loop",
  `enemy_squad.gd:37-41`). Re-capping saves <1 ms and un-does a 2026-07-28 Summoner ruling. Dead.
- **Perception heartbeat batching:** measured **~2.6 rays/physics-frame level-wide —
  microseconds** (`PERF_LEDGER.md:290-295`). The COMBAT-tier ally scan (`enemy_base.gd:842-850`)
  is ~50×8 distance checks per think — trivial. No milliseconds live here, and the witness law
  bars shedding it anyway (§3).
- **Cold-body physics/anim rate halving:** already built — the WA-A2 body gate
  (`enemy_base.gd:538-553`) — and **correctly open for everyone during a siege** (COMBAT pins it;
  measured 0% gated in a firefight is the right census, `PERF_LEDGER.md:341-349`). Nothing to
  tune at the climax; #1 is the version of this idea that works when everyone is legitimately hot.
- **NavBaker/pathfinding spikes at wave spawn:** no bake happens at spawn — NavBaker bakes at
  world build (`mission_generator.gd:809`); attackers steer via `nav_router.gd:33-44` box lookups
  and fall back to direct steer off-mesh, and `assault_objective` men run `_move_toward` straight
  lines (`enemy_base.gd:1274-1276,1334-1335`). No spike mechanism exists to fix. (Re-check only if
  the §4 bench shows physics spikes correlated with `materialize()` prints.)
- **`world_config` ladder wiring:** already wired (§0.2). Its rungs are geometry/nav dials, and
  geometry is measured not-the-limiter (`PERF_LEDGER.md:95-104`). `NAV_ENABLED=false` stays what
  it is: a documented escape hatch, not a plan item.

---

## 3. MUST NOT TOUCH

- **The witness/perception heartbeat runs on EVERY unit at EVERY tier.** `enemy_base.gd:591-593`
  ("This is the guard-rail — tiering never sheds the witness check") and the binding cold-tier
  guard-rail at `ADR-026:93-98`: `set_physics_process(false)` is never used to shed AI cost.
  #1 slows the metronome for everyone equally — it never silences it for a tier. No lever in
  this plan may make a cold or distant man blind or deaf.
- **Never cap bodies.** Firefight scale is a pillar (`ADR-026:74-79`, "There is NO headcount
  cap"; the cap-the-fighters alternative was REJECTED by decree, `ADR-026:138-139`). The d50 and
  `LIVE_CAP = 50` (`siege_director.gd:32-36`, Summoner ruling 2026-07-28) are canon numbers, not
  tuning knobs.
- **Renderer stays Forward+.** `ADR-026:144-147`. Not evaluated, not mentioned again.
- **Any tier that fires emits the full telegraph** (`ADR-026:99-100`); the flash sprite/tracer/
  report are exempt from every cap (`ADR-026:42-47`). No FX lever in §2.6 may touch them.
- **The break math and the siege ledger** (`siege_director.gd:78-92`, paper-strength counting at
  `marching_cell.gd:52-62`) — ADR-037 contracts, not perf surface.

---

## 4. THE BENCH PROTOCOL (Caleb, windowed, at the siege)

**Setup (once):** Blender CLOSED (`PERF_LEDGER.md:195-199`). Single Godot instance (`ps` check).
Restore `renderer/rendering_method="forward_plus"` to `project.godot` and verify the runtime
print — the key strips on editor save (`PERF_LEDGER.md:24-27,1108-1110`). Record scale
(0.75/mode5), renderer, and seed 29072026 on every row (measurement contract,
`PERF_LEDGER.md:18-29`). Fix §0.4 (ring override) FIRST so the bench measures the real assault.

**Prerequisite patch (~20 lines):** 1 Hz counter print in `demo_game.gd` — deltas of
`CombatManager.ai_usec_think/move/hitzone/anim`, `bodies_run/gated`, `rays_*`
(`combat_manager.gd:16-32`), plus `Engine.get_frames_per_second()`,
`Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)`, draw calls + primitives
(`RenderingServer.get_rendering_info`), and GPU/CPU ms
(`viewport_get_measured_render_time_gpu/cpu` — enable the flag; it has never been on outside the
arena, `PERF_LEDGER.md:966-971`). For bench boots only, drop `SIEGE_AT_S` to ~60s
(`demo_game.gd:27`) so a run costs 5 minutes, not 12 — restore before commit.

**Run 0 — THE ATTRIBUTION (do this before pulling ANY lever):** boot `demo_game.tscn`, stand on
the wire facing the attack sector, let the 40-strength siege land, capture 3+ minutes of 1 Hz rows
through the peak. This yields the demo's first-ever numbers: FPS, CPU-vs-GPU split, and the
per-bucket AI wall at the real body count. **If GPU ms > CPU ms at the siege, the ranking above
re-orders and draw-call work (canopy atlas file, `PERF_LEDGER.md:1003-1015`) re-enters.**

**Per lever — A/B/A, same protocol that caught the shadow artifact:**
1. Baseline run → lever run → baseline run, identical timeline (fixed `SIEGE_AT_S`, same seed;
   the arc clock makes runs comparable at the same t — the escalation-conflation trap of
   `PERF_LEDGER.md:226-231` is controlled by comparing identical clock windows).
2. Noise floor = widest gap between the two baselines; any delta inside it is INSIDE NOISE
   (`PERF_LEDGER.md:519-521`).
3. **No FPS delta is accepted unless the counter delta has the right SIGN and a plausible
   MAGNITUDE** (binding rule, `PERF_LEDGER.md:1066-1069`): #1 must halve `ai_usec_*` per second;
   #2 must drop `ai_usec_hitzone` AND whole-frame CPU; #4 must drop draw calls; #3/#5 show in
   frame-CPU-minus-buckets and worst-frame ms respectively.
4. Look-check every lever against Pillar 2 and RULE #1 (walk it, don't just stand: no jungle
   sightline has ever been measured, `PERF_LEDGER.md:972-975`).

**Which counters to read per lever:** the table in §1 — each lever names its bucket; the two
uncounted paths (skeletal anim, render-frame sync) read as `frame CPU ms − (think+move+hitzone+anim)`.

---

*Recorded per the session-completion law: the §0 corrections (MAX_THINK_TIME gone, ladder wired,
ring override missing) are NO-DRIFT findings and should be folded into GAME_GUIDE/tracking on the
next doc pass.*
