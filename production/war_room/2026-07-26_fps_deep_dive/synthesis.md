# THE DECREE — Whole-Game FPS Deep Dive
**Council:** 2026-07-26 · **Arbiter:** recon-overseer (Director) · **Summoner query:** *"deep dive overall in the game how to increase the fps"*
**Architects:** technical-director · godot-specialist · technical-artist · gameplay-programmer · devil's-advocate · measurement-engineer
**Full analyses:** `production/war_room/2026-07-26_fps_deep_dive/analysis/`

> **NO NEW FPS ROW IS WRITTEN BY THIS SESSION.** Every FPS figure below is either quoted from an
> existing measured `PERF_LEDGER.md` row or explicitly labelled INFERRED / GUESSED. Nothing here was
> measured windowed by an agent, because agents cannot measure windowed. `PERF_LEDGER.md` gains
> pointer corrections only.

---

## 0. THE HEADLINE

**The frame has never been measured properly, and the one number everybody has been optimising against
is the most flattering pose in the game.**

Two findings, each from a different architect by a different route, converge on this:

- **`tests/perf_probe.gd` — the only harness ever run against the shipped world — reports no
  milliseconds at all.** It reads three counters (`:110`, `:112`, `:114`) and never calls
  `viewport_set_measure_render_time`. **The CPU-vs-GPU split has never been measured at `fsb_main`,
  ever.** The 44.35ms / 51.94ms pair everyone cites (`PERF_LEDGER.md:200-201`) is the *night stress
  arena at native scale* — a different scene, population and pixel count. **It does not transfer.**
  *(technical-director)*
- **Every FPS row in the ledger is a stationary camera standing inside a cleared firebase.** The
  ledger's own census proves how flattering that is: **exactly 1 near-solid canopy node in range**
  (`PERF_LEDGER.md:912-914`), because there is no jungle where he is standing.
  `tree_cover_layer.gd:38-40` records **919 solid-mesh candidates** in the 70m ring out in the jungle.
  **The frame composition inverts when he walks out the wire, and that has never been measured.**
  *(devil's-advocate, corroborated by measurement-engineer)*

**Therefore the first action of this polish pass is not a lever. It is fixing the ruler.**
Adding ms reporting costs 0 FPS and unblocks every ranked decision below. The devil's advocate puts it
plainly and the Arbiter adopts it: *lowering the detectability floor is worth more than any single lever
on this list.*

**The detectability floor, stated:** ship-parity A/B/A noise floors of **1.1 / 1.4 / 2.8 FPS** — and you
cannot know in advance which you drew. **≈3 FPS ≈ 2.4ms at the 34 FPS baseline is the honest floor.**
Any lever whose expected win is below that is *unfalsifiable on this hardware* and **must not be shipped
on faith.**

---

## 1. THE CENSUS (Summoner deliverable #1)

### 1a. What the council COULD establish — static, from glTF JSON and code, not estimated

| Subsystem | Static count | Pointer |
|---|---|---|
| **`fsb_main.glb`** (the hub, placed **once**, at the exact 34-FPS pose) | **681 nodes · 202 meshes · 204 surfaces · 94 materials · 9 textures.** 94 materials collapse to **48 distinct signatures — 46 are exact duplicates** (`Crate_Post_Wood_*`×20, `OliveDrab.00N`×8, `BarbedWireMetal.00N`×7) | `site_planner.gd:644` |
| **Canopy far-cards** | **27 species live, NOT 40.** `TYPE_SPECIES` unions to exactly 27; the other 13 cards on disk are never scattered. ~957–1,017 draw calls | `vegetation_manager.gd:48-55` |
| **Village set** | 26 files · 251 surfaces · **159 materials but only 17 distinct names** — palettes duplicated per-GLB (26 copies of one `jungle_palette`) | `tools/gen_village.py` |
| **Temple set** | 29 files · 272 surfaces · 205 materials · 30 distinct (28 copies of one `temple_laterite`) | `tools/gen_temples.py` |
| **US grunt** | **COUNT DISPUTED — see below.** ~25 US bodies resident at spawn (17 garrison + 8 allies) | `site_planner.gd:681-695`, `civilian.gd:103-106` |
| **VC model** | 3 nodes / 13 calls · **civilians** 1–3 | — |
| **Water** | already one mesh, one material — **not a target** | `water_system.gd:62` |

**An honest disagreement the Arbiter does NOT paper over:** technical-director counted a US grunt at
**36 nodes / 44 draw calls / 6,070 tris**; technical-artist counted **51–61 MeshInstance3D / 71–81
surfaces / 20–26 materials**. Both read real assets. The gap is probably variant/dresser state
(`grunt_dresser.gd`) or pre- vs post-cull counting. **This is an open count, resolved by census phase
F3, not by picking the number I prefer.**

### 1b. What the council could NOT establish without a windowed run — SAID SO, not estimated

The CPU/GPU split at the hub · how many of the ~25 bodies are actually in frustum · `fsb_main.glb`'s
*culled* surface count · the understory-vs-canopy split of the far ring · whether calls→FPS is linear ·
**and any pose other than the spawn — no jungle sightline has ever been measured.**

**These are exactly the questions the measurement batch (§5) answers.** The unattributed **~355–464
non-canopy calls** (`PERF_LEDGER.md:896-898`) now have two credible owners nobody had checked: the
**~25 resident character bodies** and **`fsb_main.glb`'s 204 surfaces**.

---

## 2. THE ATLAS QUESTION, SETTLED (Summoner deliverable #2)

### 2a. Canopy 27-card atlas — **VIABLE, CHEAPER THAN FEARED, AND GATED BEHIND ONE MEASUREMENT**

The godot-specialist materially improved the costing and **the ledger's stated blocker was mis-scoped**:

- You do **not** need an atlas packer. You need a **`Texture2DArray` + MultiMesh `INSTANCE_CUSTOM.x` =
  layer index**. The 27 PNGs already exist.
- Each card's aspect is readable from `_extract_mesh`'s own AABB (`tree_cover_layer.gd:323`) — already
  dumped by `tools/diag_veg_cards.gd:19`.
- The shader exists: `terrain/shaders/vegetation_sway.gdshader` already has `ALPHA_SCISSOR_THRESHOLD`
  and `IN_SHADOW_PASS`. **~15 lines.**
- **Real cost ≈ 2.5 days.** Win ≈ **5.3×, not 10×** (~188 calls, not ~94 — trees export a crossed
  8v/12i quad, grass/vine a single 4v/6i, so **two** unit meshes are required).
- **Engine truth that kills a common misconception:** a shared material collapses **nothing**. Godot
  never batches 3D draws across `GeometryInstance3D` nodes. The win comes from merging the *instance
  arrays*, not from sharing a material.

**The devil's advocate lands the decisive blow, and the Arbiter upholds it:** the measured **+8.0 FPS is
the cost of the WHOLE canopy — draw calls PLUS card fill PLUS 12% of primitives. The atlas recovers only
the CALL fraction, and that fraction has never been measured.** If calls are 25% of that win, you build
a whole new far-card renderer path for **~1.8 FPS — below the detectability floor — and you cannot prove
it worked.**

> **RULING: the atlas is NOT killed and NOT approved. It is GATED behind Batch item 4**, which reads the
> call-vs-fill split directly. **< floor → the atlas is dead. > +4 FPS → build it with a number in hand.**
> One 3-minute experiment either saves a week or earns it.

### 2b. Firebase 9→5 material collapse — **DEAD. Not "unproven" — FALSE.**

**Four architects killed this independently, by four different routes.** The Summoner asked that it not
stand on assertion alone; it does not survive contact with the assets at all:

- **The 23 nine-slot assets do not exist as Godot assets.** The folder holds `fsb_main.glb` + 4 kit
  GLBs carrying **1, 1, 1, 5 surfaces (mean 2.0)** — never 9. *(technical-artist, technical-director)*
- **Unused Blender material slots do not export.** `gen_firebase.py` is Blender-side only, and its
  `MATS` list is now 10 entries, not 9. *(technical-director)*
- **The 7 `fb_*` textures are referenced by nothing** — zero overlap with `fsb_main`'s 9 images, and
  none of the 4 kit GLBs loads at runtime. The source doc concedes this at its own `:268`.
  *(godot-specialist)*
- Even granting the premise, it is bounded from the ledger's own numbers at **~0.35–0.7 FPS** — the
  entire non-canopy frame is only 411–464 calls. **Unfalsifiable.** *(devil's-advocate)*

> **RULING: strike the claim at `firebase_kit_phase1_read.md:261-263`.** 9→5 removes **zero** draw calls
> today. The *real* `fsb_main` defect is different and is ranked in §3: **46 duplicate materials and 20
> alpha-BLEND surfaces at the exact pose every baseline is measured from.** And per
> `PERF_LEDGER.md:98-100` (77 calls → ~0 FPS), material de-duplication must be sold as **hygiene, not
> FPS**.

---

## 3. THE RANKED PLAN

**Binding order: look-free levers rank above look-costing ones even when smaller. RULE #1 outranks every
FPS number.**

### TIER 0 — FIX THE RULER (do first; 0 FPS, unblocks everything)

| # | Action | Cost | Why |
|---|---|---|---|
| 0.1 | **Add ms reporting to `tests/perf_probe.gd`** — copy `arena_perf_overlay.gd:100,136-142`. CPU ms, GPU ms via `viewport_get_measured_render_time_gpu` | ~1h | The CPU/GPU split at the hub is **unmeasured**. Lowers the detectability floor below 3 FPS |
| 0.2 | **Extend `perf_probe.gd` with the subsystem census phases** (~60–80 lines, 0 new files) | ~1h | Produces the real §1b census. Extending inherits A/B/A, noise floor, ship capture, and auto-enrollment in `test_ship_parity.gd:15-21` |
| 0.3 | **Restore `renderer/rendering_method="forward_plus"` to `project.godot`** | 1 line | The key is **gone again** (only the `.mobile` override survives). `perf_probe.gd:208` now prints a fallback string instead of a read value — **every future row violates the measurement contract** |
| 0.4 | **Drop the 2 dead cycle phases** (campfires, shadow) — both measure nothing at seed 47225 and both self-warn | trivial | 14 wasted seconds + 2 wasted phase slots every run since 07-20 |

### TIER 1 — LOOK-FREE BUGS. These are defects, not tradeoffs. Ship them.

| # | Lever | Win | Evidence class | Pointer |
|---|---|---|---|---|
| 1.1 | **The canteen regex bug** — `\.(\d+)$` matches the retired `us_grunt_v3` naming; all six shipping grunts use `canteen_l_002…_006` (**underscores**). **Every grunt renders 5 stacked canteens.** | **−4 calls/body × ~25 bodies ≈ −100 calls** | **MEASURED** (static, definitive) | `model_actor.gd:407` |
| 1.2 | **The WA-A2 hitzone gate LEAKS.** `sync()` runs on two paths; `hitzone_builder.gd:164-166` connects an **ungated** closure to `skeleton_updated`. The shipped gate only closes the physics-tick path (`enemy_base.gd:463`) | ~0.3ms | INFERRED | `hitzone_builder.gd:164-166` |
| 1.3 | **11 matrix inversions where 1 would do** — `hitzone_builder.gd:225` writes `hz.global_transform`, forcing a parent `affine_inverse()` **per zone** | ~0.5–1.0ms | INFERRED | `hitzone_builder.gd:225` |
| 1.4 | **`monitoring = true` on hitzones with nothing consuming overlaps** — all damage is raycast. Keep `monitorable` (load-bearing for `projectile_base.gd:279`) | small, free | INFERRED | `hitzone.gd:38` |
| 1.5 | **`create_shadow_meshes=true` on 362/362 imports while shadows are OFF** | import/VRAM only | MEASURED (settings) | `game_world.gd:52` |
| 1.6 | **Merge US gear by material** — 44 → ~18 surfaces is **pixel-identical**. The gib contract (`gib_system.gd:22-52`) does not list webbing/ruck/canteens, so they are free to merge | **−26 calls/body** | MEASURED (counts) | — |
| 1.7 | **VRAM-compress the 413/838 LOSSLESS textures.** 19 copies of one **3600×5700** character map, **18 byte-identical**, 78.3 MB RGBA8 each. Cards alone are 121.5 MB uncompressed | 4× VRAM cut | MEASURED (settings) | `compress/mode=2` |

> **1.7 is also the atlas de-risking experiment** (godot-specialist): VRAM compression changes **zero
> calls and zero prims — only bytes.** If FPS moves, the canopy is **bandwidth-bound** and the atlas is
> over-sold. If it does not, **call-bound is proven.** Run it before spending 2.5 days.

### TIER 2 — CHEAP, BIG, BUT NEEDS HIS EYES (look-check required, not look-cost assumed)

| # | Lever | Win | The look question |
|---|---|---|---|
| 2.1 | **All 40 canopy cards are alpha-BLEND + doubleSided; zero MASK.** ~1,000 cards with **no depth write, no early-Z, plus CPU sorting.** Violates **ADR-026:30** ("alpha-scissor jungle") and **:63** (back-face cull). Precedent already in-repo: `ground_clutter.gd:103-105`. **~15 lines, under an hour** | Attacks **OVERDRAW — which the atlas cannot touch** | Hard cutout edges vs soft. **His eyes decide.** |
| 2.2 | **`doubleSided: true` on 100% of assets** (94/94 fsb_main, 159/159 village, 205/205 temple, all characters) — backface culling **off on closed bunkers, crates and soldiers** | Biggest look-free fill lever | Look-free on **closed** geometry; needs a pass to spot genuine two-sided pieces |
| 2.3 | **20 alpha-BLEND materials in `fsb_main`** — 19 identical `Sandbags*` on a 64×64 texture, in the transparent pass, **filling the screen at the measured pose** | — | Same cutout question as 2.1 |

**Two independent architects found 2.1 by different routes** (technical-artist and godot-specialist,
both by reading the glTF JSON of all 40 card GLBs). *When they converge from different doors, it is the
strongest signal this process produces.* It is also a **live violation of ratified law**, which makes it
a correction rather than an optimisation.

### TIER 3 — GATED ON MEASUREMENT (do not build before the batch)

| # | Lever | Gate |
|---|---|---|
| 3.1 | **The canopy card atlas** (`Texture2DArray`, ~2.5 days, ~5.3×) | Batch item 4 must show the call fraction > +4 FPS |
| 3.2 | **Physics `60 → 30 Hz`.** `physics_interpolation=true` is **already ON and unexploited** (`project.godot:300`). The CPU wall is per-tick body cost | **SUMMONER CALL — costs player feel.** Gate on ballistics: `ballistics.gd:37` derives `dt` from tick rate |
| 3.3 | **De-phase the AI body to 30Hz** — ~18–19ms of the 39.8ms W0 wall | INFERRED from measured; needs the ms ruler first |
| 3.4 | **Animation LOD** — **there is no animation LOD anywhere in the project.** Largest single unmeasured CPU item | **GUESSED.** Measure before scheduling |
| 3.5 | **Per-species far-card distance** — one 350m ring serves all 27 species (`tree_cover_layer.gd:46`); **15 are understory** (rice/fern/bush/grass/vine) | ~500 calls, **+2.6–3.4 FPS INFERRED** (extrapolated, assumes linearity). **COSTS LOOK in grassland/paddy** |

---

## 4. WHAT IS NOT WORTH DOING — with the evidence, so this stops being re-litigated

| Killed | The evidence |
|---|---|
| **Sun shadows** | Ship runs `shadow_enabled = false` (`game_world.gd:52`). The +10.9/+10.5/+9.8 "wins" were a **bench artifact measured and believed twice in two harnesses**, retracted (`PERF_LEDGER.md:393, :626, :653`). At ship parity: **−0.2, inside noise.** Guarded by `tests/test_ship_parity.tscn` |
| **Campfires / ADR-026 Part A #1** | **0.0 at seed 47225** (DAY, zero campfires); unmeasurable even at seed 12 night with 4 fires (`:846-861`). A **CANON win, not a perf win** |
| **Clutter / grass** | Inside noise every time |
| **Firebase 9→5 material collapse** | §2b — the assets don't exist; bounded at 0.35–0.7 FPS even if they did |
| **Triangle-shaving** | The canopy's ~1,000 calls carry **~3,000 triangles total** (40 cards × ~3 tris). **Arithmetically dead.** Measured elsewhere: 33% prim cut + 77 calls → ~0 FPS |
| **Renderer swap** | Forward+ **DECREED**, ADR-026 Amendment A. Closed |
| **FSR / FSR2** | Adds cost and **ghosts foliage**. `mode=5` (4.7 nearest) is already the right choice for PSX |
| **Occlusion culling** | CPU-side cost, and **alpha cards cannot occlude** |
| **Glow / SSAO / SSR / GI / volumetric fog** | **All already off.** That box is empty |
| **`BUCKET 64→128` AS A SHIP CHANGE** | See §6. **Trap.** Ship never; instrument only |

---

## 5. THE MEASUREMENT BATCH (Summoner deliverable #6)

**~18 min machine time, ~35 min wall clock.** Console exe, `--test-save` on every item. A/B/A bracketed.
**Requires TIER 0.1–0.3 first** — items 1, 2 and 6 need the census patch; 3, 4, 5 run today.

| # | Question it answers | Command | Time |
|---|---|---|---|
| **1** | **THE CENSUS** — where do the ~1,400 calls live by subsystem? | `-- --perf-probe --perf-cycle --test-save`, ×2. Phases: `baseline → no_canopy_far → b2 → no_structures → b3 → no_characters → b4 → no_water → b5` | 4.6 min |
| **2** | **IS IT FILL-BOUND?** Scale ladder in one boot — can invalidate half the GPU plan, may hand back sharpness free | `0.75 / 0.60 / 0.75 / 0.85 / 0.75`, 40s | 1.8 min |
| **3** | Does the far ring pay? **Zero code** — the only free flag on the only measured lever | `-- --card-dist=250`, **A/B/A across 3 boots** (`view_distance` is baked at construction, `tree_cover_layer.gd:135`) | 3.6 min |
| **4** | **THE ATLAS GATE — call-vs-fill split.** Moves calls **without moving fill**, so it reads the split directly and errs conservative | `BUCKET` 64→128, **1 line**, `tree_cover_layer.gd:52` | 1.2 min + eyes |
| **5** | **THE WALK.** Every ledger row is a stationary camera. **RULE #1 is about walking.** `[PERF] FPS=` already prints every 2s | Walk out the wire into jungle. **Zero code** | 4 min |
| **6** | A second pose — is the spawn representative? **Zero code** | `-- --spawn-at-village` | 2.2 min |

**If time is short, the cut line is 1, 2 and 5.** Item 5 costs nothing and attacks the single largest
blind spot in the entire ledger.

**Free command-line levers found (no code needed):** `--card-dist=N` (`tree_cover_layer.gd:77-80`) ·
`--perf-seed=N` (`game_flow.gd:202`) · `--spawn-at-village` (`:288`) ·
`--perf-probe / --perf-cycle / --shadow-study` (`:352-358`) · `--test-save` (`campaign_state.gd:130`) ·
arena-only: `--fill_chance= / --view_distance=` (`ai_stress_arena.gd:471`) and
`--scale= / --mode= / --no-lights / --no-shadows / --seconds= / --warmup= / --label= / --shot=`
(`ps2_perf_probe.gd:147-187`).

### The protocol rule, baked in — why the old harness lied

The instrument **wrote the property it measured in every phase**
(`sun.shadow_enabled = phase_name != "no_sun_shadow"`). **A/B/A measures precision, not accuracy — a
uniformly-wrong baseline is uniformly wrong.** And the tell was on screen the whole time: **the
primitive column contradicted the FPS column for three runs and nobody read them together.**

> **THE RULE, now binding on every future bench: no FPS delta is accepted unless the draw-call/primitive
> delta has the right SIGN and a plausible MAGNITUDE.** Plus: capture-and-restore ship state (never a
> phase-name expression), a `hidden=N` census with a zero-warning, and `.visible` toggles only — **never
> `queue_free`.**

---

## 6. WHAT THIS DECREE SACRIFICES (the law binds the Arbiter too)

- **We are not building the atlas this session.** If the batch proves it, we lose ~3 days of latency.
  The Arbiter accepts that: a one-way door on the **protected world foundation**, in the one place
  RULE #1 is sacred, sized on an **unmeasured fraction of a one-pose ceiling**, is not a bet to take
  blind — especially during his declared FP-arms priority window with **PLAYTEST R4 unresolved**.
- **We spend ~2 hours on instrumentation that ships no FPS.** Named as a cost. It is the price of not
  paying for the shadow retraction a third time.
- **`BUCKET=128` is used as an instrument and then thrown away.** We learn the split and deliberately
  decline the 2.5× call cut, because `tree_cover_layer.gd:48-52` documents ±90m quantisation against a
  65m handoff — **a jungle hole (the historical invisible-jungle bug) or double-rendered cards.** There
  is no escape hatch: `:315-318` disables fade deliberately. **RULE #1 outranks the win.**
- **Tier 2 stalls on his eyes.** The overdraw fix is the best cheap lever on the board and an agent
  cannot approve it, because it changes how the jungle *looks*.

## 7. THE LANDMINE (undocumented, filed here so it is not stepped on)

**13 card GLBs sit on disk that are never scattered** (40 on disk, 27 live —
`vegetation_manager.gd:48-55`). **Wiring them in would raise canopy draw calls by ~48%** — undoing more
than `BUCKET=128` would ever save. Anyone adding foliage variety must know this. Related: **the card
bake tool is still absent from the repo** (verified across 97 tools; commit `ad25457f` touched zero
files in `tools/`), so **the 40 cards are currently unreproducible in-tree.**

## 8. NO-DRIFT CORRECTIONS (found and fixed this session)

| Claim | Truth | Status |
|---|---|---|
| `PERF_LEDGER.md:21-23` — renderer "explicitly `forward_plus` in `project.godot:300`" | **Key absent entirely**; only `.mobile` override survives (`project.godot:305`) | ✅ corrected in ledger |
| `PERF_LEDGER.md:909-911` — `tree_cover_layer.gd:94/:47/:115/:118/:199` | **`:110/:52/:132/:135/:323`** | ✅ corrected in ledger |
| `PERF_LEDGER.md:922` — comment at `tree_cover_layer.gd:43-46` | **`:48-51`** | ✅ corrected in ledger |
| `PERF_LEDGER.md:889` — scale at `project.godot:304`, renderer `:299` | **`:308`**; renderer pointer dead | ✅ corrected in ledger |
| `game_world.gd:48` shadow pointer (3 places) | **`:52`** (`:48` is `DirectionalLight3D.new()`) | ✅ corrected |
| **`ADR-026:121-123` still calls the +8.6 FPS light win "#1"** | **Refuted at `PERF_LEDGER.md:611, :855`** | ⚠️ **LIVE DRIFT IN RATIFIED LAW — must be amended** |
| `firebase_kit_phase1_read.md:261-263` — 9→5 is "the real performance lever" | **False** (§2b) | ⚠️ **must be struck** |
| `ADR-026:164` — "80m foliage landed" | Describes `jungle_patch_layer`, which **does not ship** (`world_config.gd:21`); live card ring is **350m** | ⚠️ to amend |
| `vegetation_manager.gd:34-38` — TREE_COVER "unwired" | **It is live** | ⚠️ to amend |
| The briefing's own DORMANT/AGGREGATE ask | **ADR-025 is SUPERSEDED at its own line 3**; `world_sim.gd` is now 34 lines, a flat registry. **Budget nothing against it** | ✅ noted; my briefing was wrong |
| `world_config`'s FPS-fallback ladder called a fossil | **It is LIVE** (`vegetation_manager.gd:292`) | ✅ noted |

## 9. FOR THE SUMMONER — the two calls only he can make

1. **The alpha-scissor look-check (Tier 2.1).** Best cheap lever on the board; ~15 lines; fixes a live
   ADR-026 violation. **It changes how jungle edges read — hard cutout instead of soft blend.** Your
   eyes, not a counter. *Deliverable is a screenshot pair, not an FPS number.*
2. **Physics 60 → 30 Hz (Tier 3.2).** One line; `physics_interpolation` is already on and unexploited;
   plausibly the largest single CPU lever. **It costs player feel and no agent may judge that.**
