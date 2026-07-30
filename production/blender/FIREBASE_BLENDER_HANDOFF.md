# FIREBASE — BLENDER HANDOFF

**Everything to do on the Blender/generator side next time the firebase is opened.**
Written 2026-07-29 out of the demo playtest council
(`production/war_room/2026-07-29_demo_playtest_collision/`).

Files:
- Generator: `tools/gen_firebase_v3.py` (with `tools/fb_kit.py`, `tools/gen_firebase.py`)
- Blend: `production/blender/.../firebase/kit/firebase_v3.1.blend`
- Export target: `assets/world/building models/structures/firebase/fsb_main_v3.glb`
- Export: `export_firebase()` — **headless only** (`blender -b`), per the standing rule.

---

## THE CHECKLIST — what a re-export buys, and what still needs hand work

Everything in **A** is already fixed in `gen_firebase_v3.py` and lands the moment you re-export.
Godot repairs each of them at load today, prints a count, and those counts drop to 0 once the
new GLB is in — that is the signal to delete the repair code (`site_planner._repair_glb_colliders`).

| | Item | State |
|---|---|---|
| **A1** | `fb_terrain_mound` → `COL_NONE` (terrain is the ground now) | generator done, re-export |
| **A2** | `fb_sbg_seg_` → `COL_TRIMESH` (shoot through, and stop the box burying the berm) | generator done, re-export |
| **A3** | 5 merged solid veg objects → `COL_TRIMESH` (see §3) | generator done, re-export |
| **A4** | mound manifest written on export (`write_mound_manifest`) | generator done, re-export |
| **B1** | **Fire slits** cut into the parapet + verify bunker embrasures | §2 — hand work |
| **B2** | **Fighting step / banquette + flat berm crest** | §2b — hand work |
| **B3** | `Base_Human` donor rendering inside every US soldier | §5 — different .blend |

---

## §00. HOW TO EXPORT THE MOUND SO THE PLAYER CAN WALK ALL OF IT

His question, 2026-07-29: *"how do i export the model from blender to make sure the player can
walk on it all and not fall thru it or get stuck"* — and the ruling behind it: *"i want that
mesh mound because it showed destroyed earth and mud, so just moving the world terrain up
doesn't fix a lot of problems."*

**That ruling settles the architecture. The MODEL is the ground.** A 4 m heightmap can never
show a crater lip or a mud wallow; the mesh can. So `fb_terrain_mound` goes back on
`COL_TRIMESH` (it is on `COL_NONE` today), the terrain is flattened to the mound's TOE and
stays under it, and everything the player stands on comes from the GLB.

### The five things that make a walked-on trimesh fail, and the fix for each

**1. Falling through — flipped normals.** Godot's concave trimesh collision is generated
per-face; a face whose normal points down is a hole a capsule drops through, and it looks
identical to solid ground. **Fix:** select the ground mesh, Edit Mode, `A`, `Shift+N`
(Recalculate Outside). Then turn on Overlay → Face Orientation and look: any red is a hole.

**2. Getting stuck — unwelded seams.** The mound, the skirt and the berm are separate `bmesh`
builds. Where their edges nearly-but-don't-quite meet, a capsule catches on the crack every
time it crosses. **Fix:** join the ground pieces into ONE object and Merge by Distance
(`M` → By Distance, ~0.001). One continuous surface, no seams to catch.

**3. Getting stuck — faces steeper than the player can climb.** A `CharacterBody3D` walks up
to `floor_max_angle`, 45° by default. `crater_delta` throws up a rim, and the berm's inner
face is already 37°. Anything past 45° is a wall the player slides down, and it reads as
"stuck". **Fix:** check slopes before export — the recipe is below — and ramp anything over
~40° that a man is meant to cross.

**4. Getting stuck — the knife-edge crest.** `berm()` emits inner→crest and crest→outer with
NO cap, so the top is a single line of verts. There is nowhere to stand even after you climb.
**Fix:** cap it — a third quad strip between the inner and outer crest lines.

**5. Scale/transform not applied.** The collider is built from mesh data; an unapplied object
scale puts the collision somewhere the visual is not. **Fix:** `Ctrl+A` → All Transforms
before export. (`export_firebase` already exports with `export_apply=True`, so this mostly
bites on hand-made additions.)

### The slope check, before you export

```python
import bpy, math
ob = bpy.data.objects["fb_terrain_mound"]     # or the joined ground object
me = ob.data
bad = [p.index for p in me.polygons
       if math.degrees(p.normal.angle(( 0, 0, 1 ))) > 40.0]
print(f"{len(bad)} faces steeper than 40 degrees out of {len(me.polygons)}")
# select them so you can SEE where they are
import bmesh
bpy.ops.object.mode_set(mode='EDIT'); bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
for f in bm.faces: f.select = f.index in bad
bmesh.update_edit_mesh(me)
```
Run it headless or in the Scripting tab. Zero bad faces on the walked surface = he can cross
it. Any cluster tells you exactly which crater lip to soften.

### And the fighting step goes here too

Since the model is the ground, the banquette (§2b) is modelled, not raised in terrain: a flat
shelf ~0.9 m above the compound floor and ~1.2 m wide, running inside the revetment, with an
~11 m ramp up to it. That is what lets him see over his own parapet AND what the VC come up
once the sandbags are blown. **The terrain-side version is switched OFF (`step_h: 0.0` in the
mound manifest) precisely so it cannot bury the mud you want to see.**

### What Godot does automatically once this is right

- `fb_terrain_mound` on `COL_TRIMESH` → a `-colonly` twin sharing the real mesh
- `site_planner` stops stripping it, and stops sculpting terrain to match — **both of those
  are code changes I make when you re-export; tell me and they go in together**
- the one-ground probe keeps checking that terrain never rises through the model

---

## §0. How collision works in this pipeline — read this first

Godot builds a collider from any glTF node whose name **ends with `-colonly`**. That node is
**invisible in game** and exists purely as collision. `make_collision()` in the generator emits
one `-colonly` twin per solid object automatically at export time, then deletes the twins again
so they never live in the .blend.

There are exactly three behaviours, chosen by name prefix at the top of `gen_firebase_v3.py`:

| List | What the twin is | Use when |
|---|---|---|
| `COL_NONE` | no twin at all — you walk straight through | alpha cards, mud decals, ground paint |
| `COL_TRIMESH` | the twin **shares the real mesh** | anything with a doorway, a pit, a walkable top, **or a hole you shoot through** |
| *(default)* | an axis-aligned **box** wrapping the object's extents | simple solids: barrels, crates, a howitzer |

**The box is why you cannot shoot through sandbag cracks today.** A box hull fills every
opening in the mesh it wraps. Cut the prettiest embrasure you like into a parapet segment and
the box seals it shut — and gives you a flat ledge on top to stand on, besides.

**So: to shoot through something, that something must be on `COL_TRIMESH`.** That is the whole
answer. Nothing in Godot needs changing; the model carries its own holes.

### The cheaper option, if trimesh gets expensive

You do **not** have to make the pretty 9-course sandbag mesh be the collider. You can author a
**collision proxy**: a crude low-poly shell — a slab with the slit cut out of it — sitting in
the same place, named `<something>-colonly`. Godot renders nothing for it and collides against
it exactly. Visual mesh stays as detailed as you want, collider stays cheap, the slit is a real
hole in both. That is the standard way this is done, and it is the fallback if the trimesh
parapet costs too much.

---

## §1. Already changed in the generator — these take effect on your next export

I edited `tools/gen_firebase_v3.py`. Nothing here needs a decision from you; it just needs an
export to land.

1. **`fb_terrain_mound` moved to `COL_NONE`.** The GLB no longer ships a ground collider.
   Godot now sculpts the *terrain* to that mound's own surface, so the base stands on exactly
   one ground. Until you re-export, `site_planner._strip_mound_collider()` deletes it at load
   and prints `[FSB] stripped 1 duplicate mound collider(s)` — measured working. When your
   re-export lands, that count goes to 0 and the strip function should be deleted.

2. **`fb_sbg_seg_` moved to `COL_TRIMESH`.** The perimeter parapet becomes a real collider —
   lead through the cracks, and no flat 6 m slab to stand on. **Measure the cost**: ~50
   segments of 9-course bag geometry going box → trimesh. If it hurts, use a proxy (§0).

3. **`write_mound_manifest()` added**, called from `export_firebase()`. It writes
   `fsb_main_v3_mound.json` next to the GLB with `MOUND_H`, `R0`, `RIDGE_STRETCH`,
   `MOUND_FALL`, `BERM_W/H` and the `platform_z` harmonics. **Godot reads that file to shape
   the terrain.** It exists so the numbers are never hand-copied into GDScript — copy them and
   the day you tweak the mound, the terrain silently keeps the old shape and the "two floors,
   one invisible" bug comes straight back.

   **Consequence you must know: `platform_z()` is now a shared contract, not a private
   function.** Change the mound freely — but re-export, so the manifest travels with it.

---

## §2. Still to author in Blender — the fire slits

Nothing in the model has a firing embrasure today. `parapet_segments()` builds a solid
9-course wall; there is no notch, no slit, no step.

1. **Cut embrasures into a share of the parapet segments.** Roughly one in three — a
   continuous line of slits reads as a castle wall, not a firebase. Weight them toward the
   likely approach bearings rather than spacing them evenly.
2. **Add a firing step behind each slit segment.** A slit at course 6 with nothing to stand on
   is a slit nobody can use. Check it against eye height: the player's eye is ~1.6 m, and
   `BAG_H` × 9 courses is the wall.
3. **Verify the bunkers.** `fb_bunker_mg` and `fb_bunker_fighting` are already on
   `COL_TRIMESH`, so *if* an aperture is modelled, lead already passes. **Nobody has confirmed
   one is modelled.** Measure it — do not assume the trimesh flag means shootable.
4. **The gun pits, `fb_gun_pit` / `fb_mortar_pit`, are trimesh too** — same check applies to
   whatever you expect to shoot over or through there.

---

## §2b. THE FIGHTING STEP — you cannot see over your own wall

Owner, 2026-07-29 playtest: *"the ramp of the mounds aren't climbable so I cannot ever see over
the sandbag walls."*

Measured, not estimated:

| | value | source |
|---|---|---|
| berm height | 1.22 m | `BERM_H`, gen_firebase_v3.py:30 |
| berm width | 3.2 m | `BERM_W`, same line |
| parapet | 9 courses × 0.13 m = **1.17 m** | `courses=9` (:267) × `BAG_H` (fb_kit.py:22) |
| **parapet top above compound floor** | **2.39 m** | berm + parapet |
| standing eye height | ~1.6 m | player |

So the wall's top is **0.8 m over your eyes** and there is nothing to stand on. Two things
cause that, and both are geometry:

1. **The berm has no walkable top.** `berm()` (:206-226) emits two quad strips — inner→crest
   and crest→outer — meeting at a single line of verts. The crest is a **knife edge**, and the
   parapet sits directly on it. Climb the 37° inner face and you arrive at an edge with a wall
   on it and slide back off. That is the "ramp isn't climbable" report.
2. **There is no banquette.** A real firebase parapet is chest-high *to a man standing on a
   firing step*, not to a man standing in the yard.

**The fix, with numbers.** Add a flat step on the INNER face, running the perimeter, broken at
the gate:
- step top **0.9 m** above the compound floor, **1.2 m** wide
- eye on the step = 2.5 m vs parapet top 2.39 m → you see over by ~0.1 m standing, and
  crouching puts you completely behind cover. That is the feel to aim for.
- approach to the step becomes 0.9 m over ~1.6 m ≈ **29°** — comfortably walkable
- **also cap the berm crest flat** (a third quad between inner and outer crest lines) so the
  top is standable at all

Do this in the same pass as the fire slits (§2) — a slit and the step it is used from are one
piece of design, and the slit height should be set from the step, not the yard.

## §3. SOLVED — the four invisible platforms over the base (keep this; it is the pattern)

The Summoner spent three playtests getting stuck on invisible floors above the compound. The
decisive clue was his own: *"I should not be able to jump ONCE and be stuck above the firebase."*
One jump is ~1 m, not 12 — so it was never one object.

**`scatter_veg` (:522-570) MERGES every instance of a card type into ONE object** spanning the
whole ~300 m treeline ring. Five of those are solid, and none were on `COL_NONE`:

| merged object | instances | box-hull result |
|---|---|---|
| `fb_veg_tree_stump` | 90 | a 300 m slab at stump height — **the one-jump floor** |
| `fb_veg_fallen_log_a` / `_b` | 46 | slabs at log height |
| `fb_veg_felled_trunk` | — | slab |
| `fb_veg_felled_tree` | 16 | slab at **+12.5 m** — the high ceiling |

Each exported as ONE axis-aligned box wrapping the entire ring, ground to tallest instance:
four stacked invisible floors with walkable tops and impassable rims. Confirmed by the spawn
probe, which named `fb_veg_felled_tree` as the topmost hit 12.48 m over open ground; after the
fix that delta fell to 2.45 m and the top hit became a hootch roof.

**Fixed at source**: those five are now in `COL_VEG_SOLID`, folded into `COL_TRIMESH`, so they
export as real shapes. They stay solid — a man still walks round a stump.

**THE LESSON, which applies to anything else you merge:** the default box hull is fine for a
single compact object and catastrophic for a merged one. **If a generator function joins many
instances into one mesh, that object can never take a box hull.** Trimesh it or `COL_NONE` it.

Godot also now prints, every boot:
- `[FSB] N collider(s) floating >3m off the ground; worst: ...` — names anything standing on air
- `[FSB] one ground: N samples, worst gap Xm` — terrain vs the authored mound surface

Currently 2 floating colliders remain, both `fb_int_fb_hanging_bulb` at +4.4 m — those hang from
a roof and are correct. If that list ever grows, a new floater has shipped.

---

## §5. `Base_Human` — a second man inside every US soldier (different .blend)

Not the firebase file: this is the US body source (`us_base_v3.blend` → the `us_grunt_*` GLBs).

Every `us_grunt_*` GLB carries an un-kitted `Base_Human` mesh **alongside** its finished
`us_grunt_joined` body, and both render. Measured 2026-07-29 on every US unit in the game:

```
us_grunt_rifleman renders 2 body-sized meshes, not 1: Base_Human, us_grunt_joined
us_grunt_rto      renders 3: prc25_antenna, Base_Human, us_grunt_joined
```

Two symptoms, one cause: soldiers reading as **doubled up**, and a **black spot on top of every
helmet** — the base mesh's bare scalp poking through the helmet crown.

`ModelActor` hides gib donors by prefix (`grunt_` / `head_frag_` / `cap_`) and `Base_Human`
matches none of them, exactly as `helmet_camo_shell` slipped the same net before it. Godot now
hides it by name and a probe reports any body that renders more than one body-sized mesh.

**The clean fix is at export**: don't ship `Base_Human` in the game GLB, or rename it to the
donor convention (`grunt_base_human`) so it is covered by the rule rather than by a special case.

---

## §4. Standing rules for this model

- **Export headless.** `blender -b` only.
- **Numbered before the suffix.** `fb_hootch_007-colonly`, never `fb_hootch-colonly.007` —
  Blender's `.001` lands after the name and the node stops ending in `-colonly`, which imports
  as a silent invisible mesh with no collision at all.
- **`platform_z` is a contract now (§1.3).** Change it, re-export, so the manifest follows.
- **Purge orphans before saving** (`export_firebase` already does).
- **Re-measure the AABB consts** in `site_planner.gd` after any re-export —
  `tools/diag_fsb_seat` asserts them against the loaded GLB.
