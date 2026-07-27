# GODOT-SPECIALIST — engine-internals analysis

**Session:** 2026-07-26 FPS deep dive · **Lens:** Godot 4.7 engine internals, MultiMesh/atlas/shader path
**Method:** static read of the repo as of 2026-07-26 + direct binary read of the glTF JSON chunks of 355
`.glb` assets. **No Godot was launched.** No GPU number below is mine — every FPS figure quoted is from
`production/PERF_LEDGER.md` with its own config.

**POINTER LAW:** every code claim below carries a `file:line` verified today. Claims about *engine*
behaviour (Godot's own source) are labelled **[engine fact]**. Anything I could not verify without a
windowed or headless run is labelled **[UNSETTLED]** and routed to the measurement batch in §5.

---

## 0. DRIFT CORRECTED ON CONTACT (NO-DRIFT law)

The briefing and the ledger cite line numbers that have moved. Corrected here, in the same change:

| Cited as | Actually, today |
|---|---|
| `game_world.gd:48` (sun shadow off) — briefing §1, `ADR-026:39` | **`scripts/levels/game_world.gd:52`** |
| `tree_cover_layer.gd:105` (group key) — briefing §1 | **`terrain/vegetation/tree_cover_layer.gd:110`** |
| `tree_cover_layer.gd:52` (BUCKET) — briefing §1 | **`:52`** ✔ (ledger's `:47` is stale) |
| `tree_cover_layer.gd:125 / :128` (two MMIs) — briefing §1 | **`:132` (near solid) / `:135` (far card)** |
| `tree_cover_layer.gd:47-51` (visibility_range comment) | **`:49-52`** |
| `tree_cover_layer.gd:199` `_extract_mesh` — `PERF_LEDGER.md:907` | **`:323`** |
| "**27** card textures, each its own PNG" — `PERF_LEDGER.md:932` | **40 card GLBs + 40 PNGs exist on disk; exactly 27 species are LOADED.** Both numbers are true and the ledger conflated them. See §1.1. |
| `ADR-026:164` — "foliage `view_distance` 128m → 80m LANDED", citing `jungle_patch_layer.gd:73` | **That path does not ship.** `world_config.gd:21` `USE_TREE_COVER = true` routes the canopy to `TreeCoverLayer`, whose card ring is **350m** (`tree_cover_layer.gd:46`). The ADR's "80m foliage" line describes a renderer the game no longer uses. |

One more, load-bearing: `vegetation_manager.gd:40` declares `canopy_source = CanopySource.JUNGLE_PATCH`
as the **default**, and the class comment at `:34-38` still calls JUNGLE_PATCH "the shipped merged-patch
render" and TREE_COVER "the look-check-gated switchover — do NOT wire it live". **It is wired live.**
`scripts/levels/game_world.gd:100-101` overrides the default from `WorldConfig.USE_TREE_COVER`, and
`scripts/levels/world_config.gd:21` sets that `true`. The comment is a fossil-shaped lie in the map.
It should be corrected.

---

## 1. THE ATLAS QUESTION — VERIFIED AGAINST THE REPO TODAY

### 1.1 Census: what is actually on disk, and what actually loads

**Verified by directory listing + glTF JSON read, 2026-07-26.**

- `assets/world/vegetation/cards/` holds **40 `_card.glb` + 40 extracted PNGs** (`CARD_DIR`,
  `tree_cover_layer.gd:15`). All dated 2026-07-17 — i.e. **the impostor wave predates the 2026-07-20
  ledger measurement.** Nothing about the far-card ring has changed in six days. The ledger's canopy
  attribution is still current.
- `assets/world/vegetation/` holds **47 solid GLBs** (`SOLID_DIR`, `:14`).
- **Only 27 species load.** `vegetation_manager.gd:128-133` `_all_species()` returns the unique union of
  the five `TYPE_SPECIES` pools at `:48-55`; I enumerated it by hand: rice_a/b, tall_grass_a/b,
  elephant_grass_a/b, bush_a/b/c, fern_a/b/c, banana_a/b, palm_sapling_a, jungle_palm_a1/a2/b1/b2,
  broadleaf_a/b/c, bamboo_a/b/c, liana_a, vine_a = **27**. That is fed to `load_species`
  (`vegetation_manager.gd:118` → `tree_cover_layer.gd:85`). **The ledger's "27" is correct as a count of
  LIVE materials.** Its "×27 PNGs" is wrong as a disk count — there are 40, and **13 card assets
  (grass_fan, grass_tuft_a/b/c, elephant_grass_c, jungle_palm_a3/b3, palm_sapling_b, tall_grass_c,
  liana_b, vine_b, trunk_vine_a/b) are imported by the editor and referenced by nothing.**
  Hygiene, not frame cost — they occupy no VRAM because nothing loads them.
- Far-card ring maths, re-derived and confirming the ledger: buckets in a 350m radius at `BUCKET = 64.0`
  (`:52`) = π·350²/64² = **94.0**. × ~17.6 species present per bucket ≈ 1,654 far nodes, of which the
  ledger measured ~1,670 inside `visibility_range` and **957–1,017 surviving frustum culling**
  (`PERF_LEDGER.md:896-898`). The model reproduces the measurement. **The pinning stands.**

### 1.2 The bake tool: STILL NOT IN THE REPO — confirmed

I read every candidate the briefing named and grepped the whole tree:

- `tools/make_jungle_flora.py` (952 lines) — the word "card" appears only in prose at `:4` and `:11`,
  both arguing *against* flat cards. No card generator.
- `tools/make_jungle_vegetation.py` (587 lines) — one card, the star-fan grass at `:521`. Not an
  impostor baker.
- `tools/make_jungle_patches.py`, `tools/add_variants.py`, `tools/assemble_sheets.py` — **zero** hits
  for "card".
- Repo-wide: `grep -ril impostor --include=*.py` returns **no tool at all** — only docs and
  `tools/gen_firebase_textures.py` (firebase wire, unrelated).
- `grep -rl "_card" --include=*.py` returns `extract_fsb_sources.py`, `gen_firebase*.py`,
  `make_helmet_decals.py` — none of them vegetation.

**Verdict: the bake tool is not in the repo, six days on. The ledger's blocker is factually intact.**
The pipeline exists only in the memory note `recongame-impostor-foliage` (Blender orthographic render →
transparent PNG → quad), and in Caleb's head.

**But — and this is the finding — the atlas does not need the bake tool.** See §1.4.

### 1.3 THE ENGINE ANSWER to "does one shared material actually collapse the calls?"

**No. A shared material alone collapses nothing.** [engine fact]

Godot 4's 3D renderer has **no automatic draw-call batching across `GeometryInstance3D` nodes.** Every
`MultiMeshInstance3D` is a distinct `RenderingServer` instance and submits at least one draw per
surface, regardless of whether the material is byte-identical to its neighbour's. Sharing a material
buys **state-change / pipeline-bind savings inside a pass**, not call savings. This is precisely why
the ledger's pinning is correct that "the call count IS the node count"
(`PERF_LEDGER.md:904-905`) — the canopy already shares materials per species and it still costs ~1,000
calls.

The collapse therefore comes from **merging the INSTANCE ARRAYS**, not from merging the materials: one
`MultiMesh` per bucket carrying every species' instances. A single `MultiMesh` demands a single `Mesh`
with a single surface, which is what forces the unit-quad + atlas/array-texture design. **The material
unification is a prerequisite of the merge, not the mechanism.**

**Does per-node `visibility_range` obstruct the merge?** No. `visibility_range_begin/end` are properties
of the **node** (`GeometryInstance3D`), not of the material or the instance
(`tree_cover_layer.gd:311-314`). Collapsing a bucket to one node gives that bucket one range — which is
exactly what we want. `visibility_range` is not a blocker; it is a **look tax**, and here is its exact
shape:

> Today each far node's AABB is the bounding box of *one species' instances inside a 64m bucket* — often
> a handful of trees spanning 10–20m. After the merge the node's AABB is the *whole 64m bucket*.
> Since the range test runs against the **transformed AABB**, not the origin (godot#79471, recorded at
> `tree_cover_layer.gd:49-52`), the near/far handoff quantisation gets **worse for the far ring while the
> near ring keeps its tight per-species AABBs** — an *asymmetric* handoff. That can produce either a
> double-drawn band (card + solid both on) or a thin gap at the 65m boundary
> (`near_distance`, `:45`). This is the same defect family as the historical invisible-jungle bug,
> at reduced magnitude. **It is a LOOK risk and must be look-checked by Caleb's eyes, not by a counter.**
>
> **The mitigation is bought by the atlas itself:** once a bucket costs ~1–2 calls instead of ~17.6, you
> can afford a **finer** `BUCKET`. At `BUCKET = 32` the far ring costs π·350²/32² ≈ 376 buckets × ~2 =
> ~750 calls — worse than 64. At `BUCKET = 48`: 167 × 2 = 334. So the sweet spot stays near 64, and the
> honest statement is: the atlas does **not** hand back a free tightening; it hands back the *option* at
> a price. Keep 64 and look-check the handoff.

### 1.4 THE COST, HONESTLY — and it is MUCH cheaper than the ledger says

The ledger cost this as "writing the bake pipeline from scratch, plus a unit-quad mesh with per-instance
UV-rect custom data and a shader to read it, plus re-deriving each card's aspect into the instance
transform… a new far-card renderer path" (`PERF_LEDGER.md:936-939`). **Three of those four items are
already solved in the repo or are free. I am revising the estimate down.**

**(a) No re-bake is needed. Use a `Texture2DArray`, not an atlas.** [engine fact]
The 27 impostor PNGs *already exist* and are already the orthographic renders. A `Texture2DArray` is
built at runtime from loaded `Image`s in ~10 lines (`Texture2DArray.create_from_images()`), sampled in a
spatial shader as `texture(sampler2DArray, vec3(UV, layer))`. The per-instance **layer index** rides in
`MultiMesh.use_custom_data` → `set_instance_custom_data(i, Color(layer,0,0,0))` → read in the shader as
`INSTANCE_CUSTOM.x`. **This eliminates the atlas packer, the UV-rect maths, and the bake tool entirely.**
The only asset requirement is uniform dimensions per array, satisfied by `Image.resize()` at load.

**(b) The aspect is already in the repo — derive it, do not author it.**
`tree_cover_layer.gd:323-332` `_extract_mesh` already returns the card `Mesh`. Its `get_aabb()` gives
the exact world width and height of every species' card (I read them straight out of the glTF
accessors today: `broadleaf_a_card` is 4.28 × 8.57m, `fern_a_card` 2.05 × 0.60m, `vine_a_card`
0.33 × 2.39m). Fold that into the instance basis scale in the loop at `:128-130`. **Zero new tooling.**
`tools/diag_veg_cards.gd:19-21` already reads exactly these AABBs — the probe exists.

**(c) The shader is 80% written and already in the repo — and the shipping canopy is not using it.**
`terrain/shaders/vegetation_sway.gdshader` already: declares `ALPHA_SCISSOR_THRESHOLD` in `fragment()`;
guards its wind maths with the 4.7 `IN_SHADOW_PASS` built-in; and reads per-MultiMesh-instance world
origin from `MODEL_MATRIX[3]` for wind phase. It is used by `scripts/world/ground_clutter.gd:22`,
`terrain/vegetation/jungle_patch_layer.gd:8`, `ai_stress_arena.gd:539`, `gore_lab.gd:159` — and
**by nothing in `tree_cover_layer.gd`** (zero references; `_extract_mesh:323-332`'s own comment says it
returns the GLB mesh "with its own materials"). Adding `uniform sampler2DArray` + `INSTANCE_CUSTOM.x` is
a ~15-line diff to a shader that already exists and already ships elsewhere.

**(d) Crossed vs single quads.** Read today from the glTF: trees/palms/bamboo/banana export **8 verts /
12 indices** (crossed, 2 quads, non-zero Z extent); grass/fern/vine/liana export **4 verts / 6 indices**
(single quad, Z extent exactly 0). So **two unit meshes are needed, not one** → **~2 nodes per bucket**,
not 1. Corrected win: **94 buckets × 2 = ~188 far-card calls, replacing ~957–1,017.** That is
**~5.3×, not ~10×.** The ledger's "~94 calls" figure assumed a single unit mesh and is optimistic.
(You *could* force everything onto the crossed quad and take ~94 calls — 2 extra tris per grass tuft,
and "tri budgets are style not perf" — but grass rendered crossed reads visually denser. Name it as a
look change, do not slip it in.)

**Cost estimate, honest:**

| Item | Real work |
|---|---|
| `Texture2DArray` builder (2 arrays: crossed / single), uniform resize at load | 0.5 day |
| Extend `vegetation_sway.gdshader` with `sampler2DArray` + `INSTANCE_CUSTOM.x` layer | 0.25 day |
| Rework `generate_for_chunk` `:101-153`: merge far groups per bucket, derive aspect from card AABB, write custom data | 1 day |
| Fossil-law deletion + probe/test updates (see below) | 0.5 day |
| Look-check iterations with Caleb (handoff band, card density read) | 1 day, his clock |
| **Total** | **~2.5 engineering days + a look-check gate** |

Not "a new pipeline". Not "a one-liner" either. **~2.5 days.**

**Expected win, stated as a bound not a promise.** Removing the canopy entirely is worth +6.3 / +7.8 /
+8.0 FPS (`PERF_LEDGER.md:875-878`). The atlas removes ~80% of its draw calls and **0% of its
primitives, pixels or texture bytes.** If the canopy is purely call-bound, expect ~+5 to +6.4. If any
material part of that delta is fill or texture bandwidth, the atlas banks proportionally less.
**Which it is has never been measured**, and §2.2 gives the cheap experiment that settles it.
**Do not start the atlas before that experiment runs.**

**FOSSIL LAW — what must die when this ships (ADR-023):**
1. `CARD_DIR` per-species `_card.glb` files and their extracted PNGs — the unit-quad + array supersedes
   them. All 40, including the 13 already dead.
2. `_card_mesh` (`tree_cover_layer.gd:56`) and the card branch of `_extract_mesh`'s call site at `:91-94`.
3. The `solid: bool` far branch of `_multimesh` (`:297-319`, `:134-135`) — cards and solids stop sharing
   the emitter.
4. `tools/diag_veg_cards.gd` — its entire subject (per-species card AABB vs solid anchor) evaporates.
5. `tests/test_tree_cover_lod.gd` and `tests/veg_lod_lookcheck.gd` reference `_card`; they must be
   ported in the same change, not left asserting a dead shape.

**RISKS, named:**
- **The handoff asymmetry in §1.3.** Look risk. Mitigated only by Caleb's eyes.
- **Texture detail loss.** A `Texture2DArray` forces one resolution per array. The live cards range from
  768×131 (`fern_b`) to 768×5508 (`vine_a`) — an 11:1 aspect spread. Resizing everything to a common
  size squashes texel density on the extremes. Vines and lianas will lose the most. **Two arrays
  (crossed/single) partly sorts this because the extreme aspects are all single-quad.** Still a look
  risk; screenshot the vine-heavy HEAVY_JUNGLE band before/after.
- **Per-species tint/material variance is lost.** Verified today: every card GLB carries exactly **one
  material** and no per-species shader parameters, so nothing is actually lost. Low risk.
- **Shadows.** Cards already set `SHADOW_CASTING_SETTING_OFF` (`:309`) and the sun casts none
  (`game_world.gd:52`). No interaction.

---

## 2. THE LEVERS NOBODY HAS TAKEN — engine level

These are ranked **look-free first**, per RULE #1.

### 2.1 ★ THE CARDS ARE ALPHA-**BLEND**. THEY SHOULD BE ALPHA-SCISSOR. THIS IS AN ADR-026 VIOLATION.

**This is my headline finding and it is the cheapest real lever in the frame.**

**Verified today by reading the glTF JSON chunk of every card GLB:** all **40** declare
`"alphaMode": "BLEND"` and `"doubleSided": true`. Zero declare `MASK`. (For contrast, **45 of the 47
solid GLBs are `OPAQUE`** — only `grass_fan` and the six `jungle_palm_*` carry a BLEND surface, matching
the ledger's "4 palms carry 2 surfaces" at `PERF_LEDGER.md:907`.)

`tree_cover_layer.gd:323-332` `_extract_mesh` returns the imported mesh **with the GLB's own materials**
and nothing anywhere overrides them. So whatever Godot's glTF importer builds from `alphaMode: BLEND` is
what ~1,000 far-card nodes render with, every frame.

**Why this is expensive** [engine fact]: `alphaMode: BLEND` imports as a `TRANSPARENCY_ALPHA*` mode.
Either mapping is bad here:
- it puts all ~1,000 card nodes in the **transparent pass**, which is **depth-sorted per object on the
  CPU every frame** and cannot early-Z;
- transparent geometry **writes no depth**, so nothing behind a card is rejected — in a 350m ring of
  overlapping foliage this is the worst-case overdraw pattern on an Intel UHD;
- and `doubleSided: true` imports as `CULL_DISABLED`, doubling fragment work on every quad. Legitimate
  for a crossed card; **not** legitimate for the single-quad species, which are exactly the ones with
  the biggest textures (vines, lianas).

**Exactly which `TRANSPARENCY_*` constant the 4.7 importer picks is [UNSETTLED]** — Godot has mapped
BLEND to `TRANSPARENCY_ALPHA_DEPTH_PRE_PASS` in some versions, which would mean **each card node is
submitted twice per frame**. I will not assert which without evidence. **The repo already contains the
probe that settles it**: `tests/test_veg_material.gd` dumps `transparency`, `cull_mode` and
`alpha_scissor_threshold` for solids and cards. It reads resource data, not GPU timings, so **headless
is valid here — this is not RendererDummy fiction.** It needs one card-species line added
(`NAMES` at `:8` only covers 7 species and only two cards are dumped, `:16-17`).

**Why this is an ADR-026 compliance defect, not a new proposal:**
- `ADR-026:30` — Part A.1 assumes the sun shadow sits "over **alpha-scissor** jungle."
- `ADR-026:63` — Part A.3 binds: "Single-side (back-face cull) any surface whose back is never seen;
  keep `cull_disabled` **only** where a single-plane billboard genuinely needs both faces."
- `scripts/world/ground_clutter.gd:103-105` already does it correctly:
  `TRANSPARENCY_ALPHA_SCISSOR`, `alpha_scissor_threshold = 0.4`.
- `terrain/shaders/vegetation_sway.gdshader` already does it correctly for the *retired* patch canopy.

**The shipping canopy is the one subsystem that does it wrong.** This is the divergent-systems pattern
exactly: the correct renderer path exists and the live path does not use it.

**Does it cost the look?** **Arguably it improves it.** Alpha-scissor is the PSX/PS2-correct read
(hard-edged foliage), it kills the per-object sorting pop that BLEND cards will exhibit against each
other, and it is what the memory note records as the *original intent* ("fix = alpha-CLIP not BLEND").
The soft feathered edge is lost. At 65–350m through `fog_density = 0.0065` (`game_world.gd:76`), at
`scaling_3d/scale = 0.75` with **nearest** filtering and no AA, I do not expect that edge to be visible
— **but that is my opinion and Caleb's eyes rule, so screenshot it.**

**Two ways to fix, and they are not equivalent:**
- **Right fix (source):** re-export the cards with glTF `alphaMode: MASK` + `alphaCutoff`. Blocked —
  the bake tool is not in the repo (§1.2).
- **Available fix (runtime, ~15 lines):** in `load_species` (`tree_cover_layer.gd:85-94`), after
  `_extract_mesh`, walk `mesh.surface_get_material(i)` and set
  `transparency = TRANSPARENCY_ALPHA_SCISSOR`, `alpha_scissor_threshold ≈ 0.4`, and `cull_mode =
  CULL_BACK` for the **single-quad** species only (keep `CULL_DISABLED` for crossed). Meshes are loaded
  once and shared, so one mutation covers every instance. **Under one hour of work.**
  Guard it with a line in `tests/test_veg_material.gd` so it cannot silently regress.

**Ranking: #1. Lowest cost, ADR-mandated, look-neutral-to-positive, and it is the only lever here that
attacks OVERDRAW rather than call count — the half of the canopy cost the atlas does not touch.**

### 2.2 ★ 121 MB OF **UNCOMPRESSED** CARD TEXTURES — and the experiment that settles the atlas

**Verified today.** Every card PNG imports with `compress/mode=0` (Lossless) and
`metadata={"vram_texture": false}` — read from
`assets/world/vegetation/cards/broadleaf_a_card_broadleaf_a.png.import`, and the same block is present
on all 40. `mipmaps/generate=true`. So they are resident as **RGBA8 + mips**.

I summed the PNG headers directly:

| set | resident texture memory (RGBA8 + mips) |
|---|---|
| the **27 species that load** | **121.5 MB** |
| all 40 on disk | 231.7 MB |

Worst offenders among the **live** 27: `vine_a` 768×5508 (16.9 MB), `liana_a` 768×4539 (13.9 MB),
`bamboo_c` 768×2473 (7.6 MB). Two vine/liana species alone are ~30 MB — a quarter of the budget — for
mostly-empty alpha.

On an Intel UHD (shared system memory, no dedicated VRAM, modest bandwidth), 121 MB of alpha textures
sampled across a 350m foliage ring is a plausible bandwidth cost. **VRAM compression (`compress/mode=2`,
BPTC/BC7) cuts that ~4× to ~30 MB, with near-lossless quality at impostor distance.** Cost to look:
BC block artefacts on alpha edges — small at 65–350m. Cost to build: an import-setting change on 40
files, minutes, plus a reimport.

**AND — this is the important part — it is the perfect discriminating experiment.**

The atlas rests entirely on the claim that the canopy is **call-bound**. That claim is inferred from
"canopy = 85% of calls but only 12% of prims" (`PERF_LEDGER.md:877`). **It has never been tested against
the third possibility: texture bandwidth.** `no_canopy` removes calls, prims, fill **and** 121 MB of
texture sampling all at once, so it cannot tell them apart.

> **VRAM-compressing the card textures changes ZERO draw calls and ZERO primitives. It changes only
> bytes touched.**
>
> - If FPS moves ⇒ the frame is (partly) **bandwidth-bound**, and the atlas is over-sold.
> - If FPS does not move ⇒ **call-bound is confirmed**, and the atlas is the right 2.5 days.

**This is a ~30-minute A/B/A that de-risks a 2.5-day build. Run it before the atlas. Ranking: #2.**

Related hygiene, no look cost: `process/size_limit=0` on every card. Capping the extreme-aspect
single-quad species (vines, lianas, trunk_vines) to 1024 on the long axis would cut a further large
slice. **Look-costing at the margin — rank below the compression change.**

### 2.3 ★ THE SHIPPING CANOPY HAS NO WIND, AND THE SHADER FOR IT ALREADY EXISTS

Not an FPS lever — a **look** lever I am obliged to report because RULE #1 outranks FPS. The
ground clutter at your boots sways (`ground_clutter.gd:22`), the *retired* patch canopy swayed
(`jungle_patch_layer.gd:8`), and the **live** jungle from 0–350m is completely static, because
`tree_cover_layer.gd` never touches `vegetation_sway.gdshader`. If the far ring moves to that shader for
the atlas (§1.4c), wind comes along for free — and `IN_SHADOW_PASS` is already guarded in it, so there
is no shadow-pass cost even if shadows ever return.

### 2.4 fsb_main.glb — 204 surfaces and 19 opaque-looking BLEND materials AT THE SPAWN POSE

The shipped baseline is measured **stationary at the `fsb_main` spawn** (`PERF_LEDGER.md:679`). I read
that GLB's JSON chunk today:

- **681 nodes, 202 meshes, 204 surfaces, 94 materials, 9 images.**
- `scripts/world/site_planner.gd:644` instantiates the whole scene. It is the only firebase asset loaded
  at runtime (verified: no other `structures/firebase` path is referenced from `scripts/` or `terrain/`).
- **204 surfaces is up to 204 draw calls from one building** — against a measured 411–464
  canopy-hidden total (`PERF_LEDGER.md:897`). The firebase plausibly owns **half the non-canopy frame.**
  [UNSETTLED as an attribution — needs the windowed toggle in §5.]
- **19 materials named `Sandbags`, `Sandbags.002`…`Sandbags.071` are `alphaMode: BLEND`,
  `doubleSided: true`.** Sandbags are not translucent. This is a Blender export defect, and it means
  ~19 opaque surfaces render in the **transparent pass** — no depth write, double-sided fragment work,
  and, worst of all, **they occlude nothing**, so the jungle behind the berm is fully shaded instead of
  being early-Z rejected. Directly violates `ADR-026:63`.
  The only legitimately-alpha material in the file is `mat_bwire_card` (the wire impostor), and even
  that should be `MASK`.
- Elsewhere: `structures/converted/helipad.glb` is **44/55 BLEND** (a helipad is concrete — pure
  defect), and `kit/fb_sandbag_heavy.glb` / `fb_sandbag_light.glb` are BLEND. Neither is loaded at
  runtime today, so neither costs frame — but both are source for future placement and will carry the
  defect forward if re-exported as-is.

**Fix:** same runtime-material pass as §2.1 applied at `site_planner.gd` placement, or a re-export.
**Look cost: zero — sandbags are meant to be opaque.** Ranking: **#3, tied with §2.1 in character,
lower in magnitude only because the count is 19 not 1,000.**

### 2.5 THE FIREBASE "9 → 5 ATLAS FAMILIES IS THE REAL PERFORMANCE LEVER" CLAIM — RULED

`production/firebase_kit_phase1_read.md:261-263`. Verdict: **mechanism half-right, conclusion not
supported, and irrelevant to today's frame.**

1. **"one placed asset can cost up to 9 draw calls" is TRUE** [engine fact] — surfaces within one mesh
   carrying different materials are separate draws.
2. **"collapsing 9 → 5 atlas families" only helps if it collapses SURFACES.** Reducing the *material
   count* while leaving nine surfaces changes nothing: Godot does not batch 3D draws across surfaces or
   nodes (§1.3). If the atlas genuinely merges nine surfaces into five, it cuts calls; if it merely
   re-textures, it cuts zero. The doc does not distinguish, so as written it is **unproven.**
3. **It is moot today.** I enumerated the kit: **only four `fb_*.glb` exist repo-wide**
   (`fb_FoxholeSandbags`, `fb_gate_assembly`, `fb_sandbag_heavy`, `fb_sandbag_light`), carrying
   **1, 5, 1, 1 surfaces — never 9** — and **none of them is loaded at runtime.** The same doc says so
   at `:268`: "Nothing is exported to .glb yet." **The 23-asset 9-slot kit is not in the frame. This
   claim cannot be a lever until the kit ships.** Label it unproven and park it.

Meanwhile **the real firebase draw-call problem is `fsb_main.glb`'s 204 surfaces** (§2.4), which the
kit rule does not touch at all.

---

## 3. THE 4.7 / ENGINE LEVER SWEEP — each ruled with evidence

| Lever | Current state | Ruling |
|---|---|---|
| **Nearest-neighbour 3D scaling (4.7)** | `project.godot:307` `scaling_3d/mode=5`, `:308` `scale=0.75` | **ALREADY TAKEN.** Ratified `ADR-026:67-68, :139`. The 4.7 brief's single best aesthetic-aligned win is banked. Nothing to do. |
| **FSR / FSR2** | `:309` `fsr_sharpness=0.3` is a **dead setting** (only read in FSR modes) | **NOT A LEVER — reject.** FSR1 *adds* GPU cost (EASU/RCAS) on a GPU-starved frame; FSR2 is temporal, needs motion vectors, and would ghost 1,000 alpha foliage cards catastrophically. Both also blur, which fights the PSX read. The 2026-07-12 audit's E2 recommendation (`GAME_AUDIT_2026-07-12.md:126`) is **superseded** by the 4.7 nearest filter. *Hygiene: delete the dead `fsr_sharpness` line.* |
| **`scaling_3d/scale` below 0.75** | 0.75 = 56% of native pixels | **REAL, and the biggest remaining GPU lever — but LOOK-COSTING.** 0.75→0.65 cuts fill ~25%. With nearest it reads *more* PSX, not worse. **Ranked below every look-free lever. Screenshot A/B; his eyes rule.** |
| **Occlusion culling (`OccluderInstance3D` / bake)** | **Zero references repo-wide** — not enabled, no occluders | **NOT A LEVER HERE — reject.** Three reasons: (a) Godot's occlusion culling is a **CPU** software rasteriser, and the frame is co-limited with CPU at 44.35ms vs GPU 51.94ms (`PERF_LEDGER.md:200-201`) — it spends the scarcer resource; (b) alpha foliage cards cannot be occluders and are the bulk of the calls; (c) the terrain is generated and streamed at runtime, so the editor bake does not apply — you would have to build `ArrayOccluder3D` per chunk, i.e. **a new system**. Revisit only if the frame ever goes GPU-dominant. |
| **`VisibilityRange` fade modes** | `FADE_DISABLED` (`tree_cover_layer.gd:318`) | **DECIDED, DO NOT REOPEN.** `:315-318` records why: `FADE_SELF` alpha-dithers across the margin and renders trees **see-through**. It is also *more* expensive (dither work + forces alpha). The `RANGE_MARGIN = 8.0` (`:53`) hysteresis is correct as written — in `FADE_DISABLED` the margin genuinely acts as hysteresis [engine fact]. Leave it. |
| **Mesh LOD** | `project.godot:310` `threshold_pixels=2.0` (default 1.0 — already aggressive); GLB imports set `meshes/generate_lods=true` | **ALREADY TUNED, and irrelevant.** The near ring costs ~0 calls (`PERF_LEDGER.md:917`) and cards are 2–4 triangle quads with nothing to LOD. Not a lever. |
| **Shadow atlas / directional shadow settings** | `game_world.gd:52` `shadow_enabled = false` | **DEAD BY CONSTRUCTION.** No shadow pass exists, so no atlas setting can matter. Guarded by `tests/test_ship_parity.tscn`. Per briefing: not re-litigated. |
| **MSAA / TAA / SMAA** | No `anti_aliasing/quality/msaa_3d` key ⇒ default **off**. No TAA key ⇒ off. | **CORRECTLY OFF — do not enable.** At 0.75 nearest, no-AA *is* the PSX call. `ADR-026:139` already states MSAA off. Nothing to gain. |
| **Debanding** | `project.godot:306` `use_debanding=true` | Fullscreen noise pass, sub-0.1ms class. **Keep.** Not worth measuring. |
| **Glow / SSAO / SSR / SDFGI / VoxelGI** | Read `game_world.gd:60-81` in full: `background_mode = BG_SKY` (`:65`), `ambient_light_source = AMBIENT_SOURCE_SKY` (`:67`), fog only. **None of glow, SSAO, SSR, SDFGI or VoxelGI is ever enabled.** | **NOTHING TO TURN OFF. This box is already empty** — worth stating so the ledger stops implying otherwise. The 4.6 "SSR overhaul is cheaper now" note is a **non-lever** here: SSR is off and should stay off. |
| **Volumetric fog** | `:74-77` uses plain **depth fog** (`fog_enabled`, `fog_density=0.0065`, `fog_aerial_perspective=1.0`). `volumetric_fog_enabled` never set. | **Already the cheap path. Do not enable volumetric fog.** Also means the 4.7 transmittance-blending gotcha does **not** apply to this project — a stale worry in the 4.7 brief for RECON specifically. |
| **HDR output / AreaLight3D / Vulkan RT (4.7)** | Not used | **ANTI-FEATURES on Intel UHD. Never.** |
| **`IN_SHADOW_PASS` (4.7)** | Already used in `vegetation_sway.gdshader:30` | **Correctly exploited — but in the shader the shipping canopy does not use.** Becomes real if §1.4c lands. Worth ~0 today because shadows are off. |
| **Shader Baker (4.5, export-time precompile)** | Not configured in any export preset | **Not an FPS lever — a HITCH lever.** Kills first-material-use stalls (first blood decal, first flash). Zero look cost, zero runtime cost. **Free hygiene; take it at export time.** |
| **`rendering/limits/*`** | No overrides in `project.godot:302-310` | Defaults are fine. `max_fps=120` (`:23`) is irrelevant at ~34 FPS. **Not a lever.** |
| **D3D12 vs Vulkan driver A/B (4.6)** | Not set; Vulkan is in use (`ADR-026:145` confirms `Vulkan 1.3.215 - Forward+` at runtime) | **A legitimate free experiment** — Intel UHD Vulkan drivers are historically weak and this is a one-line project setting, not a renderer change (Forward+ is preserved either way, so ADR-026 Amendment A is untouched). **[UNSETTLED]** — put it in the batch. If it wins it wins for nothing; if it loses, revert. |
| **`physics_ticks_per_second` 60 → 30** | Not set in `project.godot` ⇒ **60Hz default**. `project.godot:300` `common/physics_interpolation=true` is **already ON**. Jolt is the engine (`:298`). | **THE BIGGEST CPU LEVER IN THE FRAME, AND IT IS A ONE-LINE SETTING.** The CPU wall at 65 units is ~38–40ms/tick and is dominated by the **body** — hitzone sync ~10ms + `move_and_slide` ~9ms + execute/anim ~18ms (`PERF_LEDGER.md:296-304`). **All of that is per-physics-tick.** Halving the tick rate halves it. Physics interpolation being already on is what makes 30Hz visually smooth rather than juddery. **Named costs (real):** ~16ms extra input latency on the player capsule; coarser `CharacterBody3D` stepping/slope response; `scripts/combat/ballistics.gd:37` derives its integration `dt` **from `Engine.physics_ticks_per_second`**, so projectile arcs re-integrate at half rate — **grenade/M79/rocket trajectories must be re-verified**, and `tests/test_flat_damage` and the ballistics suite are the gate. This is a **feel** change, not a look change, so it is Caleb's ruling, not mine. **Rank: #1 on the CPU side, and it costs an afternoon to A/B.** |

---

## 4. WHAT IS **NOT** WORTH DOING — kill list with the evidence

So this ledger stops re-litigating:

1. **Sun shadows.** Off at `game_world.gd:52`; the "+10.9/+10.5/+9.8" wins were a bench artifact measured
   and believed **twice**, retracted at `PERF_LEDGER.md:626-635`; at ship parity it reads −0.2, inside
   noise (`:696`). Guarded by `tests/test_ship_parity.tscn`. **Dead.**
2. **The ≤40m shadow cap as a mitigation.** 40m / 80m / uncapped identical within 0.5 FPS
   (`PERF_LEDGER.md:723-730`). **Dead.**
3. **Campfire lights.** 0.0 at seed 47225, unmeasurable at seed 12 night with four fires
   (`PERF_LEDGER.md:846-861`). **Dead.**
4. **Triangle shaving.** Measured: 33% of prims and 77 calls moved FPS ~0. Briefing §4. **Dead.**
5. **Renderer swap.** `ADR-026` Amendment A. **Closed.**
6. **FSR / FSR2.** §3. Adds GPU cost, ghosts foliage, blurs the PSX read. **Reject.**
7. **Occlusion culling.** §3 — spends the scarcer resource (CPU) and cannot see through alpha foliage.
   **Reject for now.**
8. **`VISIBILITY_RANGE_FADE_SELF`.** Renders trees see-through and costs more. **Reject.**
9. **Turning OFF glow/SSAO/SSR/GI.** They were never on. **Nothing there.**
10. **Raising `BUCKET` to 128.** ~2.5× call cut but a **LOOK change** — it doubles the near/far handoff
    quantisation to ±90m, the reduced form of the historical invisible-jungle bug
    (`tree_cover_layer.gd:49-52`). **RULE #1 outranks it. Ranked below every look-free lever, and below
    the atlas which obtains a bigger win without the look cost.**
11. **The firebase 9→5 atlas claim as a *live* lever.** §2.5 — the assets are not exported and not in
    the frame. **Unproven and moot.**

---

## 5. WHAT NEEDS A WINDOWED RUN — my contributions to the measurement batch

Bracket every one A/B/A at **seed 47225, 1280×720, `scaling_3d/scale = 0.75`, forward_plus, stationary
at the `fsb_main` spawn**, single Godot instance, Blender closed. Print the noise floor.

| # | Change under test | Question it answers | Why this one |
|---|---|---|---|
| **M1** | *(headless, valid — resource data, not GPU)* run the existing `tests/test_veg_material.gd` with the card list widened at `:8`/`:16-17` | **Which `TRANSPARENCY_*` mode does 4.7 actually import `alphaMode: BLEND` as, and is `cull_mode` DISABLED?** | Settles §2.1's one [UNSETTLED]. Zero risk, ~1 minute. **Do this first — it is free.** |
| **M2** | Cards forced to `TRANSPARENCY_ALPHA_SCISSOR` (+ `CULL_BACK` on single-quad species) via ~15 lines in `load_species` | **What does moving ~1,000 nodes out of the transparent pass into the opaque pass buy?** | The cheapest real lever, ADR-026-mandated. Capture a screenshot for the look gate. |
| **M3** | Card PNGs reimported at `compress/mode=2` (VRAM/BPTC). **Zero calls, zero prims changed.** | **Is the canopy call-bound or bandwidth-bound?** | **The discriminating experiment. It de-risks the 2.5-day atlas.** Run it before committing to §1.4. |
| **M4** | Hide only `fsb_main`'s mesh subtree (leave collision/markers) | **How much of the 411–464 non-canopy call budget is the firebase's 204 surfaces?** | Settles the census attribution the briefing asks for in §3.1. |
| **M5** | `physics/common/physics_ticks_per_second = 30` | **How much of the CPU 44ms is per-tick body cost?** | The biggest CPU lever, one line. **Gate on the ballistics suite** — `ballistics.gd:37` reads the tick rate. |
| **M6** | `rendering/rendering_device/driver = d3d12` | **Is the Intel UHD Vulkan driver leaving frame on the table?** | Free, reversible, does not touch the decreed renderer. |
| **M7** | `scaling_3d/scale = 0.65` | **How much fill is left, and does he accept the look?** | **LOOK-COSTING. Screenshot A/B is the deliverable, not the FPS number.** |

**Snapshot `project.godot` before the batch and diff-verify the restore afterwards** —
`production/war_room/2026-07-20_overnight_plan/synthesis.md:111` records a hand-restore that has already
gone wrong once.

---

## 6. VERDICT IN ONE PARAGRAPH

The canopy pinning survives verification unchanged, and the bake tool is still absent — but the atlas is
**cheaper than the ledger costs it**, because the blocker was mis-scoped: you do not need an atlas
packer, you need a `Texture2DArray` + `INSTANCE_CUSTOM`, the 27 impostor PNGs already exist, the card
aspects are readable from the mesh AABBs already in memory, and the shader is `vegetation_sway.gdshader`
plus fifteen lines. **~2.5 days, ~5.3× not ~10×** (two unit meshes are needed — crossed and single),
and a merged material collapses nothing on its own: **the win comes from merging the instance arrays,
because Godot never batches 3D draws across nodes.** But before spending those days, take the two
things that cost hours: **the ~1,000 far cards are alpha-BLEND double-sided when ADR-026 already
mandates alpha-scissor and back-face culling, and their textures are 121 MB of uncompressed RGBA8.**
Fixing the first attacks the overdraw the atlas cannot touch; fixing the second is simultaneously a free
win and **the experiment that proves whether the atlas is worth building at all.**
