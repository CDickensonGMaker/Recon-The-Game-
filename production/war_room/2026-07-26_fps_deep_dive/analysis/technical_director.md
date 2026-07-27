# TECHNICAL DIRECTOR — where the frame actually goes

**Session:** 2026-07-26 whole-game FPS deep dive · **Lens:** frame budget ownership, CPU-vs-GPU split.

**Method statement, said first because it governs everything below.** I ran **no windowed Godot**, quoted
**no headless GPU figure**, and ran **no test suite**. Everything labelled MEASURED below is either (a) a
row already in `PERF_LEDGER.md` from a sanctioned windowed run, or (b) a **static asset/code count** I
took myself by parsing GLB glTF-JSON chunks and reading source. Static counts are exact and reproducible;
they are counts of *what is submitted*, never of *milliseconds*. Anything converting a count into an
expected FPS delta is labelled **INFERRED** and shows its arithmetic. Nothing here is presented as a
measurement that is not one.

---

## 0. THE HEADLINE, BEFORE THE DETAIL

Four things, in order of how badly they change the picture:

1. **The CPU-vs-GPU split has NEVER been measured at `fsb_main`. Not once, in any harness.** The
   44.35ms/51.94ms pair the briefing cites is the *night arena at native*, a different scene. See §2.
2. **Characters are the missing subsystem in every prior attribution, and they are a draw-call bomb.**
   A US grunt renders as **36 MeshInstance3D nodes / 44 draw calls** for 6,070 triangles. The VC and
   civilian models are built correctly (3 nodes / 9–13 calls). ~25 US bodies are resident at the hub
   spawn. See §1.3.
3. **A live bug renders five stacked canteens on every US grunt** — `model_actor.gd:407` matches a
   dot-suffix that no shipping export uses. See §3, lever 1.
4. **The firebase 9→5 material claim is FALSE as stated, and I can kill it statically.** Unused Blender
   material slots do not export. See §4.

---

## 1. THE CENSUS — attributed by subsystem

### 1.1 What is MEASURED and still stands (from the ledger, unchanged by my work)

| fact | value | source |
|---|---|---|
| shipped baseline, seed 47225, scale 0.75, forward_plus, Intel UHD, stationary at fsb_main spawn | **~34 FPS** | `PERF_LEDGER.md:679, :698` |
| total draw calls in that frame | **1,346 – 1,481** | `PERF_LEDGER.md:679-687, :896` |
| draw calls with the canopy hidden | **355 – 464** | `PERF_LEDGER.md:682, :897` |
| ⇒ draw calls FROM the canopy | **~957 – 1,017** | `PERF_LEDGER.md:898` |
| ⇒ **draw calls from EVERYTHING ELSE** | **~355 – 464** | derived from the two rows above |
| canopy lever, three seeds/configs | **+6.3 / +7.8 / +8.0** vs floors 1.4 / 1.1 / 2.8 | `PERF_LEDGER.md:875-878` |
| sun shadow at ship parity | **−0.2, inside noise** (it is already OFF) | `PERF_LEDGER.md:696`; `game_world.gd:52` |
| campfires at seed 47225 | **0.0** (zero campfires exist; seed rolls DAY) | `PERF_LEDGER.md:846-857` |
| clutter | inside noise every time | `PERF_LEDGER.md:825, :843` |

**The whole unexplained block is that `~355–464` non-canopy call budget.** No pass has ever attributed
it. That is the hole this analysis fills.

### 1.2 STATIC ASSET CENSUS — my own counts, exact, taken by parsing glTF JSON chunks

Surfaces = glTF mesh primitives = **one draw call each** when the instance is visible and in frustum.
Godot does not merge surfaces on import and does not batch skinned meshes.

| asset family | GLBs | surfaces total | surfaces/asset (mean / max) | tris total |
|---|---:|---:|---:|---:|
| **`fsb_main.glb`** (the whole firebase, one placed scene) | 1 | **204** (202 mesh nodes, **94 materials**) | 204 | 20,554 |
| **US characters** | 9 | 583 | 64.8 / 81 | 39,520 |
| VC characters | 5 | 284 | 56.8 / 59 | 16,627 |
| civilians | 10 | 384 | 38.4 / 39 | 13,176 |
| temple set | 29 | 272 | 9.4 / 22 | 61,125 |
| village set | 26 | 251 | 9.7 / 16 | 32,865 |
| ruins | 22 | 69 | 3.1 / 6 | 15,296 |
| vc_nva props | 7 | 136 | 19.4 / **62** (`tunnel_entrance_hidden.glb`, 62 mats) | 6,384 |
| infrastructure | 4 | 56 | 14.0 / **53** (`us_army_bridge.glb`) | 25,976 |
| converted | 9 | 65 | 7.2 / **55** (`helipad.glb`, **55 materials**) | 21,021 |
| firebase kit | 4 | 8 | 2.0 / 5 | 1,381 |
| **veg cards** | 40 | 40 | **1.0 / 1** | 122 (≈3 tris each) |
| veg solids | 47 | 53 | 1.1 / 2 | 12,371 |

Two readings jump out immediately:

- **The cards are already perfect geometry and cannot be improved by geometry work.** 40 cards, 1 surface
  each, ~3 triangles each. The canopy's ~1,000 draw calls carry roughly **3,000 triangles total.** This is
  the purest possible confirmation of the standing law that *tri budgets are style, not perf*: the canopy
  is 70–85% of the frame's draw calls and ~2% of its triangles. Any proposal to simplify card geometry is
  arithmetic nonsense — there is nothing left to remove.
- **The heavy surface counts are on things nobody has ever profiled**: the firebase monolith, the US
  characters, and a handful of props with absurd material counts (`helipad.glb` 55 materials for 9,572
  tris; `tunnel_entrance_hidden.glb` 62 materials for 1,688 tris).

### 1.3 THE US CHARACTER PROBLEM — the biggest thing prior passes missed

`model_actor.gd:478-481` hides gib donors, `cap_*` meshes and the two gib-gear helmets at spawn. I applied
that exact rule statically to every character GLB and counted what is left **visible**:

| model | total surfaces | **VISIBLE after donor-hide** | visible mesh NODES |
|---|---:|---:|---:|
| `us_grunt_marksman.glb` | 81 | **47** | 36 |
| `us_grunt_rifleman.glb` | 78 | **44** | 36 |
| `us_grunt_rto.glb` | 72 | **38** | 29 |
| `us_grunt_mg.glb` | 71 | **37** | 26 |
| `us_grunt_pointman.glb` | 71 | **37** | 26 |
| `us_grunt_grenadier.glb` | 68 | **34** | 26 |
| `us_grunt_v3.glb` | 62 | **28** | 19 |
| `vc_guerilla.glb` | 59 | **13** | **3** |
| `vc_guerilla_mosin.glb` | 55 | **9** | **3** |
| `civ_farmer_m.glb` | 38 | **4** | **2** |
| `civ_kid.glb` | 37 | **3** | **1** |

**The VC and the civilians are built right. The US grunts are not.** A rifleman's 36 visible nodes are:

```
m16_world 5 · helmet_shell_worn 4 · us_grunt_joined 2 · Base_Human 1
ruck_body/flap/frame_bar/frame_l/frame_r/buckle_l/buckle_r/pocket_0/pocket_1/pocket_2   (10 × 1)
web_back_yoke/bandolier/belt/buckle/clip_b_l/clip_b_r/clip_f_l/clip_f_r/flap_l/flap_r/
  pouch_l/pouch_r/snap_l/snap_r/susp_l/susp_r                                            (16 × 1)
canteen_l_002/003/004/005/006  (5 × 1)   pouch_belt_worn 1
```

The **body** is correctly joined (`us_grunt_joined`, 2 surfaces). Everything expensive is **gear that was
never merged**: 16 webbing straps, 10 ruck pieces and 5 canteens, each its own skinned MeshInstance3D
with its own draw call. The materials confirm the cause — `us_grunt_rifleman.glb` declares 23 materials,
**six of which are `us_grunt_mat`, `us_grunt_mat.001` … `us_grunt_mat.005`** — duplicate resources of the
same material, which defeats any batching the renderer might otherwise attempt.

**Resident US bodies at the hub spawn pose (MEASURED from code):**

- **17 garrison men inside the wire** — `site_planner.gd:681-695` (`FSB_GARRISON_POSTS`, men column sums
  to 17), spawned by `mission_generator.gd:764` using `CivilianScript.GARRISON_MEN`, which is
  `civilian.gd:103-106` — **the `us_grunt_*` models**, not the cheap civilian models.
- **8 allies** in the player's squad (`PERF_LEDGER.md:364`: "13 live (5 enemies, 8 allies)" at hub start).

**≈25 US bodies × ~40 visible surfaces ≈ 1,000 submitted draw calls before frustum culling.**

**INFERRED (arithmetic, not measured):** the measured non-canopy budget is ~355–464 calls. If ~9–11 of
those 25 men are in frustum at the default spawn view — which faces the base interior, i.e. *directly at
the garrison* — characters alone account for essentially **the entire non-canopy draw-call budget**. That
fits suspiciously well, but **which men are in frustum is exactly what I cannot settle without a windowed
run.** I put it in the measurement batch rather than assert it.

### 1.4 THE CANOPY — mechanism re-verified, and one thing the ledger got wrong

The ledger's canopy diagnosis (`PERF_LEDGER.md:901-928`) is **still correct**, but every line pointer in
it has drifted. Corrected pointers:

| ledger says | actual today |
|---|---|
| `tree_cover_layer.gd:47` `BUCKET = 64.0` | **`:52`** |
| `tree_cover_layer.gd:94` group key | **`:110`** |
| `:115` / `:118` two nodes per group | **`:132` / `:135`** |
| `:43-46` the `visibility_range` AABB comment | **`:49-51`** |
| `game_world.gd:48` `shadow_enabled = false` | **`:52`** |

Mechanism confirmed at the corrected lines: `tree_cover_layer.gd:110` keys groups as
`[name, floor(x/BUCKET), floor(z/BUCKET)]`; `:132` emits the near solid (`0..near_distance`), `:135` emits
the far card (`near_distance..view_distance`) for any species that has a card. `near_distance = 65.0`
(`:45`), `view_distance = 350.0` (`:46`), `BUCKET = 64.0` (`:52`). MultiMesh is used correctly (`:299-319`)
and there is no per-plant MeshInstance3D. **The call count is the node count. That still stands.**

**What the ledger has WRONG (NO DRIFT — reporting it):**

`PERF_LEDGER.md:928-936` says the atlas lever means "**collapse the 27 card materials**" and calls the
27-species pool the ceiling. The **27 is right for what is scattered** — I enumerated `TYPE_SPECIES`
(`vegetation_manager.gd:48-55`) through `_all_species()` (`vegetation_manager.gd:128-133`) and it unions
to exactly **27 unique species**. But `:932` says "The 27 card textures are NOT atlased … verified by
probe" while **there are 40 card GLBs and 40 card PNGs on disk today**
(`assets/world/vegetation/cards/`). **13 of them are never scattered by any pool** and are pure dead
weight: `elephant_grass_c, grass_fan, grass_tuft_a/b/c, jungle_palm_a3, jungle_palm_b3, liana_b,
palm_sapling_b, tall_grass_c, trunk_vine_a, trunk_vine_b, vine_b`. (20 solid GLBs are likewise never
scattered.) They cost zero FPS — `load_species()` (`tree_cover_layer.gd:85`) is only ever called with the
27 — but the ledger's "27 cards" reads as a complete inventory and is not one.

**The atlas blocker is UNCHANGED and I verified it rather than assuming it.** The card bake tool is
**still not in the repo**. `git show --stat ad25457f` (the 2026-07-17 commit that added every card)
touched **zero files under `tools/`**. `tools/make_jungle_flora.py` bakes the **solid** meshes and already
gives them a shared palette atlas (`:69-88`, material `jungle_atlas`) — but it does not produce cards.
Nothing in `tools/` writes `*_card.glb`. **The briefing's question "is the card bake tool NOW in the
repo?" is answered: NO, and it was never added — the cards were committed as binaries on 2026-07-17,
nine days ago, not in the last six.**

**The new finding on the canopy — and it does not need the atlas.** `tree_cover_layer.gd:46` gives
**every species one shared `view_distance = 350.0`**, and `:135` emits a far card for **every one of the
27 scattered species that has a card — which is all 27** (I checked the intersection; the "NO card" set is
empty). That means **rice, three ferns, three bushes, four grasses, a palm sapling, a liana and a vine —
15 of the 27, 56% of the pool — are drawing impostor cards out to 350 metres.** Understory that is
sub-pixel at 150m is paying full far-ring node cost at 350m. Nobody has ever proposed tiering this. See
§3 lever 4.

### 1.5 What I could NOT establish statically, and am therefore NOT estimating

- How many of the ~1,000 far-card nodes belong to understory vs canopy species at the actual spawn pose.
  Depends on the seed's terrain classification per bucket. **Windowed count required.**
- How many of the 25 resident US bodies are in frustum. **Windowed count required.**
- How many of `fsb_main.glb`'s 202 mesh nodes survive frustum culling at the spawn view. **Windowed.**
- **Any millisecond attribution at `fsb_main` whatsoever.** See §2 — the instrument does not collect it.

---

## 2. THE CPU-vs-GPU SPLIT — the honest answer is "unknown, and the instrument cannot tell us"

**The briefing asks whether the arena's near-balanced 44.35ms CPU / 51.94ms GPU is still the shape at
`fsb_main`. The answer is that this has never been measured at `fsb_main`, in any harness, ever.**

Evidence, all pointers:

- `tests/perf_probe.gd` — the **only** harness that has ever run against the shipped patrol world at
  `fsb_main` (`PERF_LEDGER.md:371-383, :673-687`) — reads exactly three counters:
  `RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME` (`:110`), `..._TOTAL_DRAW_CALLS_IN_FRAME` (`:112`),
  `..._TOTAL_OBJECTS_IN_FRAME` (`:114`). It **never calls**
  `RenderingServer.viewport_set_measure_render_time`, and it **never reads**
  `Performance.TIME_PROCESS` or `Performance.TIME_PHYSICS_PROCESS`. Every ledger table produced by it
  has columns `fps / prims / calls / objs` and no ms column — that is why.
- The one other patrol-world row, `tests/windowed_patrol_perf.tscn` on 2026-07-18, says so in its own
  caveat: **"gpu_ms unavailable (measured-render-time flag not enabled in this scene)"**
  (`PERF_LEDGER.md:273`).
- The 44.35 / 51.94 pair is `ai_stress_arena` — **night, 18v18 escalating firefight, at native 1.00**
  (`PERF_LEDGER.md:152`). The shipped hub is **day, 13 live units, at scale 0.75**. Different scene,
  different population, different pixel count. It does not transfer and should stop being quoted as if
  it does.
- The instruments that *do* measure the split — `arena_perf_overlay.gd:100, :141-142` and
  `ps2_perf_probe.gd:45, :98-99` — are both **arena-only**. `ps2_perf_probe.gd:52` hard-instantiates
  `AIStressArena`; `arena_perf_overlay.gd:86` is wired by the arena.

**So: the hub may well be a different regime, and I refuse to guess which.** I will say what the counts
make plausible and label it: **INFERRED** — a day scene with zero shadow pass, ~3,000 canopy triangles,
~157k total primitives (`PERF_LEDGER.md:679`) and 1,400 draw calls looks far more **draw-call / CPU
submission-bound** than fill-bound, because the frame is carrying an enormous call count against a tiny
primitive count. The arena's fill-heavy shape (806k primitives, `PERF_LEDGER.md:152`) is a *different
problem*. But that is reasoning from counts, not a measurement, and it is exactly what the measurement
batch must settle.

**The single cheapest, highest-value change in this entire analysis is not an optimization at all — it is
adding four lines to `tests/perf_probe.gd`** so it reports `gpu_ms`, `render_cpu_ms`, `process_ms` and
`physics_ms` alongside its existing counters. Every one of those calls already exists in
`arena_perf_overlay.gd:100, :136-142`; it is copy-and-paste. Until that lands, **every FPS conclusion
about the shipped world is being drawn blind to which half of the machine is binding.**

---

## 3. THE RANKED PLAN

**Ranking law applied:** look-free levers rank above look-costing ones even when smaller (RULE #1). I have
sorted strictly on that, not on size. Where a lever's expectation is an extrapolation I say so on the row.

---

### RANK 0 (prerequisite, not a lever) — instrument the shipped-world probe

**Change:** `tests/perf_probe.gd` — add `RenderingServer.viewport_set_measure_render_time(vp, true)` in
`_ready`, and sample `viewport_get_measured_render_time_gpu/_cpu` plus `Performance.TIME_PROCESS` and
`TIME_PHYSICS_PROCESS` into the existing per-phase averages.

- **Expected win:** 0 FPS. It is a measuring instrument.
- **Work:** ~30 minutes. The exact calls are already written in `arena_perf_overlay.gd:100, :136-142`.
- **Sacrifices:** nothing. `viewport_set_measure_render_time` costs a GPU timestamp query per frame,
  which is why it must stay behind the probe flag and never ship enabled.
- **Look cost:** none.
- **Why rank 0:** §2. Everything below is currently unfalsifiable at the hub without it.

---

### RANK 1 — fix the five stacked canteens (LOOK-POSITIVE, ~10 minutes)

**MEASURED, statically and definitively.** `model_actor.gd:403-423` exists to collapse numbered duplicate
gear meshes. `model_actor.gd:407` compiles the pattern:

```gdscript
re_num.compile(r"^(.+)\.(\d+)$")     # matches canteen_l.002  — a DOT
```

I read the mesh **node** names straight out of every character GLB's glTF JSON:

| model | mesh nodes | **dot**-suffixed | **underscore**-suffixed |
|---|---:|---:|---:|
| `us_grunt_v3.glb` (retired export) | 44 | **5** | 0 |
| `us_grunt_rifleman.glb` | 61 | **0** | **5** (`canteen_l_002 … _006`) |
| `us_grunt_marksman.glb` | 61 | **0** | **5** |
| `us_grunt_mg / pointman / grenadier` | 51 | **0** | **5** each |
| `us_grunt_rto.glb` | 54 | **0** | **5** |

There is **not one dot in any mesh node name in any shipping grunt** — Godot's glTF importer sanitizes
`.` out of node names (the *mesh resource* names keep them: `helmet_shell_worn.001`, but `mi.name` at
`model_actor.gd:390` reads the **node**). The regex was written against `us_grunt_v3`, the export the
pipeline moved off. **It matches the fossil and misses all six live variants.** The function runs, hides
zero meshes, and prints nothing (`:425-426` is gated on `hidden > 0`).

**Consequence: every US grunt on the map — all 17 garrison men and all 8 allies — renders five canteens
stacked in the same place.**

- **Expected win:** **4 draw calls + their overdraw per US soldier**, ~100 calls across 25 resident
  bodies before culling. As FPS: **INFERRED, small** — see the §3-lever-3 note on call-to-FPS conversion.
- **Work cost:** one regex. `r"^(.+)[._](\d+)$"` catches both conventions and keeps `us_grunt_v3` working.
- **Sacrifices:** nothing.
- **Look cost:** **NEGATIVE — this improves the look.** Five coincident canteens are z-fighting on every
  grunt's hip right now.
- This is also a clean FOSSIL-LAW case: cleanup code written for a retired export, still reading as live.

---

### RANK 2 — merge US grunt gear by material (LOOK-FREE BY CONSTRUCTION, the largest honest lever)

**MEASURED (the counts).** 44 visible surfaces on a rifleman, spread over 36 nodes, but only **23 declared
materials — six of which are duplicates of one** (`us_grunt_mat`, `.001`–`.005`). The VC models prove the
pipeline can do better: `vc_guerilla.glb` is **3 nodes / 13 surfaces** for a comparable silhouette.

Two stages, and the first is pixel-identical:

- **Stage A — dedupe materials + join meshes that share a material.** Merging meshes that already share a
  material produces **byte-identical pixels**. 44 surfaces → **~17–18** (one per unique material).
  **~60% cut, zero look risk, by construction.**
- **Stage B — atlas the gear textures** (webbing/ruck/canteen share a small palette already). 17–18 → **~4–6**.
  This one *can* shift pixels and needs his eyes on a side-by-side.

- **Expected win:** Stage A removes **~26 draw calls per US body**; across ~25 resident bodies that is
  **~650 submitted calls**, of which the in-frustum fraction is what actually bills.
  **INFERRED as FPS: see the conversion note below. Do not quote an FPS number for this until §5's batch
  runs.**
- **Work cost:** **real but bounded and already-owned.** `us_base_v3.blend` is the source of truth for
  every US model (standing ruling), the export driver exists (`tools/export_units_gltf.py`), and
  `tools/merge_face_skin_material.py` shows the material-merge pattern is already in this pipeline.
  Estimate a focused Blender session per variant family, not a new system.
- **Sacrifices:** the gib contract must stay intact. It does: `gib_system.gd:22-52` lists only
  `grunt_*` meshes, `cap_*` caps and two helmet gear names as dismemberable. **Webbing, ruck and canteens
  appear nowhere in `REGIONS`** — they have no dismemberment requirement and are free to merge. The
  merged gear must not swallow `helmet_camo_shell`/`helmet_bugjuice` (they fly off) or the `_joined` body
  (it swaps on gib). Name the merged mesh outside the `grunt_`/`cap_`/`head_frag_` namespaces or
  `model_actor.gd:478-481` will hide it.
- **Look cost:** **Stage A: none, by construction.** Stage B: needs an eyes check.
- **Why this ranks so high:** it is the only large lever in this document that is look-free *by
  construction* rather than by argument.

---

### RANK 3 — audit the three absurd-material props (LOOK-FREE, small, cheap)

**MEASURED (static).** `helipad.glb` = **55 materials / 55 surfaces** for 9,572 tris.
`tunnel_entrance_hidden.glb` = **62 materials / 62 surfaces** for 1,688 tris. `us_army_bridge.glb` = 53
surfaces / 23,852 tris. `punji_trap.glb` = 50 surfaces on 4 materials.

A 1,688-triangle tunnel mouth carrying 62 materials is an export accident, not an art decision. Same
merge-by-material treatment as Rank 2; same zero look cost when materials are shared.

- **Expected win:** **GUESSED.** These are props whose on-screen residency I have not established — the
  helipad is at the firebase (in view at spawn), the tunnel entrances are scattered. Cheap to fix; do it
  when the models are next touched, and do not build a plan around it.
- **Work cost:** small, per-asset.
- **Sacrifices / look cost:** none if materials are genuinely duplicates. Verify before merging.

---

### RANK 4 — per-species far-card `view_distance` tiering (LOOK-COSTING — ranked below the above, and this is the law working)

**This is the biggest single number in the document and it is deliberately ranked fourth, because it
changes what he sees and RULE #1 outranks the FPS.**

**MEASURED (static):** `tree_cover_layer.gd:46` sets one `view_distance = 350.0` for every species;
`:135` emits a far card for all 27 scattered species; **15 of the 27 are understory** (rice ×2, ferns ×3,
bushes ×3, grasses ×4, `palm_sapling_a`, `liana_a`, `vine_a`) against **12 canopy/silhouette species**
(broadleaf ×3, banana ×2, bamboo ×3, jungle_palm ×4).

**INFERRED (arithmetic, shown so it can be checked):** far-card nodes in visibility range scale with the
annulus area between `near_distance` and `view_distance`, divided by bucket area:

- today: `π(350² − 65²) / 64² ≈ 90.7 buckets` × ~17.8 species present per bucket ≈ **1,614 nodes in range**
  — which reconciles with the ledger's measured **~1,670 in range** (`PERF_LEDGER.md:913-914`), so the
  model is sound.
- understory dropped to a 120m card ring: `π(120² − 65²) / 64² ≈ 7.8 buckets`.
- new total ≈ `90.7 × 7.9 (canopy)` + `7.8 × 9.9 (understory)` ≈ 717 + 77 ≈ **794 nodes in range**.
- **≈51% fewer far-card nodes.** Scaling the measured ~957–1,017 *drawn* canopy calls by the same factor
  gives **~470–500 drawn instead of ~957–1,017 — roughly 500 draw calls, ~35% of the whole frame's calls.**

**Converting that to FPS — and here is the honest limit of what I can say.** The canopy lever is
call-bound and measured end-to-end: removing ~1,200 calls buys **+6.3 / +7.8 / +8.0 FPS**
(`PERF_LEDGER.md:875-878`). If the relationship is linear in calls, removing ~500 buys **≈ +2.6 to +3.4
FPS. That is an EXTRAPOLATION FROM A MEASURED ENDPOINT, NOT A MEASUREMENT**, and linearity is an
assumption I cannot test without a windowed run. It also assumes species presence is uniform across
buckets, which is a model, not a fact — the terrain classifier
(`vegetation_manager.gd:48-55`, per-type pools of 2/6/8/11/14 species) means understory dominates
GRASSLAND and RICE_PADDY buckets and is a minority in HEAVY_JUNGLE.

- **Work cost:** **genuinely small** — a per-species distance table read at `tree_cover_layer.gd:135`
  instead of the single `view_distance`. No new system, no new render path, no asset work. This is the
  crucial contrast with the atlas.
- **Sacrifices, named:** distant ground cover disappears. In **dense jungle this is invisible** — the 12
  canopy species occlude the understory at range anyway. In **open grassland and rice paddy the
  understory IS the visual**, and a 120m ring will read as bare ground rolling toward the treeline.
  The mitigation is per-species tuning (keep `elephant_grass_*` and `rice_*` long, cut `fern_*`/`bush_*`/
  `liana`/`vine` short) rather than one understory number — but that is a look decision and it is his.
- **Look cost: YES.** It must be eyes-checked in grassland and paddy, not just in jungle, and it must be
  checked from the seed-47225 spawn *and* from open ground.
- **Fairness check (ADR-026 §2 draw-distance floor):** this touches **foliage only** and never unit draw
  distance, so the `SIGHT_CAP_OPEN = 140m` floor is untouched. It is the same class of change as the
  already-ratified `jungle_patch_layer` 128→80m foliage pull (ADR-026:164). Concealment is a separate
  system (the veg grid), not the card ring, so AI sight is unaffected.

---

### RANK 5 — `BUCKET` 64 → 128 (LOOK-COSTING, and the ledger already priced it)

Unchanged from `PERF_LEDGER.md:919-925`. ~2.5× call cut, but `tree_cover_layer.gd:49-51` records why it
is a look change: `visibility_range` is evaluated per-NODE against the transformed AABB (godot#79471 —
the docs say origin and are wrong), so a 128m bucket quantises the 65m near/far handoff by **±90m**
instead of ±45m. That either double-renders cards inside the solid ring or opens a jungle gap — **the
±181m version of this defect WAS the historical invisible-jungle bug.**

**Ranked below Rank 4** because it costs more look for a comparable win, and because Rank 4's damage is
tunable per species while this one's is structural.

---

### RANK 6 — the card atlas (the ~10× win, and still real work)

Unchanged and re-verified: 27 scattered species, 27 separate PNGs, 27 separate `StandardMaterial3D`s, and
**no bake tool in the repo** (§1.4). Atlasing means writing the bake pipeline, a unit-quad mesh with
per-instance UV-rect custom data, a shader to read it, and re-deriving each card's aspect into the
instance transform — a **new far-card renderer path**.

- **Expected win: ~94 calls instead of ~1,000** — INFERRED from the bucket arithmetic, consistent with
  `PERF_LEDGER.md:926-928`. On the measured canopy endpoint that approaches the full **+6.3 to +8.0**.
- **Work cost: the largest in this document by a wide margin.** A new asset pipeline plus a new render
  path.
- **Sacrifices:** a whole new system to own and keep honest; FOSSIL LAW then requires deleting the
  per-species card material path in the same change.
- **Look cost:** intended to be zero, but a new impostor renderer always risks aspect/anchor regressions —
  and `tools/diag_veg_cards.gd` exists precisely because card anchoring has bitten before.
- **Ranked last not because it is bad but because Rank 4 gets ~half the win for ~2% of the work.** Do
  Rank 4, measure it, and only then decide whether the atlas is still worth building.

---

## 4. WHAT IS NOT WORTH DOING — with the evidence that kills it

**1. The firebase "9 → 5 material collapse". KILLED, statically, today.**
`production/firebase_kit_phase1_read.md:261-263` asserts collapsing the 9 fixed material families to 5 is
"the real performance lever". The briefing correctly flags it as unmeasured. **It is worse than
unmeasured — its premise is false.** `tools/gen_firebase.py:61-77` declares 9 material *slots*, but a
Blender→glTF export **only emits a surface for a material that has faces assigned to it.** Measured, by
parsing the exported GLBs:

| firebase kit asset | surfaces | materials |
|---|---:|---:|
| `fb_gate_assembly.glb` | 5 | 3 |
| `fb_FoxholeSandbags.glb` | 1 | 1 |
| `fb_sandbag_heavy.glb` | 1 | 1 |
| `fb_sandbag_light.glb` | 1 | 1 |

**Mean 2.0 surfaces per asset, max 5. Not 9.** The unused slots never reach the GPU. Collapsing 9 declared
slots to 5 would change **nothing** about what is submitted. *The claim should be struck from
`firebase_kit_phase1_read.md`, not measured.*

**However — the real firebase number is worse than the claim it replaces, and it is a different thing
entirely.** The shipped firebase is not the kit; it is **`fsb_main.glb`: one GLB, 202 mesh nodes, 204
surfaces, 94 materials, 20,554 tris**, placed as a single scene by
`site_planner.gd:798-819` (`place_firebase_main`). *That* is up to 204 draw calls at the exact pose every
ledger baseline is measured from. It belongs in the measurement batch — but it is **not** the
9→5 lever, and conflating them would repeat the error.

**2. Triangle shaving. Killed twice, and my census makes it absurd.** Measured: cutting 99,500 prims
(33%) and 77 draw calls moved FPS by **~0** (`PERF_LEDGER.md:96-100`). And the canopy — 70–85% of the
frame's draw calls — is **40 cards × ~3 triangles**. There is no triangle problem.

**3. Sun shadow.** Already `false` (`game_world.gd:52`). At ship parity the lever reads **−0.2, inside
noise** (`PERF_LEDGER.md:696`). The near-field cap is not a mitigation: 40m / 80m / uncapped are identical
within a 0.5 FPS floor (`PERF_LEDGER.md:718-722`). Guarded by `tests/test_ship_parity.tscn`. **Measured
and believed twice, retracted twice. Stop.**

**4. Campfires.** 0.0 at seed 47225 (zero exist — DAY seed); unmeasurable at seed 12 night with four fires
(`PERF_LEDGER.md:846-857`). A canon win, not a perf win.

**5. Clutter / grass.** Inside noise every single time (`PERF_LEDGER.md:825, :843`). And structurally it
cannot be otherwise: `ground_clutter.gd:14` `NEAR_END = 42.0` — it draws to 42m.

**6. `VEGETATION_DENSITY_MULT` as an FPS dial.** `world_config.gd:16` is `1.0`. It is read
(`vegetation_manager.gd:292-293`), so the briefing's "read by NOTHING" fossil claim is **stale — VERIFY
result: it IS wired**. But `world_config.gd:2-5` already tells the truth about it: it is a memory/CPU-gen
lever, not an FPS one. It scales *candidate counts*, which changes primitives — and primitives are not
the limiter.

**7. A renderer swap.** Closed by ADR-026 Amendment A (`:133-137`). Not evaluated here.

**8. Occlusion culling.** No `use_occlusion_culling` key exists in `project.godot` (default off). It is
tempting against a 1,400-call frame — but an OccluderInstance3D bake over a **procedurally generated,
destructible** 1280m AO is a new system with a bake step that fights `ClearingSystem` and the ADR-031
destruction path. And jungle occludes poorly (thousands of small alpha cards, no big blockers).
**GUESSED to be a net loss; not recommended, and not worth measuring before Ranks 1–4.**

---

## 5. DOC CLAIMS THAT ARE NO LONGER TRUE (NO DRIFT — reported, with pointers)

1. **`PERF_LEDGER.md:21-23`** — *"As of 2026-07-20 it is explicitly `forward_plus` in `project.godot:300`…
   if it goes missing again, restore it before measuring."* **It has gone missing again.** `project.godot`
   today has **no `renderer/rendering_method` key at all**; line 305 is
   `renderer/rendering_method.mobile="gl_compatibility"`, which is the *mobile-platform* override, not the
   desktop method. **Behaviour is unaffected** — Forward+ is the desktop default, and ADR-026:142-146
   already ruled that this key "is NOT and cannot be a committed setting". **The ledger's instruction is
   the stale part**, and its `:300` pointer is wrong. The measurement contract should say *confirm the
   renderer at runtime from the boot banner*, which is what ADR-026 already says.
2. **`PERF_LEDGER.md:889-890`** — cites `project.godot:299` (forward_plus) and `:304` (scale 0.75).
   Actual today: `scaling_3d/mode=5` at **`:307`**, `scaling_3d/scale=0.75` at **`:308`**; no renderer
   line exists.
3. **`ADR-026:139`** — *"Already live (`project.godot:302-305`)"*. Actual: **`:307-310`**.
4. **`ADR-026:39` and `:148`** — cite `game_world.gd:48` for `shadow_enabled = false`. Actual: **`:52`**.
5. **`arena_perf_overlay.gd:81`** — the code comment cites `game_world.gd:48`. Actual: **`:52`**.
6. **`PERF_LEDGER.md:901-928`** — the whole canopy-mechanism section's pointers have drifted by 5–17
   lines. Corrected table in §1.4.
7. **`PERF_LEDGER.md:932`** — *"The 27 card textures"* reads as a complete inventory. There are **40**
   cards on disk; 27 are scattered, 13 are dead weight (§1.4).
8. **The briefing's own §3.3** — the firebase 9→5 claim is not merely unmeasured, its premise is false
   (§4.1). `production/firebase_kit_phase1_read.md:261-263` should be struck, not benched.
9. **The briefing's §3.3 asks about ADR-025's DORMANT/AGGREGATE tiers as a CPU plan.** **ADR-025 is
   SUPERSEDED** (`ADR-025-lod-tier-simulation.md:3-19`) — *"Do not extend `WorldSim`, and do not wire
   `materialize_near`/`dematerialize_far`."* The ADR records that it "stayed DRAFT-but-live for four days
   and actively misdirected work". **No plan item should route through it.**
10. **The briefing's §1 fossil claim that `world_config`'s FPS ladder "is read by NOTHING".** Verified:
    **stale.** `WorldConfig.VEGETATION_DENSITY_MULT` (`world_config.gd:16`) is read at
    `vegetation_manager.gd:292-293`. It is a live-but-useless dial, not a fossil.
11. **`ADR-026:164`** — *"Foliage `view_distance` 128m → 80m — LANDED"* in `jungle_patch_layer.gd:73`.
    That file is the **legacy JunglePatch canopy**, and `world_config.gd:21` `USE_TREE_COVER = true`
    means the shipped AO **does not build it** (`vegetation_manager.gd:100-101, :116`). The landed lever
    applies to the arena only. The shipped canopy's distance is `tree_cover_layer.gd:46` = **350m**,
    untouched by that ADR item.
12. **`tools/diag_veg_cards.gd` does not run.** Invoked headless via `--script` it fails at compile:
    `Identifier not found: GameManager` at `tree_cover_layer.gd:192` (`_resolve_center`), because
    `--script` does not register autoloads. It needs a scene-based harness. A diagnostic that cannot
    execute is the same disease as a fossil.

---

## 6. WHAT I COULD NOT SETTLE WITHOUT A WINDOWED RUN

Handing these to the measurement-engineer rather than estimating them:

1. **The CPU/GPU split at `fsb_main`** — blocked on Rank 0. Highest priority; everything else is
   guesswork without it.
2. **Character attribution at the hub** — hide the 17 garrison men + 8 allies and read Δcalls/Δfps.
   This is the number that decides whether Rank 2 is the main event or a footnote. *There is no toggle
   for this today*; `arena_perf_overlay.gd:282-285`'s F4 calls `set_characters_active` on the **arena**,
   not on the patrol world. A `no_characters` phase in `perf_probe.gd` is the missing instrument.
3. **`fsb_main.glb` attribution** — hide the placed firebase root and read Δcalls. Up to 204 surfaces at
   the exact pose every baseline is measured from.
4. **The understory/canopy split of the far-card ring at the spawn pose** — needed to turn Rank 4's
   ~51% node estimate into a real number. A `--card-dist=` lever already exists
   (`tree_cover_layer.gd:78-80`) and can bracket it crudely today; a per-species version is the real test.
5. **Whether the canopy call→FPS relationship is linear** — Rank 4's +2.6/+3.4 extrapolation depends on
   it. One intermediate `--card-dist` point between 350 and 65 answers it.
6. **A pose other than the spawn.** Every ledger row is the same stationary spawn view into the base
   interior (`PERF_LEDGER.md:270-273, :524`). We have literally never measured the frame from a jungle
   sightline, which is where the canopy lever is presumably *largest* and the character lever smallest.

---

## 7. SUMMARY TABLE

| # | lever | expected win | evidence class | work | look cost |
|---|---|---|---|---|---|
| 0 | instrument `perf_probe.gd` with ms | 0 FPS | — | ~30 min | none |
| 1 | canteen regex `model_actor.gd:407` | −4 calls/US body | MEASURED (static) | ~10 min | **negative (improves)** |
| 2 | merge US grunt gear by material | −26 calls/US body (Stage A) | MEASURED (static) | Blender session/variant | **none (Stage A, by construction)** |
| 3 | merge absurd-material props | small | GUESSED | small | none |
| 4 | per-species far-card distance | ~500 calls; **+2.6–3.4 FPS** | **INFERRED (extrapolated)** | small (a table) | **YES — needs his eyes** |
| 5 | `BUCKET` 64→128 | ~2.5× call cut | ledger | small | **YES — quantisation/jungle gap** |
| 6 | card atlas | ~1,000 → ~94 calls | INFERRED | **new pipeline + render path** | intended zero, risk real |

**The one-sentence verdict:** the frame is a **draw-call frame, not a triangle frame or a fill frame**;
the canopy owns 70–85% of the calls and the *characters* are the strongest candidate for the rest; the
cheapest real wins are look-free character-mesh hygiene that nobody has looked at, and the biggest cheap
win is telling 15 understory species to stop drawing impostors at 350 metres — **but we have never once
measured which half of the machine is binding at the pose we judge the game by, and that must be fixed
before any of it is trusted.**
