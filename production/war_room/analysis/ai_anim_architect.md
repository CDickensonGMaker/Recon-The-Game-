# AI & Animation Architect — Defects 4, 5, 6 (2026-08-11 playtest sweep)

Read-only diagnosis. Every claim carries a pointer. No code was edited.

---

## DEFECT 5 — corpses fall, then SNAP BACK UP to standing (root cause first: it explains 6 too)

### The death path, as wired

- Clean kill (the common case): `EnemyBase._die()` → `ma.start_ragdoll(last_hit_dir, 4.5)`
  (`scripts/enemies/enemy_base.gd:2743-2745`). Explosive kills also end in a ragdoll via
  `GibSystem.explosion_kill` (`enemy_base.gd:2741-2742`). Allies identical
  (`scripts/allies/ally_base.gd:1740-1766`). So the ragdoll path carries nearly every kill.
- `start_ragdoll()` pauses the clip (`stop_anim()` = `_anim.pause()`,
  `scripts/visuals/model_actor.gd:676-678, 773`), starts `PhysicalBoneSimulator3D`
  (`model_actor.gd:785`), and arms a settle timer: after `RAGDOLL_SETTLE_S = 4.0`
  (`model_actor.gd:732`) it calls `sleep_ragdoll()` then `ground_current_pose()`
  (`model_actor.gd:794-801`).
- `sleep_ragdoll()` "bakes" the fallen pose by reading `_skel.get_bone_global_pose(bi)` for
  every bone, then calls `physical_bones_stop_simulation()`, then writes those poses back
  (`model_actor.gd:700-716`).

### The root cause

`PhysicalBoneSimulator3D` is a **SkeletonModifier3D** in Godot 4.3+. Modifier output is
applied in the deferred skeleton update and is **never written into the bone poses**.
`Skeleton3D.get_bone_global_pose()` is documented to return *"the global pose you set to the
skeleton in the process; the final global pose can get overridden by modifiers in the deferred
process — if you want to access the final global pose, use
`SkeletonModifier3D.modification_processed`"* (Godot stable docs, Skeleton3D, verified
2026-08-11).

So while the corpse visibly ragdolls to the ground, the underlying bone poses still hold the
**death-moment animation frame** — the standing/running pose the paused AnimationPlayer left
behind (`stop_anim()` pauses, it does not clear, `model_actor.gd:676-678`). The "bake" at
`model_actor.gd:705-708` therefore reads the standing pose and writes the standing pose back —
a no-op. The instant `physical_bones_stop_simulation()` runs (`model_actor.gd:709`), the
modifier stops overriding and the skeleton renders its bone poses again: **the corpse snaps
upright to its death-moment pose, exactly 4.0 s after every ragdolled kill.**

The code's own header comment (`model_actor.gd:695-699`) names this precise failure mode as
the thing the bake was added to fix (2026-08-04 floating-corpse report) — the fix was built on
`get_bone_global_pose()`, which by contract cannot see the simulated pose, so the bug it was
burying is still alive. `ground_current_pose()` (`model_actor.gd:820-836`) reads the same
pre-modifier poses, so after the revert it measures a *standing* skeleton whose toes are
already at floor height and shifts nothing — the corpse stands on its feet, dead.

### Why the non-ragdoll paths are (mostly) clean, confirming the ragdoll as the culprit

- Death **clips** are one-shot: glTF clips import play-once, and no `death*` name is in the
  loop lists (`model_actor.gd:334-368`); a finished one-shot holds its last frame.
- Nothing replays idle on a corpse: `_update_sprite()` hard-returns on DEAD
  (`enemy_base.gd:532-533`), `_die()` disables physics processing
  (`enemy_base.gd:2709`, `civilian.gd:697`), and the 1.5 s `settle_flat_corpse()` guard skips
  any body that has a ragdoll (`enemy_base.gd:2770-2774`, `model_actor.gd:843-845`).
- Corner case worth noting while in here: `settle_flat_corpse()` re-poses via the FIRST
  alphabetical `death*` clip (`model_actor.gd:847-849`), not the clip that actually played — a
  small visible pose pop on capped-ragdoll kills, but it ends lying, not standing.
- Civilian oddity, same neighborhood: `Civilian._die()` plays a death clip AND pitches the
  whole CharacterBody 90° (`scripts/world/civilian.gd:712-713`) — a capsule-era fossil that
  double-lays garrison/villager corpses. Not the snap-up, but it breaks those kills too.

### Proposed fix (exact insertion point)

`model_actor.gd:700-716` (`sleep_ragdoll`): bake from the **physics bodies**, not from
`get_bone_global_pose()`. For each `PhysicalBone3D` child of `_ragdoll_sim`, compute the
bone's skeleton-space pose from the body's `global_transform` (mirroring what the engine's
modifier applies: `skel.global_transform.affine_inverse() * pb.global_transform *
pb.body_offset.affine_inverse()`), write it with `set_bone_pose_*`, THEN call
`physical_bones_stop_simulation()`. Non-simulated child bones keep their locals and ride their
baked parents.

Stronger variant (also fixes defect 6 and corpse hitzones in one move): while
`_ragdoll_sim.is_simulating_physics()`, copy the physical-bone transforms into the bone poses
**every physics frame** (a `_physics_process` on ModelActor, active only during the ≤4 s
simulate window, ≤12 concurrent by `MAX_ACTIVE_RAGDOLLS`, `model_actor.gd:731`). Then
`sleep_ragdoll` needs no bake at all, and every consumer of bone poses — `BoneAttachment3D`
gear, `HitzoneBuilder.sync` on corpses (`enemy_base.gd:705-711`, currently syncing hitzones to
the standing ghost, so shooting a ragdolling corpse hits air), `ground_current_pose`,
`_pose_span_y` — sees the real fallen pose.

**Sacrifice:** per-frame pose writes for up to 12 simulating corpses (~50-60 bones each) for
4 s per death — a real but bounded cost; and the modifier now applies on top of bone poses it
itself produced (idempotent, but it forfeits the "modifiers never touch poses" purity).

---

## DEFECT 6 — the belt that came off the corpse

### How gear attaches (three different mechanisms on the rosters)

1. US grunt webbing/gear: **skinned into the character GLB** and hidden/shown by name
   (`model_actor.gd:400-427, 434-485`). Skinned gear renders with the final (modifier) pose —
   it follows the ragdoll correctly.
2. Helmets and gib gear: donor meshes thrown by GibSystem; belts are NOT in any gib gear list
   (only `helmet_camo_shell`/`helmet_bugjuice`, `scripts/combat/gib_system.gd:23-52`) — gibs
   are not the belt's story.
3. NVA/VC belts: **hung on a `BoneAttachment3D`** on `mixamorig:Hips`
   (`scripts/visuals/vc_nva_dresser.gd:347-361` `_rehang_belt` → `_hang` builds the
   attachment at `:458-461`). Same pattern for headgear/packs/chest rigs.

### Root cause — same disease as defect 5, seen from the gear's side

`BoneAttachment3D` updates from the skeleton's **bone pose**, and its own docs warn it "may
cause unintended behavior when used at the same time with SkeletonModifier3D" (Godot stable
docs, BoneAttachment3D.override_pose note, verified 2026-08-11). During the ragdoll window the
bone poses still hold the standing death-moment frame (defect 5 evidence above), so:

- the **skinned body** (modifier-driven) collapses to the ground, while
- the **belt on the BoneAttachment3D** stays hung at the *standing* hips position, ~1 m in the
  air — "the belt came off";
- at the 4 s settle the body snaps back up INTO the belt (defect 5), or, had the bake worked,
  the belt would teleport down onto the corpse — weird either way.

This is the defect-5 root cause, not a modelling error: the attachment reads poses the ragdoll
never writes. Any dresser-hung piece (NVA/VC headgear, packs, chest rigs — `vc_nva_dresser.gd:196`,
and GruntDresser's hung helmet variants, `scripts/visuals/grunt_dresser.gd:262`) detaches the
same way on any ragdolled death; the belt is just the piece Caleb noticed.

### Proposed fix

The per-frame ragdoll→bone-pose bake from defect 5's "stronger variant" fixes this outright —
attachments follow bone poses, and the bone poses would finally track the simulation. No
gear-side change needed. If only the settle-time bake is done (cheap variant), the belt still
floats for the 4 s simulate window; name that residue if the cheap variant is chosen.

**Sacrifice:** none beyond defect 5's cost; the two defects are one fix.

---

## DEFECT 4 — villagers and VC stuck inside buildings

### The navigation architecture, as built

- Navmesh is baked per stamped site, not per chunk (`scripts/world/nav_baker.gd:1-27`).
  Village huts are carved out of the mesh as their **whole authored footprint box**, inflated
  by agent radius (`nav_baker.gd:441-469`, inflate at `:458`), via `nav_blockers` +
  `nav_box` meta set in `SitePlanner.place_structure`
  (`scripts/world/site_planner.gd:176-191`).
- But the village set is **deliberately enterable**: every village GLB is trimesh-collided
  precisely so "a box hull would [not] seal the doorway the generator verified you can walk
  through" (`scripts/world/collision_table.gd:9-37`). And even `mesh: true` structures still
  carve their full box out of the navmesh (`site_planner.gd:184-185` — "the box entry above
  still drives the nav carve").
- **Contradiction:** physics lets an NPC walk in through the door; the navmesh says the entire
  building, doorway included, does not exist. Any NPC inside a village building is off-mesh by
  design, with no path out.

### How they get inside

1. **Teleports.** `Civilian.place_for_current_hour()` sets `global_position = target` with no
   navmesh or collision check (`scripts/world/civilian.gd:993-1004`), at first tick
   (`:330-333`) and on every wake from LOD_FAR (`:975-976`). Targets are `home ± 3 m` random
   jitter (`:1014`) or a work marker + 1.5 m ring (`_bt_settle`, `:1083-1094`) — with huts
   4-16 m wide (`collision_table.gd:12-37`), those jittered points routinely land inside a
   footprint. The router's own header already documents work posts sitting "inside a bunker
   footprint... 5-8 m off walkable ground" (`scripts/ai/nav_router.gd:33-37`).
2. **Direct steering through real doorways.** Civilians route ONLY at LOD_FULL; past 80 m the
   step is a straight line (`civilian.gd:662-663`). FLEE is a straight line away from the
   threat (`civilian.gd:380-386`). A navmesh exists at a village only if an enemy anchor is
   within radius+60 m at generation (`nav_baker.gd:109-117` `should_bake`) — a quiet village
   has NO region, so `box = -1` and every villager direct-steers all day (`nav_router.gd:59`).
   Straight lines pass through open doorways; the trimesh colliders let the body follow.
3. **VC:** same `NavRouter` (`nav_router.gd:1-9`), same carve. A VC pushed inside a hut while
   assaulting (or spawn-adjusted, or chasing a target behind a hut off-region) is in the same
   trap. At the firebase the bake uses real colliders so interiors ARE walkable there
   (`nav_baker.gd:30-43, 374-399`), but doorways survive only if wider than ~2×`AGENT_RADIUS`
   0.5 m after 0.25 m cell quantization (`nav_baker.gd:264-269`) — narrow hootch doors erode
   shut. (Retest dependency: the pending firebase export changes this geometry.)

### Why they never get OUT

Off-mesh recovery is a straight line to the nearest mesh point
(`nav_router.gd:106-113`) — and for a man inside a carved footprint, the nearest mesh point is
through the wall next to him, not through the door. `move_and_slide` pins him there. The
target clamp does the mirror image for men OUTSIDE trying to reach an interior point: it pulls
the destination to the outer wall (`nav_router.gd:84-92`), where they press forever.
And in `Civilian._step_toward`, a recovery vector shorter than 1 m zeroes velocity entirely
(`civilian.gd:662-671`) — a villager just inside a wall stands still, permanently.

### Existing stuck/unstick logic

Enemies and allies have a 1 s stuck watchdog that sidesteps 0.6 s, alternating sides
(`scripts/enemies/enemy_base.gd:198-218`, `scripts/allies/ally_base.gd:55-70`). It cannot find
a doorway — inside a hut it oscillates against interior walls. **Civilian has no unstick logic
at all** (no counterpart anywhere in `civilian.gd`).

### Proposed fix (logic-level; nav geometry retest deferred to the new firebase export)

1. **Never teleport into a carved footprint.** In `place_for_current_hour()`
   (`civilian.gd:993-1004`) and `_resolve_target()` (`civilian.gd:1007-1014`): after computing
   the target, clamp it with `NavigationServer3D.map_get_closest_point()` when a region covers
   it (the same call NavRouter already uses, `nav_router.gd:86`), or at minimum reject points
   inside any `nav_blockers` box (group + `nav_box` meta are queryable). Same guard on
   `_bt_settle`'s jitter ring (`civilian.gd:1090`).
2. **Port the unstick watchdog to Civilian** (copy of `enemy_base.gd:204-218`, ticked from
   `_physics_process` near `civilian.gd:390`), plus an escalation the soldiers should get too:
   if still stuck after ~3 alternations AND off-mesh AND not `CombatManager.perceivable`,
   snap the body to `_self_out` (the cached nearest-mesh point, `nav_router.gd:106-109`).
   An unwatched rescue teleport is the honest cure for a man the geometry has already eaten.
3. **Stop steering fleeing villagers through doorways:** in FLEE (`civilian.gd:380-386`),
   clamp the flee target onto the navmesh when a region exists, so the escape vector bends
   around buildings instead of through them.

**Sacrifices:** (1) trades "man stands exactly on his authored marker" for "man stands at the
nearest walkable point" — interior work markers (aid station, mess) will drift to the wall
outside village huts; acceptable in villages, and the firebase is unaffected (its interiors
are on-mesh). (2)'s rescue teleport is a simulation lie, gated on non-perceivability so it is
never seen. (3) means villagers no longer take shortcuts through their own homes — slightly
longer flee paths. The doorway-width question at the firebase cannot be signed off until the
pending export lands: **retest defect 4 after the new firebase bake.**
