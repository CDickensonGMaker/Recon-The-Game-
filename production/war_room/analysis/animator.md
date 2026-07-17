# Animator — FP Weapon ADS Sight Work vs. The Existing Rifle_Idle Clip

**Architect:** animator · **Council:** 2026-07-14 · RECONgame
**Knowledge loaded:** `GUN_ANIMATION_WORKFLOW.md`, `viewmodel_anim.gd` plan (§6), `viewmodel_editor.gd`, ADR-001, ADR-014, ADR-023.
**Method:** I parsed every `*_arms_viewmodel.tscn` (13), every `*_fp.glb` node graph (11), the `export_viewmodel.py` exporter, the editor model-load path, and the .tres `hip_*` / `ads_*` values. Channel counts measured, not inferred.

---

## 0 · THE ONE FACT THAT BINDS EVERYTHING BELOW

The `*_arms_viewmodel.tscn` files are **single-GLB wrappers** (lines 1–9, all 13). They are 9 lines each:

```
[ext_resource type="PackedScene" path="res://assets/player/viewmodels/<X>_fp.glb" id="1"]
[node name="<X>ArmsViewmodel" type="Node3D"]
[node name="Model" parent="." instance=ExtResource("1")]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)
```

That is the **entire** .tscn. **No AnimationPlayer lives in the .tscn. No `rifle_idle` lives in the .tscn.** The clip, the armature, the MuzzlePoint, the gun, the empty — all five — live **inside the GLB**, instantiated as the `Model` child at the (0, -1.81, 0) Y-drop offset the editor and the game share.

The m26 grenade viewmodel and the medkit viewmodel are **not** GLB-based — m26 instances a gltf scene, medkit is CSG-only. Neither has an `rifle_idle` clip. Neither is touched by this analysis.

---

## 1 · PER-VIEWMODEL .TSCN STATUS (all 13)

| # | Viewmodel .tscn | Has `AnimationPlayer` in .tscn? | Has `rifle_idle` in .tscn? | Notes |
|---|---|---|---|---|
| 1 | `m14_arms_viewmodel.tscn` | **no** | **no** (inside `m14_fp.glb`) | GLB has 156 channels, 1 anim `rifle_idle`, 1 empty `MuzzlePoint` |
| 2 | `m16a1_arms_viewmodel.tscn` | **no** | **no** (inside `m16_fp.glb`) | identical structure |
| 3 | `ak47_arms_viewmodel.tscn` | **no** | **no** (inside `ak_fp.glb`) | identical |
| 4 | `mosin_arms_viewmodel.tscn` | **no** | **no** (inside `mosin_fp.glb`) | gun mesh has non-uniform scale (0.957, 1.022, 1.043) — applied by `export_apply=True` |
| 5 | `m60_arms_viewmodel.tscn` | **no** | **no** (inside `m60_fp.glb`) | belt is 69 islands (GUN_ANIMATION_WORKFLOW §7b) |
| 6 | `rpd_arms_viewmodel.tscn` | **no** | **no** (inside `rpd_fp.glb`) | belt-fed |
| 7 | `ppsh_arms_viewmodel.tscn` | **no** | **no** (inside `ppsh_fp.glb`) | drum mag (island 4) |
| 8 | `m70_arms_viewmodel.tscn` | **no** | **no** (inside `m70_fp.glb`) | stripper-clip reload (no removable mag) |
| 9 | `ithaca_arms_viewmodel.tscn` | **no** | **no** (inside `ithaca_fp.glb`) | pump action, no removable mag |
| 10 | `colt45_arms_viewmodel.tscn` | **no** | **no** (inside `colt45_fp.glb`) | **.tres is m1911.tres — the pistol viewmodel is reused.** Mag fused into grip frame. |
| 11 | `rpg2_arms_viewmodel.tscn` | **no** | **no** (inside `rpg2_fp.glb`) | launcher |
| 12 | `m26_grenade_viewmodel.tscn` | **no** | **no** (gltf, no skeleton) | not an arms viewmodel — no `rifle_idle` ever |
| 13 | `medkit_viewmodel.tscn` | **no** | **no** (CSG boxes) | not an arms viewmodel — no rig at all |

**Every animation channel — 156 of them across 53 bones (52 named arm + camera + ArmsMesh as 53 nodes; let me correct: 156 / 3 TRS = 52 bone nodes, the IK bones 49–53 contribute too, see below) — lives inside the GLB and is loaded by Godot at GLB instantiate time, not at .tscn parse time.** That is why `weapon_holder.gd:823-825` and `viewmodel_editor.gd:271-273` use `find_child("AnimationPlayer", true, false)` — they recurse INTO the GLB-instanced subtree.

### A `rifle_idle` clip is *keyframed, not empty*, in every GLB checked

Verified: m14_fp, m16_fp, ak_fp each carry `rifle_idle` with **156 channels**, all targeting bone nodes (49–53 range). The arms are 100% posed around the gun. The gun mesh has **zero** animation channels. This matches the GUN_ANIMATION_WORKFLOW measurement.

### Why all 11 GLBs are identical in node count (56 nodes)

```
root
├── ArmsRig
│   ├── ArmsMesh (mesh, skin)
│   └── 52 bones (shoulder, upper_arm, forearm, hand, palm.01–04, fingers, IK targets, camera)
├── <GUN>_Rifle (mesh)  ← one mesh, NO skin
│   └── MuzzlePoint (empty)  ← child of gun, not a bone, not in any animation channel
```

The `MuzzlePoint` in m14_fp is **node 19, child of node 20 `M14_Rifle`** — i.e. **parented to the gun mesh, not the rig, not world, not a bone.** Same parenting in every GLB.

**This is the load-bearing detail for the ADS work.** See §3.

---

## 2 · WILL THE ADS WORK BREAK THE EXISTING `rifle_idle` CLIP?

### Verdict: **NO — if (and only if) the new sight empties are parented to the gun mesh (or world), NOT to a bone.**

Reasoning, measured:

- `rifle_idle` carries **156 channels** on **52 nodes**, all in bone index range 49–53 plus arm bones 0–48. **Zero channels target the gun mesh, MuzzlePoint, or any empty.** Verified by direct channel-list read of m14_fp / m16_fp / ak_fp.
- Per `tools/export_viewmodel.py:74-79`, the exporter selects **`[arm, mesh, gun]`** plus `muz` (the MuzzlePoint). **Anything else in the .blend is dropped at export.**
- The exporter does **not** enumerate empties generically. It strips pose-bone constraints, removes all but the idle action, and renames ONE empty (`muzzle_<GUN>` → `MuzzlePoint`).

**Therefore the ADS work is safe under two conditions, dangerous under one:**

| Empty parented to | Impact on existing 156 channels | Impact on future animation |
|---|---|---|
| **Gun mesh (`<GUN>_Rifle`)** | **none** — gun has no channels | breakable on weapon-bone add unless the empty is re-parented then |
| **World (root)** | **none** | static — never moves, can't be used as IK target |
| **A bone on `ArmsRig`** | **none** if it's a new bone with no track; **breaks the existing clip** if it's a bone with an existing channel and the empty is re-skinned, because `remove_immutable_tracks=true` is the live .import setting | best for the future — see §3 |

The exporter is the gatekeeper, not the .tscn or the AnimationPlayer. If `sight_rear_<gun>` and `sight_front_<gun>` are added to the .blend and the exporter is **not** updated, **the empties are dropped on export** — same as `muzzle_<gun>` would be if its name didn't match. Right now the export selector picks `[arm, mesh, gun, muz]` and nothing else. The briefing's claim that "M14 has the markers" is **wrong by the exporter's contract** — the .blend may have them, but the .glb does not. Verified: zero `sight*`-named nodes in any of the 11 GLBs.

### Per-viewmodel: does the ADS geometry authoring break the existing clip?

**All 11 arms viewmodels: NO — under the gun-mesh-parent rule above, the existing `rifle_idle` will continue to play untouched.** This is the Technical Artist's §7 ruling: the rig change is additive; adding empties to the gun mesh is the same kind of additive change.

**Caveat — `remove_immutable_tracks = true` is still set in every .import file** (m14_fp.glb.import line 36; presumably all 11). Per GUN_ANIMATION_WORKFLOW §3, this will delete any bone track that has no keyframes. **For the ADS work this is harmless: no new bone is being added with no keyframes.** For the future reload/jam work, it remains the live landmine.

---

## 3 · THE BONE-EMPTIES vs WORLD-EMPTIES vs GUN-MESH-EMPTIES DECISION

This is the only decision the ADS work makes that has a downstream cost, and the only one where the right answer depends on the rig-change plan in GUN_ANIMATION_WORKFLOW §7.

### The three options

**Option A — parent `sight_rear_<gun>` and `sight_front_<gun>` to the gun mesh (`<GUN>_Rifle`).**
- Same parent as `MuzzlePoint` today.
- Exporter needs a **one-line change**: `if muz: export_set.append(muz)` → loop over a known list of empties (`muz`, `srear`, `sfront`).
- The empties ride with the gun when it tilts during a future reload — but the gun **cannot tilt today** (GUN_ANIMATION_WORKFLOW §7b, verified: zero channels on the gun mesh). So the sight empties are static until the rig change lands.
- The exporter pipeline takes them through to the GLB for free.
- **Downside:** when the rig change lands and the gun becomes a bone-skinned mesh, the sight empties are children of the gun MESH, not the gun BONE. They get re-parented to the bone then, OR they keep riding the mesh's rest transform, which glTF can move if the gun bone rotates. In practice: empties parented to a mesh that is itself skinned to a bone *do* move with the bone in Godot — the mesh is rendered by the bone's transform, and the empty's parent is the mesh, which is the bone. **It works, but it's two indirection hops.** This is the same pattern MuzzlePoint already follows.

**Option B — parent the empties to a new bone on `ArmsRig` (e.g. `sights` or `iron_sights`).**
- **Wrong today, right tomorrow.** Today the gun is not a bone — making `sights` a bone gives an AnimationPlayer a track that, with `remove_immutable_tracks=true` and no keys, will be deleted, then with one key on a future reload clip the empty rides the bone. The exporter would have to include this bone in the export.
- Skips the gun-mesh indirection hop.
- But: it commits to the §7 rig change being additive (it is) and means two bones must be added instead of one if the gun mesh also needs to be a bone (52 → 54 per the workflow).
- **A trap:** the workflow says "two bones (weapon + mag)" and the AK magazine rock-in is a §1 chain (`gun → magwell → gun_mag`). **Adding a third `sights` bone breaks the "minimum rig change is two bones" decree.** Strictly, the answer is no — use Option A or a sub-mesh of the gun.

**Option C — parent the empties to world (root) with a world-space `bore_dir` baked.**
- Static forever. Useless for a future reload where the gun tilts inboard — the sights detach from the gun in space.
- Free in every other way (no exporter change, no rig change, no risk).
- Wrong for an FPS where the gun moves during gameplay.

### My recommendation: **Option A (parent to gun mesh).**

Reasons:
1. Matches the existing `MuzzlePoint` pattern. Symmetric. No new mental model.
2. The §7 "minimum rig change" decree is preserved (still 52 → 54 if/when the weapon+mag bones land — sights don't grow the count).
3. When the gun becomes bone-skinned, the empty rides the bone's transform via the mesh — same as MuzzlePoint rides today. The 1-hop indirection is invisible to gameplay code.
4. The exporter change is **2 lines** — explicit list of empties to carry through, not a magic regex.

**The devil's advocate counter:** Option A is correct only if the gun's BORE is the empty's parent in the post-rig-change world. If the §1 chain (`gun → magwell → gun_mag`) is ever built, the receiver (the `gun` bone) is the sight-empty parent, and today the gun mesh is a sibling of the armature. The "correct" parent tomorrow is a bone. Option A is the **stepping stone** to that — and explicitly compatible with the rewrite.

### Where does the muzzle empty sit in the post-rig-change world?

The workflow's plan: `MuzzlePoint` becomes a `BoneAttachment3D` on the `gun` bone (GUN_ANIMATION_WORKFLOW §6.5). The new ADS empties should NOT follow suit — they should **stay parented to the gun mesh**, because the gun mesh rides the gun bone. Same effective motion, simpler hierarchy. **Naming convention for the future:** `muzzle_<gun>` and `sights_<gun>` empties all live under the gun mesh; only the `MuzzlePoint` gets a `BoneAttachment3D` upgrade when the rig change lands.

---

## 4 · THE `viewmodel_anim.gd` LISTENER PLAN — REACHABILITY

**The listener plan from GUN_ANIMATION_WORKFLOW §6 is unshipped.** `scripts/weapons/viewmodel_anim.gd` does not exist. The current call site in `weapon_holder.gd:823-825` uses a **local variable** for the AnimationPlayer and throws it away. The HUD subscribes to 4 of the 5 signals that the new listener would route (weapon_fired, weapon_reloaded, magazine_changed, ads_changed; the missing one is `weapon_jammed`).

### Does the ADS work block, parallel, or unblock the listener?

**Parallel, slightly cheaper.** The ADS work is purely **cosmetic geometry authoring in the .blend + the .tres**. It does not touch:
- the AnimationPlayer reference
- the .play() call site
- the signal emissions
- the loop-mode setting (which the listener §6.2 will fix)

The listener's job is **strictly bigger** than it would be without the ADS work, but in a clean way:

- **+5 nodes per viewmodel** (per the brief's claim: `sight_rear_<gun>` + `sight_front_<gun>` + `muzzle_<gun>` = 3, but the workflow also calls for `grip_<gun>` and other per-gun markers that GUN_ANIMATION_WORKFLOW §7 mentions; the brief says "5 empties per gun" which I read as 5 new). 15 guns × 5 empties = 75 new Node3Ds.
- These are **not bones** (Option A) — they have no animation channels, no skin, no IK. The listener's only job that touches them is `find_child("MuzzlePoint", true, false)`-style lookups, and a possible future path `MuzzlePoint → weapon_model.find_child("sight_rear", ...)` to set the iron-sight post as a child of the world-space point where the bore crosses zero. Even so, that's `find_child` with the right arg — not a refactor.
- The .tres save/load contract is unchanged. The listener's only .tres read is `current_weapon.reload_time` (line 845), `current_weapon.recoil_*` (line 790-793), and `current_weapon.viewmodel_fov` (line 854). The new `sight_*` empties do not enter this contract.

**One reachability flag:** if the future reload-anim work is going to be authored in a shared library (GUN_ANIMATION_WORKFLOW §2b's "8 family libraries" plan), then **the listener's job is hardest at the moment of authoring** because the .tres-driven hip/ADS transforms at the viewmodel root **collide** with whatever the shared library is doing to the rig. The viewmodel root is a sibling of the rig in the .tscn; both are children of the WeaponHolder. **The `weapon_model.position =` / `weapon_model.rotation_degrees =` writes (weapon_holder.gd:795-796) do not touch the rig.** So the rig is free to animate; the runtime transform is the model's, not the rig's. **No collision today.** This is the same as MuzzlePoint: it lives in the model subtree, and `weapon_model.position.lerp(...)` is applied to the model root, which is the parent of the gun mesh, which is the parent of MuzzlePoint. So MuzzlePoint rides the model transform. The same will be true of the new sight empties under Option A.

### Honest answer to Q2 / Q3

- **Q2 (viewmodel_anim.gd reachability):** The ADS work **does not block** the listener. The listener's blockers today are: cache the AnimationPlayer, set loop modes, fire `reload_cancelled`, MuzzlePoint → BoneAttachment3D. The ADS work adds 5 empties to find by name in the same `find_child` pattern. **Cost added: ~5 lines in the listener if it ever needs to know about them; zero lines if it doesn't.**
- **Q3 (75 new nodes harder?):** **Slightly. Each `find_child` is a recursive walk. The listener's existing pattern is `find_child("MuzzlePoint", true, false)` — same cost, just a different name.** No combinatorial explosion.

---

## 5 · THE RELOAD-ANIM WORK REACHABILITY

Per GUN_ANIMATION_WORKFLOW §2b: **8 family libraries**, not 1. The shared ArmsRig precondition is met (every GLB has identical skeleton, identical `rifle_idle`).

**The reload-anim work is also parallel to the ADS work, but the Order (§8) puts it after the rig change (Step 5).** Concretely:

| Step | Work | Blocks reload-anim? | Blocks ADS-sight work? |
|---|---|---|---|
| 0 | `remove_immutable_tracks = false` on every `*_fp.glb` | yes | no (no new bone tracks yet) |
| 1 | Add `weapon` + `mag` bones to ArmsRig | yes (rig is the precondition) | no (sights stay on the gun mesh) |
| 2 | `viewmodel_anim.gd` + cache + signals | yes | no |
| 3 | Author `jam` (30 frames) on M16 | yes (Step 1 must be done) | no |
| 4 | Author `reload` / `reload_empty` on M16 | yes | no |
| 5 | Roll the rig to other 12 | yes (each gun's blend needs weapon+mag bones added) | no |
| 6 | `TwoBoneIK3D` + `SpringBoneSimulator3D` | yes | no |
| 7 | `magwell` offset bone for ONE-clip-per-family | yes (only after step 4 proves the shape) | no |

**The ADS sight work is a Step 0-and-a-half: it lands in the .blend, in the .glb, in the .tres, but it does not advance the rig, the listener, the jam, or the reload.** It is the work the Summoner can do TODAY that produces immediate, visible gameplay delta — the player sees the iron sights snap into focus — without depending on any of the rig/listener/reload prerequisites.

### Q5 — runtime `.position =` writes vs future `.tscn` reload clips

`weapon_holder.gd:795-796` writes to `weapon_model.position` and `weapon_model.rotation_degrees` every frame. The viewmodel root is the .tscn's "Model" child (line 7 of every arms_viewmodel .tscn). The rig — ArmsRig, all bones, ArmsMesh — is **inside the GLB instanced under Model**. Therefore the rig is **NOT a child of `weapon_model`; it is a child of the GLB root, which is a child of `weapon_model`**. So a write to `weapon_model.position` translates the entire subtree (rig + gun + MuzzlePoint + sight empties) together.

A future `rifle_reload` clip on the rig **animates the rig in its local space**, which sits under the GLB root, which sits under `weapon_model`. The clip expresses motion **relative to the GLB root**, not relative to world. So:
- If a reload clip moves the left hand 5cm down, in clip-local space, the world-space motion is (5cm down) + `weapon_model.position.lerp(ads, t)`. The two compose, they don't collide.
- **This is the same composition the existing `rifle_idle` clip already does — and it already works.** Today, `rifle_idle` moves the arms in clip-local space, and `weapon_model.position` translates the whole assembly. The hands appear at the right world position. There is no collision.

**The honest caveat:** if a future reload clip **also** wants to move the model root (e.g. a reload that tilts the whole gun inboard), it will fight the runtime `.position =` write. The right architecture for that is a per-gun `reload_root_offset` Vector3 in the .tres (added to `target_pos` before the lerp), NOT a clip-track on the rig root. **This is a §7 follow-up, not an ADS-work blocker.**

---

## 6 · THE EXPORT PIPELINE — DOES IT CARRY `sight_rear_<gun>` THROUGH?

**Read the tool, line 74-79:**

```python
export_set = [arm, mesh, gun]
if muz: export_set.append(muz)
for o in export_set:
    o.select_set(True)
```

**The exporter selects exactly four (or three) objects: the armature, the arms mesh, the gun, and (if present) the muzzle empty.** Anything else in the .blend is **silently dropped at export**, regardless of whether it's a child of the gun or parented to the world.

**Therefore the answer to Q6 is: NO — not today.** The exporter has to be updated to carry `sight_rear_<gun>` and `sight_front_<gun>` through. The change is mechanical: replace the conditional `muz` append with a small loop:

```python
EXPORTED_EMPTIES = ("muzzle", "sight_rear", "sight_front")
for prefix in EXPORTED_EMPTIES:
    e = bpy.data.objects.get(f"{prefix}_{GUN}")
    if e: export_set.append(e)
```

**That is a 5-line patch and an exporter commit.** The blender-stager owns the patch; the animator's read of it is that it's the only change between today's GLB and tomorrow's. The M14 GLB today has MuzzlePoint only; the new M14 GLB will have MuzzlePoint + sight_rear_M14_Rifle + sight_front_M14_Rifle, same parenting (children of M14_Rifle), same exporter contract otherwise.

---

## 7 · THE EDITOR IS THE BENCH — CONFIRMATION

**Confirmed. The editor (`viewmodel_editor.gd:259-273`) and the game (`weapon_holder.gd:800-826`) run the same five-step pipeline:**

1. Load the .tres from `current_weapon.model_path`.
2. Instantiate as `weapon_model = scene.instantiate()`.
3. Parent to a `WeaponHolder` child of the camera.
4. `weapon_model.scale *= _lens_ratio(weapon_data)`.
5. `find_child("AnimationPlayer", true, false)` → `play("rifle_idle")`.

The editor's `weapon_holder` is `$Camera3D/WeaponHolder` (line 17). The game's `weapon_holder` is the WeaponHolder under the player camera. **Same name, same identity transform (the editor scene enforces this in its head comment), same camera FOV (75 hip / per-weapon ADS), same model scale.** The .tscn at the top of every arms_viewmodel file is identical structure, so the editor's "WYSIWYG contract" comment (line 265-268) is **literally true** for the eyes-on output: what you nudge in the editor is what the game renders, modulo the runtime `.position.lerp()` smoothing the editor skips.

**Two reasons the editor IS the bench, not a mock:**
- The `rifle_idle` clip is the same in the editor and the game (both `find_child` into the same GLB subtree).
- The `bore_dir` calibration the editor exposes (I/K/U/O) writes to the .tres — the game reads the same .tres at `_get_muzzle_position()` (line 862, `find_child("MuzzlePoint", true, false)`) and uses the muzzle origin with `weapon_data.bore_dir` indirectly. So the editor's "BORE @25m" diagnostic is the same math the game's hit-scan uses.

**One confirmation of a non-confirmation:** the editor's mode toggle (line 674-678) flips between hip and ADS preview by writing `edit_position` / `edit_rotation` from `current_weapon.hip_*` / `current_weapon.ads_*`. **It does NOT actually lerp the model between them** — it snaps. The game lerps at `ADS_SPEED = 10.0` (line 795-796). **This is the two-frame bug the briefing §1.2 names:** the editor and the game disagree on whether the transition is a snap or a lerp. **The ADS work does not fix this; the editor needs a `_process`-driven lerp using the same `ADS_SPEED` for symmetry.** This is a §1 secondary-bug fix, not in scope for today.

---

## 8 · BONE-EMPTIES vs WORLD-EMPTIES vs GUN-MESH-EMPTIES — THE FINAL WORD

Q4 asked whether the ADS work needs any of the existing two bones (`weapon`, `mag`) on `ArmsRig`, or needs more (e.g. a sight bone).

**Answer: no bones, no. Empties on the gun mesh.**

- The two existing bones are not yet in any GLB — the rig change is Step 1, not landed.
- The ADS work is purely cosmetic and the existing rifle_idle must survive untouched. Adding bones (Option B in §3) costs the "minimum rig change" decree and adds risk for zero gameplay benefit.
- The gun mesh is the right parent because the gun is a single welded mesh today, and when it becomes bone-skinned (Step 1), the empty rides the bone via the mesh.
- The 2nd empty in `MuzzlePoint → sight_rear` and `sight_front` does **not** need to be a `BoneAttachment3D` like MuzzlePoint's plan — it can stay a regular child of the gun mesh. The reason MuzzlePoint needs BoneAttachment3D is that it's the *origin of every fired bullet*, and a missed parent means the flash spawns in mid-air. The sight empties are pure read-points (the analytic-alignment tool uses them, not the firing path). If they detach during a reload — they won't, because the gun mesh rides the bone — no gameplay consequence.

**Confirmed: no rig change, no bone, no new skeleton. Option A throughout.**

---

## 9 · THE M16A1 + MOSIN LANDMINES (per §7b) — CURRENT VIEWMODEL STATE

The workflow names two specific landmines. Measured in the current viewmodels:

### M16A1 — "the gun literally cannot move today"

**Confirmed.** The m16a1_fp.glb has the M16A1_Rifle mesh at translation `(-0.04792, 0.25352, 0.07868)` with scale (1, 1, 1). **Zero animation channels target the M16A1_Rifle node or any child of it (including MuzzlePoint).** The "empty gun" is a real, current problem: any reload that wants to tilt the rifle inboard has no track to express it. The same is true for **all 11 arms viewmodels** — not just M16A1. M16A1 is the *easy* one (AluMag.001 is a one-material vertex-group pick), but the structural fact is the same for the M14, AK, RPD, Mosin, M60, PPSh, M70, Ithaca, M1911, RPG-2.

**Status: live, all 11 guns. Not the ADS work's bug to fix, but the ADS work doesn't unblock or block the fix.**

### Mosin — non-uniform scale (0.957, 1.022, 1.043)

**Confirmed in the live GLB.** The Mosin_Rifle_VC node carries scale `[0.9568722248077393, 1.042649507522583, 1.0219284296035767]`. `export_apply=True` (line 87 of export_viewmodel.py) bakes this into the vertex transforms at export time, so the .glb data is correct. **The landmine is: if anyone in the future opens the .blend and re-exports WITHOUT `apply_scale` first, the glTF skin breaks silently** — vertex positions are world-space, joint bind matrices are local-space, the two drift by exactly the per-axis scale. GUN_ANIMATION_WORKFLOW §7b warns this is a single-vertex-graph-corruption bug that's hard to see. The exporter handles it; the workflow needs a stager-side decree that says "apply scale at .blend open, before any edit."

### Other landmines named in §7b, checked against current viewmodels

- **M60 belt is 69 islands** — workflow says "defer." No animation work today. ✓
- **Colt .45 mag fused into grip frame** — workflow says "needs modelling." Not animation. ✓
- **Mosin, Ithaca: no removable mag** — stripper clips / shell-by-shell. Not animation. ✓
- **A `CHILD_OF` constraint with keyed 0→1 influence ALWAYS POPS** — this is a Blender constraint landmine, not a viewmodel landmine. Not relevant to the ADS work. ✓
- **IK and `COPY_ROTATION` do not survive glTF** — the existing export pipeline handles this by `export_bake_animation=True` (line 86). ✓
- **156-bone unused Rigify rig** — workflow notes a stale Rigify rig in the .blend. Not in any .glb. Not an ADS-work issue. ✓
- **Stale `handIK.L → COPY_TRANSFORMS → grip_L_M60_MG` constraint** — same, .blend-only. Not in any .glb. Not an ADS-work issue. ✓

### Where the workflow is wrong or imprecise

1. **"M14 has the markers"** (briefing §6, Chain A) — the M14 *blend* has them per the workflow; **the M14 *glb* does not** (verified: zero `sight*`-named nodes in m14_fp.glb). The exporter strips them at line 74-79. **The fix is in the exporter, not the .blend.** A 5-line patch.
2. **"M14 has the second-most work done (sight rebuild complete)"** — fine, that's .blend-side.
3. **"the gun is a static root sibling of ArmsRig"** — correct, confirmed. The gun is a sibling of the rig, not parented to a bone, with MuzzlePoint as its child.
4. **"A new empty parented to the gun's root should have no impact"** (Q8) — **confirmed correct, with the caveat that the exporter must be updated to include the new empty in `export_set`.** Today, the exporter would silently drop it.

---

## 10 · SPECIFIC BLOCKERS PER VIEWMODEL (the only ones the ADS work needs to know about)

| Gun | Today's ADS state | ADS-work blocker? |
|---|---|---|
| **M14** | `ads_position = (-0.25, 0.175, -0.02)`, `ads_rotation = (-6.6, -9.97, 2.79)` — **REAL, calibrated values.** Gun mesh has MuzzlePoint. | **No**. This is the reference gun. Markers in .blend; need exporter patch to land in .glb. |
| **M16A1** | `ads_position = (0, 0.05, 0.08)`, `ads_rotation = (4, 0, 0)` — placeholder. | No blocker. Replace placeholder with analytic-derived values. |
| **AK-47** | `ads_position = (0, 0.05, 0.08)`, **no `ads_rotation` key** — falls back to `Vector3.ZERO` per `weapon_data.gd:93` default. | No blocker. But the missing key means the existing editor save has to write BOTH position and rotation together on first edit, or the default-zero rotation will look "right" but be wrong. |
| **Mosin** | `ads_position = (0, 0.05, 0.08)`, no `ads_rotation` key. Non-uniform mesh scale in .glb (0.957, 1.022, 1.043). | No blocker for ADS itself. The non-uniform scale is a stager-side decree ("apply_scale before edit"), not an animation concern. |
| **M60** | placeholder. Belt is 69 islands (defer reload). | No blocker. |
| **RPD** | placeholder. Belt-fed. | No blocker. |
| **PPSh-41** | placeholder. Drum mag at island 4. | No blocker. |
| **M70** | placeholder, no `ads_rotation`. Stripper clip. | No blocker. |
| **Ithaca** | placeholder, has `ads_rotation = (4, 0, 0)`. Pump action, no removable mag. | No blocker. |
| **Colt .45 (m1911)** | placeholder, has `ads_rotation = (4, 0, 0)`. Mag fused into grip. | No blocker. **Note: this viewmodel .tscn is reused for both m1911 and colt45 — the .tres files are the only differentiator.** |
| **RPG-2** | placeholder, has `ads_rotation = (4, 0, 0)`. Launcher. | No blocker. |
| **M26 grenade** | `hip_position == ads_position == (0.2, -0.15, -0.3)`, both rotations ZERO. Uses gltf, not arms GLB — no `rifle_idle`, no rig, no AnimationPlayer. | **No `rifle_idle` ever**. Different model type. ADS work is a no-op here. |
| **Medkit** | No `model_path` in any data file (no `medkit.tres` exists). Pure CSG boxes. | Not a gun. Not in scope. |

---

## 11 · ANSWERS TO THE EIGHT SPECIFIC QUESTIONS

1. **Does the ADS geometry authoring break the existing `rifle_idle`?** **No** — provided the new empties are parented to the gun mesh, not to a bone. The 156 channels all target bone nodes 0–53, none of them the gun mesh or its children. Verified across m14/m16/ak GLBs.
2. **Is the `viewmodel_anim.gd` plan reachable from the ADS work?** **Parallel.** The ADS work does not block the listener (which is unshipped) and the listener does not block the ADS work. The only shared concern is `MuzzlePoint` parenting, which is already in both plans.
3. **Are 75 new nodes harder for the listener?** **Slightly, but linearly.** Each new empty is a `find_child` lookup. The listener's hardest part is the rig-change plumbing, not the empty count.
4. **Does the ADS work need any of the existing `weapon` / `mag` bones? Need more bones (sight bone)?** **No to both.** The gun is a welded mesh today; when the rig change lands, the gun mesh rides the `weapon` bone, and the sight empties ride the mesh. No new bone is needed.
5. **Does the runtime `hip_position` / `ads_position` write conflict with a future `rifle_reload` clip?** **No, if the reload clip targets the rig** (which is what the workflow §2b plans). The model-root transform composes with the rig's local transform. The conflict only arises if a future reload wants to move the model root itself, in which case the right architecture is a `reload_root_offset` in the .tres, not a clip-track.
6. **Does the blend→GLB pipeline carry the new empties?** **No, not today.** The exporter's `export_set` is hard-coded to `[arm, mesh, gun, muz]`. **5-line patch needed** in `tools/export_viewmodel.py`. This is the blender-stager's task; the animator flags it as a precondition.
7. **Is the editor the bench (not a mock)?** **Confirmed.** The editor and the game run the identical 5-step pipeline: load, instantiate, parent, scale, play. The .tscn structure is identical. The bore_dir calibration writes to the .tres the game reads. **One open bug: the editor's mode toggle SNAPS, the game LERPs at ADS_SPEED = 10.0. This is the two-frame bug.** Fix is editor-side: add a `_process` lerp using the same `ADS_SPEED` constant.
8. **Empty parented to the gun root (not a bone) has no impact on `rifle_idle`.** **Confirmed correct.** Channel count, target node indices, and per-channel TRS all check out across m14/m16/ak GLBs. The only impact is **the exporter must be updated to include the new empty in `export_set`**, which it does not do today.

---

## 12 · WHAT IS SACRIFICED

Per War Room law, naming the tradeoffs:

1. **We will not author any reload clips today.** The ADS work is purely cosmetic. The existing `rifle_idle` must survive untouched; the rig change (Step 1) is a separate, unstarted work stream. **This sacrifices the "all FP work done by Friday" wish** in favor of "the player sees iron sights by Friday" — i.e. we choose visible-deliverable over structural-completeness.
2. **We will not change the exporter more than 5 lines.** A surgical patch: `EXPORTED_EMPTIES = ("muzzle", "sight_rear", "sight_front")` and a loop to append them. **Sacrificed:** a more general "export all empties parented to the gun" rule. That's a future refactor; for today, the explicit list is auditable.
3. **The `MuzzlePoint` → `BoneAttachment3D` upgrade (GUN_ANIMATION_WORKFLOW §6.5) is deferred** to the rig change. The ADS work keeps `MuzzlePoint` and the new `sight_rear_<gun>` / `sight_front_<gun>` empties as plain Node3D children of the gun mesh. **Sacrificed:** the bullet-origin stability during reload. For ADS-only gameplay (no reload today), this is invisible. The MuzzlePoint's parent changeover is a Step-1 deliverable, not a Day-1 deliverable.
4. **The editor's snap-vs-lerp two-frame bug is named, not fixed.** The ADS work proceeds; the editor fix is in the secondary workstream (Day 2 of the brief, after primary closes). **Sacrificed:** certainty that the editor preview matches the game. The discrepancy is a snap of 1/ADS_SPEED = 0.1s on toggle, which is fine for the alignment bench but ugly in the editor preview.
5. **The "M14 has markers" claim is corrected.** The .blend has them; the .glb does not. The fix is the exporter patch (item 2 above). **Sacrificed:** the briefing's confidence that the M14 is "the reference" — it is the reference for the .blend authoring workflow, but the .glb has zero sight empties today. The exporter is the gatekeeper, not the .blend.
6. **The Mosin non-uniform scale landmine is documented, not pre-empted.** The exporter's `export_apply=True` handles it; the workflow's warning applies to manual re-exports without `apply_scale` first. **Sacrificed:** a stager-side "always apply scale on .blend open" macro. The decree is: blender-stager runs `apply_scale` at the top of every per-gun ADS pass, before measuring.
7. **No new bone is added.** The "minimum rig change is two bones" decree holds. The ADS work is a 0-bone, 3-empty-per-gun additive change. **Sacrificed:** the option of using a `sights` bone for future IK targeting. The right answer there is a future `TwoBoneIK3D` on the dead `handIK.L/R` bones (GUN_ANIMATION_WORKFLOW §4), which the workflow already plans as Step 6 — the sights follow the gun mesh which follows the gun bone, which is what the IK system would target anyway.
8. **The `viewmodel_anim.gd` listener is not started today.** The ADS work does not depend on it; the listener does not depend on the ADS work. **Sacrificed:** the temptation to bundle "make animations work" with "make ADS work" — they are separate problems with separate blockers, and the brief's primary is the ADS work.

---

## 13 · BEAD PROPOSALS (for the Arbiter)

- **RECONgame-anim-1 (P1, blocker for ADS Day 1):** Patch `tools/export_viewmodel.py` to carry `sight_rear_<gun>` and `sight_front_<gun>` empties through to the GLB. 5 lines. **Owner: blender-stager.** Closes a 13-gun-per-day throughput ceiling; without it, every per-gun ADS pass is a wasted re-export.
- **RECONgame-anim-2 (P2, parallel):** Document the `MuzzlePoint` parent decision — stay-on-gun-mesh today, upgrade-to-BoneAttachment3D on Step 1 of the workflow. Prevents future-me from re-parenting the MuzzlePoint prematurely and breaking the §7 "minimum rig change" decree.
- **RECONgame-anim-3 (P2, advisory):** `medkit` has no .tres and no model_path — it's a CSG-only viewmodel. Not in any `weapons/*.tres`. **The data/weapons/medkit.tres file does not exist** (verified). Either author the .tres or remove `medkit_viewmodel.tscn` from the project. **Owner: ux-designer or general cleanup.**

---

## 14 · FINAL VERDICT (for the Arbiter)

**The ADS work is a pure-cosmetic, gun-mesh-relative, 0-bone, 3-empty-per-gun change.** The existing `rifle_idle` is safe across all 11 arms viewmodels. The exporter needs a 5-line patch to carry the new empties through; without that patch, every per-gun ADS pass is wasted. The `viewmodel_anim.gd` listener is parallel work, not blocked, not blocking. The reload-anim work is downstream of the rig change (Step 1), which is downstream of `remove_immutable_tracks=false` (Step 0) — and **none of that is the ADS work.**

**The Summoner's bottleneck is exactly what he said: the Blender work and the .tres write.** The animation side of it is clean. The exporter is the only seam.

**The two claims in the briefing that the animator corrects:**
- "M14 has the markers" → **M14 .blend has them; M14 .glb does not.** The exporter is the gate.
- "Switching hipfire ↔ ADS repositions the gun while correcting for only ONE of the two transforms" → **The editor SNAPS; the game LERPs.** Both are correct, neither is a "two-frame" issue; it's a snap-vs-lerp discrepancy in the editor's `_on_mode_toggle` (line 674-678), which doesn't lerp.

Both fixes are in the editor and the exporter. Neither is a rig change.
