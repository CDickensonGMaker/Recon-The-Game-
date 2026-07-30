# TECHNICAL-DIRECTOR / GODOT-SPECIALIST — ADR-026 "THE PS2 BUDGET"

Read from code, not the plan. Godot 4.7 Forward+, measured baseline: deep-night jungle 18v18 ≈ 19 fps,
BOTH-bound (GPU ~50ms foliage fill + CPU ~40ms / 36 clustered men).

---

## 0. WHAT THE CODE ACTUALLY SAYS (the load-bearing facts)

**Renderer / scaling — `project.godot [rendering]`:**
- `renderer/rendering_method="forward_plus"` — we pay the clustered-light + depth-prepass tax of a AAA path on a PSX game that uses none of its GI/SSR/volumetrics.
- `scaling_3d/mode=1` → that is **FSR 1.0**, not nearest. `scaling_3d/scale=1.0` → **we render at full native res and FSR-upscale by 1.0 (a no-op).** The knowledge brief's "scale=0.77 already set" is STALE — the project file says 1.0. **The single cheapest, most PSX-aligned GPU lever in the engine is currently switched off.**
- `mesh_lod/lod_change/threshold_pixels=2.0` — mesh LOD already aggressive (good).
- `max_fps=120`, window 1280×720.

**Lights (Rule 1 targets):**
- `gun_fx.gd:116` — every **explosion** spawns a real `OmniLight3D` (energy 8.0, range 16m), tweened out over 0.25s — beside an already-emissive unshaded billboard (line 122), so the omni is redundant.
- `gun_fx.gd:248` — every **muzzle flash** spawns a real `OmniLight3D` (energy 3.0, range 7m). In an 18v18 firefight = **dozens of transient dynamic lights per frame**, each re-running Forward+ cluster assignment.
- `terrain_vfx.gd:265` — another explosion OmniLight (energy 5.0).
- `illum_flare.gd:30` — flare OmniLight (energy 3.5); arena keeps 1–2 burning + re-pops every 18s.
- `ai_stress_arena.gd:493` — 4 campfire OmniLights (energy 1.8, range 14m).
- `ai_stress_arena.gd:385` — **the sun `DirectionalLight3D` has `shadow_enabled = true`.** The ONE shadow-caster, and in dense alpha-scissor jungle almost certainly the largest single slice of the 50ms: the shadow pass re-rasterizes every grass fan / palm frond, and **alpha-scissor kills early-Z**, so it is full-overdraw twice (shadow + colour).

**Vegetation / geometry (Rules 3–5):**
- `vegetation_sway.gdshader:15` — `render_mode cull_disabled` on ALL swaying foliage. Every star-fan and frond rasterized **both sides** → the fill-rate killer, no early-Z because also alpha-scissor.
- No `IN_SHADOW_PASS` branch — wind vertex math runs during the shadow pass for nothing.
- `_scatter_ground_plants()` — **18 variants × 110 = 1,980 MultiMesh instances**, plus JunglePatchLayer patches, 2× elephant-grass strips (80 each), rice (55 each), palms, bamboo, tree clumps. `visibility_range_end=65m` with `VISIBILITY_RANGE_FADE_SELF` — the fade mode costs a dither/alpha pass; PS2 had no smooth LOD.
- `water_static.gdshader:2` — `depth_draw_always, cull_disabled` + Fresnel + procedural normal maps + per-pixel specular. Double-sided transparent with forced depth writes = expensive; not in the jungle bench, so LOW priority for the measured frame.
- `terrain_chunk.gd:build_mesh` — `SurfaceTool` with **no `st.index()`**; every quad emits 6 unshared verts (2× vertex load, no post-transform cache reuse). Fallback material also `CULL_DISABLED`. Not the arena's dominant cost but the anti-pattern repeats project-wide.

**CPU (Rule 2 target) — the 40ms / 36 men:**
- Real per-agent cost = EnemyBase/AllyBase think @ 6–7Hz + NavigationAgent3D + `CombatManager.has_line_of_sight` raycasts + per-frame `_execute`.
- **BUT the arena inflates its own baseline:** `_update_patrol_contact` → `_spotted_us_for` runs an **O(US×VC) LOS raycast sweep EVERY frame** in patrol mode (up to 18×18 ≈ 324 `has_line_of_sight` calls/frame). `_update_debug_vis` rebuilds an `ImmediateMesh` + touches every `Label3D` every frame. `_update_telemetry` walks all agents ~6×/frame. **A meaningful chunk of "40ms/36 men" is bench instrumentation, not shippable AI.** The entity cap MUST be sized from a real mission profile, not this contaminated number.

---

## 1. ARE THE FIVE RULES THE RIGHT PRESCRIPTION? — YES on GPU, with one structural gap

Frame is **both-bound (50/40)**. Rules 1,3,4,5 attack GPU; only Rule 2 attacks CPU. That asymmetry is the whole story (§3).

### Rule 1 — LIGHT BUDGET: **SOUND, high value.**
Forward+ cluster cost scales with lights × touched tiles × frame. Per-shot muzzle OmniLights are the worst case (many, transient, forcing re-cluster). Emissive quad + additive sprite is strictly cheaper and more PSX. Bigger win hiding here: **turn the sun's shadow off** (or cap `directional_shadow_max_distance` ~40m). PS2 had no real-time shadow maps; that alone should reclaim a large fraction of the 50ms.

### Rule 2 — ENTITY BUDGET: **DROPPED by Summoner amendment.** PS2 Budget is graphics-only; no headcount cap. Big firefights (real 30v30 ≈ 60 combatants, all visible/animated) are a PILLAR. CPU is solved by **activity-tiered AI**, not fewer bodies — see §2.5 for the affordable hot-set size (the real CPU budget).

### Rule 3 — DRAW DISTANCE (fog wall): **SOUND, nearly free.**
Distance fog in Forward+ is a cheap fragment op (do NOT use volumetric — 4.7 changed its blending and it costs real GPU). Current `fog_density=0.006` is far too thin to hide anything. Raise so opaque by ~90m, then hard-cull behind it with `visibility_range_end`.

### Rule 4 — VEGETATION/GEOMETRY: **SOUND, the single biggest GPU lever.** (fixes in §2)
The `cull_disabled` + shadow-casting jungle IS the ~50ms. Rule is correct; it just needs concrete shader/flag changes named.

### Rule 5 — WATER/FX: **SOUND but LOW priority.** Not in the measured frame. Fix `depth_draw_always`/`cull_disabled` when it matters; don't let it block the decree.

---

## 2. THE NUMBERS I WOULD PUT IN THE ADR

| Budget | Value | Why it's cheap in Godot 4.7 |
|---|---|---|
| **Max simultaneous real-time lights (N)** | **8** total on screen, **0 shadow-casting dynamic lights** | Cluster cost is per-light-per-tile; hard cap bounds it. Muzzle/explosion → emissive sprite (no OmniLight). Campfires/flares pooled + capped. |
| **Sun shadow** | **OFF** (or `directional_shadow_max_distance ≤ 40m`, near-field only) | Alpha-scissor shadow pass over dense jungle is the biggest night cost; PS2 had no shadow maps. |
| **Active-entity cap** | **16 active** (hard ceiling 20), rest trickled by the existing wave system; freeze/cull > ~70m or off-screen via `set_physics_process(false)` + think-interval ×3 for far units | CPU is 40ms; only lever that touches it. 16×0.8ms ≈ 13ms leaves room under a 33ms (30fps) frame. |
| **Render-scale target** | **`scaling_3d/scale = 0.6`**, **`scaling_3d/mode = 5`** (nearest-neighbor, new in 4.7) — NOT the current FSR1 (mode=1), which blurs | Fill is O(pixels): 0.6² ≈ 0.36 → ~2.8× less fragment work. Nearest = crisper AND more PSX. Currently a no-op (scale=1.0) — biggest free win on the table. |
| **Fog far / draw distance** | Fully opaque by **~90m**; `visibility_range_end` foliage **80m**, units **~70m** | Distance fog (not volumetric) is a cheap fragment op; culling behind it removes real fill. |
| **LOD snap distances (hard, no fade)** | Foliage: full <40m, hide-snap **65–80m** (switch `FADE_SELF` → `FADE_DISABLED`). Units: full <35m, low 35–70m, cull/impostor >70m | Hard snaps skip the dither/fade pass; `mesh_lod threshold_pixels=2.0` already handles geometry LOD. PS2 had no crossfade. |

## 2.5 CPU BUDGET — AFFORDABLE HOT-SET SIZE (replaces the dropped entity cap)

60 combatants all exist / visible / animated (pillar). CPU is bounded by **activity tier, not headcount**. The per-frame full-sim cost lives in the HOT set; COLD fighters run cheap behaviors (move/hold/suppress/reposition/fire-in-general-direction) with **cached squad-level LOS**, no per-agent raycast.

Sizing from the bench, decontaminated: 40ms/36 ≈ 1.1ms/man raw, but a large slice is bench-only (O(US×VC) per-frame patrol LOS sweep, per-frame ImmediateMesh debug, 6× telemetry walks). Real full-sim ≈ **0.6–0.8ms/man** (LOS raycasts dominate). Cold-tier ≈ **~0.1ms/man**. For a 30fps frame (33ms) allotting ~16ms to AI alongside 60 animated bodies:

  0.7·H + (60−H)·0.1 ≤ 16  →  0.6·H ≤ 10  →  **H ≤ ~16**

**Target hot-set: 12 fully-simulated fighters, ceiling 16.** That bounds per-frame full-sim AI compute (~8–13ms) regardless of whether 40 or 80 men are on the field. Two force-multipliers on top, both free of the pillar:
- **Stagger the hot-set's think/raycast across frames** (round-robin) — even 16 hot fighters need not all raycast the same frame; this alone can double the effective hot-set or halve its cost.
- **Distance/visibility LOD** demotes far/off-screen units to cold automatically; **promote-on-death** reassignment (EnemySquad coordinator owns hot/cold membership) keeps the hot-set full where the player is looking.
- Candidates if 12–16 proves tight: **AI think on a WorkerThreadPool** (raycasts are the parallelizable part) and **batched physics queries** (`PhysicsDirectSpaceState3D` in one pass) — but ship the tiering first and re-measure before threading.

**Note:** the affordable hot-set is a CPU-budget target to design the coordinator against, NOT a visibility/spawn cap. Every one of the 60 is drawn, animated, and killable.

**Vegetation shader fixes (Rule 4, concrete):**
1. **Delete `cull_disabled`** from `vegetation_sway.gdshader` (and the terrain fallback). Bake real backfaces if two-sidedness is truly needed — don't pay it every fragment, every frame, in the shadow pass too.
2. **Wrap wind vertex math in `if (!IN_SHADOW_PASS)`** (4.7 built-in) so any surviving shadow pass skips the sway.
3. Set foliage `visibility_range_fade_mode = DISABLED` (hard snap).

---

## 3. THE SINGLE BIGGEST TECHNICAL RISK

**The PS2 Budget decree is graphics-only, but the measured frame is BOTH-bound (GPU 50 / CPU 40). Win every graphics rule and you do NOT reach 60fps — you convert a 19fps both-bound frame into a ~25fps CPU-bound frame (40ms) and stall there.** The graphics decree and the activity-tiered-AI work are **two legs of the same stool**; shipping the decree alone leaves the game CPU-bound. The tiering (§2.5) is not optional follow-up — it is the other half of hitting frame, and it must land in the same push or the graphics wins are invisible on the fps counter.

Second: the "40ms/36 men" baseline is **contaminated by bench-only cost** — the O(US×VC) per-frame patrol LOS sweep, per-frame ImmediateMesh debug rebuild, and 6× telemetry walks are `ai_stress_arena.gd` instrumentation no shipping mission runs. **Profile the hot-set cost in a real mission with bench instrumentation OFF before locking H=12**, or the coordinator gets tuned against a phantom number. Honest sequence: (1) graphics decree — drop render scale to 0.6/nearest, kill sun shadow, un-`cull_disabled` foliage — cheap, reversible, re-measure GPU; (2) profile real per-agent full-sim cost with the bench harness off; (3) size the hot-set to that number and build the hot/cold coordinator + think-stagger. Guessing H before step 2 is guessing.

**Secondary risk (named):** Forward+ → Mobile renderer is the logical endpoint of a light-budget ADR (Mobile drops clustered-light/GI/SSR/volumetrics this game never uses, adds FP16 + debanding), but it is a look-shifting, ~one-way change — make it an explicit A/B *after* the cheap wins, not bundled blind into the decree.
