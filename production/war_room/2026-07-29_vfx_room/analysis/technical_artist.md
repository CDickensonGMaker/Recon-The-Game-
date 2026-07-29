# Technical Artist — VFX Realism Pass (smoke, fire, explosions)
*War Room 2026-07-29. Independent analysis. Code verified against `scripts/combat/gun_fx.gd`,
`scripts/combat/smoke_cloud.gd`, `scripts/vehicles/fire_hazard.gd`, `scripts/combat/gib_system.gd`
as of this date.*

## 0. The craft frame

The school we are copying (RTCW / MoHAA / Vietcong, per the `gun_fx.gd` header and
`production/research/engine_mining_2026-07-18/mohaa.md §8`) did everything with **animated sprite
sheets on billboard quads, additive for fire, alpha for smoke, zero lights, zero volumetrics**. MoHAA
explosions are literally a 16-frame fireball flipbook + a dirt burst + a lingering smoke sprite. That
is not a limitation to work around — it IS the target look, and it happens to be exactly what ADR-026
Part A #1/#5 mandates ("animated texture planes + sprite particles").

The project already proved the whole pipeline: `gun_fx.gd blood()` runs an 8-frame flipbook
(`particles_anim_h_frames=4, v_frames=2`) off `assets/textures/fx/blood/blood_mist_sheet.png` on
`BILLBOARD_PARTICLES`. Every technique below is that pattern, scaled up.

**Perf posture (briefing constraint 3):** last bench 23fps, **CPU-bound**, GPU has headroom.
Therefore: **every new particle system is GPUParticles3D**, never CPUParticles3D — CPU particles
simulate on the main thread we cannot afford. The existing CPU systems (explosion smoke/debris,
impact puffs) get replaced by GPU equivalents and deleted (fossil law, ADR-023). The one thing GPU
particles cost that CPU ones don't is **per-node overhead and first-use shader compile** on the
Intel UHD driver — answered below by pooling + boot warm-up, not by falling back to CPU.

---

## 1. Shared infrastructure (build once, all four effects ride it)

### 1.1 FXPool — pre-built, restart()-driven effect scenes
`gun_fx.gd` today mints fresh nodes + fresh `StandardMaterial3D` per event (except the muzzle flash,
which already got the shared-material treatment — `_flash_mat()`). On a CPU-bound frame,
`Node3D.new()` + material setup + add_child per explosion is exactly the wrong allocation pattern,
and a *fresh GPUParticles3D* additionally risks a first-frame pipeline-compile hitch.

- One `FXPool` (autoload or static on GunFX, matching the existing all-static style): pre-instantiate
  **6 ExplosionFX + 12 ImpactPuffFX + 4 FireFX + 4 SmokeCloudFX** at mission load, hidden.
- Trigger = move to position, `restart()`, `emitting = true` (the one-shot re-trigger pattern from
  the particles-vfx skill §2). Return to pool on a timer — replaces the `_expire`+`queue_free` churn.
- **Warm-up:** on mission load, fire every pooled effect once at `Vector3(0,-500,0)` for one frame.
  This forces shader/pipeline compilation off the first real firefight. (Godot 4.7 ubershaders help,
  but a deliberate warm-up costs nothing and removes the doubt.)
- Existing caps carry over: `MAX_EXPLOSIONS=6` stays the pool size; the prune-freed-nodes dance at
  `gun_fx.gd:125` becomes unnecessary (pooled nodes are never freed mid-mission) but the
  MissionScope reset hook must clear/repark the pool.

### 1.2 Shared materials — the `_flash_mat()` discipline, extended
One static ShaderMaterial (or StandardMaterial3D) per effect *class*, cached like
`_shared_flash_mat` (`gun_fx.gd:227`): `_fireball_mat`, `_smoke_mat`, `_flame_mat`, `_dust_mat`,
`_ring_mat`. Never mint per event. This is also what keeps draw calls low — identical materials on
identical quads batch.

### 1.3 Texture set — art-storage discipline (palette strips over photo maps)
All sheets authored small, limited palette, imported **nearest filter** (PSX), mipmaps on. Total new
texture budget **< 400 KB on disk**:

| Sheet | Layout | Frame px | Sheet px | Palette | Use |
|---|---|---|---|---|---|
| `explo_fireball_sheet` | 4×4 = 16 fr | 64×64 | 256×256 | white→yellow→orange→red→black, ~12 colors | explosion core |
| `smoke_puff_sheet` | 4×2 = 8 fr | 64×64 | 256×128 | 4 grays + alpha | all smoke (explosion, grenade, fire, dust recolored via vertex color) |
| `flame_sheet` | 4×4 = 16 fr | 32×64 (tall) | 128×256 | 8 hot colors | napalm flame tongues |
| `shockring` | 1 fr | 64×64 | 64×64 | white ring, radial falloff | ground shockwave |
| `dust_dab` | 1 fr | 32×32 | 32×32 | 1 gray + alpha, tinted per-surface | impacts, dirt, debris |
| `scorch` | 1 fr | 128×128 | 128×128 | black/brown splotch | fire + explosion decal |
| `ember_dot` | 1 fr | 8×8 | 8×8 | white dot | sparks/embers (tinted) |

Authoring route: bake the fireball and smoke sheets from a quick Blender smoke/pyro sim rendered
orthographic to frames, then **posterize hard + downscale to 64px** so they read chunky-2002, not
photoreal. The flame sheet is faster hand-painted (8–16 licking-tongue frames — the Quake/RTCW
flame is *drawn*, and it reads better than any sim at 32px). One neutral **grayscale** smoke sheet
serves every smoke in the game — grenade color (goofy grape purple, WP white, signal yellow),
explosion gray-brown, napalm black all come free via `color`/`color_ramp` tint. That is the
palette-strip discipline applied to FX: one alpha shape, many tints, no per-color sheets.

Frame-rate of flipbooks: play 16 frames over ~0.5s (fireball) — 30fps flipbook is period-correct;
do NOT interpolate frames (no `particles_anim` smoothing exists anyway; the snap is the look).

### 1.4 Two shader techniques, used sparingly
- **Soft particles** = `StandardMaterial3D.proximity_fade_enabled`, distance 0.6–1.0m — one checkbox,
  a depth-texture sample in Forward+. Use ONLY on the big smoke quads (grenade cloud, lingering
  explosion smoke, napalm smoke) where a hard quad-vs-ground/tree intersection line would break the
  volume illusion. Skip it on fast short-lived stuff (fireball, dust) — invisible at 0.4s lifetimes
  and it costs a depth fetch per pixel of overdraw.
- **UV distortion / heat shimmer** = a spatial shader on one upright quad:
  `hint_screen_texture` sampled with UV offset by scrolling noise, masked by a vertical falloff.
  ~10 lines. This is the ONLY screen-texture effect in the pass, one quad per live fire, and it is
  a **P2 garnish** — MoHAA-era games shipped without it; cut it first if the frame complains.
  (Screen-texture reads force a copy of the screen; keep it to napalm only, never on explosions.)

Everything else is `StandardMaterial3D`: UNSHADED, `BILLBOARD_PARTICLES`, BLEND_ADD for fire,
TRANSPARENCY_ALPHA for smoke, ALPHA_SCISSOR (threshold ~0.4, the gore_fx.md dither discipline) for
dirt/debris/dust so they cost no sorting and no smooth-alpha overdraw.

---

## 2. (a) Explosions — the 5-layer stack

Replaces `_spawn_explosion_visual()` (`gun_fx.gd:118-185`) wholesale; the tween-scaled quad, its
CPU smoke and CPU debris are **deleted in the same change** (ADR-023). Signature and the
`scale_mult`/`lifetime_mult` AmbientWar contract stay — pooled `ExplosionFX.fire(pos, scale, life)`.

One pooled `ExplosionFX` scene, five children, all pre-wired:

| # | Layer | Node | Amount | Lifetime | Material | Notes |
|---|---|---|---|---|---|---|
| 1 | **Fireball** | GPUParticles3D | 3 | 0.5s | ADD, unshaded, `explo_fireball_sheet` 4×4, anim_loop off, `anim_speed` so 16 fr ≅ lifetime | `explosiveness=1.0`, tiny sphere emission (0.3m), scale 1.2→2.5m via scale_curve (grow fast, hold). 3 overlapping desynced flipbooks (`anim_offset_max=0.15`) read fuller than one — the MoHAA trick. Emission via material emission color pinned hot so it blooms under glow if glow is on; still zero lights. |
| 2 | **Shockwave ring** | MeshInstance3D (flat quad, +Y up, NOT billboard) | 1 | 0.35s | ADD, `shockring` | Tween scale 0.5→(5m·scale_mult), alpha→0. Sits 5cm off ground. This one layer is 80% of perceived "concussion". Cheapest node in the stack. |
| 3 | **Dirt column** | GPUParticles3D | 14 | 0.9s | ALPHA_SCISSOR, `dust_dab` tinted 0.4/0.34/0.25 | `direction=UP, spread≈18°` (a COLUMN, not a cone — the Vietnam arty look), vel 6–12·scale, gravity −14, scale 0.15–0.5m. Replaces the old debris block but shaped vertical. |
| 4 | **Debris streaks** | GPUParticles3D | 10 | 0.7s | same dust mat | spread 55°, vel 8–16, tiny (0.05–0.12m) — the fast radial chunks. Could share node 3 via two-burst restart; keep separate for shape control, same material so it batches. |
| 5 | **Lingering smoke** | GPUParticles3D | 6 | 3.5s | ALPHA + proximity_fade, `smoke_puff_sheet` looped slow, gray-brown tint | slow rise 0.8–1.5 m/s, scale 1→3m growing, alpha ramp in/out. This is the layer the current effect completely lacks and the one that sells "something died here" from 100m. `fixed_fps=30`. |
| + | **Scorch decal** | via existing Decal FIFO pattern | — | persistent | `scorch` | New `_scorch_decals` pool, MAX 16, reusing the `bullet_hole()` orient/FIFO code path. Ground memory of the fight — Pillar 2 for free. |

**Cost per explosion:** 5 draw calls + 1 decal, ≤33 particles. ×6 concurrent cap = ~30 draw calls,
~200 particles — noise on a GPU with headroom, ~zero CPU (pooled, GPU-simmed). The current effect is
3 draw calls with 36 *CPU* particles; we are strictly cheaper on the axis that is starved.

Distant AmbientWar events (scale_mult up, 200–800m): the fireball + smoke layers alone carry it;
gate ring/dirt/debris off when `scale_mult > 2` — they're sub-pixel at that range anyway.

---

## 3. (b) Smoke grenade — billow that never lies about the sphere

`blocks_sight()` (`smoke_cloud.gd:15`) is a segment-vs-sphere test at `center+1.5up, r=current_radius()`.
**The law: rendered smoke must fill that sphere and not meaningfully exceed it.** Design accordingly:

1. **Delete the SphereMesh** (`smoke_cloud.gd:45-56`) — same change, fossil law.
2. **Puff cluster:** one GPUParticles3D, continuous, `amount=28`, `lifetime=3.0`,
   `local_coords=true` (cloud doesn't move; cheaper transforms),
   `emission_shape=SPHERE`. Drive `emission_sphere_radius = current_radius() * 0.65` from the
   existing `_physics_process` (that 0.65, plus puff quad half-width ~0.35r, keeps rendered extent
   ≈ the gameplay r — puff centers inside, alpha skirts touch the boundary; verify against a debug
   sphere once, then delete the debug sphere).
   - Draw pass: 2–3.5m quads, `smoke_puff_sheet` slow-looping (`anim_speed≈0.4`, random
     `anim_offset` so no two puffs sync), `BILLBOARD_PARTICLES`, ALPHA blend, `proximity_fade` 0.8m.
   - Billow = three cheap motions, no turbulence needed: slow rise (vel 0.3–0.7), per-particle
     `angular_velocity ±20°/s` (rolling), and the flipbook itself. If it still reads static, enable
     `turbulence` at strength 0.3 — GPU-only cost, allowed, but try without first.
   - `color` = `smoke_color` tint on the grayscale sheet — grape/WP/signal colors free.
   - Alpha ramp: born at 0 → 0.55 by 20% life → 0 at death; plus drive the whole system's
     `amount_ratio` down over the last 5s to mirror `current_radius()`'s decay window, so the visual
     thins exactly when the sight-block shrinks.
   - `draw_order = LIFETIME`, `fixed_fps = 30`.
3. **Camera-inside case (visual truth, both directions):** when
   `camera.global_position.distance_to(center) < r`, the puff shell alone under-occludes (you'd see
   clear pockets while the AI legally can't see you — a lie in the player's favor). Add a
   camera-facing quad child of the camera (or a fullscreen ColorRect on a HUD layer), tinted
   `smoke_color`, alpha ramping 0→0.85 across the outer 20% of the radius. ~10 lines in the player
   script reading `SmokeCloud.active_clouds`. This is the single most important honesty fix in the
   whole pass.
4. **Cost per cloud:** 1 draw call (all puffs one system) + the inside-overlay. The real cost is
   **fill-rate/overdraw**: 28 × 3m alpha quads stacked. At 0.75 render scale, 4 concurrent clouds
   measured worst-case (player standing IN one looking through another) is the bench to run before
   ratifying `amount=28`. Mitigations in reserve, in order: fewer/larger puffs (16 × 4.5m reads
   nearly as well), tighter alpha ramp, half-res… not needed until measured.

Practical cap: 4 live clouds (pool size). The `active_clouds` array and `blocks_sight()` are
untouched — this is a pure renderer swap inside the same node.

---

## 4. (c) Napalm / fire — flame cards on the damage disc

Replaces the emissive cylinder (`fire_hazard.gd:26-40`, self-described placeholder) — deleted same
change. **Rendered area = `hazard_radius`, exactly**: every emitter below uses
`emission_shape=RING/SPHERE` with radius driven from `hazard_radius`.

Pooled `FireFX` attached by `FireHazard.create_at()`:

| Layer | Node | Amount (r=10m) | Lifetime | Material | Notes |
|---|---|---|---|---|---|
| **Flame cards** | GPUParticles3D | 36 | 1.1s | ADD, `flame_sheet` 4×4 looping, random `anim_offset` | **Y-axis-locked billboards** — Godot 4.7 `TRANSFORM_ALIGN_LOCAL_BILLBOARD` + `transform_align_axis=Y` (particles-vfx skill, 4.7 section): tall 32×64 tongues stand upright and face the camera without flat-lying when viewed from a hill. Emission ring at r·0.9 **plus** interior sphere fill (two systems or one sphere-emission with the ring look coming from density; interior fill matters — napalm burns the middle too). Cards 0.8–1.8m tall, slight upward vel, scale-down curve. Amounts scale with radius: `amount ≈ 0.35 · r²` clamped 12–48. |
| **Black smoke** | GPUParticles3D | 10 | 5.0s | ALPHA + proximity_fade, `smoke_puff_sheet` tinted 0.08 gray | rise 1.5–2.5 m/s to ~8m, growing 1.5→4m, `fixed_fps=30`. The pillar of black smoke IS the napalm image (Pillar 2); visible over treelines, marks the strike for the whole AO. |
| **Embers** | GPUParticles3D | 16 | 0.8s | ADD, `ember_dot`, tint orange | vel up 2–5 with spread, slight gravity. Cheap sparkle layer. |
| **Ground glow** | MeshInstance3D flat quad | 1 | pulsing | ADD, radial falloff tex (reuse `_get_flash_tex()` pattern) | sits 5cm up, r·2 wide, alpha oscillating 0.15–0.3 via one tween loop. The FAKE light — sells illumination with zero lights (ADR-026). |
| **Heat shimmer** | MeshInstance3D upright quad | 1 | — | screen-texture UV-distort shader | P2 garnish, see §1.4 — build last, cut first. |
| **Scorch** | Decal | 1 | persistent | `scorch`, sized to r | spawned at ignition, OUTLIVES the FireHazard node (parent to scene via the `_scorch_decals` FIFO, not to the hazard). Burned earth after the fire dies is the payoff shot. |

**Death fade:** over the last 2s of `duration`, tween `amount_ratio` → 0 on flames/embers and let
smoke self-expire — fire gutters out instead of blinking off (the current cylinder just vanishes).
Note the damage keeps ticking at full rate until `queue_free`; guttering visuals over a
still-lethal floor is a small lie — acceptable only because scorch + residual embers still mark the
area; if the council wants zero lies, fade damage_per_second with the same curve (gameplay call,
flagging it, not deciding it).

**Cost per fire:** 5–6 draw calls, ~62 particles. Cap 4 live fires (napalm is an event, not a
carpet). Additive layers don't sort and overdraw cheaply (no depth-fade, blend-add). The black
smoke is the only smooth-alpha layer.

---

## 5. (d) Supporting dust & debris

- **Impact puffs** (`impact()`, `gun_fx.gd:286-307`): port to 12 pooled GPUParticles3D
  (`MAX_IMPACTS` unchanged), `dust_dab` + ALPHA_SCISSOR, same shape params. Deletes 12×
  per-event CPU sims and per-event material mints. Add a 0.4s ground-hug drift (gravity −2 not −6)
  on soft surfaces so dirt hits *linger* a beat — the RTCW read.
- **Bullet dirt-kick strips:** for near-miss suppression fire on dirt, the same pooled puff with
  `spread` tightened works as walking impacts; no new system.
- **Explosion rolling dust ring:** already covered by explosion layer 3/4; if the ground plane wants
  a low rolling donut, RING emission on layer 4 (radius 1→3m) does it inside the same node.
- **Muzzle dust:** prone/low shots near ground — reuse impact puff at muzzle pos, gated by a ground
  ray we already cast for other reasons; P3, skip unless free.
- **Lingering battlefield haze:** after ≥3 explosions inside 20m/30s, drop one 20s low-alpha
  (0.12) large smoke system at the centroid. One pooled node, pure Pillar 2. P2.

---

## 6. GPU vs CPU verdict table

| Effect | Node | Why |
|---|---|---|
| Explosion (all 4 particle layers) | **GPUParticles3D** | one-shot bursts, CPU-starved frame |
| Smoke grenade cloud | **GPUParticles3D** | 28 alive × up to 4 clouds continuous — never on CPU |
| Napalm flames/smoke/embers | **GPUParticles3D** | continuous, biggest counts in the pass |
| Impact puffs | **GPUParticles3D** (pooled) | 12 concurrent one-shots |
| Blood mist/droplets (existing) | leave CPUParticles3D **for now** | 3+10 particles, works, flipbook proven; port opportunistically when touching gore, not in this pass — scope discipline |
| Shock ring / ground glow / shimmer | MeshInstance3D + tween | 1 quad each; a particle system is overkill |

CPUParticles3D earns a place in this game **nowhere new**. The skill's "CPU for low-end" rule of
thumb inverts here: our low-end is the CPU.

---

## 7. Budget roll-up (worst legal frame)

6 explosions + 4 smokes + 4 fires + 12 impacts, everything at cap:

- **Draw calls:** ~30 (explosions) + 8 (smokes+overlay) + 22 (fires) + 12 (impacts) ≈ **72 FX draw
  calls**. The tri-budget memory rule says chase draw calls: 72 is real but this co-occurrence is a
  screenshot, not a steady state; typical firefight frame is ~15–25.
- **Particles alive:** ≈ 700, all GPU-simmed. Trivial vertex load (2 tris each).
- **Fill rate** is the one axis to bench: stacked smooth-alpha smoke. Bench = 4 clouds + 2 fires
  through each other at 0.75 scale on the Intel UHD before ratifying amounts; `amount_ratio` is the
  pre-wired quality knob on every system if it fails.
- **CPU:** pool moves + `emission_sphere_radius` writes + a handful of tweens. Net CPU *reduction*
  vs today (CPU particle sims deleted).
- **Textures:** < 400 KB disk, 7 files, one folder `assets/textures/fx/` beside `blood/`. Purge any
  orphaned experiments before saving (art-storage law).

## 8. ADR-026 compliance checklist

- Zero new lights; fake glow = additive quads (fireball emission color, ground-glow pulse). Passes
  `tests/test_fake_lights.gd` by construction. ✔
- All sprites/flipbooks/texture planes — Part A #5 verbatim. ✔
- Forward+ features used: proximity_fade (depth), 4.7 local-billboard align, screen-texture (P2
  shimmer only). All within canon renderer. ✔
- FLASH_SECONDS and the muzzle-flash path untouched. ✔
- Visual truth: smoke fills the blocks_sight sphere both from outside AND inside (§3.3); fire fills
  hazard_radius; scorch marks are testimony, not gameplay. ✔
- Fossil deletions named: explosion tween-quad+CPU smoke+CPU debris (`gun_fx.gd:133-178`), the
  SphereMesh block (`smoke_cloud.gd:45-56`), the cylinder block (`fire_hazard.gd:26-40`), CPU
  impact puff internals (`gun_fx.gd:289-307`). Each dies in the change that replaces it. ✔

## 9. Build order (each step ships alone)

1. FXPool + warm-up + texture sheet authoring (fireball, smoke, flame, ring, dab, scorch, ember).
2. Explosion 5-layer stack (deletes old visual). Highest visible payoff per hour.
3. Smoke grenade puff cloud + inside-cloud overlay (deletes sphere). The honesty fix rides here.
4. Napalm stack + scorch decals (deletes cylinder).
5. GPU impact puffs (deletes CPU internals).
6. P2: heat shimmer, battlefield haze. P3: muzzle dust.

Overdraw bench after step 3; do not proceed to 4 on a red bench.

## 10. What is sacrificed (named)

- **No volumetric anything** — smoke silhouettes are quad clusters; from directly above a grenade
  cloud reads flatter than from the ground. Accepted: period aesthetic, and the AO is mostly
  eye-level jungle.
- **Blood stays CPU this pass** — a known inconsistency, deferred deliberately for scope.
- **Fire gutters visually before damage stops** (~2s) unless the council fades damage too.
- **Shimmer and haze are cuttable garnish** — the design must read complete without them, and does.
