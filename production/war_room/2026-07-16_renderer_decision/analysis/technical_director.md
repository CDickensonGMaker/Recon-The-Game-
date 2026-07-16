# Technical Director / Godot-Specialist — Renderer Decision Analysis

**Verdict up front: Mobile (Forward Mobile) is SAFE for launch scope. Ship Mobile + native (scale 1.0).**
Verified independently from code, not from the briefing's summary. The project.godot is ALREADY on
`rendering_method="mobile"`, `scaling_3d/scale=1.0`, debanding on, nearest texture filter — so this
decree ratifies the current on-disk state rather than changing it.

---

## 1. Forward+-only feature audit (grep + read, refuting/confirming the briefing)

Environment is built in **code**, not a `.tres` — `scripts/levels/game_world.gd:43 _setup_environment()`.
There is **no WorldEnvironment .tres and no .tres of any kind under terrain/** (glob returned nothing),
so game_world.gd is the single source of truth for the frame's post/GI stack. Reading it line by line:

| Forward+-only feature | Grep/read result | In use? |
|---|---|---|
| SDFGI | absent from all .gd/.tres | NO |
| SSIL | absent | NO |
| SSAO | absent | NO |
| SSR / screen-space reflection | absent | NO |
| Glow / bloom | absent (no `glow_*`) | NO |
| Volumetric fog | only `env.fog_enabled=true` + `fog_density=0.004` — that is classic **exponential distance fog**, which Mobile fully supports. No `VolumetricFog`, no `volumetric_fog_*`. | NO (distance fog only) |
| SSS / subsurface / backlight | absent from shaders | NO |
| High-precision depth / normal-roughness texture | no spatial shader reads it | NO |
| Directional shadows | `light.shadow_enabled = false` (`game_world.gd:48`) | OFF |
| MSAA | not set (off) | OFF |
| Ambient | `AMBIENT_SOURCE_SKY` (procedural sky) — Mobile-supported | fine |
| Lights placed statically | exactly **one** `DirectionalLight3D`, no static omni/spot | fine |

**The briefing's claim that NOTHING Forward+-only is used is CONFIRMED.** Every renderer-gated feature
in the sacrifice ledger (SSAO/SSIL/SDFGI/SSR/volumetric/HDR-glow) is already unused. Mobile takes away
nothing this game currently renders.

## 2. Custom shaders — Mobile-compatibility review

9 shaders exist. Grepped every one for the two things Mobile handles differently from Forward+:
`hint_screen_texture` and `hint_depth_texture`/`DEPTH_TEXTURE` reads in **spatial** shaders (Mobile does
not maintain the same resolved screen/depth copies mid-pass that Forward+ does).

| Shader | Type | Concern | Mobile-safe? |
|---|---|---|---|
| `terrain/shaders/suppression.gdshader` | **canvas_item** | reads `hint_screen_texture` (`SCREEN_UV`) | **YES** — screen-texture reads in the **2D/canvas pipeline are fully supported on Mobile**; the renderer split only affects *spatial* screen/depth reads. The briefing's A/B screenshots show the HUD/overlay rendering correctly, which is this shader. |
| `terrain/water/water.gdshader` (+ coastal/static/swamp) | spatial | `render_mode depth_draw_always` | YES — that WRITES depth, it does not READ `DEPTH_TEXTURE`. Depth-fade/shore blend is done via **vertex color** (`v_shore_distance = COLOR.r`), NOT a depth-texture read. This is a Mobile-friendly design by construction — no soft-particle-style depth sampling anywhere. |
| `terrain/water/water_common.gdshaderinc` | include | no depth/screen reads | YES |
| `terrain/shaders/terrain.gdshader` | spatial | plain PBR: albedo/normal/roughness, no screen/depth reads | YES |
| `terrain/shaders/vegetation_sway.gdshader` | spatial | `cull_disabled, diffuse_lambert, specular_disabled` — standard | YES |
| `assets/shaders/antenna_sway.gdshader` | spatial | `vertex_lighting` — a Mobile-oriented mode; fine | YES |
| `terrain/shaders/lab_grid.gdshader` | spatial | `unshaded` | YES |

**No shader of concern.** The only screen-reading shader is a 2D overlay (safe on Mobile), and the water
system deliberately avoids depth-texture reads. Zero spatial screen/depth sampling in the whole tree.

## 3. The one real Mobile ceiling — dynamic omni light clustering

Grep found **dynamically spawned OmniLight3D** (none static, none with shadows):
- `scripts/combat/gun_fx.gd:116,248` — muzzle-flash omni (range 7–16m, brief)
- `scripts/combat/illum_flare.gd:30` — **illum flare, range ~42m, energy 3.5, 25s lifetime** (night)
- `scripts/world/tunnel_room.gd:55` — one omni per tunnel room (range 7m)
- `scripts/missions/mission_generator.gd:805` — placed omni (range 14m)
- `terrain/systems/terrain_vfx.gd:265` — explosion omni (range = blast radius)

Mobile's Forward-clustered path caps **~8 omni/spot lights affecting a single mesh** (project default;
`rendering/limits/cluster_builder/max_lights_per_object` style ceiling). When exceeded, Mobile **silently
drops the lowest-priority lights on that surface** — it degrades, it does not crash or black-hole.

For **launch scope (daytime jungle + arena, Army grunt)** this is not reachable: muzzle flashes are
transient and few-at-a-time, tunnel lights are one-per-room, explosion lights are momentary. **SAFE.**

The place it bites is exactly the briefing's pillar-2 worry: **night operations with several illum flares
(42m range each) stacked over one terrain chunk, plus muzzle flashes** — a chunk mesh could exceed 8 omnis
and start dropping flare contribution on parts of the ground. Same ceiling blocks a future "night village
with many lamp/fire lights." That is a *future-feature* constraint, not a launch bug.

## 4. Config recommendation

**SHIP: Mobile + native (scaling_3d/scale = 1.0).** Already the on-disk config.

Ledger of the three options:
- **Mobile + native 1.0 (RECOMMEND):** 40.9 FPS, clears the 30 gate with ~36% headroom, PSX-crisp at
  native res, debanding on. Sacrifices: the Forward+-only stack the game already doesn't use, and the
  8-omni/mesh night ceiling (§3). No blur.
- **Mobile + 0.77 bilinear:** *Reject.* On Mobile the FSR1 mode falls back to **bilinear**, which softens
  the deliberate PSX crispness — a visual cost for perf we don't need (native already clears 30). If perf
  headroom is ever wanted, the correct lever is the **4.7 nearest-neighbor 3D scale filter** at a lower
  scale (looks *more* PSX, not blurry), NOT bilinear.
- **Stay Forward+ 0.77:** *Reject.* 29.2 FPS — fails the 30 gate — while paying for clustered-light/GI
  machinery this game never invokes. Strictly dominated.

Leave `scaling_3d/mode=1`/`fsr_sharpness=0.3` in place: harmless dead settings at scale 1.0 (no upscale
happens), and they're the ready-made knob if a future Forward+ A/B is ever wanted. Debanding (`use_debanding
=true`) is a 4.6 Mobile win — keep it; it removes the classic Mobile banding objection on gradients/sky.

## 5. Biggest single risk

**The Mobile ~8-omni-per-mesh cluster cap at night.** It does not threaten launch (daytime jungle+arena),
but it is the hard ceiling on the pillar-2 atmosphere features the briefing named — multi-flare night ops
and lamp-lit villages will silently drop lights on terrain chunks. Mitigation when that content lands:
raise `max_lights_per_object`, or (better) fake most night point-lights as emissive/unshaded geometry +
baked ambient rather than real OmniLights. Not a reason to hold launch on Forward+.
