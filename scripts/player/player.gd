## player.gd - Player root node that coordinates all player systems
extends CharacterBody3D

## Movement speeds
const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const CROUCH_SPEED: float = 2.5
const ACCELERATION: float = 10.0
const DECELERATION: float = 12.0

## Jump and gravity
const JUMP_VELOCITY: float = 5.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## Mouse sensitivity
@export var mouse_sensitivity: float = 0.002

## Crouch settings
const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 0.9
const CROUCH_TRANSITION_SPEED: float = 10.0

## Lean settings
const LEAN_ANGLE: float = -18.0  ## Negative so lean_right tilts right (increased 20%)
const LEAN_OFFSET: float = 0.36  ## Positive so lean_right moves right (increased 20%)
const LEAN_SPEED: float = 12.0
const LEAN_MOVE_MULT: float = 0.8

## Node references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var weapon_holder: WeaponHolder = $Head/Camera3D/WeaponHolder
@onready var grenade_handler: GrenadeHandler = $Head/Camera3D/GrenadeHandler
@onready var health_system: HealthSystem = $HealthSystem
@onready var equipment_manager: EquipmentManager = $EquipmentManager

## Hitzones for body part damage
var hitzones: Array[Hitzone] = []

## State tracking
var is_crouching: bool = false
var is_sprinting: bool = false
var is_prone: bool = false
var lean_amount: float = 0.0
var current_speed: float = WALK_SPEED

## Stamina (W33): sprint drains, St scales the pool, winded blocks sprint.
const PRONE_HEIGHT: float = 0.5
const PRONE_SPEED: float = 1.0
var stamina: float = 100.0
var stamina_max: float = 100.0
const STAMINA_DRAIN: float = 18.0    ## per second sprinting
const STAMINA_REGEN: float = 10.0    ## per second otherwise
var _winded: bool = false

## Wound effects (W37): limbs degrade function until a medkit heal.
var wounded_legs: bool = false
var wounded_arms: bool = false

## Smoke grenades (W39): key 5 lobs marking/concealment smoke.
var smoke_count: int = 2


func _throw_smoke() -> void:
	if smoke_count <= 0 or not GameManager.can_player_act() or is_seated:
		return
	smoke_count -= 1
	var dir: Vector3 = get_aim_direction()
	var body := RigidBody3D.new()
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	col.shape = sphere
	body.add_child(col)
	var vis := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 0.14
	vis.mesh = cyl
	body.add_child(vis)
	get_tree().current_scene.add_child(body)
	body.global_position = get_camera_position() + dir * 0.5
	body.linear_velocity = dir * 13.0 + Vector3(0, 3.5, 0)
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if is_instance_valid(body):
			SmokeCloud.spawn_at(get_tree().current_scene, body.global_position)
			NoiseBus.emit_noise(NoiseBus.NoiseType.IMPACT, body.global_position, 0)
			body.queue_free())


func apply_wound(zone_name: String) -> void:
	match zone_name:
		"LIMB_LEG", "LEG":
			if not wounded_legs:
				wounded_legs = true
		"LIMB_ARM", "ARM", "LIMB":
			if not wounded_arms:
				wounded_arms = true


func clear_wounds() -> void:
	wounded_legs = false
	wounded_arms = false

## Camera rotation limits
var camera_rotation_x: float = 0.0
const MAX_LOOK_ANGLE: float = 89.0

## Recoil system
var recoil_offset: float = 0.0  # Current recoil offset (added to camera)
var target_recoil: float = 0.0  # Target recoil to lerp toward
const RECOIL_SPEED: float = 15.0  # How fast recoil kicks up
const RECOIL_RECOVERY_SPEED: float = 5.0  # How fast camera recovers

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")

	# Register with managers
	GameManager.register_player(self)
	CombatManager.register_player(self)

	# Setup body part hitzones
	_setup_hitzones()

	# Setup cross-references
	health_system.setup(self, equipment_manager)
	equipment_manager.setup(self, weapon_holder, health_system, grenade_handler)
	grenade_handler.setup(self, equipment_manager)

	# W29: Strength scales HP + stamina (RECON: St IS your capacity).
	var st: float = float(CampaignState.player_data.get("st", 100))
	health_system.max_hp = int(50.0 + st * 0.5)
	health_system.current_hp = health_system.max_hp
	stamina_max = 60.0 + st * 0.4
	stamina = stamina_max
	weapon_holder.equipment_manager = equipment_manager


func _input(event: InputEvent) -> void:
	if not GameManager.can_player_act():
		return

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		_handle_mouse_look(mouse_event.relative)


func _handle_mouse_look(mouse_delta: Vector2) -> void:
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	camera_rotation_x -= mouse_delta.y * mouse_sensitivity
	camera_rotation_x = clamp(camera_rotation_x, deg_to_rad(-MAX_LOOK_ANGLE), deg_to_rad(MAX_LOOK_ANGLE))
	# head.rotation.x is set in _handle_recoil to combine base rotation + recoil


## Seated mode (W05): glued to a seat marker, head-look only, no collision.
var is_seated: bool = false
var _seat_node: Node3D = null


func enter_seat(seat: Node3D) -> void:
	is_seated = true
	_seat_node = seat
	velocity = Vector3.ZERO
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = true


func exit_seat(ground_pos: Vector3) -> void:
	is_seated = false
	_seat_node = null
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = false
	global_position = ground_pos
	velocity = Vector3.ZERO


var _footstep_timer: float = 0.0


## Footstep noise for the AI ears (R13). Crouch-walk is near-silent.
func _emit_footsteps(delta: float) -> void:
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or flat_speed < 1.0:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	_footstep_timer = 0.35 if is_sprinting else 0.55
	# W28: Silent Movement skill shrinks every footstep radius.
	var quiet_mult: float = 1.0 / (1.0 + 0.12 * float(CampaignState.player_skill("silent_movement")))
	if is_crouching:
		NoiseBus.emit_noise(NoiseBus.NoiseType.FOOTSTEP, global_position, 0, 3.0 * quiet_mult)
	elif is_sprinting:
		NoiseBus.emit_noise(NoiseBus.NoiseType.FOOTSTEP_SPRINT, global_position, 0,
			float(NoiseBus.RADII[NoiseBus.NoiseType.FOOTSTEP_SPRINT]) * quiet_mult)
	else:
		NoiseBus.emit_noise(NoiseBus.NoiseType.FOOTSTEP, global_position, 0,
			float(NoiseBus.RADII[NoiseBus.NoiseType.FOOTSTEP]) * quiet_mult)


func _physics_process(delta: float) -> void:
	if not GameManager.can_player_act():
		return

	# Seated (Huey ride): follow the seat, keep head-look, skip movement.
	if is_seated:
		if _seat_node != null and is_instance_valid(_seat_node):
			global_position = _seat_node.global_position
		return

	# Downed (W17): on the deck waiting for Doc - no movement, low camera.
	if health_system and health_system.is_downed:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= 9.8 * delta
		move_and_slide()
		var head_node := get_node_or_null("Head") as Node3D
		if head_node:
			head_node.position.y = lerpf(head_node.position.y, 0.45, delta * 3.0)
		return

	# Cap delta for framerate independence (Quake 3 pattern - max 66ms)
	var capped_delta: float = minf(delta, 0.066)

	_emit_footsteps(delta)

	_handle_gravity(capped_delta)
	_handle_movement(capped_delta)
	_handle_crouch(capped_delta)
	_handle_lean(capped_delta)
	_handle_recoil(capped_delta)
	move_and_slide()


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Prone toggle (W34).
	if Input.is_action_just_pressed("prone"):
		is_prone = not is_prone

	# Smoke (W39).
	if Input.is_action_just_pressed("throw_smoke"):
		_throw_smoke()

	# Stamina + wounds gate sprinting (W33/W37).
	if _winded and stamina > stamina_max * 0.35:
		_winded = false
	var can_sprint := not is_crouching and not is_prone and not health_system.is_healing \
		and not wounded_legs and not _winded and stamina > 0.0
	is_sprinting = Input.is_action_pressed("sprint") and can_sprint and input_dir.y < 0

	if is_sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		if stamina <= 0.0:
			_winded = true
			is_sprinting = false
	else:
		stamina = minf(stamina_max, stamina + STAMINA_REGEN * delta)

	if is_prone:
		current_speed = PRONE_SPEED
	elif is_crouching:
		current_speed = CROUCH_SPEED
	elif is_sprinting:
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

	# Apply ADS speed modifier
	if weapon_holder and equipment_manager.is_weapon_slot():
		var ads_move: float = weapon_holder.current_weapon.ads_move_mult if weapon_holder.current_weapon else 0.6
		var ads_mult: float = lerpf(1.0, ads_move, weapon_holder.get_ads_amount())
		current_speed *= ads_mult

	# Apply lean speed penalty
	if abs(lean_amount) > 0.1:
		current_speed *= LEAN_MOVE_MULT

	if direction:
		velocity.x = lerpf(velocity.x, direction.x * current_speed, delta * ACCELERATION)
		velocity.z = lerpf(velocity.z, direction.z * current_speed, delta * ACCELERATION)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * DECELERATION)
		velocity.z = lerpf(velocity.z, 0.0, delta * DECELERATION)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_prone:
		velocity.y = JUMP_VELOCITY


func _handle_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch") and not is_prone
	if is_crouching:
		is_prone = false
	var target_height := STAND_HEIGHT
	if is_prone:
		target_height = PRONE_HEIGHT
	elif is_crouching:
		target_height = CROUCH_HEIGHT

	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = lerpf(capsule.height, target_height, delta * CROUCH_TRANSITION_SPEED)
		collision_shape.position.y = capsule.height / 2.0
		var target_head_y := target_height - 0.1
		head.position.y = lerpf(head.position.y, target_head_y, delta * CROUCH_TRANSITION_SPEED)


func _handle_lean(delta: float) -> void:
	if is_sprinting:
		lean_amount = lerpf(lean_amount, 0.0, delta * LEAN_SPEED)
	else:
		var target_lean := 0.0
		if Input.is_action_pressed("lean_left"):
			target_lean = -1.0
		elif Input.is_action_pressed("lean_right"):
			target_lean = 1.0

		lean_amount = lerpf(lean_amount, target_lean, delta * LEAN_SPEED)

	camera.rotation_degrees.z = lean_amount * LEAN_ANGLE
	camera.position.x = lean_amount * LEAN_OFFSET


## Get the aim direction from camera
func get_aim_direction() -> Vector3:
	return -camera.global_transform.basis.z


## Get the camera's global position
func get_camera_position() -> Vector3:
	return camera.global_position


## Check if player is moving
func is_moving() -> bool:
	return velocity.length() > 0.5


## Get current movement speed
func get_current_speed() -> float:
	return current_speed


## Handle recoil recovery
func _handle_recoil(delta: float) -> void:
	# Lerp recoil offset toward target
	if abs(recoil_offset - target_recoil) > 0.001:
		recoil_offset = lerpf(recoil_offset, target_recoil, delta * RECOIL_SPEED)

	# Recover target recoil back to zero when not firing
	if target_recoil > 0:
		target_recoil = lerpf(target_recoil, 0.0, delta * RECOIL_RECOVERY_SPEED)

	# Apply recoil offset to head rotation (positive recoil = kick view UP)
	head.rotation.x = camera_rotation_x + recoil_offset


## Apply recoil to camera (called when firing)
func apply_recoil(vertical: float, horizontal: float) -> void:
	# Add to target recoil (positive value kicks view UP)
	target_recoil += deg_to_rad(vertical)
	target_recoil = minf(target_recoil, deg_to_rad(30.0))  # Cap max recoil

	# Horizontal recoil - random left/right
	rotate_y(deg_to_rad(randf_range(-horizontal, horizontal)))


## Take damage - forwarded from health system
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	return health_system.take_damage(amount, damage_type, attacker)


## Get health system
func get_health_system() -> HealthSystem:
	return health_system


## Setup body part hitzones for damage detection
func _setup_hitzones() -> void:
	# Head - critical hit zone (4x damage)
	_create_hitzone(Hitzone.ZoneType.HEAD, Vector3(0, 1.65, 0), 0.15)
	# Torso - center mass (1.5x damage)
	_create_hitzone(Hitzone.ZoneType.TORSO, Vector3(0, 1.1, 0), 0.3, 0.6)
	# Left arm
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(-0.35, 1.0, 0), 0.12, 0.5)
	# Right arm
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(0.35, 1.0, 0), 0.12, 0.5)
	# Left leg
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(-0.12, 0.4, 0), 0.12, 0.8)
	# Right leg
	_create_hitzone(Hitzone.ZoneType.LIMB, Vector3(0.12, 0.4, 0), 0.12, 0.8)


## Create a hitzone for a body part
func _create_hitzone(zone_type: Hitzone.ZoneType, pos: Vector3, radius: float, height: float = -1.0) -> void:
	var hitzone := Hitzone.new()
	hitzone.zone_type = zone_type
	hitzone.set_owner_entity(self)

	var col := CollisionShape3D.new()
	if height > 0:
		# Capsule shape for elongated body parts (torso, arms, legs)
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = height
		col.shape = shape
	else:
		# Sphere for head
		var shape := SphereShape3D.new()
		shape.radius = radius
		col.shape = shape

	col.position = pos
	hitzone.add_child(col)

	# Set collision layers for player hitzone
	hitzone.collision_layer = 32  # Layer 6: player_hurtbox
	hitzone.collision_mask = 16   # Layer 5: enemy_hitbox

	hitzone.add_to_group("player_hurtbox")
	hitzone.add_to_group("hitzone")

	add_child(hitzone)
	hitzones.append(hitzone)
