# Technical Director — VFX Realism Pass (perf + canon compliance)

Date: 2026-07-29. Lens: performance on the reference machine (Intel UHD, 1280x720,
`scaling_3d/scale=0.75` → ~960x540 render target, Forward+), plus ADR-026 / test_fake_lights
compliance. Evidence pointers throughout per the Pointer Law.

## 0. Where the frame actually is (so we spend the right currency)

- CPU-bound in AI at ~23 fps in firefights (ADR-026:108-109, 121-122; briefing constraint 3).
- BUT the GPU is fill/pipeline-sensitive, not geometry-sensitive: cutting 99.5k prims + 77 draw
  calls moved FPS ~0 (PERF_LEDGER.md:95-104), and the standing overdraw finding says the transparent
  pass is already the GPU's sore spot — ~1,000 alpha-BLEND doubleSided canopy cards with no depth
  write (PERF_LEDGER.md:1034-1043).
- Conclusion: the currency we have to spend is GPU *compute/sim* headroom. The currency we do NOT
  have is (a) CPU main-thread time and (b) transparent-pass fill. Smoke is exactly a
  transparent-pass fill effect. That tension is the whole ruling below.

## 1. GPUParticles3D migration — GO, with conditions

### Why GO
- CPUParticles3D simulates every particle on the main thread every frame — the thread we are
  starving. GPUParticles3D moves sim to compute dispatch on the GPU, which has headroom
  (briefing constraint 3). This is the correct direction for a CPU-bound frame.
- Forward+ is canon (ADR-026 Amdt A) and is exactly the renderer where GPUParticles is
  full-featured (trails, turbulence, collision — particles-vfx SKILL.md §1, §5, §7).
- Current CPU particle counts are tiny (explosion 16+20, impact 10, blood 3+10 —
  gun_fx.gd:151, :167, :292, :348, :378), so today's *steady-state* CPUParticles cost is small.
  The real CPU cost of the current design is the **alloc-per-event churn** (§2), which the
  migration must fix at the same time or it buys little.

### Costs and conditions
1. **Node/dispatch cost.** Each GPUParticles3D is one compute dispatch + one draw call per draw
   pass, resident whether emitting or not once in tree. Keep the resident emitter population
   bounded: **≤ 32 GPUParticles3D nodes alive in the world, total, all FX combined** (pool-owned,
   see §2). Baseline draw calls at the measured pose were 164 (PERF_LEDGER.md:98) — +≤40 draw
   calls from FX is tolerable; +hundreds is not.
2. **First-emission stutter (the known hitch).** Two distinct causes:
   - *Pipeline/shader compile*: each unique (process material × draw-pass material × mesh format)
     combination compiles a pipeline on first render. Mitigation: **shared materials by decree** —
     ONE ParticleProcessMaterial and ONE draw-pass StandardMaterial per FX archetype (explosion
     fire, explosion smoke, debris, dirt puff, grenade smoke, napalm fire, napalm smoke ≈ 7 unique
     pipelines total). gun_fx.gd already learned this lesson for the flash (`_flash_mat()`,
     gun_fx.gd:227-243) — extend the same law to every particle draw pass. Never mint a
     StandardMaterial3D per event (also the godot-optimization anti-pattern list, SKILL.md §7).
     At export time, the Shader Baker (godot_4.7_features.md:149) kills first-contact compile
     hitches for shipped builds; in dev, warm-up covers it.
   - *Buffer allocation + cold emitters*: first `emitting = true` on a fresh node allocates GPU
     buffers. Mitigation: **warm the pool at mission load** — after the world builds and before
     the fade-in, `restart()` + emit each pooled emitter for one frame (or
     `request_particles_process(lifetime)` — 4.7 API, particles-vfx SKILL.md §10) while the
     screen is still covered. This is a one-time load-screen cost, zero runtime cost.
3. **`fixed_fps = 30`** on all lingering FX (smoke clouds, napalm, battlefield haze) — halves sim
   dispatch work for effects nobody can see updating at 60 (SKILL.md §10). Burst effects
   (explosion flash/debris) stay at render rate.
4. **Blood/gibs stay CPUParticles.** They are 3–10 particles, already shipped, already use the
   flipbook path (gun_fx.gd:344-397), and the Fossil Law does not force migration of a system we
   are not replacing. Migrating them is churn for ~0 measured win. Scope the GPU migration to:
   explosion (fire/smoke/debris), impacts (dirt puff), SmokeCloud, FireHazard, plus any new
   ambient battlefield smoke.

## 2. Pooling — YES, this is the bigger CPU win than the GPU sim itself

gun_fx.gd `_spawn_explosion_visual` (gun_fx.gd:118-185) allocates **per event**: 1 Node3D +
1 MeshInstance3D + 1 QuadMesh + 1 fresh StandardMaterial3D + 2 CPUParticles3D + 1 Tween +
1 Timer, then queue_frees the lot 1.4s later. `impact()` (gun_fx.gd:286-307) does the same per
bullet strike. During a 30v30 contact this is dozens of allocations and frees per second on the
thread that is already the wall — plus the fresh material breaks batching and (for GPUParticles)
would force pipeline re-use misses. This is the exact `instantiate()+queue_free()` anti-pattern
the optimization skill names (godot-optimization SKILL.md §7, references/memory-management.md).

**Architecture ruling: a static FXPool, preallocated at mission load.**
- Preallocate N rigs per archetype: **6 explosion rigs** (matches MAX_EXPLOSIONS — the cap is
  fine, keep it), **12 impact puffs** (matches MAX_IMPACTS), **4 smoke-cloud emitters**,
  **2 napalm emitters**, ≈ 24–30 nodes ≤ the 32 budget.
- Checkout = reposition + `restart()` + `emitting = true` (one-shot re-trigger pattern,
  particles-vfx SKILL.md §2). Return = timer flips `emitting=false` and marks free. Zero
  allocation in the combat hot path; the caps become "pool exhausted → drop the event", which is
  what MAX_EXPLOSIONS already does, but without the `_explosion_nodes.filter()` array rebuild per
  call (gun_fx.gd:125 — a per-event allocation itself).
- **MissionScope teardown**: pool is rebuilt per mission (same lifecycle as `reset_session()`,
  gun_fx.gd:24-33). Pooled nodes must reset ALL state on checkout (position, scale, material
  alpha the tween touched) — the pool checklist item in godot-optimization SKILL.md §8.
- **Test-compat constraint (critical, see §5):** the pooled explosion visual must still be
  parented (or reparented on checkout) under the CALLER's parent node, because
  test_fake_lights.gd finds the visual via `host.get_child(0)` (test_fake_lights.gd:64, :78).
  A globally-parented pool that leaves the host childless turns the guard red. Reparent-on-
  checkout is cheap and keeps the probe honest.
- **Fossil Law (ADR-023 / ADR-026:111-116):** the GPU/pooled path DELETES the CPUParticles +
  per-event-material code in `_spawn_explosion_visual` and `impact()` in the same change. Two
  ways to draw an explosion is the exact fossil the law forbids.

## 3. Smoke fill-rate — the real GPU risk, quantified

Overdraw, not particle count, is the GPU cost of smoke. Numbers for the reference target:

- Render target at scale 0.75 of 1280x720 ≈ **960x540 ≈ 518k pixels**.
- A smoke grenade cloud (max_radius 8m, smoke_cloud.gd:7) stood next to can fill **half the
  screen**. If built from ~40 modest overlapping alpha billboards, average overdraw through the
  cloud core is easily 8–15x → **2–4 M shaded transparent fragments per cloud per frame**, with
  no early-Z (alpha blend never depth-writes). Intel UHD effective transparent fill is a low
  single-digit Gpix/s with blending; 3–4 clouds + napalm + an explosion could plausibly add
  **3–8ms GPU** — enough to flip the frame back from CPU-bound to co-limited, which is the
  two-legged failure ADR-026:108 warns about. The canopy overdraw finding proves this pass is
  already the sensitive one (PERF_LEDGER.md:1034-1043).

**Mitigations (ordered, binding):**
1. **Few, big, flipbook-animated particles — never many small ones.** A cloud is **8–16 large
   billboards** with an animated smoke flipbook (canon-blessed form: ADR-026 A.5 "animated
   texture planes + sprite particles"; the blood flipbook proves the pipeline,
   briefing :13-14). Internal motion comes from the flipbook + slow rotation + turbulence
   (SKILL.md §8), not from particle count. 12 big quads at 10x overdraw beats 100 small quads at
   the same coverage with worse sort cost.
2. **Tight texture occupancy.** Author the smoke sprite to fill its quad (little transparent
   border) — every fully-transparent shaded pixel is pure wasted fill. Prefer near-round puffs
   cropped tight.
3. **Soft particles (proximity/depth fade): DEFER.** It adds a depth-texture sample per
   transparent fragment across exactly the millions of fragments we just budgeted — a bandwidth
   tax on the weakest part of the GPU. And hard billboard/geometry intersections are
   period-authentic (2000s-FPS school, gun_fx.gd:1). If ground-plane clipping looks bad in the
   look-check, enable `proximity_fade` on the ONE grenade-smoke material only, and A/B it on the
   bench before it ships.
4. **Concurrency caps, same pattern as today:** MAX_SMOKE_CLOUDS = 4 (pool size), napalm ≤ 2,
   explosion smoke lifetime ≤ ~4s so lingering columns don't stack across a contact. Lingering
   "battlefield haze" (briefing :36) must be ONE cheap effect: a handful of very large, very
   low-alpha, `fixed_fps=15` billboards — not a per-corpse emitter.
5. **Fire is additive** (no sort pain, blends cheaply with itself) but costs the same fill —
   napalm at radius 10 (fire_hazard.gd:7) must be a RING of flame sprites at the perimeter +
   sparse interior tongues, not a solid 10m disc of alpha.

## 4. Gameplay-truth wiring (constraint 5) — cheap, but name it

- SmokeCloud: drive the emitter's emission sphere radius / draw scale from `current_radius()`
  each physics tick exactly as the placeholder sphere does now (smoke_cloud.gd:59-66). The
  particle cloud's visual hull must track the `blocks_sight()` sphere (smoke_cloud.gd:15-28)
  through grow AND the 5s decay. A pretty cloud that outlives its concealment is a fairness lie.
- FireHazard: flame ring radius = `hazard_radius` (fire_hazard.gd:14-20). Same law.
- These are `_physics_process` property writes on 4–6 nodes — negligible CPU.

## 5. What turns test_fake_lights.gd red (do NOT do these)

1. **Any OmniLight3D/SpotLight3D anywhere under a flash or explosion root** — `_count_lights`
   walks the whole subtree (test_fake_lights.gd:34-38, :67, :81). "Realistic fire" via a
   flickering light is a canon violation, full stop (ADR-026 A.1). The Shader answer is emissive
   flipbooks; ground glow is an unshaded additive quad or a Decal, never a light.
2. **Replacing the explosion's MeshInstance3D fireball with particles only** — the probe requires
   ≥1 self-lit (UNSHADED + emission_enabled) MeshInstance3D under the explosion root
   (`_selflit_quads`, test_fake_lights.gd:41-54, :82), and ≥2 under the muzzle flash (:68-69).
   GPUParticles3D is not a MeshInstance3D and its draw-pass material is not scanned. **Keep the
   emissive core quad** (it is also the fairness POP, ADR-026:41-46). The upgrade layers
   particles AROUND the quad; it never deletes it.
3. **Pooling that de-parents the visual from the caller** — `host.get_child(0)` returns null
   (:64, :78). Reparent pooled rigs on checkout.
4. **Touching FLASH_SECONDS (0.06) or MAX_FLASHES (< 32)** — :70-72 fail. Fairness floor, not a
   look knob (gun_fx.gd:250-253).
5. **"Improving" IllumFlare, the tunnel candle, or the campfire while in the neighborhood** —
   the flare and candle must KEEP real lights (:124-127); the campfire source-checks for
   `_firelight_mat` + UNSHADED + ADD + `emission_energy_multiplier` (:116-119). If the campfire
   gets new fire VFX, those tokens must survive or the probe is updated in the same change with
   the Arbiter's sign-off.

## 6. Measured probe BEFORE ship + FPS-regression strategy

The ledger's binding bench law applies (PERF_LEDGER.md:1066-1068): no FPS delta accepted unless
the draw-call/primitive delta has the right sign and plausible magnitude; windowed only (GPU-ms
reads 0 headless); Blender closed.

**Pre-ship probe (required — smoke fill is estimated above, not measured):**
- Windowed bench, ship parity, fixed pose. Phases: `baseline` → `fx_worst_case` (script-spawn
  6 explosions + 4 max-radius smoke clouds + 1 napalm inside the view) → `baseline` A/B/A.
  Record fps, GPU-ms, draw calls, prims. **Acceptance: FX worst case costs ≤ 2.5ms GPU and
  ≤ +0.5ms CPU at the pose; draw calls +≤40.** If smoke alone blows the GPU budget, halve
  particle counts per cloud (16→8) before touching anything else — fill scales ~linearly with
  layer count.
- Second probe: **first-emission hitch** — frame-time spike on the first explosion after boot,
  with and without the load-time warm-up. Acceptance: no frame > 66ms attributable to first FX
  (the Quake-3 cap, CLAUDE.md timestep section, is the ceiling of tolerable).
- CPU spike check: spawn 20 impacts + 3 explosions in one second pre- and post-pooling;
  the pooled path should show ~0 allocation cost (godot-optimization §1 micro-bench pattern).

**Regression guard going forward:** add an `fx_stress` phase to the existing perf-probe cycle
(the `--perf-probe --perf-cycle` harness, PERF_LEDGER.md:1091-1100) so every future ledger batch
re-measures FX cost for free. Plus a headless structural probe (extend test_fake_lights or a
sibling): asserts pool sizes ≤ caps, zero lights, shared-material identity (all explosion rigs
reference the SAME material resource — catches the per-event-material fossil re-appearing).
Headless can't see fill, but it can see the shapes that create fill.

## 7. Verdict summary (budgets of record for this pass)

| Budget | Value |
|---|---|
| Resident GPUParticles3D nodes (all FX) | ≤ 32, pool-owned, preallocated at mission load |
| Unique FX pipelines (process mat × draw mat) | ≤ ~8, shared statics, warmed at load |
| Smoke grenade cloud | 8–16 large flipbook billboards, `fixed_fps=30` |
| Concurrency | explosions 6 (unchanged) · smoke clouds 4 · napalm 2 · impacts 12 (unchanged) |
| FX GPU cost, worst case, measured pose | ≤ 2.5ms (bench-gated) |
| FX CPU cost, steady state | ~0 (pooling; no alloc in hot path) |
| Draw calls added | ≤ +40 |
| Real-time lights added | 0. Ever. |
| Soft particles / proximity fade | deferred; grenade smoke only, only after a bench A/B |

GPUParticles3D migration: **GO** for explosions, impacts, smoke, fire — conditional on pooling,
shared materials, load-time warm-up, and the pre-ship fill bench. Blood/gib CPUParticles stay.
The emissive fireball/flash quads stay (fairness + probe). The predecessor CPUParticles code is
deleted in the same change (ADR-023).
