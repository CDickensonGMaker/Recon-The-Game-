# TERRAIN & VEGETATION — the workflow that already exists

**Written 2026-07-12.** Supersedes the first draft of `BLENDER_TERRAIN_SPEC.md`, whose item #0 was
**wrong** (see §6). Read this one.

---

## TL;DR

> **Do not sculpt terrain in Blender. Do not hand-model trees.**
>
> The ground is **generated from a seed, in code.** The jungle is **composed by a headless Blender script**
> from a library of 30 procedural species into **23 pre-baked 12m patches**. Both already work.
>
> **You do not model the jungle. You model the SPECIES — and the generator composes the jungle.**
>
> **The real gap is that THERE IS NO CREEK** (§5). Water exists only as rice paddies. The trail-breaker
> that makes the whole E&E fantasy work has no art to run on.

---

## 1 · Godot 4.7 has no terrain node. Here are the three real options.

| Option | What it is | Verdict |
|---|---|---|
| **A. Code-generated heightmap** | `FastNoiseLite` → heightmap → chunked meshes built with `SurfaceTool` + trimesh collision | **This is what you have, and it is correct.** |
| **B. A plugin** (Terrain3D, HTerrain) | GPU-clipmap terrain, texture splatting, editor sculpt tools | Prettier, and it fights everything below |
| **C. Sculpt in Blender, import a static mesh** | one big mesh, hand-authored | **Forbidden by your own design — see §2** |

---

## 2 · Why sculpting terrain in Blender would KILL the game you designed this morning

**ADR-017 (the persistent province)** says the world is **generated once from a province seed and rebuilt
on demand.** Your exact words, four hours ago:

> *"i dont want a super memorized map that i spent tons of time on crafting but its easy to 'beat'."*

**A hand-sculpted Blender terrain IS that map.** You cannot have "random per campaign, fixed and learnable
within it" from a mesh you carved by hand. **The procedural terrain is not a compromise — it is the
decision you already made, and the province architecture depends on it.**

Two more reasons it is locked:

- **The ground craters.** `damage_system.gd` and `clearing_system.gd` deform the heightmap live (grenades,
  mortars, bombs, bulldozed vegetation). You cannot crater an imported Blender mesh without rebuilding it.
- **ADR-013:** a 1.5km AO loads whole, as 5×5 chunks. That is a chunked *generator*, not a single mesh.

---

## 3 · What actually exists (and it is good)

### THE GROUND — `terrain/core/`
`terrain_engine.gd` builds a heightmap from **FastNoiseLite with domain warp** (Vietnam-style ridges and
valleys). `terrain_manager.gd` cuts it into **256m chunks**; `terrain_chunk.gd` builds each one with
SurfaceTool and cooks a trimesh collider. `gameplay_grid.gd` is the **gameplay truth**: terrain type,
**vegetation density (0–1)**, water, passability.

**Nothing to model. You tune noise profiles and biome presets, not meshes.**

### THE JUNGLE — `tools/make_jungle_flora.py` + `tools/make_jungle_patches.py`

```bash
blender -b -P tools/make_jungle_patches.py     # <- THIS is "the vegetation pipeline"
```

**`make_jungle_flora.py`** (798 lines) — the **species library**. Thirty plants, each built procedurally
from primitives: `broadleaf_tree`, `bamboo_stand`, `elephant_grass`, `fern`, `bush`, `banana`,
`palm_sapling`, `fallen_log`, `hanging_vine`, `trunk_vine`, `rice_clump`, `moss_patch`, `tall_grass`…
Colour comes from a **palette atlas indexed by vertex colour** — no textures, so an entire patch is
**one draw call**.

**`make_jungle_patches.py`** (805 lines) — composes those species into **12m tiles**, and it is smarter
than it looks:
- **Poisson-disc spacing** per species (pure random clumps; a grid reads as a grid)
- **Overhang past the tile edge**, so neighbouring tiles interlock and *the seams disappear*
- Research-driven stratification: primary forest floor is nearly **bare** (closed canopy takes 95–99% of
  the light); the impenetrable stuff is **secondary growth** where the canopy was broken; lianas are
  thigh-thick and strung between crowns
- Bakes each patch to **ONE merged mesh** plus a `_far` **LOD twin**, exports GLB + `patches.json`

**`terrain/vegetation/jungle_patch_layer.gd`** stamps them as **MultiMesh**, one instance per patch type
per chunk — a handful of draw calls for an entire chunk of jungle.

### The 23 patches you already have

| density | patches |
|---|---|
| **open** | `patch_open` (crater/burn) · `patch_clearing` · `patch_grassfield` *(chest-high — crouch and vanish)* |
| **paddy** | `patch_paddy` · `_quad` · `_fallow` · `_grove` · `_edge` *(paddy meets treeline — the killing ground)* |
| **light** | `patch_understory` *(PRIMARY: big boles, bare floor, lianas)* · `patch_fern_floor` · `patch_scrub` · `patch_trail` |
| **medium** | `patch_canopy` · `patch_deadfall` *(blowdown)* · `patch_palmgrove` · `patch_vine_hall` |
| **dense** | `patch_grove` · `patch_bamboo_grove` · `patch_secondary` *(riot of light)* · `patch_elephant` *(elephant grass sea)* |
| **wall** | `patch_thicket` *(no sightlines — where an ambush lives)* · `patch_tangle` *(cut through it)* · `patch_bamboo_wall` |

---

## 4 · Where YOUR Blender work plugs in — three levels, cheapest first

### LEVEL 1 — a new PATCH (pure composition, **no modelling at all**)
Write a function in `make_jungle_patches.py` that arranges **existing** species. ~20 lines of Python.
This is where nearly all the remaining value is. **Start here.**

### LEVEL 2 — a new SPECIES (procedural)
Add a builder to `make_jungle_flora.py` alongside the other thirty. Primitives, palette index, done.

### LEVEL 3 — a hand-modelled hero species (**real Blender work**)
Worth it for one or two signature assets — a **buttress-root tree** you can genuinely hide behind. Import
it in `flora.py` and instance it into patches like any other species.

**Contract if you do this:**
- **one mesh, one material** (it gets merged into the patch and MultiMeshed)
- **palette-indexed vertex colours** (`Col` attribute) — or add your colour to `PALETTE` in `flora.py`
- **Z-up in Blender, origin at the base of the trunk**, real-world scale in metres
- **~200–800 tris** — it will be instanced hundreds of times
- **no collider in the mesh.** See §7.

---

## 5 · ⚠ THE ACTUAL GAP: **THERE IS NO CREEK.**

I shipped **water breaks trail** an hour ago (`probe_hunt` scenario 8). Wade a stream and you lay no
breadcrumbs; the freshest sign stays at the bank you went *in* at. **Measured: wade 60m east up a creek and
an NVA sweep pushes 87m NORTH, hunting empty jungle.** That is the "made it out alive."

**It has no art to run on.** Of 23 patches, **zero** are creeks. `grep -icE "creek|stream|river|ford"` in
the patch generator returns **0**. The only water in the game is **rice paddies** — which are *open*,
*exposed*, and conceal nothing.

**So the single most valuable thing you can make right now is not a tree. It is a stream.** And it is a
LEVEL 1 job — composition, not modelling:

| New patch | Why it matters |
|---|---|
| **`patch_creek`** | a channel running the tile, cut banks either side. **The escape hatch.** |
| **`patch_creek_bend`** | so a creek can *meander* and a chase crosses the same water twice |
| **`patch_ford`** | shallow crossing — where *they* cross too, so it is watched |
| **`patch_creek_canopy`** | a stream under closed canopy: **erases your trail AND hides you.** The best tile in the game. |

The bank is the money detail: **a cut bank is prone cover AND water at the same time.**

**Second gap: nothing is flagged as an LZ.** `patch_open` and `patch_clearing` exist, but nothing tells the
engine *"a Huey can get down here."* The climax of an E&E run is sprinting for a hole in the canopy with a
net closing behind you — and right now there are no holes. Add an `lz: true` flag in `patches.json` and
author the clearings on purpose. **There should never be many.**

---

## 6 · The thing I got wrong in the first draft (correcting the record)

The first version of this doc opened with: *"the AI does not look at your meshes — you must hand-tag every
asset with `conceal` / `conceal_r` / `conceal_h` or the art will be a lie."*

**That is backwards, and it is worth understanding why.**

`GameplayGrid` is the **source of truth**, and `jungle_patch_layer.gd` **reads it to choose the art** —
terrain type → density class → a patch of that class. So the concealment the AI uses and the vegetation you
see **are the same number, by construction**. You *cannot* desync them, because **you never hand-place
vegetation at all.** The grid places it.

Which means the interesting question is not "how do I tag my assets" but: **does each density class LOOK
like what its sight-cap number claims?** `dense` and `wall` must genuinely kill sightlines at ~45m; `open`
must genuinely be 140m of exposure. That is an **art-vs-number calibration** job, and it is exactly what
the `patch_*` density classes are for.

---

## 7 · Collision: foliage blocks sight, never bullets (the Fairness Law)

Line-of-sight rays test **collision layer 1 (world)**. Patch meshes are MultiMesh instances and carry
**no collision at all** — which is *correct*: leaves that collided would be **bulletproof** and
**binary-opaque**, and the whole statistical concealment model would die.

Concealment is handled by the **density grid** (sight cap 140m open → 45m jungle) and by
`SmokeCloud`/foliage occlusion — *not* by ray-blocking geometry.

**The one thing worth adding:** a **trunk collider** on the handful of big boles per patch, so a tree you
dive behind actually stops a bullet. That is a `patch_*` authoring decision (emit a capsule collider list
alongside the mesh), not a per-asset one — and it is the difference between cover you can trust and cover
that is a lie.

---

## 8 · What to do next, in order

1. **`patch_creek` + `patch_creek_bend` + `patch_creek_canopy`.** ~60 lines of Python, no modelling. It
   turns the shipped trail-breaker from a system into a *game*.
2. **`lz: true` flag + authored clearings.** The bird needs a hole.
3. **Trunk colliders** on the big boles (§7) — cover you can trust.
4. **Calibrate density vs sight-cap** (§6): stand in a `dense` patch and check you actually cannot see 45m.
5. Only then: **Level 3 hero assets** — a buttress-root tree worth hiding behind.

*The chase is built and it is coming. Model the escape routes.*
