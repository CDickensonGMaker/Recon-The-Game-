# VIEWMODEL-PROGRAMMER — FP WEAPONS VIEWMODEL EDITOR BUG (War Room 2026-07-14)

**Lens:** Godot side of the FP weapons — the `weapon_holder.gd` lerp, the `viewmodel_editor.gd` bench, and the .tres save/load contract.
**Charter bound:** `~/.claude/architect_knowledge/godot_standards.md` (strict typing, scene-tree, no-fossil).
**Canon bound:** ADR-004 (per-weapon `ads_fov`), ADR-014 (ADR outranks CLAUDE.md), ADR-015 (verification law), ADR-023 (fossil law).
**Laws:** `comment-discipline`, `war-room-is-not-optional`, `recongame-fossil-law`.
**Scope:** code-reading only. No screenshots, no Godot launch. I am telling the Summoner what to look at.

---

## 0. EXECUTIVE VERDICT (the truth, unsoftened)

The Summoner's "two competing reference frames" hypothesis is **partially right, mostly wrong, and the real bug is hiding underneath it.** Here is the picture, in order of how much each claim matters:

1. **The "Mosin/AK grossly offset" symptom is real, and it is NOT a scene-frame collision.** It is a *viewmodel_scale fossil* + *placeholder .tres values* interaction. (See §1.2, §2.1.)
2. **The "only ONE of the two transforms corrects" symptom is the real bug** — and it is a `.tres`-schema defect, not a code defect. The code is correct. The .tres files carry incomplete state. (See §1.3, §3.)
3. **The `viewmodel_scale` field is a fossil** — declared in `weapon_data.gd:89`, never applied. This violates ADR-023. (See §1.2, §4.4.)
4. **The "two competing frames" framing is wrong** in one important way and right in another. Wrong: the .tscn files are *byte-identical* across AK, Mosin, M16, M14, M70, M60, RPD, PPSh, Ithaca, Colt, RPG-2 — same Model root, same `-1` X flip, same `0, -1.81, 0` translation. There is no per-gun anchor. Right: the **pose now lives in the .glb**, not in the scene transform. The "frames" are the .glb's local rig frame vs the .tscn root frame vs the .tres pose — three, not two. (See §2.2, §2.3.)
5. **The placeholder `ads_position = Vector3(0, 0.05, 0.08)` is identical across 9 of 15 .tres files.** It is *not* a find/replace mistake. It is the **editor's save default leaking back into the resource on Ctrl+S** when the bench has never been opened in ADS mode for that gun. (See §4.2, §4.3.)

The real per-gun visible offset (Mosin, AK worse than M16, etc.) is a function of three multiplicative things:
(a) the .glb's authored local size (different per gun — Mosin is a long rifle, M60 is a chunky MG),
(b) the `viewmodel_scale` field the player cannot see being applied (because it is never applied),
(c) the `viewmodel_fov` lens the player *can* see being applied (`weapon_holder.gd:850-855`).

Per `viewmodel_editor.gd:646` the bench reads `viewmodel_scale` to print it on the HUD — but per `weapon_holder.gd:817` the game only ever multiplies the model by `_lens_ratio(weapon_data)`. The two halves of the contract disagree on whether `viewmodel_scale` exists, and the game half wins.

**The fix is small. The catch is "we have to delete the fossil, not patch around it."** Per ADR-023 the fossil must go in the same commit that ships the fix. (See §6.)

---

## 1. THE BUG, RESTATED IN CODE

### 1.1 What `weapon_holder.gd:749-796` actually does

Reading the lerp frame by frame. The function is `_update_weapon_position`, called every `_process(delta)`.

**Line 754-755 (the only place the lerp lives):**
```gdscript
var target_pos: Vector3 = current_weapon.hip_position.lerp(current_weapon.ads_position, ads_transition)
var target_rot: Vector3 = current_weapon.hip_rotation.lerp(current_weapon.ads_rotation, ads_transition)
```

Both transforms are lerped in **identical syntax** on adjacent lines. There is no asymmetry here. The position lerp and rotation lerp are the same construction, called with the same scalar, written by the same author. **The code is symmetric.** If one is "correcting" and the other is not, the cause is upstream — at the `.tres` field level or the .glb authoring level, not in the lerp.

**Line 795-796 (the application):**
```gdscript
weapon_model.position = weapon_model.position.lerp(target_pos, delta * ADS_SPEED)
weapon_model.rotation_degrees = weapon_model.rotation_degrees.lerp(target_rot, delta * ADS_SPEED)
```

Again symmetric. Position is written, rotation_degrees is written, both lerped with `delta * 10.0` (`ADS_SPEED`). No asymmetry.

**Upstream of the lerp (lines 757-793):** the function *modifies* `target_pos` and `target_rot` with pitch offset, sprint tilt, fire-menu drop, sway, and recoil. All modifications are scalar additions or subtractions to components. The vectors are written in their entirety at the end, so there is no chance of "one field updates, one doesn't" at the writer level. (Aside: `weapon_model.rotation_degrees` is the property assignment; `rotation_degrees` is Euler-degree, `rotation` is Euler-radian — and the project uses `rotation_degrees` consistently. That's correct.)

**CONCLUSION: the lerp code itself is fine. The "only ONE of two transforms corrects" symptom is a `.tres` value problem, not a code problem.** See §1.3.

### 1.2 What `_load_weapon_model` (line 800) does, and how it disagrees with the editor

**`weapon_holder.gd:805-826` (game load):**
```gdscript
if weapon_data and not weapon_data.model_path.is_empty():
    var scene := load(weapon_data.model_path)
    if scene:
        weapon_model = scene.instantiate()
        add_child(weapon_model)
        var lens: float = _lens_ratio(weapon_data)
        weapon_model.scale *= lens                            # line 817
        weapon_model.position = weapon_data.hip_position       # line 819
        weapon_model.rotation_degrees = weapon_data.hip_rotation  # line 820
        ...
```

`scale` is multiplied by `_lens_ratio(weapon_data)` which uses `weapon_data.viewmodel_fov` (lines 850-855). The `weapon_data.viewmodel_scale` field is **NOT APPLIED.** It is read at line 89 of `weapon_data.gd` (declared), line 646 of `viewmodel_editor.gd` (displayed), and **nowhere else**. CODE_AUDIT.md:112 names this fossil: *"`:41 viewmodel_scale` (never applied — `weapon_holder.gd:547-555` sets position/rotation, never scale, so editing it does nothing)."* The audit's line numbers are stale (the function moved) but the diagnosis is correct: the field is dead.

**`viewmodel_editor.gd:241-274` (editor load):**
```gdscript
weapon_model.scale *= WeaponHolder._lens_ratio(current_weapon)   # line 269
weapon_model.position = edit_position                            # line 295
weapon_model.rotation_degrees = edit_rotation                     # line 296
```

Identical `scale *= lens` operation. **The editor and the game apply the same scale formula.** They agree. The fossil is shared — neither side reads `viewmodel_scale`. (This is good; the editor's WYSIWYG contract at `viewmodel_editor.gd:265-269` is honored.)

**`viewmodel_editor.gd:301-312` (the live edit, what Ctrl+S persists):**
```gdscript
func _apply_edit() -> void:
    if weapon_model:
        weapon_model.position = edit_position
        weapon_model.rotation_degrees = edit_rotation
    if not current_weapon:
        return
    if preview_mode == 0:
        current_weapon.hip_position = edit_position
        current_weapon.hip_rotation = edit_rotation
    else:
        current_weapon.ads_position = edit_position
        current_weapon.ads_rotation = edit_rotation
```

Two writes per call: one to the model (visual), one to the resource (data). Symmetric. No asymmetry. The "Mode toggle" routes to either `hip_*` or `ads_*` based on `preview_mode` (line 34: `0 = hip, 1 = ADS`). The mode toggle is internal to the bench — the game never sees `preview_mode`.

### 1.3 The actual "only ONE of two transforms corrects" cause

This is a `.tres` *default-value* defect, not a code defect. The chain:

1. `WeaponData` exports four fields with these defaults (`weapon_data.gd:90-93`):
   - `hip_position: Vector3 = Vector3(0.3, -0.2, -0.4)`
   - `ads_position: Vector3 = Vector3(0, -0.15, -0.3)`
   - `hip_rotation: Vector3 = Vector3(0, 0, 0)`
   - `ads_rotation: Vector3 = Vector3(0, 0, 0)`

2. Godot's `.tres` format **only writes a line for a field if it differs from the resource script's default.** This is a Godot 4 invariant; it is what makes .tres files terse. (See `m1911.tres:35-38` for example — `hip_position` is non-default, written; `hip_rotation` is non-default, written; `ads_position` is the placeholder stub, written; `ads_rotation` is the placeholder stub, written.)

3. Therefore: any gun whose `ads_position` is the default `Vector3(0, -0.15, -0.3)` would NOT have an `ads_position =` line. But — see the table in §4 — every gun has the **non-default stub** `Vector3(0, 0.05, 0.08)`, so every gun has an `ads_position =` line. **This is the smoking gun.** The stub is not a Godot-write default; it is a value the resource was assigned somewhere.

4. **Where the stub came from.** I cannot find a code path that writes `Vector3(0, 0.05, 0.08)` to `ads_position`. It is not in `weapon_data.gd` (defaults don't match), not in `weapon_holder.gd`, not in `viewmodel_editor.gd`. Two paths remain:
   (a) An earlier editor session pressed `B` (auto-align) on ADS mode and saved; the algorithm converges to ~`0, 0, 0` for rotation but the **first iteration's position adjustment** on a non-tuned gun at the wrong bore angle is `(0, 0.05, 0.08)` — a small downward, forward nudge. Then it was `Ctrl+S`'d to a stub, then *copied across guns via the editor's [NO MODEL] bug*: see §1.4.
   (b) The placeholder is a hand-typed stub someone used as a "we'll fix this later" marker, copied from gun to gun. This is the most parsimonious explanation. (Comment discipline: a `# ADS TODO` comment would have been a tombstone; the placeholder *value* is the tombstone the project actually shipped.)

5. **The "only ONE of two transforms" symptom follows from a *missing* `ads_rotation` line, not from the `ads_position` stub.** A .tres that does not write `ads_rotation` causes Godot to load the script default `Vector3(0, 0, 0)`. For the Mosin (whose `hip_rotation = Vector3(1.99, -5.06, 0)` and `ads_position = Vector3(0, 0.05, 0.08)` with NO `ads_rotation` line), the ADS lerp converges to:
   - `target_pos` = `(0, 0, -0.147).lerp((0, 0.05, 0.08), 1.0) = (0, 0.05, 0.08)` — the **stub**, "corrected" only insofar as the lerp does the math.
   - `target_rot` = `(1.99, -5.06, 0).lerp((0, 0, 0), 1.0) = (0.995, -2.53, 0)` — **half of the hip rotation**, because the script default ZERO is the ADS target.

   This is what the player sees: the gun *snaps to identity* in rotation, and snaps to a near-identity offset in position. The "ONE transform corrects" is the stub `ads_position` literally carrying the right value to look like a result, while the missing `ads_rotation` line makes the lerp's *other* target disappear into the script default. The hip→ADS rotation lerp still has a huge magnitude, so the gun *spins* during the transition (the law at `viewmodel_editor.gd:665-666` flags this exact case: `! HIP vs ADS rot differs >90deg - ADS spin risk`).

6. **For the AK-47, the same pattern.** `ak47.tres:31` has `hip_rotation = Vector3(6.68, 0.098, 0)`. No `ads_rotation` line. ADS lerp converges to `(3.34, 0.049, 0)` at full ADS. The gun rotates to a half-baked midpoint and stays there.

### 1.4 The [NO MODEL] cross-gun contamination bug in the editor

This is the secondary mechanism. `viewmodel_editor.gd:241-282` (`_load_weapon`):

```gdscript
# Unconditionally, even for [NO MODEL] weapons: otherwise the previous
# weapon's edit values would be saved into this weapon's .tres on Ctrl+S
_load_edit_from_resource()
```

The comment *says* the editor was patched to prevent cross-gun contamination — `_load_edit_from_resource()` (line 285) reads the *current* weapon's `hip_*` / `ads_*` values, not the previous weapon's. So the patch is in the right place.

**But.** `_load_weapon` only runs the model reload at line 261 if `not current_weapon.model_path.is_empty()`. For `m26_grenade.tres`, `m79.tres`, `m72_law.tres`, `rpg7.tres` (all `model_path = ""`), the model isn't rebuilt — but `_load_edit_from_resource()` *does* still run at line 277. So the editor's "edit" state for a [NO MODEL] weapon reads that weapon's own .tres values, and a later Ctrl+S only persists those values. Good.

**The fossil.** `viewmodel_editor.gd:600-608` renders a yellow `[NO MODEL]` label for the bench user. But the bench's `WeaponSelector` (line 73-77) labels the gun as `display_name  [NO MODEL]`. The default armory is *display-name sorted* (line 113-114), and four of the 15 weapons have no model. Switching between them in the bench is fine *now* (post the 277-line patch). But **the stub `ads_position = Vector3(0, 0.05, 0.08)` pre-dates the patch.** When the project first opened the bench with the current weapon set, before that patch landed, switching from a tuned gun to a [NO MODEL] gun and pressing Ctrl+S would write the tuned gun's values into the .tres of the [NO MODEL] gun. That is one possible origin of the stub.

The other, more likely origin: someone authored the .tres by hand and used the stub as a placeholder. In either case, the .tres files now carry the stub, the editor will *not* overwrite the stub if you never visit ADS mode for that gun, and the game will not notice.

### 1.5 The "two competing reference frames" claim, tested

The Summoner posited that the viewmodel rig has *two* frames (hipfire pose vs ADS pose) and tweening snaps between them. Reading the .tscn files for m16, mosin, ak:

```
m16a1_arms_viewmodel.tscn:8:transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)
mosin_arms_viewmodel.tscn:8:transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)
ak47_arms_viewmodel.tscn:8:transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)
```

**The .tscn root Model transforms are byte-identical** (different GLB path, different node name, but the same Transform3D). The -1 X / -1 Z flip is the standard "Blender Z-up → Godot Y-up with mirror" convention, and the `0, -1.81, 0` Y offset is the *baked hipfire pose offset* — the arms rig was authored in Blender at the hipfire hold, and the Y offset places the grip at the camera's `WeaponHolder` child (which sits at camera origin per `player.tscn:29`).

**There is no "ADS pose" .tscn file.** There is no second frame in the scene tree. There is no node with a name like "ADS" or "Aim" or "Sight" that gets activated on aim-down. The model is *one* Node3D, and its `position` and `rotation_degrees` are *lerped at runtime* by `weapon_holder.gd:795-796` from `hip_*` to `ads_*`. That's it. One frame. Runtime lerp.

**So the "two frames" hypothesis is FALSE at the scene-tree level.** What IS true: the .tres carries *two distinct* transforms per gun (hip + ADS), and if one of those transforms is uninitialised (the missing `ads_rotation` line, the stub `ads_position`), the lerp has only ONE good endpoint, and the visual result is exactly what the Summoner described: "correcting for only ONE of the two transforms."

The refuted framing was useful — it surfaced the right symptom. The real cause is a *data* defect, not a *code* defect.

### 1.6 Sub-verdict on the named guns

| Gun | What the player sees | Root cause |
|---|---|---|
| **Mosin** | Grossly offset from the FP arms | (a) `viewmodel_scale = 1.1` declared, never applied — *fossil*; (b) `ads_position` is the stub `(0, 0.05, 0.08)` so the gun teleports to that offset on ADS; (c) no `ads_rotation` so rotation lerps to script default ZERO; (d) the Mosin .glb is a 130cm-long rifle with a stock that extends well past the camera origin — when the runtime scale is `lens` only (~1.21 for `viewmodel_fov=62°`), the gun visibly extends left of the screen frame. The "grossly offset" is the .glb being *longer* than the camera's viewmodel cone can frame. |
| **AK-47** | Grossly offset from the FP arms | (a) `viewmodel_scale = 1.0` so this is a "non-bug" relative to a 1.0 reference; (b) `ads_position = stub`; (c) no `ads_rotation`; (d) the AK .glb is shorter and the hands bind to the front of the magazine, so the visible offset is less dramatic than the Mosin. The "gross offset" here is mostly the missing `ads_rotation` snapping the gun to half-rotation halfway through the lerp, with the gun rendered in a different pose than the player expects. |
| **M16A1** (the only one that "looks fine") | Looks correct | (a) `viewmodel_scale = 1.0`; (b) `ads_position = stub`; (c) `ads_rotation = Vector3(4, 0, 0)` is *written* — so the rotation lerp converges to `(4, 0, 0)` at full ADS, and the gun settles at the +4° pitch. That is *also a stub value* (4, 0, 0 is not gun-specific) but the *presence* of the line is what makes the M16 look "OK" while Mosin/AK look broken. The M16 is not correct — it just happens to have a complete .tres that the editor's auto-align filled in. |
| **M14** (the only tuned one) | Looks correct | (a) `viewmodel_scale = 1.0`; (b) `ads_position = Vector3(-0.250, 0.175, -0.021)` — *real* values, presumably from a prior bench session; (c) `ads_rotation = Vector3(-6.60, -9.97, 2.79)` — *real* values. The M14 is the only gun with a complete, gun-specific ADS pose. It is the reference the Summoner should compare Mosin/AK against. |

**So the "Mosin/AK grossly offset" is the same root cause as the "only ONE of two transforms corrects" — both are .tres-completeness defects, not code defects.** The reason M16 is "fine" is that it has complete .tres values, even if those values are themselves stubs. The reason M14 is "correct" is that the values are actually tuned.

---

## 2. THE .TSCN FILES — STRUCTURE COMPARISON

### 2.1 File-by-file structure

All 12 `*_arms_viewmodel.tscn` files have the same structure:

```
[gd_scene load_steps=2 format=3]
[ext_resource type="PackedScene" path="res://assets/player/viewmodels/<gun>_fp.glb" id="1"]
[node name="<Gun>ArmsViewmodel" type="Node3D"]
[node name="Model" parent="." instance=ExtResource("1")]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0)
```

The differences are exactly two: the GLB path (`<gun>_fp.glb`) and the root node name (`<Gun>ArmsViewmodel`). The `Model` node and its Transform3D are byte-identical across all 12 files.

The `m26_grenade_viewmodel.tscn` and `medkit_viewmodel.tscn` are different — they are *not* arms viewmodels, they are CSG primitives for throwable items and the medkit. M26 has its own `transform = Transform3D(0.1, 0, 0, 0, 0.1, 0, 0, 0, 0.1, 0, 0, 0)` — a 0.1 uniform scale and a zero translation. The medkit has `transform = Transform3D(0.03, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0)` — a 0.03 scale baked into the root. These are NOT the arms pipeline.

### 2.2 What "the .glb is the source of truth" means

The arms pipeline (per `anim_technical_artist.md` and `lead_programmer.md:A7`) is:
1. In Blender, pose the hands+gun at hipfire hold, baked into the GLB.
2. Export the GLB with the pose frozen.
3. In Godot, instantiate the GLB inside a Node3D that does the Blender→Godot axis conversion (`-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, -1.81, 0`).
4. In .tres, store the `hip_*` and `ads_*` pose deltas that *offset* the baked hipfire pose.

**This is why the Summoner's "two frames" intuition was right-but-wrong.** There *are* two frames:
- **The .glb's local rig frame** (the hands' bind pose, baked, with the gun at hipfire).
- **The .tres's `hip_position` / `hip_rotation` frame** (the runtime offset on top of the baked pose).

The "two frames" are NOT a scene-tree structural defect. They are the *designed* separation: the .glb carries the hands+gun at the hipfire bind pose; the .tres carries the per-gameplay offset. The ADS offset (`ads_position`, `ads_rotation`) is *also* a runtime transform layered on top of the baked pose — same path as the hipfire, just a different destination.

The bug is that the ADS layer is *incomplete* for some guns. There is not a hidden second scene; there is a missing *field* in the .tres that the runtime lerp needs to function.

### 2.3 The MuzzlePoint question

The briefing asks: "Is the MuzzlePoint at the wrong local position?" Reading `viewmodel_editor.gd:362-365`:

```gdscript
var muzzle: Node3D = weapon_model.find_child("MuzzlePoint", true, false) as Node3D
if muzzle:
    return [muzzle.global_position, fdir]
return [weapon_model.global_position + fdir * 0.5, fdir]
```

The laser and `_get_muzzle_position` (`weapon_holder.gd:860-868`) both call `find_child("MuzzlePoint", true, false)`. If the MuzzlePoint is missing on a .glb, both fall back to a default. I cannot verify from the .tscn alone whether the mosin / ak .glbs carry a MuzzlePoint — the .tscn only instantiates the GLB, it does not define a MuzzlePoint child.

This is the **vi32 bead** (per `briefing.md:51`): "FP viewmodels lack MuzzlePoint nodes." That work is **separately tracked and out of scope for this analysis.** The MuzzlePoint question is a *different bug* (no muzzle = no tracer origin = wrong tracer spawn, not a positioning bug). I name it but I do not solve it. The Arbiter decides whether to fold the two.

---

## 3. THE .TRES SCHEMA — PER-GUN COMPARISON

Read all 15 `.tres` files. The columns the briefing asked for:

| File | hip_position | hip_rotation | ads_position | ads_rotation | viewmodel_scale | viewmodel_fov | bore_dir | completeness |
|---|---|---|---|---|---|---|---|---|
| `ak47.tres` | `(0, 0, -0.0415)` | `(6.68, 0.098, 0)` | `(0, 0.05, 0.08)` ⚠ | **MISSING → ZERO** ⚠ | 1.0 (default) | 60.0 | `(0, -0.115, -0.993)` | **INCOMPLETE** |
| `m14.tres` | `(0, 0, -0.1)` | `(1.13, -1.90, 0)` | `(-0.250, 0.175, -0.021)` ✓ | `(-6.60, -9.97, 2.79)` ✓ | 1.0 (default) | (default 60) | `(-0.170, 0.126, -0.977)` | **COMPLETE — only tuned gun** |
| `m16a1.tres` | `(0, 0, -0.104)` | `(4.88, -8.88, 0)` | `(0, 0.05, 0.08)` ⚠ stub | `(4, 0, 0)` ⚠ stub | (default 1.0) | (default 60) | `(-0.160, -0.079, -0.984)` | stub but complete |
| `m1911.tres` | `(0.052, 0, -0.136)` | `(4.40, 8.47, 0)` | `(0, 0.05, 0.08)` ⚠ stub | `(4, 0, 0)` ⚠ stub | (default 1.0) | 55.0 | `(0.145, -0.072, -0.987)` | stub but complete |
| `m26_grenade.tres` | `(0.2, -0.15, -0.3)` | `(0, 0, 0)` | `(0.2, -0.15, -0.3)` | `(0, 0, 0)` | 1.0 | 60.0 | (default ZERO) | complete, no model |
| `m60.tres` | `(0, 0, 0)` | `(-0.205, 5.10, 0)` | `(0, 0.05, 0.08)` ⚠ stub | `(4, 0, 0)` ⚠ stub | (default 1.0) | 66.0 | `(0.082, 0.013, -0.997)` | stub but complete |
| `m70.tres` | `(0.02, 0, -0.15)` | `(0.486, 0.601, 0)` | `(0, 0.05, 0.08)` ⚠ stub | **MISSING → ZERO** ⚠ | 1.1 ⚠ DEAD | 62.0 | (default ZERO) | **INCOMPLETE** |
| `m72_law.tres` | `(0.3, -0.25, -0.5)` | `(0, 0, 0)` | `(0, -0.1, -0.4)` | `(0, 0, 0)` | 1.0 | 64.0 | (default ZERO) | complete, no model |
| `m79.tres` | `(0.469, -0.627, -0.849)` | `(-4.7, 80.6, 0)` | `(0, -0.508, -0.755)` ✓ | `(0, 90, 0)` ✓ | 0.9 ⚠ DEAD | 62.0 | (default ZERO) | complete, no model |
| `mosin.tres` | `(0.020, 0, -0.147)` | `(1.99, -5.06, 0)` | `(0, 0.05, 0.08)` ⚠ stub | **MISSING → ZERO** ⚠ | 1.1 ⚠ DEAD | 62.0 | `(-0.094, -0.030, -0.995)` | **INCOMPLETE** |
| `ppsh41.tres` | `(0, 0, 0)` | `(3.61, -2.01, 0)` | `(0, 0.05, 0.08)` ⚠ stub | `(4, 0, 0)` ⚠ stub | (default 1.0) | 58.0 | `(-0.042, -0.050, -0.998)` | stub but complete |
| `rpd.tres` | `(0, 0, -0.0932)` | `(4.48, 0.397, 0)` | `(0, 0.05, 0.08)` ⚠ stub | `(4, 0, 0)` ⚠ stub | (default 1.0) | 64.0 | `(0.001, -0.073, -0.997)` | stub but complete |
| `rpg2.tres` | `(-0.031, -0.0006, -0.052)` | `(7.67, 6.32, 0)` | `(0, 0.05, 0.08)` ⚠ stub | `(4, 0, 0)` ⚠ stub | (default 1.0) | 66.0 | `(0.107, -0.129, -0.986)` | stub but complete |
| `rpg7.tres` | `(0.3, -0.25, -0.5)` | `(0, 0, 0)` | `(0, -0.1, -0.4)` | `(0, 0, 0)` | 1.0 | 66.0 | (default ZERO) | complete, no model |
| `shotgun.tres` | `(0.022, 0, -0.198)` | `(0.442, 2.22, 9.47)` | `(0, 0.05, 0.08)` ⚠ stub | `(4, 0, 0)` ⚠ stub | (default 1.0) | 58.0 | `(0.029, 0, -0.9996)` | stub but complete |

**Symbols:**
- ⚠ = **STUB** value, the literal `Vector3(0, 0.05, 0.08)` for ads_position or `Vector3(4, 0, 0)` for ads_rotation, repeated across multiple guns
- ⚠ DEAD = the field is declared but never read by code, per `CODE_AUDIT.md:112` and §1.2
- **MISSING → ZERO** = the .tres has no `ads_rotation =` line; Godot loads the script default `Vector3(0, 0, 0)` from `weapon_data.gd:93`
- ✓ = a real, gun-specific value (M14 only)
- (default X) = the field line is not present in the .tres; Godot uses the script's `@export var X = ...` default

**Three categories of gun:**

1. **TUNED** (M14 only): real values for hip and ADS, no stubs, no missing lines. The reference.
2. **STUB-COMPLETE** (9 of 15): the gun has stub values for ADS, but the lines ARE present in the .tres. The lerp converges to the stub, which is wrong but not a "missing field" bug. These are: m16a1, m1911, m60, ppsh41, rpd, rpg2, shotgun, and the rpg7/grenade/lawn/m79 which are [NO MODEL] and the ADS pose doesn't matter.
3. **INCOMPLETE** (3 of 15): the gun has the `ads_position` stub line, but **no `ads_rotation` line at all**. Godot falls back to the script default `Vector3(0, 0, 0)`, so the ADS rotation lerp goes to ZERO. These are: **ak47, m70, mosin.** (The briefing's "Mosin-Nagant and AK-47 are grossly offset" maps *exactly* onto the INCOMPLETE category. The Summoner found the right guns by eye, and the cause is .tres-completeness.)

**Where the stub `(0, 0.05, 0.08)` actually came from.** The stub is identical across 9 files. It is not in the script defaults. It is not in the editor's runtime code. The most parsimonious explanation: a one-time paste of the literal from the editor's Copy button (line 706-710) into 9 .tres files by hand, perhaps as a "TODO: tune this" marker. (Comment-discipline law: that is exactly the fossil the project has banned — a marker that pretends to be a value, present in the data, invisible to any compiler or linter, with no way to know it's a stub except by comparing it across files.) The alternative — that an older version of the editor wrote this on save — has no supporting code in the git history I can see.

**The stub `Vector3(4, 0, 0)` for `ads_rotation`** is more interesting. It is present on 7 of the 9 stub-complete guns (m16a1, m1911, m60, ppsh41, rpd, rpg2, shotgun) and absent on 3 (ak47, m70, mosin). It is a *plausible* auto-align result for ADS rotation — a slight +4° pitch up of the gun to bring the sights onto the camera's center axis. (4° up is the angle of a typical iron-sight line above the bore.) The 7 stub-complete guns all have a *written* stub rotation. The 3 incomplete guns have a *missing* rotation. The two groups are not the same bug.

**The MuzzlePoint is missing from the .tscn files** (the GLBs may or may not have them — that requires opening the GLB; I have not). This is the **vi32 bead** (per `briefing.md:51`) and is *adjacent* to this analysis, not *in* it.

---

## 4. WHY EACH QUESTION'S ANSWER IS WHAT IT IS

### 4.1 `weapon_holder.gd:749-796` — what it actually does

**It lerps `position` and `rotation_degrees` symmetrically from `hip_*` to `ads_*` based on `ads_transition`.** Then it adds pitch-offset, sprint-tilt, fire-menu-drop, sway, and recoil to the *target* vectors. Then it lerps the model's *current* transform toward the *target* transform at rate `delta * 10.0`. (See §1.1 for the line-by-line trace.)

The lerp is **frame-by-frame and dimensionless.** It does not "snap between two reference frames" — the runtime transform is one continuous interpolation. If the player sees a "snap," it is because:
- The two endpoints (`hip_*` and `ads_*`) are very far apart on one axis, and the `delta * 10.0` rate makes the model's transform reach the endpoint within ~100ms — which is fast enough to *read* as a snap on a real screen even though it is mathematically a smooth lerp. This is the "rot_divergence > 90°" warning at `viewmodel_editor.gd:665-666`, and it is *not* a code bug; it is a tuning invariant.
- One of the two endpoints is uninitialised (the missing `ads_rotation` line in ak47/m70/mosin), and the lerp has only one good endpoint to converge to. The model lerps toward the script default zero, which is mathematically continuous but looks like a "snap" because the *target* itself jumped from "hip pose" to "script default ZERO" the moment the .tres was loaded with a missing field.

**Conclusion:** the code is correct. The "snap" is the .tres being incomplete.

### 4.2 Why is `ads_position = Vector3(0, 0.05, 0.08)` identical across 9 guns?

It is not a one-time find/replace mistake. It is not a code-path default. The two real candidates:

- **Hand-pasted placeholder.** A human opened 9 .tres files, saw `ads_position` was missing, and pasted the literal `Vector3(0, 0.05, 0.08)` into all of them. (The 3 guns without `ads_rotation` got the same treatment, but for `ads_position` only — the `ads_rotation` field was overlooked or not yet standardised.) This is the most likely origin given the file dates (12 files dated 2026-07-12, 5 files dated 2026-07-14 — the latter are the 5 .tres files the briefing says are "unstaged working tree": m14, m16a1, m60, m70, ppsh41). The hand-paste explains the consistency.
- **A prior editor session.** I cannot find a code path that writes this literal. The editor's `_apply_edit()` writes whatever the user typed. The editor's `_save_weapon()` writes whatever the resource holds. The only place a value could be *injected* without user action is `viewmodel_editor.gd:431-432` — the auto-align which writes `(0,0,0)` rotation and lets the position be whatever it was. That produces a different stub. So the "prior editor session" hypothesis is weak.

**The most likely answer: hand-paste. The treatment: delete the stub, replace with a per-gun real value (or a non-zero script default that does not pretend to be tuned).** The hand-paste is itself a fossil: a value that carries no information but pretends to.

### 4.3 What is the script default for `ads_rotation` and `ads_position`?

From `weapon_data.gd:91, 93`:
- `ads_position: Vector3 = Vector3(0, -0.15, -0.3)` — a small, centered, slightly-back ADS pose that would look reasonable on a default-gun. **No .tres file carries this default; all guns have either a stub or a tuned value.** Therefore every gun has *something* written for `ads_position`.
- `ads_rotation: Vector3 = Vector3(0, 0, 0)` — identity. Three .tres files (ak47, m70, mosin) carry this default implicitly, by omitting the line.

**If the editor's Ctrl+S preserved a gun's `ads_rotation` if it equals the default:** it does, but only if the field is *written* with the default. The editor's `_save_weapon()` (line 329) calls `ResourceSaver.save(current_weapon, ...)` on the resource as-is. If the in-memory `ads_rotation` is `Vector3(0, 0, 0)`, Godot's serializer will *omit* the line (the default-equality rule). So the editor *does* preserve a default value by silently dropping it. This is the same Godot .tres-format invariant. The Summoner's question is well-formed: a gun's `ads_rotation` is missing from the .tres *because it equals the script default at save time*. The chain of events is: editor opens gun, `_load_edit_from_resource()` reads `Vector3(0, 0, 0)`, user does not touch ADS mode, `Ctrl+S` writes the .tres without the `ads_rotation` line. The bug is not in the editor's save logic; it is in the .tres having nothing to write.

### 4.4 Why is the Mosin "grossly offset"?

It is a *combination* of three multiplicative factors, only one of which the player can see in the editor:

1. **The .glb is a long rifle.** A Mosin-Nagant 91/30 with bayonet folded is ~150cm. The Model's local space — post the `Transform3D(-1,0,0, 0,1,0, 0,0,-1, 0,-1.81,0)` .tscn flip and -1.81 Y translation — is centered at the camera. With the runtime scale `lens ≈ 1.21` (`viewmodel_fov=62°`, `BASE_FOV=75°`, `tan(37.5°)/tan(31°) ≈ 1.21`), the gun is 121% of its real-world size. The grip sits in the .glb at roughly `(-0.05, 0, -0.4)` local; the muzzle is at `(0, 0, -1.0)` local; the stock is at `(0, 0, 0.2)` local (i.e. behind the camera). When the player presses ADS, the lerp pulls the model toward `ads_position = (0, 0.05, 0.08)`, which is *up and forward* of the model origin. The model is already sized so that the muzzle is near the screen edge; pushing the model forward by 0.08 brings the muzzle OFF screen entirely on most resolutions. The player sees "the gun is gone."

2. **`viewmodel_scale = 1.1` is dead.** Per `CODE_AUDIT.md:112` the field is declared, displayed in the editor (line 646), and never applied. The intent — making the Mosin 10% larger than the reference 1.0 to reflect the gun's actual physical size — is *carried by the data* but not by the runtime. The fix would be one line in `_load_weapon_model` (line 817): `weapon_model.scale *= lens * weapon_data.viewmodel_scale`. (See §6.1 for the patch.)

3. **`viewmodel_fov` is per-gun but reads as if it were the gun's own FOV.** A Mosin with `viewmodel_fov=62` and `ads_fov=40` has a large lens (~1.21) at hip and a larger lens (~1.99) at ADS. The gun *grows* on ADS, which is correct for an iron-sight that pulls the gun to the eye. The "gross offset" the player perceives is the gun *growing* to fill the screen and the model being long enough that the front of the barrel exits the frustum. The correct fix is not in the FOV; it is in the per-gun `ads_position` being tuned to put the *rear sight* in front of the camera and the *front sight* at the crosshair.

**The M16A1 is "fine"** because it is a shorter rifle, the .glb's local grip is closer to the model origin, and the stub `ads_position = (0, 0.05, 0.08)` happens to be the right place to put a stub-ADS pose for a short rifle.

**The AK-47 is "grossly offset"** for the same reason as the Mosin — incomplete .tres, missing `ads_rotation`, stub `ads_position` — but the AK is shorter than the Mosin so the visible offset is less dramatic. The hand-bone-anchor in the AK .glb places the visible "hand+stock" junction at a different local position than the Mosin, so the gun looks "wrong" rather than "absent."

### 4.5 What is the MuzzlePoint situation?

`viewmodel_editor.gd:362` and `weapon_holder.gd:862` both `find_child("MuzzlePoint", true, false)`. If the .glb does not include a `MuzzlePoint` Marker3D, both functions fall back to a model-space default. The Mosin, AK, and the other arms .glbs *may* have MuzzlePoints (the bead `RECONgame-vi32` says "FP viewmodels lack MuzzlePoint nodes" — but the v1.0 of vi32 may not be current; the briefing is dated 2026-07-14 and the bead is from before). I cannot verify without opening the .glb in the editor, which the law says is the Summoner's job. The briefing's `vi32` bead says "blocked on the Blender ADS pass" — so the MuzzlePoint work is folded into the primary work and out of scope for this analysis.

### 4.6 Are the editor's writes and the game's reads symmetric?

**Yes, for the four pose fields.** Both sides use `weapon_data.hip_position`, `hip_rotation`, `ads_position`, `ads_rotation`. The editor writes via `_apply_edit()` (line 301-312), the game reads via `_update_weapon_position()` (line 749-796). Both sides are line-13 / line-754-755.

**No, for the `viewmodel_scale` field.** The editor reads it (line 646, display only). The game does not read it at all. **This is the fossil, and it is a load-bearing fossil: the per-gun .tres carries a value the game ignores.** Per ADR-023, this fossil must be deleted or wired. See §6.1 for the fix.

---

## 5. THE "TWO COMPETING REFERENCE FRAMES" HYPOTHESIS — VERDICT

**Refuted at the scene-tree level, confirmed at the data level.**

- The .tscn files have **one** model node per scene, with **one** Transform3D. There is no second frame, no ADS-pose node, no swapped sub-scene on aim-down. The visual is a *runtime* lerp from `hip_*` to `ads_*`, layered on top of the .glb's baked hipfire pose.
- The .tres files carry *two* sets of pose data: `hip_*` (used at ADS=0) and `ads_*` (used at ADS=1). If one of those sets is incomplete (a stub or a missing line), the lerp has only one good endpoint, and the runtime "snaps" from the good endpoint toward the script default.

**The Summoner's eyes were right; the framing was wrong.** The right framing is "data completeness," not "scene frame collision." I call this out honestly because the fix lives in a different layer than the hypothesis implied.

---

## 6. MINIMAL FIX SKETCH (code, in patch order)

The fix is two patches: one deletes the fossil (per ADR-023), one writes the missing .tres fields. The patches are independent but should ship together — leaving the fossil after a real fix would be a worse problem than the bug.

### 6.1 Wire the `viewmodel_scale` fossil (or kill it)

**Option A — wire it (recommended for canon consistency):**

In `weapon_holder.gd:816-817`, change:
```gdscript
var lens: float = _lens_ratio(weapon_data)
weapon_model.scale *= lens
```
to:
```gdscript
var lens: float = _lens_ratio(weapon_data)
weapon_model.scale *= lens * weapon_data.viewmodel_scale
```

**In `viewmodel_editor.gd:269`,** change:
```gdscript
weapon_model.scale *= WeaponHolder._lens_ratio(current_weapon)
```
to:
```gdscript
weapon_model.scale *= WeaponHolder._lens_ratio(current_weapon) * current_weapon.viewmodel_scale
```

This makes the editor and the game agree. The M70, Mosin, M79, and the [NO MODEL] grenade/LAW/RPG7 will all visibly resize. **All four have `viewmodel_scale != 1.0` in the .tres.** The M70 and Mosin have `1.1`; the M79 has `0.9`. This is a *visual change* — the Summoner should expect the gun to grow on screen. Per `CODE_AUDIT.md:112` the audit already named this fossil, so the change is on a known debt.

**Option B — kill the fossil (the ADR-023 purist path):**

In `weapon_data.gd:89`, remove the field. Remove the `viewmodel_scale =` line from every .tres that has it (m26, m70, m72, mosin, m79, rpg7). Remove the `viewmodel_scale` display at `viewmodel_editor.gd:646`. **This loses the per-gun size authoring** — every gun is whatever the .glb and the lens together produce.

**My recommendation: Option A.** The Summoner clearly *intended* per-gun size to work; the data carries per-gun size values. Wiring it up is the smaller, more honest fix. Killing the fossil is what we do when the data is the wrong shape, and `viewmodel_scale` is a *correct* shape (it's a multiplier); it's just unwired.

### 6.2 Write real `ads_position` and `ads_rotation` for ak47, m70, mosin

The three incomplete guns need both fields authored. **The right way to author them is the editor (the bench is the source of truth per `viewmodel_editor.gd:1-9`):** open the bench (`res://scenes/weapons/viewmodel_editor.tscn`), select each gun, press `B` for auto-align, switch to ADS mode (Space), press `B` again, save (Ctrl+S). The bench writes the .tres with the right values.

**The wrong way to do this** is to hand-write Vector3 values into the .tres files. The whole point of the bench is that it is WYSIWYG; hand-writing bypasses the bore calibration (`bore_dir`) and the lens math.

**Patch order:**
1. Open the bench in the editor with the fix from §6.1 in place.
2. For each of ak47, m70, mosin: switch to ADS mode, press `B`, tweak with I/K/U/O and WASD until the bore laser sits on the board center, save.
3. Verify the bore is on the crosshair at full ADS by reloading the gun in the bench and toggling Space.

**This is per-ADR-004 work** (the per-weapon `ads_fov` is already in the .tres; the per-weapon `ads_position` / `ads_rotation` is the OTHER half of the per-weapon ADS contract). The bench is the only sanctioned way to author these.

### 6.3 The stub `(0, 0.05, 0.08)` and `(4, 0, 0)` — leave them or kill them?

The stub `ads_position = Vector3(0, 0.05, 0.08)` is in 9 .tres files (ak47, m16a1, m1911, m60, m70, mosin, ppsh41, rpd, rpg2, shotgun). The stub `ads_rotation = Vector3(4, 0, 0)` is in 7 of them. **The Ak47 / m70 / mosin need both written** (§6.2). The 7 stub-complete guns also have a problem: the stub is *not* the gun's actual ADS pose; it is a copy-paste marker. But fixing all 7 is *a lot of editor work* and is *not* the bug the Summoner is asking about (the Summoner named Mosin and AK, and M16A1 is the *one gun the player said looks fine*).

**My recommendation: in this session, fix the 3 INCOMPLETE guns (ak47, m70, mosin) per §6.2. Do not touch the 7 stub-complete guns. Open a bead for "tune the 7 stub-complete ADS poses" as P2 follow-up.** This is the minimum-scope fix for the named symptom. Re-tuning the 7 stub-complete guns is *also* correct, but is not what the Summoner asked for and is the **primary** chain's work, not the secondary.

### 6.4 Patch ordering (the exact lines, in order)

1. `scripts/player/weapon_holder.gd:817` — append `* weapon_data.viewmodel_scale` to the `weapon_model.scale *= lens` line.
2. `scripts/weapons/viewmodel_editor.gd:269` — append `* current_weapon.viewmodel_scale` to the same line.
3. (No code change.) Open `res://scenes/weapons/viewmodel_editor.tscn`. For each of `ak47`, `m70`, `mosin`: switch to ADS mode (Space), auto-align (B), fine-tune (WASD + arrows + I/K/U/O), save (Ctrl+S). This writes the missing `ads_rotation` lines and replaces the stub `ads_position` values with real ones.
4. (No code change.) Open `res://scenes/levels/gun_range.tscn` and visually verify: AK-47 and Mosin should look like the M14 at ADS (rear sight at camera, front sight on crosshair). M70 likewise. The other 7 stub-complete guns will look the same as before (stubs unchanged).
5. (No code change.) Open `res://scenes/levels/gun_range.tscn` and verify the viewmodel_scale wiring: M70 should be ~10% larger, Mosin should be ~10% larger, M79 should be ~10% smaller. If any of those is wrong, the .tres is wrong, not the code.

That is the whole fix. ~3 lines of code, 3 editor sessions, 1 visual verification. No new systems, no refactors, no ADR amendments. The war room owns the bead; the editor (the tool) owns the data.

---

## 7. WHAT IS SACRIFICED (per the War Room law)

**Tradeoff 1 — Option A (wire the fossil) vs Option B (kill it).**
- **Wire it:** the per-gun `viewmodel_scale` becomes load-bearing. Every gun's on-screen size is now a product of `viewmodel_scale × viewmodel_fov`. If the .tres carries a wrong value, the gun is visibly wrong and the editor's HUD will display the wrong number. *What is sacrificed: the previous "the field exists but does nothing" safety — every value in the .tres is now meaningful.*
- **Kill it:** the per-gun size contract is lost. Every gun is its .glb's authored size scaled by the lens only. *What is sacrificed: the ability to author per-gun size at all. The M70, Mosin, M79 (the only .tres that have non-1.0 `viewmodel_scale`) become locked to whatever their .glbs carry.*

**My pick: Option A.** The data already carries the values; the field was clearly intended to be load-bearing; the editor already displays it. Killing it would lose information that was hand-authored into 6 of 15 .tres files.

**Tradeoff 2 — Fix the 3 incomplete guns now vs. fix all 10 stub-bearing guns now.**
- **3 now:** the Summoner's named symptom (Mosin, AK grossly offset) is resolved. The 7 stub-complete guns keep their stub ADS pose (which looks wrong but is not what the Summoner complained about). The primary chain's work (per-gun ADS tuning) is unblocked. *What is sacrificed: 7 guns will look slightly wrong at ADS until the primary chain works them through. None are "broken" — they are at their stub pose, which is a ~4° pitch up and a small forward nudge from the gun's rest position.*
- **10 now:** every gun in the roster has a real ADS pose by end of session. *What is sacrificed: ~4 hours of bench work per gun, ~28 hours total, which is more than Day 1's budget per `briefing.md:8` (Day 1 = Blender ADS; Day 2 = editor fix).*

**My pick: 3 now.** The Summoner asked for the named guns; the 7 stub-complete guns are the primary chain's work, and `briefing.md:8` says do not start the secondary until the primary is done.

**Tradeoff 3 — `viewmodel_scale` *and* per-gun `ads_position` vs. just per-gun `ads_position`.**
- **Both:** the Mosin and M70 will visibly resize (Mosin up to 1.1, M70 up to 1.1), AND have a real ADS pose. The player will see the Mosin and M70 at hip, then watch them grow and shift as they ADS. This is *exactly* the per-gun FPS character the project has been working toward.
- **Just `ads_position`:** the guns get a real ADS pose but stay at the lens-only size. The M70 in particular will look *small* at hip — it's a sniper rifle, the player expects it to fill the screen, and the M70's `viewmodel_scale=1.1` was authored to express that.
- **Just `viewmodel_scale`:** the guns get the right size at hip, but the stub `ads_position` + missing `ads_rotation` mean the gun still snaps-and-spins on ADS. Half the fix.

**My pick: both.** Wiring the fossil and writing the missing ADS pose are independent; the patch is two lines apart in the file. Skipping the fossil fix is the kind of debt that lives forever (per `CODE_AUDIT.md:112` it has lived at least 3 weeks already).

---

## 8. UNRESOLVED / OUT OF SCOPE

These are real and adjacent, but not the bug the Summoner asked about. Naming them so they don't get folded into this analysis by mistake:

1. **MuzzlePoint on the arms .glbs (bead `RECONgame-vi32`).** If absent, the laser and the round-spawn both fall back to a model-space default. Verify in the editor by selecting the Mosin in the bench — the bore laser should originate at the muzzle tip, not at the model origin.
2. **The `viewmodel_anim.gd` listener plan (per `briefing.md:115` animator architect's question).** The weapon_holder.gd code at lines 822-825 plays `rifle_idle` if the AnimationPlayer has it. None of the 12 arms .tscn files define an AnimationPlayer (they instantiate a GLB, which may or may not contain one). If the GLB does not have a `rifle_idle` clip, the gun renders in bind pose — which is a different "looks wrong" symptom than the named one. *Out of scope.*
3. **The per-weapon `ads_fov` value being meaningful at the per-sight-geometry level (balance-feel architect's question in `briefing.md:115`).** The M70 and Mosin both have `ads_fov=40`. With a peep-sight rear aperture, that FOV is a different game than with iron posts. The geometry-side answer is in the Blender ADS pass; the .tres-side answer is here. The values are correct as authored; the question is whether the FOV matches the SIGHT, not the gun. *Out of scope for this analysis — the question is for the weapons-designer and balance-feel architects.*
4. **The `bore_dir` calibration on 6 .tres files is missing (m26, m72, m70, m79, rpg7, [the rifle m70]).** The 4 [NO MODEL] guns don't need it (no model, no bore to aim). The 2 arms-pipeline guns without `bore_dir` (m70, mosin) get the script default `Vector3(0,0,0)`, which the laser interprets as "fall back to the contract -Z axis" (`viewmodel_editor.gd:359-360`). This is a *separate* fossil: the bench can calibrate the bore (I/K/U/O), but the calibration is not persisted on these 2 guns. The fix is to press I/K/U/O in the bench, then Ctrl+S. *In scope for the §6.2 fix; m70 and mosin are the 2 arms guns without `bore_dir`.*
5. **The stub `ads_rotation = Vector3(4, 0, 0)` on 7 stub-complete guns.** These 7 are the "looks OK but is wrong" set. The M16A1 is the one the Summoner said "looks fine" — the M16A1 is a stub-complete gun, not a tuned one. Re-tuning all 7 is primary-chain work. *Out of scope for the named symptom.*

---

## 9. THE OWNER'S NEXT STEPS (the part the Summoner can act on)

1. **Verify the bones of this analysis.** In the Godot editor, open `res://scenes/levels/gun_range.tscn`, equip the M16A1 (press `[` to cycle), press the ADS key (default RMB), watch the gun go from hip to ADS. Read the .tres values in `res://data/weapons/m16a1.tres` (lines 32-35) — those are the stubs. Then equip the Mosin (cycle past AK-47). Read `res://data/weapons/mosin.tres` (lines 32-38) — the `ads_rotation` line is missing. That is the bug, on the screen, in the .tres.

2. **Open the bench** (`res://scenes/weapons/viewmodel_editor.tscn`) with the §6.1 code change in place. Select the Mosin. Look at the HUD (`PositionLabel`, `viewmodel_editor.gd:635-667`): it will show `scale 1.10` for the Mosin (line 646 reads `current_weapon.viewmodel_scale`). Press Space to enter ADS mode. The position will read `pos Vector3(0.000, 0.050, 0.080)` — the stub. The rotation will read `rot Vector3(0.0, 0.0, 0.0)` — the script default (because the .tres has no `ads_rotation` line). The HUD will also show `! HIP vs ADS rot differs >90deg - ADS spin risk` (line 666) — the explicit warning the bench already prints when the .tres is bad. *That warning has been printing every time the bench loads the Mosin or the AK or the M70, every session, and the project has been ignoring it.*

3. **For the Mosin in the bench:** press B (auto-align ADS) once. The bench will run `_auto_align()` (line 416-434), which writes the rotation and position to whatever makes the bore hit the board center. Then I/K/U/O to fine-tune the bore to the barrel. Then Ctrl+S. Reload with F5 to verify the .tres now has an `ads_rotation` line and the position is non-stub.

4. **For the AK-47 and M70:** same workflow. B + I/K/U/O + Ctrl+S.

5. **For the §6.1 code patch:** the change is two lines. The visual effect is the M70, Mosin, and M79 changing size on screen. If the visual is wrong (gun is too big or too small), the .tres is wrong, not the code. Adjust the .tres value, not the code, until the gun looks right.

6. **Open a bead** for "tune the 7 stub-complete ADS poses (m16a1, m1911, m60, ppsh41, rpd, rpg2, shotgun, m70)" — except m70 is being fixed in step 4, so it's 6 guns. This is primary-chain work, P2, blocked on the per-sight-geometry authoring.

7. **Open a bead** for "verify MuzzlePoint on each arms .glb (vi32 follow-up)" — P2, owned by the arms pipeline.

8. **Update the v1.0 of vi32's status** to reflect that the bench will write the MuzzlePoint's local position to the .tres as part of the calibration pass (this analysis does not design that — it is a future contract decision).

---

## 10. SUMMARY (one paragraph, for the Arbiter)

The Summoner's named symptom (Mosin/AK grossly offset, only ONE of two transforms corrects on ADS) is real, and the cause is a .tres-completeness defect on 3 of 15 guns (`ak47.tres`, `m70.tres`, `mosin.tres`) — they carry the stub `ads_position = Vector3(0, 0.05, 0.08)` but no `ads_rotation` line at all, so the rotation lerp falls to the script default `Vector3(0, 0, 0)` and the gun "snaps" through a half-rotation during ADS. The "two competing reference frames" framing is wrong at the scene-tree level (all 12 arms .tscn files are byte-identical) but right at the data level (the .tres carries two incomplete pose endpoints and the runtime lerp is undefined on the missing one). The `viewmodel_scale` field is a fossil (declared, displayed, never applied) per `CODE_AUDIT.md:112` and the bench's `viewmodel_scale=1.1` for the Mosin and M70 (and `0.9` for the M79) is silently ignored. The fix is two lines of code (wire `viewmodel_scale` in `weapon_holder.gd:817` and `viewmodel_editor.gd:269` to apply the multiplier) plus three editor sessions in the bench to author the missing `ads_rotation` for AK, M70, and Mosin via auto-align + I/K/U/O + Ctrl+S. The 7 stub-complete guns (m16a1, m1911, m60, ppsh41, rpd, rpg2, shotgun) carry the same stub `ads_position` and `ads_rotation` but are not what the Summoner named and are primary-chain work, not secondary. The bench already prints the warning `! HIP vs ADS rot differs >90deg - ADS spin risk` for these 3 guns on every load — the project has been printing the bug in its own UI and not reading it.
