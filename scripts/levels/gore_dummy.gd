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

## The dummy runs Caleb's clip library so you shoot a LIVING target, not a
## statue - cycles every few seconds; the lab HUD names the playing clip.
const PLAYLIST: Array[String] = [
	"idle", "idle_aiming", "idle_crouching", "crouching_turn_90_left",
	"reloading", "run_forward", "firing_rifle", "idle_unarmed",
]
const CLIP_CYCLE_S: float = 4.0

## Spawn as an already-down, ragdolled body (the drag-test casualty): no AI,
## no playlist, no combat registration - just a physical man on the ground.
var unconscious: bool = false

var hp: int = MAX_HP
var model: ModelActor = null
var _removed: Array[String] = []
var _dead: bool = false
var _clip_idx: int = 0
var _clip_timer: float = 0.0
## zone Area3D -> skeleton bone index; synced every physics tick so hitzones
## FOLLOW THE ANIMATION. Static zones + an animated body = rounds pass through
## the picture of the man and hit nothing (the gore-lab "no lethality" bug).
var _zone_bones: Array = []


func _ready() -> void:
	add_to_group("enemies")  # hitzone group wiring
	CombatManager.register_enemy(self)  # explosions damage via active_enemies
	# Allies must NOT execute the practice dummy (it parks beside the squad).
	set_meta("non_hostile", true)
	# LAYER 0: the movement capsule must be INVISIBLE to bullets. On layer 3 it
	# physically shadowed the (smaller) hitzones inside it - every round hit the
	# capsule first and resolved as flat no-multiplier BODY damage (28x3=84 ~ 85
	# HP = the "headshots take 3 shots" bug). Zones are the only shot surface.
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
	if not model.setup(UNIT):
		push_error("[GORE LAB] %s.glb missing - nothing to test" % UNIT)
		return
	if unconscious:
		_dead = true
		CombatManager.unregister_enemy(self)
		_build_hitzones()
		# FLAT casualty (Caleb): freeze at the end of a death clip (a lying
		# pose), ragdoll gently FROM that pose, then park the solver - a calm
		# flat body, not a crumpled heap. Grabbing him wakes the physics.
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


## Rig-contract report: gear must ride BoneAttachment3D nodes or it renders as
## a frozen T-pose shell over the animated body (the exact 2026-07-10 export
## regression). WARNs loudly so the Blender side knows what to re-export.
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


## Zones are MEASURED FROM THE RIG (Caleb: "match the body parts with this
## model, not the other way around") - every size/center derives from actual
## bone spans in world scale, so any export at the contract height fits
## automatically. Each zone is bone-synced per tick. Static bands remain only
## as the no-rig fallback.
func _build_hitzones() -> void:
	var skel: Skeleton3D = model.skeleton() if model != null else null
	if skel == null:
		_zone(Hitzone.ZoneType.HEAD, "HEAD", Vector3(0, 1.65, 0), 0.15)
		_zone(Hitzone.ZoneType.TORSO, "BODY", Vector3(0, 1.3, 0), 0.3, 0.35)
		_zone(Hitzone.ZoneType.GUT, "GUT", Vector3(0, 0.9, 0), 0.28, 0.3)
		_zone(Hitzone.ZoneType.LIMB, "ARM_L", Vector3(0.35, 1.0, 0), 0.12, 0.5)
		_zone(Hitzone.ZoneType.LIMB, "ARM_R", Vector3(-0.35, 1.0, 0), 0.12, 0.5)
		_zone(Hitzone.ZoneType.LIMB, "LEG_L", Vector3(0.12, 0.4, 0), 0.12, 0.8)
		_zone(Hitzone.ZoneType.LIMB, "LEG_R", Vector3(-0.12, 0.4, 0), 0.12, 0.8)
		return

	# world-space rest position of a bone (includes the rig's normalization scale)
	var bw := func(bone: String) -> Vector3:
		var bi: int = skel.find_bone(bone)
		return (skel.global_transform * skel.get_bone_global_rest(bi).origin) if bi >= 0 else Vector3.ZERO

	# HEAD: sphere spanning skull base -> crown, centered mid-skull. Covers the
	# face because it's sized from the head's real extent, not a guess.
	var head_base: Vector3 = bw.call("mixamorig_Head")
	var head_top: Vector3 = bw.call("mixamorig_HeadTop_End")
	var skull: float = maxf(0.18, head_base.distance_to(head_top))
	_zone(Hitzone.ZoneType.HEAD, "HEAD", Vector3.ZERO, skull * 0.72, -1.0,
		"mixamorig_Head", Vector3(0, skull * 0.5, 0))

	# TORSO: capsule spanning Spine -> just below the Neck, radius from real
	# shoulder width, top CLAMPED under the chin so it can never eat face shots.
	var spine_lo: Vector3 = bw.call("mixamorig_Spine")
	var neck: Vector3 = bw.call("mixamorig_Neck")
	var shoulder_half: float = bw.call("mixamorig_LeftArm").distance_to(bw.call("mixamorig_RightArm")) * 0.5
	var chest_len: float = maxf(0.25, spine_lo.distance_to(neck) - 0.04)
	_zone(Hitzone.ZoneType.TORSO, "BODY", Vector3.ZERO, minf(shoulder_half * 0.8, chest_len * 0.5), chest_len,
		"mixamorig_Spine1")

	# GUT: hips -> spine base.
	var hips: Vector3 = bw.call("mixamorig_Hips")
	var gut_len: float = maxf(0.18, hips.distance_to(spine_lo) + 0.10)
	_zone(Hitzone.ZoneType.GUT, "GUT", Vector3.ZERO, shoulder_half * 0.62, gut_len, "mixamorig_Hips")

	# ARMS/LEGS: capsules sized from real joint-to-joint spans, riding the
	# mid-limb bone (elbow/knee) so they track the swing.
	for side in ["Left", "Right"]:
		var tag: String = "L" if side == "Left" else "R"
		var arm_len: float = bw.call("mixamorig_%sArm" % side).distance_to(bw.call("mixamorig_%sHand" % side))
		_zone(Hitzone.ZoneType.LIMB, "ARM_%s" % tag, Vector3.ZERO, maxf(0.06, arm_len * 0.14), arm_len,
			"mixamorig_%sForeArm" % side)
		var leg_len: float = bw.call("mixamorig_%sUpLeg" % side).distance_to(bw.call("mixamorig_%sFoot" % side))
		_zone(Hitzone.ZoneType.LIMB, "LEG_%s" % tag, Vector3.ZERO, maxf(0.07, leg_len * 0.13), leg_len,
			"mixamorig_%sLeg" % side)

	print("[GORE LAB] zones from rig: skull=%.2f chest=%.2f shoulder_half=%.2f" % [skull, chest_len, shoulder_half])


func _zone(zone_type: Hitzone.ZoneType, region: String, pos: Vector3, radius: float, height: float = -1.0, bone: String = "", bone_offset: Vector3 = Vector3.ZERO) -> void:
	var hz := GoreLabHitzone.new()
	hz.zone_type = zone_type
	hz.region = region
	hz.set_owner_entity(self)
	var synced: bool = false
	if bone != "" and model != null and model.skeleton() != null:
		var bi: int = model.skeleton().find_bone(bone)
		if bi >= 0:
			_zone_bones.append([hz, bi, bone_offset])
			synced = true
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
	# bone-synced zones ride the Area3D origin (the bone); static fallback
	# zones keep the old fixed band offsets.
	col.position = Vector3.ZERO if synced else pos
	hz.add_child(col)
	hz.collision_layer = 64
	hz.collision_mask = 16
	hz.add_to_group("enemy_hurtbox")
	hz.add_to_group("hitzone")
	add_child(hz)


func _physics_process(delta: float) -> void:
	if model == null:
		return
	# zones ride the skeleton even on the corpse (shooting bodies stays honest)
	var skel: Skeleton3D = model.skeleton()
	if skel != null:
		for entry in _zone_bones:
			var hz: Area3D = entry[0]
			var bi: int = entry[1]
			var off: Vector3 = entry[2]
			if is_instance_valid(hz):
				hz.global_position = skel.global_transform * skel.get_bone_global_pose(bi).origin + off
	if _dead:
		return
	_clip_timer += delta
	if _clip_timer >= CLIP_CYCLE_S:
		_clip_timer = 0.0
		for _attempt in range(PLAYLIST.size()):
			_clip_idx = (_clip_idx + 1) % PLAYLIST.size()
			if model.play(PLAYLIST[_clip_idx]):
				break


func current_clip() -> String:
	if model == null:
		return "-"
	return model.current_action


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
			# GORE_WORKFLOW: kill by explosion at close range -> multi-gib.
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


## Death doctrine (Caleb, gore lab round 7):
##   clean kill        -> RAGDOLL, always (dead weight just drops)
##   explosion kill    -> multi-gib + RAGDOLL flung by the blast (the
##                        SeveredBones modifier keeps ripped parts gone)
##   bullet-gibbed kill-> random death ANIMATION (the performance beat)
func _die(dir: Vector3, explosive: bool = false) -> void:
	_dead = true
	CombatManager.unregister_enemy(self)
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


## Inner hitzone that carries its region through the existing zone_name channel,
## so weapon_holder._resolve_hit -> take_damage(zone) needs zero changes.
class GoreLabHitzone:
	extends Hitzone
	var region: String = ""

	func get_zone_name() -> String:
		if region != "":
			return region
		return super()
