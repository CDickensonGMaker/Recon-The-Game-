# HANDOFF — code fixes, 2026-08-12

**For a separate coding window. Caleb is in Blender in the other session — do not touch
`.blend` files, do not drive the Blender MCP, do not re-export any GLB.**

Every claim below carries a `file:line`. Items marked **VERIFIED** were read directly in the
source today. Items marked **CLAIMED** came from a War Room architect and still need checking
before you act on them.

---

## FIX 0 — THE PERIMETER WALL IS NOT IN THE NAVMESH (biggest single cause of "stuck")

**VERIFIED. `scripts/world/site_planner.gd:1607-1631` + `scripts/world/nav_baker.gd:374-390`.**

Every parapet segment is rebuilt at runtime: a `Destructible` is created and added to
`_parent` (**GameWorld**), the segment's `CollisionShape3D` is moved off its auto-generated
`StaticBody3D` onto that Destructible, the body is freed, and the mesh is reparented under it:

```gdscript
_parent.add_child(d)                 # d is under GameWorld, NOT under the firebase root
...
body.remove_child(shape); d.add_child(shape)
mi.reparent(d, true)
d.add_to_group(FSB_PARAPET_GROUP)
```

`nav_baker.gd:374 _add_colliders(source, root, box)` walks a stack seeded **only with the root
it is handed**. The parapets no longer live under that root, so **all ~80 perimeter colliders
are invisible to the bake.** The navmesh has no perimeter wall, and pathing routes men straight
into solid berm. `_rescue_snap` cannot recover them — they are standing on valid navmesh
(`scripts/allies/ally_base.gd:92`); the mesh is simply wrong.

**Fix (~8 lines, CLAIMED):** seed `_add_colliders`' stack with the `FSB_PARAPET_GROUP` members
in addition to `root`. Claimed side benefit: destroyed segments then bake as walkable, so
breaches become real paths.

**Note the second-order effect before you write it:** `nav_baker.gd:386` reads
`cs.get_parent().name` and matches it against `NAV_IGNORE_PREFIXES`. After the reparent the
shape's parent is the `Destructible`, not the original named node — so any name-based skip
logic behaves differently for these. Check that before assuming a straight stack-seed is safe.

---

## FIX 0b — no `[navigation]` section in `project.godot`

**VERIFIED.** `grep "\[navigation\]" project.godot` returns nothing.

Godot then uses `cell_height = 0.25`, and `nav_baker.gd:270` floors `agent_max_climb` to the
cell height — so the intended **0.4 m step becomes 0.25 m**. Every crater rim on the cratered
mound reads as a cliff.

**Fix (3 lines, CLAIMED — verify the values against Godot 4.7 before committing):**

```
[navigation]
3d/default_cell_height=0.2
```

plus `filter_walkable_low_height_spans = true` on the bake settings.

---

## FIX 0c — `-colonly` nodes are SIBLINGS, so 23 structures never hand over their colliders

**CLAIMED, verify.** `scripts/world/site_planner.gd:1706` `_adopt_structure` uses
`mi.get_children()` to find the collider to adopt, but the exported GLB is claimed to be flat —
all 365 `-colonly` nodes are siblings of their meshes, not children. If true, 23 bunkers/towers/
stacks never transfer their shapes, and a destroyed one stays solid forever, which contradicts
the assertion at `scripts/props/destructible.gd:176-179`.

Fix is claimed to be ~6 lines: look up the sibling by name, and preserve the transform at
`site_planner.gd:1625`.

---

## FIX 0d — `terrain_watchdog.gd:57` teleports allies onto roofs

**CLAIMED, verify** — same class as FIX 3 below. `scripts/missions/terrain_watchdog.gd:57` is
said to still call `surface_y`, so every non-squad ally crossing ~210 m gets re-seated on
whatever roof is above it. One-line change to `floor_y`, but confirm the point carries a
meaningful Y first.

---

## FIX 1 — the export overwrites its own source blend

**VERIFIED. `tools/gen_firebase_v3.py:918-930`.**

```python
clear_collision()
for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for d in list(blk):
        if d.users == 0:
            blk.remove(d)
bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)   # <-- line 929
```

It purges every zero-user mesh/material/image and then **saves over the source `.blend`**.
This is the call that destroyed the medical complex on 2026-07-31. A datablock with zero users
at export time is not necessarily garbage — anything held only by a collection that was
temporarily unlinked, or by an un-exported workbench, is deleted permanently.

**Fix:** do not write the source blend from the exporter. Either drop the `save_as_mainfile`
entirely (the export does not need it), or write to a `_postexport` sidecar path. If the purge
is genuinely wanted, it must run on a copy, never on the artist's file.

**Why first:** every other fix here eventually implies a re-export. Until this is disarmed, a
re-export can silently eat work. Nothing downstream is safe before it.

---

## FIX 2 — AI cannot path inside ANY placed building

**VERIFIED. `scripts/world/site_planner.gd:176-185` and `scripts/world/nav_baker.gd:441-469`.**

`site_planner.gd`:

```gdscript
body.add_to_group("nav_blockers")
body.set_meta("nav_box", box_size)
# mesh: true -> the GLB carries -col trimesh nodes ... The authored box would double the
# collision AND block doorways/breaches, so skip it; the box entry above still drives the nav carve.
if not bool(entry.get("mesh", false)):
    <box collision>
```

For `mesh: true` models the *collision* box is deliberately skipped so a man can walk through
the doorway — but the model stays in `nav_blockers` with a full-footprint `nav_box`.
`nav_baker.gd:441-469` `_add_structures()` then carves that footprint out of the navmesh,
inflated by `AGENT_RADIUS + 0.15`.

Net effect: **the doorway is physically open and navigationally sealed.** The player walks in.
No NPC can ever path there. `scripts/world/collision_table.gd:10-12` states the opposite intent
outright — *"ALL trimesh: these are enterable, and a box hull would seal the doorway the
generator verified you can walk through."* This affects all 26 village structures.

This is also a **Pillar 1** problem, not just a bug: a walkable interior the enemy is
nav-forbidden to enter is a player safe room.

**Fix (CLAIMED, verify first):** route `mesh: true` buildings through the existing collider path
instead of the box carve — `nav_baker.gd:146 queue_site_with_colliders()` is already public and
is claimed to be proven at 370 m on the firebase. Confirm that before relying on it. The
minimal alternative is to skip `add_to_group("nav_blockers")` when `entry.mesh` is true, so the
trimesh itself is what the bake sees.

**Do not** simply shrink the `nav_box`. The wall footprint still needs to block; it is the
*interior* that must stay walkable.

---

## FIX 3 — allies and squad spawn on top of buildings

**VERIFIED.** `floor_y()` was written on 2026-08-04 specifically to stop this, and was wired
into exactly one file.

`scripts/levels/game_world.gd:436` — `floor_y()`, probes down a short reach from the caller's
known Y, so a roof overhead is never sampled. Its own comment: *"surface_y's top-down ray stood
every covered garrison post — and the whole squad, ringed around an indoor bunk — ON THE ROOFS
(his playtest, 2026-08-04)."*

`scripts/levels/game_world.gd:400` — `surface_y()`, probes **top-down from `SURFACE_PROBE_UP`
= 18 m, first hit wins**. Correct for open ground. On any point under a roof it returns the roof.

Current callers:

| Caller | Uses | Should be |
|---|---|---|
| `scripts/missions/field_director.gd:46` — **ally seating** | `surface_y(pos) + 0.5` | `floor_y` |
| `scripts/main/game_flow.gd:232, 280, 689, 696` | `surface_y` | review each |
| `scripts/levels/demo_game.gd:262` | `surface_y` | review |
| `scripts/enemies/marching_cell.gd:169` | `surface_y` | probably fine (open ground) |
| `scripts/missions/mission_generator.gd:1027,1034,1036,1057,1065,1069` | **`floor_y`** | already correct |

`game_flow.gd:689` already carries the comment *"surface_y()'s top-down raycast misses the
hootch"* — the problem was known and the fix was never propagated.

**The rule:** an authored or interior point (a bunk, a garrison post, anything under a roof)
→ `floor_y()`. An arbitrary outdoor point → `surface_y()`. Do not blanket-replace; `surface_y`
is right for open ground and exists to clear the firebase mound.

**Related art defect, do not fix in code:** `scripts/main/game_flow.gd:178` — *"fsb_main_v3
ships 8 hootch visuals against 4 `-colonly` bodies"*. Half the hootches have no collision. That
is Caleb's Blender job, not yours.

---

## FIX 4 — silent 3×2×3 default for unlisted structures

**VERIFIED. `scripts/world/collision_table.gd:182`.**

```gdscript
static func get_entry(model_name: String) -> Dictionary:
    return STRUCTURES.get(model_name, {"box": Vector3(3, 2, 3), ...})
```

Silent. Asymmetric with `is_soft()` (`:293`), which warns loudly when a model has no authored
material. A new 12 m HQ tent would get a 3 m nav carve and men would path through canvas.

**Fix:** `push_warning` on the fallback, matching the wording style of `is_soft()`.

---

## FIX 5 — new buildings named "hooch" guess SOFT

**VERIFIED. `scripts/world/collision_table.gd:293-312`.**

`is_soft()` checks the authored `MATERIALS` table first, and only then falls back to
`_filename_guess()`, which substring-matches `_SOFT_NAME_HINTS` (`:303`) —
`["hooch", "hootch", "hut", "thatch", "bamboo", ...]`.

It **does** `push_warning` on the fallback, so this is loud, not silent. But a planned
*"dug-in earth bunker hooch"* would match `"hooch"` and ship **shootable through**.

**Fix:** no code change needed. Any new building GLB must get a `MATERIALS` entry at the same
time it is added. Worth adding a test that fails when a model in `STRUCTURES` has no `MATERIALS`
entry.

---

## FIX 6 — screen door (NEW FEATURE, ruled by Caleb 2026-08-12)

Do this **after** FIX 0 and FIX 2. Without them it is decoration on a sealed room.

**The ruling, and the reason for it, in his words:** *"if the firebase ever gets over run you can
hide in the hooch and enemies can come in."* The door is deliberately **always passable** so an
interior can never become a player safe room — that is a **Pillar 1** requirement, not a
convenience.

**Design: a screen door on a spring. No collision, no interact key.**

- `Area3D` across the threshold. On `body_entered` swing the leaf open; spring it closed on
  `body_exited` after a short delay. Applies to the player **and** to allies and enemies
  identically — nobody presses anything.
- The leaf is **visual only**. It must never carry a collider and must never be a
  `nav_blockers` member.
- The doorway bakes **open, permanently**. This is already the established law here —
  `scripts/zombies/zombie_door.gd:8-12`: *"the navmesh is baked with every doorway OPEN and never
  rebakes. A closed door is a physical blocker only. Nothing needs to path through it."*

**Why not the existing patterns:**
- `_try_field_interact` (`scripts/player/player.gd:948`) is a hardcoded branch chain with **no
  registry** — medical crate, then tunnel, then more. Every door added there competes with the
  medkit crate for one key. A screen door needs no key, so it never enters that chain.
- The `ZombieDoor` `Blocker` + `Leaf` pattern (`scripts/zombies/zombie_door.gd`, 75 lines) is
  the right model for a door that genuinely **shuts** — hold it in reserve for the officers' HQ
  tent or the bunker hooch. It requires NPC open-door behaviour, which does not exist repo-wide:
  **zero `AnimatableBody3D`, zero "doors" group, zero `door_open` in `scripts/`.**

**Naming:** use a `door_*` prefix on the leaf so `nav_baker.gd`'s prefix contract can skip it
explicitly rather than by accident. Add the hooch to `CollisionTable.MATERIALS` at the same
time — see FIX 5; anything matching `"hooch"` guesses SOFT and ships shootable-through.

---

## Context you will want

- **Nothing built since 2026-07-26 is in the game.** `fsb_main_v3.glb` is dated 07-26 and its
  1259 nodes contain **zero chow hall and zero medical complex** (verified by parsing the GLB).
  The chow hall (8/3), medical complex (8/5) and crewed mortar pit (8/7) are finished in blends
  and have never been exported. Do not attempt the re-export — it is Caleb's call and FIX 1
  must land first.
- **`firebase_v3.2.blend` is the new canonical firebase** (built today). See
  `assets/world/building models/structures/firebase/kit/README_WHICH_FIREBASE.md`.
- **No GDScript reads `work_med*` / `work_chow*` / `work_medofficer*`.** A friendly-side
  director does not exist; `work_pos`/`work_clip` walking is VC-camp only
  (`scripts/world/camp_director.gd`, `scripts/enemies/enemy_base.gd:1660`). 18 fresh medical
  markers now exist in `firebase_v3.2.blend`, each carrying `work_clip`, `work_posture`,
  `work_phase`, `face_yaw_deg` custom properties — ready for a director that does not yet exist.
- **The GLB is not the problem.** The nav architect's conclusion, after measuring it: 1,259
  nodes, 148k collision tris, authored `-colonly` twins, correct trimesh list — it bakes fine.
  **All the nav failures are runtime code.** Do not "fix" this by re-authoring the model.
- **Do not split the mound into a separate scene.** `NAV_IGNORE_PREFIXES` is a *name* contract
  read off the collider's parent (`nav_baker.gd:386`); a rename silently re-enters 178 cots into
  the bake with no error.
- **Suspected, unproven:** the raw terrain grid bakes *alongside* the mound trimesh with all
  three Recast filters left at default false, producing a second walkable layer buried under the
  mound (1.5–6.5 m gap vs a 1.8 m agent). `filter_walkable_low_height_spans` in FIX 0b is the
  claimed cure. Measure before believing.
- Three analyses are written:
  `production/war_room/analysis/technical_director_nav_2026-08-12.md`
  `production/war_room/analysis/godot_specialist_interiors_2026-08-12.md`
  `production/war_room/analysis/devils_advocate_interiors_2026-08-12.md`

## CLAIMED, unverified — check before trusting

- The `recon-destructible-export` skill's `file:line` references are all stale (~94 lines of
  drift). If true, correct them on contact — that doc exists to prevent silent breaks.
- `fb_int_` interior dressing is 356 of 1259 firebase nodes (28%) and accounts for ~45% of draw
  calls for 3.75% of geometry; the 40 m visibility cull is firebase-prefix-only, so village
  interior props would draw from 230 m (`site_planner.gd:209`).
- `m72_law_fp.glb` and `us_pilot_white`'s gib contract are said to be failing tests today.

## House rules

- Strict typing: `lerpf`/`minf`/`maxf`/`maxi`, explicit types on anything that could infer
  Variant. See `CLAUDE.md`.
- Comment discipline: state constraints the code cannot show. No narration, no changelogs, no
  "this used to be X".
- Fossil law: when you replace a system, delete the old one in the same change.
- Run `tests/test_fossils.tscn` before finishing; a NEW fossil fails the build.
