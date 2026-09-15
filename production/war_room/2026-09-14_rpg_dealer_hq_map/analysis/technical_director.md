# TECHNICAL DIRECTOR — Individual Sight, 2026-09-14 (the 3x map, the technique, audibility, the observatory)

Read against code at HEAD this evening. Every claim carries a `file:line` or is dated. No game file edited.

---

## 0 · The one finding that reorders the rest

**The map is already three tiers deep and nobody wrote it down.** Beyond the 80/105 m behavioural LOD
(`scripts/ai/ai_lod.gd:44-49`) there is a SLEEP tier at 240 m that already ships in the demo:
`scripts/missions/terrain_watchdog.gd:8-9` — `SUSPEND_DIST 240 / RESUME_DIST 210` — sets
`set_physics_process(false)` + `visible = false` on every enemy, ambient ally and civilian past 240 m
(`:45-59`), every 2 s, and re-seats him on resume (`:61-73`). It is added by
`mission_generator.gd:1024` on every world. On the 512 m slice the firebase sits at (256,256), the
authored sites at 165–210 m (`mission_generator.gd:770-781, 807-808`), so a man 240 m from the
player was rare and the tier almost never engaged. **On an 890 m map it engages over most of the AO
every time he walks out the wire.** So the third tier the brief asks me to name is not a proposal —
it is a fossil-in-waiting that becomes load-bearing the moment the map grows, and it has two defects
the bigger map will expose (§2.3).

ADR-026 Part B's guard-rail says `set_physics_process(false)` is never used to shed AI cost
(`ADR-026:129-132`). The watchdog does exactly that. The guard-rail's *reason* (a blind cold unit voids
the 150 m loud-kill beacon) is not violated only because `SUSPEND_DIST 240 > GUNSHOT 150`
(`noise_bus.gd:23`) — a suspended man is outside every NoiseBus radius by construction, and his
`_on_noise_heard` handler stays connected (`enemy_base.gd:594`) and still writes `last_known_target_pos`
(`:1694`) for when he resumes. **That invariant — sleep radius > every noise radius — is the law that
makes the tier legal, and it is nowhere written.** It must be.

---

## 1 · THE 512 → 890 m AUDIT

### 1.1 The size itself: 890 is not a number the engine can build

`HeightmapStorage._init` rounds the sample grid up to a multiple of 64 cells = 256 m
(`terrain/core/heightmap_storage.gd:22-31`), and `TerrainManager._ready` builds
`ceil(map_size / chunk_size)` chunks per side (`terrain_manager.gd:60`). **Any map_size in (768, 1024]
costs exactly what 1024 costs**: 16 chunks built, scattered, collided and drawn; the fence and the
planner use 890, and 134 m of live jungle sits outside the fence on two sides (visible over it: the
fence is invisible, `game_world.gd:437-460`). Three honest choices:

| map_size | chunks | area vs 512 | note |
|---|---|---|---|
| 768 | 3×3 = 9 | 2.25× | "3x area" missed; firebase dead-centre lands ON a chunk seam (384) — fine, seams are invisible |
| **896** (3.5 chunks) | 4×4 = 16 built, 12.25 playable | 3.06× | what he asked for; pays for 16, plays 12 |
| **1024** | 4×4 = 16 | 4× | same build cost as 896, nothing wasted; 512 m from centre to edge |

**Recommendation: 1024, not 890.** Same cost, no dead terrain past the fence, no `map_size / chunk_size`
fraction anywhere. If the council wants "smaller than 4×", 768 is the only other honest number. The
`DEMO_MAP_SIZE` const (`game_flow.gd:586`) is the one line; `tests/test_demo_planner.gd:12` mirrors it
and must change in the same commit (it asserts 512).

### 1.2 The audit table

Legend — **S** scales from `map_size` automatically · **H** hard number that must move · **A** authored
relative to `fsb_center`, does not need to move but leaves the new ground empty unless the plan grows.

| # | Where | What | S/H/A | At 1024 m | Cost at 1024 |
|---|---|---|---|---|---|
| 1 | `scripts/main/game_flow.gd:586` `DEMO_MAP_SIZE = 512.0` → `:624 world.map_size` | THE constant | **H** | change once | — |
| 2 | `scripts/levels/world_config.gd:9` `MAP_SIZE = 1280` | patrol-world default; demo overrides it. ADR-013 cites it as "the AO of record" — stale, demo ships 512 | S (unused by demo) | untouched; correct ADR-013 pointer | — |
| 3 | `tests/test_demo_planner.gd:12` `MAP_SIZE 512` | test mirror | **H** | move with #1 | — |
| 4 | `terrain/core/terrain_manager.gd:60` chunks_per_side; `heightmap_storage.gd:22-31` 64-cell rounding | 2×2 → 4×4 | S | 16 chunks | build ≈ 50 ms/chunk (`PERF_LEDGER.md:1589-1591`: veg_generate 42.5 + build_mesh ~6 + heightfield ~0.1) → **+0.6 s load**, once |
| 5 | `terrain_manager.gd:238-240` `arm_patch_cache()` ~1 MB/chunk | RAM | S | 16 MB (was 4) | trivial on 15.6 GB |
| 6 | Terrain tris 8,192/chunk (`recon-crater-stall-wave` correction) | GPU | S | 131k tris resident (1280 map held 200k "flat", ADR-013) | draw is range-culled anyway (#12) |
| 7 | `terrain/systems/clearing_system.gd:57` `vegetation_size 512` px; `game_world.gd:573-577` `* map_size / 512.0` | clearing MASK resolution, 1 px = map/512 m | S (resolution halves: 2 m/px) | acceptable; FSB clear discs are 26 m feathered | 0 |
| 8 | `terrain/vegetation/vegetation_manager.gd` scatter per chunk (~9,700 plants/chunk cache) | veg cache | S | ×4 memory, ×4 build (inside #4) | draw is ring-gated: `tree_cover_layer.gd:87 SMALL_RING 150`, `:252 RING_STEPS 150/100/250`, `:62 RING_RADIUS 70` trunks, `:118 CANOPY_BUCKET 128` — **in-range node count does not change with map size** |
| 9 | `scripts/world/ground_clutter.gd:22,152,225` `SUBCELL 32`, `ceil(map_size/32)` | clutter cells | S | 32×32 = 1,024 cells (was 256) | build only; draws to `NEAR_END` (`:258`) |
| 10 | `scripts/world/nav_baker.gd:26-28, 43` per-SITE boxes (HALF 35–70 m, FSB 185) | nav bake | **scales with SITE COUNT, not area** | +1 region per new authored place; jungle between sites is direct-steer (`NavRouter`) | ~0.3 s per village bake, at load (breach rebake ~110 ms, `recon-fps-audit-2026-09-11`) |
| 11 | `scripts/missions/terrain_watchdog.gd:6` `POLL_SECONDS 2`, `:44` walks ALL bodies, `:79 floor_y` raycast each | watchdog scan | S with body count (O(N) rays / 2 s) | his 9/14 log: worst `phys.terrain_watchdog` **58.1 ms** with ~50 bodies — that step is already the worst physics step in a quiet walk | **must be time-sliced** (§2.3) |
| 12 | `site_planner.gd:366` `STRUCTURE_VISIBILITY_END 230`; `helicopter.gd:47` 1200; `spectre_gunship.gd:16` 1200; `interior_prop_fold.gd:102,164` | cull distances | S | unchanged | see §2.4 table |
| 13 | `game_world.gd:437-460` EdgeFence, `:635-637` re-seat clamp | uses `map_size` | S | fence at 1024 | 0 |
| 14 | `field_director.gd:130` prewarm parks at `(0, -500, 0)` | reserve parking | S (off-map on purpose, dormant = `PROCESS_MODE_DISABLED`) | — | the memory's "z≈865 pre-warm" is not in this code path; the 58 ms was the scan (#11) |
| 15 | `siege_director.gd:19-20` `RING_MIN 300 / RING_MAX 500` from `fsb_center` | siege forms up | **H** (today it forms up OFF the 512 slice: centre 256 ± 300–500 is outside on every bearing — memory `recon-demo-audit-2026-09-07`) | at 1024 the ring lands 12–212 m INSIDE the fence — **the form-up becomes visible and audible ground for the first time**; cells materialize at `MATERIALIZE_M 80` from fsb_center (`marching_cell.gd:15`) | 0 perf; a design gift |
| 16 | `siege_director.gd:80` `REAP_RADIUS_M 600`, `:87 MORTAR_TUBE_STANDOFF 700`, `:79 RALLY_M 350` | siege reach | **H** — 700 m tube is off a 512 map and ON a 1024 map | keep; now real ground | 0 |
| 17 | `mission_generator.gd:748-781` demo sites at 165–210 m from `fsb_center`; ruins 140–175 (`:804`); AA 195–210 (`:886`); camp 265–300 (`:856-860`); spawn cells 150–300 from gate (`:833`) | authored plan | **A** | everything stays inside a 300 m disc of a 1024 map → **a 200 m ring of empty jungle to the fence**. The 3x map is only worth building if the PLAN grows: new places at 350–450 m | +1 site ≈ its nav bake + its population |
| 18 | `mission_generator.gd:548, 595, 618` patrol-world bands 240–470 / 320–560 / 420–600 (`game_flow.gd:635-636` says they "collapse under ~900 m") | patrol planner | S-ish | at 1024 these bands FIT again — the open-patrol planner becomes usable on the demo map | — |
| 19 | `site_planner.gd:10` `MARGIN 100`, `:1050 FSB_EDGE_MARGIN 60`, `:1900 FSB_AO_ROOM_M 470` | edge keep-outs | S (subtract from map_size) | AO_ROOM 470 finally satisfiable (it never was on 512: 256 < 470) | 0 |
| 20 | `field_director.gd:278-279, 1496` clamp 60 m; `mission_generator.gd:144-171` clamp 80 m | spawn clamps | S | — | 0 |
| 21 | `scripts/ai/air_traffic.gd:341, 491-497, 689-690, 824` `_map_size()`; `:272 ORBIT 130`, `:280 INBOUND 330`, `:451 SPECTRE_KEEP_OUT 420` | air | S (exits at `0.55 × map`) | orbits now inside the fence; the 1200 m airframe range (#12) still covers corner-to-corner (1,448 m diag → **corner Huey clips at 1200**; raise to 1500 or accept) | 0 |
| 22 | `scripts/ui/journal.gd:473-476, 551-552` grid = pos/map_size × 1000 | map/journal | S | grid squares become 102 m | 0 |
| 23 | `scripts/world/ambient_encounters.gd:18-47` ROLL 65 / CONTACT 110–200 / DESPAWN 220 | ambient rolls | S (player-relative) | more ground to roll on = more encounters per walk; H&M density knob | per-encounter spawn cost only |
| 24 | `enemy_base.gd:41-56` think LOD 80/150 m; `ai_lod.gd:44-49` 80/105/160; `terrain_watchdog.gd:8-9` 240/210; `model_actor` anim throttle 80 m (`recon-perf-fix-wave-2026-09-10`) | the tiers | S (player-relative) | unchanged | 0 |

**Grep of bare `512` / `256` / `1024` in `scripts/` + `terrain/`** (excluding colours/hex): every `256` is
`CHUNK_SIZE` or the gameplay-grid cell count (`gameplay_grid.gd:10,61` — 256 cells over `map_size`, so a
cell grows 2 → 4 m; `terrain_chunk.gd:6,50`; `heightmap_storage.gd:30`); the only `512` is the clearing
texture (#7) and `terrain_manager.gd:261`'s comment; the only `1024` is that same comment's Recast
heightfield figure. **No hidden 512 m literal exists in the world build.** The hard numbers are #1, #3,
#15/#16 (which become correct by accident), and the authored plan (#17).

### 1.3 Perf at 1024, honestly

- **Load**: +0.6–0.9 s once (16 chunk builds + veg scatter). Nobody will feel it.
- **GPU**: unchanged in steady state — every jungle layer, structure and clutter draws inside a
  player-centred ring (#8, #9, #12). The 9/11 finding "CPU is no longer the wall; the GPU is" stands and
  the map size does not move the GPU because the rings do not move.
- **CPU**: scales with **bodies**, not metres. The demo fields 36 garrison (his log `:278`), 8 live
  enemies, a village, patrols → ~50–60 bodies. A 3x plan with a second village, the dealer's corner, a
  crash site and a camp is ~90–110 bodies. Past 240 m they are suspended (free) — **but the watchdog
  scan itself is O(N) raycasts every 2 s and already spikes 58 ms** (#11). That is the one term that
  gets worse with the map and it is a 30-line fix (§2.3).
- **The 9/14 numbers** (mean 37.5 / median 34 / p95 68) were taken with the third tier barely
  engaged. With it engaged over most of the AO, a walk-out should measure *equal or better* per body
  — the paired A/B is `perf_walk.bat` at 512 vs 1024 on the same seed, same evening, `tasklist | grep
  Godot` = 1 (the measurement law, `recon-perf-fix-wave-2026-09-10`).

---

## 2 · THE TECHNIQUE

### 2.1 What the studied games actually did (full study in `../study_large_maps.md`)

Ghost Recon (2001) shipped **400 × 400 m** maps with everything resident and enemies placed by
plan/trigger zones; Far Cry (2004) shipped island-sized levels with **no loading inside a level**, all
AI resident, activated by area triggers and kept cheap by sensor cones; Far Cry 2/3/4 went 50 km² and
paid with streaming plus a **~500 m active-NPC bubble with ~12 NPCs max** and a director that spawns
ahead of the player. MoH:AA/PA is trigger-spawned scripted actors on Quake 3 hub levels. The dividing
line is exactly ADR-013's: under ~1–2 km the winners kept the world resident and **spent their budget on
who thinks, not on what exists**. Above that they streamed and faked the far world. We are under.

### 2.2 The ONE approach for RECON: **RESIDENT WORLD, THREE RINGS, ONE CLOCK**

Nothing streams (ADR-013). Every man exists from world build to teardown. Cost is governed by three
player-centred rings, all of which already exist in code — the work is to make the outer one correct,
write the invariant that binds them, and give the sleeping ring a schedule.

| Ring | Radius | Who ticks what | Exists at |
|---|---|---|---|
| **NEAR** (full brain) | ≤ 80 m promote / 105 m + 3 s demote / sticky ≤ 160 m | everything | `ai_lod.gd:44-56` |
| **FAR** (cheap brain) | 105–240 m | lane walk, suppression, fear, bursts, hearing, witness, 0.3–0.6 s think, 10 Hz anim | `enemy_base.gd:41-56, 2208`; `model_actor` throttle |
| **ASLEEP** (no body) | > 240 m (resume 210) | **nothing per frame**; `_on_noise_heard` still records; schedule advances by clock on wake | `terrain_watchdog.gd:8-9, 45-73` |

**The binding invariant (new, one line in `noise_bus.gd` + one test):**
`TerrainWatchdog.SUSPEND_DIST` **>** `max(NoiseBus.RADII) × radius_multiplier` **>** `AILod.STICKY_MAX_M`.
Today 240 > 150 > 160 — *the middle inequality already fails*: a man at 155 m can be sticky-promoted
(shooting at the player) while outside GUNSHOT radius, which is harmless, but a monsoon
`radius_multiplier` > 1.6 would let a shot reach a sleeping man. Assert it in `tests/`, and the guard-
rail in ADR-026 gets amended from "never `set_physics_process(false)`" to "never inside a noise radius".

**Why not a fourth tier / a schedule-driven "off-screen sim"?** Because the sleeping men are not on a
journey. The garrison stands at posts; villagers walk a schedule of a few hundred metres; VC squads sit
in camps or hunt the evidence ledger (`evidence_ledger.gd`). The only things that MOVE at range are
siege cells (already bodiless: `marching_cell.gd:1-19`, position advanced at `STEP_INTERVAL 0.25` with
no body), convoys and aircraft (Node3D, exempt). So "position advanced by schedule" is needed for
exactly one class — **civilians** — and only as a *wake-time snap*, not a per-frame far sim (§2.3 c).

### 2.3 The build list for the technique (BaseGame-V1 first, merge forward)

| # | File | Change | Lines | Perf risk |
|---|---|---|---|---|
| a | `scripts/missions/terrain_watchdog.gd:44-79` | **Time-slice the scan**: keep a cursor into the three groups, visit ≤ 12 bodies per physics tick (all ~100 in ~0.3 s, still < `POLL_SECONDS`); skip the `floor_y` raycast for suspended men (they are not falling — their physics is off) | ~30 | removes the 58 ms step; **the** map-size perf item |
| b | `terrain_watchdog.gd:45-59` | Never suspend: `squad_member` allies (already), `silent_infiltrator` sappers (they are the siege), a man with `alert_tier == COMBAT` within `STICKY_MAX_M` of *any* friendly (ADR-005 witness chain must finish) | ~8 | 0 |
| c | `scripts/world/civilian.gd:510` (`_physics_process`) + `terrain_watchdog.gd:61-73` resume branch | **Wake-time snap**: on resume, if `SimClock.sim_hour` moved past the man's next scheduled action while asleep, set his BT blackboard `scheduled_action` / `resolved_home` (`civilian.gd:1294-1295`) and teleport him to that post's marker if it is > 30 m away and the player cannot see it (`CombatManager.perceivable`). The village is at the right hour when he walks back in. | ~40 | one nav query per woken civilian, spread by the slice in (a) |
| d | `scripts/autoload/noise_bus.gd` + new `tests/test_sleep_radius.gd` | The invariant in §2.2 as a const assertion + test | ~25 | 0 |
| e | `scripts/main/game_flow.gd:586`, `tests/test_demo_planner.gd:12` | `DEMO_MAP_SIZE 1024` | 2 | measured, §1.3 |
| f | `scripts/vehicles/helicopter.gd:47`, `spectre_gunship.gd:16` | airframe range 1200 → 1500 (corner-to-corner 1,448 m) | 2 | negligible (one airframe) |
| g | `production/adr/ADR-013` | correct the "1280 AO of record" pointer; add "demo 1024" | doc | — |
| h | `ai_lod.gd` census line | add `asleep N` beside `near N` so the `[AILOD]` row shows all three rings | ~6 | 0 |

**Estimate: one evening, ~110 lines, one paired A/B.** Not in the list, on purpose: threading the
chunk build (ADR-013 asks for it before any streaming; we are not streaming), terrain LOD (draw is
ring-gated; the 131k resident tris were "flat" at 200k), impostors for men (the FAR tier already
throttles anim to 10 Hz and the PS1 models are ≤ 3k tris — an impostor card would cost more in
sorting than it saves).

### 2.4 Cull distances per asset class (values of record, all already shipped — no change proposed)

| Class | `visibility_range_end` | Pointer |
|---|---|---|
| Trunk real meshes (ring) | 70 m | `tree_cover_layer.gd:62` |
| Small plants / grass | 150 m | `:87` |
| Canopy species (near mesh → card) | 150 / 100 / 250 steps | `:252` |
| Structures (village, camp, temple) | 230 m (+25 margin) | `site_planner.gd:366-367` |
| Interior props | folded by dial | `interior_prop_fold.gd:102,164` |
| Ground clutter | `NEAR_END` | `ground_clutter.gd:258` |
| Men (anim) | throttle past 80 m / off-screen > 30 m | `model_actor.gd` (9/10 wave) |
| Men (body) | suspended + invisible past 240 m | `terrain_watchdog.gd:8` |
| Airframes | 1200 m (→ 1500) | `helicopter.gd:47` |

On the bigger map the horizon past 250 m is bare terrain + cards, which is what PSX Vietnam looks like
anyway (fog is the period's LOD). If he wants a further treeline, the lever is a **third card ring at
400 m for the tallest species only**, ~20 lines in `tree_cover_layer._ring_for`, measured.

### 2.5 What is sacrificed (no free lunches)

1. **A man asleep at 300 m does not react to a distant firefight.** GUNSHOT reaches 150 m; he is deaf
   by design past that. HLL-style "the whole valley wakes" cannot happen — the witness rule already
   says only a man who SEES goes COMBAT (`noise_bus.gd:15-19`), so this is consistent, but it caps how
   far an alarm propagates without a runner/radio mechanic (a design item, not tech).
2. **Civilians snap on wake (c).** A player with binoculars at 250 m watching a village will, on
   walking in, see a man who was "there" now "here". Mitigated by the `perceivable` check; not zero.
3. **The siege form-up becomes visible ground (#15).** Cells still materialize at 80 m from the
   *centre*, so a player standing 300 m out at night could watch a fireteam appear. `materialize_center`
   is passed by the director; the fix is materializing on distance to the PLAYER or the centre,
   whichever is nearer — ~6 lines in `marching_cell.gd`, and it changes nothing about who wins.
4. **The empty ring (#17).** Technically free; designerly expensive. The 3x map is jungle unless the
   plan grows, and every authored place is a nav bake, a population and an art list.
5. **1024 is 4×, not 3×.** More ground than he asked for at the same cost as 890; the alternative is
   768 at 2.25×. There is no 3×.

---

## 3 · JUNGLE AUDIBILITY

### 3.1 What exists

| Piece | Pointer | State |
|---|---|---|
| `NoiseBus` autoload, 7 types, radii FOOTSTEP 8 / SPRINT 16 / GUNSHOT 150 / VOICE 20 / EXPLOSION 110 | `scripts/autoload/noise_bus.gd:9-30` | one signal to ~N listeners, sphere test, **no occlusion** |
| Player noise emitter | `player.gd:1572-1594` — 0.35 s sprint / 0.55 s walk cadence, crouch = 3 m × `quiet_mult` | **the player IS a stimulus already** |
| Enemy ears | `enemy_base.gd:594` subscribe; `:1679-1701` `_on_noise_heard`: own-team gunfire/steps ignored, radius check, `awareness += 0.35`, RELAXED→SUSPICIOUS→ALERT never COMBAT | correct per ADR-005 |
| Enemy → NoiseBus | only VOICE (shouts, pain, orders) and GUNSHOT; **enemy footsteps never reach the bus** (grep: `FOOTSTEP` emitters are player + `marching_cell.gd:113`) | fine for enemy-vs-enemy; means **allies cannot hear enemies** |
| NPC step audio | `audio_manager.gd:91-134`: 6-voice `AudioStreamPlayer3D` pool, `STEP_AUDIBLE_M 28`, surface-matched dirt/grass/water, called from `enemy_base.gd:1211` and `ally_base.gd:976` every 0.85 m of travel | **exists, capped, headless-safe** |
| 3D voice bank | `audio_manager.gd:24` 24 gunshot voices, distant band 85 m, `attenuation_filter_cutoff_hz 5000` (`:84`) | air absorption only |
| Total `AudioStreamPlayer3D.new` sites | 16 across 12 scripts (gun_fx, vo_manager, ambient_war, vehicles, radio, siren, doors) | no scene-instanced 3D players |
| Occlusion anywhere | `sight_cap.gd:43` has a seeded per-cell canopy occlusion model for SIGHT; audio has **none** | — |

So the brief's "pool it like the muzzle-flash pool" is done: the step pool predates the request. What
is missing is (1) **range** — 28 m is a man's own footfall, HLL's "hear them in the jungle" is 40–60 m
of brush, kit rattle and voice; (2) **the second layer** — brush rustle when a man crosses vegetation,
equipment clank on a sprint, a canteen on a crouch-walk; (3) **occlusion** — a hill or a hut between
you and the walker should low-pass and drop him, or the audio lies about geometry; (4) **symmetry for the
AI** — enemy movement noise as a NoiseBus stimulus so the player's squad AI (and the observatory) can
"hear" what the player hears.

### 3.2 The minimal extension

| # | File | Change | Lines | Perf risk |
|---|---|---|---|---|
| 1 | `scripts/autoload/audio_manager.gd:91-134` | `STEP_AUDIBLE_M 28 → 48` for walking, 64 for sprint (`velocity` passed in), crouch stays ×0.5. `STEP_VOICES 6 → 10`. Add a **BRUSH layer**: when `_step_grid.get_terrain_type(pos)` is jungle/dense (the same enum the step already reads) play `brush_1..3.wav` on a second 6-voice pool with `max_distance 40`; add a **KIT layer** on sprint only (`kit_rattle_1..2.wav`, 30 m). Pools are the cap: 60 men walking can never exceed 22 voices. | ~60 | +16 `AudioStreamPlayer3D`, all pooled; a voice that is not playing costs nothing |
| 2 | `audio_manager.gd` `play_step_3d` | **Occlusion, one ray**: on voice START only (not per frame), `intersect_ray(cam → pos, mask = world layer 1)`; if blocked, `attenuation_filter_cutoff_hz = 900` and `volume_db -= 9`; else 5000. One ray per step that is *inside audible range and got a free voice* — pool-rate, ≤ 10/s | ~15 | ≤ 10 raycasts/s, vs the AI's ~hundreds |
| 3 | `audio_manager.gd` | Canopy density as a second attenuator: reuse `SightCap`'s seeded per-cell occlusion (`sight_cap.gd:43`) — sample once per step, scale volume by `1 − 0.5·density`. Jungle muffles, paddies carry. | ~10 | a dictionary read |
| 4 | `scripts/enemies/enemy_base.gd:1211` and `ally_base.gd:976` | Emit `NoiseBus.FOOTSTEP` (walk) / `FOOTSTEP_SPRINT` alongside `play_step_3d`, **throttled to one emit per 3 s per man** (a signal to 60 listeners every 0.85 m of 60 men is 4k signals/min — the throttle keeps it ~20/s). Enemies already ignore own-team steps (`:1689`), so this is a stimulus for allies + observatory only. | ~12 | see throttle |
| 5 | `scripts/allies/ally_base.gd` | Subscribe to NoiseBus if not already; on enemy FOOTSTEP inside radius, raise the squad's "contact possible" flag → the existing point-man callout (whatever `ally_base` uses for "movement front") | ~25 | 0 per frame |
| 6 | assets | 3 brush, 2 kit, 1 canteen wav, 48 kHz mono per the house contract (`recon-audio-pipeline-map`) | art | — |

**Total ~120 lines + 6 wavs. Perf risk: low and capped by construction** — every new cost is behind a
pool slot or a 3 s throttle. The one thing NOT to do is give each man his own `AudioStreamPlayer3D`
(60 players, each mixed every frame whether audible or not — Godot mixes players that are in range
regardless of whether they are playing silence).

**What is sacrificed:** occlusion is a single ray to the camera — a man behind a *thin* hut wall and a
man behind a *hill* sound the same; a proper obstruction/exclusion model is a GDExtension. Brush
rustle is per-step, not per-plant-touched (no physics contact with vegetation exists).

---

## 4 · THE OBSERVATORY (technical shape)

### 4.1 What exists

| Instrument | Pointer | Gives |
|---|---|---|
| `ObservationTools` (dev node) | `scripts/dev/observation_tools.gd` (229 lines): O = free-fly observer that freezes + hides the player and blinds the AI to the camera; I = per-agent `Label3D` overlay at 10 Hz reading `current_state`, `current_goal`, `order_mode`, `alert_tier`, `suppression_level`, `target` (`:209-226`); `\ [ ] - = 0` time controls. `OS.is_debug_build()` gated (`:27-31`). Used by `anim_review.gd:148`, `observation_room.gd` | **the seed of the observatory — already the right shape** |
| Arena debug vis | `ai_stress_arena.gd:243-281, 445-447` `ImmediateMesh` + `Label3D`, F3 toggle, cost bucketed | arena-only |
| Dev keys in the live game | `game_flow.gd:75-90` F8 force siege, H sapper run, G gun run, O/I skip time | **key collision: O and I are taken by GameFlow in the live world** |
| `--npc-census` probe | `tools/probe_npc_census.gd`, attached by `game_flow.gd:773-776`; reads `civ._bt_bb` (`:255`), `ally.order_mode`, positions vs posts | headless, once per sample hour |
| `StallLedger` / `FrameSentinel` / `FpsPrinter` | `scripts/dev/` | frame cost, not AI state |
| `[AILOD]` census row | `ai_lod.gd:117-137`, printed by the FPS printer | near/peak/hot slots |
| State choke points | **enemy: ONE** — `enemy_base.gd:2686-2689 _change_state` (the only `current_state =` write in 3,786 lines); alert: `:1655-1675 _set_tier`; hearing: `:1679`; **civilian: SEVEN** direct `state =` writes (`civilian.gd:469, 545, 550, 1084, 1091, 1172`) + BT dispatch `:1269-1295` | enemy log hooks in 2 functions; civilian needs a setter first |
| Ledgers | `scripts/enemies/evidence_ledger.gd` (what the player left, dated, decays, `band()` `:45`), `scripts/world/hm_ledger.gd` (H&M deeds) | read-only data sources |

### 4.2 The cheapest zero-cost-when-off shape

1. **The decision log is a ring buffer per man, written only at the choke points.** `enemy_base.gd`:
   a `PackedStringArray` of 10 + a `PackedInt64Array` of stamps; `_change_state` and `_set_tier` append
   `"%s→%s %s" % [old, new, cause]` where `cause` is a `StringName` the caller passes (`&"saw_player"`,
   `&"heard_gunshot"`, `&"corpse"`, `&"suppressed"`, `&"lod_demote"`). **Cost when off: one array write
   per transition — transitions are rare (a man changes state a few times a minute), so it is free
   enough to leave on always, and then the log exists in the census and in save-bug reports too.**
   ~25 lines + adding a `cause` argument at the ~15 call sites of `_change_state`/`_set_tier`.
   Civilians: first collapse the seven `state =` writes into one `_set_civ_state(new, cause)`
   (fossil law, same change), then the same ring. ~40 lines.
2. **The overlay is `ObservationTools`, extended, in the live world.** It already builds one `Label3D`
   per agent and refreshes at 10 Hz; when `_overlay_on` is false it does nothing (`:27-31` +
   the `_overlay_t` gate). Extend the text with: `ai_tier` (NEAR/FAR) + `suspended` meta (ASLEEP),
   `awareness` bar, `last_known_target_pos` distance/age, sight cap in force
   (`SightCap` open/jungle), the last 3 lines of the ring, the civilian `_bt_bb.scheduled_action`,
   the H&M band of the man's village (`HMLedger` lookup). Add an `ImmediateMesh` line layer (one mesh,
   rebuilt at 10 Hz only while on) for: sight cone (facing_dir × sight cap), a line to `target`, a
   dashed line to `last_known_target_pos`, a circle at the last noise heard, witness-chain arrows
   (`_stamp_contact` → who he reported to: `d.report_contact`, `:1650`). ~150 lines in
   `observation_tools.gd`. **Zero cost off**: the node's `_process` returns at the first line when the
   overlay is off; no Label3D exists until toggled; the mesh is cleared on toggle-off.
3. **A side panel (Control) for ONE selected man**: click-select via a ray from the observer camera →
   the full ring buffer, the numbers, the ledger entries touching his place. ~120 lines, a
   `PanelContainer` + `RichTextLabel` re-texted at 5 Hz while open (the 9/11 lesson: re-text, never
   rebuild — `mission_hud._update_squad_strip` was the 50 ms hitch).
4. **The map pane (follow-up)** is the journal's 1000-unit grid (`journal.gd:473-476`) with dots per
   man coloured by tier; ~60 lines, reads the same arrays.
5. **Keys**: F9 observatory (GameFlow already owns F8/H/G/O/I); F10 cycle panes. Do not reuse
   ObservationTools' O/I in the live world — they collide with skip-time.
6. **Gate**: `OS.is_debug_build()` stays; additionally `GameSettings.has_flag("--observatory")` or the
   F9 press instantiates the node at all — in a shipping build the file is not even loaded.

**Total ~400 lines, all in `scripts/dev/` + the two choke-point edits. Perf when on: the arena's
`debug_vis` bucket measured its ImmediateMesh + Label3D at a few ms with 36 men — acceptable for a tool
he uses with the observer camera, and the ring buffer is the only part that runs in a real playtest.**

**What is sacrificed:** the ring buffer's `cause` argument touches ~15 enemy call sites and the seven
civilian writes — a real diff on the AI file the week of a playtest; the collapse of civilian state
writes is a behaviour-preserving refactor that still needs the census gate green (`--npc-census`, 3/7
tests were red at HEAD on 9/13 — memory `recon-npc-first-batch-2026-09-13`).

---

## 5 · Summary verdict for the Arbiter

- **Map**: build **1024**, not 890 — 890 costs 1024 and wastes 134 m. Two constants + one test. Load
  +0.6 s, GPU unchanged (rings), CPU scales with bodies not metres. The one map-driven perf item is
  the watchdog's O(N) scan (58 ms in his 9/14 log) → time-slice it (~30 lines).
- **Technique**: resident world, three rings, one clock. The third ring **already ships** at 240 m in
  `terrain_watchdog.gd` and is legal only because 240 > every noise radius — write that invariant down
  and test it, amend ADR-026's guard-rail wording, give civilians a wake-time schedule snap, exempt
  sappers and COMBAT men. ~110 lines. Siege form-up lands on the map for the first time.
- **Audibility**: the pool exists (6 voices, 28 m). Extend range to 48/64 m, add brush + kit pools, one
  occlusion ray at voice start, canopy attenuation from `SightCap`, throttled enemy-step NoiseBus emits
  for allies. ~120 lines + 6 wavs; every cost capped by a pool or a throttle.
- **Observatory**: `ObservationTools` is the seed; the enemy has exactly one state setter and one tier
  setter to hook a 10-deep cause ring; civilians need their seven `state =` writes collapsed first.
  ~400 lines in `scripts/dev/`, zero when off.
- **Sacrificed**: no 3× exists (4× or 2.25×); a sleeping man is deaf past 150 m by design; civilians
  snap on wake; single-ray occlusion; the cause-argument diff lands on `enemy_base.gd` during playtest
  week.
