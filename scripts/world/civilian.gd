## civilian.gd - Village noncombatant (W47): wanders, flees gunfire, cowers.
## An informer who escapes after seeing you raises the alarm. Killing civilians
## costs you at debrief and with the war.
class_name Civilian
extends CharacterBody3D

enum CivState { WANDER, FLEE, COWER, GONE }

var state: CivState = CivState.WANDER
var home: Vector3
var is_informer: bool = false
var director: MissionDirector
var _hp: int = 20
var _wander_target: Vector3
var _timer: float = 0.0
var _saw_player_at: Vector3 = Vector3.ZERO
var _inform_clock: float = -1.0
var actor: ModelActor = null      ## the real villager. Was a brown pill.
var _last_clip: String = ""

## THE VILLAGE, AS IT WAS: a brown CapsuleMesh, radius 0.3, albedo (0.55,0.45,0.3).
##
## Every one of these models has been finished and sitting in assets/models/characters/
## for weeks. The ONLY reference to "civ_farmer_m" anywhere in the codebase was a HEIGHT
## TABLE ENTRY in model_actor.gd. Somebody built the socket; nobody plugged anything in.
##
## THE INVERSE OF THE r4bk LAW: simulation without presentation is unfinished work -
## and ART WITHOUT AN INSTANTIATOR DOES NOT EXIST.
const VILLAGERS: Array[String] = [
	"civ_farmer_m", "civ_farmer_m_b", "civ_farmer_m_c",
	"civ_farmer_f", "civ_farmer_f_b", "civ_farmer_f_c",
	"civ_elder", "civ_elder_b",
	"civ_kid", "civ_kid_b",
]


static func spawn(parent: Node, pos: Vector3, mission_director: MissionDirector, informer: bool) -> Civilian:
	var civ := Civilian.new()
	civ.director = mission_director
	civ.is_informer = informer
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	civ.add_child(col)
	# A PERSON, not a pill. Deterministic per position so the same village rebuilds
	# with the same faces (ADR-010/017 - the province must come back identical).
	var pick: int = absi(hash(Vector2i(int(pos.x), int(pos.z)))) % VILLAGERS.size()
	var actor := ModelActor.new()
	civ.add_child(actor)
	if actor.setup(VILLAGERS[pick]):
		civ.actor = actor
	else:
		# The model is missing. Fall back to the old pill rather than an invisible
		# man - but say so LOUDLY, because a silent fallback is how a village full
		# of capsules survives for weeks without anyone noticing.
		push_warning("[Civilian] no model for '%s' - falling back to a CAPSULE. The village will look like pills." % VILLAGERS[pick])
		actor.queue_free()
		var mesh := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.3
		cm.height = 1.6
		mesh.mesh = cm
		mesh.position = Vector3(0, 0.8, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.45, 0.3)
		mesh.material_override = mat
		civ.add_child(mesh)
	civ.collision_layer = 2
	civ.collision_mask = 1
	parent.add_child(civ)
	civ.global_position = pos
	civ.home = pos
	civ._wander_target = pos
	civ.add_to_group("civilians")
	NoiseBus.noise_emitted.connect(civ._on_noise)
	return civ


func _on_noise(type: int, position: Vector3, _radius: float, _team: int) -> void:
	if state == CivState.GONE:
		return
	if type == NoiseBus.NoiseType.GUNSHOT or type == NoiseBus.NoiseType.EXPLOSION:
		if global_position.distance_to(position) < 60.0:
			state = CivState.FLEE if randf() < 0.6 else CivState.COWER


func _physics_process(delta: float) -> void:
	if state == CivState.GONE:
		return
	_timer += delta
	velocity.y -= 9.8 * delta

	# Informer: spotted you nearby -> starts the clock; escapes -> alarm.
	var player := GameManager.player as Node3D
	if is_informer and player and _inform_clock < 0.0 \
			and global_position.distance_to(player.global_position) < 15.0:
		_inform_clock = 0.0
		_saw_player_at = player.global_position
		state = CivState.FLEE
	if _inform_clock >= 0.0:
		_inform_clock += delta
		if _inform_clock > 25.0:
			_inform_clock = -1.0
			state = CivState.GONE
			if director:
				director.toast.emit("THAT VILLAGER TALKED - THEY KNOW YOU'RE HERE")
			NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, _saw_player_at, 0, 120.0)
			visible = false
			set_physics_process(false)
			return

	match state:
		CivState.WANDER:
			if _timer > 4.0:
				_timer = 0.0
				var a := randf_range(0.0, TAU)
				_wander_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 10.0)
			_step_toward(_wander_target, 1.2, delta)
		CivState.FLEE:
			var flee_from := _saw_player_at
			if player and flee_from == Vector3.ZERO:
				flee_from = player.global_position
			var away := (global_position - flee_from)
			away.y = 0
			_step_toward(global_position + away.normalized() * 10.0, 4.0, delta)
		CivState.COWER:
			velocity.x = 0
			velocity.z = 0
	move_and_slide()
	_animate()


## THE CLIPS CALEB MADE TODAY, PLAYING FOR THE FIRST TIME.
##
## civ_panic_run, cower, hands_up, work - all authored, all exported into the shared
## PSXRig library, and NONE of them had ever been played by anything but a debug
## bench. The state machine below has existed for weeks; it just moved a capsule.
##
## play_first() takes a fallback chain, so a missing clip degrades to the next one
## instead of freezing a man mid-stride.
func _animate() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.4
	var want: String = ""
	match state:
		CivState.COWER:
			# Hands up if he has SEEN you and is about to sell you out; cowering if
			# he is just terrified. Two different men, and the player can read them.
			want = "hands_up" if is_informer and _inform_clock >= 0.0 else "cower"
		CivState.FLEE:
			want = "civ_panic_run"
		CivState.WANDER:
			want = "walk" if moving else "work"
		_:
			want = "idle"
	if want == _last_clip:
		return
	_last_clip = want
	match want:
		"civ_panic_run":
			actor.play_first(["civ_panic_run", "panic_run", "run", "sprint", "walk"])
		"hands_up":
			actor.play_first(["hands_up", "surrender", "cower", "idle"])
		"cower":
			actor.play_first(["cower", "crouch_idle", "idle"])
		"walk":
			actor.play_first(["civ_walk", "walk", "walking", "idle"])
		"work":
			# The villager is doing something with his hands - the "work" clip Caleb
			# built. A village of men standing perfectly still is a morgue.
			actor.play_first(["work", "civ_work", "idle"])
		_:
			actor.play_first(["idle", "idle_relaxed"])


func _step_toward(target: Vector3, speed: float, delta: float) -> void:
	var dir := (target - global_position)
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
		velocity.x = lerpf(velocity.x, dir.x * speed, delta * 6.0)
		velocity.z = lerpf(velocity.z, dir.z * speed, delta * 6.0)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 6.0)


func take_damage(amount: int, _t: Enums.DamageType = Enums.DamageType.PHYSICAL, _a: Node = null) -> int:
	_hp -= amount
	if _hp <= 0 and state != CivState.GONE:
		state = CivState.GONE
		set_physics_process(false)
		rotation_degrees.x = 90
		if director:
			director.state.flags["civ_casualties"] = int(director.state.flags.get("civ_casualties", 0)) + 1
			director.toast.emit("CIVILIAN DOWN. THAT FOLLOWS YOU HOME.")
		get_tree().create_timer(30.0).timeout.connect(queue_free)
	return amount
