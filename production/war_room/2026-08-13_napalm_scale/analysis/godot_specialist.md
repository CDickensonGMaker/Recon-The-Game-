# GODOT SPECIALIST / TECHNICAL DIRECTOR — napalm scale pipeline, verified against code

**Session:** 2026-08-13_napalm_scale · Written independently; no other architect's analysis read.
**Method:** every number below recomputed from source, file:line cited. Knowledge loaded:
`~/.claude/architect_knowledge/godot_standards.md`, `godot_4.7_features.md`.
**NOTE (pointer law):** `~/.claude/architect_knowledge/GodotPrompter/` does not exist on disk —
no skills folder, no README (globbed 2026-08-13). CLAUDE.md's standing instruction to load
`GodotPrompter/skills/<topic>/` points at nothing. That is itself drift worth logging.

---

## 1. The rendered-width formula — CONFIRMED, and the briefing UNDERSTATES it

The chain: `play_explosion_3d` (`scripts/combat/gun_fx.gd:158-162`) computes
`scale_mult = _KIND_SCALE[kind] × visual_mult`; `_KIND_SCALE.explosion_napalm = 111.0`
(`gun_fx.gd:132`), default `visual_mult = ORDNANCE_VISUAL_MULT = 2.0` (`gun_fx.gd:138,159`)
→ `_spawn_explosion_visual` sets `root.scale = Vector3.ONE * 222` (`gun_fx.gd:321`).
`billboard_keep_scale = true` (`gun_fx.gd:191,213,332`) makes that scale real for billboards.

**Fireball width:** quad 2.2 m (`gun_fx.gd:370-371`, square by construction —
`_fx_quad` sets `Vector2(size, size)`, `gun_fx.gd:240-241`) × particle scale 0.8–1.3
(`gun_fx.gd:356-357`) × 222 = **391–635 m per sprite, mean ~513 m — and ~513 m tall,
quads are square.** Briefing #1 CONFIRMED. Six desynced sprites spawn in an emission
sphere of 0.35 local = **78 m radius** (`gun_fx.gd:361-362`), widening the dome further.

**What the briefing missed — the two most nuclear elements are not the fireball:**
- **Flash core:** 1.2 m quad (`gun_fx.gd:327`) at local y=0.6 → **133 m altitude**
  (`gun_fx.gd:341`), tweened to scale 3.0 (`gun_fx.gd:494`) → 1.2 × 3.0 × 222 =
  **~799 m additive flash pop**, fading over 0.91 s (`gun_fx.gd:495`, 0.35 × 2.6).
- **Shock ring:** 1.0 m ground-flat quad (`gun_fx.gd:409-425`) tweened to 4.5
  (`gun_fx.gd:496`) → **~999 m expanding ground ring**. A kilometre-wide expanding
  ring + white flash + rising column is the textbook nuclear schema. Real napalm has
  NO shock ring at all.
- **Airburst geometry:** the fireball emitter itself sits at local y=0.7
  (`gun_fx.gd:372`) → **155 m in the air**; linger smoke at 0.8 → 178 m
  (`gun_fx.gd:485`). Napalm is a ground-hugging sheet; this one detonates at
  15 storeys altitude because a grenade's 0.7 m offset was multiplied by 222.

## 2. Velocity scaling and the plume — CONFIRMED, worse than stated

`_burst` sets `local_coords = true` (`gun_fx.gd:279`), so node scale multiplies particle
motion. All lifetimes below include `_KIND_LIFE.explosion_napalm = 2.6` (`gun_fx.gd:153`)
and `EXPLOSION_HOLD_S = 3.0` (`gun_fx.gd:146`).

| layer | local v, g (file:line) | ×222 world | lifetime | top of travel (world) |
|---|---|---|---|---|
| fireball | 0.6–1.6 up, g **+1.2 up** (`:353-355`) | 133–355 m/s, +266 m/s² | 0.7×2.6+3.0×0.45 = **3.17 s** (`:372`) | 11.1 local = 2 464 m + 155 m start ≈ **2.6–2.9 km** |
| embers | 2.5–6.0, g −3 (`:396-398`) | 555–1332 m/s | 1.1×2.6+3.0 = 5.86 s (`:405`) | apex 6.0 local ≈ **1.33 km** |
| dirt | 5–9, g −9 (`:431-433`) | 1 110–1 998 m/s | 2.6 s (`:439`) | apex 4.5 local ≈ **1.0 km** |
| debris | 5–13, g −20 (`:449-451`) | 1 110–2 886 m/s | 2.34 s (`:456`) | apex 4.2 local ≈ **0.94 km** |
| linger smoke | 0.7–1.6, g **+0.5 up** (`:471-473`) | 155–355 m/s rising | 3.2×2.6+3.0 = **11.32 s** (`:484`) | 50.1 local = **11.1 km** |

Briefing #5's m/s figures CONFIRMED exactly (133–355, 555–1332). The part it did not
compute: the fireball's gravity is UPWARD, so displacement grows quadratically —
**the fire centre is already 270–490 m up one second after impact**, and the lingering
smoke column tops out around **eleven kilometres** before its root frees at 14.4 s
(`gun_fx.gd:486`, 4.4×2.6+3.0). That is a mushroom stem, mechanically.

**visibility_aabb — the briefing's worry is REFUTED.** The box `(-40,-12,-40)+(80,100,80)`
(`gun_fx.gd:287`) is LOCAL space and is transformed by the root's scale for culling.
Max local excursions: linger 50.9 (0.8 + 50.1), fireball 11.8, ember ~6.5 up / 25 lateral,
debris 26 lateral — **all inside y∈[−12,+88], x/z∈[±40]. Culling clips nothing, at 222 or
any other scale.** Cost note, not correctness: at 222 the world-space box is ~17.8 × 22 km,
so a napalm plume is never frustum-culled from anywhere on the 512 m map for its full life.

## 3. Call-site parity — CONFIRMED

Every `"explosion_napalm"` caller in the repo:
- **World:** `scripts/vehicles/cas_airplane.gd:419` — `GunFX.play_explosion_3d(tree.current_scene, impact, "explosion_napalm")`, default mult, inside `_drop_napalm_strip` (`:405-422`): 9 drops (`FirePlan.NAPALM_DROPS`, `scripts/gameplay/fire_plan.gd:31`) on 22 m spacing (`fire_plan.gd:32`), rippled `i × NAPALM_STAGGER` = 0.1 s (`cas_airplane.gd:26,413`).
- **Bench:** `scripts/levels/vfx_range.gd:244` (single) and `:279` (`_fire_all` row) — same call, default mult, kind from `KINDS` (`:19-22`).

**Parameters are IDENTICAL** (kind + default mult; parent/pos differ immaterially). No unit
mismatch — briefing #3 confirmed. Non-default `visual_mult` exists in exactly one caller:
`scripts/world/destructible.gd:201` passes `("explosion_grenade", 1.0)` — collapse dust,
non-ordnance, exactly the case the param was built for (`gun_fx.gd:156-157`).
`destructible.gd:177-178` uses default mult via `blast_for()` kinds (grenade fallback,
`destructible.gd:56-60`) — never napalm.

**Two callers BYPASS the ladder entirely** (they call `_spawn_explosion_visual` direct):
- `scripts/ai/ambient_war.gd:193` — horizon flashes at **fixed scale 12.0, lifetime 2.5**. Not routed through `_KIND_SCALE`, so it will NOT follow any re-anchor (see §7.4).
- `scripts/levels/game_world.gd:227` — boot shader warm-up, default 1.0. Harmless.

## 4. Who reads the constants — CONFIRMED: a retune turns nothing red

Repo-wide grep for `_KIND_SCALE|ORDNANCE_VISUAL_MULT` (scripts + tests + tools):
- `gun_fx.gd` itself (`:117,120,137,138,159,161`).
- `tools/probe_fire_parity.gd:46-50` — **PRINTS the ladder only.** Its napalm gate
  (`:111-115`) fails on `felled == 0`, `release_count != 9`, `fires < 9` — counts, never
  scale. `_failures` is untouched by any scale value. Briefing #8 confirmed precisely.
- `scripts/autoload/audio_manager.gd:368` — a COMMENT naming `_KIND_SCALE`; the code reads
  `_KIND_AUDIO` (`:371-377`), which has **no napalm entry** — napalm's ears are borrowed
  `explosion_heavy` via `_AUDIO_KIND` (`gun_fx.gd:149`).
- `tests/test_fake_lights.gd:77` fires a default grenade and gates on light count and
  self-lit quads (`:79-82`) — scale-independent.
- Docs only: `production/DEMO_SHIP_BACKLOG.md:105` (says "x5" — stale, mult is 2.0).

**Verdict: retuning `explosion_napalm` (or the whole ladder) turns zero probes and zero
tests red.** The suite gates behaviour; the look is gated only by ADR-015 (his eyes).

## 5. The three instrument fixes, judged

**(a) Player-eye camera preset — ENDORSE, and here is the arithmetic that convicts the
current camera.** Bench camera: `(0, 300, 900)` FOV 70 (`vfx_range.gd:32-33,123-127`) =
**948.7 m slant range** to the shot. Demo truth: strike at `NAPALM_RANGE_M = 210.0`
(`scripts/levels/demo_game.gd:234`; strike path `:304-311`), player eye 1.7 m / hip FOV 75
(ADR-034 contract, enforced by `tests/test_viewmodel_sync_contract.gd`; bench camera spec
Y=1.7 FOV 75 in CLAUDE.md). Godot `Camera3D.fov` is VERTICAL (default `keep_aspect`
KEEP_HEIGHT): at 210 m, FOV 75 frames **~322 m of height** and ~573 m of width at 16:9.
The current visual is ~513 m wide with a column passing 500 m inside a second — **it
cannot be seen whole from the demo distance at all; only the 949 m god-cam frames it.**
The 8/12 tune was made on the only camera in the project that can contain the thing.
Implementation: one more preset key setting `_cam.position = Vector3(0, 1.7, 210)`,
zeroed pitch, `fov = 75.0`; far 12000 already suffices (`vfx_range.gd:127`). ~10 lines,
no cost, no engine caveats.

**(b) Full-run key from FirePlan constants — ENDORSE.** Correct shape: loop
`FirePlan.NAPALM_DROPS` (`fire_plan.gd:31`), offsets `(i − DROPS/2) × NAPALM_SPACING`
(`fire_plan.gd:32`, mirroring `cas_airplane.gd:407-410`), ripple via
`get_tree().create_timer(i × CASAirplane.NAPALM_STAGGER)` (`cas_airplane.gd:26` — 0.1 s;
same timer idiom as `:413`), each impact firing `GunFX.play_explosion_3d(self, p,
"explosion_napalm")` + `FireHazard.create_at(self, p, FirePlan.NAPALM_BLAST_M,
FirePlan.NAPALM_BURN_S)` (`fire_plan.gd:33-34`; signature `scripts/vehicles/
fire_hazard.gd:35`). Damage stays out — visuals and carpets only. Naming the constants
means the bench cannot drift from the world. ~15 lines; 9 FireHazards are nothing on a
bench scene. Two truths this key will faithfully reproduce (both world-identical, so the
instrument stays honest): `MAX_EXPLOSIONS = 9` is sized exactly to the run
(`gun_fx.gd:66-71`) — any 10th visual during it recycles the oldest by design — and
`MAX_LINGER = 8 < 9` (`gun_fx.gd:295,461-462`), so **the last drop of every napalm run
never gets lingering smoke, in the world and on the bench alike.**

**(c) Treeline yardstick — ENDORSE, number found.** The canopy height is already MEASURED
on disk: `data/veg_break_bands.json` is generated from the shipped `*_stump/_stem/_crown`
GLBs in `assets/world/vegetation/` by `tools/gen_veg_break_bands.py` ("every value is
measured, none is authored by hand", `veg_break_bands.json:2`). Tree tops (`top_m`):
**broadleaf_c 13.378 m** (tallest), broadleaf_b 11.192, broadleaf_a 8.568, bamboo_c 8.221,
jungle_palm_b3 8.112, palms a1–b2 5.1–7.7, bamboo_a/b 4.9–5.9. **The shipped canopy band
is ~8–13.4 m; the yardstick figure is 13.4 m.** Caution: the "12 m" in
`terrain/systems/damage_system.gd:20-21` and `jungle_patch_layer.gd:1-2,53` is the jungle
tile FOOTPRINT (12×12 m ground pan, ±0.92–1.10 jitter, `jungle_patch_layer.gd:297-300`),
not a height — do not anchor to it. Bench implementation: instance a treeline row of
`broadleaf_c.glb` + `jungle_palm_b3.glb` at the strike line (or a labelled 13.4 m pole
if GLB loading is unwanted in the bench). Trivial cost.

## 6. Re-anchoring to N× canopy — the formula

Mean rendered fireball width:
**W = 2.2 (quad) × 1.05 (mean particle scale) × K × 2.0 (mult) = 4.62 K → K = W / 4.62**
(band: W × 0.76 … W × 1.24 from scale_min/max 0.8–1.3, `gun_fx.gd:356-357`).

| target W per drop | in canopies (13.4 m) | `_KIND_SCALE` K | root scale |
|---|---|---|---|
| 45 m | 3.4× | **9.7** | 19.5 |
| 60 m (= NAPALM_BLAST_M lane width, `fire_plan.gd:33`) | 4.5× | **13.0** | 26 |
| 90 m (the stale bench-comment size, `vfx_range.gd:28`) | 6.7× | **19.5** | 39 |
| 513 m (current) | 38× | 111 | 222 |

Sanity at K=13 (root 26): fireball emitter at 18.2 m — literally just **above the
13.4 m treeline**, satisfying the 2026-08-04 decree's own words; rise 15.6–41.6 m/s;
1-second plume ≈ 75–110 m (~6–8 canopies); embers 65–156 m/s; full-life fire top ~305 m;
linger smoke still climbs to ~1.3 km over 11.3 s. **Chain geometry:** adjacent-drop overlap
= 1 − 22/W. At W=513 the overlap is 96% — nine drops fuse into one ~690 m dome
(176 m strip + 513 m width; briefing #2 arithmetic confirmed), which mathematically ERASES
his 2026-08-05 "rolling wall" ruling. At W=60 the overlap is 63% — a continuous 236 m wall
that still reads as a marching chain. **The map-width anchor and the rolling-wall ruling
are geometrically incompatible; the canopy anchor restores both of his earlier rulings.**
Caveat to name honestly: K alone cannot buy a LOW roll — the composition's up-gravity and
2.6× hold keep a column character at every K (see §7.1-.2).

## 7. The defects BEHIND the defect

1. **Napalm has no composition of its own — it is a grenade ×111.** Same cached procs,
   same sheet for every non-mortar kind (`napalm_explosion_sheet` drives grenade, rocket,
   heavy AND napalm — `gun_fx.gd:370-371`), same anatomy (flash/fireball/core/embers/
   ring/dirt/debris/linger). Uniform scale multiplies every internal offset and velocity:
   155 m airburst, 133 m flash altitude, 999 m ring, 11 km smoke. Only mortar ever got a
   kind-specific composition (`gun_fx.gd:364-376`). One scalar cannot fix a schema.
2. **The shock ring is the single most nuclear element** (999 m expanding ground ring,
   `gun_fx.gd:409-425,496`) — napalm should skip it exactly the way mortar skips the hot
   core (`gun_fx.gd:376-377` pattern). A napalm-specific `_fx_proc` (lateral spread, low
   up-gravity, no ring) is one more cached resource — zero per-event cost by the file's
   own architecture (`gun_fx.gd:165-168`).
3. **The ears will still say nuke after any visual fix.** Napalm borrows
   `explosion_heavy` audio (`gun_fx.gd:149`; no napalm key in `_KIND_AUDIO`,
   `audio_manager.gd:371-377`) — nine max-class blasts (max_d 1100 m, 520 ms duck each)
   inside 0.9 s. Out of today's scope but name it in the decree or he will re-report it.
4. **`ambient_war.gd:193` bypasses the ladder at fixed 12.0.** After a re-anchor to
   root ~26, the player's own napalm is ~2× an ambient horizon flicker's base scale —
   retune the 12 in the same change or distant war reads wrong relative to his strikes.
5. **Stale comments to correct ON TOUCH (NO-MORE-DRIFT):** `gun_fx.gd:118` header says
   "mortar ~37m", computed 2.2×1.05×10×2 = **46.2 m** (all other header rows check out:
   40mm 3.2 ✓ grenade 4.62 ✓ rocket 18.5 ✓ heavy 110.9 ✓ napalm 512.8 ✓);
   `gun_fx.gd:157` "stay off the x5" and `destructible.gd:200` "the x5 spectacle" — the
   mult is **2.0** (`gun_fx.gd:138`); `cas_airplane.gd:401` "Five canisters" —
   `NAPALM_DROPS` is **9** (`fire_plan.gd:31`); `vfx_range.gd:28` "Napalm now reads ~90m
   wide" sits directly above ":29-31 sized to cover the 512 m square" — **the bench header
   contradicts itself in consecutive lines**; `DEMO_SHIP_BACKLOG.md:105` "x5".
6. **Second bench (briefing #9) — real, three-way, but not in the napalm path.**
   `support_fire_range.gd:17` `FIELD := 200.0` → `wire(self, player, FIELD)` (`:133`);
   `probe_fire_parity.gd:44` wires **600.0**; demo is **512** (`game_flow.gd:565,603`).
   `map_size` feeds FieldDirector spawn/decoy clamps (`field_director.gd:179-180,
   1355-1358`), not the visual pipeline. Rule: harmonise to `GameFlow.DEMO_MAP_SIZE`
   as a one-line follow-up; do not let it expand this session.

## Recommendation (technical)

Order of operations: **(1)** land the three bench instruments (a=eye preset, b=full-run
key, c=canopy yardstick + the ~90 m header fix) — ~40 lines, zero engine risk, suite
stays green; **(2)** re-anchor `_KIND_SCALE.explosion_napalm` to the canopy yardstick
(start K≈13, his eye rules per ADR-015); **(3)** in the same change, give napalm a real
composition: skip the shock ring, drop the emitter y-offsets toward the deck, lateral
spread on a napalm-specific cached proc — that is what removes "nuclear", not the scalar;
**(4)** correct the five stale comments on touch; **(5)** follow-up ticket: napalm audio
identity + `ambient_war.gd` fixed 12.0 + bench `map_size` harmonisation.
What is sacrificed: the 8/12 "napalm ~513 m map-width" ruling dies — it was made on the
only camera that could see it and it geometrically contradicts his older rolling-wall
ruling; the canopy anchor is the one that keeps all three rulings alive.
