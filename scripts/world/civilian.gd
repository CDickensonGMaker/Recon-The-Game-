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
