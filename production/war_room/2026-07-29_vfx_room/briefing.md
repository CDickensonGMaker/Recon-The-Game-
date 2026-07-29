# War Room 2026-07-29 — VFX Realism Pass (smoke, fire, explosions)

## Summoner's query (verbatim)
"making the special effects better. more realistic smoke clouds, realy fire, real explosions etc."

## Current state (pointers, verified 2026-07-29)
- `scripts/combat/gun_fx.gd:118-185` — the ONLY explosion visual: one tween-scaled emissive
  billboard quad + CPUParticles3D smoke (16 particles, flat color) + debris (20). Cap 6 concurrent.
- `scripts/combat/smoke_cloud.gd` — smoke grenade: a single translucent SphereMesh scaled over time.
  `blocks_sight()` (line 15) is LIVE GAMEPLAY — AI sight lines respect the sphere.
- `scripts/vehicles/fire_hazard.gd:26-40` — napalm: flat emissive cylinder, comment says
  "placeholder VFX". Damage ticks are live gameplay.
- `scripts/combat/gib_system.gd`, `gun_fx.gd blood()` — the flesh layer already uses flipbook
  sheets (`assets/textures/fx/blood/`), proving the flipbook path works here.
- Research on file: `production/research/gore_fx.md`, `production/research/gunfeel_2026-07-25.md`,
  `production/research/engine_mining_2026-07-18/` (MoHAA/Quake3 FX architecture notes).

## Binding constraints (canon — violations are an automatic overrule)
1. **ADR-026 Part A** (`production/adr/ADR-026-ps2-graphics-budget.md`): flashes/explosions are
   FAKE — emissive/additive sprites, never a per-event OmniLight. ≤8 real-time lights, 0 dynamic
   shadow casters. Guarded by `tests/test_fake_lights.gd`. FX = "animated texture planes + sprite
   particles."
2. **Forward+ is canon** (ADR-026 Amdt A, closed). Claw frame back within it.
3. **Perf reality**: last bench 23fps, CPU-bound in the AI. GPU has headroom; CPU does not.
   GPUParticles3D vs CPUParticles3D matters here.
4. **Fairness law**: muzzle flash telegraph floor (FLASH_SECONDS) untouchable.
5. **Visual truth = gameplay truth**: SmokeCloud's rendered volume must match `blocks_sight()`;
   FireHazard's rendered area must match its damage radius. Improving the look must not lie about
   the mechanic.
6. **Fossil law (ADR-023)**: any replacement deletes its predecessor in the same change.
7. **Aesthetic**: PSX-era low-poly, 2000s-FPS FX school (RTCW/MoHAA per gun_fx.gd header) — period
   Vietnam grit, not modern AAA volumetrics.

## Question before the council
Design the VFX upgrade: explosions (grenade/M79/RPG/arty), smoke grenades, napalm/burning fire,
and whatever supporting pieces (impact dust, lingering battlefield smoke) serve Pillar 2
(Atmosphere) — within ADR-026, on GPU headroom, without touching gameplay truth.
