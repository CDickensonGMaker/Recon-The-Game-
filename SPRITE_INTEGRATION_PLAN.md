# Sprite Integration Plan — 8-Direction NPC Sprites

**Status:** planning only. No code written. Nothing in `scripts/` has been modified.
**Target:** Godot 4.6, Forward+. Replace the colored-capsule NPCs with the rendered sprite matrix.

---

## 0. Ground truth (verified, not assumed)

| Fact | Where | Consequence |
|---|---|---|
| NPCs are `MeshInstance3D` + `CapsuleMesh`, hardcoded `Color(0.4,0.4,0.3)` | `enemy_base.gd:238-250` | This is the single replace point. `enemy_data.color` is declared but ignored. |
| **No** `Sprite3D`, `AnimatedSprite3D`, `SpriteFrames`, `AtlasTexture` anywhere | grep across `scripts/ scenes/ terrain/` | Building from scratch. No competing code to reconcile. |
| Camera is **perspective, FOV 75, free-look mouse** | `scenes/player/player.tscn`, `player.gd:380-383` | Direction index must be computed **per-enemy, per-frame**. No fixed isometric yaw. Pitch clamps ±89°, so billboards must be **Y-locked**, not full-billboard. |
| `_execute()` runs **every frame**; `_think()` is LOD-throttled to 0.15–0.6s | `enemy_base.gd:294-318` | Sprite frame advance + direction select belong in `_process`/`_execute`, never `_think`. |
| `facing_dir` (line 76) is set by `_move_toward()` but the **node is never rotated** while moving | `enemy_base.gd:1023-1035` | Reading `global_transform.basis.z` gives the wrong angle while patrolling. Use `facing_dir`. |
| `look_at()` rotates the body only while aiming a target | `enemy_base.gd:782-817` | Both paths agree only in COMBAT. |
| `model_path` (`enemy_data.gd:28`) is **dead** — never read by any code | grep | Free to repurpose. |
| Two of four `.tres` are WW2 holdovers (`german_rifleman`, `german_smg`), and have **no uid** | `data/enemies/` | Delete or convert. |
| `_die()` takes **no arguments** | `enemy_base.gd:1328` | `death_forward` vs `death_from_right` cannot be chosen today. Requires threading the hit direction. |
| `character_height_m` = 1.7132, capsule = 1.8, HEAD hitzone @ y=1.65 | manifests vs `enemy_base.gd:253-287` | Anchor by `ground_row`, never by centering the quad. |
| `ground_row` = 143.53 of a 160px cell | manifests | ~16.5px of empty space below the feet, ~0.35 m of headroom above. |
| `vc6_heavy` (RPG-2) still rendering | 643/1280 frames at time of writing | Six of seven units are complete. Don't hard-code a 7-unit list yet. |

---

## 1. Architecture — three new files, four edits

Keep the sprite system **out of** `enemy_base.gd`. It's already 1407 lines. Give it one child node and a handful of calls.

```
scripts/visuals/
  sprite_manifest.gd     # class_name SpriteManifest  — loads + caches one action's .json
  sprite_library.gd      # class_name SpriteLibrary   — autoload; unit → {action → SpriteManifest}
  sprite_actor.gd        # class_name SpriteActor     — Node3D; owns the Sprite3D, picks dir + frame
```

**`SpriteActor` is the only thing that touches Sprite3D.** `EnemyBase` and `AllyBase` both call the same four methods:

```
actor.play(action_id)            # switch clip; respects loop / hold_last_frame
actor.set_facing(facing_dir)     # world-space forward vector
actor.get_muzzle_world()         # Vector3, from muzzle_px of the CURRENT dir + frame
actor.flash(color, seconds)      # replaces the mesh.material_override red flash
```

### Why `Sprite3D`, not a shader (initially)

The `_ALL.png` sheet is already an 8×8 grid, row 0 = `front`, column 0 = frame 0. That maps 1:1 onto `Sprite3D`:

```
hframes = 8            # columns == manifest.columns
vframes = 8            # directions
frame   = dir_index * 8 + col_index
```

No `.gdshader` needed. A shader only buys you cross-fade between direction rows and GPU-side frame select — neither is required to ship. **Defer the shader.** If you later want it, the manifest already carries everything it needs.

Required on the Sprite3D:
- `billboard = BaseMaterial3D.BILLBOARD_FIXED_Y` (not `BILLBOARD_ENABLED` — the camera pitches ±89° and full billboard will make sprites lean)
- `texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST`
- `alpha_cut = ALPHA_CUT_DISCARD` (so they write depth and don't sort-fight the foliage)
- `shaded = false` unless you want them lit; `no_depth_test = false`
- `pixel_size = m_per_px` from the manifest (**0.014375**) — do not eyeball it

---

## 2. Anchoring — get this right first, everything else depends on it

The quad is 160px tall but the character occupies only ~119px of it. Centering the sprite sinks him.

```
sprite.pixel_size = manifest.m_per_px                    # 0.014375
feet_offset_px    = (cell_h / 2.0) - manifest.ground_row # 80 - 143.53 = -63.53
sprite.offset.y   = -feet_offset_px                      # push the quad up so ground_row lands at y=0
sprite.position   = Vector3.ZERO                         # SpriteActor sits at the CharacterBody3D origin
```

**Acceptance test:** spawn one enemy on flat ground next to the player capsule. His feet must touch the ground plane and his head must land at ~1.71 m. If he floats or sinks, `ground_row` handling is wrong — fix it before touching anything else.

Leave the hitzones (`enemy_base.gd:253-287`) exactly where they are. They define the real hit silhouette and already match: HEAD @ 1.65 vs `character_height_m` 1.7132.

---

## 3. Direction selection

```
to_cam  = camera.global_position - enemy.global_position
to_cam.y = 0
facing  = enemy.facing_dir  (fallback: -enemy.global_transform.basis.z)
angle   = atan2(to_cam.x, to_cam.z) - atan2(facing.x, facing.z)
dir_idx = wrapi(roundi(angle / (TAU / 8.0)), 0, 8)
```

`dir_idx == 0` must render the enemy **facing the camera** — that's `front`, row 0 of `_ALL.png`, per `combined_row_order_top_to_bottom`.

**Verify empirically, don't trust the sign.** Spawn one enemy, strafe a full circle around him, confirm the sprite rotates the correct way. Getting this mirrored is the single most likely bug, and it looks *almost* right — enemies will appear to walk backwards.

Camera reference: `get_viewport().get_camera_3d()`. Cache it per-frame at the manager level, not per-enemy — with 30 enemies that's 30 redundant lookups.

---

## 4. AIState → clip mapping, and the holes in it

`_change_state()` (`enemy_base.gd:1013-1018`) is the single funnel. It emits `state_changed`. **Connect `SpriteActor` to that signal** rather than polling.

| AIState | Clip | Notes |
|---|---|---|
| `IDLE` | `rifle_aiming_idle` (standing) / `start_walking` (patrolling) | `_execute_idle` patrols when `patrol_route` is non-empty — needs a **looping walk**, which we don't have. See gap below. |
| `ALERT` | `start_walking` | walking to `last_known_target_pos` |
| `COMBAT` | `firing_rifle` while `can_fire == false`, else `rifle_aiming_idle` | fire is hitscan + burst; drive the clip off the fire timer |
| `SUPPRESSED` | `stand_to_cover` → hold | |
| `SEEKING_COVER` | `run_forward` | |
| `FLANKING` | `run_forward` | |
| `ADVANCING` | `run_forward` | |
| `RETREATING` | `injured_walk_backwards` | |
| `DEAD` | `death_forward` / `death_from_right` | see §6 |

**Not states — flags and side effects. These need separate hooks:**

| Thing | Where | Clip |
|---|---|---|
| `is_crippled` | `enemy_base.gd:1271-1273` (squashes the mesh) | `injured_walk_backwards`, or slow the fps |
| `is_surrendered` | `enemy_base.gd:1347-1374` (recolors the mesh) | **no clip exists** — need one |
| hit flinch | `enemy_base.gd:1250-1314` — it's a *fire-rate stall*, not an animation | **no clip exists** |
| reloading | never a state; `fire_timer` only | `reloading` clip exists but nothing triggers it |

### Clip inventory vs. what the AI needs

**We have, unused:** `brutal_assassination`, `sitting`, `swimming`, `rifle_turn`, `kneeling_pointing`, `laying_breathless`, `stop_walking_with_rifle`, `action_idle_to_standing_idle`, `rifle_crouch_idle_to_walk`.

**We need, and don't have:**
- **looping walk** — `start_walking` is a one-shot transition (71 source frames, `hold_last_frame: true`). Patrol needs a cycle.
- **flinch / hit reaction**
- **surrender pose**
- **crouch walk**, **prone / crawl**

`strafe` and `strafe_1` are the two strafe directions (confirmed — all 64 frames differ). Not duplicates.

**Recommendation:** ship with the mapping above, accept that patrol uses `run_forward` at reduced fps as a stand-in, and derive the missing clips later with `tools/derive_actions.py` (it already does reverse / splice / bone-offset / hold). A looping walk is a splice job, not a Mixamo trip.

---

## 5. Weapons and firing — the wiring you asked about

### What exists

`_fire_at_target()` (`enemy_base.gd:1118-1205`) is **hitscan, not projectile**. It calls `get_muzzle_position(final_aim)` once at line 1152 and feeds that single `origin` to five consumers (lines 1163-1172):

1. `BulletTracer.spawn_tracer(scene, origin, tracer_end, Color(0.4,1.0,0.5,1.0))`
2. `NoiseBus.emit_noise(GUNSHOT, origin, 1)`
3. `GunFX.play_shot_3d(scene, origin, weapon_data.resource_path)`
4. `GunFX.muzzle_flash(scene, origin)`
5. `GunFX.impact(...)` on hit

**Fix `get_muzzle_position()` and all five follow for free.** It has exactly one caller.

### Current implementation (`enemy_base.gd:1240-1243`)

```gdscript
func get_muzzle_position(aim_dir: Vector3) -> Vector3:
	var flat_aim := Vector3(aim_dir.x, 0.0, aim_dir.z).normalized()
	var right := flat_aim.cross(Vector3.UP).normalized() * -0.22
	return global_position + Vector3.UP * 1.35 + flat_aim * 0.55 + right
```

Three magic numbers: `1.35` shoulder height, `0.55` forward push, `-0.22` right-hand lateral. The comment on line 1239 already anticipates this work: *"Sprite states will refine per-frame offsets later (R21/R28)."*

### Replacement

`muzzle_px[dir][col]` gives the barrel tip in cell pixels, y measured from the **top** of the cell. Convert to a world offset from the enemy's feet:

```
lateral_m = (muzzle_px.x - cell_w / 2.0) * m_per_px      # +x = sprite's screen-right
height_m  = (ground_row  - muzzle_px.y) * m_per_px       # above the feet
```

The lateral term is in **screen space** — it must be rotated into world space along the camera-right vector, not the enemy's right, because the sprite is Y-billboarded toward the camera:

```
cam_right = camera.global_transform.basis.x  (flattened, normalized)
muzzle_world = enemy.global_position
             + Vector3.UP * height_m
             + cam_right  * lateral_m
```

Cross-check with `firing_rifle`, dir 0 (front), col 0 → `[74.61, 57.91]`:
- lateral = `(74.61 - 64) × 0.014375` = **+0.153 m**
- height = `(143.53 - 57.91) × 0.014375` = **1.231 m**

Against the hardcoded `1.35` / `-0.22`. Same ballpark — swapping in manifest data will not visibly break tracers, which means **this can be done incrementally and verified by eye.**

### Caveat worth knowing before you build it

At sharp angles the barrel tip is *behind* the enemy's origin in world Z, and the hitscan ray starts at `origin` with `exclude = [self]`. If the muzzle lands behind a wall the enemy is peeking around, the ray now starts inside the wall and the shot eats geometry. The current fixed `+0.55` forward push masks this. **Keep a forward bias:** after computing `muzzle_world`, push it along `flat_aim` by ~0.2 m, or clamp the result to be no further than 0.1 m behind the enemy's origin along the aim axis. Test this at 45° and 135° to the camera specifically.

### Weapon → sprite pairing

Each unit folder is `<unit>/<weapon>/`, one weapon per unit. That's a **hard pairing baked into the render** — `us_grunt` only ever holds an M16A1, `vc5_nva` only a PPSh-41. There is no runtime weapon swap on the sprite.

Meanwhile `enemy_data.weapon_path` points at a `WeaponData` `.tres` that drives fire rate, spread and range. These two must be kept consistent by hand. `nva_regular.tres` currently uses `ak47.tres` but the closest sprite is `vc5_nva/ppsh41`. **Either re-render `vc5_nva` with an AK, or repoint the `.tres` at `sks.tres`/`ppsh41.tres`.** Do not let the sprite show a PPSh while the ballistics say AK — that's the kind of thing nobody notices for six months and then can't unsee.

---

## 6. Death, and the directional-death problem

`_die()` (`enemy_base.gd:1328-1342`) takes no arguments and does `mesh.rotation_degrees.x = 90` — the capsule tips over.

We shipped `death_forward` **and** `death_from_right`. Nothing can select between them, because the hit direction is known in `take_damage(amount, type, attacker)` and thrown away before `_die()` is called.

**Minimal change:** store the last hit direction on the enemy in `take_damage`, read it in `_die()`.

```
# in take_damage, when attacker is valid:
last_hit_dir = (global_position - attacker.global_position).normalized()

# in _die():
var from_right := last_hit_dir.dot(global_transform.basis.x) > 0.35
actor.play("death_from_right" if from_right else "death_forward")
```

Both clips have `loop: false, hold_last_frame: true`, so the corpse holds its final frame for the 45 s before `queue_free`. Also: `_die()` sets `collision_layer = 0` and `set_physics_process(false)` — the SpriteActor must therefore advance its own frames in `_process`, not `_physics_process`, or the death animation freezes on frame 0.

Only two death directions exist. A shot from the left will play `death_from_right` mirrored-wrong, or `death_forward`. Accept it, or derive a `death_from_left` with `derive_actions.mirror()`.

---

## 7. Data model changes

`enemy_data.gd:28` — replace the dead `model_path` with three fields the loader can resolve:

```gdscript
@export_group("Visuals")
@export var sprite_faction: String = ""   # "Vietcong and NVA"
@export var sprite_unit: String = ""      # "vc1_farmer"
@export var sprite_weapon: String = ""    # "ak47"
```

Resolving to `res://assets/NPCs/{faction}/{unit}/{weapon}/{action}/`.

Prefer three fields over one path string: the loader needs the unit id anyway for cache keys, and a single path invites typos that fail silently at runtime.

Then, in `data/enemies/`:

| `.tres` | Action |
|---|---|
| `nva_regular.tres` | → `vc5_nva` / `ppsh41`. **Also fix `weapon_path`** — currently `ak47.tres`. |
| `vc_rifleman.tres` | → `vc1_farmer` / `ak47`. `weapon_path` is `sks.tres`; sprite holds an AK. Pick one. |
| `german_rifleman.tres` | **Delete.** WW2 holdover, no uid. |
| `german_smg.tres` | **Delete.** WW2 holdover, no uid. |

Then add `.tres` files for the units that have no data yet: `us_grunt`, `us_grunt_black`, `vc2_mainforce`, `vc3_sapper`, `vc6_heavy`. Note `us_grunt` and `us_grunt_black` are **allies**, not enemies — they belong to `ally_base.gd`.

Also wire `enemy_data.color` (line 29), currently ignored, or delete it too.

---

## 8. Allies

`scripts/allies/ally_base.gd` has an identical `_setup_visual()` at lines 87-99, plus the same mutation sites (hit flash 452-456, death tip-over 483-484). Same `SpriteActor`, same treatment. `us_grunt` (M16A1) and `us_grunt_black` (M60) are the two ally sprites.

Do enemies first, get one enemy on screen and correct, **then** copy across. Don't do both at once.

---

## 9. Order of work

1. **`SpriteManifest`** — load one JSON, expose typed fields. Unit-test the muzzle math against the known value above (`[74.61, 57.91]` → `+0.153 m`, `1.231 m`).
2. **`SpriteActor`** — Sprite3D child, anchoring by `ground_row`, one hardcoded clip, no direction logic. **Acceptance: he stands on the ground at the right height.**
3. **Direction select.** **Acceptance: strafe a circle, he rotates the right way.**
4. **Frame advance** from `fps` / `loop` / `hold_last_frame` in `_process`.
5. **Swap `_setup_visual()`** in `enemy_base.gd`. Fix the four `mesh` mutation sites (1259, 1271, 1338, 1363) — they all assume `MeshInstance3D.material_override`.
6. **Connect `state_changed`** → `actor.play(clip)`. Ship the mapping in §4.
7. **`get_muzzle_position()`** → manifest-driven. Keep the forward bias. Verify tracers at 45° and 135°.
8. **Directional death** — thread `last_hit_dir`.
9. **`SpriteLibrary` autoload** + cache. 30 enemies must share one `Texture2D` per action, not load 30 copies.
10. **Data model** — `.tres` rewrite, delete the German pair.
11. **Allies.**

Steps 1–4 are pure addition and can't break anything. Step 5 is the first destructive one.

---

## 10. Traps

- **`spider_hole`** (`enemy_base.gd:131-135`) sets `visible = false` on the CharacterBody3D root. A Sprite3D child inherits that correctly. No change needed — but don't "fix" it by toggling the mesh directly.
- **`try_surrender()`** calls `set_physics_process(false)`. If frame advance lives in `_physics_process`, surrendered enemies freeze mid-animation. Use `_process`.
- **`default_texture_filter=0`** in `project.godot` governs 2D canvas only. You must still set `TEXTURE_FILTER_NEAREST` on the Sprite3D or the sprites will be blurry in 3D.
- **`scaling_3d/scale=0.77`** — the game renders at 77% and upscales. Pixel-art sprites will get resampled. Check how bad it looks before committing to the palette work; you may want the sprites rendered at a higher cell size, or FSR off.
- **Think-LOD** throttles `_think()` to 0.6s beyond 150 m. Frame advance in `_execute`/`_process` is unaffected, but if you ever move sprite logic into `_think`, distant enemies will animate at 1.6 fps.
- **`Enums` is not an autoload.** It's `class_name Enums extends RefCounted`. The autoloaded `GameEnums` is a different file with no `AIState`.
- **`_ALL.png` is 1024×1280.** Seven units × 20 actions = 140 of them, ~135 KB each. Load lazily per unit, cache in `SpriteLibrary`, never preload all.
- **`.import` files already exist** for all 6 completed units and are lossless/nearest-friendly. Don't regenerate them.

---

## 11. Open decisions for you

1. **Patrol walk.** Ship with `run_forward` at reduced fps, or derive a looping walk first? (Derivation is ~20 min with `derive_actions.py`.)
2. **`vc5_nva` weapon mismatch.** Re-render with an AK, or repoint `nva_regular.tres` at a PPSh `WeaponData`?
3. **`scaling_3d/scale=0.77`** vs pixel-art fidelity. Worth a look before more art work.
4. **Missing clips** — flinch, surrender, crouch-walk, prone. All derivable. Which matter for the first playable?
