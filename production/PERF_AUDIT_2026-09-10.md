# PERFORMANCE AUDIT — why it sits at ~20 fps, and how much of that is us (2026-09-10)

**His question:** *"figure out why the performance is so bad for this game? are we using godot wrong?
do i have too many throttles or something happening? ... i just dont believe that were stuck at this
20 fps hole for any reason that is proper production."*

**Method.** Read against the code and the logs already on disk (`perf_stress_20260909_011104.log`,
`perf_walk_20260908_213156.log`, `perf_walk_PSX_20260909_004610.log`), one new headless instrument
(`tools/probe_scene_census.tscn` — counts what is IN the world by class), Godot's own 4.7 docs and
tracker, and what comparable games do. Nothing windowed was run — he was at the machine. Every number
below names its source. Numbers from the Intel UHD are the punishment floor, not the target
(ADR-026 Amdt C); they are used here only to attribute cost, never to justify a cut.

---

## 1 · THE VERDICT, IN PLAIN WORDS

**It is two different problems wearing one number, and only one of them is the hardware.**

1. **On the Intel UHD the GPU alone is 14–35 ms per frame** (`viewport_get_measured_render_time_gpu`,
   sampled every frame by `fps_printer.gd:121`). Quiet walk: **13.9–25.0 ms** GPU at 960×540 internal
   (0.75 scale). Siege: **15.6–35.3 ms**, one 61 ms window. That is a 28–70 fps ceiling before a single
   line of GDScript runs. **This part is the iGPU**, and it is made worse by three things that ARE ours
   (§3: Forward+ on an iGPU, Vulkan on Intel, 3,600 draw-call buckets).
2. **The CPU side would take a good GPU to 3–5 fps in the siege anyway** (`ai.execute` dominant, 45-man
   assault at ~2.7 fps, handoff 9/09), and it hitches on ANY machine: `nav.collect 285.9 ms`,
   `terrain.crater 44–106 ms`, `spawn.man 119.5 ms` per soldier, `treebreak.spawn 84 ms` — all on the
   main thread, all synchronous, **zero threads anywhere in `scripts/` or `terrain/`** (grep). **This
   part is production**, and a discrete GPU will not hide it.

**Are we using Godot wrong?** In four specific, fixable ways — §3. **Too many throttles?** No: too few
in the places that cost (animation, spawning, rebuilds), and one throttle of the wrong shape (the
vegetation is 3,631 MultiMeshes averaging 7.8 instances each — the opposite of what MultiMesh is for).

---

## 2 · WHAT IS ACTUALLY IN THE WORLD — `tools/probe_scene_census.tscn`, demo seed, headless

```
[CENSUS] nodes total 21859
[CENSUS] MeshInstance3D visible 4757, surfaces 6291, tris 1519632, 4125 with NO visibility range
[CENSUS] MultiMeshInstance3D 3631, instances 28169, instanced tris 5068845
[CENSUS] CollisionShape3D 3314 (2762 concave trimesh)
[CENSUS] lights 1 (0 with shadows), decals 4, particles 3, audio3d 42
[CENSUS] CharacterBody3D 57, NavigationAgent3D 56, Skeleton3D 98, AnimationPlayer 93
[CENSUS] scripts with _physics_process 192, with _process 13
```

Read with the logs (`[FPS]` rows: draw calls **1,155–2,438**, primitives **266k–521k** per frame in
the siege; **362–1,397** / 85k–280k on the quiet walk):

- **Lighting is innocent.** One light, no shadows, four decals, three particle systems. Every "turn
  off shadows / lights" lever is already pulled. Do not go looking there again.
- **The vegetation is 3,631 draw-call buckets.** 27 species × 64 m buckets (`tree_cover_layer.gd:101
  BUCKET = 64.0`; species list in the `[TreeCover]` boot line) = one `MultiMeshInstance3D` per
  species-per-cell, **7.8 instances each on average**. A 350 m canopy ring covers ~120 cells per
  species, so at any moment the camera has several hundred to ~2,000 of these in frustum, **each one a
  draw call and a per-node cull**. That is where the 1,200–2,400 draw calls come from. MultiMesh exists
  to turn thousands of instances into ONE draw call; at 7.8 per node it is doing almost nothing.
- **40% of all MeshInstance triangles are Hueys.** `huey_v3.glb` accounts for **604,368 of 1,519,632
  tris** (24 hull meshes + 12 + 12 + 12 + 36 sub-meshes — twelve airframes' worth of geometry in the
  tree at boot, ~50k tris each), **with no visibility range**. A PS1 helicopter is 1–2k tris. The M101
  is 17,600 tris × 4. This is art budget, not engine.
- **93 AnimationPlayers on 98 skeletons are ticking at boot, before the 45-man assault lands** —
  garrison, squad, villagers. Nothing throttles an AnimationPlayer for a far or off-screen man (grep
  `model_actor.gd` for `_anim.active`, `process_mode`, `VisibleOnScreen`: nothing). Godot's own
  tracker puts the practical ceiling at **~100 animated characters at 60 fps, 3–4× more with the
  players disabled** (godot#74540), and a *playing* AnimationPlayer at ~1 ms (godot#101494). In the
  siege this game runs **~140**. That cost is engine-side and lands in the "UNATTRIBUTED" physics
  steps the ledger keeps reporting.
- **192 `_physics_process` scripts at 30 Hz.** Physics script span **mean 7–13.5 ms per step** in the
  siege (`[STALL]` rows) — 21–40% of the 33 ms step on GDScript alone, before Jolt, navigation,
  animation or rendering.
- **4,125 MeshInstances with no visibility range** — every one is culled per frame and drawn whenever
  in frustum, at full detail, from any distance. The firebase bake alone is 5,648 nodes.

---

## 3 · FOUR WAYS WE ARE USING GODOT WRONG — each with the doc or issue that says so

### 3.1 Forward+ on an integrated GPU — the one the decree forbids, stated anyway

Godot 4.7's own renderer page: Forward+ has the **"Highest base cost, and low scaling cost"**;
Compatibility **"Low base cost"**; and *"Choose Compatibility if: You are developing for older mobile
devices, or older desktop devices."* Forward+ pays for a depth prepass, clustered light binning and
compute passes on every frame whether the scene uses them or not — and **this scene uses none of
them**: 1 light, no shadows, no GI, no volumetric fog, 3 particle systems.

**What Compatibility would cost THIS game in features: effectively nothing.** No volumetric fog (not
used), 8 lights per mesh (there is one light), GPUParticles fall back to CPU (three systems).

**It has never been measured here** (memory, 9/08: *"Compatibility renderer has NEVER been
measured"*). Caleb decreed Forward+ on 2026-07-17 — *"make the game run smooth on Forward+"* — and
the decree stands until he lifts it. This audit does not lift it. It records that the single biggest
untested lever on the iGPU is one project setting, ten minutes on a copy of the project, and reversal
is the same setting. **His call, §5 Q1.**

### 3.2 Vulkan on Intel

`perf_stress_20260909_011104.log` boots `Vulkan 1.3.215 - Forward+ - Intel(R) UHD Graphics`.
Godot **made Direct3D 12 the default Windows driver in 4.6 specifically because Intel's Vulkan driver
is slow and poorly maintained** (godot-proposals#12234; measured on a Jasper Lake iGPU at **60+ fps
D3D12 vs 40 fps Vulkan**, godot#116919). This project has no `rendering_device/driver.windows` key
and is booting Vulkan. **One launch flag to test: `--rendering-driver d3d12`.** Caveat from the same
issue: some Intel parts glitch on D3D12 — which is exactly why it is a test, not a switch.

### 3.3 The vegetation bucket size

`BUCKET = 64.0` (`tree_cover_layer.gd:101`) with 27 species. The file's own comment (`:97`) names the
reason: `visibility_range` culls against a node's whole AABB (godot#79471), so small buckets cull
tighter. That is true, and the price is 3,631 nodes. The docs' rule is the other way: *"One MultiMesh
with 10,000 instances is one draw call."* **The honest lever is bigger buckets for the 12 canopy
species (a 256 m chunk = one node per species per chunk, ~300 nodes instead of ~1,700 for those
species) and keeping 64 m only for the 15 ground-cover species whose 150 m ring actually benefits
from tight culling.** Draw calls should roughly halve in the canopy; measure, do not assume.

### 3.4 Everything on the main thread, everything at once

No `WorkerThreadPool`, no `Thread`, anywhere. Every world rebuild is synchronous inside a frame:
`nav.collect 285.9 ms`, `terrain.crater 44.6–106.4 ms` (already down from 175 after the 9/09 crater
wave), `terrain.veg_generate 23–56 ms`, `treebreak.spawn 84 ms`, and **`spawn.man 119.5 ms` for ONE
soldier** (`spawn.hitzones 17.6` + `spawn.anim_library 11.8` inside it) — 45 reinforcements arriving is
~5 s of stall spread across the wave. The ledger's own line says it: *"the expensive things are
world-state rebuilds, not the pretty things."* Godot 4 lets mesh/collision/nav data be BUILT on a
worker and COMMITTED on the main thread; none of that is used. The PERF plan Phase 3/4 already names
this; it is unbuilt.

---

## 4 · WHAT COMPARABLE GAMES DO — and where we sit

| game | the lesson | us |
|---|---|---|
| **Arma Reforger** (Enfusion) | AI is THE CPU cost. Servers cap `aiLimit`; **AI and vehicles despawn beyond ~800 m if nobody is near**; cheaper model LODs render at distance. | Behavioural LOD built 9/09 (promote 80 m / demote 105 m), **never measured**. Nothing despawns. |
| **Arma 3** | Single-core bound; *"loading large amounts of units ... will bring performance to a halt."* Their forums are 12 years of "high specs, low fps". | Same shape, same bottleneck. Ours is worse per man (0.6 ms/tick) because it is GDScript with per-frame string lookups. |
| **Road to Vostok** (Godot 4, Forward+, dense forest) | Ships on discrete GPUs; its own fps guides say foliage density and contact shadows are the levers; **42→78 fps from settings**. | We are asking an iGPU to draw 27 species to 350 m. |
| Godot tracker, animation | ~100 animated characters at 60 fps; 3–4× with players off (#74540). | 93 at boot, ~140 in the siege, no throttle. |
| Godot docs, MultiMesh | thousands of instances → one draw call. | 7.8 instances per node. |
| Jolt / NavigationServer (community measurements) | ~800 `CharacterBody3D` before Jolt degrades; query `NavigationServer3D.map_get_path` directly and **stagger** path requests across frames. | 56 agents, path query every tick per near man (`enemy_base.gd:2034`). |

---

## 5 · THE PLAN — ranked by expected gain per hour, with what each needs from him

| # | change | expected | cost | needs |
|---|---|---|---|---|
| **Q1** | **Measure Compatibility** on a copy of the project, same walk, same seed | on an iGPU: possibly the largest single number in this file; on a discrete GPU: little | 10 min | **his ruling** — the 7/17 decree forbids it |
| **Q2** | **`--rendering-driver d3d12`** A/B, same walk | 0–50% on Intel per Godot's own numbers | 5 min | his window (one double-click) |
| 1 | **Canopy buckets 64 → 256 m** for the 12 canopy species | draw calls roughly halve in the treeline | 2–4 h | nothing; A/B in `--print-fps` |
| 2 | **Animation throttle**: far/off-screen men tick their `AnimationPlayer` at 10 Hz or pause; hitzone sync already gates on `_body_hot`, the skeleton does not | the biggest CPU term nobody has measured | 3–6 h | nothing; count with the census + `[STALL]` |
| 3 | **Soldier pool / pre-warm**: instantiate the assault's 45 men during the day, hide them, promote at siege | kills the 120 ms-per-man arrival hitch | 4–8 h | nothing |
| 4 | **Huey + M101 art budget**: 50k → ≤3k tris per airframe, visibility range on both | 40% of static triangles | ART, 1–2 days | his art |
| 5 | **Worker-thread the rebuilds**: nav collect, chunk mesh, veg scatter built off-thread, committed on-thread | removes the 50–290 ms hitches on every machine | 2–3 days | nothing, but it is the risky one |
| 6 | Cache `get_node_or_null("Burning")`, stop `look_at()`/`set_facing` when unchanged, path query at think rate not tick rate | shaves the 0.6 ms/man | 2–4 h | nothing |

**What this audit did NOT do, on purpose:** open a window, run a bench on a quiet scene, or propose
any of the three cuts he has already refused (single-sided foliage, unshaded grass, cutting bushes).

---

## 6 · TWO INSTRUMENT NOTES

- **`bodies 0 pairs 0 islands 0` on every `[FPS]` row** is Jolt not populating Godot's physics
  monitors, not an empty physics world. Do not read it as "physics is free".
- **`scaling_3d/mode=5` is `SCALING_3D_MODE_NEAREST`** (4.7 class ref) — the cheapest upscale, and the
  crisp-pixel look the PSX pass wants. It is correct. `fsr_sharpness=0.3` beneath it does nothing.
