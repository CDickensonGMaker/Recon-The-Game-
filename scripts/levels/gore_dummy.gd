## gore_dummy.gd - Rig-verification target for the labs: full ModelActor +
## per-region hitzones, no AI. Bench gore rules are deliberately EXAGGERATED so
## the rig is what gets tested - any limb hit pops it, any head hit kills.
## The live thresholds are ~45 damage to pop a limb, ~60 on the kill for a head.
class_name GoreDummy
extends CharacterBody3D

signal died
signal hit_taken(zone: String, amount: int, hp_left: int)

## Stand still (no clip cycling) so the shooter tests AIM, not tracking.
@export var idle_only: bool = false

## Which rig stands on the range - labs set this before add_child.
@export var unit_id: String = "us_grunt_rifleman"
const MAX_HP: int = 85

## Cycled every CLIP_CYCLE_S so the target is a living man, not a statue.
const PLAYLIST: Array[String] = [
	"idle", "idle_aiming", "idle_crouching", "crouching_turn_90_left",
	"reloading", "run_forward", "firing_rifle", "idle_unarmed",
]
const CLIP_CYCLE_S: float = 4.0

## Spawn already down and ragdolled: no AI, no playlist, no combat registration.
var unconscious: bool = false

var hp: int = MAX_HP
var model: ModelActor = null
var _removed: Array[String] = []
var _dead: bool = false
var _clip_idx: int = 0
var _clip_timer: float = 0.0
## HitzoneBuilder sync entries. MUST be synced every physics tick so the zones
## follow the animation - static zones on an animated body means rounds pass
## through the picture of the man and hit nothing.
var _zone_sync: Array = []


func _ready() -> void:
	add_to_group("enemies")  # hitzone group wiring
	AgentRegistry.register(self, AgentRegistry.Kind.ENEMY)  # explosions damage via the roster
	# Allies must NOT execute the practice dummy (it parks beside the squad).
	set_meta("non_hostile", true)
	# LAYER 0: the movement capsule must stay INVISIBLE to bullets. On a shootable
	# layer it shadows the smaller hitzones inside it and every round resolves as
	# flat no-multiplier BODY damage. The zones are the only shot surface.
	collision_layer = 0
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	model = ModelActor.new()
	add_child(model)
	if not model.setup(unit_id):
		push_error("[GORE LAB] %s.glb missing - nothing to test" % unit_id)
		return
	if unconscious:
		_dead = true
		AgentRegistry.unregister(self)
		_build_hitzones()
		# Freeze at the end of a death clip (a lying pose), ragdoll gently FROM that
		# pose, then park the solver: a flat body, not a crumpled heap.
		for c in model.clip_names():
			if String(c).begins_with("death"):
				model.pose_end_of(String(c))
				break
		model.start_ragdoll.call_deferred(Vector3(0.05, 0, 0.05), 0.3)
		var settle: SceneTreeTimer = get_tree().create_timer(1.2)
		settle.timeout.connect(func() -> void:
			if is_instance_valid(self) and model != null:
				model.sleep_ragdoll())
		return

	if not model.play(PLAYLIST[0]):
		print("[GORE LAB] RIG WARN: no '%s' clip - dummy will T-pose (export missing anims?)" % PLAYLIST[0])

	_report_gear_rigging()
	_build_hitzones()


## Rig contract: gear MUST ride BoneAttachment3D nodes or it renders as a frozen
## T-pose shell over the animated body. Warns loudly so the export can be fixed.
func _report_gear_rigging() -> void:
	var root: Node3D = model.instance_root()
	if root == null:
		return
	for gear_name in ["helmet_camo_shell", "m16_world", "ruck_bag", "bandolier"]:
		var g: Node = root.find_child(gear_name, true, false)
		if g == null:
			continue
		var n: Node = g
		var attached: bool = false
		while n != null and n != root:
			if n is BoneAttachment3D:
				attached = true
				break
			n = n.get_parent()
		if not attached:
			print("[GORE LAB] RIG WARN: gear '%s' is NOT bone-attached in this export - it will float at T-pose (re-export with bone parenting)" % gear_name)


## The same hitzone authority the live enemies wear: HitzoneBuilder mesh hulls +
## data/hitzones tuning. Zone labels carry the specific region ("ARM_L_UP") so
## the gib bench knows which limb.
func _build_hitzones() -> void:
	_zone_sync = HitzoneBuilder.build(self, model, 64, 8, ["hitzone"], true)
	for c in get_children():
		if c is Hitzone:
			(c as Hitzone).zone_label_override = str((c as Hitzone).get_meta("region", ""))


func _physics_process(delta: float) -> void:
	if model == null:
		return
	# zones ride the skeleton even on the corpse (shooting bodies stays honest)
	HitzoneBuilder.sync(model, _zone_sync)
	if _dead or idle_only:
		return
	_clip_timer += delta
	if _clip_timer >= CLIP_CYCLE_S:
		_clip_timer = 0.0
		for _attempt in range(PLAYLIST.size()):
			_clip_idx = (_clip_idx + 1) % PLAYLIST.size()
			if model.play(PLAYLIST[_clip_idx]):
				break


func take_damage(amount: int, _damage_type: int = 0, attacker: Node = null, zone: String = "BODY") -> void:
	var dir: Vector3 = -global_transform.basis.z
	if attacker is Node3D:
		dir = (global_position - (attacker as Node3D).global_position).normalized()
	var hit_pos: Vector3 = global_position + Vector3.UP * 1.2

	GunFX.blood(get_parent(), hit_pos, -dir, dir, self)
	hit_taken.emit(zone, amount, maxi(0, hp - amount))

	# Builder zones report segment regions (ARM_L_UP/_LO); gibs speak 4-limb.
	var limb: String = HitzoneBuilder.base_region(zone)
	match limb:
		"ARM_L", "ARM_R", "LEG_L", "LEG_R":
			hp = maxi(0, hp - amount)
			if not _removed.has(limb):
				if GibSystem.dismember(model, limb, dir, get_parent()):
					_removed.append(limb)
					var live_verdict := "would pop" if amount >= 45 else "would NOT pop (needs >=45)"
					print("[GORE LAB] %s OFF (hit %s) - dmg %d (live rule: %s)" % [limb, zone, amount, live_verdict])
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
			# An explosive kill multi-gibs.
			var explosive: bool = _damage_type == Enums.DamageType.EXPLOSIVE
			if hp <= 0 and explosive:
				var to_pop: Array[String] = []
				for r in ["ARM_L", "ARM_R", "LEG_L", "LEG_R", "HEAD"]:
					if not _removed.has(r):
						to_pop.append(r)
				to_pop.shuffle()
				var count: int = mini(2 + randi_range(0, 2), to_pop.size())
				for i in range(count):
					if GibSystem.dismember(model, to_pop[i], dir + Vector3.UP * 0.5, get_parent()):
						_removed.append(to_pop[i])
				print("[GORE LAB] EXPLOSION KILL - %d parts gibbed" % count)
			if hp <= 0 and not _dead:
				_die(dir, explosive)


func regions_removed() -> Array[String]:
	return _removed


## Death doctrine:
##   clean kill         -> RAGDOLL, always
##   explosion kill     -> multi-gib + RAGDOLL flung by the blast
##   bullet-gibbed kill -> random death ANIMATION
func _die(dir: Vector3, explosive: bool = false) -> void:
	_dead = true
	AgentRegistry.unregister(self)
	var ragdolled: bool = false
	if model != null and (explosive or _removed.is_empty()):
		ragdolled = model.start_ragdoll(dir, 9.0 if explosive else 4.5)
	if not ragdolled and model != null:
		var deaths: Array[String] = []
		for c in model.clip_names():
			if String(c).begins_with("death"):
				deaths.append(String(c))
		if deaths.is_empty():
			print("[GORE LAB] RIG WARN: no death_* clips in export")
		else:
			var pick: String = deaths[randi_range(0, deaths.size() - 1)]
			model.play(pick, true)
			print("[GORE LAB] death anim: %s" % pick)
	elif ragdolled:
		print("[GORE LAB] death: RAGDOLL (impulse %.0f)" % (10.0 if explosive else 7.0))
	GunFX.blood_pool(get_parent(), global_position)
	GunFX.blood(get_parent(), global_position + Vector3.UP * 0.9, Vector3.UP, dir, self)
	died.emit()
