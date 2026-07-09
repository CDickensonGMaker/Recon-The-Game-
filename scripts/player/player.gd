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
## Claymores (W58): key 6.
var claymore_count: int = 2
## Pop flares (W54): key 7.
var flare_count: int = 3
## Binoculars (W55).
var _binocs_active: bool = false
var _mark_timer: float = 0.0

## R52: hold-breath - short meter, big sway/spread cut while aiming.
var breath_meter: float = 100.0
const BREATH_MAX: float = 100.0
const BREATH_DRAIN: float = 30.0
const BREATH_REGEN: float = 22.0
var is_holding_breath: bool = false

## --- Suppression (R11): the player-side "under heavy fire" feel. Rounds that
## crack past you (near-misses from enemy fire) drive this 0..1 up; it drains
## fast when you break contact and FASTER when you get low. Screen greys out +
## vignettes, the camera shakes, audio muffles. The point: it makes taking cover
## and crawling out of the beaten zone feel necessary, not optional. ---
var suppression: float = 0.0
const SUPPRESS_DECAY: float = 0.55          ## per second, standing
const SUPPRESS_DECAY_LOW: float = 1.3       ## per second, prone/crouched (reward getting down)
const SUPPRESS_PER_NEARMISS: float = 0.34   ## a round cracking past adds this
const SUPPRESS_SHAKE_MAX: float = 0.06      ## camera h/v offset metres at full
var _shake_seed: float = 0.0
var _supp_rect: ColorRect = null
var _supp_mat: ShaderMaterial = null
var _supp_lowpass_idx: int = -1


func _update_hold_breath(delta: float) -> void:
	var want: bool = Input.is_action_pressed("hold_breath") and weapon_holder \
		and weapon_holder.is_aiming and breath_meter > 0.0
	is_holding_breath = want
	if want:
		breath_meter = maxf(0.0, breath_meter - BREATH_DRAIN * delta)
	else:
		breath_meter = minf(BREATH_MAX, breath_meter + BREATH_REGEN * delta)


func _update_binoculars(delta: float) -> void:
	var want: bool = Input.is_action_pressed("binoculars") and not is_seated
	if want != _binocs_active:
		_binocs_active = want
	if camera:
		var target_fov: float = 18.0 if _binocs_active else 75.0
		if _binocs_active or absf(camera.fov - 75.0) > 0.5:
			if not (weapon_holder and weapon_holder.is_aiming):
				camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)
	if not _binocs_active:
		return
	# Mark whatever you're glassing (2s dwell tags them for the team).
	_mark_timer += delta
	if _mark_timer < 0.5:
		return
	_mark_timer = 0.0
	var origin := get_camera_position()
	var dir := get_aim_direction()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 200.0, 1 | 4)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result and result.collider is EnemyBase:
		var enemy := result.collider as EnemyBase
		if not enemy.has_meta("marked"):
			enemy.set_meta("marked", true)
			var mark := Label3D.new()
			mark.text = "v"
			mark.font_size = 30
			mark.pixel_size = 0.006
			mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			mark.modulate = Color(1.0, 0.4, 0.3)
			enemy.add_child(mark)
			mark.position = Vector3(0, 2.6, 0)
			_field_toast("TARGET MARKED")
			get_tree().create_timer(10.0).timeout.connect(func() -> void:
				if is_instance_valid(enemy):
					enemy.remove_meta("marked")
				if is_instance_valid(mark):
					mark.queue_free())


## W69: surface-matched footstep audio (dirt / grass / water via GameplayGrid).
const STEP_DIRT := preload("res://assets/audio/sfx/step_dirt.wav")
const STEP_GRASS := preload("res://assets/audio/sfx/step_grass.wav")
const STEP_WATER := preload("res://assets/audio/sfx/step_water.wav")
var _wade_timer: float = 0.0
var _grid: GameplayGrid = null
## R73: are we currently wading a flooded paddy (slow, loud, exposed)?
var _in_rice_paddy: bool = false


func _play_footstep_sound() -> void:
	var stream: AudioStream = STEP_DIRT
	_in_rice_paddy = false
	if _grid != null:
		if _grid.is_water(global_position):
			stream = STEP_WATER
			_wade_timer += 0.5
			# W71: leeches - linger in the water and pay for it.
			if _wade_timer > 20.0:
				_wade_timer = 0.0
				_field_toast("LEECHES. GODDAMN LEECHES.")
				if health_system:
					health_system.take_damage(3, Enums.DamageType.PHYSICAL, null)
		else:
			_wade_timer = maxf(0.0, _wade_timer - 1.0)
			var t: int = _grid.get_terrain_type(global_position)
			if t == GameplayGrid.TerrainType.GRASSLAND or t == GameplayGrid.TerrainType.RICE_PADDY:
				stream = STEP_GRASS
			if t == GameplayGrid.TerrainType.RICE_PADDY:
				stream = STEP_WATER  # R73: the paddy is flooded - it sounds like a wade, not a step
				_in_rice_paddy = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -16.0 if is_crouching else -10.0
	p.pitch_scale = randf_range(0.9, 1.1)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _field_toast(text: String) -> void:
	var hud_node := get_tree().get_first_node_in_group("mission_hud")
	if hud_node and hud_node.has_method("show_toast"):
		hud_node.show_toast(text)


## W51: tunnel state.
var _in_tunnel: TunnelRoom = null


## W61/W63/W60/W51: interact = capture / loot / crate / tunnel enter-exit.
func _try_field_interact() -> void:
	# Tunnel exit (when underground).
	if _in_tunnel != null:
		if global_position.distance_to(_in_tunnel.ladder_point()) < 2.5:
			global_position = _in_tunnel.surface_return
			velocity = Vector3.ZERO
			_field_toast("BACK IN THE GREEN")
			_in_tunnel = null
			return
		if not _in_tunnel.looted and global_position.distance_to(_in_tunnel.cache_point()) < 2.2:
			_in_tunnel.looted = true
			CampaignState.intel_points += 2
			CampaignState.save_campaign()
			if weapon_holder:
				weapon_holder.spare_magazines += 2
				weapon_holder.magazine_changed.emit(weapon_holder.current_ammo, weapon_holder.spare_magazines)
			_field_toast("TUNNEL CACHE - DOCUMENTS AND AMMO (+2 INTEL)")
			return
	# Temple shrine: one-time offering search (intel + flavor).
	for t in get_tree().get_nodes_in_group("temple_shrines"):
		var shrine := t as Node3D
		if shrine and not shrine.has_meta("searched") \
				and global_position.distance_to(shrine.global_position) < 4.0:
			shrine.set_meta("searched", true)
			CampaignState.intel_points += 1
			CampaignState.save_campaign()
			_field_toast("OLD SHRINE - SOMEONE LEFT MAPS HERE (+1 INTEL)")
			return
	# Tunnel entrance (topside).
	for t in get_tree().get_nodes_in_group("tunnel_entrances"):
		var entrance := t as Node3D
		if entrance and global_position.distance_to(entrance.global_position) < 3.0:
			var room := TunnelRoom.get_or_create(get_tree().current_scene, entrance)
			_in_tunnel = room
			global_position = room.entry_point()
			velocity = Vector3.ZERO
			_field_toast("GOING DOWN. TIGHT IN HERE.")
			return
	for c in get_tree().get_nodes_in_group("supply_crates"):
		var crate := c as Node3D
		if crate and global_position.distance_to(crate.global_position) < 3.0:
			if weapon_holder:
				weapon_holder.spare_magazines += 3
				weapon_holder.magazine_changed.emit(weapon_holder.current_ammo, weapon_holder.spare_magazines)
			if equipment_manager:
				equipment_manager.add_grenade(2)
			if health_system:
				health_system.health_packs = mini(3, health_system.health_packs + 2)
				health_system.health_pack_changed.emit(health_system.health_packs)
			smoke_count = 2
			claymore_count = 2
			flare_count = 3
			_field_toast("RESUPPLIED - MAGS, FRAGS, MEDKITS, KIT")
			crate.queue_free()
			return
	for e in get_tree().get_nodes_in_group("surrendered"):
		var prisoner := e as EnemyBase
		if prisoner and global_position.distance_to(prisoner.global_position) < 2.8:
			CampaignState.intel_points += 1
			CampaignState.save_campaign()
			_field_toast("PRISONER SECURED - INTEL GAINED (+1)")
			prisoner.died.emit(prisoner)  # counts for mission tallies
			prisoner.queue_free()
			return
	# PT9: recover a fallen squadmate's kit (ammo/frags only - not their weapon,
	# that's yours to carry forward, not theirs to leave behind).
	for a in get_tree().get_nodes_in_group("ally_corpses"):
		var fallen := a as Node3D
		if fallen == null or not is_instance_valid(fallen) or fallen.has_meta("looted"):
			continue
		if global_position.distance_to(fallen.global_position) < 2.5:
			fallen.set_meta("looted", true)
			var nick: String = str(fallen.get("member").get("nick", "HE")) if "member" in fallen else "HE"
			if weapon_holder:
				weapon_holder.spare_magazines += 2
				weapon_holder.magazine_changed.emit(weapon_holder.current_ammo, weapon_holder.spare_magazines)
			if equipment_manager:
				equipment_manager.add_grenade(1)
			_field_toast("%s'S KIT - MAGS AND A FRAG RECOVERED" % nick.to_upper())
			return
	for e in get_tree().get_nodes_in_group("lootable_corpses"):
		var corpse := e as EnemyBase
		if corpse == null or not is_instance_valid(corpse):
			continue
		if global_position.distance_to(corpse.global_position) < 2.5 and not corpse.has_meta("looted"):
			corpse.set_meta("looted", true)
			var roll := randf()
			# R57: their weapon is on the table too - take it, and it sounds
			# friendly to their side afterward (visual detection still applies).
			if roll < 0.2 and weapon_holder and corpse.weapon_data != null \
					and corpse.weapon_data != weapon_holder.primary_weapon:
				weapon_holder.equip_captured_weapon(corpse.weapon_data)
				_field_toast("PICKED UP THEIR %s" % corpse.weapon_data.display_name.to_upper())
			elif roll < 0.6 and weapon_holder:
				weapon_holder.spare_magazines += 1
				weapon_holder.magazine_changed.emit(weapon_holder.current_ammo, weapon_holder.spare_magazines)
				_field_toast("SCAVENGED A MAGAZINE")
			elif roll < 0.8 and equipment_manager:
				equipment_manager.add_grenade(1)
				_field_toast("FOUND A GRENADE")
			else:
				CampaignState.intel_points += 1
				CampaignState.save_campaign()
				_field_toast("DOCUMENTS RECOVERED - INTEL GAINED (+1)")
			return


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

## Recoil system. Additive view offsets in radians that decay back to zero;
## they NEVER touch camera_rotation_x / _yaw_base, so the shot recovers to the
## exact aim the player held. The kick is applied INSTANTLY in apply_recoil (a
## lerped rise peaked at ~60% of the authored degrees and felt like foam).
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_recovery: float = 12.0  # exp decay per second, set per shot
var _yaw_base: float = 0.0          # body yaw from mouse look, before recoil
const RECOIL_MAX_PITCH: float = 0.35  # rad (~20 deg)

func _ready() -> void:
	_setup_suppression()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	mouse_sensitivity = GameSettings.mouse_sensitivity  # W83
	_yaw_base = rotation.y  # seed recoil-recoverable yaw from spawn orientation

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

	var gw := get_tree().get_first_node_in_group("game_world")
	if gw != null and "gameplay_grid" in gw:
		_grid = gw.gameplay_grid


func _input(event: InputEvent) -> void:
	if not GameManager.can_player_act():
		return

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		_handle_mouse_look(mouse_event.relative)


func _handle_mouse_look(mouse_delta: Vector2) -> void:
	_yaw_base -= mouse_delta.x * mouse_sensitivity
	camera_rotation_x -= mouse_delta.y * mouse_sensitivity
	camera_rotation_x = clampf(camera_rotation_x, deg_to_rad(-MAX_LOOK_ANGLE), deg_to_rad(MAX_LOOK_ANGLE))
	_apply_look()


## Single writer for view angles. Called from mouse look (poll rate) AND recoil
## recovery (physics rate) so pitch is no longer 60Hz-quantized while yaw is smooth.
func _apply_look() -> void:
	head.rotation.x = clampf(
		camera_rotation_x + _recoil_pitch,
		deg_to_rad(-MAX_LOOK_ANGLE), deg_to_rad(MAX_LOOK_ANGLE))
	rotation.y = _yaw_base + _recoil_yaw


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
	_play_footstep_sound()
	# W28: Silent Movement skill shrinks every footstep radius.
	var quiet_mult: float = 1.0 / (1.0 + 0.12 * float(CampaignState.player_skill("silent_movement")))
	# R73: wading a rice paddy throws a wake - louder than dry ground, no hiding it.
	if _in_rice_paddy:
		quiet_mult *= 2.2
	if is_crouching:
		NoiseBus.emit_noise(NoiseBus.NoiseType.FOOTSTEP, global_position, 0, 3.0 * quiet_mult)
	elif is_sprinting:
		NoiseBus.emit_noise(NoiseBus.NoiseType.FOOTSTEP_SPRINT, global_position, 0,
			float(NoiseBus.RADII[NoiseBus.NoiseType.FOOTSTEP_SPRINT]) * quiet_mult)
	else:
		NoiseBus.emit_noise(NoiseBus.NoiseType.FOOTSTEP, global_position, 0,
			float(NoiseBus.RADII[NoiseBus.NoiseType.FOOTSTEP]) * quiet_mult)


## R96: photo mode - free-fly spectator cam. No combat, no HUD, snap back to
## where you toggled it on (no fall damage from wherever you flew off to).
var _photo_mode: bool = false
var _photo_saved_pos: Vector3 = Vector3.ZERO
const PHOTO_FLY_SPEED: float = 9.0


func _toggle_photo_mode() -> void:
	_photo_mode = not _photo_mode
	if _photo_mode:
		_photo_saved_pos = global_position
		if weapon_holder and weapon_holder.weapon_model:
			weapon_holder.weapon_model.visible = false
	else:
		global_position = _photo_saved_pos
		velocity = Vector3.ZERO
		if weapon_holder and weapon_holder.weapon_model:
			weapon_holder.weapon_model.visible = true
	for group in ["mission_hud", "combat_hud"]:
		var node := get_tree().get_first_node_in_group(group)
		if node:
			node.visible = not _photo_mode


func _update_photo_fly(delta: float) -> void:
	head.rotation.x = camera_rotation_x
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var vertical: float = (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("crouch") else 0.0)
	var move: Vector3 = camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	global_position += (move + Vector3.UP * vertical) * PHOTO_FLY_SPEED * delta


func _physics_process(delta: float) -> void:
	if not GameManager.can_player_act():
		return

	if Input.is_action_just_pressed("photo_mode") and not is_seated \
			and not (health_system and health_system.is_downed):
		_toggle_photo_mode()
	if _photo_mode:
		_update_photo_fly(minf(delta, 0.066))
		return

	_update_suppression(minf(delta, 0.066))

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
	_update_hold_breath(capped_delta)

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

	# Smoke (W39). (Key 5 belongs to the fire menu while it's open.)
	if Input.is_action_just_pressed("throw_smoke") and not MissionDirector.any_fire_menu_open:
		_throw_smoke()

	# Claymore (W58): key 6, placed at your feet facing your aim. Key 6 doubles as
	# CBU while ON THE NET (cbu_strike shares the physical key), so the guard below
	# keeps one press from doing both. [audit fix: key-6 double-bind]
	if Input.is_action_just_pressed("place_claymore") and claymore_count > 0 and is_on_floor() \
			and not MissionDirector.any_fire_menu_open:
		claymore_count -= 1
		var aim := get_aim_direction()
		Claymore.place(get_tree().current_scene, global_position + Vector3(aim.x, 0, aim.z).normalized() * 1.2, aim)

	# Corpse loot + prisoner capture (W61/W63/W80).
	if Input.is_action_just_pressed("interact"):
		_try_field_interact()

	# Pop flare (W54): key 7, night tool.
	if Input.is_action_just_pressed("pop_flare") and flare_count > 0:
		flare_count -= 1
		var aim7 := get_aim_direction()
		IllumFlare.pop(get_tree().current_scene, global_position + Vector3(aim7.x, 0, aim7.z).normalized() * 30.0)
		_field_toast("FLARE OUT")

	# Binoculars (W55): hold B - zoom + mark what you glass.
	_update_binoculars(delta)

	# Stamina + wounds gate sprinting (W33/W37).
	if _winded and stamina > stamina_max * 0.35:
		_winded = false
	var can_sprint := not is_crouching and not is_prone and not health_system.is_healing \
		and not wounded_legs and not _winded and stamina > 0.0 \
		and not MissionDirector.any_fire_menu_open
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

	# On the radio (handset up): you can only shuffle - slowed and exposed while you
	# call it in. "Getting on the net" is a real commitment, not a free action.
	if MissionDirector.any_fire_menu_open:
		current_speed = minf(current_speed, CROUCH_SPEED)

	# R73: flooded rice paddy drags at your legs.
	if _grid != null and _grid.get_terrain_type(global_position) == GameplayGrid.TerrainType.RICE_PADDY:
		current_speed /= float(GameplayGrid.MOVEMENT_COSTS[GameplayGrid.TerrainType.RICE_PADDY])

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
	# Framerate-exact exponential decay back to the held aim.
	var decay: float = 1.0 - exp(-_recoil_recovery * delta)
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, decay)
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, decay)
	_apply_look()


## Apply recoil to the view (called by WeaponHolder on every round). The kick is
## INSTANT; only the recovery is smoothed. Yaw is recoverable (decays to zero)
## instead of permanently spinning the body like the old rotate_y did.
func apply_recoil(vertical: float, horizontal: float, recovery: float = 12.0) -> void:
	_recoil_pitch = minf(_recoil_pitch + deg_to_rad(vertical), RECOIL_MAX_PITCH)
	_recoil_yaw += deg_to_rad(randf_range(-horizontal, horizontal))
	_recoil_recovery = recovery
	_apply_look()


## Take damage - forwarded from health system
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null, _zone: String = "BODY") -> int:
	# W66: directional damage indicator - where is it coming from?
	if attacker is Node3D and camera:
		var to_attacker: Vector3 = ((attacker as Node3D).global_position - global_position)
		to_attacker.y = 0.0
		if to_attacker.length() > 0.5:
			var fwd: Vector3 = -camera.global_transform.basis.z
			fwd.y = 0.0
			var rel: float = fwd.normalized().signed_angle_to(to_attacker.normalized(), Vector3.UP)
			var hud_node := get_tree().get_first_node_in_group("mission_hud")
			if hud_node and hud_node.has_method("show_damage_direction"):
				hud_node.show_damage_direction(-rel)
	return health_system.take_damage(amount, damage_type, attacker)


## Get health system
func get_health_system() -> HealthSystem:
	return health_system


## Setup body part hitzones for damage detection
func _setup_hitzones() -> void:
	# Head - critical hit zone (4x damage)
	_create_hitzone(Hitzone.ZoneType.HEAD, Vector3(0, 1.65, 0), 0.15)
	# Chest - center mass (2.0x)
	_create_hitzone(Hitzone.ZoneType.TORSO, Vector3(0, 1.3, 0), 0.3, 0.35)
	# Gut - devastating (1.75x). Locational parity with enemies: you are as mortal.
	_create_hitzone(Hitzone.ZoneType.GUT, Vector3(0, 0.9, 0), 0.28, 0.3)
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


func _setup_suppression() -> void:
	# Full-screen overlay on its own layer, built in code (no scene edit).
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_supp_rect = ColorRect.new()
	_supp_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_supp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_supp_mat = ShaderMaterial.new()
	_supp_mat.shader = load("res://terrain/shaders/suppression.gdshader")
	_supp_mat.set_shader_parameter("amount", 0.0)
	_supp_rect.material = _supp_mat
	layer.add_child(_supp_rect)

	# One lowpass on Master, wide open until suppression closes it (everything
	# goes underwater under heavy fire).
	var mi := AudioServer.get_bus_index("Master")
	if mi >= 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(mi, lp)
		_supp_lowpass_idx = AudioServer.get_bus_effect_count(mi) - 1


## A round cracked past. Called by enemies on a near-miss of the player.
func add_suppression(amount: float = SUPPRESS_PER_NEARMISS) -> void:
	suppression = clampf(suppression + amount, 0.0, 1.0)


## Drives the overlay, camera shake and audio muffle every frame, then decays.
func _update_suppression(delta: float) -> void:
	if _supp_mat != null:
		_supp_mat.set_shader_parameter("amount", suppression)

	# Camera shake: pure-visual h/v offset jitter (never touches aim direction).
	if camera != null:
		if suppression > 0.02:
			_shake_seed += delta * 34.0
			var s := suppression * suppression * SUPPRESS_SHAKE_MAX  # ramp late
			camera.h_offset = sin(_shake_seed) * s
			camera.v_offset = cos(_shake_seed * 1.37) * s
		elif absf(camera.h_offset) > 0.0001 or absf(camera.v_offset) > 0.0001:
			camera.h_offset = 0.0
			camera.v_offset = 0.0

	# Audio muffle: high cutoff = clear, drops toward 600Hz at full suppression.
	if _supp_lowpass_idx >= 0:
		var mi := AudioServer.get_bus_index("Master")
		if mi >= 0:
			var eff := AudioServer.get_bus_effect(mi, _supp_lowpass_idx) as AudioEffectLowPassFilter
			if eff != null:
				eff.cutoff_hz = lerpf(20500.0, 650.0, suppression)

	# Decay - faster when you got low. This is the payoff: crawling out of the
	# beaten zone actively clears the effect.
	var low: bool = is_prone or is_crouching
	suppression = maxf(0.0, suppression - (SUPPRESS_DECAY_LOW if low else SUPPRESS_DECAY) * delta)
