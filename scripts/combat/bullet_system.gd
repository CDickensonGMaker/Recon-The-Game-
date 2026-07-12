## bullet_system.gd - REAL bullet simulation (bead 7ks; Summoner decree
## 2026-07-11: "hitscan is an inferior system - I want actual projectiles").
##
## Every small-arms round in the game is a simulated projectile: spawned at
## the muzzle, integrated under gravity, and SEGMENT-RAYCAST each physics
## tick so a 900 m/s round cannot tunnel through a hitzone (Area3D overlap
## detection - ProjectileBase - is fine for an 84 m/s rocket and useless at
## rifle speed; rockets keep ProjectileBase).
##
## One manager loop steps every live round - not one scripted Node per
## bullet. Damage resolves at ARRIVAL: falloff by the distance actually
## travelled, zone multiplier from the Hitzone that was struck, wound rolls
## and impact FX at the point of arrival. "A bullet is a bullet" (Summoner):
## rounds fly to MAX_TRAVEL regardless of the weapon's stat-card max_range -
## falloff floors at min_damage_mult and a lucky head hit at distance still
## kills (ADR-016 grammar untouched; HEAD stays fatal via the zone seams).
##
## The tracer IS the bullet's visual (nx9n: per-weapon tracer_ratio and
## tracer_color in WeaponData) - the streak moves at true muzzle velocity
## because it is the round, ending the fixed-500 m/s BulletTracer visual lie
## and the hardcoded every-round enemy green.
class_name BulletSystem
extends Node3D

## Player-fired bullet landed on a damageable target (HUD hitmarker feed).
signal player_bullet_hit(killed: bool, headshot: bool)

const MAX_BULLETS: int = 128       ## oldest round retires silently past this
const MAX_TRACERS: int = 48        ## visual streaks cap (sim is unaffected)
const MAX_TRAVEL: float = 1200.0   ## m - nothing on a 1280m AO flies further
const MAX_AGE: float = 4.0         ## s backstop
const GRAVITY: float = 9.8

var _bullets: Array = []
var _visual_pool: Array[MeshInstance3D] = []


## Spawn one live round. `mask`/`exclude` come from the shooter's faction -
## the FULL-REALISM FRIENDLY FIRE masks port verbatim from the old rays.
func fire(wd: WeaponData, shooter: Node, from: Vector3, dir: Vector3,
		mask: int, exclude: Array, show_tracer: bool) -> void:
	if _bullets.size() >= MAX_BULLETS:
		_finish(_bullets[0])
		_bullets.remove_at(0)
	var excl_rids: Array[RID] = []
	for e in exclude:
		if e is CollisionObject3D:
			excl_rids.append((e as CollisionObject3D).get_rid())
	var b: Dictionary = {
		"pos": from,
		"vel": dir.normalized() * maxf(50.0, wd.projectile_speed),
		"wd": wd, "shooter": shooter, "mask": mask, "exclude": excl_rids,
		"traveled": 0.0, "age": 0.0, "visual": null,
	}
	if show_tracer:
		b.visual = _visual_acquire(wd.tracer_color)
	_bullets.append(b)


func _physics_process(delta: float) -> void:
	if _bullets.is_empty():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var i: int = 0
	while i < _bullets.size():
		var b: Dictionary = _bullets[i]
		b.age = float(b.age) + delta
		var vel: Vector3 = b.vel
		vel.y -= GRAVITY * delta
		b.vel = vel
		var from: Vector3 = b.pos
		var to: Vector3 = from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, int(b.mask))
		q.collide_with_areas = true  # hitzones are Area3D (the sponge fix)
		q.exclude = b.exclude
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			_impact(b, hit)
			_finish(b)
			_bullets.remove_at(i)
			continue
		b.traveled = float(b.traveled) + from.distance_to(to)
		b.pos = to
		if float(b.traveled) > MAX_TRAVEL or float(b.age) > MAX_AGE:
			_finish(b)
			_bullets.remove_at(i)
			continue
		_visual_update(b)
		i += 1


## Arrival resolution - the union of the three retired hitscan resolvers
## (weapon_holder/_resolve_hit, enemy_base, ally_base): one honest path for
## every shooter in the game.
func _impact(b: Dictionary, hit: Dictionary) -> void:
	var wd: WeaponData = b.wd
	var shooter: Node = b.shooter
	var col: Object = hit.collider
	var scene: Node = get_tree().current_scene
	var travel_dir: Vector3 = (b.vel as Vector3).normalized()

	var target: Node = null
	var mult: float = 1.0
	var zone: String = "BODY"
	if col is Hitzone:
		var hz := col as Hitzone
		target = hz.owner_entity
		mult = hz.get_damage_multiplier()
		zone = hz.get_zone_name()
	elif col is Node:
		var n := col as Node
		if n.is_in_group("enemies") or n.is_in_group("player") or n.is_in_group("allies"):
			target = n
		else:
			var p: Node = n.get_parent()
			if p != null and (p.is_in_group("enemies") or p.is_in_group("player") or p.is_in_group("allies")):
				target = p

	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		GunFX.blood(scene, hit.position, hit.normal, travel_dir, target)
		var dist: float = float(b.traveled) + (b.pos as Vector3).distance_to(hit.position)
		var falloff: float = wd.damage_multiplier_at(dist)
		var dmg: int = maxi(1, int(float(wd.get_damage()) * falloff * mult))
		target.take_damage(dmg, wd.damage_type, shooter, zone)
		# GORE channel: hand the struck zone's REGION (ARM_L_UP...) to the
		# target so the one gore authority can pop the right limb. The zone
		# STRING above stays the 4-name law for damage/wound logic.
		if col is Hitzone and target.has_method("on_zone_hit"):
			target.on_zone_hit(str((col as Hitzone).get_meta("region", "")), dmg, travel_dir)
		# W37 parity: limb hits wound (arm = shaky aim, leg = no sprint).
		if zone == "LIMB" and target.has_method("apply_wound"):
			target.apply_wound("LIMB_LEG" if randf() < 0.5 else "LIMB_ARM")
		if shooter != null and is_instance_valid(shooter) and shooter.is_in_group("player"):
			var killed: bool = target.has_method("is_dead") and target.is_dead()
			player_bullet_hit.emit(killed, zone == "HEAD")
	else:
		GunFX.impact(scene, hit.position, hit.normal, _surface_is_hard(col))
		GunFX.bullet_hole(scene, hit.position, hit.normal)


## Cheap surface guess for impact flavour (moved from weapon_holder so every
## shooter's rounds spark on rock and puff on dirt, not just the player's).
static func _surface_is_hard(col: Object) -> bool:
	if col is Node:
		var n := col as Node
		if n.is_in_group("hard_surface"):
			return true
		var nm := str(n.name).to_lower()
		return "rock" in nm or "metal" in nm or "bunker" in nm or "vehicle" in nm or "truck" in nm
	return false


## ---- tracer visuals (the streak IS the round) ------------------------------
func _visual_acquire(color: Color) -> MeshInstance3D:
	var v: MeshInstance3D = null
	for cand in _visual_pool:
		if not cand.visible and not _visual_in_use(cand):
			v = cand
			break
	if v == null:
		if _visual_pool.size() >= MAX_TRACERS:
			return null
		v = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.02, 1.0)
		v.mesh = box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		v.material_override = mat
		v.visible = false
		add_child(v)
		_visual_pool.append(v)
	var m := v.material_override as StandardMaterial3D
	m.albedo_color = color
	m.emission = color
	# R78 parity: tracers burn brighter at night, no dynamic lights (perf-first).
	m.emission_energy_multiplier = 4.5 if MissionWeather.is_night else 2.0
	return v


func _visual_in_use(v: MeshInstance3D) -> bool:
	for b in _bullets:
		if b.visual == v:
			return true
	return false


func _visual_update(b: Dictionary) -> void:
	var v: MeshInstance3D = b.visual
	if v == null:
		return
	var vel: Vector3 = b.vel
	var speed: float = vel.length()
	if speed < 0.1:
		return
	var streak: float = clampf(speed * 0.016, 0.4, maxf(0.4, float(b.traveled)))
	var head: Vector3 = b.pos
	var mid: Vector3 = head - vel.normalized() * (streak * 0.5)
	var up_ref: Vector3 = Vector3.UP if absf(vel.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	v.look_at_from_position(mid, head, up_ref)
	v.scale = Vector3(1.0, 1.0, streak)
	v.visible = true


func _finish(b: Dictionary) -> void:
	var v: MeshInstance3D = b.visual
	if v != null:
		v.visible = false
		b.visual = null


## MissionScope hygiene: drop every live round (mission teardown).
func clear_all() -> void:
	for b in _bullets:
		_finish(b)
	_bullets.clear()


func live_count() -> int:
	return _bullets.size()
