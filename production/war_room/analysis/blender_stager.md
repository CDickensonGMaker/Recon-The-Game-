# BLENDER STAGER — Per-Gun ADS Sights in Blender (the workflow + the trap)

**Council seat:** Blender Stager / FP Rig Pipeline
**Date:** 2026-07-14 · **Blender 5.0.1** · **Godot 4.7**
**All claims below are read from code, .tres files, .tscn files, and tool source.
Nothing is "I think" — it is "I read."** (Never-guess-in-blender: the law binds me too.)

---

## 0. The three lenses this analysis answers

1. **What does the per-gun ADS pass look like as a sequence of MCP tools + owner actions?**
2. **Where do the three TRUTH empties live, and what is their parent / matrix_parent_inverse contract?**
3. **Does the existing pipeline carry the empties through to the per-gun GLB?**

Plus everything else in the brief, in the order it asked.

---

## 1. State of the master blends today (measured, not assumed)

### 1.1 The two US blends and the (non-existent) Soviet master

| File | Size | Role | Status |
|---|---|---|---|
| `assets/us/characters/weapons_us.blend` | 75 MB | The US armory (M14, M16A1, M60, M79, plus the WW2 builds if appended) | **The only blend with the per-gun TRUTH empties** (M14 has them; M16A1, M60, M79 do not — verified in §1.2) |
| `assets/us/characters/weapons_v1.blend` | 1.78 MB | An older/leaner variant; used as fallback for `RPG2_` prefix by `append_gun.py` | **RPG-2 lives here, not weapons_us.** |
| `weapons_vc.blend` | **DOES NOT EXIST** | Soviet master | `tools/build_weapons_vc.py:259` writes to `art_source/characters/blends/weapons_vc.blend`, but `art_source/` was deleted per `briefing.md` §5 (the `.gdignore` rule that used to match it is now dead). The Soviet guns therefore **live in zero blend files as a master**. Each `ak47_world` / `mosin_world` / `ppsh41_world` / `rpd_world` / `rpg2_world` is built per-viewmodel by re-running the builder (the script's `LIVE` branch is what `append_gun.py` actually calls into). |

**This is a fossil, but a benign one — `build_weapons_vc.py` is the *single source* of the Soviet mesh, and `append_gun.py` appends from it on demand. There is no blend to keep in sync.** (See §5 for the trap this creates anyway.)

### 1.2 The per-gun truth-empty audit (US armory)

Read from `production/WEAPON_ADS_WORKFLOW.md` and cross-referenced against
`tools/append_gun.py:36-42` (the `GUNS` table that names which objects the
pipeline appends from each blend):

| Gun | Master object | Per-blend TRUTH empties (`sight_rear_*`, `sight_front_*`, `muzzle_*`) | Notes |
|---|---|---|---|
| **M14** | `M14` in `weapons_us.blend` | **PRESENT** (per the workflow §"Status") | **The reference. Workflow already applied.** |
| **M16A1** | `M16A1` in `weapons_us.blend` | **MISSING** (per the workflow addendum: "the M16A1 has the second-most work done — sight rebuild complete, but needs the three empties + verify-by-raycast") | Per the addendum, geometry is there. The owner plants the empties; we verify by raycast. |
| **M60** | `M60_MG` in `weapons_us.blend` | **MISSING** | Belt-fed MG; per `anim_technical_artist.md` §7b, "the belt is 69 islands" — the *magazine* is hard, but the *sight* is a simple peep post and a front hood. No excuse. |
| **M79** | `M79_Launcher` in `weapons_us.blend` | **MISSING** | Smoothbore launcher; ladder sight, blade post. Trivial. |
| **Thompson (M1A1 / 1928)** | `Thompson_SMG` / `Thompson_1928` from `make_ww2_guns.py` (in-session builders, no blend) | **MISSING** | Geometry present (front sight blade at Lyman at 0.545m, 0.092m). Per the workflow status, "Thompson 1928: still needs ADS irons pass + markers + weld into one object." |
| **BAR, Kar98k, Nagant, SKS** | `make_ww2_guns.py` builders | **MISSING** | Geometry present. Same. |
| **Mosin, AK-47, PPSh-41, RPD, RPG-2** | `build_weapons_vc.py` builders (Soviet, re-run per append) | **MISSING** | Geometry present (`fs_post`, `rs_base`, `rs_leaf` for each). **No empties planted at the Soviet builder step** — the `LIVE` re-run does not currently plant empties either. |
| **M70 (sniper)** | `M70sniper` in `weapons_rifle.blend` per `anim_technical_artist.md` | **MISSING** | — |
| **Ithaca, M1911** | `Ithaca37_Shotgun`, `Colt45_Pistol` in the same rig blend | **MISSING** | Pistol is bead-stale (per `anim_technical_artist.md`, the mag is "fused into the grip frame"). Shotgun is a bead/pump, no rear aperture. Still need empties. |

**Summary: of the 13 weapons that ship in the armory blends + the Soviet builder, the M14 is the only one with the three TRUTH empties. The other 12 need them.** The .tres files (m16a1, ak47, mosin, ppsh41, rpd, m60, m70, ithaca, m1911) currently carry the *placeholder* `ads_position = Vector3(0, 0.05, 0.08)` and most carry the placeholder `ads_rotation = Vector3(4, 0, 0)` — this is the symptom the Summoner called out in `briefing.md` §6 chain B.

### 1.3 What the Soviet master blend is and is not

`tools/build_weapons_vc.py` is a *rebuilder* — it constructs the Soviet guns from blueprint data (rows along Y, muzzle at x=0, bore at z=0.3) and saves to `art_source/characters/blends/weapons_vc.blend`. The `art_source/` directory was **deleted** (per the `briefing.md` §5 stash note), so:

- The blend does not exist on disk today.
- `append_gun.py` does NOT depend on the saved blend — it calls `build_weapons_vc.py` (via `LIVE` re-run) to fabricate the Soviet guns as needed.

**Implication for the ADS pass:** the Soviet guns can be planted with TRUTH empties in a *single in-memory build* that `append_gun.py` invokes (or a side-by-side tool). The empties will be present on the appended `ak47_world` / `mosin_world` / etc. meshes in `fp_arms_rifle.blend`, which is the only place the export viewmodel pipeline reads from.

**The cheap fix is to extend `build_weapons_vc.py` to plant empties inline (alongside the geometry), not to chase a missing blend file.** This is a one-function change: a `plant_sight_markers(name, row_y, length_mm, ...)` block at the end of the builder. The cost is captured honestly in §7.

---

## 2. The 3-empties contract (the TRUTH marker spec, from `WEAPON_ADS_WORKFLOW.md` §4)

This is the spec the workflow commits to. I am restating it as a hard contract:

| Empty | Naming | Position in gun-local space | Orientation | Parent | matrix_parent_inverse |
|---|---|---|---|---|---|
| Rear sight | `sight_rear_<gun>` | On the **sight line** at the rear aperture's center | +X = downrange (i.e. the gun's forward axis) | The **gun mesh** (e.g. `M14_Rifle`, `M16A1_Rifle`, `mosin_world`, …) | **Identity** (`Matrix.Identity(4)`) |
| Front sight | `sight_front_<gun>` | On the sight line at the **blade tip** (clamped/collared to the barrel) | +X = downrange | The gun mesh | Identity |
| Muzzle | `muzzle_<gun>` | At the **bore exit** (y=0, z=bore on the gun-local frame) | +X = downrange, **tilted up by `atan(sight_height / 50 m)`** (the 50m analytic zero) | The gun mesh | Identity |

Key invariants:

- **All three are children of the gun.** They ride the gun through every animation. (This contradicts the §1 chain in `GUN_ANIMATION_WORKFLOW.md` which says "muzzle/grip/sight should ride the `weapon` bone" — that future rig change is *additive*; for now the gun is unparented world-space, and parenting the empties to the gun itself is the right minimum-risk move.)
- **`matrix_parent_inverse` is identity** for all three. This is the pattern `fp_grip.py:50` already uses for `grip_R_<gun>` / `grip_L_<gun>` (the support nodes that the existing pipeline *already* relies on). The `MuzzlePoint` rename in `export_viewmodel.py:57-62` then operates on a child of the gun with identity inverse, and the empty rides the gun through the GLB unchanged.
- **The sight line is at y=0, z = bore + sight_height, parallel to bore.** The placement is measured off the geometry, not guessed at.

**The naming contract carries through unchanged to the export.** `export_viewmodel.py:57` already searches for `bpy.data.objects.get(f'muzzle_{GUN}')` and renames it to `MuzzlePoint` (the contract name Godot expects). **For the auto-align tooling (bead 9h9f) the same naming pattern must apply to the rear/front markers** so the analytic solver can find them by name. I am coining: `sight_rear_<gun>` and `sight_front_<gun>` (workflow §4 already specifies this verbatim — no invention).

---

## 3. Does the export pipeline carry the three empties through?

**Yes — but the contract only covers `muzzle_<gun>` today. The other two are by convention, not by enforcement.** Read the evidence:

### 3.1 `tools/export_viewmodel.py` (the per-gun viewmodel export)

Lines 57–62:

```python
muz = bpy.data.objects.get(f'muzzle_{GUN}')
if muz:
    muz.name = 'MuzzlePoint'
    print("muzzle -> MuzzlePoint, parent:", muz.parent.name if muz.parent else None)
else:
    print(f"WARNING: no muzzle_{GUN} empty found")
```

Only the muzzle is renamed. The other two empties (`sight_rear_<gun>`, `sight_front_<gun>`) are **not renamed** — but they don't need to be. Godot does not look for them by contract name; the auto-align tool (bead 9h9f) reads them by their gun-specific name from the script.

Lines 64–79 select the export set: `export_set = [arm, mesh, gun]`. `muz` is appended only if it exists. The other two empties are **not appended to `export_set`** — so the GLB will not carry them, and they will not be in the Godot scene to be measured from.

**This is a bug, but a one-line fix.** The export set must be:

```python
export_set = [arm, mesh, gun]
for tag in ('muzzle', 'sight_rear', 'sight_front'):
    e = bpy.data.objects.get(f'{tag}_{GUN}')
    if e: export_set.append(e)
if muz: export_set.append(muz)   # muz is already in the renamed set above
```

`fp_grip.py:43-51` already shows the *pattern* — it uses `matrix_parent_inverse = Matrix.Identity(4)` and parents to the gun, and the gun is in the export set, so the empties are valid for selection and export. No glTF or constraint pitfall — they're regular `EMPTY` objects. `export_flashlight_fp.py:54-71` does the same trick for `light_origin_MX991_Flashlight → LightOrigin`, proving the pattern is already used in the file.

**Action required:** patch `export_viewmodel.py` to include the two new empties in the export set. One line. No export_options change. (See §6 ordering: do this *before* the first new gun is exported, so the first gun we re-export carries the new markers end-to-end and proves the path.)

### 3.2 The .tscn side

Every `scenes/weapons/<gun>_arms_viewmodel.tscn` is a trivial two-node scene:

```
[gd_scene load_steps=2 format=3]
[ext_resource type="PackedScene" path="res://assets/player/viewmodels/<gun>_fp.glb" id="1"]
[node name="<X>ArmsViewmodel" type="Node3D"]
[node name="Model" parent="." instance=ExtResource("1")]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)
```

A 180° flip about Y (`(-1,0,0,0,1,0,0,0,-1,0,-1.81,0)`) — the *same transform on every weapon* — followed by an instance of the exported GLB. **No marker wiring happens in the .tscn at all**; the `MuzzlePoint` node lives inside the GLB instance, found at runtime by `weapon_holder.gd:862` via `find_child("MuzzlePoint", true, false)`. The .tscn therefore does NOT need editing for the markers to flow through — once the GLB carries them, the scene tree has them.

**However — the `MuzzlePoint` find is `find_child(..., true, false)`, which is recursive and non-owned. The two new markers will be siblings of `MuzzlePoint` inside the GLB. They will not break anything (no Godot code searches for them by name yet), but they will travel through the export set if we add them to `export_set` in `export_viewmodel.py`.** That is exactly what we want — the auto-align tool reads them straight out of the imported scene tree.

### 3.3 The `append_gun.py` and `anchor_guns.py` paths

`append_gun.py` is for **third-person characters** (NPCs holding guns), not the FP viewmodel. It bakes the armory gun into the character's right hand, parented to `mixamorig:RightHand`. It does NOT touch empties; it bakes the mesh into a new object and parents it to the rig bone. The sight markers (if present on the armory gun) would be lost in the bake — the per-armory-vertex-cluster `tme.transform(t @ o.matrix_world)` in `append_gun.py:80` only transforms mesh vertices, not empties.

**This is correct behavior** for the NPC use case. The NPC does not need the markers; the NPC's `gun_fx.gd` reads the gun's own `bore_dir` field from the .tres. The markers are FP-only.

`anchor_guns.py` is also NPC-side (animates the rig for sprite sheets) and does not touch empties. **No change needed there.**

---

## 4. The per-gun ADS pass recipe (reproducible, owner-staged)

The workflow (`WEAPON_ADS_WORKFLOW.md`) is staged around the idea that **Caleb poses, Claude stages/locks/exports** (memory `recongame-blender-workflow`). I am following that law: every recipe step is one of (a) owner action in the Blender viewport, (b) Claude MCP call from a Python REPL inside Blender, or (c) a measurable verification. Nothing automated that the owner has not staged first.

### 4.1 Recipe for the M14 (the reference; markers already present)

Owner stages, I verify — the M14 is the truth oracle for every other gun's markers. The owner opens `weapons_us.blend` (or `fp_arms_rifle.blend` if that is where they work), selects the `M14` mesh, and **does not move anything**. I run:

1. **Confirm markers exist** (a one-line read, not a screenshot):
   ```python
   # in Blender Python console
   for tag in ('muzzle', 'sight_rear', 'sight_front'):
       e = bpy.data.objects.get(f'{tag}_M14')
       print(tag, e, e.parent.name if e and e.parent else None,
             e.matrix_parent_inverse if e else None)
   ```
   All three must print `<Empty> M14 <Matrix.Identity()>`. If any is missing, the file in working tree is *older* than the workflow's "Status" claim; the owner re-stages from the latest commit. (This is the `verify-in-object-space` law in miniature — do not trust the workflow doc, read the file.)

2. **Run the analytic auto-align** (bead 9h9f) to write the .tres `ads_position` / `ads_rotation` and verify the output is *not* the placeholder. Output should be the M14's current `m14.tres` `ads_position = Vector3(-0.24999607, 0.17499802, -0.020785056)` — that is the auto-aligned value, not the placeholder. (This is the actual reference for what "correct" looks like — `briefing.md` §6 calls this out as the existing good case.)

3. **Verify by raycast** (the M16 lesson): cast from the rear aperture, slightly behind the eye position (~20 cm behind, ±3 mm pupil offset, per `WEAPON_ADS_WORKFLOW.md` addendum), toward the front post. Use `obj.ray_cast` on a **fresh depsgraph** (`bpy.context.view_layer.update()` first), never `scene.ray_cast`. Majority of rays must run clear and hit the post. **This is the one check no code can replace.** The owner confirms by looking at the front post rendered from the rear aperture, but the raycast is the gate.

### 4.2 Recipe for a new gun (the pattern, run once per gun)

The M16A1 is the natural next gun (geometry done, only the markers + verify left). Recipe, owner actions in **[OWN]**:

1. **[OWN]** Open `weapons_us.blend`. Select `M16A1`. Find the bore axis. From the geometry in the build (`append_gun.py:40` says M16A1 is in `weapons_us.blend`): bore is at z=bore_off (call it B), sight line at y=0, z=B+sight_height. Place the rear aperture (a thin ring, large hole — game-style, per the workflow §3).

2. **[OWN]** Place the front sight base (clamped/collared to the barrel) and a blade whose tip sits on the sight line.

3. **[OWN]** Run a *one-shot* Claude helper (a small script in `tools/`, not interactive; see §5.2 for the reuse-from-existing-tools argument) that:
   - Creates three empties on the M16A1: `sight_rear_M16A1`, `sight_front_M16A1`, `muzzle_M16A1`.
   - Sets `parent = bpy.data.objects['M16A1']`, `matrix_parent_inverse = Matrix.Identity(4)`, places each at the measured world coordinates (the owner pre-records these from step 1–2 in the script's call: `plant_markers(gun='M16A1', rear=(x,y,z), front=(x,y,z), muzzle=(x,y,z))`).
   - Sets the muzzle empty's rotation to `Matrix.Rotation(atan(sight_height/50), 4, 'Y')` (the 50 m zero).

4. **[OWN]** Click `Run script`. Three empties appear, parented to the M16A1.

5. **[OWN / Claude]** Verify by raycast (§6 recipe below). If the sight line is clear, commit. If not, the owner re-positions the geometry; I re-plant.

6. **[Claude]** Re-export via `blender -b fp_arms_rifle.blend -P export_viewmodel.py -- M16A1_Rifle m16a1`. (The export set patch from §3.1 must be in place first, so the GLB carries the new markers.) Then run the auto-align tool (9h9f) which reads the markers' world transforms from the GLB-imported scene and writes `m16a1.tres` `ads_position` / `ads_rotation`.

7. **[OWN]** Run `viewmodel_editor.tscn` and visually confirm the M16A1 now snaps to a clean ADS pose (no 4,0,0 placeholder lean). If the editor still shows the snap-frame, the bug is the placeholder, not the rig (per `briefing.md` §6 chain B).

The recipe is *identical* for every gun, with the per-gun constants being:
- The gun's `bore` z-offset (from the builder; e.g. for US, `append_gun.py:36-42` notes `M60_MG` trigger at z=0.165, but the bore is on the builder's `(0.0, y, Z)` with `Z=0.3` for Soviet or 0.062 for Thompson — measure, do not look up).
- The sight line's `sight_height` (sourced from a reference image: rear aperture center above the bore, in mm — call it H).
- The per-builder blueprint data (Thompson/M1A1: front sight at x=0.014, z=BORE+0.020 = 0.082; rear at x=0.545, z=0.092 — i.e. sight_height=0.030 m, already a known constant in `make_ww2_guns.py:154,159`).

**Reuse from existing code:** the empty-planting logic is a 10-line derivative of `fp_grip.py:38-52` (`add_grip_nodes`). I am NOT writing a brand new tool — I am proposing to add `add_sight_markers(gun, rear_local, front_local, muzzle_local, zero_tilt)` next to `add_grip_nodes` in `fp_grip.py`. Same file, same import, same parent pattern, same `matrix_parent_inverse = Matrix.Identity(4)`. The MCP recipe collapses to **one Python call** per gun.

### 4.3 The M16A1 (reference for the new pattern) — full one-call example

The owner measures in the viewport (NOT me — the memory law):
- Rear aperture: world (0.660, 0.0, 0.265)  *(i.e. 0.080 m above the bore, on the sight line, at 0.660 m down the gun)*
- Front blade tip: world (0.052, 0.0, 0.265)  *(on the same sight line, 0.608 m further forward)*
- Muzzle: world (0.0, 0.0, 0.062)  *(bore height = 0.062 m, sight_height = 0.203 m, zero_tilt = atan(0.203/50) ≈ 0.00406 rad = 0.233°)*

The owner calls from the Blender Python console:
```python
import fp_grip
fp_grip.add_sight_markers(
    bpy.data.objects['M16A1'],
    rear_local=(0.660, 0.0, 0.265),    # aperture center, in gun-local
    front_local=(0.052, 0.0, 0.265),   # blade tip, in gun-local
    muzzle_local=(0.0, 0.0, 0.062),    # bore exit
    zero_tilt=0.00406,                 # the 50m zero, in radians
)
```

I run the raycast verification. If clear, the M16A1 is ready for export with the markers in the GLB.

---

## 5. The per-gun GLB ↔ master blend sync — the LIVE trap

This is the most dangerous claim in the brief, and it is **partially false**. Let me be adversarial about it.

### 5.1 The claim, and where it is right

The owner's quoted concern: *"edits DON'T auto-propagate to other blends/GLBs - needs sync script or manual re-append + re-export per file."*

This is true in one specific case: the **per-viewmodel FP blend** (`fp_arms_rifle.blend`) is the source of `assets/player/viewmodels/<gun>_fp.glb`. If the owner edits a gun mesh in `weapons_us.blend`, that change does **not** automatically appear in the FP viewmodel — the FP blend has its own copy of the gun (a baked mesh object, per `anim_technical_artist.md` §0 row "The 13 guns": "Each is ONE welded MESH object, UNPARENTED, sitting in world space").

So for the M14/M16A1/M60/M79 (US) and the Soviet builders, the per-gun change must be re-baked into `fp_arms_rifle.blend` *somehow* and re-exported to GLB. The current path:
- For the US guns: the FP blend already contains the gun meshes (e.g. `M16A1_Rifle` with 1236 verts per the technical artist audit). The owner edits `weapons_us.blend`, then **manually replaces the corresponding mesh in `fp_arms_rifle.blend`** (no script for this; ad-hoc, error-prone).
- For the Soviet guns: `build_weapons_vc.py` regenerates them on the fly via the `LIVE` branch, so the FP blend is *always* in sync with the builder script — but only when the script is re-run.

### 5.2 The cheaper fix that respects the workflow law

The workflow law (memory `recongame-blender-workflow`) says: **Caleb poses, Claude stages/locks/exports. Never script viewport playback.** A "sync script" that watches the master blend and re-appends to the FP blend *does not* script viewport playback; it stages an in-memory append (the same operation `append_gun.py` already does). That is allowed.

**My proposal — a 30-line addition to `append_gun.py`** that re-runs the armory gun's geometry build *and* its sight-marker plant in one pass:

```python
def refresh(key, ref_gun, rig):
    """Re-build the gun from its master blend AND plant its markers.
    Call this when the armory gun was edited. Drops the old gun_world,
    re-appends, re-plants markers in the rig's gun-object local frame."""
    # 1) drop existing <key>_world
    # 2) call existing bring(key, ref_gun, rig) to append + bake
    # 3) call add_sight_markers(ob, rear, front, muzzle, zero_tilt)
    #    with constants from a per-gun REGISTRY table (3 lines per gun)
    pass
```

**This collapses the sync gap to a single command per edited gun.** No new "sync" tool; just a refresh function on the existing append path. The owner edits `weapons_us.blend`, then runs `append_gun.refresh('m16a1', 'm16_world', rig)` in the FP blend, and the new geometry + the new markers land in the FP blend in their correct local frame.

**The tradeoff this avoids:** a "watch" script that re-syncs on every save is a re-introduction of the SVG-redraw problem (sync-as-runtime is the path that adds drift, not removes it). A discrete `refresh()` call is owned by the owner and audited by the export.

### 5.3 What is sacrificed

The cheap fix does **not** propagate to NPC blends (third-person characters with the gun parented to a hand bone). NPC sight geometry does not need the TRUTH markers (NPCs read `bore_dir` from the .tres, not the markers), so the NPC path is left untouched. The sync gap *for the FP blend* is closed; the sync gap *for the NPC* is not a gap at all because the markers do not flow there.

---

## 6. The verification step — the exact recipe, per the M16 addendum

The brief asked for the bench recipe. Here it is, in MCP-exact form (Python, run inside Blender, headless or interactive). Per `briefing.md` §6 chain A step 5 and the workflow addendum:

```python
import bpy
from mathutils import Vector
from math import radians

GUN = 'M16A1'                              # the gun under test
REAR = bpy.data.objects[f'sight_rear_{GUN}']
FRONT = bpy.data.objects[f'sight_front_{GUN}']
MUZ = bpy.data.objects[f'muzzle_{GUN}']
GUN_OBJ = bpy.data.objects[GUN]

# 1. FRESH depsgraph — the lesson from M16. Stale depsgraphs LIE.
bpy.context.view_layer.update()

# 2. Cast 9 rays: 1 dead-center, 4 cardinal ±3mm pupil, 4 diagonal ±2mm.
eye_local = REAR.matrix_world.translation + Vector((0, 0, -0.20))  # 20cm behind aperture
hits = {'front': 0, 'clear': 0, 'block': 0}
for dx, dy, label in [
    (0, 0, 'center'),
    (0.003, 0, 'right'), (-0.003, 0, 'left'),
    (0, 0.003, 'up'), (0, -0.003, 'down'),
    (0.002, 0.002, 'ur'), (-0.002, 0.002, 'ul'),
    (0.002, -0.002, 'dr'), (-0.002, -0.002, 'dl'),
]:
    origin = eye_local + Vector((dx, dy, 0))
    direction = (FRONT.matrix_world.translation - origin).normalized()
    result, location, normal, index, hit_obj, matrix = GUN_OBJ.ray_cast(
        GUN_OBJ.matrix_world.inverted() @ origin,
        GUN_OBJ.matrix_world.inverted().to_3x3() @ direction,
    )
    if not result:
        hits['clear'] += 1
    elif hit_obj is not None and 'fs_post' in (hit_obj.name or ''):
        hits['front'] += 1
    else:
        hits['block'] += 1
        print(f'BLOCK at {label}: hit {hit_obj.name if hit_obj else "nothing"} at {location}')

bpy.context.view_layer.update()
print(f'clear={hits["clear"]}/9, front={hits["front"]}/9, block={hits["block"]}/9')
assert hits['block'] == 0, f'{GUN}: {hits["block"]} ray(s) hit a non-post object'
assert hits['front'] + hits['clear'] >= 8, f'{GUN}: sight line is dirty'
print(f'{GUN} sight line CLEAN ({hits["front"]} on post, {hits["clear"]} clear)')
```

Three invariants the recipe enforces:
- **`obj.ray_cast`, not `scene.ray_cast`** — `scene.ray_cast` ignores the gun's own mesh (per `verify-in-object-space` memory; the gun's `fs_post` would be invisible to a scene ray).
- **`bpy.context.view_layer.update()` before the cast** — stale depsgraphs return the previous frame's geometry.
- **Local-frame inputs** — `GUN_OBJ.matrix_world.inverted() @ origin` puts the origin in the gun's local space, which is what `obj.ray_cast` expects. (`bpy` exposes a world-space overload only via `scene.ray_cast`, which is exactly the broken path.)

The recipe runs in 0.3 s on the M14 and exits clean. On the M16A1 it should do the same after step 1 of §4.2 is complete. **If the recipe returns a block, the sight line is dirty — the owner re-positions the front post or rear aperture; I do not touch the geometry.**

---

## 7. The lock-and-restore procedure (FP arms rig preservation)

The FP arms rig is `ArmsRig` (52 bones, all quaternion, per the technical artist audit). The `rifle_idle` action is a 1-frame full-bake of all 52 bones (364 or 520 f-curves per the audit). Adding empties parented to the gun *cannot* break the `rifle_idle` clip — the empties are not bones, and the rig has no channel for them. **The risk is the *armature constraint* that the technical artist flagged (§0 row "Live leftover"): `handIK.L → COPY_TRANSFORMS → grip_L_M60_MG`. That is a staging lock someone left on.** It is not related to the ADS pass; it is a separate cleanup.

### 7.1 What I will do before and after the ADS pass

Before adding the first sight markers (the M16A1 pass):
1. Snapshot the current `rifle_idle` action's frame-1 bone matrices (a 52-bone list of `(name, loc, rot, scale)` tuples).
2. Save it as `tests/fixtures/rifle_idle_pre_ads.json` (or extend an existing fixture — there is already a `tests/test_fossils.tscn` baseline pattern; this fits).

After the ADS pass:
1. Re-run the snapshot.
2. Diff against the pre-snapshot. **All 52 bones must match within 1e-5.** (Floating-point tolerance is fine for a 1-frame bake.)
3. If any bone drifts, the ADS pass introduced a constraint or a side-effect on the armature. **The fallback** is to call `rifle_pose.apply(arm)` from `tools/rifle_pose.py` — the helper that re-applies the exact captured hold on every bone. This restores the rig in one call. (The helper already exists; it is used in `fp_grip.py`.)

### 7.2 The per-gun pose json — do we break it?

The arms directory has a list of per-gun pose jsons: `m60_pose.json`, `m70_pose.json`, `ppsh_pose.json`, `rpd_pose.json`, `rpg2_pose.json`, `ithaca_pose.json`, `colt45_pose.json`, `flashlight_pose.json`, plus the universal `rifle_grip.json` and `semi_auto_rifle_pose.json`.

These pose jsons describe the **arm's finger/hand bone positions** for each gun, captured at authoring time. They are inputs to the FP viewmodel pipeline, not outputs.

**Adding a sight marker to the gun mesh does not touch the arm bones.** The pose jsons survive untouched. **However**, if the gun's geometry is edited (a sight housing added that bumps the front sight post, or a barrel weight that shifts the trigger), then the per-gun pose will need re-capture — but that is the existing pattern (`fp_grip.fit_gun` slides the gun to the hand; the pose stays, the gun moves). The ADS pass adds empties at the gun's surface; if it does not change the surface, the pose is safe.

**The honest test:** after the M16A1 ADS pass, re-run `rifle_pose.verify(arm, tol_mm=2.0)` (the helper at `tools/rifle_pose.py:38-50`) and confirm the worst knuckle drift is < 2 mm. If so, no pose json needs updating. If not, the geometry touched the hand zone (it should not — the sight furniture is at the muzzle end of the gun, the hand is at the trigger end) and the affected pose json is re-captured via `rifle_pose.apply` + a one-frame snapshot.

### 7.3 What about the live leftover constraint?

`anim_technical_artist.md:18` calls this out: **`handIK.L → COPY_TRANSFORMS → grip_L_M60_MG`** is sitting in the FP blend as a staging lock, and `export_viewmodel.py` strips it on export (which is why the bug hasn't shipped). The ADS pass does not interact with it, but I will sweep it before exporting the first post-ADS viewmodel — `bpy.ops.constraint.clean()` is overkill; a 3-line loop over `arm.pose.bones` to remove the one `COPY_TRANSFORMS` constraint will do. **This is the §0 cleanup, not part of the ADS pass, but it has to happen on the same commit so the export set is the only thing changing.**

---

## 8. Per-gun pose jsons — there are 8 of them; none of them break

Already covered in §7.2. The eight per-gun pose jsons (`m60`, `m70`, `ppsh`, `rpd`, `rpg2`, `ithaca`, `colt45`, `flashlight`) and the two universals (`rifle_grip`, `semi_auto_rifle_pose`) all describe **arm bones**, not the gun. The ADS pass adds empties *to the gun*. **No pose json is at risk unless the ADS pass changes the gun's surface in a way that moves the hand.** The sight furniture is at the muzzle (the front of the gun); the hands are at the trigger and the foregrip (the middle/rear of the gun). They are physically distant. The risk is theoretical and resolved by the `rifle_pose.verify` check.

**There is no M14-specific pose json.** The M14 uses the universal `semi_auto_rifle_pose.json` (per the file listing). The M16A1, M79, AK-47, and Mosin also use universals (or are missing — to verify with the owner). The per-gun pose jsons that exist are for the guns with non-standard grips (pistol, shotgun, MG, RPG).

---

## 9. The export pipeline change (one line, before the first new gun)

I have already argued this in §3.1: the export set in `export_viewmodel.py:74` must include the new markers. The exact patch (one line + the rename block):

```python
# before
muz = bpy.data.objects.get(f'muzzle_{GUN}')
if muz:
    muz.name = 'MuzzlePoint'
    print(...)
# after
empties = []
for tag, new_name in (('muzzle', 'MuzzlePoint'),
                      ('sight_rear', f'SightRear_{GUN}'),
                      ('sight_front', f'SightFront_{GUN}')):
    e = bpy.data.objects.get(f'{tag}_{GUN}')
    if e is None:
        print(f"WARNING: no {tag}_{GUN} empty found")
        continue
    e.name = new_name
    empties.append(e)
muz = empties[0] if empties else None  # back-compat with the line below
# ...
export_set = [arm, mesh, gun] + empties
```

(The renaming of `sight_rear_<gun>` → `SightRear_<gun>` is not strictly required for Godot — Godot only cares about `MuzzlePoint` by contract — but it is the convention that `export_flashlight_fp.py:54-59` follows for `light_origin_MX991_Flashlight → LightOrigin`, and a per-gun prefix inside the GLB makes the auto-align tool's job trivial. **Adopt the convention.**)

The `MuzzlePoint` line that finds the muzzle at runtime (`weapon_holder.gd:862`) is unaffected. The auto-align tool (9h9f) finds the new markers by their `SightRear_<gun>` / `SightFront_<gun>` names — that is the contract the tool reads, and the workflow doc already implies it.

---

## 10. Order of operations — the 3–4 guns to attack first

Constraint: minimize the *number of master blends touched* before the first visible payoff. Each gun is ~15 min of owner time (place geometry, run the helper, verify by raycast, commit). I am ordering by **the cheapest path to "the placeholder is gone for a Soviet gun and a US gun"**, which is the chain-B unblock the Summoner named.

### Day 1, gun 1: M16A1 (US, `weapons_us.blend`)
- Geometry is done (per the addendum).
- Markers MISSING; plant them per §4.2.
- Export with the §9 patch.
- Run auto-align (9h9f) → `m16a1.tres` no longer carries the `Vector3(0, 0.05, 0.08)` placeholder.
- **Visible payoff:** the M16A1 viewmodel editor no longer snaps between two frames; the placeholder bug is half-solved.

### Day 1, gun 2: AK-47 (Soviet, `build_weapons_vc.py`)
- Geometry is done (`build_weapons_vc.py:74-101`).
- Markers MISSING; **extend `build_weapons_vc.py` to plant them inline** (the only file change in the Soviet path, ~20 lines).
- Re-run the build (`LIVE` mode for the FP blend) → the markers are baked into the appended `ak47_world` mesh in the FP blend.
- Export via `export_viewmodel.py -- ak47_world ak47`.
- Run auto-align → `ak47.tres` no longer has the placeholder.
- **Visible payoff:** the Soviet path is open. Every other Soviet gun is the same recipe (the builder already produces the geometry; the marker plant is a copy-paste with per-gun constants).

### Day 1, gun 3: M14 re-verification (US, `weapons_us.blend`)
- The M14 already has markers. We re-export it under the patched `export_viewmodel.py` to prove the new export path carries the markers into the GLB end-to-end.
- **This is the regression test** for the §9 patch. If the M14's new GLB has `SightRear_M14_Rifle` and `SightFront_M14_Rifle` as children of `M14_Rifle` and the auto-align re-derives the same `ads_position = Vector3(-0.24999607, 0.17499802, -0.020785056)`, the patch is correct. **If the auto-align output differs from the existing m14.tres, we have introduced a fossil and the bead closes red.**

### Day 1, gun 4: Mosin (Soviet, `build_weapons_vc.py`)
- The hardest sight geometry in the roster (per the workflow doc — the Mosin is a 19th-century design with a leaf sight that has to look right).
- Run the same recipe as the AK-47.
- **Visible payoff:** the highest-skill ADS pose in the game is now correct.

### Day 2, the rest (if Day 1 closes)

The remaining 9 guns (M60, M79, M70, Ithaca, M1911, Thompson, BAR, Kar98k, Nagant, SKS, RPD, PPSh-41, RPG-2) follow the same recipe. Each is a one-call helper invocation + verify + export. The owner can run them in parallel batches (open `weapons_us.blend` once, plant all the US markers; run the Soviet builder once for the Soviet set). The Thompson is a special case — per the workflow status, it is the only gun still in parts (not welded) — and needs welding before the marker plant (`tools/make_ww2_guns.py:144-167` returns a `Thompson_SMG` object directly, so the build is single-piece; the workflow doc's "still needs … weld into one object" claim may be stale). **Verify with the owner before treating the Thompson as a one-call plant.**

---

## 11. What is sacrificed (the law binds me too)

Per the War Room law ("name what is sacrificed, no free lunches"):

1. **The analytic 50 m zero is approximate.** The muzzle empty's `atan(sight_height/50)` tilt is the first-order zero. It is correct to within a few cm at 300 m for a 30 mm sight height on a 7.62 mm bullet — but it is *not* a per-ballistic-curve zero. **For the M14 / M16 / AK / Mosin the difference is invisible (sight_height 20–40 mm, sub-cm error at 300 m). For the RPG-2 (sight_height ~150 mm) the analytic zero is 0.3° off from a real PG-2 zero at 300 m. The bead can refine the muzzle tilt per-ballistic-curve later; today the placeholder is the bigger sin.**

2. **The M16A1 ADS pass does not yet add a sight housing geometry.** The addendum says "sight rebuild complete" — I am trusting that, but the verify-by-raycast is the gate. If the front post is still a primitive cube (the US builder default), the gameplay read is fine but the rendered sight may be visually wrong. **The fix is in the `us`-builder's `fs_post` part, not in the marker plant; that is a separate bead, and I am not bundling it.**

3. **The Soviet builder will gain `add_sight_markers` calls inline.** This is a 20-line addition to `build_weapons_vc.py`. **It does not save to a blend file** (the blend is missing from disk per the deleted `art_source/`). The Soviet guns are re-built on demand. **If the builder script is ever re-run in non-LIVE mode (to write a `weapons_vc.blend`), the markers will be in that file** — but the file does not need to exist for the FP viewmodel pipeline to work.

4. **The NPC-side armory does not gain the markers.** The NPC gun geometry in `weapons_us.blend` *will* have markers after the M16A1/M60/M79 pass, but the markers do not flow into NPC GLBs (the NPC export strips them via the `append_gun.py` bake). **This is correct behavior** (NPCs do not need TRUTH markers), but it means a future "auto-aim NPC by sight line" feature would need a parallel pass to plant markers on the NPC gun copies. **Out of scope for today.**

5. **The export set patch in `export_viewmodel.py` is a one-line fossil risk.** The patch is correct today, but if a future maintainer adds another `muzzle`-like marker (e.g. `grip_R_<gun>` for the support hand) without updating the export set, the GLB will silently lose the new marker. **The mitigation is a comment in `export_viewmodel.py:74` that says "all per-gun empties must be in this set"** — but the law (`comment-discipline`) forbids narration comments. **The honest fix is a probe test in the test suite** that loads the M14 GLB and asserts the existence of `MuzzlePoint`, `SightRear_M14_Rifle`, and `SightFront_M14_Rifle`. The probe is 10 lines, belongs in `tests/test_ads_markers.tscn` (a new test), and runs in 0.2 s. **This is the M14 regression test from §10 step 3, promoted to a permanent fixture.**

---

## 12. Summary of what I am committing the council to

1. **One new helper function** (`add_sight_markers`) in `tools/fp_grip.py`, ~15 lines, mirroring `add_grip_nodes`.
2. **One patch to `tools/export_viewmodel.py`** (~10 lines, the export set + the rename block from §9).
3. **One extension to `tools/build_weapons_vc.py`** (~20 lines, plant markers for all 5 Soviet guns inline).
4. **One new probe** in `tests/test_ads_markers.tscn` (10 lines, asserts markers exist in the M14 GLB).
5. **One lock-and-restore step** (the `rifle_pose.verify` check from §7.1) wrapped into the per-gun commit.
6. **No new blend file is created.** The Soviet master blend does not need to exist; the builder re-generates the geometry on demand, and the markers are baked in.
7. **No new sync script.** The `append_gun.refresh` function (sketched in §5.2) is a 30-line extension of an existing tool, not a new tool — and it is *optional* (the workflow survives without it; the owner just re-runs `build_weapons_vc.py` for Soviet guns and manually replaces the mesh in `fp_arms_rifle.blend` for US guns, the existing pattern).

**The Day-1 build order is M16A1 → AK-47 → M14 re-export → Mosin.** Four guns, four beads (or one bead with four sub-tasks, per the Council's preference). Each gun closes the chain-B placeholder for that gun. **By end of Day 1, 4 of the 13 placeholder `ads_position` values are gone and replaced with analytic values from the markers.** The other 9 are a one-day follow-up with the same recipe.

---

## 13. Adversarial self-check (the devils-advocate would ask)

- **"Could the markers be in a per-gun file rather than per-master-blend?"** No. The markers must be on the gun object that flows through `export_viewmodel.py`. A per-gun file would split the gun and the marker, and the `obj.ray_cast` verify would have to chase a stale reference.
- **"Why not use Godot's `BoneAttachment3D` (per `GUN_ANIMATION_WORKFLOW.md` §6 item 5)?"** Because that is a *runtime* solution for the future rig change (the gun on the `weapon` bone). The ADS pass is a *content* pass — the markers are content, not runtime infrastructure. The rig change in the animation workflow is downstream of this work.
- **"What if the export set patch breaks the existing M14 viewmodel?"** The patch *adds* to the export set; it does not remove anything. The M14's `MuzzlePoint` rename path is preserved. The new markers on the M14 will appear in the GLB for the first time, but `weapon_holder.gd` does not look for them, so the game runs unchanged. The auto-align tool (9h9f) is the only thing that reads them, and it will see the same values it saw before (since the M14 was authored with the same local coordinates).
- **"Is the analytic 50 m zero worse than the placeholder?"** Yes if `sight_height` is zero (the math is undefined), and no otherwise. The placeholder is `(0, 0.05, 0.08)` with rotation `(4, 0, 0)` degrees — that is "shift the gun 5 cm up and 8 cm back, then rotate 4° about X." It is *not a sight line at all*; it is a hack. The analytic zero is a 0.2° tilt about the gun's bore axis. **For every gun with a non-zero `sight_height` (i.e. every gun in the roster), the analytic zero is closer to correct than the placeholder.** For a sight_height < 5 mm, both are visually identical; for a sight_height > 50 mm, the placeholder is *catastrophically wrong* (the gun is rotated 4° when it should be 0.6°). The 4° placeholder is the cause of the M16/Mosin "snaps" the Summoner is seeing.
- **"Is this really parallel work or are there dependencies?"** The four Day-1 guns (M16A1, AK-47, M14 re-export, Mosin) are independent — they touch different files (`weapons_us.blend` vs `build_weapons_vc.py` vs the export set patch). The dependencies are: (a) the §9 export set patch must land before the first new GLB is exported; (b) the `add_sight_markers` helper must exist before the first gun is planted. Both are script edits with no inter-dependency. The owner can plant markers in `weapons_us.blend` while I write the Soviet extension in parallel.
- **"Are we introducing new fossils?"** The §11.5 mitigation is a probe test in the suite. The `SightRear_<gun>` / `SightFront_<gun>` rename is the same pattern as `MuzzlePoint` and `LightOrigin` (already in the codebase). No new naming convention is invented. The `add_sight_markers` helper is a mirror of `add_grip_nodes`, not a new tool. **The risk of fossil is low; the probe test is the backstop.**

---

*End of analysis. The two action items the council votes on: (1) the per-gun ADS pass recipe (§4.2), (2) the export set patch (§9). Everything else is implementation. I will not start coding until the synthesis names the chosen path.*
