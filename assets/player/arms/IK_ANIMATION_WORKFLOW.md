# IK Animation Workflow — FP Arms Rig (Blender 5.0)

How to author, verify, bake, and export animation for **this** rig: the CC0 PSX arms
(`arms_rig.blend`, ~52 bones) with IK controls `handIK.R/L` + `elbowIK.R/L`, finger
`.01` bones that curl while `.02/.03` follow via `COPY_ROTATION`, and a chain-2 IK
constraint on each forearm targeting `handIK`. Companion docs: `VIEWMODEL_ANIM_SPEC.md`
(clip contract), `ANIM_TIMING.md` (30 fps craft rules), `tools/rifle_pose.py` (pose
capture/restore). We author via the Blender MCP (`mcp__blender__execute_blender_code`,
`get_viewport_screenshot`) and headless `bpy` scripts.

> **Golden rule for this rig:** you animate by keyframing the **IK target bones**
> (`handIK`, `elbowIK`) and the finger **`.01`** driver bones. You do **not** keyframe
> the forearm/upper-arm (they're solved by IK) and you do **not** keyframe `.02/.03`
> (they're solved by COPY_ROTATION). At export you **bake with visual keying** so the
> solved bones become real glTF keys.

---

## 0. Blender 5.0 reality check — the Action data model changed

Blender 4.4 introduced **slotted (layered) Actions** and **5.0 removed the legacy
`action.fcurves` API entirely**. An Action no longer holds F-Curves directly. The new
hierarchy is:

```
Action
 └─ Slot            (one per animated datablock; id_type + name, e.g. the armature)
 └─ Layer           (action.layers)  — currently exactly ONE allowed
     └─ Strip        (layer.strips, type='KEYFRAME') — currently exactly ONE, infinite
         └─ Channelbag(slot)  — THIS is the old "action" F-curve container
             └─ fcurves / groups
```

So "the F-curves for my armature" now live at
`action.layers[0].strips[0].channelbag(slot).fcurves`. A **Channelbag is exactly the
legacy Action data model** — same `fcurves.new(...)`, `fcurves.find(...)`, `groups.new(...)`.
There is still a **one-layer, one-strip limit** in 5.0 (full layering/NLA-style strips
come later), so don't design around multiple layers yet.

Sources: [Slotted Actions upgrade notes](https://developer.blender.org/docs/release_notes/4.4/upgrading/slotted_actions/) ·
[Layered Actions feature docs](https://developer.blender.org/docs/features/animation/animation_system/layered/) ·
[ActionChannelbag API](https://docs.blender.org/api/current/bpy.types.ActionChannelbag.html) ·
[Actions manual](https://docs.blender.org/manual/en/latest/animation/actions.html)

### The one thing that saves you: `keyframe_insert` still auto-builds all of it

You almost never need to hand-build slots/layers/strips. Calling
`pose_bone.keyframe_insert(...)` (or `obj.keyframe_insert`) **auto-creates the Action,
the slot, the layer, the KEYFRAME strip, the channelbag, and the slot assignment** on
`animation_data`, exactly like the old API. Use the low-level channelbag API only when
you need to *read/edit existing* curves.

```python
# Reliable in 5.0 — same call as always, plumbing is auto-created:
pb = arm.pose.bones["handIK.R"]
pb.keyframe_insert("location",            frame=f)
pb.keyframe_insert("rotation_euler",      frame=f)   # IK controls are EULER (see §3)
```

To *reach existing* curves for editing (e.g. set interpolation, apply overshoot):

```python
ad   = arm.animation_data
act  = ad.action
slot = ad.action_slot                       # the slot this armature is bound to
cbag = act.layers[0].strips[0].channelbag(slot)
fc   = cbag.fcurves.find('pose.bones["handIK.R"].location', index=1)  # Y channel
for kp in fc.keyframe_points:
    kp.interpolation = 'BEZIER'
```

To build a curve from scratch on a specific slot (headless bake target, §5):

```python
slot  = act.slots.new(id_type='OBJECT', name=arm.name)   # bind arm to this slot
layer = act.layers.new("Base")
strip = layer.strips.new(type='KEYFRAME')
cbag  = strip.channelbag(slot, ensure=True)
fc    = cbag.fcurves.new('pose.bones["handIK.R"].location', index=1)
```

---

## 1. Animating an IK rig

### 1a. What you keyframe (and what you must not)

| Bone group | Mode | Keyframe it? | Why |
|---|---|---|---|
| `handIK.R/L` | **Euler** | **Yes** — `location` + `rotation_euler` | Drives the whole arm via the chain-2 IK constraint on the forearm. Position = where the hand goes; rotation = wrist twist. |
| `elbowIK.R/L` (pole target) | Euler | Yes, sparingly — `location` | Controls elbow swing/plane. Key it only when the elbow needs to move (inspect, reload). A static pole is fine for idle. |
| finger `.01` (proximal) | Euler/Quat | **Yes** — `rotation` | The curl driver. `.02/.03` copy it. |
| finger `.02 / .03` | — | **No** | Solved by `COPY_ROTATION`. Keying them fights the constraint. |
| forearm / upper-arm | — | **No** | Solved by the IK constraint. Keying them fights IK. |
| `camera` bone | — | Reference only; do not export | Eye position for framing screenshots (74° FOV, 4:3). |

**IK vs FK for FP arms:** keep the arms on **IK**. The whole point for reload/bolt/jam
is that the hand can plant on the weapon and the arm follows, and you can retarget the
hold with `rifle_pose.py` without re-posing the chain. FK is only worth it for a free
"inspect" flourish where the hand traces an arc in air — and even then IK with a moving
`handIK` gives you the same arc with less keying. Community consensus for 1st-person is
**IK for the support/planting hand, IK or IK-with-a-bit-of-FK-wrist for the working hand**.
(See [Polycount IK/FK for FP](https://polycount.com/discussion/56103/ik-fk-or-blend-for-1st-person-animation), [UltiDigi FPS arms rig guide](https://ultidigi.com/tutorials/fps-arms-rigging-in-blender).)

### 1b. Idle sway / inspect via the IK controls

Per `ANIM_TIMING.md` and `VIEWMODEL_ANIM_SPEC.md`: **procedural sway lives in Godot
code over a near-still idle** — do **not** bake mouse-lag sway. What you *may* bake is a
subtle additive **breathing loop** (4–6 s, 1–2 cm vertical) underneath. You get that by
keyframing `handIK.R` (and, if both hands ride the gun, `handIK.L`) `location.z`/`.y` a
centimetre or two on a slow sine, holding the start=end key so it loops seamlessly.

An **inspect/check flourish** (draw's optional first-draw beat, ~8–10 f) is a short arc:
key `handIK.R` out+up to tilt the weapon toward camera, rotate the wrist a few degrees,
hold 2–4 f, ease back. Apply the 7 craft rules from `ANIM_TIMING.md` — hand leads the
gun by 1–2 f, fast-in/slow-out, 10–20% overshoot then settle.

### 1c. The finger COPY_ROTATION question — answered

**Keyframe the `.01` bones only; let `.02/.03` follow.** That is the whole reason the
constraints exist — one curl key per finger instead of three. This is the standard
"one driver bone + copy-rotation followers" finger rig
([Copy Rotation manual](https://docs.blender.org/manual/en/latest/animation/constraints/transform/copy_rotation.html)).
Two consequences to plan for:

- **In the viewport / MCP screenshots** the constraint is live, so `.02/.03` visibly
  follow `.01`. Good — what you see is what bakes.
- **At export** glTF cannot represent COPY_ROTATION, so `.02/.03` would be static unless
  you **bake with visual keying** (§5). After baking, `.02/.03` carry real keys that
  reproduce the curl, and you can (optionally) clear the constraints on the baked copy.
- **Known gotcha:** constraint-driven followers can bake with a **1-frame delay** on
  fast motion ([T69615](https://developer.blender.org/T69615)). For finger curls at our
  speeds it's invisible; if a fast snap ever looks laggy, bake at `step=1` and, if needed,
  nudge the follower keys back one frame.

Because our authoring path applies poses via `rifle_pose.py` (which writes **quaternion**
values to every bone incl. fingers), the fingers are already correctly curled before you
start animating — you're only adding motion on top.

---

## 2. Useful tools / addons (all free / ships with Blender)

| Tool | Ships with Blender? | Use for FP hands |
|---|---|---|
| **Graph Editor** | Built-in | Where the craft happens. Apply `ANIM_TIMING.md`'s fast-in/slow-out, overshoot, 1–2 f hand-lead offset. Set handle types, retime, clean curves. Non-negotiable. |
| **Pose Library (Asset Browser)** | Built-in add-on (4.x+) | **Reusable hand poses.** Select the IK+finger controls, *Create Pose Asset* on the timeline → a 1-frame Action marked as asset. Build a catalog: `rifle_hold`, `mag_grab`, `bolt_grip`, `open_hand`, `fist`. Apply/blend from the Asset Browser in Pose Mode; poses **mirror L↔R**. This is the GUI-native version of `rifle_pose.py`. ([Pose Library manual](https://docs.blender.org/manual/en/latest/animation/armatures/posing/editing/pose_library.html), [Pose Library v2 blog](https://code.blender.org/2021/05/pose-library-v2-0/)) |
| **Slotted Actions** | Built-in (5.0) | One Action per clip (`idle`, `fire`, `reload`…), each bound to a slot. Keeps the clip-name contract from `VIEWMODEL_ANIM_SPEC.md` clean. |
| **Auto keying + Keying Sets** | Built-in | A keying set of exactly `handIK.R/L loc+rot`, `elbowIK.R/L loc`, and the finger `.01` rotations = one keypress keys the whole meaningful pose, nothing spurious. |
| **NLA Editor** | Built-in | Stage/preview multiple clips; source for glTF export by track (§6). Remember the 5.0 one-strip-per-Action limit is about *layers inside an Action*, not NLA tracks. |
| **`bpy_extras.anim_utils.bake_action`** | Built-in module | Headless-safe IK→FK bake (§5). |

**Rigify / Auto-Rig Pro:** not needed here — we already have a working hand-built IK rig
with the exact bone-name contract other tooling depends on. Rigify would give you IK/FK
snap toggles and a nicer bone UI, but adopting it means re-rigging and breaking
`rifle_pose.py` / `fp_grip.py` bone-name assumptions. **Skip.** (ARP is paid anyway.) Keep
what works; use the Pose Library for the reuse Rigify would have given you.

---

## 3. Blender MCP for animation — what's reliable and the gotchas

`mcp__blender__execute_blender_code` runs arbitrary `bpy` Python inside a **running GUI
Blender** (so it has real context, unlike `--background`). `get_viewport_screenshot`
returns the current viewport. This is the ideal authoring loop: real context + eyes.

### Gotchas we've hit / that matter

1. **No JS runtime helpers.** `Date.now()` and friends don't exist — this is Python.
   Use `time.time()` / `frame_set`. (Noted because prior scripted passes assumed a JS-ish env.)
2. **Slotted actions (§0).** Any code that touches `action.fcurves` directly throws in
   5.0. Go through `channelbag`, or just use `keyframe_insert`.
3. **IK controls are EULER — capture `matrix_basis`, not location+forced quaternion.**
   This is the load-bearing lesson. When capturing/baking a pose-bone's local transform
   for later replay, read **`pb.matrix_basis`** — it is the bone's full local transform
   (loc + rot + scale) **in its own rotation mode**, and it round-trips correctly whether
   the bone is Euler or Quaternion. Do **not** capture `location` and then jam a
   `rotation_quaternion` onto an Euler `handIK` — the quaternion channel is ignored (mode
   is EULER) and you lose the rotation. Reliable capture/replay:

   ```python
   # capture
   snap = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
   # replay on a frame
   for name, m in snap.items():
       pb = arm.pose.bones[name]
       pb.matrix_basis = m           # respects the bone's own rotation_mode
       pb.keyframe_insert("location", frame=f)
       if pb.rotation_mode == 'QUATERNION':
           pb.keyframe_insert("rotation_quaternion", frame=f)
       else:
           pb.keyframe_insert("rotation_euler", frame=f)
   ```

   > Note `rifle_pose.py` deliberately *forces* every bone to `QUATERNION` and writes
   > `rotation_quaternion` — that works because it **sets the mode first**
   > (`pb.rotation_mode='QUATERNION'`) before writing. That's fine for a static pose
   > restore. For **animation keying** prefer `matrix_basis` + key the channel that
   > matches each bone's *existing* mode, so you don't silently switch the IK controls
   > off Euler and desync the Graph Editor curves.

4. **`bpy.ops.nla.bake` needs a VIEW_3D context.** Via the MCP (GUI Blender) it usually
   works, but it's fragile. Prefer the **data-API bake** (`anim_utils.bake_action`, §5),
   which needs no operator context and works in `--background` too. If you must use the
   operator, wrap it in `context.temp_override(area=<VIEW_3D>, region=<WINDOW>, ...)`.
5. **Always `bpy.context.view_layer.update()` after setting transforms** before you read
   world positions or screenshot — IK solves lazily.
6. **`frame_set(f)` before capturing solved state.** To bake by hand you must step frames
   so constraints/IK re-solve at each `f`.
7. **Screenshots are your regression test.** After every keyframe pass, screenshot from
   the `camera` bone's view and eyeball the hold against the reference.

### Recommended loop

```
1. AUTHOR in GUI via MCP: frame_set → set handIK/elbowIK/.01 → keyframe_insert → next pose
2. VERIFY: view_layer.update() → get_viewport_screenshot → compare to reference/hold
3. REFINE curves: reach the channelbag, set interpolation/handles, add overshoot & hand-lead
4. BAKE headless: anim_utils.bake_action(visual_keying=True) → real keys on solved bones
5. EXPORT headless: gltf with sampled animation → load in Godot, bind to clip-name signals
```

Sources: [PoseBone API](https://docs.blender.org/api/current/bpy.types.PoseBone.html) ·
[bpy.ops.nla](https://docs.blender.org/api/current/bpy.ops.nla.html) ·
[context.temp_override for poll() failures](https://medium.com/@anvilinteractivesolutions/stop-guessing-blender-context-solve-bpy-ops-poll-and-ship-paste-ready-code-with-contextwizard-98f6bb074b20)

---

## 4. Baking IK → keyframes (the export prerequisite)

glTF has **no IK and no constraints** — it only stores per-bone TRS keys. So an
IK/constraint rig **must be baked with visual keying** before export, or the exported
clip is dead (this is the classic "IK not baking on glTF export" trap:
[Godot forum](https://forum.godotengine.org/t/blender-ik-not-baking-in-animations-on-gltf-export/58134),
[glTF-Blender-IO #439](https://github.com/KhronosGroup/glTF-Blender-IO/issues/439)).

**Visual keying** = key the *final, solved* transform (post-IK, post-copy-rotation)
rather than the raw channel values. After baking, every bone — forearm, upper-arm,
`.02/.03` fingers — carries explicit keys reproducing the solved motion.

Two ways to bake:

- **Operator:** `bpy.ops.nla.bake(visual_keying=True, use_current_action=True,
  only_selected=False, bake_types={'POSE'})`. Needs VIEW_3D context (fine in MCP GUI,
  flaky headless). `clear_constraints=True` strips IK/copy-rotation from the baked result
  — do this on a **duplicate** so your editable rig keeps its constraints.
- **Data API (preferred, headless-safe):** `anim_utils.bake_action` — see §5.

The glTF exporter can also sample-on-export (`export_force_sampling`), which effectively
bakes at export time. Belt-and-suspenders is fine, but an **explicit pre-bake gives you a
clean Action you can inspect/tweak** before it leaves Blender.

---

## 5. Headless bake snippet (reliable, no operator context)

`bpy_extras.anim_utils.bake_action` takes a `BakeOptions` struct (Blender 4.x/5.0 form,
replacing the old positional-arg signature — see
[rigacar #132](https://github.com/digicreatures/rigacar/issues/132)). `BakeOptions`
fields: `only_selected, do_pose, do_object, do_visual_keying, do_constraint_clear,
do_parents_clear, do_clean, do_location, do_rotation, do_scale, do_bbone, do_custom_props`
([anim_utils API](https://docs.blender.org/api/current/bpy_extras.anim_utils.html)).

```python
import bpy
from bpy_extras import anim_utils

arm = bpy.data.objects["ArmsRig"]

# Bake the CURRENT action's frame range into a fresh action, resolving IK + copy-rotation.
scene = bpy.context.scene
frames = range(scene.frame_start, scene.frame_end + 1)

baked = anim_utils.bake_action(
    arm,
    action=None,                 # None → new action; or pass an action to fill
    frames=frames,
    bake_options=anim_utils.BakeOptions(
        only_selected=False,
        do_pose=True,
        do_object=False,
        do_visual_keying=True,   # <-- resolves IK constraint + finger COPY_ROTATION
        do_constraint_clear=False,  # keep constraints on THIS obj; bake a copy if you want them gone
        do_parents_clear=False,
        do_clean=False,
        do_location=True,
        do_rotation=True,
        do_scale=True,
        do_bbone=False,
        do_custom_props=False,
    ),
)
baked.name = "idle_baked"
```

Notes:
- Works in `--background` — no VIEW_3D needed. This is the headless bake path.
- The returned action already lives on the new slotted structure; assign/rename per clip.
- For a non-destructive pipeline: `arm.copy()` the armature (or bake into a new action and
  only export that), so your working rig keeps live IK/constraints for further editing.

---

## 6. glTF export settings (headless)

```python
bpy.ops.export_scene.gltf(
    filepath=r"C:\Users\caleb\RECONgame\...\m14_fp.glb",
    export_format='GLB',
    export_animations=True,
    export_animation_mode='ACTIONS',   # one glTF anim per Action (our clip names)
    export_nla_strips=True,            # or drive from NLA tracks if you stage them there
    export_force_sampling=True,        # sample = bake-on-export safety net for any residual constraint
    export_bake_animation=True,
    export_frame_range=True,
    export_apply=False,                # don't apply modifiers on the skinned mesh
)
```

- `export_animation_mode='ACTIONS'` gives **one glTF animation per Blender Action**, so the
  clip names (`idle`, `fire`, `reload`, …) survive into Godot's AnimationPlayer — that's
  the contract in `VIEWMODEL_ANIM_SPEC.md`.
- Keep `export_force_sampling=True` while constraints exist on the rig; you can turn it off
  (smaller files) only once everything is pre-baked and confirmed working
  ([2026 Blender→Godot export guide](https://supermatrix.studio/blog/best-workflow-for-exporting-animated-characters-from-blender-to-godot)).
- Export **only the clips you want** — disable "all actions" so dozens of test actions
  don't ship ([glTF export manual](https://docs.blender.org/manual/en/2.81/addons/import_export/io_scene_gltf2.html)).

---

## 7. Concrete: author a per-gun idle-sway + inspect on THIS rig

Goal: a subtle breathing idle (looping) plus an optional inspect flourish, for the M14
hold, reusing `rifle_pose.py`'s capture approach. Run each block via
`mcp__blender__execute_blender_code`, screenshot between steps.

**Step 0 — load the hold.** In the running Blender, apply the captured rifle hold so every
finger/knuckle is placed, then confirm reconstruction:
```python
import importlib, sys
sys.path.append(r"C:\Users\caleb\RECONgame\tools")
import rifle_pose; importlib.reload(rifle_pose)
arm = bpy.data.objects["ArmsRig"]
rifle_pose.apply(arm)
print("worst reconstruction err (mm):", rifle_pose.verify(arm))   # ~0 = perfect
bpy.context.view_layer.update()
```

**Step 1 — capture the neutral hold as frame-1 pose (matrix_basis, §3).**
```python
import bpy
from mathutils import Vector
scene = bpy.context.scene
scene.frame_start, scene.frame_end = 1, 120     # 4 s @ 30 fps loop
scene.render.fps = 30

ctrl_bones = ["handIK.R","handIK.L","elbowIK.R","elbowIK.L"]  # + finger .01 if they move
neutral = {n: arm.pose.bones[n].matrix_basis.copy() for n in ctrl_bones}

def key_pose(f, mats):
    scene.frame_set(f)
    for n, m in mats.items():
        pb = arm.pose.bones[n]
        pb.matrix_basis = m
        pb.keyframe_insert("location", frame=f)
        if pb.rotation_mode == 'QUATERNION':
            pb.keyframe_insert("rotation_quaternion", frame=f)
        else:
            pb.keyframe_insert("rotation_euler", frame=f)

key_pose(1, neutral)
```

**Step 2 — breathe: raise the hands ~1.5 cm at mid-loop, return identical at the end.**
```python
mid = {}
for n, m in neutral.items():
    m2 = m.copy()
    if n.startswith("handIK"):
        m2.translation.z += 0.015          # ~1.5 cm up  (tune per gun weight)
        m2.translation.y -= 0.005          # tiny sink toward body
    mid[n] = m2

key_pose(60, mid)          # peak of the breath
key_pose(120, neutral)     # identical to frame 1 → seamless loop
```

**Step 3 — make it read like breathing, not a bounce (Graph Editor via channelbag).**
```python
ad   = arm.animation_data
cbag = ad.action.layers[0].strips[0].channelbag(ad.action_slot)
for fc in cbag.fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = 'BEZIER'
        kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'
ad.action.name = "idle"     # clip-name contract
```
Screenshot from the `camera` bone view; confirm the gun drifts a hair, doesn't pop at loop.

**Step 4 — (optional) inspect flourish** as a SEPARATE action `inspect` (8–10 f in, hold,
ease out), applying `ANIM_TIMING.md` draw-check rules: tilt weapon toward camera by moving
`handIK.R` out+up and rotating the wrist, hand leading 1–2 f, 10–20% overshoot, hold 2–4 f,
settle. Same `key_pose` helper; keep it its own Action so it maps to its own glTF clip.

**Step 5 — reusable poses.** Instead of hand-numbers, capture the key holds as **Pose
Library assets** (select `ctrl_bones` + finger `.01`, *Create Pose Asset*): `m14_hold`,
`m14_inspect_peak`. Future clips blend between them from the Asset Browser — the GUI twin
of `rifle_pose.py`, and they mirror for the left-hand-lead weapons.

**Step 6 — bake + export** (headless, §5 then §6): `bake_action(do_visual_keying=True)`
on the `idle` action → resolves the IK + finger copy-rotation into real keys → export
`m14_fp.glb` with `export_animation_mode='ACTIONS'`. Load in Godot, bind `idle` on the
viewmodel AnimationPlayer (procedural sway rides on top in code — do not bake it here).

> Reminder from `VIEWMODEL_ANIM_SPEC.md`: idle can be nearly dead-still because
> `weapon_holder` already does procedural sway/breath. This baked breath is an *optional*
> subtle additive base — keep amplitude tiny (1–2 cm) so it doesn't fight the code.

---

## Sources
- [Slotted Actions — upgrade notes](https://developer.blender.org/docs/release_notes/4.4/upgrading/slotted_actions/)
- [Layered Actions — feature docs](https://developer.blender.org/docs/features/animation/animation_system/layered/)
- [ActionChannelbag / ActionChannelbags API](https://docs.blender.org/api/current/bpy.types.ActionChannelbag.html)
- [Actions — Blender manual](https://docs.blender.org/manual/en/latest/animation/actions.html)
- [Blender 5.0 Python API release notes](https://developer.blender.org/docs/release_notes/5.0/python_api/)
- [PoseBone API](https://docs.blender.org/api/current/bpy.types.PoseBone.html)
- [bpy_extras.anim_utils (bake_action / BakeOptions)](https://docs.blender.org/api/current/bpy_extras.anim_utils.html)
- [bake_action signature change (rigacar #132)](https://github.com/digicreatures/rigacar/issues/132)
- [bpy.ops.nla (bake operator)](https://docs.blender.org/api/current/bpy.ops.nla.html)
- [Copy Rotation constraint manual](https://docs.blender.org/manual/en/latest/animation/constraints/transform/copy_rotation.html)
- [Constraint bake 1-frame delay (T69615)](https://developer.blender.org/T69615)
- [Pose Library manual](https://docs.blender.org/manual/en/latest/animation/armatures/posing/editing/pose_library.html) · [Pose Library v2 blog](https://code.blender.org/2021/05/pose-library-v2-0/)
- [glTF IK-not-baking (Godot forum)](https://forum.godotengine.org/t/blender-ik-not-baking-in-animations-on-gltf-export/58134) · [glTF-Blender-IO #439](https://github.com/KhronosGroup/glTF-Blender-IO/issues/439)
- [glTF export manual](https://docs.blender.org/manual/en/2.81/addons/import_export/io_scene_gltf2.html) · [Blender→Godot export guide 2026](https://supermatrix.studio/blog/best-workflow-for-exporting-animated-characters-from-blender-to-godot)
- [FPS arms rigging / IK-FK for first-person: UltiDigi](https://ultidigi.com/tutorials/fps-arms-rigging-in-blender) · [Polycount IK/FK FP thread](https://polycount.com/discussion/56103/ik-fk-or-blend-for-1st-person-animation)
- [context.temp_override for headless poll() failures](https://medium.com/@anvilinteractivesolutions/stop-guessing-blender-context-solve-bpy-ops-poll-and-ship-paste-ready-code-with-contextwizard-98f6bb074b20)
