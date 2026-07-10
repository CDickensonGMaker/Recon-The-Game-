## gore_dummy.gd - a us_grunt_v2 rig-verification target for the gore lab.
##
## A CharacterBody3D wearing the full ModelActor + per-region hitzones, no AI.
## BENCH RULES (deliberately exaggerated so the RIG is what gets tested):
##   any LIMB hit    -> that limb pops (live rule: single hit >= ~45)
##   any HEAD hit    -> kill + head pop, helmet flies (live rule: kill >= ~60)
##   TORSO/GUT       -> normal damage + blood; death at 0 HP
## Every pop prints what the LIVE GORE_WORKFLOW rule would have done.
class_name GoreDummy
extends CharacterBody3D

signal died

const UNIT := "us_grunt_v2"
const MAX_HP: int = 85

var hp: int = MAX_HP
var model: ModelActor = null
var _removed: Array[String] = []
var _dead: bool = false


func _ready() -> void:
	add_to_group("enemies")  # hitzone layers + player rays treat it as a target
	collision_layer = 4      # layer 3: enemies
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	model = ModelActor.new()
	add_child(model)
	if not model.setup(UNIT):
		push_error("[GORE LAB] %s.glb missing - nothing to test" % UNIT)
		return
	for clip in ["idle", "rifle_idle", "Idle"]:
		if model.play(clip):
			break

	_build_hitzones()


## Same bands as EnemyBase._setup_hurtbox (GAME_SCALE_STANDARD), but each zone
## carries its REGION so the gib system knows WHICH limb the round took.
func _build_hitzones() -> void:
	_zone(Hitzone.ZoneType.HEAD, "HEAD", Vector3(0, 1.65, 0), 0.15)
	_zone(Hitzone.ZoneType.TORSO, "BODY", Vector3(0, 1.3, 0), 0.3, 0.35)
	_zone(Hitzone.ZoneType.GUT, "GUT", Vector3(0, 0.9, 0), 0.28, 0.3)
	_zone(Hitzone.ZoneType.LIMB, "ARM_L", Vector3(0.35, 1.0, 0), 0.12, 0.5)
	_zone(Hitzone.ZoneType.LIMB, "ARM_R", Vector3(-0.35, 1.0, 0), 0.12, 0.5)
	_zone(Hitzone.ZoneType.LIMB, "LEG_L", Vector3(0.12, 0.4, 0), 0.12, 0.8)
	_zone(Hitzone.ZoneType.LIMB, "LEG_R", Vector3(-0.12, 0.4, 0), 0.12, 0.8)


func _zone(zone_type: Hitzone.ZoneType, region: String, pos: Vector3, radius: float, height: float = -1.0) -> void:
	var hz := GoreLabHitzone.new()
	hz.zone_type = zone_type
	hz.region = region
	hz.set_owner_entity(self)
	var col := CollisionShape3D.new()
	if height > 0.0:
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = height
		col.shape = shape
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		col.shape = sphere
	col.position = pos
	hz.add_child(col)
	hz.collision_layer = 64
	hz.collision_mask = 16
	hz.add_to_group("enemy_hurtbox")
	hz.add_to_group("hitzone")
	add_child(hz)


func take_damage(amount: int, _damage_type: int = 0, attacker: Node = null, zone: String = "BODY") -> void:
	var dir: Vector3 = -global_transform.basis.z
	if attacker is Node3D:
		dir = (global_position - (attacker as Node3D).global_position).normalized()
	var hit_pos: Vector3 = global_position + Vector3.UP * 1.2

	GunFX.blood(get_parent(), hit_pos, -dir, dir, self)

	match zone:
		"ARM_L", "ARM_R", "LEG_L", "LEG_R":
			hp = maxi(0, hp - amount)
			if not _removed.has(zone):
				if GibSystem.dismember(model, zone, dir, get_parent()):
					_removed.append(zone)
					var live_verdict := "would pop" if amount >= 45 else "would NOT pop (needs >=45)"
					print("[GORE LAB] %s OFF - dmg %d (live rule: %s)" % [zone, amount, live_verdict])
			if _removed.size() >= 4 and not _dead:
				_die(dir)
		"HEAD":
			hp = 0
			if not _removed.has("HEAD"):
				if GibSystem.dismember(model, "HEAD", dir, get_parent()):
					_removed.append("HEAD")
					var live_verdict := "would pop" if amount >= 60 else "would NOT pop (needs >=60 on the kill)"
					print("[GORE LAB] HEADSHOT - dmg %d (live rule: %s)" % [amount, live_verdict])
			if not _dead:
				_die(dir)
		_:
			hp = maxi(0, hp - amount)
			print("[GORE LAB] %s hit, dmg %d, HP %d/%d" % [zone, amount, hp, MAX_HP])
			if hp <= 0 and not _dead:
				_die(dir)


func regions_removed() -> Array[String]:
	return _removed


func _die(dir: Vector3) -> void:
	_dead = true
	for clip in ["death", "death_1", "die", "Death"]:
		if model != null and model.play(clip):
			break
	GunFX.blood_pool(get_parent(), global_position)
	GunFX.blood(get_parent(), global_position + Vector3.UP * 0.9, Vector3.UP, dir, self)
	died.emit()


## Inner hitzone that carries its region through the existing zone_name channel,
## so weapon_holder._resolve_hit -> take_damage(zone) needs zero changes.
class GoreLabHitzone:
	extends Hitzone
	var region: String = ""

	func get_zone_name() -> String:
		if region != "":
			return region
		return super()
