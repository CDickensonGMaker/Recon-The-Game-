# TECHNICAL-ARTIST — asset-side draw-call & material census

**Session:** 2026-07-26 whole-game FPS deep dive · **Lens:** assets, materials, textures, import flags.
**Method:** static inspection only. Every GLB below was parsed by reading its glTF JSON chunk; every
texture measured from its PNG/JPEG header; every import flag read from the `.import` file. **No windowed
run, no headless GPU number, no estimate presented as fact.** Where a count cannot be settled without a
windowed run it is marked **[MEASURE]** and stated as a question, not an answer.

---

## 0. HEADLINE

Three findings outrank everything else in this analysis, and none of them was in the ledger:

1. **`fsb_main.glb` carries 94 materials for 9 textures, across 204 surfaces — and 20 of those
   materials are alpha-BLEND.** The shipped firebase is a single GLB with ~204 unbatchable surfaces
   sitting at the exact pose the 34-FPS baseline was measured from. 46 of the 94 materials are
   parameter-identical duplicates.
2. **All 40 impostor cards are `alphaMode: BLEND`, not alpha-scissor.** ~957–1,017 far cards are
   therefore drawn in the transparent pass — no depth write, no early-Z, full overdraw, plus CPU depth
   sorting. The project already uses `TRANSPARENCY_ALPHA_SCISSOR` for ground clutter
   (`scripts/world/ground_clutter.gd:103-104`), so the pattern is precedented in-repo.
3. **19 copies of a 3600 × 5700 character texture, 18 of them byte-identical, all imported LOSSLESS.**
   78.3 MB of RGBA8 VRAM *each*. Character textures alone total ~908 MB RGBA8 across
   `us/` + `nva_vc/` + `civilians/`.

The firebase 9→5 atlas claim is **not merely unproven — it is inapplicable.** See §3.

---

## 1. NO-DRIFT CORRECTIONS (made on contact, per the standing law)

The briefing and `PERF_LEDGER.md:882-943` carry pointers that no longer resolve. Correcting in place:

| claim | stated pointer | measured actual |
|---|---|---|
| group key `[species, bucket_x, bucket_z]` | ledger `:94`, briefing `:105` | `tree_cover_layer.gd:110` |
| `BUCKET = 64.0` | ledger `:47` | `tree_cover_layer.gd:52` ✓ (briefing `:52` correct) |
| two nodes per group emitted | ledger `:115`/`:118`, briefing `:125`/`:128` | `tree_cover_layer.gd:132` (near) / `:135` (far) |
| `_extract_mesh` takes first mesh only | ledger `:199` | `tree_cover_layer.gd:323` |
| `visibility_range` per-NODE comment | ledger `:43-46` | `tree_cover_layer.gd:49-51` |
| "4 palms carry 2 surfaces" | ledger `:907` | **6 palms** carry 2 (`jungle_palm_a1/a2/a3/b1/b2/b3` = `palm_bark` + `palm_leaf`). 47 solid GLBs → 53 surfaces. |
| "the 27 card textures are NOT atlased" | ledger `:932` | **Still true for the 27 live species.** The folder now holds **40** cards. See §4. |
| firebase kit = "23 assets, 9 fixed material slots" | briefing §2.3, `gen_firebase.py:61-77` | `MATS` is now **10 entries** (`gen_firebase.py:64-79`; `fb_kit.WALL_MAT` appended at `:78`). More importantly **none of the 23 assets exists as a shipped GLB.** See §3. |

**Card bake tool: STILL NOT IN THE REPO.** `tools/` has 97 Python scripts; none bakes an impostor card.
`make_jungle_vegetation.py:521` is still the star-fan grass quad, `make_jungle_flora.py`'s "card" hits
are prose (`:4`, `:11`). The 40 cards were baked outside the repo and are **not regenerable from source
in-tree.** The ledger's atlas blocker stands unchanged, and it is now worse: 40 unreproducible artifacts
instead of 27.

---

## 2. THE CENSUS

All counts are **asset-file truth** (surfaces and materials as authored). A surface with a distinct
material is a draw call unless something batches it; Godot 4 Forward+ does not auto-merge separate
`MeshInstance3D` nodes, and there is **no mesh-merge step anywhere in the codebase** (the only `_merge`
is `scripts/world/nav_baker.gd:96/113`, which merges nav AABBs, not meshes). So authored surface count
is the upper bound on calls, and material duplication is what prevents the count from collapsing.

### 2.1 Summary table

| subsystem | files | surfaces | materials | distinct mat *names* | tris | alpha | instancing |
|---|---:|---:|---:|---:|---:|---|---|
| **Canopy far-cards** | 40 | 40 | 40 | 40 | 122 | **40 BLEND** | MultiMesh ✓ |
| **Canopy near-solids** | 47 | 53 | 53 | **4** | 12,371 | 46 OPAQUE / 7 BLEND | MultiMesh ✓ |
| **Firebase `fsb_main.glb`** | 1 | **204** | **94** | 94 | 20,554 | 74 OPAQUE / **20 BLEND** | individual MeshInstance3D ✗ |
| Firebase `kit/` GLBs | 4 | 8 | 6 | 6 | 1,381 | 4 OPAQUE / 2 BLEND | individual ✗ |
| **Village** | 26 | 251 | 159 | **17** | 32,865 | all OPAQUE | individual ✗ |
| **Temple** | 29 | 272 | 205 | **30** | 61,125 | all OPAQUE | individual ✗ |
| Ruins | 22 | 69 | 69 | **9** | 15,296 | all OPAQUE | individual ✗ |
| VC/NVA structures | 7 | 136 | 78 | 78 | 6,384 | 76 OPAQUE / 2 BLEND | individual ✗ |
| Infrastructure | 4 | 56 | 8 | 8 | 25,976 | all OPAQUE | individual ✗ |
| Colonial / commercial / airfield | 14 | 25 | 17 | 17 | 3,779 | all OPAQUE | individual ✗ |
| **US characters** | 9 | 583 | 173 | — | 38,520 | all OPAQUE | individual ✗ |
| **VC characters** | 5 | 284 | 59 | — | 16,627 | all OPAQUE | individual ✗ |
| Civilians | 10 | 380 | 54 | — | 13,176 | all OPAQUE | individual ✗ |
| Village props | 17 | 104 | 36 | — | 4,876 | all OPAQUE | individual ✗ |

**Every single material in every asset above is `doubleSided: true`** — 100% of them, measured. That is
`cull_mode = CULL_DISABLED` on closed bunkers, crates, buildings, temples and soldiers. See §5.1.

### 2.2 Canopy — far cards and near solids

**Which canopy actually ships, settled:** `scripts/levels/world_config.gd:21` — `const USE_TREE_COVER:
bool = true` → `scripts/levels/game_world.gd:100-101` selects `CanopySource.TREE_COVER`. The
`JUNGLE_PATCH` default at `terrain/vegetation/vegetation_manager.gd:40` is overridden at boot.
**`TreeCoverLayer` is live and the ledger's canopy diagnosis stands.**

**The far-card ring is 27 species, not 40 — and this is the important correction to the impostor wave.**
`vegetation_manager.gd:118` calls `load_species(_all_species())`, and `_all_species()` (`:128-133`)
returns the union of `TYPE_SPECIES` (`:48-55`). That union is exactly **27** species:

> `rice_a/b · tall_grass_a/b · elephant_grass_a/b · bush_a/b/c · fern_a/b/c · banana_a/b ·
> palm_sapling_a · jungle_palm_a1/a2/b1/b2 · broadleaf_a/b/c · bamboo_a/b/c · liana_a · vine_a`

The 13 cards on disk that `TYPE_SPECIES` never names are **never loaded and never drawn**:
`elephant_grass_c · grass_fan · grass_tuft_a/b/c · jungle_palm_a3 · jungle_palm_b3 · liana_b ·
palm_sapling_b · tall_grass_c · trunk_vine_a/b · vine_b`.

**So the impostor wave did NOT grow the far-card ring.** Species-per-bucket is unchanged, the ledger's
`94 buckets × ~17.6 species ≈ 957–1,017 far cards` still holds, and the ~1,200-call canopy figure is not
stale. The wave added 13 unused assets and a duplicated source-texture set (§5.4), not draw calls.

**Materials are shared correctly on the near ring's *name*, and not shared at all in *resource* terms.**
40 of the 47 solid GLBs carry a material named `jungle_atlas` sampling an image named `jungle_palette`
— but each GLB extracted its own copy: `assets/world/vegetation/bamboo_a_jungle_palette.png`,
`..._b_...png`, ×40, **all 40 byte-identical, and all 17×1 pixels.** So they are 40 distinct
`StandardMaterial3D` + 40 distinct `CompressedTexture2D` resources that Godot cannot batch across.
**This costs essentially nothing in practice** — the palette is 17×1 px (VRAM ~zero) and the near ring
resolves to ~1 visible node (ledger `:912-914`). **Not a lever. Named here so nobody chases it.**

### 2.3 Firebase — the real number

`assets/world/building models/structures/firebase/fsb_main.glb`, 7.4 MB, placed **exactly once** per AO
(`scripts/world/site_planner.gd:644`, `:818`):

- **681 nodes · 202 meshes · 204 primitives (surfaces) · 94 materials · 9 images · 20,554 tris**
- Collapsing materials by full parameter signature (baseColorTexture, all factors, alphaMode,
  doubleSided, normal, emissive): **94 materials → 48 truly distinct signatures.** 46 materials are
  redundant duplicates.
- The duplication is textbook Blender `.00N` drift:
  `Crate_Post_Wood_*` ×20 · `Crate_Wood.00N` ×10 · `OliveDrab.00N` ×8 · `BarbedWireMetal.00N` ×7 ·
  `Crate_Metal.00N` ×5 — **all untextured flat-colour materials with identical parameters.**
- **19 `Sandbags*` materials** (`Sandbags`, `.002`–`.007`, `.048`–`.051`, `.054`–`.059`, `.070`, `.071`)
  are **parameter-identical** — no `baseColorFactor`, `metallicFactor: 0`, no `roughnessFactor` — and
  all 19 point at **image index 2, the same 64×64 `Sandbags` PNG**, via 19 different `texture` entries.
  Nineteen materials, one 64×64 texture, zero difference between them.
- **20 of the 94 materials are `alphaMode: BLEND`**: the 19 `Sandbags*` plus `mat_bwire_card`. The
  sandbags — the bulk of a firebase, at point-blank range, at the measured 34-FPS spawn pose — are
  rendering in the **transparent pass**.

**Attribution honesty.** `PERF_LEDGER.md:896-898` measured 411–464 draw calls with the canopy hidden.
`fsb_main` authors 204 surfaces. If a large share of them are in frustum at the spawn pose, `fsb_main`
is a **large fraction of the entire non-canopy frame**. I cannot settle the in-frustum share statically.
**[MEASURE-1]** — see §7.

**Firebase textures are already correct**: all 9 are `compress/mode=2` (VRAM compressed) with mipmaps.
No win there.

### 2.4 Village and temple

- **Village: 26 GLBs, 251 surfaces, 159 materials — but only 17 distinct material *names*.**
  Mean **9.7 surfaces / 6.1 materials per building**. `site_layouts.gd:8-9` stamps 7–10 huts plus a
  centre model plus edge/yard pieces per village; ledger `:263-264` records **4 villages resident**.
  So roughly **40–56 buildings ≈ 400–540 authored surfaces** resident across the AO.
- **Temple: 29 GLBs, 272 surfaces, 205 materials, 30 distinct names, 61,125 tris.**
- **Materials are DUPLICATED, not shared.** Every GLB extracted its own copy of the shared palette:
  `village jungle_palette` — **26 copies, 1 distinct content, 17×1 px**;
  `vil_thatch` — **13 copies, 1 distinct, 256×256**;
  `temple_laterite` — **28 copies, 1 distinct, 256×256**.
  Two thatch huts standing side by side therefore use two different `StandardMaterial3D` resources
  pointing at two different `CompressedTexture2D` resources holding **identical pixels**, and cannot
  batch. This is the single most mechanical batching loss in the building sets.
- Village/temple textures are `compress/mode=2` with mipmaps. **Correct — no import win there.**
- All village and temple materials are OPAQUE. **Good.**

### 2.5 Characters

| model | meshes | surfaces | materials | tris |
|---|---:|---:|---:|---:|
| `us_grunt_rifleman.glb` | 61 | 78 | 23 | 6,070 |
| `us_grunt_marksman.glb` | 61 | 81 | 26 | 6,126 |
| `us_grunt_rto.glb` | 54 | 72 | 24 | 6,150 |
| `us_grunt_mg/pointman.glb` | 51 | 71 | 23 | 4,410 / 5,066 |
| `vc_guerilla.glb` | 25 | 59 | 14 | 3,707 |
| `civ_farmer_m.glb` | 25 | 38 | 5 | 1,220 |

**A US grunt is 51–61 separate `MeshInstance3D` nodes carrying 71–81 surfaces and 20–26 materials, and
nothing merges them.** Materials duplicate *within* a single model too — `us_grunt_rifleman.glb` carries
`us_grunt_mat` plus `us_grunt_mat.001`–`.005`, six materials for one body surface.

`FSB_GARRISON_POSTS` (`site_planner.gd:681-694`) seats **14 men inside the wire** before the squad.
I cannot state how many are in frustum at the spawn pose without a windowed run. **[MEASURE-2]**.

**This is the gameplay-programmer's and technical-director's territory on the CPU side; I flag only the
asset fact: per-character surface count is 3–4× what a PSX-era character needs, and it is an export
structure problem (51 unjoined objects), not a triangle problem.** Tri counts are fine and I am not
proposing to shave them.

### 2.6 Terrain, water, roads, paddy

Out of my measurable reach statically, but two asset-side facts settled:

- **Water is already optimal.** `terrain/water/water_system.gd:239` — *"Build ONE mesh + ONE material
  for every water body. Collapsing ~dozens of…"*. One mesh, one `ShaderMaterial`. **Not a lever.**
- Terrain and swamp water are shader-driven (`terrain/shaders/terrain.gdshader`,
  `terrain/water/water_static.gdshader`, `water_swamp.gdshader`). `PERF_LEDGER.md:98-100` names
  full-screen terrain/water fragment shading as the limiter at that pose. **That is the
  godot-specialist's and technical-director's lens, not mine — I defer it and do not double-count it.**
- `jungle_patch_layer.gd:160` sets `render_priority = 1` on the swamp water material so it draws after
  vegetation. Correct as authored; noted so nobody "fixes" it.

---

## 3. ASSIGNMENT 2 — THE FIREBASE 9→5 CLAIM: **INAPPLICABLE, NOT MERELY UNPROVEN**

`production/firebase_kit_phase1_read.md:261-263` asserts:

> *"The atlas rule is the real performance lever… Every kit asset carries 9 material slots, so one
> placed asset can cost up to 9 draw calls. Collapsing 9 → 5 atlas families is measured-relevant in a
> way that shaving triangles is not."*

**VERDICT: the claim cannot be true of the shipped game, because the assets it describes are not in the
shipped game.** Measured:

1. **The 23 nine-slot kit assets do not exist as Godot assets.** The entire firebase asset folder is:
   `fsb_main.glb` + `kit/{fb_FoxholeSandbags, fb_gate_assembly, fb_sandbag_heavy, fb_sandbag_light}.glb`
   + `tex/`. That is **four** kit GLBs, not 23. `fb_bunker_mg`, `fb_tower`, `fb_toc`, `fb_hootch`,
   `fb_gun_pit` etc. exist only as objects inside `kit/firebase_kit_review.blend`.
2. **The four kit GLBs that do exist carry 1–3 materials, not 9**, and none of them is an `fb_*`
   material: `SandbagMaterial` · `wood.001`/`GateMetal`/`MetalPost` · `Sandbags.051` · `Sandbags.071`.
3. **The 7 `fb_*` atlas textures are referenced by nothing.** `firebase/tex/fb_sandbag.png`,
   `fb_earth`, `fb_timber`, `fb_psp`, `fb_canvas`, `fb_corrugated`, `fb_crate` (all 256×256) appear in
   no GLB in the project. `fsb_main.glb`'s 9 images are `tmpgrkqkgg0` (hessian), `hessian_230`,
   `Sandbags`, `m2hb_7_normal`, `m2hb_7_baseColor`, `FRAInfantry`, `tmp_x5k00cr` (corrugated),
   `corrugated_iron`, `barbwire_impostor`. **Zero overlap.**
4. `gen_firebase.py` is a **Blender-side shapes library** (`:7`), and the shipped `fsb_main.glb` was
   exported 2026-07-18 by `tools/export_fsb_main.py` (`site_planner.gd:633`) from a different,
   hand-authored source. The 9-slot convention has **never crossed into Godot**.
5. Even the slot count is stale: `MATS` at `gen_firebase.py:64-79` is **10** entries — `fb_kit.WALL_MAT`
   was appended at `:78`.

**How many draw calls does 9→5 remove at `fsb_main` today? ZERO.** There is no shipped asset carrying
the 9 slots.

**What is TRUE and what the claim was groping toward.** The firebase *does* have a severe material
problem — it is just a different one. `fsb_main.glb` carries **94 materials for 9 textures, 46 of them
exact duplicates**, and **20 of them alpha-BLEND**. Collapsing 94 → 48 by de-duplicating identical
materials is a **real, look-free** change with a real (if unmeasured) magnitude. That is the lever;
"9 → 5" is not.

**Honest magnitude, and I will not oversell it.** `PERF_LEDGER.md:98-100` records that cutting **99,500
prims (33%) and 77 draw calls moved FPS by ~0**. A 46-material de-duplication is in the same order of
magnitude as that 77-call cut, so **on the call-count argument alone it should be expected to move FPS
by roughly nothing.** I am ranking it as a *hygiene* win, not an FPS win.

**The `fsb_main` change I do expect to matter is the 20 BLEND materials, and that is a FILL argument,
not a call argument** — see §5.2. Fill is what the ledger named as the limiter at this pose.

**FOSSIL LAW note for the Arbiter.** `firebase/tex/fb_*.png` (7 textures) and the `MAT_INDEX`/`MATS`
scheme in `gen_firebase.py` are referenced by no shipped asset. Either the kit ships and they become
live, or they are a fossil. That is a Summoner call, not mine — but the doc at
`firebase_kit_phase1_read.md:261-263` must be corrected either way, because it currently reads as a
statement about the shipped frame and it is not one.

---

## 4. ASSIGNMENT 3 — THE IMPOSTOR FOLIAGE WAVE

**Verified against assets. Committed in one commit, `ad25457f` "Commit veg impostor cards + world
assets".**

### What it did
- **40 card GLBs**, one quad or crossed-quad pair each. Total across all 40: **122 triangles**
  (`bamboo_a_card` = 8 verts / 4 tris = 2 crossed quads; `vine_b_card` = 4 verts / 2 tris = 1 quad).
  Against 12,371 tris in the 47 solids, the 98.7% tri-cut claim is **directionally correct** for the
  far ring. It is also, per the standing measurement, **worth ~0 FPS** — tri budgets are style.

### What it did NOT do
- **It did not change the far-card ring.** Only **27** of the 40 are in `TYPE_SPECIES` and loaded
  (§2.2). The other 13 are inert. Species-per-bucket is unchanged.
- **It did not change the atlas blocker.** Each of the 40 still has its own PNG and its own
  `StandardMaterial3D` (40 GLBs → 40 materials → 40 distinct names, measured). No atlas, no bake tool.
- **It did not add barbwire to the canopy.** The barbwire impostor lives inside `fsb_main.glb` as
  `mat_bwire_card` / image `barbwire_impostor` (1024×348), consistent with the standing ruling that
  `barbwire_card.glb` is the only wire (`gen_firebase.py:43-46`).

### ALPHA MODE — the finding that matters
**All 40 cards are `alphaMode: BLEND` and `doubleSided: true`. Measured, 40/40, no exceptions.**

glTF `BLEND` imports as `StandardMaterial3D.transparency = TRANSPARENCY_ALPHA`. Consequences on an
Intel UHD, which is fill- and bandwidth-starved:

- Cards render in the **transparent pass**: **no depth write, no early-Z rejection.** ~957–1,017 far
  cards overlapping in a jungle means the GPU shades **every fragment of every card**, front to back,
  with nothing culling the hidden ones. This is the definition of unbounded overdraw.
- Transparent objects are **depth-sorted per-object on the CPU every frame** — so this also taxes the
  CPU half, which `PERF_LEDGER.md:200-201` says is near-balanced with the GPU.
- `doubleSided` + BLEND means each card is shaded **twice** with no depth rejection between the passes.
- MultiMesh instances inside one MMI cannot sort against each other, so alpha-blend is also
  *incorrect* here — it buys sorting artifacts it cannot pay for.

**`TRANSPARENCY_ALPHA_SCISSOR` is the correct mode for foliage impostors**, and the project already
knows it: `scripts/world/ground_clutter.gd:103-104` sets
`TRANSPARENCY_ALPHA_SCISSOR` / `alpha_scissor_threshold = 0.4`, and `:50/:57` plumb an `alpha_scissor`
parameter through the clutter shader. **The canopy cards are the outlier, not the precedent.**

**LOOK COST: I assess this as zero-to-positive, and I flag it as an assessment, not a measurement.**
Alpha-scissor gives hard-edged cutout foliage — which is *more* PSX/PS2-correct than soft-blended
leaves, and it is what the aesthetic already does on ground clutter. But **RULE #1 says his eyes decide**,
so this ships behind a look-check, not on my say-so.

**MAGNITUDE: unmeasured, and I will not guess a number.** The argument for it being large is that the
ledger names fill as the limiter and this is the largest fill item in the frame. The argument for
caution is that the same ledger has twice retracted a "large" fill/shadow win. **[MEASURE-3]**.

### Card texture cost
All 40 card PNGs import at **`compress/mode=0` (Lossless → RGBA8 in VRAM)** with mipmaps on
(`mipmaps/generate=true` ✓, `process/fix_alpha_border=true` ✓ — both correct).

Card textures are **768 px wide × 131–8,838 px tall**, non-power-of-two:

| | base RGBA8 | + mipmaps | if `compress/mode=2` (+mips) |
|---|---:|---:|---:|
| all 40 cards | 173.8 MB | 231.7 MB | 57.9 MB |
| **the 27 LIVE cards** | **91.1 MB** | **121.5 MB** | **30.4 MB** |

The four largest are `vine_b` 768×8838 (27 MB), `trunk_vine_b` 768×6015, `vine_a` 768×5508,
`liana_b` 768×5394. **`vine_b`, `trunk_vine_b` and `liana_b` are among the 13 that are never loaded.**
`vine_a` (768×5508, 17 MB RGBA8) and `liana_a` (768×4539) **are** live.

---

## 5. ASSIGNMENT 4 — ASSET-SIDE CHEAP WINS, RANKED

Ranked by **expected magnitude × confidence**, look-free first. Every one has a pointer. I have labelled
my confidence honestly; nothing here is a promised FPS number.

### 5.1 — `doubleSided: true` on 100% of assets · LOOK-FREE · large fill argument · HIGH confidence it is wrong, UNMEASURED magnitude

**Measured: every material in every GLB inspected is `doubleSided: true`.** 94/94 in `fsb_main.glb`,
159/159 village, 205/205 temple, 53/53 veg solids, all characters, all props.

`doubleSided` → `cull_mode = CULL_DISABLED` → **backface culling off**, so the GPU rasterises and shades
the inside of every closed bunker, crate, hut, temple wall and soldier. **On a closed solid this is pure
waste — you cannot see a backface you are outside of.** It is a Blender export default, not an art
decision.

- **Legitimately needs double-sided:** the 40 cards, the 7 BLEND veg leaf materials (`palm_leaf` ×6,
  `grass_fan`), thatch/canvas sheets, `mat_bwire_card`.
- **Does not:** everything else — crates, bunkers, walls, ground, characters, weapons.

**Fix:** set `use_backface_culling = True` on closed-solid materials in the Blender generators
(`tools/gen_village.py`, `tools/gen_temples.py`, `tools/gen_firebase.py`, `tools/fb_kit.py`,
`tools/make_jungle_vegetation.py`) and re-export; or override `cull_mode` on import for the shipped
GLBs that have no generator (`fsb_main.glb`, characters).
**LOOK COST: zero on closed solids — by definition invisible. Non-zero if applied to a sheet
(thatch/leaf/canvas would vanish from one side), so it must be per-material, not global.**
**This is my #1 recommendation. It is the largest look-free fill reduction available on the asset side.**

### 5.2 — 20 alpha-BLEND materials in `fsb_main.glb` · LOOK-FREE (needs verification) · at the measured pose · HIGH value

The 19 `Sandbags*` materials sample a **64×64** texture (`fsb_main_Sandbags.png`, 3 KB) and are BLEND.
Sandbags fill the screen at the 34-FPS spawn pose. If that 64×64 texture has no meaningful alpha — and a
3 KB 64×64 packed sandbag map almost certainly does not — then **setting these 19 to OPAQUE is a pure
free win**: it moves the bulk of the firebase out of the transparent pass into the depth-writing opaque
pass, restoring early-Z for everything behind it.
`mat_bwire_card` genuinely needs alpha and should become **ALPHA_SCISSOR**, not BLEND.
**Pointer:** materials `Sandbags`, `Sandbags.002`–`.007`, `.048`–`.051`, `.054`–`.059`, `.070`, `.071`
in `assets/world/building models/structures/firebase/fsb_main.glb`.
**Verify before shipping:** does `fsb_main_Sandbags.png` carry real alpha? If it does, ALPHA_SCISSOR;
if not, OPAQUE. Either beats BLEND.

### 5.3 — 40 canopy cards BLEND → ALPHA_SCISSOR · LOOK-CHECK REQUIRED (assessed neutral-to-positive) · potentially the largest single fill lever

See §4. Precedent in-repo at `scripts/world/ground_clutter.gd:103-104`.
**Cheapest implementation that touches no assets:** `tree_cover_layer.gd:135` already owns the far-card
MMI. A per-species shared `StandardMaterial3D` (or a `material_override` on the far MMI) set to
`TRANSPARENCY_ALPHA_SCISSOR` with `alpha_scissor_threshold ≈ 0.4` and
`cast_shadow = SHADOW_CASTING_SETTING_OFF` (already set, `:309`) applies to all 1,000 cards from one
place. **Materials must be shared per species, created once, never `.new()` per MMI** — otherwise this
trades a fill win for a batching loss.
**LOOK COST: named. Hard cutout edges instead of soft. His eyes decide.**

### 5.4 — Texture import: 413 of 838 asset textures are LOSSLESS · LOOK-FREE at `compress/mode=2` · large VRAM/bandwidth win

Measured across `assets/`: **413 `compress/mode=0` vs 425 `compress/mode=2`.** The lossless half is
concentrated exactly where it hurts:

| folder | lossless textures | RGBA8 base |
|---|---:|---:|
| `assets/nva_vc/characters` | 18 | **478.5 MB** |
| `assets/us/characters` | 34 | **373.1 MB** |
| `assets/civilians/characters` | 50 | 56.4 MB |
| `assets/world/vegetation/cards` | 40 | 173.8 MB (91.1 MB live) |
| `assets/world/vegetation/cards/tex` | 40 | duplicate set, see below |
| `assets/world/vegetation` | 51 | ~0 (17×1 palettes) |

**The `*_better textures.png` disaster.** 19 files, **3600 × 5700 px each** = 20.5 Mpixels,
**78.3 MB RGBA8 each** (104.4 MB with mipmaps). **18 of the 19 are byte-identical** (single MD5); only
`us_grunt_m14_better textures.png` differs. 155.9 MB on disk. Every character GLB references it as its
main body map (`us_grunt_rifleman.glb` images: `better textures`, `insectrepl`, `cigs`, `canvas_od`,
`gore_tex`, `face_atlas_v3`).

Three separate wins here, in increasing look risk:

- **(a) `compress/mode=2` — LOOK-FREE.** BPTC/S3TC is perceptually near-lossless and cuts VRAM **4×**.
  Every other asset family in the project already does this (firebase, village, temple all mode=2).
  This is an unambiguous, no-argument fix. **~680 MB → ~170 MB across characters alone.**
- **(b) De-duplicate the 18 identical copies to ONE shared texture — LOOK-FREE.** 18 separate
  `CompressedTexture2D` resources holding identical pixels also force 18 separate materials, so this is
  a batching win as well as a memory win. Requires re-export with a shared external texture rather than
  per-GLB extraction.
- **(c) Resolution — THIS IS A LOOK CALL, NOT A FREE WIN.** 3600×5700 on a PSX low-poly grunt is far
  beyond what the aesthetic reads at gameplay range. I believe 1024² would be invisible and arguably
  *more* correct for the target era. **But that is an opinion about his eyes, and RULE #1 says his eyes
  decide. Ranked below (a) and (b) deliberately, and flagged as a look change.**

### 5.5 — `meshes/create_shadow_meshes=true` on all 362 GLB imports · LOOK-FREE · small, certain

**Measured: 362/362 `.glb.import` files set `create_shadow_meshes=true`.** The ship runs
`shadow_enabled = false` (`scripts/levels/game_world.gd:48`, per ledger `:36`) and the far cards
explicitly disable shadow casting (`tree_cover_layer.gd:309`). **Every shadow mesh in the project is
therefore built, stored and never used.** Turning it off costs import time and memory only — it cannot
change a pixel while shadows are off. Small win, zero risk, and it stops the project carrying a
duplicate index buffer per mesh.
**Caveat, stated honestly:** if shadows are ever turned back on, these must be restored. The ledger says
shadows cost ~10.5 FPS and are staying off, so this is safe today.

### 5.6 — `assets/world/vegetation/cards/tex/` is an exact 14.5 MB duplicate set · LOOK-FREE · repo hygiene, not FPS

**Measured: all 40 files in `cards/tex/` are byte-identical to their `cards/*_card_*.png` counterparts
(40/40 MD5 matches).** 14.5 MB of the repo duplicated, and **both sets carry `.import` files**, so both
are project resources. This costs **disk and repo weight, not frame time** (Godot loads textures on
demand and nothing references `cards/tex/`). Flagged under the standing art-storage-bloat law, not as an
FPS item, and I am not claiming otherwise.

### 5.7 — `fsb_main.glb` 94 → 48 materials · LOOK-FREE · expect ~0 FPS, do it for hygiene

See §3. 46 exact-duplicate materials, concentrated in `Crate_Post_Wood_*` ×20, `Crate_Wood.00N` ×10,
`OliveDrab.00N` ×8, `BarbedWireMetal.00N` ×7, `Crate_Metal.00N` ×5 — all untextured flat colours.
**Explicitly ranked last among look-free items** because `PERF_LEDGER.md:98-100` measured a 77-call cut
at ~0 FPS and this is the same order of magnitude. **Do not sell this as an FPS win.**

### 5.8 — Village/temple palette de-duplication · LOOK-FREE · unmeasured, plausibly worth more than 5.7

26 copies of one `jungle_palette`, 13 of one `vil_thatch`, 28 of one `temple_laterite` (§2.4). Sharing
one texture + one material per family would let two adjacent thatch huts batch. Requires changing
`tools/gen_village.py` / `tools/gen_temples.py` to reference a shared external texture rather than
embedding, then re-exporting **all 55 GLBs** — this is a re-export wave, not a flag flip. **Higher work
cost than everything above it; listed for completeness, not recommended first.**

### NOT a win — recorded so nobody re-litigates it

- **`jungle_atlas` ×40 material duplication in veg solids** — real, but the near ring resolves to ~1
  visible node (ledger `:912-914`) and the palette is 17×1 px. **Costs nothing. Leave it.**
- **Water** — already one mesh, one material (`water_system.gd:239`). **Nothing to take.**
- **Firebase textures** — already mode=2 + mipmaps. **Nothing to take.**
- **Village/temple textures** — already mode=2 + mipmaps. **Nothing to take.**
- **Triangle counts anywhere** — style, not perf, per standing measurement. **Not proposed.**

---

## 6. WHAT I COULD NOT SETTLE STATICALLY

Stated plainly rather than estimated:

- How many of `fsb_main.glb`'s **204 surfaces** are in frustum at the spawn pose. Authored count is an
  upper bound, not a draw-call count.
- How many characters are visible at the spawn pose, and therefore what share of the frame the 71–81
  surfaces per grunt actually claim.
- Whether Godot's importer collapses any of the 46 duplicate `fsb_main` materials at import time. I
  read the glTF, not the imported `.scn`. **My reading of the importer is that it does not** — it
  creates one `StandardMaterial3D` per glTF material — but I did not verify it against the imported
  resource, so I am labelling this an **opinion**.
- The actual fill cost of alpha-BLEND vs alpha-scissor on this specific GPU at this specific pose.
- Whether `fsb_main_Sandbags.png` carries meaningful alpha (decides OPAQUE vs ALPHA_SCISSOR in §5.2).

---

## 7. MEASUREMENT REQUESTS (for the measurement-engineer's batch)

Each is A/B/A bracketed, windowed, at seed 47225 / scale 0.75 / forward_plus, from the `fsb_main` spawn
pose. I have ordered them by what I expect to be most informative per minute of his time.

- **[MEASURE-3] Card alpha mode.** A: ship. B: `material_override` on the far-card MMIs
  (`tree_cover_layer.gd:135`) with a **shared per-species** `StandardMaterial3D`,
  `TRANSPARENCY_ALPHA_SCISSOR`, threshold 0.4. A. → *Does moving ~1,000 far cards out of the
  transparent pass move the frame?* **This is the single highest-value question in my lens.**
- **[MEASURE-1] Firebase surface attribution.** A: ship. B: hide the `fsb_main` node
  (`site_planner.gd:818` sets `model_name = "fsb_main"`; find and toggle `.visible`). A. → *What share
  of the 411–464 non-canopy calls, and of the frame, is the firebase?* Pairs with a draw-call read.
- **[MEASURE-4] Backface culling.** A: ship. B: walk the tree and set `cull_mode = CULL_BACK` on every
  material **except** the 40 cards, the 7 BLEND veg leaf materials, `mat_bwire_card` and thatch/canvas.
  A. → *Is 100%-double-sided costing real fill?*
- **[MEASURE-2] Character attribution.** A: ship. B: hide the 14 garrison men
  (`FSB_GARRISON_POSTS`, `site_planner.gd:681-694`). A. → *What does a 71–81-surface character
  actually cost, and how many are in frustum?* Note this moves CPU **and** GPU, so it is an
  attribution probe, not a lever.
- **[MEASURE-5] Character texture compression.** A: ship. B: flip
  `assets/{us,nva_vc,civilians}/characters/*.png.import` to `compress/mode=2`, reimport. A.
  → *Does ~680 MB → ~170 MB of RGBA8 move the frame on shared-memory Intel UHD?* Cheap to try, and the
  VRAM figure is certain even if the FPS delta is not.

**A draw-call read (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`) should accompany every bracket** —
it is free, it is not a GPU-timing number, and it is the only way to confirm a material change did what
it was meant to do rather than what we hoped.

---

## 8. VERDICT IN ONE PARAGRAPH

The canopy is still the call story and the impostor wave did not change it — **27 species scatter, not
40**, and the 13 extra cards are inert. But the census turned up a **fill** story the ledger never
attributed: **every material in the project is double-sided, all 40 canopy cards are alpha-BLEND rather
than alpha-scissor, and 20 of `fsb_main.glb`'s 94 materials — the sandbags filling the screen at the
exact 34-FPS pose — are also alpha-BLEND.** Since the ledger's own diagnosis names full-screen fragment
work as the limiter, that is where the asset side should look, and every one of those three is a flag,
not a rebuild. The firebase 9→5 atlas claim is **inapplicable**: the 23 nine-slot assets it describes do
not exist in Godot, the 7 `fb_*` textures are referenced by nothing, and the real firebase material
problem is 46 duplicate materials and 20 BLEND ones. Finally, **19 copies of a 3600×5700 character
texture, 18 byte-identical, all imported lossless** is ~680 MB of RGBA8 on an integrated GPU that shares
system memory — the `compress/mode=2` half of that fix is genuinely free and I would take it on
principle even if the frame does not move.
