# Synthesis — VFX Realism Pass (Arbiter's decree, 2026-07-29)

Council: technical_artist, tech_director, game_designer, devils_advocate (analyses in `analysis/`).

## Where the council converged (from four independent doors — strongest signal)

1. **"Realistic" means period-correct, not modern.** All four independently landed on the
   RTCW/MoHAA/Vietcong 2002-school: layered flipbook sprites, nearest-filtered small sheets,
   no volumetrics, zero real lights. ADR-026 already ratified that sacrifice; the blood system
   (`gun_fx.gd blood()`) proves the flipbook pipeline in-repo.
2. **GPUParticles3D, pooled and warm-started.** The frame is CPU-walled; every current FX particle
   is CPUParticles3D. Migrate explosions/smoke/fire/impacts to GPUParticles3D, preallocated at
   mission load, materials warmed to kill the first-emission pipeline-compile hitch. Blood/gibs
   stay CPU (tiny counts, gameplay-coupled).
3. **Visual truth slaved to gameplay geometry.** Smoke renders ≤ the `blocks_sight()` sphere
   (driven FROM `current_radius()`, both directions — includes a camera-inside overlay). Fire
   covers ≥ the FireHazard damage disc. Explosion visual scale derives from the real blast
   radius, so an RPG-7 (290) finally reads bigger than an M26 (190).
4. **Overdraw on the Intel UHD is the #1 risk.** Big stacked alpha smoke costs fill-rate the perf
   ledger has never measured. Few-large-flipbook-billboards (8–16/cloud), never many small; A/B/A
   windowed barrage bench (4 clouds + 2 fires + explosions overlapped) goes in PERF_LEDGER.md
   before amounts are ratified.
5. **Fossil law applies.** Sphere-mesh smoke, cylinder napalm, and the alloc-per-event CPU
   particle bodies are DELETED in the same change. New visuals live inside the EXISTING entry
   points and lifecycle skeleton (`play_explosion_3d`, `SmokeCloud.spawn_at`,
   `FireHazard.create_at`, caps, `_expire`, `reset_session` / MissionScope teardown).

## Conflicts resolved

- **DA: "GPU headroom is folklore" vs TD: "GO".** Both actually demand the same thing: the bench.
  Resolution: GO, conditional — the windowed barrage bench is a SHIP GATE, not a follow-up.
- **DA: lingering smoke saturates MAX_EXPLOSIONS=6 → siege arty renders nothing.** Resolution:
  split pools. Fireball/flash pool (cap 6, short-lived) is separate from lingering-smoke pool
  (cap ~8, long-lived). An arty barrage always gets its flash.
- **TD: `test_fake_lights.gd` red risk.** Resolution: the additive ground-glow and fireball stay
  emissive sprite layers (fake light by construction); pooling must keep visuals parented so the
  probe's assumptions hold. Suite run is the Summoner's (standing law) — flagged for his next run.

## The decree — build order

1. **Explosion stack** (serves every caller through `_spawn_explosion_visual`, `scale_mult`
   already plumbed): 3 desynced 16-frame fireball flipbooks + additive shock ring + dirt column +
   debris + 3.5s lingering smoke (own pool) + scorch decal. ~5 draw calls each.
2. **Napalm/fire**: Y-locked flame cards on the exact hazard disc, black oily smoke pillar
   (visible over canopy — a Freedom landmark), additive ground glow, persistent scorch. Delete
   the cylinder.
3. **Smoke grenade**: 28-puff GPU cluster driven from `current_radius()`, honest grow/fade,
   camera-inside overlay, per-use tint (grape/WP/white) from ONE grayscale sheet. Delete the
   sphere. One-time debug-sphere calibration vs `blocks_sight()`.
4. **Impact dust & firefight haze** (cosmetic only — never feeds AI perception).
5. **Bench + ledger entry** (ship gate) + Summoner suite run + eyes pass.

Assets: one grayscale smoke/fire flipbook family, 64px frames, <400 KB total, palette-friendly.

## What is sacrificed (the law binds the Arbiter too)

- No dynamic light thrown on the world by fire/explosions — canopies will not dance. ADR-026
  ratified this; the fake ground-glow is the ceiling.
- The 2002 aesthetic ceiling: FX will read as *Vietcong*, not *Battlefield*. That is the win
  condition, not the compromise.
- ~2–2.5ms of GPU frame budget and ~+40 draw calls in a barrage, bought back from CPU by the
  GPUParticles migration. If the bench disproves the headroom, amounts shrink — the caps are
  the knob, the architecture stands.
