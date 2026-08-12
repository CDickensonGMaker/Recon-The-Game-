# WATER TECH RESEARCH — addons, "real water", and the PSX happy medium

**Convened:** 2026-08-12 · **Lens:** what exists on the market, what "real water" means technically,
and what we should actually build.
**Method:** web-verified every addon claim (URLs inline, no training-data assertions); read
`terrain/water/` in full and the three sibling analyses. Every RECONgame claim carries `file:line`
(POINTER LAW).

**Summoner's ruling this answers:** *"i dont want a sheet for water i want real water"* ·
*"i know godot can get water"* · *"so find an addon or lets make real water"* ·
*"find the happy medium to make it look like a psx style once we get the water in the game actually"*.

---

## 0 · THE AXIS THAT DECIDES EVERYTHING — runtime generation

RECONgame's rivers do not exist until the game is running.

- `terrain/water/hydrology_map.gd` does Priority-Flood pit filling, D8 flow direction, and flow
  accumulation against the live heightmap, then traces channels in `_trace_channel`
  (`hydrology_map.gd:493-539`), emitting `{ "points": PackedVector2Array, "widths": PackedFloat32Array }`
  at `:539`.
- Hydrology is solved inside `TerrainManager` at `terrain/core/terrain_manager.gd:373`, and the
  retained object is handed to the water system at `scripts/levels/game_world.gd:166`.
- The renderable surface is assembled from those polylines at
  `terrain/water/water_system.gd:258-259` → `_append_river_strip` (`:319-375`) into ONE `ArrayMesh`
  with ONE `ShaderMaterial` (`:272-282`).
- ~106 channels per seed (probe, seed 47225, briefing §"THE MEASUREMENT").

**There is no Path3D. There is no `.tres` river resource. There is no editor step. There is no file
on disk that describes where a river is.** Any tool whose workflow begins with *"add a River node and
drag the path handles"* and ends with *"bake the flow map"* is describing a pipeline this project does
not have and cannot acquire without abandoning procedural generation.

Judge every candidate on that axis first. I do so explicitly below.

---

## 1 · WHAT ACTUALLY EXISTS (2026) — verified on the web, not recalled

### 1.1 Waterways — Arnklit (the obvious candidate)

| Field | Value |
|---|---|
| Repo | https://github.com/Arnklit/Waterways |
| License | **MIT** (GitHub API, `license` field) |
| Stars / issues | 1,310 · 7 open |
| Last push | **2025-12-17** (GitHub API `pushed_at`) — alive but slow |
| Archived | No |
| Branches | `main`, `godot4_0`, `godot4_5_1`, `lake-ideas` (GitHub API `/branches`) |
| Godot version | `main` has `config_version=4` → Godot 4.x. The newest work is the `godot4_5_1` branch, whose merged PRs are titled *"Godot 4.5 updates"* and *"new property additions from the v4.5.1 Godot upgrade"* (commit log, 2025-12-17). **Nothing claims 4.7.** The Asset Library listing is still the Godot **3.2** entry from 2021-01-27 (https://godotengine.org/asset-library/asset/805) |
| **Editor bake?** | **YES, mandatory.** README: *"you can use the River -> Generate Flow & Foam Map option to bake out the textures"*, and a second bake for *"WaterSystem -> Generate System Maps"* (https://raw.githubusercontent.com/Arnklit/Waterways/main/README.md) |

**VERDICT: ARCHITECTURALLY INCOMPATIBLE as a tool.** It is an `EditorPlugin` driving a bezier
`Path3D`, with two offline bake steps whose outputs are `.png`/`.res` files. We have no curve to
place and no editor session in which to bake. Wiring 106 procedurally-traced polylines into River
nodes and invoking the bake headlessly at load would cost more than writing the shader, and would
add a viewport-render dependency to world generation.

**But the SHADER is partially liftable, and this is the useful finding.** I read
`addons/waterways/shaders/river.gdshader` on the `godot4_0` branch. It declares:

- `depth_texture : hint_depth_texture` — used for the depth-fade colour/alpha ramp
- `screen_texture : hint_screen_texture` — used for `transparency_refraction`
- `i_flowmap`, `i_distmap`, `i_texture_foam_noise` — the baked artefacts
- **`i_valid_flowmap`** — a bool with a **documented fallback to a constant flow direction when no
  flowmap is baked.** The shader runs without the bake; it just loses per-pixel flow.
- `normal_bump_texture` + `normal_scale`, resolved through tangent-space normal mapping

Two of those disqualify a straight lift:
1. The tangent-space normal path needs `ARRAY_TANGENT`. Our mesh has none — `water_system.gd:265-270`
   assigns exactly `ARRAY_VERTEX`, `ARRAY_NORMAL`, `ARRAY_TEX_UV`, `ARRAY_COLOR`, `ARRAY_INDEX`, and
   `ARRAY_TANGENT` appears nowhere in the file. A tangent-space normal resolves against a zero
   tangent and renders garbage, silently.
2. Its whole UV model (`i_uv2_sides`, `flow_pressure`, `flow_distance`) assumes the Waterways mesh
   generator's UV2 layout, which our ribbon does not produce.

**What IS worth copying from it: the `depth_texture` fade and the `screen_texture` refraction — two
techniques `terrain/water/water_static.gdshader` does not use at all.** That is the substance of §2.

### 1.2 Waterways .NET — Tshmofen

| Field | Value |
|---|---|
| Repo | https://github.com/Tshmofen/waterways-net |
| License | MIT · Archived: No |
| Last push | **2025-09-05** |
| Language | **C# / .NET 8.0** — *"Whole plugin is now implemented using C#"* |
| Godot version | Asset Library entry says **4.2**, updated 2024-12-23 (https://godotengine.org/asset-library/asset/2607) |
| **Editor bake?** | **NO** — README: *"The baking is removed because of the many issues"* |

**VERDICT: NO, for a reason that has nothing to do with water.** RECONgame is a GDScript project
(CLAUDE.md, "Godot 4.7 stable, GDScript"). Adopting this means switching the whole project to the
.NET build of Godot, new export templates, a C# toolchain in the pipeline, and a second language in
every future agent's context. That is a project-wide architectural change to obtain a river tool we
still could not drive, because it remains an editor-time `RiverManager` node on a bezier curve —
removing the *bake* did not remove the *authored curve*. Same incompatibility as §1.1, plus a
toolchain bill.

Its one transferable idea is confirmed as correct practice and we already do it: **pass flow as a
vertex attribute rather than a baked texture.** We bake heading into `COLOR.b` at
`water_system.gd:346` and decode it at `water_static.gdshader:78-80`. That is the same answer
Waterways .NET reached, arrived at independently.

### 1.3 Boujie Water Shader — Chrisknyfe

| Field | Value |
|---|---|
| Repo | https://github.com/Chrisknyfe/boujie_water_shader |
| License | MIT · Archived: No · Language: **GDScript** |
| Last push | **2026-04-16** — the most recently maintained candidate |
| Asset Library | Godot **4.1**, updated 2023-09-22 (https://godotengine.org/asset-library/asset/2070) |
| **Editor bake?** | **NO.** *"The plane on which water is simulated is generated during runtime."* |
| Features | Gerstner vertex waves, refraction, Fresnel, **depth fog**, **shore foam from submerged solids**, Snell's window, LOD ocean mesh generator, distance fade |

**VERDICT: NOT usable as a system, but this is the best REFERENCE on the board.** It is an *infinite
ocean* — a camera-following LOD plane grid. It has no concept of a channel, a bank, or a flow
direction. You cannot make 106 winding creeks out of it.

What it proves, in GDScript, on Godot 4, with no bake, MIT-licensed: **depth-buffer shore foam,
depth fog and screen-space refraction all work on a runtime-generated water mesh in this engine.**
That is the direct answer to *"i know godot can get water"* — yes, and here is a maintained MIT
implementation of the exact fragment-stage techniques we are missing. Read it, port the fragment
maths, discard the ocean scaffolding.

### 1.4 The ocean-only field (all rejected on the same ground)

| Project | URL | License | Last push | Why rejected |
|---|---|---|---|---|
| Godot-Ocean-Shader (immaculate-lift-studio) | https://github.com/immaculate-lift-studio/Godot-Ocean-Shader | MIT | **2024-12-17** | Ocean planes only; no channels. Effectively dormant. |
| godot4-oceanfft (tessarakkt) | https://github.com/tessarakkt/godot4-oceanfft | — | — | Tessendorf FFT on compute shaders. Deep-ocean spectra on a 3 m jungle creek is meaningless, and it is a compute-shader dependency against the Intel-UHD floor (ADR-026). Also stylistically the *opposite* of PSX. |
| Ocean3D (itch, paid) | https://ocean3d.itch.io/ocean3d | commercial | — | Gerstner ocean + buoyancy. Ocean only. |
| Godot Realistic Water / Godot-4-Realistic-Water (spicyhaydenc) | https://github.com/spicyhaydenc/Godot-4-Realistic-Water | — | — | Self-described *"work in progress port"* of the Godot 3 UnionBytes shader. Photoreal target, planar surface. Wrong art direction and unfinished. |
| Godot River & Waterfall (gameidea, paid) | https://gameidea.org/assets/godot-river-waterfall/ | commercial | 2026-05 | Authored in Godot 4.6; a *shader* for a hand-placed river mesh. Same authored-geometry assumption. Newest thing found, and still curve-driven. |
| Godot Stylized Water Shader (gameidea, paid) | https://gameidea.org/assets/godot-stylized-water-shader/ | commercial | 2026-02 | Depth fog, absorption, refraction, foam, caustics, **plus an underwater shader**. Same authored-geometry assumption. Useful as a feature checklist. |

### 1.5 Terrain3D

**No native water support.** The only community traffic is a forum thread about *bolting* a caustics
shader onto Terrain3D (https://forum.godotengine.org/t/applying-a-water-caustics-shader-to-terrain3d/84714),
i.e. users solving water separately alongside it. Moot regardless: RECONgame runs its own terrain
engine (`terrain/core/terrain_manager.gd`, copied from TerrainEngine per CLAUDE.md "Origins"), not
Terrain3D.

### 1.6 The Asset Library, sorted by update date — the whole 4.x water shelf

Pulled live from https://godotengine.org/asset-library/asset?category=&godot_version=&sort=updated&filter=water
(18 entries total, 2.1 → 4.7):

| Asset | Godot | Updated | Note |
|---|---|---|---|
| WaterBox Demo | **4.7** | 2026-07-12 | Only 4.7-tagged water asset in the library |
| WaterBox | 4.2 | 2026-07-12 | Box-volume water tool. **I could not find a repo or documentation for it on the open web** — the search returned nothing about its architecture. Flagged as unverified, not recommended blind. |
| Shader for Transparent Water with SSR and Refraction | 4.4 | 2025-04-01 | https://github.com/marcelb/GodotSSRWater — a custom SSR pass to work around §2.4 |
| Waterways .NET | 4.2 | 2024-12-23 | §1.2 |
| Boujie Water Shader | 4.1 | 2023-09-22 | §1.3 |
| Waterways — River Generation | **3.2** | 2021-01-27 | The listed Waterways is still Godot 3 |

Everything else in the list is Godot 3.x or older, or 2D.

### 1.7 Godot 4.7 itself adds nothing for water

4.7's rendering headline features are **AreaLight3D**, **HDR output**, and **DrawableTexture2D**
(https://godotengine.org/releases/4.7/). No water primitive, no new depth/screen hint, no change to
the transparent pipeline. There is no engine-level free lunch waiting in the version we are on.

### 1.8 SUMMARY OF THE ADDON SEARCH

**Every river addon in the Godot ecosystem — without exception — is an editor-time tool built on a
hand-placed bezier `Path3D`.** That is not an accident of the ones I found; it is the shape of the
problem the ecosystem has been solving. Nobody has shipped a Godot addon that renders rivers from a
runtime-generated hydrology graph, because almost nobody generates one.

**Every no-bake, runtime-mesh water project is an OCEAN** — an infinite plane. None of them
understands a bank, a bed, or a downstream heading.

RECONgame sits in the gap between the two, and the gap is real, not a search failure.

---

## 2 · "REAL WATER", DEFINED TECHNICALLY

The Summoner is rejecting a flat opaque ribbon. Here is what the word "real" decomposes into, what
each costs, and — critically — which survive our missing `ARRAY_TANGENT`.

**The tangent constraint, stated once.** `water_system.gd:265-270` assigns five arrays and
`ARRAY_TANGENT` is not among them. Consequence: **any technique that writes `NORMAL_MAP` renders
garbage silently.** The current shader already respects this — it writes view-space `NORMAL`
directly at `water_static.gdshader:85`, converting from world space through `VIEW_MATRIX`, and the
string `NORMAL_MAP` does not occur in the file. That is correct and must stay correct. Every
technique below is marked **[T]** if it needs tangents.

### 2.1 Depth-buffer depth fade — shallow clear → deep murky · **THE SINGLE BIGGEST WIN**

Sample `hint_depth_texture` at `SCREEN_UV`, linearise it with `INV_PROJECTION_MATRIX`, subtract the
water surface's own view depth. The difference is **how much water the ray travelled through**. Drive
colour, alpha and murk off it.

- **Forward+ 4.7:** fully supported. `hint_depth_texture` is 3D-only and must be linearised via the
  inverse projection (Godot docs, screen-reading shaders).
- **Tangents:** **NO. Survives.**
- **Cost:** one texture fetch + a matrix multiply per fragment. Negligible.
- **What it replaces:** we currently *fake* this from vertex colour — `COLOR.g` baked as
  `clampf((y - bed) / COMBINED_DEPTH_RANGE, ...)` at `water_system.gd:348-350`, read as `v_depth` at
  `water_static.gdshader:72` and ramped at `:92-93`. That is per-vertex, and with **three verts across
  a 40 m ribbon** (`water_system.gd:352-365`) it is a linear gradient across an entire river. The
  depth buffer gives it per-pixel and — the part that matters — **it accounts for the actual bed
  geometry, submerged rocks, and any object standing in the water.** A soldier wading gets darker at
  his shins for free.
- **Caveat that must be respected:** the depth buffer only contains the **opaque** pass. Foliage
  cards, smoke, tracers and other water are absent. Correct behaviour for a river bed. Note it so
  nobody debugs it later.

### 2.2 Screen-space refraction of the bed

Offset `SCREEN_UV` by the perturbed normal's screen-space XY and sample `hint_screen_texture`. The
bed visibly wobbles under the surface.

- **Forward+ 4.7:** supported. Godot docs: the screen texture is captured **after the opaque pass but
  before the transparent pass**, and *"materials that use `hint_screen_texture` are considered
  transparent themselves and will not appear in the resulting screen texture."*
- **Tangents:** **NO. Survives** — the perturbation comes from our procedurally-computed world normal
  (`water_static.gdshader:45-66`), which needs no tangent basis.
- **Cost:** one back-buffer copy for the frame plus a fetch. Cheap; this is exactly what Boujie
  (§1.3) and the Waterways river shader (§1.1, `transparency_refraction`) both do.
- **Constraint:** refraction only reads what was already rasterised, so bed pixels **outside the
  screen** or **behind the water's own silhouette** are missing. Clamp the offset (a few pixels) and
  fade it near the shore, or you get bleeding artefacts along the bank. This is the standard bug and
  the standard fix.
- **Hazard specific to us:** two overlapping water surfaces. At the 106 channels' confluences the
  ribbons overlap (godot_specialist §4), and the second sheet cannot refract the first because
  screen-texture users are excluded from the screen texture. It will read flat there. Acceptable.

### 2.3 Shore / intersection foam from the depth buffer

Same depth difference as §2.1; where it is under ~0.2–0.4 m, blend toward foam. This is
**intersection foam** — it hugs the true waterline wherever the water meets *any* opaque geometry,
including a man's legs and a sampan hull.

- **Tangents:** **NO. Survives.**
- **Cost:** free once §2.1 exists.
- **What it replaces, and this is a real defect it kills:** foam currently comes from `COLOR.r`,
  baked as a hard `0.0 / 1.0 / 0.0` across left/centre/right at `water_system.gd:355/360/365` and
  smoothstepped at `water_static.gdshader:102`. On a 40 m channel that is a **20 m-wide foam
  gradient washing the entire river white** (godot_specialist §3b). Depth-buffer foam replaces a
  20 m smear with a band that is genuinely at the waterline, at any channel width, with **zero
  CPU-side bookkeeping**. It also makes `_cell_distance_to_edge` (`water_system.gd:379-385`) and
  `COMBINED_SHORE_FADE` (`:232`) dead — see §4 FOSSIL LIST.

### 2.4 Reflection — and the trap

**SSR: DOES NOT WORK.** Godot 4's screen-space reflection is implemented for opaque surfaces only.
A material can be transparent **or** receive SSR, never both
(godotengine/godot-proposals#7274; godotengine/godot#79549). Our water writes `ALPHA`
(`water_static.gdshader:113`), which puts it on the transparent pipeline unconditionally. **Do not
budget for SSR. Do not let anyone "just turn on SSR".** The only route is hand-writing a custom SSR
ray-march in the water shader — which is what https://github.com/marcelb/GodotSSRWater exists to do,
and it is far more expense and noise than a PSX jungle creek can justify.

**ReflectionProbe:** works on transparent surfaces, costs a cubemap render, and gives a plausible
canopy-and-sky reflection. But 106 channels across a 1280 m AO would need many probes, and probe
placement is an authoring act on procedurally-placed water. **Reject for channels.**

**Fresnel + sky tint: what we already do, and the right answer.** `water_static.gdshader:98-100`
computes a Schlick fresnel and mixes toward `col_sky`. Nearly free, no probes, and — importantly —
**it is what a PS1-era game did.** Keep it; improve it by driving the sky colour from the actual sky
/ time-of-day rather than a fixed uniform, so a monsoon river is not reflecting a blue sky.

- **Tangents:** none of the above need them. **All survive.**

### 2.5 Ripple normals and flow-mapped scrolling

- **Analytic sine-derivative normals** (`water_static.gdshader:45-66`, three crossing sine trains,
  exact gradients) — **already implemented, already correct, already tangent-free.** This is good
  work. Keep it.
- **Flow-mapped scrolling** — `water_flow_uvs` (`water_common.gdshaderinc:142-145`) produces the
  standard dual-phase offset pair. It is called at `water_static.gdshader:89` **but the result is
  only fed to `water_fbm` for murk** (`:90`), never to a texture. The classic
  Catlike-Coding/Waterways flow-map trick — sample the same texture at two phase-offset UVs and
  cross-fade on the phase sawtooth so the texture never stretches — needs a **texture** to be worth
  anything. Right now we scroll procedural noise, which has no visible detail to advect.
- **Tangents:** scrolling an **albedo/foam** texture is fine, **[T]** only if you scroll a
  *tangent-space normal map*. **So: scroll colour and foam textures, never a normal map.** Derive all
  normals procedurally as we already do. This is the specific rule that keeps us out of the
  garbage-normal trap.

### 2.6 Underwater view

Below the surface, the camera needs: an inverted-looking surface plane above, a heavy colour tint,
short-range fog, and no shore foam.

- Our shader is `cull_back` (`water_static.gdshader:2`), so from below the surface **is culled and
  the player sees nothing** — godot_specialist §1 calls this out as correct-but-unfinished. There is
  no `FRONT_FACING` branch and no underwater tint anywhere in `:75-117`.
- Doing it properly needs `cull_disabled` + a `FRONT_FACING` branch (cheap), **or** a separate
  fullscreen underwater post-pass triggered when the camera Y drops below `get_water_level_at`
  (`water_system.gd:511-521`).
- **Tangents:** NO.
- **RULING: OUT OF SCOPE, and say so.** With `min_lake_depth = INF` (`hydrology_map.gd:45`) there is
  no pooling, `generate_swamps = false` (`water_system.gd:28`), and the intended channel depth is
  `CHANNEL_WATER_DEPTH = 0.55 m` (`water_system.gd:238`). **There is nowhere in this AO deep enough
  to submerge a camera at 1.7 m eye height.** Building an underwater view now is building for water
  that does not exist. Revisit if and when the trunk river (level_designer §4) lands.

### 2.7 A WATER VOLUME vs a fixed-width ribbon — the structural answer

This is the one that actually answers *"i want real water, not a sheet."*

Today the surface is a **ribbon of fixed half-width**: `half = widths[i] * 0.5`
(`water_system.gd:329`), left/right verts at `p ∓ perp * half` (`:331-332`), three verts per station
(`:352-365`). **Its edges land wherever `widths[i]` says, which has nothing to do with where the
water actually meets the ground.** That is the *definition* of a sheet: a strip laid on terrain,
with an arbitrary boundary.

Real water has no width parameter. **Real water has a LEVEL, and its boundary is wherever that level
intersects the terrain.** Meshing that intersection is a level-set / marching-squares problem on the
heightmap, and every input already exists:

- The heightmap, at 4 m cells, `size == 321` on the shipping map (technical_director §preamble).
- A per-cell water surface height. `_surface_h` exists (`hydrology_map.gd:104`), is written for
  channel cells (`:518-519`), upsampled to `water_surface_full` (`:545-564`), and served by
  `get_water_level_at` (`water_system.gd:511-521`).

The algorithm: flood the surface height outward from each channel cell to any neighbour whose ground
is **below** that surface; emit a quad per fully-wet cell and a marching-squares polygon per boundary
cell, cutting the edge exactly on the ground/surface crossing. Output is a mesh whose silhouette is
the **real shoreline** — wide in the flats, pinched in the cut, pooling behind a rise. The same
routine handles ponds, flooded shell craters and paddies without a second code path.

**What this buys, concretely:**
1. The edge is where the water meets the land, **so the ribbon can no longer be buried in its own
   banks** — the briefing's defect #3 becomes structurally impossible rather than tuned away.
2. `bank_l`/`bank_r` sampling (`water_system.gd:337-338`) and both clamps (`:340-341`) — the source
   of the 52.2 % clamp rate and the 0.5 m sawtooth — **cease to exist.** There is nothing to clamp:
   the surface is a level.
3. The `widths` array stops driving geometry. It becomes what it should always have been: a
   **hydrological hint feeding the carve**, not a rendering parameter. The width/render/carve/mask
   three-way disagreement (technical_director §1.1) collapses to one authority.
4. Cross-section tessellation follows the heightmap grid automatically, so godot_specialist's
   3-verts-across-40 m defect (§3b) disappears rather than being patched.
5. The gameplay water mask can be generated by the **same flood**, which finally makes
   `is_water()` (`water_system.gd:483-490`) agree with what is drawn — the 4 m-mask-under-a-40 m-sheet
   lie (technical_director §1.1) closes.

**What it costs, honestly:**
- A real algorithm to write and test (~200 lines), where the ribbon fix is ~10.
- **It is a rewrite of `_append_river_strip` and `_append_static_quads`, so under ADR-023 both are
  DELETED**, along with the vertex-colour shore/depth contract they feed.
- Vertex count rises: a wet-cell mesh over the wetted area beats a 4,308-vert ribbon, but it is still
  one draw call, one material, built once behind the loading screen. Not a perf concern at this scale.
- **It depends on a correct, monotone `_surface_h`.** Today `:519` writes `_elev[i] - 0.65` where
  `_elev` is raw terrain, so the surface dips into filled pits and climbs back out
  (technical_director §1.4) — a level-set mesh fed that profile will pool in the wrong places,
  loudly. **`_filled[i]` is the correct datum and is already computed** (`hydrology_map.gd:100`).
  That fix is a prerequisite, not an optional extra.

**This is what separates "real water" from "a sheet", and it is the only item on this list that does.
Everything in §2.1–2.5 is paint. §2.7 is the hull.**

---

## 3 · THE PSX HAPPY MEDIUM

### 3.1 How PS1-era games actually drew water

The PS1 had no shaders, no depth buffer readback, no per-pixel anything. Water was:

- **A low-poly grid with animated vertices** — a handful of sine terms applied on the CPU/GTE.
  Coarse, low-frequency, large-amplitude. Nothing high-frequency, because there were no verts for it.
- **Scrolling UVs on a small tiling texture**, often two layers at different rates, sometimes with a
  palette cycle instead of true animation.
- **Vertex-coloured Gouraud shading**, no specular — the sparkle was painted into the texture.
- **Semi-transparency via the GPU's fixed blend modes** (the PS1's 50%/additive/subtractive
  quarter-modes), so alpha was quantised in practice.
- **Affine texture mapping** — no perspective correction, so the texture visibly swims and warps
  across large polygons. Games mitigated it by subdividing near the camera; water, being flat and
  large, is where affine warping is *most* visible and most characteristic.
- **15-bit colour** (5 bits/channel = 32 levels) with **ordered dithering** to hide the banding, all
  at ~320×240.

Modern PSX-revival work reproduces exactly this list — vertex snapping, affine warp, dither, colour
crush, low internal resolution (Retro Shaders Pro, Ultimate Retro Shader Collection, PS1/PSX Visuals
GD4 Port; and the MIT *PSX Style Water Surface* shader on godotshaders.com, which is precisely
two scrolling nearest-filtered textures + fastnoiselite vertex displacement + UV quantisation).

### 3.2 WE ALREADY HAVE THE PSX LAYER, AND IT IS OFF

This is the finding that decides the whole section.

- `assets/shaders/ps1_postprocess.gdshader` — a fullscreen `canvas_item` pass doing 4×4 Bayer
  ordered dither + `color_steps = 32.0` quantisation (`:16-17`, the literal 15-bit PS1 figure) +
  snapping to an internal-resolution texel grid (`:29-31`).
- `scripts/autoload/psx_look.gd` — registered as the `PsxLook` autoload (`project.godot:45`), sits on
  `layer = -10` (`:22`) so it crushes the 3D render but leaves the HUD crisp, and drives
  `viewport.scaling_3d_scale` to hit a **270 px internal height** (`:14`, `:50-52`).
- `assets/shaders/ps1_material.gdshader` — per-mesh **vertex snapping** (`:36-40`) and **affine
  texture warp** (`:43-45`), with `snap_resolution` locked to the same lattice the dither aligns to
  (`psx_look.gd:57-58`).
- **`GameSettings.psx_look` defaults to `false`** (`scripts/autoload/game_settings.gd:14`), toggled in
  the settings screen (`scripts/ui/screens/settings_screen.gd:63-73`).

**Two consequences that must govern the water shader:**

1. **DO NOT bake dither, colour quantisation or pixelation into the water shader.** `PsxLook` already
   does all three globally, at the correct internal resolution, aligned to the vertex-snap lattice.
   A water shader that dithers itself will **double-dither** when the toggle is on — cross-hatched
   mud — and will be the only object in the world that looks PSX when the toggle is off. The house
   architecture is: *materials describe the surface; one global pass describes the era.* Water obeys
   it like everything else.
2. **The water must read acceptably in BOTH modes,** because the toggle is off by default and the
   Summoner will judge it that way. So the PSX character we build *into* the water must be things
   that also just look like a stylised jungle river with the pass off: low-frequency waves, murky
   flat colour, a scrolling texture. Not artefacts.

**This is why the Summoner's sequencing instinct is right on the technical merits, not just on
priority.** Get the water rendering correctly, and the PSX treatment is *already built and already
wired* — it is a checkbox, not a project.

### 3.3 The happy medium — keep / degrade / reject

**KEEP from modern technique** (these read as *craft*, not as *anachronism*, and PS1 art directors
would have used them if the hardware allowed — they are the difference between water and a coloured
polygon):

| Keep | Why it survives the PSX filter |
|---|---|
| **Depth-buffer depth fade** (§2.1) | Reads as a painted shallow-to-deep gradient. Colour-crushes into ~3–4 visible bands, which is *exactly* the PS1 look. |
| **Depth-buffer shore foam** (§2.3) | Reads as a hard-edged light band at the waterline — a PS1 texture trick, done correctly. |
| **Screen-space refraction** (§2.2) | Keep it, but **turn it down hard.** A few pixels of wobble reads as "the bed is under the water." Heavy refraction reads as modern and fights the affine warp. |
| **Fresnel sky tint** (§2.4) | PS1 games faked this with vertex colours constantly. Ours is nearly free and already in (`water_static.gdshader:98-100`). |
| **Procedural analytic normals** (§2.5) | Already there, tangent-free, correct. But see the degrade list — the *frequency* is what needs to change. |

**DELIBERATELY DEGRADE:**

1. **Wave frequency: down.** `ripple_scale = 0.45` with three sine trains at `f = 1.90 / 3.70 / 0.85`
   (`water_static.gdshader:26`, `:51-53`) is a per-pixel high-frequency shimmer — a modern normal
   map's signature, and at a 270 px internal height it aliases into noise. **PS1 water was
   low-frequency and large-amplitude.** Drop to two trains, roughly halve the frequency, raise the
   steepness.
2. **Move the waves into the VERTICES.** Once §2.7's level-set mesh gives us verts at 4 m spacing,
   displace them with one or two slow sine terms. Cheap, and it is *the* PS1 water technique. Under
   `PsxLook` the vertex snap will chunk that displacement onto the pixel lattice automatically,
   which is precisely the era-correct wobble.
3. **Replace procedural fbm murk with a small tiling texture, `filter_nearest`, flow-scrolled.**
   `water_fbm` (`water_common.gdshaderinc:29-41`) is a smooth continuous field — the visual opposite
   of a 64×64 crunchy texel sheet, and it is 2 octaves × 4 hash-sin evaluations per fragment, per
   layer, twice (`water_static.gdshader:90`, `:103`). A nearest-filtered texture at two phase-offset
   UVs is **cheaper AND more era-correct.** This is the one place where the PSX choice is also the
   performance choice. It is also what finally makes `water_flow_uvs` (`:89`) earn its existence
   (§2.5).
4. **Quantise the colour ramp in the shader — a little.** Not dither (that is `PsxLook`'s job), but
   stepping the depth ramp into ~4–6 bands rather than a continuous mix. This survives with the
   PSX pass off, and reinforces it when on.
5. **Let the affine warp happen.** Water is large, flat, and near the camera — the ideal affine
   surface. Do not fight it, and do not subdivide the water mesh finely to reduce it.
6. **`SPECULAR = 0.5`** (`water_static.gdshader:116`) is a modern per-pixel highlight the PS1 could
   not produce (`ps1_material.gdshader:8` explicitly sets `specular_disabled` for exactly this
   reason). Keep it low, or fold the sparkle into the scrolling texture as PS1 games did.

**REJECT outright:** SSR (impossible anyway, §2.4), FFT ocean spectra, caustics, Gerstner storm
swell, real-time planar reflections, per-pixel foam simulation, buoyancy physics. All are modern
signatures, all cost, and none is asked for.

**Sequencing, per the Summoner's ruling:** §3.3's degrade list is **a second pass**, tuned on a
working surface. Do not gate the water on it. Get §2 rendering, put it in front of him, then tune.

---

## 4 · RECOMMENDATION

### 4.1 THE CALL: BUILD OUR OWN. There is no addon to buy.

Not a close call, and for a single reason that no amount of shopping changes: **every river addon in
the Godot ecosystem assumes a human placed the river.** Waterways bakes flow maps from an authored
bezier at editor time; Waterways .NET dropped the bake but kept the authored bezier and added a C#
toolchain bill; every no-bake runtime water project is an infinite ocean that has no concept of a
bank. RECONgame generates 106 channels from a seed at load. **The addon market has not built the
thing we need, and the reason is that almost nobody generates hydrology at runtime.**

What we take from the market instead, and this is real value, not a consolation prize:

- **The technique list** — depth fade, depth foam, refraction — proven working in Godot 4, on runtime
  meshes, in MIT GDScript (Boujie, §1.3) and in the Waterways river shader (§1.1). Read both. Port
  the fragment maths. Neither imposes any pipeline.
- **The confirmation that flow belongs in a vertex attribute, not a baked texture** — which
  Waterways .NET reached by deleting its own bake, and which we already do at
  `water_system.gd:346` / `water_static.gdshader:78-80`.
- **The confirmed dead end**: SSR on transparent water is not available in Godot 4 and no amount of
  configuration changes that.

**And the honest framing for the Summoner: we are already 70 % of the way to a good water shader.**
`water_static.gdshader` has the fresnel, the flow decode, the silt/murk ramp, the analytic
tangent-free normals, and a correct `NORMAL` write. godot_specialist's verdict stands — *"the shader
rewrite is sound work; it is paint on a boat that is not in the water."* The missing pieces are the
three depth-buffer techniques and, underneath them, a mesh that is a water body instead of a strip.

### 4.2 ARCHITECTURE — against the existing code

**PHASE 0 — MAKE IT VISIBLE. Nothing in this document matters until this lands.**
Owned by the sibling analyses; restated because it gates everything: reverse the ribbon winding at
`water_system.gd:374-375` (godot_specialist §1 — every triangle is backfacing under the `cull_back`
at `water_static.gdshader:2`), and seat the surface off the hydrology profile instead of the bank
samples (technical_director §5 A/C/D). **Do not start Phase 1 before the Summoner has seen water.**

**PHASE 1 — REAL WATER, SHADER SIDE.** `terrain/water/water_static.gdshader` only. No mesh change,
no GDScript change. Small, reversible, and independently visible.

1. Add `uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;` and
   `uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;`
   (`filter_nearest` deliberately — it is what `ps1_postprocess.gdshader:7` uses, and it costs
   nothing).
2. Linearise the depth sample with `INV_PROJECTION_MATRIX`, subtract the fragment's own view depth →
   `water_thickness` in metres.
3. Drive the colour ramp and `ALPHA` from `water_thickness` instead of `v_depth`
   (`water_static.gdshader:92-93`, `:107`).
4. Drive foam from `water_thickness` instead of `v_shore` (`:102-105`), with a threshold in metres
   (~0.25 m).
5. Refract: offset `SCREEN_UV` by the world normal's screen XY, clamped to a few pixels, faded out
   as `water_thickness → 0` so the bank does not bleed. Mix the refracted bed under the water colour
   by `1 - alpha`.
6. Keep writing `NORMAL` directly (`:85`). **Never introduce `NORMAL_MAP`** — add a comment stating
   the no-tangent constraint as the units-contract kind of comment COMMENT DISCIPLINE permits (the
   existing one at `:10-11` already does this; keep it).

**PHASE 2 — REAL WATER, GEOMETRY SIDE (§2.7).** The level-set surface.

- `hydrology_map.gd:519`: write `_filled[i] - CHANNEL_SURFACE_DROP`, not `_elev[i] - ...`. Prerequisite
  (technical_director §1.4). Without it the level-set mesh pools in the wrong places.
- New `water_system.gd` function: flood outward from channel/pool cells across the heightmap, emitting
  a quad per wet cell and a marching-squares boundary polygon per partial cell, seated at the local
  surface height.
- Feed the **same flood** into `_build_water_map_from_hydrology` (`water_system.gd:408-427`) so the
  gameplay mask and the drawn surface are finally the same object. This closes the 4 m-mask /
  40 m-sheet divergence (technical_director §1.1) — **but note it detonates the 22 m riparian belt
  (`gameplay_grid.gd:151`), which must be re-tuned in the same change** (technical_director §4.3,
  level_designer §3). Ship it as its own change with its own playtest.
- Split the mesh build out of `generate_water_bodies` so it can be rebuilt after site flattening
  (technical_director §6), with the call **guaranteed by `GameWorld`**, not by the mission generator —
  otherwise bare worlds and probe scenes silently get no water.

**PHASE 3 — THE PSX PASS (§3.3).** Shader-only tuning on a working surface: drop wave frequency,
move waves to vertices, swap `water_fbm` for a nearest-filtered scrolling texture, step the colour
ramp. **Verify with `PsxLook` both ON and OFF** (`game_settings.gd:14` defaults it off).

### 4.3 WHAT GETS DELETED — ADR-023 FOSSIL LAW

The predecessor dies in the same change. Named explicitly so nothing survives as a lie in the map:

**On Phase 1 (depth buffer replaces the vertex-colour depth/shore contract):**
- `COMBINED_SHORE_FADE` (`water_system.gd:232`) — no reader once foam is depth-driven.
- `COMBINED_DEPTH_RANGE` (`water_system.gd:234`) — no reader once the ramp is depth-driven.
- `_cell_distance_to_edge` (`water_system.gd:379-385`) — its only purpose is the `shore` term at
  `:300`, itself only feeding `COLOR.r`.
- The `COLOR.r` / `COLOR.g` bakes (`water_system.gd:313`, `:348-350`, `:355`, `:360`, `:365`) and the
  `v_shore` / `v_depth` varyings (`water_static.gdshader:39-40`, `:71-72`). **`COLOR.b` stays** — flow
  heading is genuinely per-vertex data the shader cannot derive, and the 0.02 bias at
  `water_system.gd:346` is load-bearing against the `step(0.001, v_flow)` discriminator at
  `water_static.gdshader:78`. Leave that alone.
- The vertex COLOR contract comment (`water_static.gdshader:6-11`) must be rewritten to R/G unused,
  not left describing a contract that no longer exists — the no-more-drift rule.

**On Phase 2 (level-set mesh replaces the ribbon):**
- `_append_river_strip` (`water_system.gd:319-375`) and `_append_static_quads` (`:286-315`) — both
  replaced by the level-set builder.
- `RIVER_RECESS` (`water_system.gd:236`) — the bank-guesswork constant; already condemned by
  technical_director §5 C.
- `bank_l` / `bank_r` sampling and both clamps (`water_system.gd:337-341`).
- `_path_perpendicular` (`water_system.gd:389-399`) — only caller is the ribbon.
- Whichever of `CHANNEL_CARVE_DEPTH` (`terrain_manager.gd:31`) / `CHANNEL_WATER_DEPTH`
  (`water_system.gd:238`) / `CHANNEL_SURFACE_DROP` (`hydrology_map.gd:53`) the level cut retires,
  plus the three-way contract comments at `terrain_manager.gd:28-31` and `hydrology_map.gd:51-53`
  that assert an arithmetic relationship **nothing enforces** (technical_director §8).

**Standing fossils this research confirms, for the record (not this change's job to fix, but do not
let them rot further):**
- `water_common.gdshaderinc` — `water_normal_from_height` (`:62-73`), `water_ripple` (`:54-59`),
  `water_wave` (`:48-51`), `water_flow_blend` (`:148-150`), `water_shore_foam` (`:157-162`),
  `water_crest_foam` (`:165-167`), `water_specular` (`:175-179`) and the entire
  `water_color_*` palette (`:80-118`) — **none is called by `water_static.gdshader`**, which uses
  only `water_fbm` and `water_flow_uvs`. Phase 3 deletes `water_fbm`'s caller too. **After Phase 3
  this include file is down to one used function out of sixteen.** It should be reduced to what is
  used, in that change.
- `Type.CREEK` is unreachable — `w < 6.0` at `hydrology_map.gd:513` and `avg_width < 6.0` at
  `water_system.gd:150`, against a minimum producible width of 6.95 m (level_designer §1). Not mine
  to fix; recorded so it is not lost.

### 4.4 WHAT IS SACRIFICED

| Recommendation | Cost |
|---|---|
| **Build our own, no addon** | We own it forever. No upstream fixes, no community bug reports, no other project stress-testing our water. Against that: no addon here fits, so the alternative is not "buy" — it is "bend the project around a tool that assumes a level designer draws the rivers." |
| **Depth-buffer everything (§2.1–2.3)** | Two full-screen texture fetches per water fragment. Negligible on the 4,308-vert ribbon; still negligible on a level-set mesh. But it makes the water **dependent on the opaque depth pre-pass**, which is a Forward+/Mobile-supported path but **not free on the GL Compatibility fallback** (`project.godot:322` sets `rendering_method.mobile="gl_compatibility"`). If the game ever has to run there, water needs a fallback branch. Name it now. |
| **Refraction** | Forces a back-buffer copy for the frame and excludes the water from other screen-reading shaders. At confluences, overlapping sheets cannot refract each other and read flat. |
| **No SSR, no reflection probes** | The water will never mirror the canopy. It reflects a fresnel-weighted flat sky tint. On a murky jungle creek that is defensible and era-correct; on a wide still trunk river it will read cheap. If the trunk river lands, revisit. |
| **No underwater view (§2.6)** | If pooling or a deep trunk river is ever restored, a camera dipping under the surface sees nothing, because `cull_back` (`water_static.gdshader:2`) culls it. Bounded today by there being no water over 0.55 m deep. **This becomes a real defect the moment `min_lake_depth` (`hydrology_map.gd:45`) stops being `INF`.** |
| **Level-set mesh (§2.7)** | ~200 lines and a real test, versus ~10 for patching the ribbon. It also **changes the shape of every water body in every seed** — ADR-010's same-seed-same-world contract is broken (as it is by any carve fix). And feeding the gameplay mask from it detonates the 22 m riparian belt, which must be re-tuned in the same change or heavy jungle acreage swings map-wide. |
| **PSX degrade pass (§3.3)** | The water will look worse in a still screenshot with the effects toggle off, and better in motion in the actual game. That is the trade PSX styling always is. Also: whoever tunes it must check **both** `PsxLook` states, doubling the eyeball cost of every tweak. |
| **Deleting the vertex-colour shore/depth contract** | The CPU-side foam and depth data become unavailable to anything that is not a fragment shader. Nothing reads them today, but a future gameplay system wanting "how deep is the water here" must use `get_water_depth` (`water_system.gd:494-506`) — which currently answers 0.5 m everywhere via the `int(depth*2.0)` quantisation at `:422`, and is its own open defect. |

---

## 5 · SOURCES

- Waterways — https://github.com/Arnklit/Waterways · README https://raw.githubusercontent.com/Arnklit/Waterways/main/README.md · branches/commits via GitHub API · Asset Library (Godot 3.2 listing) https://godotengine.org/asset-library/asset/805
- Waterways .NET — https://github.com/Tshmofen/waterways-net · https://godotengine.org/asset-library/asset/2607
- Boujie Water Shader — https://github.com/Chrisknyfe/boujie_water_shader · https://godotengine.org/asset-library/asset/2070
- Godot-Ocean-Shader — https://github.com/immaculate-lift-studio/Godot-Ocean-Shader
- godot4-oceanfft — https://github.com/tessarakkt/godot4-oceanfft
- Godot-4-Realistic-Water — https://github.com/spicyhaydenc/Godot-4-Realistic-Water
- GodotSSRWater (custom SSR for transparent water) — https://github.com/marcelb/GodotSSRWater
- Godot Asset Library, water filter, sorted by update — https://godotengine.org/asset-library/asset?category=&godot_version=&sort=updated&filter=water
- Screen-reading shaders (SCREEN_TEXTURE / DEPTH_TEXTURE rules) — https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
- SSR not available on transparent materials — https://github.com/godotengine/godot-proposals/discussions/7274 · https://github.com/godotengine/godot/issues/79549
- Godot 4.7 release notes — https://godotengine.org/releases/4.7/
- Terrain3D + water (community workaround only) — https://forum.godotengine.org/t/applying-a-water-caustics-shader-to-terrain3d/84714
- PSX Style Water Surface (MIT) — https://godotshaders.com/shader/psx-style-water-surface-pixelation-waves-scrolling-textures/
- PSX technique references — https://www.david-colson.com/2021/11/30/ps1-style-renderer.html · https://godotengine.org/asset-library/asset/4687 · https://godotengine.org/asset-library/asset/2989
- Godot River & Waterfall / Stylized Water (commercial, feature checklists) — https://gameidea.org/assets/godot-river-waterfall/ · https://gameidea.org/assets/godot-stylized-water-shader/
