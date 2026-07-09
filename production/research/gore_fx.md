# Gore FX Research & Plan — RECONgame (Godot 4.6)

Retro PSX/low-poly Vietnam FPS. Goal: turn the current single red-CPU-particle
"blood" into a full gore layer (surface splats, textured spray, ground pools,
enemy/ally blood, optional gibs) **without forking `GunFX`** — every addition is a
new static func or an extension of the existing Decal pipeline in
`scripts/combat/gun_fx.gd`.

Aesthetic rule: keep it *readable and stylized*, not photoreal. Hard-edged dark
splats, low particle counts, short lifetimes, alpha-scissor (dithered) edges to
match the PSX look. Cheap first, pretty second.

---

## 0. What already exists (verified reuse points)

`scripts/combat/gun_fx.gd` — `class_name GunFX extends RefCounted`, all-static API:

| Func | Line | What it does | Reuse for gore? |
|------|------|--------------|-----------------|
| `blood(parent, pos, normal)` | 174 | 14 red CPU particles + wet tick, 0.7s | **UPGRADE in place** — keep signature |
| `impact(parent, pos, normal, hard)` | 136 | dirt puff + thud | template for spray particle setup |
| `bullet_hole(parent, pos, normal)` | 211 | **real `Decal`**, oriented, FIFO `MAX_DECALS=48` | **extract the orient+pool logic**, reuse for blood splats/pools |
| `muzzle_flash` / `play_explosion_3d` / `play_shot_3d` | 103 / 98 / 73 | — | unchanged |
| `clear_decals()` | 229 | frees `_decals`, called by MissionScope | extend to also clear blood pools |

Pooling counters already present: `_active_flashes`/`MAX_FLASHES=8`,
`_active_impacts`/`MAX_IMPACTS=12`, `_decals: Array[Decal]`/`MAX_DECALS=48`.

Call sites today:
- Player flesh hit → `weapon_holder.gd:347` `GunFX.blood(...)`.
- Enemy shooter → `enemy_base.gd:1337-1338` only `impact()` on **non-Hitzone**; flesh (Hitzone) gets **nothing**.
- Enemy death → `enemy_base.gd:1519 _die()`; has `last_hit_dir` (attacker→victim world dir, set at `:1443`).
- Ally → `ally_base.gd` `take_damage:518`, `_die:551`.

**Design decision:** DO NOT touch the camera/viewmodel or damage math. All gore is
cosmetic, spawned into `get_tree().current_scene` exactly like the existing FX, and
must be poolable + mission-cleared so it never leaks (per CLAUDE.md session rules).

---

## 1. Upgrade `GunFX.blood()` — surface splat via raycast-past-hit

The single biggest win. Bodies are thin; a rifle round passes *through*. Right now
blood floats at the entry point and vanishes. Instead: keep the spray puff (see §2),
then **raycast onward along the bullet direction** and, if it hits a wall/ground
behind the target, drop a **blood Decal** there (reusing the bullet_hole pipeline).

### 1a. Extract the decal orient+pool logic (refactor, not fork)

`bullet_hole()` already contains the exact orientation math and FIFO we want. Pull it
into a private helper so both bullet holes and blood share it:

```gdscript
# --- generalized decal spawner (replaces the body of bullet_hole) ---
static func _spawn_decal(parent: Node, pos: Vector3, normal: Vector3,
		tex: Texture2D, size: Vector3, tint: Color, mix: float,
		pool: Array[Decal], cap: int) -> Decal:
	var d := Decal.new()
	d.size = size
	if tex != null:
		d.texture_albedo = tex
	d.modulate = tint
	d.albedo_mix = mix
	# PSX/perf: keep decals cheap — no normal fade work, tight cull.
	d.distance_fade_enabled = true
	d.distance_fade_begin = 25.0
	d.distance_fade_length = 8.0
	parent.add_child(d)
	d.global_position = pos + normal * 0.02
	if absf(normal.dot(Vector3.UP)) < 0.99:
		d.look_at(pos - normal, Vector3.UP)
		d.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	d.rotate_object_local(Vector3.UP, randf() * TAU)   # variety: spin around projection axis
	pool.append(d)
	while pool.size() > cap:
		var old: Decal = pool.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return d
```

Then `bullet_hole()` becomes one line into the helper (behavior unchanged):

```gdscript
static func bullet_hole(parent: Node, pos: Vector3, normal: Vector3) -> void:
	_spawn_decal(parent, pos, normal, null, Vector3(0.12, 0.3, 0.12),
		Color(0.05, 0.04, 0.03), 0.9, _decals, MAX_DECALS)
```

### 1b. Blood splat pool + textures

```gdscript
static var _blood_decals: Array[Decal] = []
const MAX_BLOOD_DECALS: int = 40

# 3-4 CC0 splat variants (see §7). Random pick per splat for variety.
const BLOOD_SPLATS: Array[Texture2D] = [
	preload("res://assets/fx/blood/splat_01.png"),
	preload("res://assets/fx/blood/splat_02.png"),
	preload("res://assets/fx/blood/splat_03.png"),
]
const BLOOD_TINT := Color(0.42, 0.03, 0.03)   # dark, desaturated — reads on jungle greens
```

### 1c. Upgraded `blood()` — spray + raycast the exit splat

Keep the existing spray block (§2 replaces its guts) and ADD the exit-wound decal.
Signature is unchanged, so **no call site changes** — but we add an optional
`shot_dir` so callers that know the bullet vector get a wall splat behind the target:

```gdscript
static func blood(parent: Node, pos: Vector3, normal: Vector3,
		shot_dir: Vector3 = Vector3.ZERO) -> void:
	_blood_spray(parent, pos, normal)          # textured GPU spray, see §2
	_blood_wet_tick(parent, pos)               # existing audio block, factored out

	# Exit splat: continue along the bullet path, splat on the surface behind.
	if shot_dir != Vector3.ZERO and parent is Node:
		var tree := (parent as Node).get_tree()
		if tree != null and tree.current_scene != null:
			var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
			var from: Vector3 = pos + shot_dir * 0.15   # start past the body
			var q := PhysicsRayQueryParameters3D.create(from, from + shot_dir * 6.0, 1)  # layer 1 = world only
			var hit := space.intersect_ray(q)
			if hit:
				var sz := randf_range(0.6, 1.1)
				_spawn_decal(parent, hit.position, hit.normal,
					BLOOD_SPLATS.pick_random(), Vector3(sz, 0.25, sz),
					BLOOD_TINT, 0.85, _blood_decals, MAX_BLOOD_DECALS)
```

Then pass the direction at the two flesh call sites (cosmetic-only edits):
- `weapon_holder.gd:347` → `GunFX.blood(scene, result.position, result.normal, final_dir)`
- `enemy_base.gd:1337` → add a flesh branch: `if result.collider is Hitzone: GunFX.blood(scene, result.position, result.normal, final_aim)` (see §4).

`shot_dir` defaults to ZERO so any other caller keeps working with zero splat and no error.

---

## 2. Textured spray particles (GPU, with CPU fallback)

Replace the 14 flat-red CPU particles with a **`GPUParticles3D`** burst using a
billboarded blood texture. GPU particles are markedly cheaper per-particle and let us
add world collision so droplets *stop* on geometry. Keep counts low (retro + perf).

Reuse the `_active_impacts`/`MAX_IMPACTS` budget so spray shares the global cap with
dust puffs — no new leak surface.

```gdscript
const BLOOD_DROPLET := preload("res://assets/fx/blood/droplet.png")  # small CC0 dab

static func _blood_spray(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if _active_impacts >= MAX_IMPACTS:
		return
	_active_impacts += 1
	var ps := GPUParticles3D.new()
	ps.one_shot = true
	ps.amount = 16
	ps.lifetime = 0.5
	ps.explosiveness = 1.0            # single burst, not a stream
	ps.draw_pass_1 = QuadMesh.new()
	(ps.draw_pass_1 as QuadMesh).size = Vector2(0.10, 0.10)

	var mat := ParticleProcessMaterial.new()
	mat.direction = normal
	mat.spread = 55.0
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -12, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	# World collision so droplets smear on surfaces instead of clipping through.
	mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	mat.collision_bounce = 0.1
	mat.collision_friction = 0.6
	ps.process_material = mat

	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES   # sprite-sheet safe
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR  # PSX dithered edge
	draw.alpha_scissor_threshold = 0.4
	draw.albedo_texture = BLOOD_DROPLET
	draw.albedo_color = BLOOD_TINT
	draw.vertex_color_use_as_albedo = false
	(ps.draw_pass_1 as QuadMesh).material = draw

	parent.add_child(ps)
	ps.global_position = pos + normal * 0.05
	ps.emitting = true
	ps.get_tree().create_timer(0.7).timeout.connect(func() -> void:
		_active_impacts -= 1
		ps.queue_free())
```

Notes:
- `collision_mode = COLLISION_RIGID` needs `GPUParticlesCollision*` nodes OR SDF/heightfield to actually collide; if none present it's a no-op (harmless). For a jungle AO, a cheap `GPUParticlesCollisionHeightField3D` on the terrain gives free floor-smear. Skip if profiling says no.
- **Fallback:** on low-end / web export, branch to the current CPU block. Gate with a
  static `use_gpu_gore := true` flag flipped from settings; keep the existing CPU code
  as `_blood_spray_cpu()` so nothing is lost.
- `BILLBOARD_PARTICLES` + `alpha_scissor` = crisp retro dabs with no sorting cost.

---

## 3. Ground blood pool on kill

On death, grow a flat **downward-projected Decal** under the corpse — the "he's
gone" beat. Reuse `_spawn_decal` with an UP normal so it lies on the floor. Animate a
quick grow via a tween on `d.size` for the wet-spread feel (cheap, one tween).

```gdscript
static var _pool_decals: Array[Decal] = []
const MAX_POOL_DECALS: int = 24
const BLOOD_POOL := preload("res://assets/fx/blood/pool_01.png")

static func blood_pool(parent: Node, world_pos: Vector3) -> void:
	# Drop to the floor beneath the corpse so the pool sits flat.
	var tree := (parent as Node).get_tree()
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	var from := world_pos + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, 1)
	var hit := space.intersect_ray(q)
	var floor_pos: Vector3 = hit.position if hit else world_pos
	var floor_n: Vector3 = hit.normal if hit else Vector3.UP

	var d := _spawn_decal(parent, floor_pos, floor_n, BLOOD_POOL,
		Vector3(0.3, 0.3, 0.3), Color(0.30, 0.02, 0.02), 0.9,
		_pool_decals, MAX_POOL_DECALS)
	# Wet spread: grow to full over ~0.8s.
	var target := Vector3(randf_range(1.2, 1.8), 0.3, randf_range(1.2, 1.8))
	var tw := d.create_tween()
	tw.tween_property(d, "size", target, 0.8).set_trans(Tween.TRANS_CUBIC)
```

Call from death handlers (§4). Cap 24 pools; FIFO recycles oldest. Small `size.y`
(0.3) keeps the projection box shallow so it doesn't paint walls.

---

## 4. Make enemies AND allies bleed (currently player-only)

Blood should spawn regardless of *who* fired. Two hook classes: shooters (spray at
the hit) and victims (pool on death).

**Enemy shooter — `enemy_base.gd:1337`** currently skips flesh. Add the flesh branch:
```gdscript
if result:
	if result.collider is Hitzone:
		GunFX.blood(get_tree().current_scene, result.position, result.normal, final_aim)
	else:
		GunFX.impact(get_tree().current_scene, result.position, result.normal, false)
```

**Enemy death — `enemy_base.gd:1519 _die()`**, add after the fall anim:
```gdscript
GunFX.blood_pool(get_tree().current_scene, global_position)
```
(`last_hit_dir` is available here too — could offset the pool slightly along it for a
directional smear, optional.)

**Ally death — `ally_base.gd:551 _die()`** and **player death — `health_system.gd:255`**:
same `GunFX.blood_pool(...)` call. Allies/player getting shot can also route their
hit reactions through `GunFX.blood()` for parity (wherever their damage lands).

Everything funnels through the same 3 static funcs — **one code path, all factions.**

---

## 5. Optional gibs for heavy hits (explosions / headshots at close range)

Reserve gibs for *heavy* events only (grenade/rocket kill, or headshot within ~5m) —
constant gibbing kills the tone and the frame budget. Two viable low-poly approaches:

**A. Pre-authored chunk set (recommended, cheapest).** A handful of low-poly gib
meshes (torso-half, limb, head — 20-80 tris each, single unlit texture). On a heavy
kill, hide the sprite/mesh and spawn 3-6 `RigidBody3D` gibs with an outward impulse
from the blast point. Trail a few `GPUParticles3D` blood dabs off each. Free them on a
timer. No runtime mesh work.

```gdscript
static func gib_burst(parent: Node, pos: Vector3, force_dir: Vector3) -> void:
	for i in range(randi_range(3, 6)):
		var body := RigidBody3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = GIB_MESHES.pick_random()
		body.add_child(mi)
		var col := CollisionShape3D.new()
		col.shape = SphereShape3D.new()          # cheap approximate collider
		body.add_child(col)
		parent.add_child(body)
		body.global_position = pos + Vector3(randf()-0.5, randf(), randf()-0.5) * 0.3
		var imp := (force_dir + Vector3(randf()-0.5, randf_range(0.5,1.2), randf()-0.5)) * randf_range(3,7)
		body.apply_central_impulse(imp)
		body.get_tree().create_timer(8.0).timeout.connect(body.queue_free)
	blood_pool(parent, pos)
```

**B. Runtime fracture** (`godot-destructible-body` / `godot-destruction-plugin`, CSG /
Blender Cell-Fracture). More dynamic but heavier and overkill for PSX gibs — note as a
future option, don't build now.

Gate behind a `gore_level` setting (Off / Splats / Full) so it's optional and
disable-able. Trigger from `projectile_base.gd`/`grenade.gd` explosion kills and from
`_die()` when the killing zone was HEAD at close range.

---

## 6. Exact reuse map (extend, don't fork)

| New capability | Where it lives | Reuses |
|----------------|----------------|--------|
| `_spawn_decal()` helper | new private in `gun_fx.gd` | orientation+FIFO from `bullet_hole():211` |
| `bullet_hole()` | `gun_fx.gd:211` | now calls `_spawn_decal` (behavior identical) |
| `blood()` upgrade | `gun_fx.gd:174` (same signature +opt `shot_dir`) | spray + exit `_spawn_decal` |
| `_blood_spray()` GPU | new in `gun_fx.gd` | `_active_impacts`/`MAX_IMPACTS` budget |
| `blood_pool()` | new in `gun_fx.gd` | `_spawn_decal` + new `_pool_decals` pool |
| `gib_burst()` | new in `gun_fx.gd` | `create_timer` free pattern |
| `clear_decals()` | `gun_fx.gd:229` | **extend** to also free `_blood_decals` + `_pool_decals` |
| `reset_session()` | `gun_fx.gd:21` | reset new counters if any |
| Player spray dir | `weapon_holder.gd:347` | pass `final_dir` |
| Enemy spray + flesh branch | `enemy_base.gd:1337` | pass `final_aim` |
| Death pools | `enemy_base.gd:1519`, `ally_base.gd:551`, `health_system.gd:255` | `blood_pool()` |
| Gib trigger | `projectile_base.gd:288`, `grenade.gd:86`, `_die()` headshot | `gib_burst()` |

**Critical:** extend `clear_decals()` so blood + pools are freed on mission teardown —
otherwise MissionScope only clears bullet holes and blood leaks across missions
(violates the no-leak rule the existing `_decals`/`clear_decals` design enforces).

```gdscript
static func clear_decals() -> void:
	for pool in [_decals, _blood_decals, _pool_decals]:
		for d in pool:
			if is_instance_valid(d):
				d.queue_free()
		pool.clear()
```

---

## 7. CC0 texture sourcing

Need ~3 splat variants, 1 small droplet dab, 1 pool. All CC0 (safe to ship):

| Source | Asset | License | Use |
|--------|-------|---------|-----|
| OpenGameArt — "Blood splat" | `blood_splat.png` | CC0 | droplet dab / small splat |
| OpenGameArt — "Blood Splatter" (ExileGL) | `blood.png` (2.6 MB, hi-res) | CC0 | wall splats (crop to 3-4 variants) |
| Material Maker — "Blood Splash" (unfa) | procedural material | CC0 | generate tileable splat/pool albedo |
| Texture Ninja (Joost Vanhoutte) | photographic blood cutouts, 5000+ files | CC0 | pool + splat variety |

Prep for PSX look: downscale to **128×128 or 256×256**, hard-quantize the alpha
(scissor, not smooth), desaturate + darken toward `BLOOD_TINT`, import with
**filter OFF (nearest)** and mipmaps on. Store under `res://assets/fx/blood/`. Author
the alpha channel so `alpha_scissor_threshold ~0.4` gives clean stylized edges.

Material Maker is the best bet for consistent, tweakable variants — generate the whole
set (splat_01-03, droplet, pool) from one graph so they read as one style.

---

## Build order (suggested beads)

1. Refactor `bullet_hole` → `_spawn_decal` (no behavior change) + extend `clear_decals`. **Safe, testable in isolation.**
2. Source + import CC0 textures to `res://assets/fx/blood/`.
3. Upgrade `blood()`: GPU spray + raycast exit splat; wire `shot_dir` at 2 call sites.
4. `blood_pool()` + death hooks (enemy/ally/player). Enemy shooter flesh branch.
5. `gib_burst()` + `gore_level` setting; wire explosion/headshot triggers. (optional/last)

Each step is cosmetic, pooled, and mission-cleared. No damage/camera/viewmodel changes.

---

## Sources

- [Using decals — Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html)
- [Decal class — Godot docs](https://docs.godotengine.org/en/stable/classes/class_decal.html)
- [Particle systems (3D) — Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html)
- [How to implement persistent blood splatter — Godot forum](https://forum.godotengine.org/t/how-to-implement-persistent-blood-splatter/121948) (raycast→decal technique)
- [directional-blood-splatter (Godot 4, GDScript) — GitHub](https://github.com/kubsterman/directional-blood-splatter)
- [DecalCo shader-based decals — GitHub](https://github.com/Master-J/DecalCo) (mobile/quad-mesh decal alternative)
- [godot-destructible-body — GitHub](https://github.com/toadile-gd/godot-destructible-body) (gib option B)
- [godot-destruction-plugin — GitHub](https://github.com/Jummit/godot-destruction-plugin) (Cell-Fracture gib workflow)
- [OpenGameArt — Blood splat (CC0)](https://opengameart.org/content/blood-splat)
- [OpenGameArt — Blood Splatter (CC0)](https://opengameart.org/content/blood-splatter)
- [Material Maker — Blood Splash by unfa (CC0)](https://www.materialmaker.org/material?id=284)
- [Texture Ninja CC0 textures](https://www.cgchannel.com/2018/12/download-5000-free-texture-images-from-texture-ninja/)
