# Godot Specialist — FP Gun Animation & the Third-Person Backlog

**Architect:** godot-specialist · **Engine:** Godot 4.7 stable, GDScript strict typing
**Knowledge loaded:** `godot_4.7_features.md`, `godot_standards.md`, GodotPrompter `animation-system/`, `assets-pipeline/`

> **Method note:** every structural claim below was *measured*, not assumed. I parsed the glTF JSON
> chunk of `assets/models/viewmodels/m16_fp.glb` directly (node graph, skins, animation channel
> targets) and read the `.import` params. Where I say "the gun is a static root sibling," that is a
> fact from the file, not an inference from the exporter script.

---

## 0. THE ONE FACT THAT DECIDES EVERYTHING

I dumped the node graph of `m16_fp.glb`. Here is what is actually in there:

```
(gltf scene root)
├── M16A1_Rifle          mesh=0   ← ROOT SIBLING. No skin. No parent. NOT A BONE.
│   └── MuzzlePoint
└── ArmsRig              ← the armature
    ├── root  (bone)
    │   ├── shoulder.R → upper_arm.R → forearm.R → hand.R → palm.01-04.R → fingers
    │   ├── shoulder.L → ... (mirror)
    │   └── camera  (bone — the eye reference)
    ├── handIK.R, elbowIK.R, handIK.L, elbowIK.L   (bones, 4 IK controls)
    └── ArmsMesh         mesh=1  SKIN=0  (52 joints)

skins:      [ArmsRig — 52 joints]
animations: rifle_idle — 156 channels over 52 nodes … ALL of them bones.
            M16A1_Rifle has ZERO animation channels.
```

**The gun is a static prop. It is not skinned, not bone-parented, and not animated. The arms are
posed *around* it by `fp_grip.py`, which slides the gun until its `grip_R` empty meets a universal
hand pose.**

Consequence, stated plainly, because it is the whole ballgame:

> **If the Summoner authors a reload today and exports through `export_viewmodel.py`, the arms will
> perform a beautiful reload and the rifle will hang motionless in mid-air while the hands wave
> around it.** The gun cannot tilt, cannot come apart, and cannot be reloaded, because nothing in
> the export can move it.

Everything below follows from fixing that.

---

## 1. FP viewmodel: AnimationPlayer or AnimationTree?

**Verdict: AnimationTree, root = `AnimationNodeBlendTree`. Not a bare AnimationPlayer.**

AnimationPlayer is the clip *container* (AnimationTree requires one anyway), but it cannot give us
three things the spec demands:

| Requirement (from `ANIM_TIMING.md` / `VIEWMODEL_ANIM_SPEC.md`) | Bare AnimationPlayer | AnimationTree |
|---|---|---|
| Fire kick plays **over** idle without killing it | ✗ `play()` replaces | ✓ `OneShot` layer |
| Reload **cancellable** mid-clip with a blend, not a pop | ✗ hard cut | ✓ `travel()` xfade |
| Reload speed matched to per-weapon `reload_time` × Agility | manual `speed_scale` | ✓ `TimeScale` node |
| Auto-fire retrigger every 86 ms without restarting the body pose | ✗ | ✓ `OneShot` re-request |

### The graph

```
AnimationTree (active = true, anim_player = ../AnimationPlayer)
└── BlendTree (root)
    ├── StateMachine "Body"      idle · sprint · draw · reload · reload_empty · jam · bolt_cycle
    │     └── TimeScale on the reload/reload_empty branch
    ├── OneShot "Fire"           in = Body, shot = fire clip, filter = gun bones + hand/wrist
    └── Output
```

- **StateMachine** for the discrete, mutually-exclusive body actions. `travel("idle")` from *any*
  state is the cancel primitive — it blends out over the transition's `xfade_time` instead of
  popping. This is precisely the "reload must be cancellable" requirement, and it is free.
- **`AnimationNodeOneShot` for `fire`.** Set `filter_enabled = true` and filter to the gun-mechanism
  bones + wrist, so the kick and the bolt cycle overlay whatever the body is doing without wiping
  the reload's finger poses. Re-issuing `ONE_SHOT_REQUEST_FIRE` restarts it — which is *correct* for
  full-auto: a real bolt does not finish its settle before the next round is in the chamber.
- Keep `fadein_time ≈ 0.02`, `fadeout_time ≈ 0.08`.

### Additive vs discrete: the split that actually matters

Do **not** make the whole thing additive, and do **not** make the whole thing discrete. Split it by
*what owns the motion*:

| Motion | Owner | Why |
|---|---|---|
| Whole-gun recoil kick (back + up, settle) | **Code — already exists.** `weapon_holder._punch` | Framerate-independent, already scales by `recoil_vertical` (M60 shoves 6× an M1911), already tuned. Do not re-author it in Blender. |
| Idle sway / breath | **Code — already exists.** `_sway_time`, killed by hold-breath | `VIEWMODEL_ANIM_SPEC.md` already says "don't bake sway." Correct. |
| ADS transition | **Code — already exists.** `hip_position` → `ads_position` lerp | Spec already says a static aimed pose is enough. Correct. |
| **Bolt cycling, ejection port, charging handle, magazine, feed tray** | **Baked clip — DOES NOT EXIST YET** | These are *moving parts*. No procedural code can do them. This is the entire reason to open Blender. |

So the `fire` clip is short (8 frames) and contains **only the mechanism** — bolt back, bolt forward,
port flicks open. The gun's *kick* rides on top procedurally. That keeps the fire clip cheap, keeps
the existing well-tuned recoil, and means the fire clip is identical for every gun in a family.

### What 4.7 gives us over 4.3

- **Ping-pong playback in AnimationTree (4.7)** — a 3-second breathing idle authored one way, played
  ping-pong, becomes a seamless 6-second loop for free. Half the keyframes.
- **Named blend points (4.7)** — `add_blend_point(node, pos, -1, &"run")`, look up with
  `find_blend_point_by_name()`. Mostly matters for the *third-person* locomotion blend, not FP.
- **`Tween.tween_await()` (4.7)** — sequence the dropped-magazine despawn without callback chains.
- ⚠️ **4.7 gotcha:** `AnimationNodeBlendSpace1D/2D` replaced the `sync` bool with a `SyncMode` enum
  (`SYNC_MODE_NONE` is now the default and *freezes* inactive animations — the old `sync = true` is
  now `SYNC_MODE_INDEPENDENT`). Only bites if blend spaces are used; the FP graph above uses none, but
  the third-person locomotion blend will.

---

## 2. THE GUN COMES APART — bone, BoneAttachment3D, or keyframed mesh?

Three candidates. Only one survives contact with the shared-library goal.

### Option A — separate glTF node, keyframed TRS in the same AnimationPlayer
The magazine is its own object under `M16A1_Rifle`; the clip keys its position/rotation.

- **Imports fine.** Godot makes it a `MeshInstance3D` and the AnimationPlayer gets a track
  `Model/M16A1_Rifle/Magazine:position`.
- **And that track path is the murder weapon.** It contains the *gun's name*. The same clip played on
  the AK looks for `M16A1_Rifle/Magazine`, finds nothing, and the AK's magazine never moves. **This
  option is fundamentally incompatible with a shared animation library.** It also cannot put the mag
  in the hand without runtime reparenting.
- ❌ Rejected.

### Option B — `BoneAttachment3D`
A `BoneAttachment3D` node follows a bone; the mag mesh is its child.

- **`BoneAttachment3D` is a *follower*, not an animation target.** You cannot keyframe it in a shared
  library — you keyframe the *bone*, and the attachment tags along. So it does not solve the problem;
  it is downstream of the solution.
- It has exactly **one** correct job here, and it is important: **`MuzzlePoint`.** Today MuzzlePoint is
  a child of the static gun node. Once the gun moves, the muzzle must move with it, or the flash
  spawns in mid-air during a reload tilt. Make `MuzzlePoint` a `BoneAttachment3D` on the `gun` bone.
  `weapon_holder._get_muzzle_position()` does `find_child("MuzzlePoint")` → `global_position`, which
  keeps working *unchanged*. (The codebase already uses BoneAttachment3D in `radio_handset.gd` and
  `gore_dummy.gd`, so the pattern is known.)
- ✅ Use it — for the muzzle only.

### Option C — **the gun parts become BONES on the ArmsRig, skinned. ✅ THIS IS THE ANSWER.**

Add to `arms_rig.blend`:

```
root
└── gun            ← the receiver. Universal rest (fp_grip already normalizes every gun to the hand).
    ├── magwell    ← PER-GUN rest. NEVER animated. Absorbs "where is this gun's mag well."
    │   └── gun_mag        ← ANIMATED by the shared clip. Rest = identity relative to magwell.
    ├── boltway    ← PER-GUN rest. NEVER animated.
    │   └── gun_bolt       ← ANIMATED.
    └── chway      ← PER-GUN rest. NEVER animated.
        └── gun_ch         ← ANIMATED (charging handle).
```

Then vertex-weight each gun part **100% to its own bone** (receiver → `gun`, magazine → `gun_mag`,
bolt → `gun_bolt`). The gun mesh joins the skin. Rigid parts, rigidly bound — no deformation, just
transform inheritance.

**Why this wins on every axis:**

1. **Track paths become gun-agnostic.** Every track in every clip is now a *bone* track:
   `ArmsRig/Skeleton3D:gun_mag`. Identical on the M16, the AK, the M14. **This is the exact contract
   that makes `model_actor.gd`'s shared library work** — that file's comment says it outright: *"THE
   NAME IS A CONTRACT: both exporters keep the armature node named PSXRig, so every library track
   resolves as PSXRig/Skeleton3D:mixamorig_* on every character."* The arms rig is already named
   `ArmsRig` consistently by `export_viewmodel.py`. The contract is half-built already.
2. **The offset-bone trick (`magwell`/`boltway`) is what makes the shared clip *correct*, not just
   *resolvable*.** Bone tracks in glTF/Godot store the **full local transform relative to the parent
   bone**, not a delta from rest. So a naive shared clip that keys `gun_mag` directly under `gun`
   would drive the AK's magazine to the *M16's* magazine position — it would fly out of the side of
   the receiver. By inserting a never-animated `magwell` bone whose **rest transform is per-gun**, the
   shared clip's motion is expressed *relative to the well*: "drop 12 cm along the well's local −Y,
   then arc away." The M16's mag drops out of the M16's well; the AK's drops out of the AK's. **The
   per-gun geometry lives in the rest pose; the per-family motion lives in the clip.** This is the
   whole trick, and without it Q3 is impossible.
3. **The magazine never needs to be reparented.** This is the thing people get wrong. In third person
   a dropped mag must physically detach. In *first person*, the animator owns the mag bone's position
   outright — they simply keyframe it into the hand, into the pouch, and out of frame. No runtime
   reparenting, no `BoneAttachment3D` swap, **no code at all**. If a mag falling to the ground is
   wanted, spawn a throwaway `RigidBody3D` at the mag bone's transform and hide the bone — but that
   is polish, not plumbing.
4. It is how every FPS ships. Half-Life, CoD, Insurgency: the weapon is bones on the viewmodel rig.

### Import gotchas — name every one

| # | Gotcha | Detail |
|---|---|---|
| **1** | **`animation/remove_immutable_tracks=true`** (current setting on `m16_fp.glb.import`) | **The nastiest one.** A bone that does not move within a clip has its track *deleted at import*. So `idle` — which never touches `gun_bolt` — ends up with **no bolt track at all**. Play `reload_empty` (bolt locked back), then return to `idle`, and **the bolt stays locked back forever**, because nothing re-authors it. Same for a mag that ends the clip in the player's hand. **Fix: set `remove_immutable_tracks=false` on the viewmodel/library GLBs.** Costs a few KB. Non-negotiable once the gun has moving parts. |
| **2** | glTF carries **no loop flag** | Already a known scar — `model_actor._apply_loop_modes()` exists precisely for this. **The viewmodel has the same bug *right now*:** `weapon_holder._load_weapon_model()` calls `vm_anim.play("rifle_idle")` and never sets `loop_mode`. It is invisible today only because `rifle_idle` is a single static pose. The moment a breathing idle is authored, it plays once and **freezes on its last frame**. Flag `idle`/`sprint` as `LOOP_LINEAR` at load. |
| **3** | glTF carries **no animation markers and no method tracks** | Blender cannot export them. They would have to be stamped on in Godot post-import and would be **destroyed on every re-export**. **Do not use method tracks for the mag-out/mag-in beats.** Use a GDScript `const` dictionary of normalized event percentages — which is exactly what `ANIM_TIMING.md` already specifies (25% out, 60% in) and exactly the philosophy of `model_actor._LOOP_PREFIXES`. Survives every re-export, diffable, testable. |
| **4** | Bone names with `:` get rewritten | Godot's NodePath uses `:` as the property separator, so `mixamorig:Hips` → `mixamorig_Hips` on import (why the character library tracks read `mixamorig_*`). The arms rig uses **dots** (`f_index.01.R`, `palm.01.R`) — **dots are safe.** Name the new gun bones plainly: `gun`, `gun_mag`, `gun_bolt`, `gun_ch`. No colons, no spaces. |
| **5** | `export_viewmodel.py` **strips all pose-bone constraints** before export | This is *correct* and must be preserved. It means: author the reload with Child-Of constraints (mag → hand during the carry phase), **visual-key bake to an action**, then export. The exporter already runs `export_bake_animation=True`. The constraint workflow the Summoner already uses for staging survives unchanged. |
| **6** | `nodes/import_as_skeleton_bones=false` | Correct as-is. Leave it. We are creating real bones in Blender, not asking Godot to synthesize them from nodes. |
| **7** | `animation/fps=30` | Already correct, and it *exactly* matches `ANIM_TIMING.md`'s 30 fps authoring grid. Do not change it. |
| **8** | `meshes/generate_lods=true` on a viewmodel | Pointless work — a viewmodel is never distant. Minor; set false to shave import time. |

---

## 3. Can the shared anim-library trick apply to the FP ARMS + GUNS?

**Yes — at the *family* level, and only if §2 Option C is done first. This is the single highest-leverage decision in the whole matter.**

### Why it works

The character library works because every character shares one skeleton with identical bone names,
so a clip is pure bone TRS and plays on anyone. The arms already satisfy the *first* half of that:
**one `ArmsRig`, 52 bones, identical on every weapon export** — `export_viewmodel.py` re-uses the
same armature for all 13 viewmodels. That is the library precondition, already met, for free.

What breaks it today is that the *gun* is not on the rig. Put the gun on the rig (Option C), add the
`magwell`/`boltway` offset bones, and a clip becomes 100% bone tracks with gun-agnostic paths and
gun-agnostic *semantics*. Then:

> **Author the AR reload ONCE. The M16, the CAR-15, the XM177, and the M14 all get it. Fix a timing
> beat once, re-export one file, and every rifle in the family is fixed.**

This is the same order-of-magnitude win the character library already delivered (91 clips in one
file; a character re-export dropped from 11 minutes to seconds).

### What breaks — name the tradeoffs honestly

**a) It is per-FAMILY, not universal. The AK rocks; the M16 drops.**
An AK magazine rocks forward ~30° out of the well and hooks back in. An M16 mag drops straight and
inserts straight, then takes a bolt-release paddle jab. That is a *different motion*, not a different
offset — no rest-pose trick can reconcile them. So the library is per-archetype, which
`VIEWMODEL_ANIM_SPEC.md` **already anticipated**:

| Family | Members | Shared clip set |
|---|---|---|
| `ar` | M16A1, CAR-15, M14 | idle · fire · reload · reload_empty · draw · jam |
| `ak` | AK-47, SKS | + rock-in reload, charging-handle rack on empty |
| `bolt` | Mosin, M70 | + `bolt_cycle` (the weapon's identity) |
| `smg` | PPSh | drum swap |
| `lmg` | M60, RPD | feed-tray / belt, long reload |
| `pistol` | M1911 | slide, not bolt |
| `pump` | Ithaca | tube-fed, shell-by-shell |
| `launcher` | RPG-2 | front-load, over-shoulder |

~8 libraries instead of 13 weapons × 8 clips = 104 hand-authored clips. **Call it a 60–70% cut in
authoring work, not a 100% one.** That is still the difference between shipping FP animation and not.

**b) The support hand grabs air if the magwells differ too much.**
The clip bakes `hand.L` in FK. If the M14's magwell sits 4 cm forward of the M16's, the shared clip's
left hand reaches for the M16's well and misses. Three answers, in ascending cost:

1. **Normalize the art (recommended, ~free).** `fp_grip.py` *already* normalizes every gun to a
   universal right-hand trigger pose by sliding the gun to meet the hand. Extend that discipline:
   within a family, position each gun so its magwell lands within ~1 cm of the family reference. At
   PSX fidelity, with a 60° viewmodel lens magnifying the receiver and cropping the arms half out of
   frame, **1 cm of hand error is genuinely invisible.** This is the right first answer.
2. **`TwoBoneIK3D` (Godot 4.6+) — the escape hatch.** The rig **already has `handIK.L/R` and
   `elbowIK.L/R` bones** (I confirmed them in the skin — 4 of the 52 joints). They are currently dead
   weight: baked FK at export, solving nothing at runtime. Add a `TwoBoneIK3D` modifier per arm
   (`upper_arm → forearm → hand`, target = `handIK` bone, pole = `elbowIK` bone) and the IK bones go
   *live*. Now the shared clip drives the IK **target**, and per-gun correction becomes a rest-pose
   offset on the target rather than a re-authored clip. **This is the single most valuable unused
   engine feature for this problem.** Do not build it first — build it when a family's spread proves
   too wide for answer 1.
3. Author the outlier separately. Always available. Costs a day.

**c) `remove_immutable_tracks` becomes lethal, not annoying.** Covered in §2 gotcha 1. In a *merged*
library the danger compounds: a borrowed clip missing a bone's track leaves that bone wherever the
previous clip parked it. Turn the setting off.

**d) The library GLB must be rig-only.** Mirror `export_anim_library.py` exactly: strip every mesh,
material, and image; keep one armature; give every action an NLA strip so `ACTIONS`-mode export emits
them all. Then merge into the per-weapon AnimationPlayer at load with the same
merge-don't-replace logic as `model_actor._merge_shared_library()` (baked clips win, library fills
gaps) — and guard it with the same contract check (`if _inst.get_node_or_null("ArmsRig/Skeleton3D")
== null: return`), because a clip merged onto a rig whose paths don't resolve does not error, it
**silently freezes the pose**. That failure mode has already cost this project time once.

---

## 4. Interruptible fire synced to `fire_rate`; cancellable reload

### Fire

`fire_rate` 700 RPM → a shot every **86 ms**. The authored fire clip is 8 frames @ 30 fps = **267 ms**.
The clip is 3× longer than the interval. Two rules:

1. **Drive the animation from `_fire_shot()`, never from `_process()`.** `weapon_holder` deliberately
   accumulates a *negative* `fire_timer` remainder as sub-frame credit so average RPM is exact and
   framerate-independent (there is a long, correct comment about this). Any animation driven off a
   frame tick will drift against it. The shot event is the truth. `weapon_fired` already fires there.
2. **Time-scale the mechanism, retrigger the kick.**
   ```gdscript
   var delay: float = current_weapon.get_fire_delay()
   var scale: float = clampf(FIRE_CLIP_LEN / maxf(delay, 0.001), 1.0, 2.5)
   _tree.set("parameters/FireScale/scale", scale)
   _tree.set("parameters/Fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
   ```
   Re-issuing `ONE_SHOT_REQUEST_FIRE` while the OneShot is live **restarts it** — the previous kick is
   cut off mid-settle. That is not a compromise, it is the correct physical read for automatic fire.
   A bolt gun runs at 1.0×; an M16 at ~2.5× reads as a fast, sharp bolt. Never stretch a clip *below*
   1.0× to fill a slow cadence — you get a bolt moving in syrup.

`ONE_SHOT_REQUEST_ABORT` is the interrupt: a jam, a death, or a weapon switch mid-burst kills the kick
cleanly instead of leaving the bolt half-open.

### Reload

**Today there is no cancel path at all.** `reload_cancelled` is declared on line 12 of
`weapon_holder.gd` and — I grepped the whole `scripts/` tree — **is never emitted anywhere.** A dead
signal. `_handle_input()` blocks fire, ADS and sprint while `is_reloading`, and `_update_reload()`
only counts down. So the reload is currently an uninterruptible 2.5-second commitment. That is a
gameplay bug as much as an animation one, and it is *against Pillar 1*.

The engine half is trivial — `playback.travel("idle")` blends out over the transition's `xfade_time`.
The **design** half is the real work, and it hangs off one question: *when is the magazine committed?*

Answer, and it falls straight out of `ANIM_TIMING.md`'s normalized beats:

```gdscript
## Normalized beats within a reload clip (ANIM_TIMING.md). Percentages, not frames,
## so they survive any retime — including Agility scaling.
const RELOAD_MAG_OUT: float = 0.25   ## old mag leaves the well
const RELOAD_MAG_IN: float  = 0.60   ## fresh mag seats — THE POINT OF NO RETURN
```

- **Cancel before 60%** — you keep your partial mag, spare count unchanged. You slapped it back in.
- **Cancel after 60%** — the reload completes regardless. You cannot un-seat a magazine.

That single rule gives you a reload that is honest, readable, tactically meaningful (do I have time?),
and — crucially — it means `_finish_reload()`'s ammo bookkeeping fires at the *animation beat*, not at
`reload_timer <= 0`. It is also what makes an interrupted reload *feel* like a decision instead of a
bug. Sprint and weapon-switch should both route through `cancel_reload()`.

**Timing sync:** `_start_reload()` already scales `reload_timer` by Agility
(`clampf(1.0 - (ag - 100.0) * 0.003, 0.6, 1.1)`). Feed the ratio into the `TimeScale` node:
`scale = canonical_clip_len / reload_timer`, **clamped to 0.85–1.25** exactly as `ANIM_TIMING.md`
prescribes. Outside that window the motion visibly breaks — file a bead to author a fast variant
rather than stretching. Do **not** `seek()` the clip from `reload_progress`: it syncs perfectly but
gives you a hard pop on cancel, and it fights the AnimationTree.

---

## 5. Minimum engine work before a reload can play

Ordered. Nothing here is speculative; each item is a named gap in a file I read.

**BLOCKER — nothing works until this is done:**

**0. The gun must become bones (§2 Option C).** This is Blender work, not engine work, but it gates
everything. Until the gun is skinned to `ArmsRig`, no reload can play, because the gun physically
cannot move. Add `gun`, `magwell`→`gun_mag`, `boltway`→`gun_bolt`, `chway`→`gun_ch` to
`arms_rig.blend`; weight the gun parts; update `export_viewmodel.py` to include the gun in the skin
rather than as a selected static object; set `remove_immutable_tracks=false` on the import.

**Engine side, in `weapon_holder.gd` — five concrete changes:**

1. **Cache the AnimationPlayer.** `_load_weapon_model()` (line ~939) finds the `AnimationPlayer`,
   plays `rifle_idle`, and then **throws the reference away** — it is a local `var vm_anim`. Nothing
   else in the file can ever play a second clip. Add `var _vm_anim: AnimationPlayer` and
   `var _vm_tree: AnimationTree`, cached on load, nulled on unload. *This is the literal first line of
   code.*
2. **Set loop modes at load.** glTF carries none. `idle` and `sprint` → `LOOP_LINEAR`; everything else
   one-shot. Lift the pattern verbatim from `model_actor._apply_loop_modes()`.
3. **Branch tactical vs empty.** `_start_reload()` does not distinguish. One line:
   `var clip: String = "reload_empty" if current_ammo == 0 else "reload"`. The bolt is locked back on
   an empty gun; playing the tactical clip there is the kind of detail this project's audience notices.
4. **Emit `reload_cancelled`.** Add `cancel_reload()`; call it from sprint start, weapon switch, and
   (per §4) fire-intent before the 60% commit beat. Wire the dead signal.
5. **Muzzle rides the gun.** Re-parent `MuzzlePoint` onto a `BoneAttachment3D` on the `gun` bone.
   `_get_muzzle_position()` (line ~978) does `find_child("MuzzlePoint")` → `global_position` and keeps
   working **unchanged**. Note `WeaponData.bore_dir` is a hand-calibrated *viewmodel-local* vector; once
   the gun tilts during a reload it is momentarily wrong — harmless, because firing is blocked during
   reload, and aimed shots already leave the camera (`ads_transition > 0.6`) rather than the muzzle.

**New file — `scripts/player/viewmodel_anim.gd` (~120 lines):**

The cleanest integration, and it touches **zero** combat logic. Every signal it needs **already exists
and already fires**: `weapon_fired`, `reload_started`, `reload_progress(percent)`, `weapon_jammed`,
`switch_started`, `weapon_switched`. The HUD already subscribes to four of them (`hud.gd:89-93`), so
the pattern is proven in-project. The viewmodel controller is just another subscriber:

```gdscript
## viewmodel_anim.gd — drives the FP viewmodel AnimationTree off WeaponHolder's
## existing signals. Combat logic is untouched; this is a pure listener.
class_name ViewmodelAnim
extends Node

const FIRE_CLIP_LEN: float = 0.267   ## 8 frames @ 30 fps (ANIM_TIMING.md)

var _tree: AnimationTree = null
var _playback: AnimationNodeStateMachinePlayback = null


func bind(holder: WeaponHolder, tree: AnimationTree) -> void:
    _tree = tree
    _tree.active = true
    _playback = _tree.get("parameters/Body/playback") as AnimationNodeStateMachinePlayback
    holder.weapon_fired.connect(_on_fired.bind(holder))
    holder.reload_started.connect(_on_reload_started.bind(holder))
    holder.reload_cancelled.connect(_on_reload_cancelled)
    holder.weapon_jammed.connect(_on_jammed)
    holder.switch_started.connect(_on_switch_started)


func _on_fired(holder: WeaponHolder) -> void:
    var delay: float = holder.current_weapon.get_fire_delay()
    var scale: float = clampf(FIRE_CLIP_LEN / maxf(delay, 0.001), 1.0, 2.5)
    _tree.set("parameters/FireScale/scale", scale)
    _tree.set("parameters/Fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _on_reload_started(holder: WeaponHolder) -> void:
    var empty: bool = holder.current_ammo <= 0
    var clip: String = "reload_empty" if empty else "reload"
    var canonical: float = 3.2 if empty else 2.2       # ANIM_TIMING.md
    var scale: float = clampf(canonical / maxf(holder.reload_timer, 0.001), 0.85, 1.25)
    _tree.set("parameters/ReloadScale/scale", scale)
    _playback.travel(clip)


func _on_reload_cancelled() -> void:
    _playback.travel("idle")                            # xfade does the blend-out


func _on_jammed() -> void:
    _tree.set("parameters/Fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
    _playback.travel("jam")


func _on_switch_started() -> void:
    _playback.travel("draw")
```

**Cheapest high-value add, and it is nearly free:** `weapon_jammed` already fires on every stoppage and
the HUD shows a toast — but **nothing renders it**. `_start_reload()` already gives the jam a 1.1-second
tap-rack timer, which is within a hair of `ANIM_TIMING.md`'s authored 30f/1.0s `jam` clip. One clip, one
`travel("jam")`, and the game's most dramatic moment finally has a picture. `VIEWMODEL_ANIM_SPEC.md`
independently calls this the "**priority gap — cheapest high-value add**." Two documents and one grep
agree. Author `jam` early.

---

## 6. Godot 4.7 features that make this materially easier — and that we are not using

Checked against the codebase. `grep` for `TwoBoneIK|IKModifier|SpringBone|LookAtModifier` across
`scripts/` and `scenes/` returns **nothing**. `AnimationTree` appears in exactly one file
(`helicopter.gd`) and nowhere in the weapon path.

| Feature | Since | Why it matters here | Priority |
|---|---|---|---|
| **`TwoBoneIK3D` / `IKModifier3D`** | 4.6 | **The rig already has `handIK.L/R` + `elbowIK.L/R` bones, and nothing solves them.** Turning them live is the escape hatch for §3's per-gun hand problem, and it kills the "custom IK script" class of work before it is written. Also: procedural left-hand-off-the-gun for a wounded arm (the game already tracks `wounded_arms`). | **HIGH** |
| **`SpringBoneSimulator3D`** | 4.4 | **The sling. The M60's ammo belt.** `ANIM_TIMING.md` craft rule 6 is "follow-through on soft parts" — this does it procedurally, on every clip, for free, forever. A rifle sling that swings when you sprint and settles when you stop is pure Pillar 2 atmosphere at near-zero cost, and it makes *every* animation look more expensive than it is. **The single best effort-to-payoff item on this list.** | **HIGH** |
| **`AnimationNodeOneShot` + filters** | (not new — unused) | The correct fire layer. See §1. | **HIGH** |
| **`remove_immutable_tracks = false`** | (import setting) | Prevents the locked-back-bolt-forever bug. Not a feature — a landmine to defuse. | **BLOCKER** |
| **Ping-pong playback** | 4.7 | A breathing/inspect idle from half the keyframes. | MED |
| **`Tween.tween_await()`** | 4.7 | Sequence the dropped-mag despawn without callback chains. | LOW |
| **Named blend points** | 4.7 | Readable third-person locomotion blend spaces. | LOW |
| **Shader Baker** | 4.5 | Kills the first-muzzle-flash material hitch at export. Not animation, but it is the first thing a player sees when they pull the trigger. Enable in the release preset. | MED |
| ⚠️ **BlendSpace `sync` → `SyncMode` enum** | 4.7 | **Gotcha**, not a feature. Default is now `SYNC_MODE_NONE`, which *freezes* inactive animations. Will bite the third-person locomotion blend, not the FP graph. | WATCH |
| ⚠️ **`LookAtModifier3D.relative` true → false** | 4.7 | **Gotcha.** Now rest-relative by default. Only bites if head-tracking gets added to the third-person characters — which it should. | WATCH |

---

## 7. The third-person backlog (deaths, wounded, crawling, medic)

Briefly, because it is the *easy* half and it is worth saying so plainly.

**The pipeline already exists and it works.** `anim_library.blend` → `export_anim_library.py` →
`anim_library.glb` (91 clips) → `model_actor._merge_shared_library()`. Characters export **mesh-only**;
they borrow every clip. **Adding deaths, wounded, crawling and medic animations requires *zero* engine
work** — author in `anim_library.blend`, re-run the exporter, and the entire roster has them. That is
the system working exactly as designed. It is also why the FP side is worth the investment to bring up
to the same standard: the Summoner has already *paid* for this architecture once and knows what it
returns.

Three things to watch as clips land:

1. **Loop modes.** `model_actor._LOOP_PREFIXES` / `_LOOP_NAMES` is a *heuristic*. `crawl` is cyclic and
   matches no current prefix — it will import play-once and **freeze mid-drag** (the "gliding statue"
   bug the comments describe fighting before). Add `crawl` to `_LOOP_PREFIXES` **before** authoring it,
   not after debugging it.
2. **Clips authored off the floor.** `ground_current_pose()` exists because `laying_breathless` lies the
   man 1.02 m in the air. Wounded/crawling/death clips are *exactly* the family that hits this. Author
   with the hips on the deck, or budget for the same fix.
3. **Ragdoll handoff.** `start_ragdoll()` stops the clip and starts the sim on the current pose. A
   wounded-crawl → death transition should reuse `pose_end_of()` rather than fighting the solver.

---

## 8. Recommendation to the Arbiter

1. **The gun becomes bones on `ArmsRig`, with per-gun `magwell`/`boltway`/`chway` offset bones.**
   Everything else is downstream of this. Without it, a reload is not merely hard — it is *impossible*,
   and the Summoner will author a beautiful animation and watch his rifle hang in the air.
2. **Set `remove_immutable_tracks = false`** on the viewmodel imports before a single clip is authored.
   A one-word change that prevents a bug class that is *miserable* to diagnose after the fact.
3. **Author the `ar` family first, and inside it author `jam` before `reload`.** `jam` is 30 frames, it
   binds to a signal that already fires into the void, and it renders the most dramatic moment in the
   game. It is also a natural rehearsal for the reload's back third — `ANIM_TIMING.md` literally
   describes it as "the back-third of a reload played angrily."
4. **Adopt the AnimationTree graph and the `viewmodel_anim.gd` listener.** Zero changes to combat code;
   every signal it needs already exists and already fires.
5. **Fix the cancellable reload — it is a Pillar 1 bug, not an animation nicety.** `reload_cancelled` has
   been declared and dead for the life of the file. Commit the magazine at 60% and let the player abort
   before that.
6. **Bead `SpringBoneSimulator3D` for the sling and the M60 belt.** It is the cheapest atmosphere in the
   entire engine and it makes every clip that ships look more expensive than it was.

**What is sacrificed (no free lunches):** the shared library is *per-family*, not universal — call it a
60–70% cut in authoring, not 100%. The gun-as-bones rig change means **every existing viewmodel GLB
must be re-exported**, and `export_viewmodel.py` must be reworked to skin the gun rather than select it
as a static object. The 13 `*_fp.glb` files and their `.tscn` wrappers are all invalidated by this
change. That is a real cost, it is unavoidable, and it is far cheaper now — before eight clips per
weapon exist — than it will ever be again.
