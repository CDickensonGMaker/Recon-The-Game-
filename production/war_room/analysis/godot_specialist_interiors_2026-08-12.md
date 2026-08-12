# GODOT SPECIALIST — Interiors: world-GLB vs Godot scenes

**War Room 2026-08-12 · Engine: Godot 4.7 stable, Forward+, GDScript strict**
**Method: read the code, not the docs. Every claim carries a `file:line`.**

> **THE QUESTION (verbatim):** *"should we just make scenes in godot and make the hooches that way
> or make them in blender as buildings with doors we can open etc and its all a part of the live
> world... i lean on having it all in the live world but ive yet to get multiplanar scenes made but
> imagine we could just put bunkers that sit under the terrain and the player can walk into it with
> the stairs"*

---

## HEADLINE

**Option A is not a proposal. It is the architecture this game already ships, and it already works
for the player.** The council is not choosing between three designs; it is choosing whether to
finish one that is 90% built, and the missing 10% is **six lines in the nav baker**, not a rebuild.

His lean is correct, and the code agrees with him harder than he knows.

---

## 1 · WHAT IS ALREADY TRUE (the part nobody has written down)

### 1a. Village huts are ALREADY enterable, and it was deliberate

`scripts/world/collision_table.gd:10-12`, the comment above the entire village block:

```
# Village (tools/gen_village.py). ALL trimesh: these are enterable, and a box
# hull would seal the doorway the generator verified you can walk through.
```

Every one of the 26 village entries carries `"mesh": true`. The temple set says it again at
`collision_table.gd:88-89`: *"Trimesh so the cella interiors stay walkable — a box hull here would
seal them shut."*

`site_planner.gd:182-191` is the machinery that honours it:

```gdscript
# mesh: true -> the GLB carries -col trimesh nodes (pow_cage, ruins). The
# authored box would double the collision AND block doorways/breaches, so
# skip it; the box entry above still drives the nav carve.
if not bool(entry.get("mesh", false)):
    ... add BoxShape3D ...
```

**The player can walk into a village hut today.** This is shipped, tested-by-generator, and
undocumented in any design doc.

### 1b. The firebase interiors are ALREADY walkable, and two functions exist ONLY to service them

The demo boots the player **seated on a bunk inside a hootch** — `game_flow.gd:_firebase_bunk`,
reading **68 `prop_sleep` markers** baked into `fsb_main_v3.glb`, each keeping *"its own authored
height, which is the floor it stands on"* (`game_flow.gd:124-127`).

Two purpose-built floor probes exist and both were written because of interiors:

- `game_world.gd:404-423 surface_y()` — top-down ray from `ground + 18.0 m`, because *"fsb_main_v3
  is authored with y=0 at the mound TOE and reaches y=14.5"*.
- `game_world.gd:436-445 floor_y()` — short-reach probe from just above the caller's Y, added
  because **surface_y's top-down ray "stood every covered garrison post — and the whole squad,
  ringed around an indoor bunk — ON THE ROOFS (his playtest, 2026-08-04)."**

You do not write `floor_y()` unless you already have interiors. **He has them. He has had them
since at least 4 August.**

### 1c. The nav baker ALREADY has the interior path built and proven at 370 m

`nav_baker.gd:150-159 _queue_firebase` + `:374-399 _add_colliders` walk the firebase's real
`-colonly` trimeshes into the navmesh, by hand, shape by shape:

```
# So this one site parses the real `-colonly` trimeshes instead: the exact colliders
# move_and_slide() hits, so navmesh and physics cannot disagree.   (nav_baker.gd:38-41)
```

It runs over a **185 m half-extent box (370 m across)** with the full 1259-node compound in it
(`FSB_HALF = 185.0`, `:43`). And `queue_site_with_colliders()` (`:146-148`) already exposes that
exact path as a **public, reusable call** — it was written so *"a bench can prove a breach through
exactly the geometry the compound uses."*

**The general-purpose "bake real interior geometry for an arbitrary site" function exists, is
public, and is called by exactly one thing.**

---

## 2 · THE ACTUAL DEFECT (and it is small)

The briefing says "interiors are currently NOT properly walkable." That is right about **AI** and
wrong about the **player**, and the distinction is the whole finding.

`site_planner.gd:176-181` — every structure with a non-zero box, **including every `mesh: true`
enterable one**, joins `nav_blockers`:

```gdscript
var box_size: Vector3 = entry.box
if box_size.length() > 0.01:
    body.add_to_group("nav_blockers")
    body.set_meta("nav_box", box_size)
```

`nav_baker.gd:441-469 _add_structures` then **carves that entire footprint out of the navmesh,
inflated by `AGENT_RADIUS + 0.15`**:

```gdscript
var inflate: float = AGENT_RADIUS + 0.15
...
source.add_projected_obstruction(corners, p.y, maxf(size.y, 1.0), true)
```

> **So: for every hut, temple and ruin the player can physically walk into, the AI navmesh has a
> solid hole the shape of the building, half a metre bigger on every side.** The player enters. No
> NPC ever can, and no NPC ever will, no matter how good the doorway geometry gets.

That is the bug. It is not an architecture problem and it does not need Blender.

### The fix, in full

In `_add_structures`, skip any blocker whose CollisionTable entry is `mesh: true`; feed those
buildings through the already-written `_add_colliders` instead. The mechanism is proven at 370 m;
this is applying it at 70 m. Two touches:

1. `site_planner.gd:180` — set a second meta (`nav_trimesh = true`) when `entry.mesh` is true.
2. `nav_baker.gd:443` — `if body.get_meta("nav_trimesh", false): continue` in `_add_structures`,
   and walk those roots through `_add_colliders` in the same bake.

**Named cost:** the bake stops being one polygon-carve per building and becomes N trimesh faces per
building. `_process` bakes **one region at a time** (`nav_baker.gd:241-249`), so a village bake gets
slower, not the frame. Acceptable. It is also the only version where navmesh and physics cannot
disagree — the same argument the firebase path already won on.

---

## 3 · THE THREE OPTIONS, SCORED

### Option A — authored in Blender, into the world, interiors live

| Axis | Verdict |
|---|---|
| **Nav baking** | Already solved. `_add_colliders` (`nav_baker.gd:374`) + `queue_site_with_colliders` (`:146`) are built and proven. Needs the §2 fix. |
| **Destructible-name contract** | **Native.** Ballistics reads the **collider** name (`site_planner.gd:1356 _tag_fsb_ballistics` for the compound; `CollisionTable.is_soft(model_name)` at `:162` for placed buildings). Destruction reads the **MeshInstance3D** name by prefix (`:1552-1576`). Both contracts live in the GLB. A GLB *is* the contract's native format. |
| **Doors / animation** | Via markers, not GLB animation. See §5. |
| **Perf** | Neutral-to-better. See §4. |
| **Iteration (solo)** | Best for reusable kit pieces (one GLB → one `place_structure` call → two table rows). **Worst for anything welded into `fsb_main_v3.glb`** — see the named tradeoff, §7. |
| **Village / camp scale-up** | Survives cleanly. `place_structure` is one generic function; new building = 1 CollisionTable row + 1 MATERIALS row + named markers. |

### Option B — separate `.tscn` scenes instantiated into the world

Not blocked by anything — `place_structure` calls `load(model_path)` (`site_planner.gd:163`) and
derives identity from `model_path.get_file().get_basename()` (`:149`), so a `.tscn` flows through
the same pipe. **It is blocked by what it costs.**

- **It creates a second authoring surface with nothing enforcing parity.** The ballistics key is the
  file basename, the destruction key is the mesh-name prefix, the nav key is the CollisionTable row,
  and the furnishing key is the marker names (`_find_markers`, `site_planner.gd:574`). In a GLB all
  four come out of one Blender export together. In a hand-built `.tscn` all four can drift
  independently, silently, and in the direction the skill warns about: **unrecognised ballistics
  defaults to `hard_surface` and unrecognised destruction defaults to nothing wired, with no error.**
  This project already lost a bunker to that class of failure — `barracks_bunker.glb` was **soft
  cover because its name contained "rack"** (`collision_table.gd:189-198`).
- **It buys no perf.** A `.tscn` wrapper does not merge draw calls; it adds `instantiate()` cost per
  placement.
- **It scales worst.** 20 building types = 20 hand-maintained scenes = 20 fossil sites. Against the
  FOSSIL LAW this is the option that manufactures the disease.

**Where B is genuinely right:** things that are *pure behaviour with trivial geometry* — a door leaf,
an interactable, a spawn volume. Which is exactly §5.

### Option C — hybrid (shell in the GLB, interior as a scene)

**Reject the version in the question. Adopt a different hybrid.**

Splitting shell-from-interior is the worst of both: the shell's `-colonly` and the interior's
`-colonly` are two colliders that must agree about where the doorway is, across two files, with
nothing checking. That is a seam, and seams in this repo become fossils.

**The hybrid that wins is the one the codebase already invented: GEOMETRY IN THE GLB, BEHAVIOUR IN
GODOT, MARRIED BY NAME.** It is running in four places right now:

| Prefix | Adopted by | Line |
|---|---|---|
| `work_*` | garrison posts, gun crews, civilian occupations | `site_planner.gd:592-594`, `:991-1003` |
| `prop_*` | interior furnishing | `site_planner.gd:555-557` |
| `prop_sleep` | the demo's opening bunk | `game_flow.gd:124-127` |
| `ANIMAL_HOME_PREFIX` / `_GRAZE_` | stabled + grazing animals | `site_planner.gd:514`, `:545` |

`fsb_main_v3.glb` carries **191 work markers** (`site_planner.gd:909`) and **68 `prop_sleep`**
markers. **The name-marker contract is this project's most successful pattern and nobody has named
it.** Every new interactive interior feature should be a new prefix and one row of GDScript.

---

## 4 · PERF AT PS1 FIDELITY — the honest bill

Interiors are not free, and the reason is **not** triangle count.

- **There is no occlusion culling in this project.** `OccluderInstance3D` has **zero hits in
  `scripts/` and `scenes/`**; the only mention repo-wide is `production/research/GAME_AUDIT_2026-07-12.md:130`
  noting it is off. Every interior wall, bunk, crate and hanging bulb inside a hooch **renders while
  you stand outside it.**
- `_apply_visibility_range` (`site_planner.gd:213-220`) sets `visibility_range_end = 230.0` on every
  GeometryInstance3D. That is **distance** culling. At 20 m from a village it does nothing.
- `_furnish_interior` (`site_planner.gd:555-557`) instantiates a prop per `prop_*` marker per
  building, and every village building is furnished (`:302`).

**This bill is identical under A and B.** Scene-vs-GLB does not touch it. Do not let anyone argue
Option B on perf.

**The three real levers, in cost order:**

1. **Nearest-neighbour 3D scaling filter (4.7).** Drop `scaling_3d/scale` below the current 0.77
   with nearest filtering. Fill-rate is the 19–25 FPS bottleneck and this **looks more PSX, not
   worse.** Free headroom that pays for interiors.
2. **Stencil buffer (4.5, all backends).** `stencil_write_mode` / `stencil_read_mode` gives portal
   and geometry-hole masking without CompositorEffect work. This is the correct tool for "stop
   rendering the interior from outside" — cheaper than baking occluders across a procedural AO, and
   it is the one that also serves the doorway.
3. **Bake `OccluderInstance3D` on building shells only.** Buildings are good occluders (the canopy
   is a terrible one — do not just flip the global flag). Per-GLB, at export.

---

## 5 · DOORS

**`AnimatableBody3D` has zero hits repo-wide.** There is no door system in RECONgame.

There is **one** door in the project and it is in zombie mode — `scripts/zombies/zombie_door.gd`,
and its header states the ruling that should be copied verbatim (`:6-12`):

```
## NAVIGATION: the navmesh is baked with every doorway OPEN and never rebakes
## (same reasoning as ZombieBarricade). A closed door is a physical blocker only.
```

That is right, and the open-sim has the half zombie mode lacks: **`NavBaker.breach_at()` +
debounced rebake** (`nav_baker.gd:193-199`, `:223-238`) already exists, so a door *can* trigger a
rebake if one is ever genuinely needed.

**The pattern:**

- **Doorway = an open hole in the GLB.** Always. Bake it open, forever.
- **Door leaf = a named marker in the GLB** (`door_*`, joining `work_*` / `prop_*`), adopted by an
  `AnimatableBody3D` + a `Tween` in Godot. `Tween.tween_await()` (4.7) sequences it in one call.
- **Never** ship a per-building `AnimationPlayer` inside the world GLB. In a 1259-node import those
  are unaddressable, unnamed by contract, and invisible to every system that reads this world.

Doors are a **Godot-side** feature attached to **Blender-side** markers. That is Option C's correct
form, and it costs one prefix.

---

## 6 · UNDER-TERRAIN BUNKERS — the direct answer

**Yes, and he does not need a hole in the terrain to get it. The firebase already does this.**

### 6a. What would ACTUALLY block a literal below-heightmap interior — three things

1. **Terrain collision has no hole mechanism.** `terrain_chunk.gd:61-110` emits **every quad** of a
   128×128 grid at 2 m spacing, unconditionally; `:228` turns that whole mesh into
   `create_trimesh_shape()`. A stairwell descending below the surface is roofed by a solid terrain
   triangle. There is no cutout parameter and no skip-quad path.
2. **The nav baker seals it a second time.** `_add_terrain` (`nav_baker.gd:326-344`) synthesises
   terrain faces from the heightmap at `GRID_STEP = 4.0 m` **across the entire box, unconditionally**.
   Even with a hole in the visual terrain, the navmesh would close it — and at 4 m sampling a 2 m
   stairwell is not even representable.
3. **There is no link mechanism.** `NavigationLink3D` appears **zero times repo-wide**
   (`production/CALEB_TODO_7_22_updated.md:508`). Two disconnected nav layers have nothing to join
   them today.

**And the multi-level failure mode is already documented in this file** — `nav_baker.gd:167-169`:
*"Overlapping, non-coincident regions produce no edge connections and `map_get_closest_point()`
picks arbitrarily — paths teleport between layers."* That is exactly what a naive two-level bunker
produces.

### 6b. Why none of that matters — build the earth UP, never dig DOWN

`game_world.gd:400-403`:

> *"fsb_main_v3 is authored with y=0 at the mound TOE and reaches y=14.5 (site_planner.gd), so the
> earth mound stands proud of the seated plateau."*

And `clear_and_flatten` (`site_planner.gd:116-127`) makes the ground under a site **flat**.

**So the firebase already has 14.5 m of vertical relief that is not terrain.** The recipe for a
dug-in bunker with zero engine work:

1. `clear_and_flatten` levels the pad. Bunker **floor sits at plateau level, y ≈ 0**.
2. The GLB builds an **earth berm up around and over it** — the roof is authored geometry that reads
   as packed earth and sandbag.
3. The player walks **up** the berm and **down a ramp** into the doorway. He is below the surrounding
   grade because the grade was **raised**, not because the ground was **dug**.
4. `surface_y`'s 18 m probe (`game_world.gd:428`) and `floor_y`'s short-reach probe (`:436`) already
   handle exactly this seating case. They were written for it.

**Read from outside it is indistinguishable from a hole in the ground. Read from the engine it is
one connected navmesh layer, one terrain trimesh, no links, no cutouts, no new code.**

If he later wants a genuinely below-grade complex (a tunnel system), the *smallest* honest path is:
`terrain_manager.modify_terrain()` (`terrain/core/terrain_manager.gd:289`) to **depress** the
heightmap into a bowl at worldgen, drop the GLB in the bowl, cap it with authored earth. Still one
nav layer, still no cutouts. **Do not write a second terrain deformer** — that one already exists and
craters use it.

### 6c. THE NUMBERS THE MODELLER NEEDS — and one of them is a trap

`project.godot` has **no `[navigation]` section** (verified: sections run
`[animation] [application] [audio] [autoload] [debug] [display] [editor] [filesystem] [input]
[layer_names] [physics] [rendering]`). So the nav map runs at Godot's **0.25 defaults for both
`cell_size` and `cell_height`** — which `nav_baker.gd:260-263` already documents as a defect source.

`nav_baker.gd:268-271` then **quantises the agent metrics to voxel units**, and the results are not
what the constants say:

```gdscript
nav.agent_radius    = ceilf(0.5 / 0.25) * 0.25   = 0.50 m
nav.agent_height    = ceilf(1.8 / 0.25) * 0.25   = 2.00 m   ← NOT 1.8
nav.agent_max_climb = floorf(0.4 / 0.25) * 0.25  = 0.25 m   ← NOT 0.4
nav.agent_max_slope = 50.0°
```

**THE AUTHORING CONTRACT — hand these five numbers to whoever models the hooch, the bunker and the
HQ tent:**

| Constraint | Minimum | Why | Pointer |
|---|---|---|---|
| **Interior headroom** | **≥ 2.0 m** clear | `agent_height` quantises **1.8 → 2.0**. A PSX hooch modelled at 1.9 m internal bakes **zero navmesh inside** and looks completely fine. | `nav_baker.gd:269` |
| **Doorway clear width** | **≥ 1.4 m** | Recast erodes by `agent_radius` 0.5 from *both* jambs. Below 1.0 m nothing bakes at all; 1.4 m leaves a usable corridor. Player capsule is only 0.4 (`scenes/player/*.tscn:10`) — **a doorway the player fits is not a doorway an NPC fits.** | `nav_baker.gd:45`, `:268` |
| **Interior corridor width** | **≥ 1.4 m** | same erosion | ” |
| **Descent** | **ramp ≤ 50°**, or steps with **riser ≤ 0.25 m** and **tread ≥ 0.50 m** | `agent_max_climb` quantises **0.4 → 0.25**. A real-world stair (0.18 riser / 0.28 tread) is 1 voxel of tread at `cell_size` 0.25 and will bake unreliably. **Ramps, not stairs — or very shallow steps.** | `nav_baker.gd:270-271` |
| **Do not dig below the flattened pad** | — | §6b | `game_world.gd:400-403` |

> **His instinct — "bunkers that sit under the terrain, walk in with stairs" — is buildable this
> week. Change "stairs" to "ramp" and "under the terrain" to "under an authored earth cap", and it
> needs no new engine code at all.**

---

## 7 · GODOT 4.7 vs 4.3/4.5 — what actually changes the answer

**Changes it:**

- **Nearest-neighbour 3D scaling filter (4.7).** The perf headroom that pays for interiors, and it
  is *aesthetically aligned* — more PSX, not worse. This is the single biggest thing 4.7 gives this
  decision.
- **Jolt stable + default (4.6).** Trimesh interiors with a `CharacterBody3D` were genuinely dicey
  on 4.3's default physics — seam-catching in concave corners was the standard argument *against*
  walkable trimesh interiors. That argument is gone.
- **CSG autosmooth (4.7).** Blockout the bunker's shape *in-engine* and walk it before committing
  Blender hours. The right way to answer "does this ramp feel like descending into a bunker."
- **`Tween.tween_await()` (4.7).** Door sequencing without callback chains.
- **Stencil buffer (4.5).** The cheapest available interior/exterior masking. Underused here.

**Does NOT change it, despite looking like it should:**

- **Import a 3D scene as Mesh / MeshLibrary (4.7).** GridMap-able interior kits without a DCC
  re-export — genuinely useful in the abstract, and **wrong for RECONgame**: GridMap carries no
  `-colonly` collider names, so it satisfies neither the ballistics contract (`site_planner.gd:1356`)
  nor the destruction contract (`:1552-1576`). It would ship a modular bunker that is silently
  bulletproof and indestructible. **Do not take this bait.**
- **Nothing in 4.7's navigation changes adds multi-level linking.** `NavigationLink3D` has existed
  since 4.0. Its absence here is a *choice*, not an engine limit.

**One 4.7 audit item if multi-level is ever attempted:** `map_get_closest_point_normal` now returns
a normalized vector — any nav slope/normal logic written pre-4.7 that consumed the raw magnitude is
now wrong.

---

## 8 · RECOMMENDATION

**OPTION A, with the marker hybrid — and it is a finishing job, not a build.**

1. **Ratify the two-lane rule.** `fsb_main_v3.glb` stays one GLB because it is **one authored
   place**. Everything reusable — the hooch, the dug-in bunker, the officers' HQ tent, every village
   and enemy-camp building — is its **own GLB** placed by `place_structure`, exactly like all 26
   village models already are. **Both lanes exist and both are shipped.** He should not be adding
   new hooch types into the compound GLB.
2. **Fix the nav carve (§2).** Six lines. This is what "make interiors walkable" actually means, and
   it lights up every hut, temple and ruin already in the game at once.
3. **Adopt the `door_*` marker prefix (§5).** Doorways bake open; leaves are Godot-side
   `AnimatableBody3D`.
4. **Ship the dug-in bunker by building earth UP, never digging DOWN (§6b).** Ramp, not stairs.
5. **Hand the modeller the five numbers in §6c before a single polygon is cut.**
6. **Backstop the perf (§4):** nearest-neighbour scaling first, stencil masking second, shell
   occluders third.

### THE TRADEOFF, NAMED — no free lunches

**Three prices, and the third is the one that will actually bite:**

1. **Every walkable interior renders from outside, and this project has no occlusion culling.**
   Zero `OccluderInstance3D`, on a 19–25 FPS Intel UHD floor, in a village of ten furnished huts.
   Option B does not fix this; nothing fixes it for free. **We are spending frame budget to buy
   interiors, and we are spending it before we have measured it.** Blockout one furnished village
   and read the frame time *before* the art is final.

2. **The nav bake stops being free.** Trimesh interiors multiply the source geometry per building,
   and `_process` bakes one region at a time (`nav_baker.gd:241-249`). Load-time, not frame-time —
   but a village bake will be measurably slower than the projected-obstruction carve it replaces.

3. **THE REAL ONE — the re-export round trip on the compound.** Anything welded into
   `fsb_main_v3.glb` costs a **13.4 MB whole-compound re-export** to change one hooch, *and* if the
   parapet segments shift, `firebase_v3_destructibles.json` must be regenerated from **the same
   export** or **80 sandbag segments silently unwire and the siege goes blind** — the manifest is an
   exact-string `find_child()` match (`site_planner.gd:1496`), and the only tell is one stdout line.
   Rule 1 above is the mitigation and it is not optional: **new interior building types go in their
   own GLBs, or iteration speed on this feature dies inside a month.**

**What we are NOT buying:** long-range AI pathing into interiors. `nav_baker.gd:18-21` names that
tradeoff already — islands by design, no border stitching, an enemy 300 m out bee-lines. An NPC will
enter a hut he is *near*. He will not path across the AO to get inside one. That is correct for this
game and it should stay correct.

---

## 9 · WHAT I COULD NOT VERIFY

- **Whether the village GLBs' doorways actually clear 1.4 m.** `collision_table.gd:11` says the
  generator verified you can walk through — but the player capsule is **0.4** and the nav agent is
  **0.5**. A doorway that passed the generator's check may still bake shut for AI. **Measure the
  doorway widths in `tools/gen_village.py` before assuming the §2 fix lights them up.** This is the
  most likely reason the fix under-delivers.
- **`cell_height` = 0.25** is inferred from the absence of a `[navigation]` section plus Godot's
  documented default, the same reasoning `nav_baker.gd:260-263` uses for `cell_size`. It is worth
  one `print(NavigationServer3D.map_get_cell_height(map))` to make it a measured fact rather than an
  inferred one, because **the 1.8 → 2.0 m headroom inflation depends on it** and that number is
  going to a modeller.
