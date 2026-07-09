# Ragdoll Implementation Plan — RECONgame (Godot 4.6)

Research doc only. No project code changed. Grounds the Godot 4 PhysicalBone3D
ragdoll API against our actual character pipeline (`ModelActor` +
Mixamo-rigged glTF) and gives a step-by-step integration into
`enemy_base._die()` (and the identical `ally_base._die()`).

---

## 0. How our characters are actually built (ground truth)

- Enemies/allies are `CharacterBody3D`. The visual is a **child node**
  `sprite_actor` which is a `ModelActor` (default) or `SpriteActor` (fallback),
  set up in `enemy_base._setup_visual()` (line ~279).
- `ModelActor.setup()` (`scripts/visuals/model_actor.gd`) does
  `load("res://assets/models/characters/<unit>.glb").instantiate()`, then
  caches `_anim: AnimationPlayer` and `_skel: Skeleton3D` via `find_child`.
  **The whole rig is instanced at RUNTIME from the .glb** — there is no saved
  per-character `.tscn` we can pre-decorate in the editor.
- All characters are **Mixamo rigs → they share the same bone names**
  (`mixamorig_Hips`, `mixamorig_Spine`, `mixamorig_LeftUpLeg`, ...). This is the
  single most important fact for the plan: **one authored physical skeleton fits
  every character.**
- Current death: `_die()` sets `AIState.DEAD`, disables physics process, zeros
  collision layer/mask, plays a canned death clip via `sprite_actor.play(...)`,
  adds to `lootable_corpses`, and `create_timer(45.0).timeout -> queue_free`.
- `last_hit_dir` (line 196) = world dir attacker→us, set in `take_damage`
  (line 1443). This is our impulse direction. We do **not** currently capture the
  exact hit *bone/position* — see §2 for how to get "good enough" without it.

---

## 1. Getting PhysicalBone3D chains onto the Mixamo skeleton

### The Godot 4.x node model (changed since 4.3)
The `physical_bones_*` functions moved OFF `Skeleton3D` onto a dedicated
**`PhysicalBoneSimulator3D`** node (a `SkeletonModifier3D`). Correct tree:

```
Skeleton3D
└── PhysicalBoneSimulator3D          # holds the sim; child of the skeleton
    ├── PhysicalBone3D  (Hips)       # bone_name = "mixamorig_Hips"
    ├── PhysicalBone3D  (Spine)
    ├── PhysicalBone3D  (Head)
    ├── PhysicalBone3D  (LeftUpLeg) ... etc
```

Each `PhysicalBone3D` has: `bone_name` (matches a skeleton bone), a child
`CollisionShape3D`, a `joint_type` (Cone for shoulders/hips/neck, Hinge for
elbows/knees, Pin as fallback), `mass`, and physics layer/mask.

### Recommended approach: author ONCE, reuse everywhere (manual, not runtime)

Because joint types and collision-shape sizes need hand-tuning (and runtime
generation gives ugly, unconstrained crumpling), the clean path is:

1. In the editor, open one character .glb inherited scene (e.g. `us_grunt.glb`).
2. Select its `Skeleton3D`, use the toolbar **Skeleton → "Create Physical
   Skeleton"**. Godot generates a `PhysicalBoneSimulator3D` + one
   `PhysicalBone3D` (with capsule collider + pin joint) per bone.
3. **Prune** to ~13–15 bones for perf & quality: Hips, Spine, Spine1/2, Head,
   Left/Right UpLeg, Left/Right Leg, Left/Right Arm, Left/Right ForeArm. Delete
   fingers, toes, twist bones, the MASTER/tracker bones (docs explicitly say to
   remove MASTER/waist/neck/headtracker). Fewer bones = fewer bodies = cheaper.
4. Set `joint_type`: Cone for UpLeg/Arm/Neck-Head, Hinge for Leg(knee)/
   ForeArm(elbow), leave Hips as the root (pinned to nothing / free).
5. Size the capsule `CollisionShape3D`s to each limb (do this AFTER joints —
   rotating a joint rotates its shape).
6. **Save the `PhysicalBoneSimulator3D` subtree as a reusable PackedScene**,
   e.g. `scenes/characters/ragdoll_mixamo.tscn` (right-click node → Save Branch
   as Scene). Since every character shares Mixamo bone names, this one scene is
   valid for ALL of them.

At runtime we then `load()` that PackedScene, instance it, and `add_child()` it
under the freshly-instanced `Skeleton3D` inside `ModelActor`. The simulator binds
`PhysicalBone3D.bone_name` → skeleton bone by name, so it "just works" on any
Mixamo character. `ModelActor` already exposes `_skel`; we add a tiny accessor
(see §6) rather than reaching into a private var.

> Runtime-generated alternative (NOT recommended as primary): you *can* create
> `PhysicalBone3D` nodes in script, add them under the Skeleton3D, set
> `bone_name`, attach `CollisionShape3D`, then start the sim. But you get
> unconstrained pin joints and hand-computed shapes — noticeably worse, and more
> code. Keep it only as a theoretical fallback. Constraint to remember:
> **PhysicalBone3D MUST be a descendant of the Skeleton3D** (via the simulator).

---

## 2. Exact Godot 4.6 API to trigger ragdoll + apply the killing impulse

### Start / stop simulation (called on the SIMULATOR node, not the Skeleton)
```gdscript
# sim: PhysicalBoneSimulator3D
sim.physical_bones_start_simulation()                 # full ragdoll (all bones)
sim.physical_bones_start_simulation([&"mixamorig_LeftArm", &"mixamorig_RightArm"])  # partial
sim.physical_bones_stop_simulation()
sim.is_simulating_physics()  -> bool
sim.physical_bones_add_collision_exception(rid)       # e.g. exclude other corpses
```

### Applying the killing impulse
`PhysicalBone3D` derives from `PhysicsBody3D` and exposes RigidBody-style impulse
methods. Apply to the bone nearest the hit so the body reacts believably:

```gdscript
# impulse dir = the round's travel direction (attacker -> us) = last_hit_dir
# strength ~ 4-8 kg*m/s for a rifle hit; scale by body multiplier if desired
var impulse: Vector3 = last_hit_dir.normalized() * 6.0
var bone: PhysicalBone3D = sim.get_node(&"Spine") as PhysicalBone3D
bone.apply_central_impulse(impulse)                   # whole-body shove
# or, to add spin/topple from an off-center hit:
bone.apply_impulse(impulse, hit_offset_from_bone_com) # offset in bone-local space
```

- We reliably have **direction** (`last_hit_dir`) but not the exact **hit
  world-position** in `_die()`. Two tiers:
  - **Tier A (ship this):** apply `apply_central_impulse(last_hit_dir * force)`
    to the **Spine/Hips** bone. Convincing knock-back with zero new plumbing.
  - **Tier B (polish):** thread the hitzone's world hit-point down from
    `Hitzone`/`take_damage` into `_die()`, pick the nearest `PhysicalBone3D`, and
    use `apply_impulse(impulse, hitpos - bone.global_position)` for headshots
    that snap the head and torso hits that fold the man over. Add a mild vertical
    component (`+ Vector3.UP * 1.5`) so bodies lift slightly instead of sliding.
- **Timing:** start the sim FIRST, then apply the impulse the SAME frame (or via
  `call_deferred` right after) so the bone body exists in the physics world.

---

## 3. Blending from the death clip into ragdoll

Two viable modes; pick per taste. RECON wants weighty, readable deaths, so
**instant ragdoll on death (Mode A)** is the recommended default; keep the canned
clip only as the LOD/over-budget fallback (§4).

**Mode A — Instant ragdoll (recommended).** On death, DON'T play the death clip.
Freeze the AnimationPlayer (so it stops driving bone poses), start the sim on the
current pose, apply impulse. The corpse falls purely from physics from wherever
the man was standing/aiming — no pop.
```gdscript
_anim.pause()                       # or _anim.stop(false) to keep pose
sim.physical_bones_start_simulation()
bone.apply_central_impulse(last_hit_dir * force)
```

**Mode B — Blend from a death clip (active/partial ragdoll).** Play the death
clip, and use `PhysicalBoneSimulator3D.influence` (0..1) tweened up so physics
takes over gradually while the animation still "tries" to move. Community
consensus: **keep the AnimationTree/Player ACTIVE during the blend** — a fully
limp switch looks worse than one still attempting a stumble.
```gdscript
sim.physical_bones_start_simulation()
sim.influence = 0.0
var tw := create_tween()
tw.tween_property(sim, "influence", 1.0, 0.35).set_ease(Tween.EASE_OUT)
```
Partial ragdoll is the same idea limited to limbs — e.g. only arms/upper body go
physical on a non-fatal stagger while legs keep animating.

Pitfall: with the simulator present, if `Skeleton3D.animate_physical_bones` is
set wrong you get bones fighting animation. For pure death (Mode A) we want the
AnimationPlayer stopped so only physics writes the pose.

---

## 4. Performance plan (target ~20 corpses on screen)

Physical skeletons are the expensive corpse type; ~13–15 bodies × N corpses adds
up. Plan:

1. **Bone budget:** cap the authored physical skeleton at ~13–15 bones (§1.3).
   This is the biggest single lever.
2. **Let bodies auto-sleep:** Godot's physics server sleeps idle bodies
   automatically — a settled ragdoll costs almost nothing. Don't fight this;
   just make sure we don't keep poking them.
3. **Freeze when settled:** run a short settle window (~3–4 s). When the Hips
   bone's `linear_velocity` is near zero, **stop simulating** and leave the
   skeleton in its final physics pose (bake), or simply let it stay asleep. This
   removes it from the active solver for the remaining ~40 s before despawn.
4. **Global active-ragdoll cap (the real safety valve):** a small autoload/static
   counter, e.g. `MAX_ACTIVE_RAGDOLLS = 8`. On death, if under budget → ragdoll;
   if over budget → fall back to the **existing canned death-clip path** (current
   behavior). Excess corpses are cheap animated/static bodies, not solvers. This
   guarantees the frame cost is bounded no matter how many men die at once.
5. **Despawn timer already exists (45 s):** unchanged. When it fires, `queue_free`
   also frees the physical skeleton. Consider a soft "oldest corpse fades first"
   if 20 pile up, but 45 s + budget is fine for M-tier.
6. **Collision-cheapen corpses:** once settled, move the physical bones to a
   corpse-only layer (see §5) so they don't keep testing against the player,
   AI navigation, or each other.

Net: at most 8 solving ragdolls at once; the other ~12 are asleep/baked/animated.
Well within budget for a Godot 4.6 FPS.

---

## 5. Collision layer setup (matches this project's CLAUDE.md)

Project layers (from CLAUDE.md → Physics Layers):

| Layer | Name |
|-------|------|
| 1 | world |
| 2 | player |
| 3 | enemies |
| 4 | player_hitbox |
| 5 | enemy_hitbox |
| 6 | player_hurtbox |
| 7 | enemy_hurtbox |
| 9 | projectiles |

Rules for the ragdoll bodies:

- **On death, the `CharacterBody3D` already zeros `collision_layer`/`mask`**
  (`_die()` lines 1526–1527) — good, the capsule stops interfering with the sim.
- **PhysicalBone3D layer:** put corpses on **layer 1 (world)** so they rest on and
  collide with static geometry (the ground). Simple and correct for a corpse.
- **PhysicalBone3D mask:** collide with **layer 1 (world)** only. Do **NOT** mask
  layer 2 (player), 3 (enemies), or the hitbox/hurtbox layers — corpses should
  not shove the living player or living AI, and should not receive bullets. This
  also avoids a fresh ragdoll's bones exploding against the dying man's own
  now-disabled body.
- **Avoid corpse-vs-corpse solving cost:** either leave corpses off each other's
  mask (they'll interpenetrate — usually acceptable and cheapest), or add mutual
  `physical_bones_add_collision_exception()` for nearby corpses. Recommend
  ignoring corpse-corpse collision for perf.
- Set these two values (layer=1, mask=1) on every `PhysicalBone3D` in the authored
  `ragdoll_mixamo.tscn`, so no runtime layer code is needed.

---

## 6. Step-by-step integration into `enemy_base._die()`

Reuses the existing structure; the canned-clip branch stays as the fallback.
Mirror the identical change into `ally_base._die()` (`scripts/allies/ally_base.gd`
~line 551 — same shape, uses `ally_corpses` group).

### 6a. One-line accessor on `ModelActor` (no logic change)
`ModelActor` already caches `_skel`. Add a getter so `_die` doesn't touch privates:
```gdscript
# model_actor.gd
func get_skeleton() -> Skeleton3D:
    return _skel
func stop_anim() -> void:
    if _anim: _anim.pause()
```

### 6b. Author asset (§1): `scenes/characters/ragdoll_mixamo.tscn`
Reusable `PhysicalBoneSimulator3D` subtree, ~13–15 bones, layer=1/mask=1, joints
tuned. Preload it in `enemy_base`:
```gdscript
const RAGDOLL_SIM: PackedScene = preload("res://scenes/characters/ragdoll_mixamo.tscn")
static var _active_ragdolls: int = 0
const MAX_ACTIVE_RAGDOLLS: int = 8
```

### 6c. New helper in `enemy_base`
```gdscript
func _try_ragdoll() -> bool:
    # Only rigged models can ragdoll; sprites/capsule use the canned path.
    if not _visual_is_model or sprite_actor == null:
        return false
    if _active_ragdolls >= MAX_ACTIVE_RAGDOLLS:
        return false
    var ma := sprite_actor as ModelActor
    var skel: Skeleton3D = ma.get_skeleton()
    if skel == null:
        return false

    ma.stop_anim()                              # §3 Mode A: stop clip driving bones
    var sim := RAGDOLL_SIM.instantiate() as PhysicalBoneSimulator3D
    skel.add_child(sim)
    sim.physical_bones_start_simulation()       # §2 start FIRST

    # §2 killing impulse on the spine (Tier A). Bone node name per the .tscn.
    var spine := sim.find_child("Spine", true, false) as PhysicalBone3D
    if spine != null:
        var force: float = 6.0
        spine.apply_central_impulse(last_hit_dir.normalized() * force + Vector3.UP * 1.5)

    _active_ragdolls += 1
    # release the slot when this corpse despawns (45s timer below)
    tree_exited.connect(func() -> void: _active_ragdolls -= 1)

    # §4 settle-then-sleep: after a few seconds, stop solving.
    get_tree().create_timer(4.0).timeout.connect(func() -> void:
        if is_instance_valid(sim) and sim.is_simulating_physics():
            sim.physical_bones_stop_simulation()
    )
    return true
```

### 6d. Splice into `_die()` — minimal change to the existing branch
Current relevant block (lines 1529–1542):
```gdscript
if sprite_actor != null:
    ... derive intent (death_right / death_forward) ...
    sprite_actor.play(..., true)
elif mesh:
    mesh.rotation_degrees.x = 90
```
Change to try ragdoll first, keep the clip as fallback:
```gdscript
if _try_ragdoll():
    pass                                        # physics takes over; no clip
elif sprite_actor != null:
    ... existing death-clip code unchanged (fallback: sprite LOD / over budget) ...
elif mesh:
    mesh.rotation_degrees.x = 90
```
Everything else in `_die()` is untouched: `set_physics_process(false)`,
`collision_layer/mask = 0`, `add_to_group("lootable_corpses")`, and the 45 s
`queue_free` timer all still apply and remain correct for a ragdoll corpse.

### 6e. Ally parity
Apply 6a–6d identically in `ally_base._die()` (group `ally_corpses`,
`unregister_ally`). Same `ModelActor`, same rig, same reusable .tscn.

---

## 7. Common pitfalls (Godot 4.6, Mixamo)

- **Wrong node for the API:** `physical_bones_*` live on
  `PhysicalBoneSimulator3D` in 4.4+, NOT on `Skeleton3D` (the official tutorial
  text lags; docs issue #100843). Call them on the simulator.
- **Bone name mismatch:** `PhysicalBone3D.bone_name` must equal the skeleton's
  bone name exactly. Mixamo importers may prefix `mixamorig_` (underscore) vs
  `mixamorig:` (colon). Verify against `_skel.get_bone_name(i)` for OUR .glbs
  before finalizing the authored .tscn; if they differ, re-name in the .tscn.
- **Start sim before impulse:** applying impulse before
  `physical_bones_start_simulation()` does nothing (no body yet).
- **Animation fighting physics:** leave the AnimationPlayer running and it will
  overwrite the physics pose. For Mode A, pause it. `animate_physical_bones`
  misconfiguration causes the same tug-of-war.
- **Scale on the rig:** `ModelActor` scales `_inst` to normalize height
  (`TARGET_HEIGHT_M`). Non-unit skeleton scale can make collider sizes/impulse
  strengths feel off — tune `force` after seeing it in-engine, and author collider
  sizes against the scaled result.
- **Corpse capsule interference:** solved already because `_die()` zeros the
  CharacterBody3D layer/mask; keep that ordering (disable body, then start sim).
- **Runtime generation crumple:** pin-jointed auto-generated bones collapse into a
  pile — reason we author joints once (§1) rather than generating at runtime.
- **Unbounded solver cost:** without the global cap, a grenade killing 6 men in
  one frame spikes the physics step. The `MAX_ACTIVE_RAGDOLLS` gate is the guard.

---

## Sources
- [Ragdoll system — Godot docs](https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html)
- [PhysicalBoneSimulator3D — Godot docs](https://docs.godotengine.org/en/stable/classes/class_physicalbonesimulator3d.html)
- [PhysicalBone3D — Godot docs](https://docs.godotengine.org/en/stable/classes/class_physicalbone3d.html)
- [Docs issue #100843 — physical_bones API moved to PhysicalBoneSimulator3D](https://github.com/godotengine/godot/issues/100843)
- [Active ragdoll in Godot 4.5 (forum: influence blend, keep anim active)](https://forum.godotengine.org/t/active-ragdoll-in-godot-4-5-how-to-achieve-good-results/128728)
- [Active Ragdoll / Physics Animations in Godot 4.0 (cberry22, MIT)](https://deepwiki.com/cberry22/active-ragdoll---physics-animations-in-godot-4.0)
