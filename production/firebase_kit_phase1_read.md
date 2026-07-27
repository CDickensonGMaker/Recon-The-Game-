# Firebase Kit — Phase 1 READ report

**Date:** 2026-07-26 · **Status:** awaiting Summoner's go · **Author:** measured, not recalled.
Every number below was read out of the live scene, the .blend files, or the GLBs with a script.
Nothing here is estimated.

---

## 1. `NEW_sandbag` — what is actually in the file

`assets/world/building models/structures/firebase/kit/NEW_sandbag.blend` (saved 2026-07-26 19:12).

| property | measured value |
|---|---|
| objects | `Camera`, `Light`, **`Cube`** (mesh) — nothing named `NEW_sandbag` |
| tris | 224 (112 quads, no tris, no n-gons) |
| dimensions | **2.984 × 12.681 × 4.213 m** |
| object scale | **(1.0, 5.9391, 1.8877) — not applied** |
| rotation | 0, 0, 0 ✓ |
| local bbox | X −1.533…1.451 · Y −1.057…1.078 · Z −1.000…1.232 |
| origin | mesh centre, **not** base centre, **not** on Z=0 |
| shading | 0 / 112 faces smooth (all flat) |
| UV | one layer, `UVMap` |
| material | `Material` → `sandbag_textures.png` (1140×772) **linked from `C:\Users\caleb\Desktop\recon game image ideas\`** |

**Reading of it.** At 12.68 m long this is not a 50 × 25 × 13 cm bag. Its shape — a subdivided
slab with a low-frequency lumpy face and a photo of stacked bags on it — matches the mid-session
instruction exactly ("the outer face is a low-frequency lumpy surface … per-bag offset ±3 cm").
So I read it as **the surface-treatment prototype for the wall body**, not as a bag mesh.
Confirmed before I build anything (Question 1).

Three things must change on it regardless of that answer: **apply scale**, **move the origin to the
connection face on Z=0**, and **move the texture off the Desktop into `firebase/tex/`** — a linked
Desktop path will break for anyone but this machine and is not exportable.

---

## 2. Existing sandbag assets — the ones being replaced

Three GLB modules in `firebase/kit/`, loaded by `tools/gen_firebase.py:155-159` (`BAG_MODULES`):

| module | tris | dimensions (m) | material | shading |
|---|---|---|---|---|
| `fb_sandbag_heavy.glb` | 176 | 2.283 × 1.081 × **1.174** | `Sandbags.051` (64×64 packed) | 160/176 smooth |
| `fb_sandbag_light.glb` | 288 | 2.139 × 0.880 × 0.483 | `Sandbags.071` (64×64 packed) | 288/288 smooth |
| `fb_FoxholeSandbags.glb` | 408 | 2.319 × 0.350 × 1.435 | `SandbagMaterial` (flat colour, **no texture**) | 295/408 smooth |

None ships a `-colonly` mesh. None uses the `fb_*` atlas materials — they carry their own
64×64 packed maps, so they sit outside the atlas scheme entirely.

**The `heavy` module is 1.174 m tall — that is 9 courses × 0.13 m to within 4 mm.** The bags already
in the project were built on the same ground truth quoted in the spec. Good corroboration; the
50 × 25 × 13 figure is safe to build on.

**Cost of the current approach:** the heavy module is 176 tris over 2.283 m = **77 tris per linear
metre** at 1.17 m height. That is already inside the spec's 80–200 tris/m wall budget. The reason
the v1 assets are heavy is not the bags themselves — it is how many runs and rings each asset stacks
(`bag_run` at `gen_firebase.py:190`, `bag_ring` at `:219`).

### Prior ruling on these bags, recorded in the generator

`tools/gen_firebase.py:151-153` records a ruling dated **today**:

> "use the sandbags ive got in the project. they arent weighing down the game and fit into the
> asthetics so dont worry just use the better sandbags."

The new instruction ("`NEW_sandbag` … will be what youll replace all the sandbags in these buildings")
**supersedes it.** I am treating the replacement as decided and will not re-ask it. When I touch
`gen_firebase.py` that comment block gets corrected in the same change, per the no-drift law.

---

## 3. Conventions already established that I intend to inherit

Read out of `tools/gen_firebase.py` and the live review scene.

| convention | current state | pointer |
|---|---|---|
| **Naming** | `fb_<name>`, lowercase, one merged mesh per asset (`fb_bunker_mg`, `fb_gun_pit`) | scene inventory |
| **Materials** | 9 fixed slots on **every** asset, same order, `MAT_INDEX` drives face assignment | `gen_firebase.py:61-77` |
| — textured (7) | `fb_sandbag`, `fb_earth`, `fb_timber`, `fb_psp`, `fb_canvas`, `fb_corrugated`, `fb_crate` — each a **256×256** PNG in `firebase/tex/` | `gen_firebase.py:61-68` |
| — flat, deliberately untextured (2) | `fb_gunmetal`, `fb_olive`. Comment at `:69-72` says weapons must never take `fb_psp` because perforated planking on a gun barrel reads as slotted metal. **Keep this.** | `gen_firebase.py:69-75` |
| **Filtering** | `tex.interpolation = 'Closest'` — point filtering already set in Blender | `gen_firebase.py:98` |
| **UVs** | box projection, `tile=1.6 m`, no unwrap, no seams | `gen_firebase.py:105-118` |
| **Texel density** | **measured 160 px/m** on `fb_sandbag_stack` (120 faces) and `fb_bunker_mg` (162 faces) — 256 px ÷ 1.6 m, dead consistent | measured |
| **Origins** | base centre, on Z=0. `fb_sandbag_stack` local Z runs 0.000 → 0.880 ✓ | measured |
| **Shading** | 0 / 120 faces smooth on generated geometry — flat, as the spec wants. Only the *imported* bags are smooth | measured |
| **Vertex colour AO** | **none exists.** No colour attributes on any of the 23 assets | measured |
| **Markers** | Empties read by name. Local +Z is facing in Godot = Blender local −Y, so a marker facing world angle `a` needs `rotation_euler.z = a + 90°`. **The file says never re-derive this** | `gen_firebase.py:40-42` |
| **Wire** | `assets/us/props/emplacements/barbwire_card.glb` is THE only wire (war room 2026-07-17, 2.88 m tiling). Imported, never re-modelled. Mesh names must keep the `bwire_card` prefix or `tools/diag_fsb_seat.gd:100` fails hard | `gen_firebase.py:43-46` |
| **Player metrics** | capsule r=0.4 h=1.8; doors 1.05 × 1.95; crawl-ins 0.95 × 1.60 | `gen_firebase.py:56-59` |
| **Godot side** | `firebase_set.json` + per-GLB `.import` files already exist for the kit | folder listing |

**Consequence worth stating plainly:** the 9-slot fixed material order is load-bearing. Anything I
generate must keep those slots in that order or the face→material mapping in the existing generator
silently shifts.

---

## 4. Course arithmetic from the ground truth

Bag = **0.50 × 0.25 × 0.13 m** laid flat. Bags are never scaled to hit a height; course count changes
and the height lands where it lands.

| spec nominal height | courses | **actual built height** |
|---|---|---|
| 0.6 m (fighting step / parapet) | 5 | **0.65 m** |
| 1.2 m (chest / standard revetment) | 9 | **1.17 m** |
| 1.8 m (blast wall / tower base) | 14 | **1.82 m** |

A 1 m module is exactly **2 bags per course** as stretchers, alternate courses offset 0.25 m for the
running bond. Clean, no remainder — the 1 m grid and the 0.5 m bag agree.

Wall thickness = one stretcher = **0.25 m**, envelope 0.31 m once the ±3 cm lump is added to the
outer face. (Real 1969 revetments were often two bags thick; the spec doesn't say. I am building
single-thickness and letting `thickness` be a parameter rather than inventing a convention.)

Note I did **not** carry over the 0.94 bed-down factor at `gen_firebase.py:216`. Courses bedding into
each other is a real thing, but on a slab body the texture carries it, and applying it would make the
built height stop being a whole multiple of 0.13.

---

## 5. Proposed `build_sandbag_wall()`

```python
def build_sandbag_wall(
        length,                 # metres along the run: 1.0, 2.0, 4.0
        height=None,            # convenience only — resolved to whole courses, never scaled to fit
        courses=None,           # authoritative if given; exactly one of height/courses
        style="straight",       # straight | corner_in | corner_out | end_cap | t_junction |
                                # angle_45 | revetment_slope | parapet_with_embrasure | blast_wall
        seed=0,                 # drives per-bag jitter: rot ±8°, pos ±2 cm, scale ±4%
        *,
        thickness=0.25,         # one stretcher
        lump=0.03,              # outer-face displacement amplitude, ±m
        inner="flat",           # flat | lumpy | none   (lumpy only when player-accessible)
        back="keep",            # keep | delete         (delete when it sits against a berm)
        top_course="real",      # real | slab           (real = FB_KIT_Sandbag instances)
        origin="connection",    # connection face, on Z=0, so instances chain by translation
):
    """Returns (object, stats). stats = {tris, dims, courses, height, over_budget}."""
```

`height` and `courses` are over-determined against the never-scale rule, so: **`courses` wins**; if
only `height` is given it is rounded to the nearest whole course and the *actual* height is returned
in `stats`, never forced back to the requested number.

Lives in `tools/fb_kit.py` as a parametric function, called by `gen_firebase.py`. Not one-shot MCP
commands.

### Tri budget, worked out per module (budget: 80–200 per 1 m)

1 m straight @ 9 courses (1.17 m):

| part | quads | tris |
|---|---|---|
| outer lumpy face (4 cols × 5 rows) | 20 | 40 |
| inner face, flat | 1 | 2 |
| two end faces (5 quads each) | 10 | 20 |
| top cap under the real course | 4 | 8 |
| top course: 2 × `FB_KIT_Sandbag_A` @ ~48 tris | — | 96 |
| **total** | | **166** ✓ |

- 1 m @ 5 courses (0.65 m): **142** ✓
- 4 m @ 14 courses (1.82 m): **598** vs 320–800 allowed ✓

The real top course is 58% of the 1 m budget. It is also the only part carrying silhouette, so it
stays; if a variant runs over, the slab top course is the release valve, not a thinner bag.

`FB_KIT_Sandbag_A/B/C` target **≤50 tris** each (micro budget 20–100) — a 4-ring lofted pillow with
pinched ends, smooth-shaded (the spec allows smooth for "sandbag lumps"), A/B/C varying by sag,
split seam, and slump.

### Phase 1 module list

| shape | lengths | heights | variants | files |
|---|---|---|---|---|
| straight | 1, 2, 4 m | 0.65 / 1.17 / 1.82 | A/B/C | 27 |
| corner in | 1 m | 0.65 / 1.17 / 1.82 | A/B/C | 9 |
| corner out | 1 m | 0.65 / 1.17 / 1.82 | A/B/C | 9 |
| end cap | 1 m | 0.65 / 1.17 / 1.82 | A/B/C | 9 |
| T junction | 1 m | 1.17 | A/B/C | 3 |
| 45° | 1 m | 1.17 | A/B/C | 3 |
| parapet w/ embrasure | 2 m | 1.17 | A/B/C | 3 |
| revetment slope | 2 m | — | A/B/C | 3 |
| | | | **total** | **66 GLBs** |

66 exports plus 66 `-colonly` meshes is a lot of files for one phase. Recommendation: build the
generator for all of it, but **export only the 1 m and 2 m straights at 1.17 m plus corner in/out
and end cap first** (18 files), get those in front of you at player-eye, then batch the rest. Not
asking — flagging, because the file count is a consequence of the variant rule, not a decision I
should quietly make either way.

---

## 6. Problems with the spec — things that will bite

1. **Texel density conflicts with the kit as built.** Spec target is 64–96 px/m. The kit measures
   **160 px/m**, exactly and consistently. Following the spec makes every firebase asset roughly
   **half as sharp as it is today**. That is a visible downgrade, not a neutral standardisation.
2. **Atlas count vs material slots.** Spec allows 6 shared 512×512 atlases; the kit has 7 textured
   materials + 2 deliberately flat. They map cleanly (Timber ← timber+crate · Fabric ←
   sandbag+canvas · Metal ← psp+corrugated+gunmetal · Ground ← earth · Alpha ← the existing
   barbwire card · Detail ← nothing yet), but merging them **renumbers `MAT_INDEX`**, and every
   face assignment in `gen_firebase.py` is written against that order. It is a mechanical change
   across ~40 family functions, not a texture swap.
3. **Naming scheme is a breaking rename.** Spec wants `FB_<CAT>_<Name>_<Detail>_<Variant>`; the kit
   is `fb_<name>` lowercase, and those names are already referenced by `firebase_set.json`, by 23
   `.import` files, and by whatever consumes them in Godot. Renaming touches the Godot side too.
4. **The v1 assets are 3–7× over the new ceilings.** Measured against the spec's classes:
   `fb_bunker_mg` **6772** (ceiling 1500) · `fb_sleeping_bunker` **5232** · `fb_bunker_fighting`
   **5148** · `fb_tower` **4160** (ceiling 1500) · `fb_supply_dump` **3620** · `fb_mortar_pit`
   **3528** · `fb_hootch` **3120** · `fb_gun_pit` **2620** · `fb_toc` **2364** · `fb_aid_station`
   **1972**. Ten of the 23 blow their budget. Phase 1 as written does not include rebuilding them.
5. **No vertex-colour AO exists anywhere in the kit.** The spec leans on baked AO for the whole art
   direction. That is new work across every asset, not a Phase 1 sandbag detail.
6. **`FB_KIT_Sandbag` derivation is circular as written.** The spec says derive it from "the user's
   existing sandbag models" — but those are 2.3 m multi-bag revetment panels, not single bags.
   There is no single-bag mesh in the project to measure. I will build the bag from the
   50 × 25 × 13 ground truth instead, which is the more reliable source anyway.
7. **The 1.8 m reference cube** the spec asks for does not exist in either file. I'll add it.
8. **`-colonly` collision meshes do not exist for any current kit GLB.** Also new work.

---

## 7. SUMMONER'S RULINGS — 2026-07-26

Given in answer to this report. Verbatim where he spoke.

1. **What `NEW_sandbag` is:** *"its a wall quick easy sandbag asset i made to solve the problem for
   what sandbags to use. so it represents a section of sandbag wall."*
   → It is a **wall section**, not a bag. The lumpy-slab treatment and its photo texture are the
   look for the wall body. Individual bags get built separately at 50 × 25 × 13 for the top course,
   loose scatter, split bags, and hero detail.
2. **Texel density: keep 160 px/m**, matching the kit as built. The spec's 64–96 px/m band is
   **amended to 160**. New sandbag texture goes into `firebase/tex/` at 512×512, box-projection
   tile 3.2 m. Nothing in the existing kit gets re-UV'd.
3. **Naming: `fb_` lowercase throughout.** The spec's `FB_<CAT>_<Name>_<Detail>_<Variant>` is
   **amended** to the convention already in the project: `fb_sbg_wall_straight_1m_a`. No rename of
   existing assets, no Godot-side breakage, no mixed naming.

### 4. The tri ceiling — answered, not ruled

He asked whether the ceiling exists for his machine or for the PSX/1999–2005 style. **Measured
answer: the style. It is not buying frames in this project.**

- `PERF_LEDGER.md:98-100` — "Cutting **99,500 prims (33%) and 77 draw calls moved FPS by ~0.**
  Geometry/draw-call count is not the jungle's limiter at this pose; full-screen terrain/water
  fragment shading + the render pipeline is."
- `PERF_LEDGER.md:407-408` — canopy owns **~70% of draw calls** (1,407 → 364) and is **call-bound,
  not primitive-bound**.
- `PERF_LEDGER.md:394-402` — the earlier "sun shadow is the dominant lever" headline is retracted;
  the probe was paying back a shadow the shipped world never renders (`game_world.gd:48`).
- `PERF_LEDGER.md:6` — "THERE IS NO NUMERIC FPS GATE. *No numeric gate — my eyes decide.*"

**Therefore:**
- Keep the tri budgets as an **art rule** — 80–200 tris/m is what forces the wall to be solved with
  silhouette and texture instead of geometry, which is the whole 1999–2005 read. Keeping them
  "so it runs better" would be a claim this ledger refutes.
- ~~**The atlas rule is the real performance lever**, and the spec files it under textures. Every kit
  asset carries 9 material slots, so one placed asset can cost up to 9 draw calls. Collapsing 9 → 5
  atlas families is measured-relevant in a way that shaving triangles is not.~~
  **STRUCK 2026-07-26 by War Room decree — this claim was FALSE, not merely unmeasured.** Four
  architects killed it independently (`production/war_room/2026-07-26_fps_deep_dive/synthesis.md` §2b):
  **the 23 nine-slot assets do not exist as Godot assets** — `assets/world/firebase/` holds
  `fsb_main.glb` plus 4 kit GLBs carrying **1, 1, 1, 5 surfaces (mean 2.0)**, never 9, because
  **unused Blender material slots do not export**. The 7 `fb_*` textures are referenced by nothing and
  none of the 4 kit GLBs loads at runtime — as §8 of this very document concedes at `:273`
  ("Nothing is exported to .glb yet"). `gen_firebase.py` is Blender-side only and its `MATS` list is
  now 10 entries, not 9. **9 → 5 removes ZERO draw calls today.** Even granting the premise it bounds
  to ~0.35–0.7 FPS — the entire non-canopy frame is only 411–464 calls (`PERF_LEDGER.md:896-898`) —
  which is below the ~3 FPS detectability floor and therefore unfalsifiable.
- **The real `fsb_main` defect is different, and it is real:** 94 materials collapsing to 48 distinct
  signatures (**46 exact duplicates**) and **20 alpha-BLEND surfaces** — 19 identical `Sandbags*` on a
  64×64 texture sitting in the transparent pass at the exact pose every FPS baseline is measured from.
  **Sell the de-duplication as hygiene, not FPS** (`PERF_LEDGER.md:98-100`: 77 calls → ~0 FPS). The
  alpha-BLEND-to-scissor fix is the part with real overdraw upside, and it needs his eyes.
- **Do not rebuild the ten over-budget v1 assets for FPS.** There is no FPS there to reclaim. They
  get rebuilt when they look wrong, on his eyes.

---

## 8. BATCH 1 — built 2026-07-26, awaiting look approval

Generator: `tools/fb_kit.py` (parametric, re-runnable). Review scene:
`firebase/kit/fb_sandbag_kit_review.blend`. Renders: `firebase/kit/review_renders/`.
**Nothing is exported to .glb yet** — held until the look is approved, so the Godot import
folder stays clean.

Texture built from the Desktop photo into `firebase/tex/fb_sandbag_wall.png`:
**320 × 320 px over a 2.0 m box-projection tile = exactly 160.0 px/m**, matching the kit.
Source periods were measured, not eyeballed — bag period 412 px, running-bond period 196 px
(= 2 courses; the bag aspect 412/98 = 4.2 against ground truth 3.85 settles it at 2, not 1).
A crop of 2 bag × 2 bond periods = 2 bags × 4 courses = 1.00 × 0.50 m of real wall, seam-blended
and tiled 2 × 4. The source photo is **not** seamless (L/R edge delta 0.174 against a global
std of 0.130), which is why it is period-cropped and cross-faded rather than used directly.

Target 1.2 m → **9 courses → 1.170 m built**, per the never-scale rule.

| module | tris | budget | dims (m) | |
|---|---:|---:|---|---|
| `fb_sbg_wall_straight_1m_a` | 176 | 80–200 | 1.007 × 0.302 × 1.167 | OK |
| `fb_sbg_wall_straight_2m_a` | 336 | 160–400 | 2.001 × 0.313 × 1.181 | OK |
| `fb_sbg_wall_corner_out_1m_a` | 372 | 160–400 | 1.051 × 1.265 × 1.178 | OK |
| `fb_sbg_wall_corner_in_1m_a` | 372 | 160–400 | 1.072 × 1.271 × 1.180 | OK |
| `fb_sbg_wall_end_cap_1m_a` | 168 | 80–200 | 1.008 × 0.301 × 1.174 | OK |

All five inside budget. Batch total 1,424 tris.

### Fixed during the build

- **Pinched bag ends floated 2.9 cm off the deck.** `sandbag_bmesh` scaled the ring profile in
  z as well as width, so the tapered end rings lifted clear of the course below and the top
  course read as flat pancakes with a visible gap. The profile is now authored with its
  underside on z=0 and only the width tapers.
- **The crest was a machined straight edge.** The displacement damped the top vertex row to
  0.35×, which flattened exactly the row that carries the silhouette. Damping now applies to
  the ground row only, and the top row carries a small z jitter.

### Still wrong, and these are art calls rather than bugs

1. **The top-course bags read pale and flat against the wall** — a value break at the crest.
   They are smooth-shaded and sampling a bright patch of the tile.
2. **End faces come out near-white.** Box projection stretches a thin texture sliver across
   the 0.30 m thick end. Visible as a pale vertical band. Fixable with a dedicated end UV.
3. **The whole thing is bleached** against the stated palette — burlap `#9C8A63`, mildewed
   `#6E6449`. The source photo is high-key and AgX pulls it further.
4. **Silhouette is still boxy.** ±3 cm is honest to the brief but at player-eye it reads as a
   textured box; the bag rhythm is carried almost entirely by the texture.

---

## 9. What I am NOT asking, because it is already ruled

- Replacing the current sandbags — decided by the new instruction, supersedes `gen_firebase.py:151`.
- Wall heights landing at 0.65 / 1.17 / 1.82 instead of 0.6 / 1.2 / 1.8 — that is the never-scale
  rule applied, not a new convention.
- Individual bags reserved for top course, loose scatter, split bags, hero detail — stated.
- Inner face flat unless player-accessible, back deleted against a berm — stated.
