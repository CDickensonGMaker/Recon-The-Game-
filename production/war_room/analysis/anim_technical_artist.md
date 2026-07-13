# TECHNICAL ARTIST — FP Gun Animation Workflow (reloads first)

**Council seat:** Technical Artist / Blender Specialist
**Date:** 2026-07-12 · **Blender 5.0.1** · **Godot 4.7**
**Everything below was MEASURED out of `fp_arms_rifle.blend` headlessly, not assumed.**
(Never guess in Blender — HARD RULE.)

---

## 0. WHAT IS ACTUALLY IN THE FILE RIGHT NOW (the measurements)

`art_source/characters/fp_arms/fp_arms_rifle.blend`:

| Thing | Reality |
|---|---|
| `ArmsRig` | ARMATURE, **52 bones**, all **QUATERNION** (the doc in `IK_ANIMATION_WORKFLOW.md` §3 says the IK controls are Euler — **that is now STALE**; `rifle_pose.py` forced every bone to quaternion and it stuck). |
| Constraints | `forearm.R/.L` → **IK** → `handIK.R/.L` (chain 2). `hand.R/.L` → COPY_ROTATION → `handIK`. 18× finger `.02/.03` → COPY_ROTATION → parent phalanx. **glTF carries none of these.** |
| **Live leftover** | `handIK.L` has a **COPY_TRANSFORMS → `grip_L_M60_MG`** still bound. A staging lock someone left on. `export_viewmodel.py` nukes all constraints on export, which is the only reason it hasn't shipped a bug. **Clean it.** |
| The 13 guns | **Each is ONE welded MESH object, UNPARENTED, sitting in world space.** `M14_Rifle` (672v), `M16A1_Rifle` (1236v), `AK47_Rifle` (258v), `PPSh41_Gun`, `RPD_MG`, `M60_MG`, `Mosin_Rifle_VC`, `M70sniper`, `Ithaca37_Shotgun`, `Colt45_Pistol`, `RPG2_Launcher`, `M79_Launcher`, `M26_Grenade`, `MX991_Flashlight`, `Kabar_Knife`. |
| **THE GUN NEVER MOVES.** | It is not parented to the rig, has no vertex groups, no armature modifier, and no animation. The *arms* are posed onto the *static* gun. |
| Per-gun empties | `grip_R_<gun>`, `grip_L_<gun>`, `muzzle_<gun>` — parented to the **gun object**, `matrix_parent_inverse` = identity. |
| Actions | 13 × `<gun>_idle` — **all 1 frame long** (frames 1–1), 364 or 520 f-curves = a full visual-key bake of all 52 bones. Plus a stray `rifle_fire` (8f, 134 curves, never exported) and the CC0 knife/guard/jab clips. |
| Junk in the file | `RIG-HandRig` (a 156-bone Rigify rig, unused), `Cube`+`Cube.001..008`, 36 `WGT-*` widget meshes. |
| **Non-uniform scale** | `Mosin_Rifle_VC` scale = **(0.957, 1.022, 1.043)**. PPSh/M70/Ithaca/Colt45 = 1.049 uniform. **Landmine — see §4 step 2.** |

Export path today (`tools/export_viewmodel.py`): sets one `<gun>_idle` action → **strips every pose-bone constraint** → deletes every other action → renames `muzzle_<gun>` to `MuzzlePoint` → exports `[ArmsRig, ArmsMesh, gun, MuzzlePoint]` as GLB with `export_animation_mode='ACTIONS'`.
Godot side (`weapon_holder.gd:939`): finds the `AnimationPlayer` and plays **`rifle_idle` and nothing else, ever.**

---

## 1. IS THE SUMMONER'S MENTAL MODEL RIGHT?

> *"keep the IK bones → lock the hands to parts of the gun → the gun has to be dismantled (clips and stuff) → stage the parts → fill in the gaps"*

**He is ~80% right, and the 20% he's missing is the part that actually blocks him.**

### Where he is RIGHT

1. **"Keep the IK bones."** Correct, and mandatory. You author on `handIK.R/L` + `elbowIK.R/L` + finger `.01` bones. You **never** key the forearm/upper-arm (IK solves them) or the `.02/.03` phalanges (COPY_ROTATION solves them). This is already the documented law in `IK_ANIMATION_WORKFLOW.md` §1a and it is right.
   *Corollary he may not know:* **glTF has no IK and no constraints.** Every clip MUST be baked with **visual keying** before export or it exports dead. `export_viewmodel.py` already relies on this (it strips constraints and trusts the action to be a full bake).

2. **"Lock the hands to parts of the gun."** Correct — and `tools/fp_grip.py` already does exactly this for the static hold (`lock_right_hand` → `fit_gun` → `snap_left`).

3. **"The gun has to be dismantled — like the clips and stuff."** **Correct, and this is THE missing piece.** No gun in the file is dismantled. Nothing can reload until this is fixed.

4. **"Stage the different parts and then fill in the gaps."** Correct, and it has a name: **pose-to-pose / key-pose blocking**. It is exactly how the industry authors a reload. He arrived at the professional method on instinct.

### Where he is WRONG (or has a blind spot)

1. **The hands do NOT all lock to the gun during a reload. That's what a reload IS — the support hand LEAVES.**
   The correct parenting is **asymmetric and it flips**:
   - **TRIGGER hand ← GUN.** The gun is the parent. It tilts inboard 20–35° and the right hand rides it, glued to the grip. *(Gun drives hand.)*
   - **MAGAZINE ← SUPPORT HAND.** The hand is the parent, from the moment it grabs the mag to the moment it seats it. *(Hand drives mag.)*
   - **SUPPORT HAND ← nobody.** It moves free in space for the whole middle of the clip.

   Locking the support hand to the gun for the whole reload gives you a man vibrating with his hand welded to the handguard. The lock must **hand off**.

2. **The gun itself has to become animatable, and today it literally cannot move.** It is an unparented static mesh. Every reload begins with the weapon tilting inboard — right now there is no channel that can express that. **This is the single biggest change to make.**

3. **"Dismantled" does NOT mean "split into separate objects."** Splitting the mesh:
   - breaks the one-mesh/one-draw-call PSX budget,
   - breaks the baked wood textures (`tools/bake_gun_wood.py`, which bakes per-material to a single image per gun),
   - and forces you into **glTF node-parent animation, which does not exist**. glTF can animate a node's TRS. It cannot re-parent a node mid-clip.

   The gun gets dismantled by **bone + vertex group**, inside the one mesh. See §2.

4. **"Fill in the gaps" does not fill itself.** Blocked key poses linearly interpolated read as a mannequin sliding on rails. The craft rules in `art_source/characters/fp_arms/ANIM_TIMING.md` (hand leads the gun by 1–2 frames · fast-in/slow-out · 10–20% overshoot then settle · hold the strong pose 2–4f · follow-through on fingers) **are** the gap-filling. That doc is already correct and already written. Use it.

### The actual industry-standard way to do an FPS reload (one paragraph)

The weapon is a **bone (or bone chain) inside the arms skeleton**, not a prop. Detachable parts — magazine, bolt/charging handle, feed cover — are **child bones** of the weapon bone, with the gun mesh **rigidly skinned** (weight 1.0, one bone per vertex) so those parts move as bones. The animator blocks 6–9 key poses, uses **temporary constraints for space-switching** (hand→gun, mag→hand), then **bakes everything to hard per-bone keys with visual keying** and deletes the constraints. What ships is **pure baked skeletal animation on one skeleton**, one clip = one animation. The engine plays a clip. It never re-parents anything at runtime. (CoD, Battlefield, Insurgency, Tarkov — all of them.)

---

## 2. HOW THE GUN GETS DISMANTLED (and the export contract)

### The verdict

> **The magazine becomes a BONE in `ArmsRig` (the arm armature).**
> The gun stays **ONE mesh object**, gains an **Armature modifier**, and is **rigidly skinned** — every vertex weight 1.0 to exactly one bone.

Rig change (52 → **54 bones**):

```
root
 └─ weapon      head at the universal trigger/grip point, tail down the bore
     └─ mag     head at the magwell, tail pointing down
     (└─ bolt / charge  — v2, for reload_empty + bolt_cycle)
```

Vertex groups on each gun mesh:
- `weapon` — every vertex, weight 1.0
- `mag` — the magazine island's vertices, weight 1.0 (removed from `weapon`)

At rest the deform is the identity matrix, so **every gun stays pixel-for-pixel where it is today and all 13 existing `<gun>_idle` clips keep working untouched** (they simply carry no keys for the two new bones, which therefore sit at rest).

### Why not the alternatives

| Alternative | Why it loses |
|---|---|
| **Mag as a separate OBJECT parented to a hand bone** | Its parent must change mid-clip (gun → hand → gun). **glTF cannot animate node parenting.** You'd have to bake its world transform anyway — at which point you've done the hard part and gained a second animated node, a second set of tracks that can desync, and a second draw call. Strictly worse. |
| **Mag as a bone in a separate GUN armature** | Two `Skeleton3D`s in Godot, two track namespaces, and `export_viewmodel.py` currently ships `export_anim_single_armature=True`. Two skeletons can and will desync under blending. No upside. |
| **Splitting the gun mesh into part objects** | Breaks the PSX one-mesh budget, breaks `bake_gun_wood.py`'s per-gun texture bake, and lands you back at the glTF re-parenting wall. |

### WHERE THE MAGAZINE IS — measured, per gun (gun-local coords, X = along the barrel, Z = up)

I walked every gun's loose-vertex islands. The mag is a **single clean island** on the priority guns:

| Gun | Mag = | Faces | Size (m) | Notes |
|---|---|---|---|---|
| **M16A1_Rifle** | island 14, material **`AluMag.001`** | 54 | 0.068 × 0.023 × 0.091 | Selectable **by material.** Default primary. |
| **M14_Rifle** | island 10, material **`AluMag`** | 54 | 0.079 × 0.048 × 0.155 | Selectable **by material.** |
| **AK47_Rifle** | **island 16** @ ctr (−0.301, 0.003, −0.037) | 40 | 0.082 × 0.033 × 0.127 | Material is `BluedSteelVC` (shared) → **must select by ISLAND, not material.** |
| **PPSh41_Gun** | **island 4** @ ctr (−0.079, 0, −0.065) | 72 | 0.047 × **0.150** × **0.152** | The drum. Thin in X, disc in YZ. |
| **RPD_MG** | island 5, material **`DrumOlive`** | 72 | 0.081 × 0.168 × 0.170 | Selectable by material. |
| **M60_MG** | **69 islands** — the belt is modelled as individual rounds (`brass`/`gunmetal`/`tracer_tip`) | — | — | **Feed-tray reload. DEFER to v2.** |
| **Colt45_Pistol** | island 4 is only the **baseplate** (0.049 × 0.024 × 0.007); the mag body is fused into the grip frame | — | — | **Needs modelling, not selection. Defer.** |
| **Mosin / Ithaca37** | no removable magazine at all | — | — | Stripper clip / tube-fed — a **different reload grammar**. Not v1. |

**→ The "this week" set is M16A1, M14, AK47.** All three have one clean magazine island. M16A1 is the default primary (`weapon_holder.gd:137`), so it goes first.

### THE EXPORT CONTRACT (Blender → GLB → Godot 4.7)

**What must be true in the .blend at export time:**
1. Gun mesh: `location=(0,0,0) rotation=(0,0,0) scale=(1,1,1)` — **all transforms applied.** (glTF **ignores the node transform of a skinned mesh** — spec, not a bug. An un-applied transform is silent corruption.)
2. Gun mesh has an **Armature modifier → `ArmsRig`** and is **object-parented to `ArmsRig`** (not bone-parented).
3. Every vertex: exactly one vertex group, weight exactly 1.0, group ∈ {`weapon`, `mag`}.
4. `muzzle_<gun>` / `grip_R_<gun>` / `grip_L_<gun>` / `sight_rear_*` / `sight_front_*` are **bone-parented to the `weapon` bone** (was: object-parented to the gun). Use `tools/bone_attach.py::attach()` — do **not** hand-roll `matrix_parent_inverse` (that bug has shipped three times in this project; read the file's header).
5. Every clip is a **full visual-key bake of all 54 bones**, and **all constraints are stripped** before export.

**What `export_viewmodel.py` must change (4 lines):**
```python
# keep the whole clip set for this gun, not just the idle:
KEEP = {f'{PFX}_idle', f'{PFX}_reload', f'{PFX}_reload_empty', f'{PFX}_fire', f'{PFX}_draw', f'{PFX}_jam'}
# ... rename each to the CONTRACT name (rifle_idle / reload / reload_empty / fire / draw / jam)
bpy.ops.export_scene.gltf(
    ...,
    export_optimize_animation_size=False,   # DEFAULT IS TRUE and it DROPS constant tracks
                                            # (this is ANIM_WISHLIST item C4's failure mode)
    export_anim_slide_to_zero=True,         # ANIM_WISHLIST C1 — clips must start at t=0
    export_force_sampling=True,             # belt-and-braces; constraints are already stripped
)
```
`export_animation_mode='ACTIONS'` (already set) gives **one glTF animation per Blender Action**, named after the action → the clip names survive into Godot's `AnimationPlayer`. That is the contract in `VIEWMODEL_ANIM_SPEC.md`.

**What Godot gets:**
```
m16_fp.glb
 └─ Skeleton3D (54 bones)
     ├─ ArmsMesh   (MeshInstance3D, skinned)
     ├─ M16A1_Rifle(MeshInstance3D, skinned — verts on `weapon` and `mag`)
     └─ BoneAttachment3D "MuzzlePoint" (on the `weapon` bone)
 └─ AnimationPlayer: rifle_idle, reload, reload_empty, fire, draw, jam
```
- `weapon_holder._get_muzzle_position()` still does `find_child("MuzzlePoint")` → **still works, and now the muzzle follows the gun through recoil and the reload tilt.** Free upgrade.
- `_scan_warhead()` walks `MeshInstance3D` surfaces by material name → unaffected by skinning.
- `bore_dir` / `hip_position` / `ads_position` are viewmodel-root-space → unaffected.
- The `.tscn` (`Model` instance, `Transform3D(-1,0,0, 0,1,0, 0,0,-1, 0,-1.81,0)`) → **unchanged.**

**The runtime is trivial, because the mag is a bone: Godot re-parents NOTHING.** No method tracks, no prop swap, no `Marker3D` juggling. It plays a clip. That is the entire payoff of the bone approach.

> ### ⚠ THE ENGINE GAP — NAME IT OR THE WORK IS INVISIBLE
> `weapon_holder.gd:939-941` plays **`rifle_idle` and nothing else.** There is no code path that plays `reload`, `fire`, `draw`, or `jam`. Every signal it needs (`reload_started`, `reload_progress`, `weapon_fired`, `weapon_jammed`, `switch_started`) **is already emitted.**
> Somebody must write ~40 lines of `viewmodel_anim.gd`: on `reload_started` → `play("reload_empty" if current_ammo==0 else "reload")` with `speed_scale = clip_length / reload_timer` (so Agility-sped reloads still land the mag-slap on the beat). **Without it, every animation Caleb authors will never appear in the game.** This is a hard dependency, not a nice-to-have. Bead it.

---

## 3. HAND IK — DO THE HANDS DRIVE THE GUN, OR THE GUN THE HANDS?

**Both, at different times, on different limbs. Getting this backwards is why reloads slide and pop.**

| Phase | Trigger hand (`handIK.R`) | Gun (`weapon` bone) | Support hand (`handIK.L`) | Magazine (`mag` bone) |
|---|---|---|---|---|
| **Idle / ready** | on the grip | **static** | on the foregrip | child of `weapon` (in the well) |
| **Tilt in** | **follows the gun** | **DRIVES** (tilt inboard/down 20–35°) | follows the gun | in the well |
| **Reach for mag** | follows the gun | holds the tilt | **FREE — drives itself** | in the well |
| **Strip mag → out of frame → fresh mag** | follows the gun | holds the tilt | **FREE — drives itself** | **follows the support hand** |
| **Seat + slap** | follows the gun | small 3° jolt on the slap | **FREE — drives itself** | follows the hand until the seat frame, then back in the well |
| **Return to ready** | follows the gun | **DRIVES** (untilt, 10–20% overshoot, settle) | back onto the foregrip | in the well |

So: **for the trigger hand, the gun is the parent. For the magazine, the support hand is the parent. The support hand has no parent at all.**

### How it's authored so it does not slide or pop

**The trigger hand — no sliding, guaranteed by construction.**
Give `handIK.R` a **CHILD_OF constraint targeting `ArmsRig` / `weapon`**, influence 1 for the entire clip. Now you animate the **gun**, and the right hand is mathematically incapable of leaving the grip. You never key `handIK.R` in world space during a reload at all. Grip slide becomes impossible, not merely unlikely.
(Set Inverse once, on the rest frame, while the gun is at rest.)

**The magazine — the parent switch, and THE BIGGEST GOTCHA IN THIS ENTIRE JOB.**

A `CHILD_OF` whose **influence is keyed 0 → 1 mid-clip WILL POP.** Blender solves it against a *stored* `inverse_matrix` computed once at "Set Inverse" time; the moment influence crosses 0, the mag teleports to wherever that stale matrix puts it. This is the classic space-switch pop and it is the single most common way an amateur reload betrays itself.

**Do not fight it. Do not use a keyed-influence constraint at all. Bake the follow directly in world space:**

```python
# tools/fp_anim.py — follow(): a CHILD_OF, minus the inverse-matrix trap.
def follow(arm, child, parent, f0, f1):
    """Make bone `child` rigidly follow bone `parent` over [f0, f1],
    preserving their EXACT relative offset as of frame f0."""
    scene = bpy.context.scene
    scene.frame_set(f0); bpy.context.view_layer.update()
    pc, pp = arm.pose.bones[child], arm.pose.bones[parent]
    offset = pp.matrix.inverted() @ pc.matrix          # captured at the handoff frame
    for f in range(f0, f1 + 1):
        scene.frame_set(f); bpy.context.view_layer.update()
        pc.matrix = arm.pose.bones[parent].matrix @ offset   # pose space; arm.matrix_world cancels
        pc.keyframe_insert("location", frame=f)
        pc.keyframe_insert("rotation_quaternion", frame=f)   # all 52 bones are QUATERNION — measured
```

Because the offset is captured **at the handoff frame**, the mag's world position at frame `f0` is **bit-identical** under both parents. **The seam is continuous by construction — there is nothing left to pop.** Same trick at the seat frame, in reverse.

Then **verify, don't trust** (Never Guess In Blender):
```python
assert seam_delta(mag, f_strip) < 1e-4   # metres — 0.1 mm
assert seam_delta(mag, f_seat)  < 1e-4
assert max_grip_slide(handIK.R, grip_R, f0..f1) < 1e-3   # 1 mm across EVERY frame
```
That `max_grip_slide` gate is the anti-slide regression test. It runs headless. It should run on every clip, every export, forever.

**The fresh magazine.** You do **not** need two mags. One `mag` bone: the old one rides the left hand **down and out of frame**, and the same mesh comes **back up "full."** Nobody has ever noticed, in any game, ever. (If you later want a *visible dropped mag*, that's a Godot-side one-shot rigid body spawned at the mag's `BoneAttachment3D` on the mag-out frame — an engine feature, not an animation one.)

---

## 4. MINIMUM VIABLE RIG CHANGE — start making reloads THIS WEEK

**Two bones. One vertex group per gun. Some re-parenting. That is the whole change.**

Nothing about the arms, the IK, the fingers, the pose JSONs, `fp_grip.py`, `rifle_pose.py`, the viewmodel `.tscn`s, `weapon_data.gd`, or the ADS math changes. All 13 existing `_idle` clips keep working unmodified.

**New script needed: `tools/rig_gun_parts.py`** (headless, self-verifying, in the spirit of `bone_attach.py`). Per gun:

1. **Snapshot** `matrix_world` of every child empty (`grip_R_*`, `grip_L_*`, `muzzle_*`, `sight_*`) and a copy of every vertex's world position. These are the invariants.
2. **Apply transforms** on the gun mesh (`Object > Apply > All Transforms`) → loc 0 / rot 0 / **scale 1**. *Mandatory. The Mosin's `(0.957, 1.022, 1.043)` non-uniform scale will silently corrupt a skinned glTF export otherwise.*
3. **Edit-mode on `ArmsRig`:** add bone `weapon` (parent `root`, head at the universal grip/trigger anchor = `handIK.R`'s head, tail 20 cm down the bore, `use_connect=False`) and bone `mag` (parent `weapon`, head at the mag island's bbox top-centre, tail at its bottom). Set both to `QUATERNION`, matching the other 52.
   *Why the pivot sits at the grip:* `ANIM_TIMING.md` demands "the muzzle rises **around the grip pivot**, not straight back." Put the bone where the physics is and recoil animates itself.
4. **Vertex groups:** `weapon` ← all verts @ 1.0. `mag` ← the magazine island's verts @ 1.0, removed from `weapon`. (Island/material picks: §2 table. Add a `--dump-islands` mode so a new gun is a 30-second lookup, never a guess.)
5. **Parent** gun → `ArmsRig` with an **Armature modifier** (`Ctrl+P > Armature Deform`, *keep transform*), rig in **REST**, depsgraph flushed. (Read `bone_attach.py`'s header on TRAP 2 before you touch this.)
6. **Re-attach the empties** to the `weapon` **bone** via `bone_attach.attach()` — identity parent-inverse, then set `matrix_world`. Never hand-roll the inverse.
7. **GATE — assert, then screenshot:**
   - every empty's `matrix_world` is unchanged from step 1 (< 1e-4)
   - the rest-pose *deformed* mesh is vert-for-vert identical to the step-1 snapshot (< 1e-5) — **the gun did not move when we skinned it**
   - every vert has exactly one group, weight 1.0
   - the `mag` group's bbox hangs **below** the bore and is **disjoint** from the rest
   - render the gun with the `mag` group hidden → **look at it.** A gun with a mag-shaped hole under the receiver = correct. Anything else = you grabbed the wrong island. *(Measure AND look. Both.)*
8. **Clean while you're in there:** delete the stale `handIK.L → COPY_TRANSFORMS → grip_L_M60_MG` constraint, `RIG-HandRig`, and the `Cube.*` junk.

That's the rig. **You can start blocking the M16 reload the same afternoon.**

---

## 5. STEP-BY-STEP: AUTHOR THE M16A1 RELOAD

**Target:** `m16a1.tres` says `reload_time = 2.4s`, `magazine_size = 20`. At 30 fps → **72 frames**. `ANIM_TIMING.md`'s canonical tactical reload is 66f/2.2s — so author 72f and the phase percentages below map straight onto it.

**Tooling split:** *authoring + eyeballs* = **MCP into the live GUI Blender** (real context, `bpy.ops` work, screenshots). *Rigging, baking, gates, export* = **headless `blender -b -P`** (repeatable, no context traps). Both are in play.

---

**1. Open the right file.** The live Blender currently has `gear_armory.blend` open — **`get_scene_info` proves it**. Open `art_source/characters/fp_arms/fp_arms_rifle.blend` before anything else, and re-confirm with `get_scene_info`. (Every MCP call hits whatever blend is actually open. This *will* bite someone.)

**2. Rig it (once, headless).**
```
blender -b art_source/characters/fp_arms/fp_arms_rifle.blend -P tools/rig_gun_parts.py -- M16A1_Rifle --mat AluMag.001
```
Passes the §4 step-7 gate, **saves the blend** (this one *does* save — it's a rig change, not an export).

**3. Load the hold + set up the space-switch (MCP, `execute_blender_code`).**
```python
import rifle_pose, fp_grip
arm = bpy.data.objects["ArmsRig"]
rifle_pose.apply(arm)                    # the captured M16 hold, every knuckle placed
print("reconstruction err:", rifle_pose.verify(arm), "mm")   # want ~0
# THE TRIGGER-HAND LOCK: gun becomes the parent of the right hand.
c = arm.pose.bones["handIK.R"].constraints.new('CHILD_OF')
c.target, c.subtarget = arm, "weapon"     # Set Inverse on the rest frame
```
Set scene to **30 fps, frames 1–72**. `handIK.L` gets **no** constraint — it is free.

**4. BLOCK the 8 key poses.** Constant interpolation first — read the *poses*, ignore the motion. Screenshot each from the `camera` bone view.

| # | Frame | % | Pose | What moves |
|---|---|---|---|---|
| 1 | 1 | 0% | **ready** (= the `m16_idle` hold, verbatim) | — |
| 2 | 9 | 12% | **tilt in** — gun rolls inboard/down 25–30° | `weapon` (R hand rides it free) |
| 3 | 15 | 21% | **support hand off the foregrip, onto the mag** | `handIK.L` + finger `.01`s → grip curl |
| 4 | 19 | **26%** | **MAG OUT** — thumb hits the release, mag breaks free | `handIK.L` starts pulling; **`follow(mag, hand.L, 19, 43)` from here** |
| 5 | 30 | 42% | **mag clear, hand dropping out of frame** | `handIK.L` down + toward camera |
| 6 | 37 | 51% | **fresh mag rising** (same mesh, offscreen swap — nobody sees it) | `handIK.L` back up |
| 7 | 43 | **60%** | **SEATED** — mag lips into the well | `follow` ends; mag is back on `weapon` |
| 8 | 50 | 69% | **THE SLAP** — palm hammers the baseplate. **The money beat.** | `handIK.L` snap up + **`weapon` jolts ~3°** |
| 9 | 58 | 80% | bolt-release paddle jab *(v2 — needs the `bolt` bone)* | — |
| 10 | 72 | 100% | **back to ready** — identical to frame 1 | `weapon` untilts, R hand rides it |

*(Percentages come straight from `ANIM_TIMING.md`'s scalable-reload table — mag-out at 25%, mag-in at 60%. Keep them there. That is what lets the engine stretch the clip for Agility and still land the slap on the beat.)*

**5. Bake the magazine's follow (MCP).** `fp_anim.follow(arm, "mag", "hand.L", 19, 43)` — §3. Then assert the two seams < 0.1 mm. **If a seam fails, stop. Do not eyeball a pop away — measure it.**

**6. FILL THE GAPS — this is the craft, and it is where reloads live or die.**
Switch interpolation to **BEZIER**, then work the **Graph Editor** and apply `ANIM_TIMING.md`'s 7 rules — every one of them, deliberately:
- **Hand leads the gun by 1–2 frames.** Offset the `handIK` curves 1–2f *ahead* of the `weapon` curves. This is the single biggest pro-vs-amateur tell.
- **Fast-in / slow-out.** 2–5f attack into every pose, 6–15f settle out. Never symmetric.
- **Overshoot 10–20%, then ease back.** Never stop hard on the target pose. Especially the untilt at f58–72.
- **Hold the strong poses 2–4f** — the seat (f43) and the slap (f50). Readability lives in the holds.
- **Follow-through:** fingers and the support hand keep moving 1–3f *after* the gun stops. A 2-frame hand drag after the mag slap is what sells the impact.
- **Start motion on frame 2, not 1** — free responsiveness; the button press throws you into the action.

**7. REVIEW — you cannot scrub a timeline over MCP.** Playblast instead: `bpy.ops.render.opengl` from the `camera` bone, every 3rd frame, overlays off, into `/scratchpad/reload_%02d.png` → then **Read the PNGs.** That is the review loop. Iterate steps 6–7 until it reads.

**8. Bake the clip (headless — `bpy_extras.anim_utils.bake_action`, `do_visual_keying=True`).** This resolves the forearm IK, the 18 finger COPY_ROTATIONs, and the trigger-hand CHILD_OF into **hard keys on all 54 bones**. Name the action `m16_reload`. Re-verify the grip-slide gate on the *baked* action (< 1 mm every frame) — the bake is exactly where a subtle IK flip would show up.

**9. Export.**
```
blender -b fp_arms_rifle.blend -P tools/export_viewmodel.py -- M16A1_Rifle m16
```
with the §2 changes: keep the whole `m16_*` clip set, rename to the contract names, `export_optimize_animation_size=False`, `export_anim_slide_to_zero=True`. Constraints are stripped *after* the bake, so the actions read verbatim.

**10. Assert the GLB** (`tools/diff_glb.py` already exists — extend it): 54 bones · the expected animation names · the gun mesh has `JOINTS_0`/`WEIGHTS_0` (i.e. it really is skinned) · every clip starts at t=0. `ANIM_WISHLIST` item **C4** exists precisely because one "optimize size" checkbox can silently gut this.

**11. Godot.** Write `viewmodel_anim.gd` (§2's engine gap) and watch it in `viewmodel_editor.tscn`. **Then, and only then, is the reload real.**

**12. Fan out.** M14 and AK47 are the *same* clip retimed with a different mag island and a different strip motion (AK = **rock-out** on the strip, **hook-and-rock-in** on the insert; M16 = straight pull, straight insert + paddle). The rifle set is reused across all three — that's `ARM_ANIMATION_SPEC.md`'s SET 1 and it is correct.

---

## 6. "VERIFY ALL GUNS MATCH THE RIG" — what the job actually is

He asked. Here is the honest answer: **right now, ZERO guns match the rig, because the rig has no `weapon` or `mag` bone at all.** The job is not an audit — it is a **migration with an audit gate**. It's `tools/verify_gun_rig.py`, headless, run over all 13 guns, asserting:

1. Gun mesh has an Armature modifier → `ArmsRig`, is object-parented to it, and has **identity transform** (loc 0 / rot 0 / **scale 1** — the Mosin will fail this until fixed).
2. Every vertex has **exactly one** vertex group at weight **1.0**, and that group ∈ {`weapon`, `mag`, `bolt`}. (No stray weights, no unassigned verts, no accidental smooth-skin blending.)
3. `mag` group is **non-empty**, its bbox hangs **below the bore**, and it's **disjoint** from `weapon`'s.
4. **Rest-pose deform == the pre-migration mesh, vert for vert** (< 1e-5). *The gun did not move when we skinned it.* This is the one that catches everything.
5. `grip_R_<gun>` / `grip_L_<gun>` / `muzzle_<gun>` (+ `sight_rear_*`/`sight_front_*` where the ADS pass has been done) are **bone-parented to `weapon`**, and their `matrix_world` is **unchanged** from before the migration (< 1e-4).
6. Per clip: `handIK.R` stays within **1 mm** of `grip_R` on **every frame** (no grip slide), and `mag`'s world transform is **continuous at both parent-switch seams** (< 0.1 mm).
7. Post-export: the GLB has 54 bones, the expected animation names, and a genuinely skinned gun mesh.
8. **Render each gun with `mag` hidden and LOOK at all 13.** The gate proves the numbers; only your eye proves you grabbed the right island. **Measure AND look.**

**And the honest per-gun scope, from the §2 measurements:**

| Tier | Guns | Work |
|---|---|---|
| **Trivial** (this week) | M16A1, M14, RPD | Mag island is a **single, material-tagged** island. Script picks it. |
| **Easy** | AK47, PPSh41 | Single clean island, but **must be picked by island index, not material.** |
| **Hard** | M60 | Belt = **69 islands** of individual rounds. Feed-tray reload. **v2 — real work.** |
| **Needs modelling** | Colt45 | Mag body is **fused into the grip frame**. Someone has to cut it. |
| **Different grammar** | Mosin, Ithaca37 | **No removable magazine.** Stripper clip / shell-by-shell tube. A `bolt` bone and a different clip set — not this sprint. |
| **N/A** | M70sniper, RPG2, M79, M26, MX991, Kabar | Own reload grammar (front-load / break-open / none). Later. |

---

## 7. THE BLENDER MCP TOOLS — WHAT THEY DO AND DON'T

**Confirmed live this session:** Blender **5.0.1**, GUI running, addons `io_scene_gltf2` + `pose_library` + `rigify` enabled, **currently holding `gear_armory.blend`.**

| Tool | What it actually lets us do |
|---|---|
| **`execute_blender_code`** | **The workhorse.** Arbitrary `bpy` in the *live GUI* Blender — so it has **real context**, and `bpy.ops` that need a `VIEW_3D` (including `nla.bake`) actually work, unlike `--background`. Keyframe, constrain, bake, measure, assert, `render.opengl`. Everything in §5 runs through this. |
| **`get_scene_info`** | Object list + types + locations + material count. **Use it first, every session, to prove which .blend is open.** |
| **`get_object_info`** | One object's detail — transform, mesh stats, materials. |
| **`get_viewport_screenshot`** | **The eyes.** Whatever the user's viewport is currently framing. This is what makes "measure AND look" possible at all. |
| Asset generators (`polyhaven`, `sketchfab`, `hyper3d`/Rodin, `hunyuan3d`) | Irrelevant to this job. Ignore. |

**What they CANNOT do — plan around these:**
- **No timeline scrubbing, no playback.** You cannot *watch* an animation. **Substitute:** `frame_set()` + `bpy.ops.render.opengl` from the `camera` bone → a strip of PNGs → **Read the PNGs.** That is the review loop and there is no other one. Build it into `fp_anim.py` as `playblast(f0, f1, step)`.
- **No camera control on `get_viewport_screenshot`** — it returns *the user's* viewport. To frame a shot yourself, set `region_3d.view_matrix` via `execute_blender_code`, or bypass it entirely and use the offscreen `render.opengl` path (which is what `WEAPON_ADS_WORKFLOW.md` step 5 already does).
- **No undo across calls.** A bad `execute_blender_code` is *live* in the user's open file. **Never save from an authoring call** — save deliberately, or work headless on a copy.
- **It hits whatever blend is open.** Right now that's `gear_armory.blend`, **not** the arms. Check with `get_scene_info` or you will author into the wrong file.
- **Long ops can time out.** Keep code chunks small — bake in frame batches, not one 72-frame monolith.
- **The stale-depsgraph trap is real here.** `bpy.context.view_layer.update()` after *every* transform write, before *any* world-space read. IK solves lazily. (`bone_attach.py` TRAP 2 · `WEAPON_ADS_WORKFLOW.md` addendum: "stale depsgraphs lie.")

**Division of labour:** MCP/GUI for **authoring and eyeballs**. Headless `blender -b -P` for **rigging, baking, gates, and export** — repeatable, no context traps, runs in CI.

---

## 8. SCRIPTS: WHAT EXISTS, WHAT'S NEEDED

| Script | Status |
|---|---|
| `tools/rifle_pose.py` | ✅ Keep. Restores the exact captured hold. Note it forces every bone to QUATERNION — that's why all 52 are quaternion now. |
| `tools/fp_grip.py` | ✅ Keep. Static hold staging. Untouched by this change. |
| `tools/bone_attach.py` | ✅ **Use it.** Its two traps (tail offset, pose-space basis) are exactly the traps §4 step 6 walks into. Read the header. |
| `tools/export_viewmodel.py` | ⚠ **Amend** (§2): keep the clip set, contract-rename, `export_optimize_animation_size=False`, `export_anim_slide_to_zero=True`. |
| `tools/diff_glb.py` | ⚠ **Extend** into the GLB assert (§5 step 10 / `ANIM_WISHLIST` C4). |
| **`tools/rig_gun_parts.py`** | 🆕 **NEW.** The migration + gate. §4. |
| **`tools/fp_anim.py`** | 🆕 **NEW.** `key_pose()` · `follow()` (the pop-free space switch) · `bake_clip()` · `verify_seam()` · `max_grip_slide()` · `playblast()`. §3, §5. |
| **`tools/verify_gun_rig.py`** | 🆕 **NEW.** The all-guns gate. §6. |
| **`scripts/player/viewmodel_anim.gd`** | 🆕 **NEW — ENGINE SIDE.** Without it none of this animation is ever seen. §2. |

---

## 9. TRADEOFFS — WHAT THIS DECISION COSTS (no free lunches)

- **Every gun mesh becomes a skinned mesh.** +2 bone matrices per vertex of GPU cost on ~13 low-poly meshes. At 258–1236 verts, this is **free** in practice. Not a real cost, but it *is* a cost.
- **`fp_grip.fit_gun()` stops being meaningful** for a rigged gun — it moves `gun.location`, and after §4 step 2 the gun has no object transform. **Staging must happen BEFORE rigging.** Gun goes: model → ADS pass → stage/pose → **lock** → *then* rig. One-way door. Rigging a gun that isn't staged yet means un-rigging it to move it.
- **Two new bones ride along in every clip**, including the 13 idles that don't use them. ~10 extra f-curves per clip. Nothing.
- **The M60 belt and the Colt45 mag are not solved by this** — they need modelling work, not a script. Naming that now beats discovering it in three weeks.
- **The `weapon` bone has ONE rest position shared by all 13 guns.** Correctness is unaffected (rigid weight-1 skinning at rest is the identity regardless of where the bone sits). But the *authoring pivot* is only ideal for guns whose trigger sits near the shared anchor. The RPG-2 (grip near the front) and the M60 will feel off-pivot to animate. **Accept it for v1**; if it bites, key `weapon`'s location alongside its rotation, or add a per-archetype second bone. Do not pre-solve this.

---

## 10. THE ONE-LINE ANSWERS

1. **Is his model right?** 80% yes — and he independently reinvented key-pose blocking, which is the professional method. **Wrong on one thing that matters:** the support hand doesn't lock to the gun during a reload, it *leaves*; the lock **hands off** (gun→trigger hand, support hand→mag). **Blind spot:** the gun currently *cannot move at all*, and IK/constraints do not survive glTF — everything must be **baked with visual keying**.
2. **How is the gun dismantled?** The magazine becomes a **BONE in `ArmsRig`**; the gun stays **one mesh**, rigidly skinned (weight 1.0). **Not** a separate object, **not** a second armature — glTF cannot animate node re-parenting, so both of those force you to bake the world transform anyway and hand you a desync risk for free.
3. **Do hands drive the gun or vice versa?** **The gun drives the trigger hand** (CHILD_OF → `weapon`, grip slide becomes impossible). **The support hand drives the magazine** (world-space `follow()` bake, offset captured at the handoff frame → the seam is continuous *by construction*, so there is nothing to pop). The support hand itself is free.
4. **Minimum rig change?** **Two bones** (`weapon`, `mag`) + one vertex group per gun + re-parent the empties to the `weapon` bone. 52 → 54 bones. **All 13 existing idles keep working untouched.** M16A1/M14/AK47 are ready this week — their magazines are single clean islands (measured).
5. **New scripts?** **Yes — three Blender (`rig_gun_parts.py`, `fp_anim.py`, `verify_gun_rig.py`) and one Godot (`viewmodel_anim.gd`).** The Godot one is the hard dependency: `weapon_holder.gd` plays `rifle_idle` and *nothing else*, so **without it, every animation he authors is invisible.**
6. **The verify job?** A migration with an 8-point gate — the load-bearing assertion being **"the rest-pose deform is vert-for-vert identical to the pre-skin mesh."** If the gun moved when you skinned it, you've corrupted it silently. **Then render all 13 with the mag hidden and LOOK.** Measure *and* look.
