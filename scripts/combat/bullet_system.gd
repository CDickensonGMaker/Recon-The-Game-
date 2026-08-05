## bullet_system.gd - real projectile simulation for every small-arms round.
##
## Rounds are spawned at the muzzle, integrated under gravity, and SEGMENT-
## RAYCAST each physics tick, so a 900 m/s round cannot tunnel through a hitzone.
## Area3D overlap detection (ProjectileBase) is fine for an 84 m/s rocket and
## useless at rifle speed - rockets keep ProjectileBase.
##
## One manager loop steps every live round; there is NO Node per bullet. Damage
## resolves at ARRIVAL: falloff by the distance actually travelled, zone
## multiplier from the Hitzone struck, wound rolls and impact FX at the point of
## arrival. Rounds fly to MAX_TRAVEL regardless of the weapon's stat-card
## max_range - falloff floors at min_damage_mult, and a lucky head hit at distance
## still kills (ADR-016; HEAD stays fatal).
##
## The tracer IS the bullet: the streak moves at true muzzle velocity because it
## IS the round (per-weapon tracer_ratio / tracer_color in WeaponData).
class_name BulletSystem
extends Node3D

## Player-fired bullet landed on a damageable target (HUD hitmarker feed).
signal player_bullet_hit(killed: bool, headshot: bool)
## Any bullet was spawned. Used by AIStressArena telemetry to count rounds fired.
signal bullet_spawned(shooter: Node, weapon: WeaponData)

## Runaway backstop, NOT a design budget. Raised 128 -> 500 by ruling (2026-07-29): "with 70+
## people shooting automatic guns theres gonna be more than 128 rounds flying around at once."
## Arithmetic behind the headroom: a 900 m/s round lives 0.11s to 100m and 0.33s to 300m, so 70
## men averaging ~3 rounds/sec sit near 32-70 in flight - but a 40-man siege plus an aircraft
## gun spawning ~100/sec is a different order, and that is what this now covers.
## Cost per round is ONE segment raycast per tick. No node, no draw call; tracers are capped
## separately at MAX_TRACERS. Cheap in the dimension this project is bound by.
const MAX_BULLETS: int = 500
const MAX_TRACERS: int = 48        ## visual streaks cap (sim is unaffected)
const MAX_TRAVEL: float = 1200.0   ## m - nothing on a 1280m AO flies further

## SHOOTER-ANCHORED TREE PROMOTION (his ruling 2026-08-05: "the object knows its got a
## collider as a bullet or something comes towards it"). The player carries a permanent
## 70m collision bubble, so trunks near HIM are already solid both ways; a man firing
## from beyond it had none, and the player's return fire passed through the tree he was
## standing behind. Anchored to the SHOOTER and not to the round: a stable point hits
## TreeCoverLayer's 4m dedupe every time, so sustained fire pays once instead of per
## shot - a corridor endpoint 250m out would miss the dedupe on aim jitter alone.
const SHOOTER_COVER_RADIUS: float = 8.0
const SHOOTER_COVER_HOLD_S: float = 2.0
const MAX_AGE: float = 4.0         ## s backstop
const GRAVITY: float = 9.8

var _bullets: Array = []
var _visual_pool: Array[MeshInstance3D] = []
## High-water mark of rounds in flight, and how often the cap actually bit. These are what
## MAX_BULLETS should be set from - a measured peak beats an invented constant.
var _peak_bullets: int = 0
var _cap_hits: int = 0


## Spawn one live round. `mask`/`exclude` come from the shooter's faction (the
## full-realism friendly-fire masks).
## `mark_surface` false leaves no bullet hole. GunFX recycles holes FIFO at MAX_DECALS 48
## (gun_fx.gd:69), so a 90-round-per-second aircraft cannon erases every hole the player
## put in the world twice a second. Cannon rounds tear ground, they do not leave 5.56 holes.
func fire(wd: WeaponData, shooter: Node, from: Vector3, dir: Vector3,
		mask: int, exclude: Array, show_tracer: bool, mark_surface: bool = true) -> void:
	if _bullets.size() >= MAX_BULLETS:
		# THE CAP JUST BIT, AND IT USED TO DO IT IN SILENCE. Retiring the oldest round mid-flight
		# is a round that never arrives: no impact, no wound, no miss - it stops existing on its
		# way to someone. In a 40-man siege plus an aircraft gun that is the fight quietly
		# thinning itself out, and nothing in the log would ever say so.
		#
		# The number is a runaway backstop, not a design budget, and it should be set from
		# _peak_bullets below rather than from a guess. Cost of raising it is ONE segment
		# raycast per round per tick - physics work, not draw calls, and this project is
		# call-bound (PERF_LEDGER). Tracers are capped separately at MAX_TRACERS, so the
		# visual cost does not move with it.
		_cap_hits += 1
		if _cap_hits == 1 or _cap_hits % 500 == 0:
			push_warning(("[BULLETS] round budget FULL (%d) - retiring live rounds mid-flight, "
				+ "%d times so far. Raise MAX_BULLETS: peak in flight was %d.")
				% [MAX_BULLETS, _cap_hits, _peak_bullets])
		_finish(_bullets[0])
		_bullets.remove_at(0)
	if shooter is Node and not (shooter as Node).is_in_group("player"):
		TreeCoverLayer.threat_zone(get_tree(), from, SHOOTER_COVER_RADIUS, SHOOTER_COVER_HOLD_S)
	var excl_rids: Array[RID] = []
	for e in exclude:
		if e is CollisionObject3D:
			excl_rids.append((e as CollisionObject3D).get_rid())
	var b: Dictionary = {
		"pos": from,
		"vel": dir.normalized() * maxf(50.0, wd.projectile_speed),
		"wd": wd, "shooter": shooter, "mask": mask, "exclude": excl_rids,
		"traveled": 0.0, "age": 0.0, "visual": null,
		# Limb over-penetration budget: a round through an arm carries into the
		# chest behind it at reduced energy. The arms ride across the chest, so
		# stopping dead in one makes the same aim kill in 1 or sponge in 4
		# depending on the pose frame.
		"pen_left": 1, "dmg_scale": 1.0,
		# SOFT COVER: thatch, bamboo, hooch wall, brush - lead goes THROUGH it.
		# Two layers per round, 20% of its energy each.
		"soft_left": 2,
		"mark": mark_surface,
	}
	if show_tracer:
		b.visual = _visual_acquire(wd.tracer_color)
	_bullets.append(b)
	_peak_bullets = maxi(_peak_bullets, _bullets.size())
	bullet_spawned.emit(shooter, wd)


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
		q.collide_with_areas = true  # hitzones are Area3D
		q.exclude = b.exclude
		CombatManager.rays_bullet += 1
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			if _impact(b, hit):
				# Limb over-penetration: the round resumes 6cm past the wound
				# (inside the limb hull - rays ignore shapes they start in, so
				# it exits clean and can find the torso behind).
				b.traveled = float(b.traveled) + from.distance_to(hit.position)
				b.pos = (hit.position as Vector3) + (b.vel as Vector3).normalized() * 0.06
				i += 1
				continue
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


## Arrival resolution - ONE path for every shooter in the game. Returns true when
## the round OVER-PENETRATES a limb and keeps flying (the caller then resumes the
## flight past the wound).
func _impact(b: Dictionary, hit: Dictionary) -> bool:
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
		# His outgoing-damage dial. Shipped code no longer duck-types the current scene to
		# ask whether it happens to be the arena (ADR-023): the value is a shared setting,
		# so it also works in the demo and the patrol world, not only on the bench.
		var player_dmg_mult: float = 1.0
		if shooter != null and is_instance_valid(shooter):
			if shooter.is_in_group("player") or (shooter.get_parent() != null and shooter.get_parent().is_in_group("player")):
				player_dmg_mult = GameSettings.player_outgoing_damage_mult
		var dmg: int = maxi(1, int(float(wd.get_damage()) * falloff * mult * player_dmg_mult * float(b.dmg_scale)))
		target.take_damage(dmg, wd.damage_type, shooter, zone)
		# GORE channel: hand the struck zone's REGION (ARM_L_UP...) to the
		# target so the one gore authority can pop the right limb. The zone
		# STRING above stays the 4-name law for damage/wound logic.
		if col is Hitzone and target.has_method("on_zone_hit"):
			target.on_zone_hit(str((col as Hitzone).get_meta("region", "")), dmg, travel_dir)
		# Limb hits wound: arm = shaky aim, leg = no sprint.
		if zone == "LIMB" and target.has_method("apply_wound"):
			target.apply_wound("LIMB_LEG" if randf() < 0.5 else "LIMB_ARM")
		if shooter != null and is_instance_valid(shooter) and shooter.is_in_group("player"):
			var killed: bool = target.has_method("is_dead") and target.is_dead()
			player_bullet_hit.emit(killed, zone == "HEAD")
		# LIMB OVER-PENETRATION: arms/legs wound the round through - it exits
		# at 75% energy and may find the torso behind (head/torso/gut stop it:
		# center mass is mass). One limb per flight, or a grazing round could
		# stitch a whole rank.
		if col is Hitzone and (col as Hitzone).zone_type == Hitzone.ZoneType.LIMB \
				and int(b.pen_left) > 0:
			b.pen_left = int(b.pen_left) - 1
			b.dmg_scale = float(b.dmg_scale) * 0.75
			return true
	else:
		GunFX.impact(scene, hit.position, hit.normal, _surface_is_hard(col))
		if bool(b.get("mark", true)):
			GunFX.bullet_hole(scene, hit.position, hit.normal)
		# SOFT COVER PUNCH-THROUGH: thatch, bamboo, a hooch wall, dense brush.
		# The round keeps going at reduced energy - a man behind a grass wall is
		# CONCEALED, not covered.
		if col is Node and (col as Node).is_in_group("soft_cover") and int(b.soft_left) > 0:
			b.soft_left = int(b.soft_left) - 1
			b.dmg_scale = float(b.dmg_scale) * 0.8
			return true
	return false


## Cheap surface guess for impact flavour - rounds spark on rock, puff on dirt.
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
	# Tracers burn brighter at night; no dynamic lights (perf-first).
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
