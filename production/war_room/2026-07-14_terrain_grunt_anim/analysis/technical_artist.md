# Technical-Artist Analysis — Shared Animation Library Contract

**Scope:** `ModelActor` loading/merging logic, the rigs it requires, the current US character exports, and a verification probe to prove any unit plays the canonical clips.

---

## 1. What `ModelActor` does to load and merge the shared animation library

The shared library is loaded once per process and reused as a refcounted `AnimationLibrary` Resource.

| Function | File | Line | What it does |
|----------|------|------|--------------|
| `setup(unit_id)` | `model_actor.gd` | 89 | Instantiates the unit `.glb`, grabs its `AnimationPlayer` and `Skeleton3D`, then calls `_normalize_height()`, `_merge_shared_library()`, `_apply_loop_modes()`, `_apply_gib_rig_contract()`, `_apply_optional_gear()`, `_apply_psx_filtering()` in that order (lines 99–107). |
| `_load_shared_library()` | `model_actor.gd` | 165 | Static loader. Checks `ResourceLoader.exists(ANIM_LIBRARY_PATH)` (line 169), instantiates the packed `anim_library.glb` scene (line 175), finds its `AnimationPlayer` (line 176), and caches `ap.get_animation_library("")` in `_shared_lib` (line 179). The instance is freed immediately; the Resource outlives it. |
| `_merge_shared_library()` | `model_actor.gd` | 187 | Merges cached library clips into the character's own `AnimationPlayer`. Bails if `PSXRig/Skeleton3D` is missing (line 194). If the mesh-only export has no `AnimationPlayer`, it creates one beside the rig with `root_node = NodePath("..")` (lines 201–204). Then it adds the default `AnimationLibrary` if absent and copies every clip from `_shared_lib` that the character does not already own (lines 212–215). |

Key ordering note: `_merge_shared_library()` is deliberately called **before** `_apply_loop_modes()` (line 102 vs. 103). The comment at line 186 warns that doing it in the opposite order would leave borrowed cyclic clips as play-once, freezing them on their last frame.

The library path is `res://assets/shared/anim_library.glb` (line 160), currently 4.6 MB and imported as a PackedScene at 30 fps with `animation/import=true` (`.import` lines 33–36).

---

## 2. Loop modes, aliases, and locomotion speed matching

### Loop modes
`_apply_loop_modes()` (line 246) sets `Animation.LOOP_LINEAR` on cyclic clips; everything else stays play-once.

- **Prefix heuristic** (`_LOOP_PREFIXES`, line 239): `idle`, `run`, `walk`, `sprint`, `strafe`, `swim`, `firing`.
- **Explicit named loops** (`_LOOP_NAMES`, line 243): `injured_walk_backwards`, `kneeling_pointing`, `sitting`, `cockpit_idle`.
- **Explicitly excluded** (line 256): clips containing `turn`, `_to_`, or `jump` are skipped so one-shot transitions stay one-shot.
- Special exception: `laying_breathless` is deliberately left play-once (comment at line 242).

### Aliases
`play(clip)` (line 543) resolves intent names through `SpriteStateMap.MODEL_ALIASES` when a clip is missing:

1. If `_anim.has_animation(clip)` is false, strip a weapon-family suffix (`__smg`, etc.) at lines 551–554.
2. Still missing: walk `SpriteStateMap.MODEL_ALIASES.get(clip, [])` and pick the first alias the rig actually has (lines 556–559).
3. If the resolved clip is already playing and `restart == false`, it is a no-op (lines 546, 553, 562).

`clip_length(clip)` (line 587) performs the same alias resolution so callers like `AllyBase._execute_seeking_cover()` (ally_base.gd:568) can size override windows from the actual clip length.

### Locomotion speed matching
`set_locomotion_speed(mps)` (line 614) scales playback rate so feet match ground speed:

- `_CLIP_SPEED` dictionary (line 601) maps authored loop names to m/s, e.g. `run_forward = 4.2`, `sprint_forward = 5.5`, `walk_forward = 1.6`, `injured_walk_backwards = 1.2`.
- If the current clip has an entry, `_anim.speed_scale = clampf(mps / ref, 0.6, 1.4)` (line 619).
- Non-locomotion clips reset `speed_scale` to 1.0 (line 621).

`AllyBase._update_sprite()` and `EnemyBase._update_sprite()` both call `set_locomotion_speed(speed)` whenever the visual is a `ModelActor` (ally_base.gd:271, enemy_base.gd:410), so every moving unit gets automatic foot-planting.

### Phase preservation across loop switches
`play()` preserves cycle phase when switching from one looping clip to another (lines 568–576). It samples `current_animation_position / current_animation_length`, wraps it with `fposmod(..., 1.0)`, and seeks the new clip to the same normalized phase. This keeps feet planted when switching `walk` → `run` → `strafe`.

---

## 3. Rigs/exports that break the shared-library contract

The shared library's track paths are authored against `PSXRig/Skeleton3D:mixamorig_*`. Three export defects break this silently:

1. **Wrong armature node name** — `model_actor.gd:194` explicitly checks `_inst.get_node_or_null("PSXRig/Skeleton3D")`. If the armature is not named `PSXRig` or the skeleton is not a child named `Skeleton3D`, `_merge_shared_library()` returns early and the character T-poses. The comment at lines 156–159 calls this "the rig name contract."

2. **Missing Mixamo skeleton / wrong bone names** — `_normalize_height()` (lines 119–122) looks for `mixamorig_HeadTop_End` and `mixamorig_LeftToeBase` (fallback `mixamorig_LeftFoot`). A non-Mixamo rig falls back to AABB normalization (lines 143–149) and the library's bone tracks resolve to nothing.

3. **Mesh-only export without an `AnimationPlayer`** — handled defensively by creating one (lines 199–204), but only if the rig path matches `PSXRig/Skeleton3D`.

4. **Medic rig exception already known** — `ANIM_WISHLIST.md:34` (item C3) documents that `export_medic_gltf.py` targets `MixamoRig`, not `PSXRig`, so `us_medic.glb` is currently an explicit contract breaker unless the exporter is renamed or the medic is declared standalone.

---

## 4. Models in `assets/us/characters/` that look like they won't take the shared library

Directory listing (GLB files only):

- `us_grunt_grenadier.glb`
- `us_grunt_m14.glb`
- `us_grunt_m60.glb`
- `us_grunt_m79.glb`
- `us_grunt_marksman.glb`
- `us_grunt_mg.glb`
- `us_grunt_pointman.glb`
- `us_grunt_rifleman.glb`
- `us_grunt_rto.glb`
- `us_grunt_v2.glb`
- `us_grunt_v3.glb`
- `us_medic.glb`
- `us_pilot_black.glb`
- `us_pilot_white.glb`
- `us_rto.glb`

Cannot tell from the file list alone which ones violate the `PSXRig` naming contract. The most likely suspect is `us_medic.glb` because `ANIM_WISHLIST.md` explicitly flags the medic exporter as targeting the wrong rig name. The v2/v3 grunts are the reference exports; the MOS variants (grenadier, mg, marksman, etc.) are expected to inherit the same export pipeline.

To confirm, the exporter scripts in `tools/export_*.py` must be checked, or each GLB must be opened in-engine and inspected for the `PSXRig/Skeleton3D` node path.

---

## 5. Verification probe to prove an arbitrary unit plays idle/run/fire/death clips correctly

A runtime probe should:

1. Iterate `ModelActor.all_units()` (model_actor.gd:34) to get every unit_id on disk.
2. For each unit, instantiate `ModelActor`, call `setup(unit_id)`, and assert it returns `true` and `_anim != null`.
3. Assert `instance.get_node("PSXRig/Skeleton3D")` exists — this is the contract gate at line 194.
4. For each canonical clip in `["idle", "run_forward", "firing_rifle", "death_forward"]`:
   - Call `play(clip, true)` and assert it returns `true`.
   - Assert the clip is present via `has_clip()` (line 629) or `clip_names()` (line 368).
   - For `idle` and `run_forward`, assert `a.loop_mode == Animation.LOOP_LINEAR` after `_apply_loop_modes()`.
   - For `death_forward`, assert `loop_mode` is **not** looping (one-shot).
5. For locomotion speed matching:
   - Play `run_forward`, call `set_locomotion_speed(4.2)`, assert `_anim.speed_scale` is approximately 1.0.
   - Call `set_locomotion_speed(2.1)`, assert speed_scale is approximately 0.5 and clamped inside `[0.6, 1.4]` per line 619.
6. Print/report any unit that fails so the export pipeline can be fixed before the Summoner's "all models have their real animations" requirement is considered satisfied.

This probe can live alongside `tools/list_clips.gd` (referenced in `ANIM_WISHLIST.md:6`) and should be run after any re-export to catch regressions in the `PSXRig` contract.

---

## Summary for the Council

`ModelActor` already has the machinery the Summoner is asking for: it loads `anim_library.glb` once, merges missing clips into every unit's `AnimationPlayer`, fixes loop modes, resolves aliases through `SpriteStateMap`, and matches playback rate to ground speed. The remaining work is not engine code; it is **export hygiene**. The medic exporter and any rig that does not produce `PSXRig/Skeleton3D` must be corrected, and a per-unit probe must prove that idle/run/fire/death clips resolve and loop correctly before the roster is declared wired.
