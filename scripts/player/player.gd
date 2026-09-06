## player.gd - Player root node that coordinates all player systems
extends CharacterBody3D

## Preloaded, not by class_name: a fresh script has no global class until the editor
## rescans, and a headless boot would fail on the name.
const SLEEP_SCREEN := preload("res://scripts/ui/screens/sleep_screen.gd")
const SLEEP_STATION := preload("res://scripts/world/sleep_station.gd")

const SATCHEL_CHARGE := preload("res://scripts/world/satchel_charge.gd")

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
## Must match player.tscn's CapsuleShape3D radius (player.tscn:10).
const CAPSULE_RADIUS: float = 0.4
const CROUCH_TRANSITION_SPEED: float = 10.0

## Lean settings
const LEAN_ANGLE: float = -18.0  ## Negative so lean_right tilts right
const LEAN_OFFSET: float = 0.36  ## Positive so lean_right moves right
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
## External movement multiplier (casualty drag, loads). Systems set and restore it.
var external_speed_mult: float = 1.0

## ADR-018: every grunt has the same body. These are constants, not a stat pool -
## no progression may raise them. Player HP 100 is ADR-016's value of record.
const BASE_HP: int = 100
const BASE_STAMINA: float = 100.0

## A field kit is a stopgap: 25% for 12 seconds. Only the armorer's bench (20s at
## the firebase) takes a rifle back to 100.
const FIELD_REPAIR_PCT: float = 25.0
const FIELD_REPAIR_SECONDS: float = 12.0
var _repair_progress: float = 0.0

## Stamina gates the BURST, never the sprint. The AO is kilometres wide and a
## grunt covers it on foot, so running out of air drops you to a sustainable
## lope - it never pins you to a walk (Summoner's ruling 2026-07-19, HLL model).
const PRONE_HEIGHT: float = 0.5
const PRONE_SPEED: float = 1.0
var stamina: float = 100.0
var stamina_max: float = 100.0
const STAMINA_DRAIN: float = 18.0    ## per second sprinting; 100/18 = 5.6s of burst
const STAMINA_REGEN: float = 10.0    ## per second at any speed below the burst
## Sustained pace once the burst is spent: 1 m/s off SPRINT_SPEED, still well
## clear of WALK_SPEED. Unlimited - the only cost of being winded is the metre.
const WINDED_SPEED: float = SPRINT_SPEED - 1.0
var _winded: bool = false

## Limb wounds degrade function until a medkit heal.
var wounded_legs: bool = false
var wounded_arms: bool = false

## Smoke grenades (key 5).
var smoke_count: int = 2
## Hunger drains with field time. Low hunger saps stamina, never health.
var hunger: float = 100.0
var ration_count: int = 2
var repair_kit_count: int = 1
var _hunger_warned: bool = false
## Claymores (key 6).
var claymore_count: int = 2
## Satchel charges. No key of their own: HOLD the interact key at a tunnel mouth
## (ADR-012 shared keys). A tap still goes down the hole, so the collapse never
## gates the descent.
var satchel_count: int = 2
var _satchel_hold_t: float = 0.0
## Pop flares (key 7).
var flare_count: int = 3
## Binoculars.
var _binocs_active: bool = false

## RADIO / RTO HANDSET. `holding_handset` (read by weapon_holder) slings the rifle
## while the PRC-25 handset is in your hand. The placeholder is the viewmodel box
## Caleb's Blender arms+handset replace; the cord anchor is the world-space point
## the RadioHandset's cord runs to. All three are made in bind_radio_handset().
var holding_handset: bool = false
var _handset_placeholder: MeshInstance3D = null
## The real exported handset, when it exists; it retires _handset_placeholder on sight.
var _handset_vm: ItemViewmodel = null
## The knife viewmodel (slot 4). Built on the first draw rather than at _ready, so a build
## with no exported `knife_fp.glb` costs nothing and simply shows no blade.
var _knife_vm: ItemViewmodel = null
const HANDSET_HOLD_POSITION: Vector3 = Vector3(0.16, -0.14, -0.32)
var _handset_cord_anchor: Marker3D = null
## The RTO's handset this player is wired to (arena binds it; real game has none yet).
## set_on_net drives it so "on the net" and "handset in hand" are one state.
var _bound_handset: RadioHandset = null
## Aim reach for the instant handset pass off your RTO.
const RADIO_REACH: float = 3.0

## Hold-breath: short meter, big sway/spread cut while aiming.
var breath_meter: float = 100.0
const BREATH_MAX: float = 100.0
const BREATH_DRAIN: float = 30.0
const BREATH_REGEN: float = 22.0
var is_holding_breath: bool = false

## SPENT LUNGS LOCK OUT. Gating the hold on `breath_meter > 0.0` alone let the meter empty, regen
## one frame's worth, and be held again immediately - so leaning on Shift gave a permanent steady
## sight for the cost of a stutter. A man who has emptied his lungs does not get another breath by
## trying harder: once spent, Shift does nothing until the meter is FULL again.
var _breath_spent: bool = false
## The gasp when the hold breaks. There is no breath audio in the project yet, so this resolves to
## null and the break is silent until a file lands at this path - no code change needed then.
const BREATH_BREAK_SFX: String = "res://assets/audio/sfx/player/breath_break.wav"
var _breath_sfx: AudioStream = null

## Suppression 0..1: near-miss enemy rounds drive it up, and it decays FASTER
## while prone/crouched. Drives the screen shader, camera shake and audio muffle.
var suppression: float = 0.0
const SUPPRESS_DECAY: float = 0.55          ## per second, standing
const SUPPRESS_DECAY_LOW: float = 1.3       ## per second, prone/crouched (reward getting down)
const SUPPRESS_PER_NEARMISS: float = 0.34   ## a round cracking past adds this
const SUPPRESS_SHAKE_MAX: float = 0.035     ## camera h/v offset metres at full
## Jitter frequency. Below ~25 the shake reads as a body flinching; above it the
## camera reads as a broken mount.
const SUPPRESS_SHAKE_HZ: float = 24.0
## FIELD TREATMENT SHAKE. Bandaging is a two-handed job done while kneeling over your own
## leg, and holding the camera perfectly still made it read as a progress bar rather than
## as work. Deliberately UNLIKE the suppression jitter: a third the amplitude, a quarter
## the frequency, and taller than it is wide, because the motion is pulling a wrap tight
## rather than a body flinching from a near miss.
const TREAT_SHAKE_MAX: float = 0.011
const TREAT_SHAKE_HZ: float = 6.5
## Vertical is the working axis; horizontal is the smaller counter-sway.
const TREAT_SHAKE_V_BIAS: float = 1.6
## Each pull settles and the next begins. Slow enough to read as separate movements.
const TREAT_TUG_HZ: float = 1.7
const TREAT_TUG_DEPTH: float = 0.45
## Eased in and out so the camera does not snap the moment the verb starts or is
## interrupted - an instant jolt reads as a bug, not as hands.
const TREAT_SHAKE_EASE: float = 6.0
var _treat_shake: float = 0.0
var _treat_seed: float = 0.0
## Below this on BOTH amount and hurt the shader is the identity transform, and a
## visible ColorRect sampling hint_screen_texture costs a full-screen backbuffer
## copy + blit at native resolution (the CanvasLayer ignores scaling_3d/scale).
const SUPPRESS_OVERLAY_MIN: float = 0.002
var _shake_seed: float = 0.0
var _supp_rect: ColorRect = null
var _supp_mat: ShaderMaterial = null
var _supp_lowpass_idx: int = -1


func _update_hold_breath(delta: float) -> void:
	var want: bool = Input.is_action_pressed("hold_breath") and weapon_holder \
		and weapon_holder.is_aiming and breath_meter > 0.0 and not _breath_spent
	is_holding_breath = want
	if want:
		breath_meter = maxf(0.0, breath_meter - BREATH_DRAIN * delta)
		if breath_meter <= 0.0:
			# The hold BROKE. Locked out from here until the meter reads full again.
			_breath_spent = true
			is_holding_breath = false
			_play_breath_break()
	else:
		breath_meter = minf(BREATH_MAX, breath_meter + BREATH_REGEN * delta)
		# FULL, not "some". A partial recovery re-arming the hold is the same feathering
		# exploit with a longer stutter.
		if _breath_spent and breath_meter >= BREATH_MAX:
			_breath_spent = false


func _play_breath_break() -> void:
	if _breath_sfx == null:
		_breath_sfx = load(BREATH_BREAK_SFX) as AudioStream
	if _breath_sfx == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _breath_sfx
	p.volume_db = -6.0
	p.pitch_scale = randf_range(0.96, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _update_binoculars(delta: float) -> void:
	var want: bool = Input.is_action_pressed("binoculars") and not is_seated
	if want != _binocs_active:
		_binocs_active = want
	if camera:
		var target_fov: float = 18.0 if _binocs_active else 75.0
		if _binocs_active or absf(camera.fov - 75.0) > 0.5:
			if not (weapon_holder and weapon_holder.is_aiming):
				camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)


## THE REPORT VERB (ADR-022 Amendment A): aim at a markable thing and press - the
## noun is inferred from the world, the mark lands on the paper map as a general-
## area circle. Costs: LOS (the ray IS the check), binos up beyond eyes range,
## roughly stationary. A failed press does NOTHING - the field never nags.
const MARK_RANGE_M: float = 300.0
const MARK_EYES_ONLY_M: float = 30.0
const MARK_STILL_SPEED: float = 1.5


## Metres inside which a villager registers what you are doing to the dead.
const EAR_WITNESS_M: float = 45.0
## Necklace growth buckets. The mesh changes at these counts and nowhere between -
## modelling every integer is art cost for no readable gain.
const EAR_BUCKETS: Array[int] = [1, 3, 6, 10, 15]


## Taking ears (Summoner, 2026-07-28). Deliberately NOT a reward: no intel, no score,
## no stat. The count exists so the necklace can grow and so the world can have an
## opinion - a trophy system that only ever pays out reads as the game approving.
func _take_ear(corpse: Node3D) -> void:
	CampaignState.ears_taken += 1
	CampaignState.save_campaign()
	if CampaignState.ears_taken in EAR_BUCKETS:
		_field_toast("THE NECKLACE IS GETTING HEAVY")
	# A villager who SEES this remembers it. ADR-019 governs the reaction: sentiment
	# moves in words, never as a meter, so this only reports the witnessing.
	for c in get_tree().get_nodes_in_group("civilians"):
		var civ := c as Node3D
		if civ == null or not is_instance_valid(civ):
			continue
		if civ.global_position.distance_to(corpse.global_position) > EAR_WITNESS_M:
			continue
		if civ.has_method("on_atrocity_witnessed"):
			civ.call("on_atrocity_witnessed", corpse.global_position)
		_field_toast("THEY SAW YOU DO THAT")
		break


func _report_field_mark() -> void:
	if is_seated or velocity.length() > MARK_STILL_SPEED:
		return
	var origin: Vector3 = get_camera_position()
	var dir: Vector3 = get_aim_direction()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * MARK_RANGE_M, 1 | 4)
	query.exclude = [self]
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return
	var hit: Vector3 = result.position
	var dist: float = origin.distance_to(hit)
	if dist > MARK_EYES_ONLY_M and not _binocs_active:
		return
	var director := get_tree().get_first_node_in_group("mission_director")
	if not (director is FieldDirector):
		return
	var fd := director as FieldDirector
	var camps: Array = []
	for loc in fd.patrol_locations:
		camps.append(loc.get("pos", Vector3.ZERO))
	var segs: Array = []
	var gw := get_tree().get_first_node_in_group("game_world")
	if gw != null and "road_network" in gw:
		var rn := gw.get("road_network") as RoadNetwork
		if rn != null:
			segs = rn.segments
	var kind: String = FieldMarkVerb.infer(result.collider, hit,
		get_tree().get_nodes_in_group("tunnel_entrances"), camps, segs)
	if kind == "":
		return
	fd.state.add_field_mark(kind, hit, FieldMarkVerb.area_radius(dist),
		CampaignState.missions_played)
	if kind == "CONTACT":
		_field_toast("CONTACT - CALLED IT IN, MARKED THE MAP")
	else:
		_field_toast("%s MARKED ON THE MAP" % kind)


## Surface-matched footstep audio (dirt / grass / water via GameplayGrid).
const STEP_DIRT := preload("res://assets/audio/sfx/step_real.wav")
const STEP_GRASS := preload("res://assets/audio/sfx/step_real.wav")
const STEP_WATER := preload("res://assets/audio/sfx/step_water.wav")
var _wade_timer: float = 0.0
var _grid: GameplayGrid = null
## Wading a flooded paddy: slow, loud, exposed.
var _in_rice_paddy: bool = false


func _play_footstep_sound() -> void:
	var stream: AudioStream = STEP_DIRT
	_in_rice_paddy = false
	if _grid != null:
		if _grid.is_water(global_position):
			stream = STEP_WATER
			_wade_timer += 0.5
			# Leeches: linger in the water and pay for it.
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
				stream = STEP_WATER  # a flooded paddy sounds like a wade, not a step
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


## ---------- RADIO / RTO HANDSET ----------

## Wire an RTO's handset to the player: build the viewmodel placeholder box and the
## world-space cord anchor on the player, hand both to the handset, and listen for
## grab / return / snap / taut. Reusable seam - the arena calls this for its RTO,
## and the real game calls it when an RTO joins the squad. Idempotent.
func bind_radio_handset(h: RadioHandset) -> void:
	if h == null:
		return
	_bound_handset = h
	if _handset_cord_anchor == null:
		_handset_cord_anchor = Marker3D.new()
		_handset_cord_anchor.name = "HandsetCordAnchor"
		add_child(_handset_cord_anchor)
		_handset_cord_anchor.position = Vector3(0.25, 1.3, -0.2)  # right chest, world space
	# THE REAL HANDSET IF IT HAS BEEN EXPORTED, the box otherwise. `handset_fp.glb` needs
	# no wrapper scene and no further wiring: exporting it is what swaps these over, and
	# the box below deletes itself from the frame the moment that file exists.
	# ZERO, not HANDSET_HOLD_POSITION: an exported item GLB is already in the camera's
	# frame (eye at its origin) and carries the authored hold pose, so an offset here
	# would apply it twice. The constant still places the fallback box below.
	if _handset_vm == null and camera != null:
		_handset_vm = ItemViewmodel.create(camera, "", Vector3.ZERO, camera, "handset")
	if _handset_vm != null:
		h.held_mesh = _handset_vm
	else:
		if _handset_placeholder == null:
			_handset_placeholder = MeshInstance3D.new()
			_handset_placeholder.name = "HandsetPlaceholder"
			var box := BoxMesh.new()
			box.size = Vector3(0.09, 0.14, 0.05)
			_handset_placeholder.mesh = box
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.12, 0.14, 0.10)
			_handset_placeholder.material_override = m
			_handset_placeholder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			camera.add_child(_handset_placeholder)
			_handset_placeholder.position = HANDSET_HOLD_POSITION
			_handset_placeholder.visible = false
		h.held_mesh = _handset_placeholder
	h.held_endpoint = _handset_cord_anchor
	if not h.handset_taken.is_connected(_on_handset_taken):
		h.handset_taken.connect(_on_handset_taken)
	if not h.handset_returned.is_connected(_on_handset_returned):
		h.handset_returned.connect(_on_handset_returned)
	if not h.cord_taut.is_connected(_on_cord_taut):
		h.cord_taut.connect(_on_cord_taut)


## ---------- KNIFE VIEWMODEL ----------

## Slot 4 draws the blade, leaving it puts the blade away. [K] deliberately does NOT come
## through here: it stabs from any slot without drawing, because reaching for a slot is
## exactly the half-second a silent takedown does not have.
func _on_slot_changed_knife(slot_index: int, _slot_type: Enums.SlotType) -> void:
	if slot_index == EquipmentManager.SLOT_KNIFE:
		if _knife_vm == null and camera != null:
			_knife_vm = ItemViewmodel.create(camera, "", Vector3.ZERO, camera, "knife")
		if _knife_vm != null:
			_knife_vm.deploy()
	elif _knife_vm != null:
		_knife_vm.stow()


## Swing the blade. equipment_manager calls this on FIRE while the knife slot is up;
## lethality is MeleeVerb's, this is only the picture.
func knife_swing() -> void:
	if _knife_vm != null and _knife_vm.visible:
		_knife_vm.play_action()


## [K] from ANY slot. The blade flashes into frame for the swing and goes straight back,
## rather than drawing and staying: a full draw costs the half-second the quick stab exists
## to avoid, and NO picture at all - which is what [K] used to give from any other slot -
## reads as the key doing nothing at all.
func knife_quick_swing() -> void:
	if _knife_vm == null and camera != null:
		_knife_vm = ItemViewmodel.create(camera, "", Vector3.ZERO, camera, "knife")
	if _knife_vm == null:
		return      # not exported yet; the stab itself still lands, MeleeVerb owns that
	if equipment_manager != null 			and equipment_manager.get_current_slot() == EquipmentManager.SLOT_KNIFE:
		knife_swing()      # already holding it - do not put it away afterwards
		return
	_knife_vm.deploy()
	_knife_vm.play_action_then_stow()


## The RTO you are looking at within arm's reach, or null. Aim-based (a deliberate
## look down the sights of your eyes), never proximity - it matches the [F] RADIO
## prompt, and a wall between you and him blocks it (world is in the mask).
func _aimed_radioman() -> AllyBase:
	if camera == null or is_seated:
		return null
	var origin: Vector3 = get_camera_position()
	var dir: Vector3 = get_aim_direction()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * RADIO_REACH, 1 | 2)
	query.exclude = [self]
	var hit: Dictionary = space.intersect_ray(query)
	if hit:
		var col: Object = hit.collider
		if col is AllyBase and (col as Node).is_in_group("radioman"):
			return col as AllyBase
	return null


## The man whose handset is wired to this player, or null. The handset is built
## as a child of its RTO (RadioHandset.attach_to).
func _rto_of_bound_handset() -> AllyBase:
	if _bound_handset != null and is_instance_valid(_bound_handset):
		return _bound_handset.get_parent() as AllyBase
	return null


## THE NET - single source of truth for "on the radio". holding_handset is the
## truth; FieldDirector.fire_menu_open is a terminal mirror driven from _enter_net/
## _exit_net (below). Every way onto the net - the [T] key, the RTO menu's GRAB, a
## dispatch hang-up, a snapped cord - funnels through here, so the two can never
## disagree. When a physical handset is wired (arena), it IS the leash: you can
## only be on the net if the cord reaches. With none wired (real game) the caller's
## _radio_check is the leash and the net opens rifle-slung with no art.
func set_on_net(want: bool) -> void:
	print("[NETDBG] set_on_net(%s) holding=%s bound=%s can_take=%s" % [want, holding_handset,
		_bound_handset, _bound_handset != null and _bound_handset.can_take()])
	if want == holding_handset:
		return
	if want:
		_rebind_nearest_handset()
		if _bound_handset != null and is_instance_valid(_bound_handset) and _bound_handset.can_take():
			if _handset_within_reach():
				_bound_handset.take(self)  # -> handset_taken -> _on_handset_taken -> _enter_net
			else:
				_field_toast("TOO FAR FROM YOUR RADIO MAN FOR THE HANDSET")
		else:
			_enter_net()  # no physical handset wired, or it is already in hand
	else:
		if _bound_handset != null and is_instance_valid(_bound_handset) \
				and _bound_handset.state == RadioHandset.State.HELD:
			_bound_handset.stow()  # -> handset_returned -> _on_handset_returned -> _exit_net
		else:
			_exit_net()


## THE HANDSET FOLLOWS THE NEAREST RADIOMAN (his ruling 2026-08-05: "make it so all
## radiomen are valid call options"). _bound_handset was fixed at spawn to ONE man, so
## standing beside any other radioman failed the cord check and toasted TOO FAR - the
## exact complaint. FieldDirector already accepts any radioman; this is the other half.
## A radioman with no physical handset is still a radio: set_on_net's existing
## no-handset branch takes him onto the net directly.
func _rebind_nearest_handset() -> void:
	if holding_handset:
		return
	var best: RadioHandset = null
	var best_d: float = INF
	for r in get_tree().get_nodes_in_group("radioman"):
		var man := r as Node3D
		if man == null or not is_instance_valid(man):
			continue
		if man.has_method("is_dead") and man.call("is_dead"):
			continue
		var d: float = global_position.distance_to(man.global_position)
		if d >= best_d:
			continue
		for h in man.find_children("*", "RadioHandset", true, false):
			var hs := h as RadioHandset
			if hs != null and is_instance_valid(hs) and hs.can_take():
				best = hs
				best_d = d
				break
	if best != null and best != _bound_handset:
		_bound_handset = best


## Would grabbing the handset now leave the cord already snapped? The held cord runs
## port -> shoulder guide -> the player's hand anchor; if that path already exceeds
## full stretch, taking it would rip straight back out (a one-frame flicker). Refuse
## instead. No cord wired -> always reachable (the caller's _radio_check is the gate).
func _handset_within_reach() -> bool:
	if _bound_handset == null or _bound_handset.cord == null or _handset_cord_anchor == null:
		return true
	var cord: RadioCord = _bound_handset.cord
	if cord.port == null:
		return true
	var hand: Vector3 = _handset_cord_anchor.global_position
	var d: float = cord.port.global_position.distance_to(hand)
	if cord.guide != null:
		d = cord.port.global_position.distance_to(cord.guide.global_position) \
			+ cord.guide.global_position.distance_to(hand)
	return d < cord.cord_length


func _enter_net() -> void:
	if holding_handset:
		return
	holding_handset = true
	if weapon_holder and weapon_holder.weapon_model:
		weapon_holder.weapon_model.visible = false
	if _handset_placeholder:
		_handset_placeholder.visible = true
	# On the net the RTO shadows your back at cord range (his ruling 2026-08-04).
	var rto: AllyBase = _rto_of_bound_handset()
	if rto != null:
		rto.radio_leash = true
		rto.set_order(AllyBase.OrderMode.FOLLOW)
	_field_toast("HANDSET IN HAND - RIFLE SLUNG")
	_notify_net(true)


func _exit_net() -> void:
	if not holding_handset:
		return
	holding_handset = false
	if weapon_holder and weapon_holder.weapon_model:
		weapon_holder.weapon_model.visible = true
	if _handset_placeholder:
		_handset_placeholder.visible = false
	var rto: AllyBase = _rto_of_bound_handset()
	if rto != null:
		rto.radio_leash = false
	_notify_net(false)


## Mirror the net onto the FieldDirector's fire menu. STRICTLY one-way: the mirror
## setter only flips the flag and emits fire_menu_changed - it must NEVER call back
## here, or the two states ping-pong. Do not connect fire_menu_changed to set_on_net.
func _notify_net(open: bool) -> void:
	var d: Node = get_tree().get_first_node_in_group("mission_director")
	print("[NETDBG] _notify_net(%s): director=%s is_fd=%s" % [open, d, d is FieldDirector])
	if d is FieldDirector:
		(d as FieldDirector).set_fire_menu_mirror(open)


func _on_handset_taken(_by: Node3D) -> void:
	# RadioHandset toggles held_mesh.visible directly, which would skip the raise; the
	# signal is where the clip belongs.
	if _handset_vm != null:
		_handset_vm.deploy()
	_enter_net()


func _on_handset_returned() -> void:
	if _handset_vm != null:
		_handset_vm.stow()
	_exit_net()


func _on_cord_taut(is_taut: bool) -> void:
	if is_taut:
		_field_toast("CORD TAUT - THE RADIO IS PULLING")


## Tunnel state.
var _in_tunnel: TunnelRoom = null
var _prompt_poll: float = 0.0


## What [F] would do right now, or "" for nothing. The ranges MUST match
## _try_field_interact's or the prompt promises a verb that will not fire.
func field_interact_prompt() -> String:
	# HIS RACK, FIRST. It only ever answers within 2.5m of one authored marker, so it can
	# never shadow another verb, and it refuses WITH A REASON rather than going dead - a
	# run-terminator the player cannot see the state of is a bug report waiting to happen.
	var rack: String = SLEEP_STATION.prompt(self)
	if not rack.is_empty():
		return rack
	if is_manning_mg:
		return "[F] DISMOUNT"
	var mg: Node3D = _nearby_mg_emplacement()
	if mg != null:
		return "[F] MAN THE GUN"
	if _in_tunnel != null:
		if global_position.distance_to(_in_tunnel.ladder_point()) < 2.5:
			return "[F] CLIMB OUT"
		if not _in_tunnel.looted and global_position.distance_to(_in_tunnel.cache_point()) < 2.2:
			return "[F] SEARCH THE CACHE"
		return ""
	if _aimed_radioman() != null:
		return "[F] RETURN HANDSET" if holding_handset else "[F] TAKE HANDSET"
	for t in get_tree().get_nodes_in_group("temple_shrines"):
		var shrine := t as Node3D
		if shrine and not shrine.has_meta("searched") \
				and global_position.distance_to(shrine.global_position) < 4.0:
			return "[F] SEARCH THE SHRINE"
	for t in get_tree().get_nodes_in_group("tunnel_entrances"):
		var entrance := t as Node3D
		if entrance and global_position.distance_to(entrance.global_position) < 3.0:
			if satchel_count > 0:
				return "[F] GO DOWN THE HOLE    [HOLD F] SATCHEL THE MOUTH"
			return "[F] GO DOWN THE HOLE"
	var doc: AllyBase = _nearby_medic()
	if doc != null:
		return "[F] BANDAGE FROM DOC (%d)" % _squad_ref().medic_bandage_count()
	var gunner: AllyBase = _nearby_gunner()
	if gunner != null:
		return "[F] BELT FROM %s (%d)" % [
			SquadRoster.call_name(gunner.member), _squad_ref().mg_belt_count()]
	var cache: FieldCache = _nearby_field_cache()
	if cache != null:
		return "[F] TAKE FROM %s" % cache.label()
	if _nearby_downed_enemy() != null:
		return "[F] SECURE THE PRISONER"
	var gun: WorldWeapon = _nearby_world_weapon()
	if gun != null:
		return "[F] PICK UP %s" % gun.display_name()
	# Not an [F] verb - [K] is - but the prompt line is where the player looks, and a
	# takedown he cannot see is a mechanic he will never find.
	if MeleeVerb.takedown_ready(self):
		return "[K] SILENT TAKEDOWN"
	return ""


## The claymore has no equipment slot - it is placed straight off its key - so its
## viewmodel is a one-shot: hands come up, plant, hands go away. Built on first use so a
## missing scene costs nothing until then.
const CLAYMORE_VIEWMODEL_PATH: String = "res://scenes/weapons/claymore_viewmodel.tscn"
const CLAYMORE_HOLD_POSITION: Vector3 = Vector3(0.3, -0.3, -0.4)
var _claymore_vm: ItemViewmodel = null


func _play_claymore_plant() -> void:
	if _claymore_vm == null:
		var cam: Camera3D = get_node_or_null("Head/Camera3D") as Camera3D
		if cam == null:
			return
		_claymore_vm = ItemViewmodel.create(cam, CLAYMORE_VIEWMODEL_PATH,
			CLAYMORE_HOLD_POSITION, cam, "claymore")
		if _claymore_vm == null:
			return      # not authored yet; the mine still goes down
	_claymore_vm.deploy()
	_claymore_vm.play_action_then_stow()


## The squad, or null on a bench that has none. HealthSystem already holds the live pointer
## (SquadSystem assigns itself as revive_handler at squad_system.gd:102) - a second lookup
## path would be a second thing to keep true.
func _squad_ref() -> SquadSystem:
	if health_system == null:
		return null
	return health_system.revive_handler as SquadSystem


## Doc, within reach, alive, with something in the bag. Offering the verb on an empty bag
## would promise a bandage that is not there - the prompt has to be able to lie about
## nothing (player.gd's prompt/verb contract).
func _nearby_medic() -> AllyBase:
	var sq: SquadSystem = _squad_ref()
	if sq == null or health_system == null:
		return null
	if health_system.health_packs >= HealthSystem.CARRY_MAX:
		return null
	if sq.medic_bandage_count() <= 0:
		return null
	var doc: AllyBase = sq.member_by_mos("MEDIC")
	if doc == null or not is_instance_valid(doc) or doc.is_dead():
		return null
	return doc if global_position.distance_to(doc.global_position) < 2.5 else null


## Spare belts the gunner will let the player hump before cutting him off.
const MG_BELT_CARRY_MAX: int = 4


## The gunner, within reach, alive, with a belt to give - and ONLY when the player's
## CURRENT gun eats belts (FeedType.BELT: m60/rpd). He hands BELTS, never rifle mags
## (ruling A2) - offering one to a rifleman would be the prompt promising ammo the
## gun cannot take.
func _nearby_gunner() -> AllyBase:
	var sq: SquadSystem = _squad_ref()
	if sq == null or weapon_holder == null:
		return null
	var w: WeaponData = weapon_holder.current_weapon
	if w == null or w.feed != Enums.FeedType.BELT:
		return null
	if weapon_holder.spare_mag_count() >= MG_BELT_CARRY_MAX:
		return null
	if not sq.can_hand_belt():
		return null
	var gunner: AllyBase = sq.member_by_mos("MG")
	if gunner == null or not is_instance_valid(gunner) or gunner.is_dead():
		return null
	return gunner if global_position.distance_to(gunner.global_position) < 2.5 else null


## The nearest box a specialist laid down. Range lives on FieldCache so the prompt and the
## verb cannot drift apart.
func _nearby_field_cache() -> FieldCache:
	var med: FieldCache = FieldCache.nearest(self, FieldCache.Kind.MEDICAL)
	var ammo: FieldCache = FieldCache.nearest(self, FieldCache.Kind.AMMO)
	if med != null and ammo != null:
		return med if global_position.distance_to(med.global_position) 			<= global_position.distance_to(ammo.global_position) else ammo
	return med if med != null else ammo


## Draw ONE thing per press. A box is not a resupply crate: it holds a finite number of a
## single commodity, and taking from it has to feel like taking, not like refilling.
func _take_from_cache(cache: FieldCache) -> void:
	if cache.kind == FieldCache.Kind.MEDICAL:
		if health_system == null or health_system.health_packs >= HealthSystem.CARRY_MAX:
			_field_toast("YOU ARE CARRYING ALL YOU CAN")
			return
		if cache.draw(1) <= 0:
			return
		health_system.health_packs += 1
		health_system.health_pack_changed.emit(health_system.health_packs)
		_field_toast("BANDAGE TAKEN (%d LEFT IN THE BOX)" % cache.stock)
		return
	if weapon_holder == null:
		return
	if cache.draw(1) <= 0:
		return
	# The box hands WHOLE mags - discrete objects, never a rounded top-up.
	weapon_holder.add_full_mags(weapon_holder.current_slot, 2)
	if equipment_manager != null:
		equipment_manager.add_grenade(1)
	_field_toast("AMMO TAKEN (%d LEFT IN THE BOX)" % cache.stock)


## Swap the gun on the ground for the one in your hands. The old weapon is DROPPED, not
## destroyed: a trade you can walk back and undo is the whole point of the verb.
func _take_world_weapon(gun: WorldWeapon) -> void:
	if weapon_holder == null or gun == null or gun.weapon_data == null:
		return
	var taken: WeaponData = gun.weapon_data
	var mags: Array[int] = gun.mags.duplicate()
	var captured: bool = gun.is_captured
	gun.queue_free()
	drop_primary_weapon()
	weapon_holder.equip_captured_weapon(taken)
	# equip_captured_weapon issues a FRESH loadout; a gun off the ground carries
	# whatever was left in it - partial mags at their true counts.
	weapon_holder.set_slot_mags(0, mags)
	# A gun you took off the enemy still sounds like theirs; one of your own does not.
	weapon_holder.primary_is_captured = captured
	_field_toast("PICKED UP THE %s" % taken.display_name.to_upper())


## Zombie-mode wall buys/mystery box name a weapon by its .tres path, never a
## WeaponData reference - they do not carry a live handle on the player. Give it
## one the same way a battlefield pickup does: through equip_captured_weapon.
func give_weapon(weapon_path: String) -> void:
	if weapon_holder == null or weapon_path.is_empty():
		return
	var data := load(weapon_path) as WeaponData
	if data == null:
		return
	weapon_holder.equip_captured_weapon(data)
	_field_toast("PICKED UP THE %s" % data.display_name.to_upper())


## True when either slot already carries the gun at this path - the wall buy uses
## this to decide "sell me the gun" vs "sell me ammo for the one I have."
func has_weapon_path(weapon_path: String) -> bool:
	if weapon_holder == null or weapon_path.is_empty():
		return false
	var primary: WeaponData = weapon_holder.primary_weapon
	var secondary: WeaponData = weapon_holder.secondary_weapon
	return (primary != null and primary.resource_path == weapon_path) \
		or (secondary != null and secondary.resource_path == weapon_path)


## Top off the slot carrying this weapon: full magazine plus a paid resupply of
## spare mags. Only fires on a slot that already holds the gun (has_weapon_path
## gates the wall buy's "ammo" price before this is ever called).
func refill_ammo(weapon_path: String) -> void:
	if weapon_holder == null or weapon_path.is_empty():
		return
	var primary: WeaponData = weapon_holder.primary_weapon
	var secondary: WeaponData = weapon_holder.secondary_weapon
	var slot: int = -1
	if primary != null and primary.resource_path == weapon_path:
		slot = 0
	elif secondary != null and secondary.resource_path == weapon_path:
		slot = 1
	if slot < 0:
		return
	var w: WeaponData = primary if slot == 0 else secondary
	var m: Array[int] = weapon_holder.slot_mags(slot)
	if m.is_empty():
		m.append(0)
	m[0] = w.magazine_size
	weapon_holder.add_full_mags(slot, 4)


## Put the current primary on the ground in front of you. Returns false when there is
## nothing to drop, so the [G] handler can stay quiet instead of toasting at empty hands.
func drop_primary_weapon() -> bool:
	if weapon_holder == null or weapon_holder.primary_weapon == null:
		return false
	var aim: Vector3 = get_aim_direction()
	var flat := Vector3(aim.x, 0.0, aim.z)
	flat = flat.normalized() if flat.length() > 0.01 else -global_transform.basis.z
	var at: Vector3 = global_position + flat * 1.0
	WorldWeapon.drop(get_tree().current_scene, weapon_holder.primary_weapon, at,
		weapon_holder.primary_mags.duplicate(), weapon_holder.primary_is_captured)
	return true


## Loot mags come PARTIAL - 5-18 rounds each, seeded from where they lay
## (ADR-010: a reloaded save finds the same rounds).
static func _seeded_partial_mags(at: Vector3, n: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(at.x * 10.0), int(at.z * 10.0)))
	var out: Array[int] = []
	for _i in range(n):
		out.append(5 + rng.randi() % 14)
	return out


## The nearest weapon on the ground within reach, or null. Range lives on WorldWeapon so
## the prompt and the verb below cannot drift apart.
func _nearby_world_weapon() -> WorldWeapon:
	var best: WorldWeapon = null
	var best_d: float = WorldWeapon.PICKUP_RANGE_M
	for n in get_tree().get_nodes_in_group(WorldWeapon.GROUP):
		var w := n as WorldWeapon
		if w == null or not is_instance_valid(w) or w.weapon_data == null:
			continue
		var d: float = global_position.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	return best


## An unoccupied MG emplacement within reach of the gunner stand, or null. The
## range MUST match the verb in _try_field_interact (prompt/verb contract).
func _nearby_mg_emplacement() -> Node3D:
	for e in get_tree().get_nodes_in_group("mg_emplacements"):
		var emp := e as Node3D
		if emp == null or not emp.has_method("man_by_player"):
			continue
		if bool(emp.call("is_occupied")):
			continue
		var stand: Vector3 = emp.call("gunner_stand_pos")
		if global_position.distance_to(stand) < MGEmplacement.REACH:
			return emp
	return null


## A downed-alive, not-yet-secured enemy within reach, or null. Range MUST match
## the surrendered-prisoner verb (prompt/verb contract). secure() re-checks the
## state, so a race with FINISH or bleed-out just returns false.
func _nearby_downed_enemy() -> EnemyBase:
	for e in get_tree().get_nodes_in_group("enemies"):
		var man := e as EnemyBase
		if man == null or not is_instance_valid(man):
			continue
		if not man.is_downed or man.is_in_group("captured"):
			continue
		if global_position.distance_to(man.global_position) < 2.8:
			return man
	return null


## The tunnel mouth within reach, or null.
func _nearby_tunnel_entrance() -> Node3D:
	for t in get_tree().get_nodes_in_group("tunnel_entrances"):
		var entrance := t as Node3D
		if entrance != null and global_position.distance_to(entrance.global_position) < 3.0:
			return entrance
	return null


func _enter_tunnel(entrance: Node3D) -> void:
	var room := TunnelRoom.get_or_create(get_tree().current_scene, entrance)
	_in_tunnel = room
	global_position = room.entry_point()
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	_field_toast("GOING DOWN. TIGHT IN HERE.")


## The grenadier is the demo man (SkillCatalog.MOS_SKILL) - HIS demolitions
## rating is what makes the charge go in fast and sure. Pillar 4: the squad is
## the RPG, so the player's own hands never improve.
func _satchel_hold_seconds() -> float:
	var lvl: int = CampaignState.roster_skill("GRENADIER", "demolitions")
	return maxf(0.9, 2.2 - 0.16 * float(lvl))


## HOLD interact at a tunnel mouth to SET A CHARGE on it. The charge burns
## SATCHEL_CHARGE.FUSE_S and then the mouth is gone: the enemy can no longer surface
## there, and it is still gone next patrol (ADR-029 Amendment B). There is
## deliberately no counter, panel or marker for what you have destroyed - the only
## way to learn that is to walk back and look. The burning fuse IS on the HUD.
## SACKING OUT IS A HOLD, NEVER A TAP (War Room 2026-08-28). Sleep ends the run and reads
## the dead; an accidental tap that does that is the worst defect this verb can ship. Same
## tap/hold split the satchel uses, and while the hold is live the tap verb is suppressed so
## one press cannot fire both.
const SLEEP_HOLD_S: float = 1.1
var _sleep_hold_t: float = 0.0
## Eight hours on a cot is not free rest. He wakes hungry - otherwise sleep hands out a bank,
## a rank, a replacement lift and a fresh fire-support day and costs nothing at all.
const SLEEP_HUNGER_COST: float = 35.0
var _sleeping: bool = false


func _tick_sleep_hold(delta: float) -> void:
	if _sleeping or not SLEEP_STATION.can_sleep(self):
		_sleep_hold_t = 0.0
		return
	if not Input.is_action_pressed("interact"):
		_sleep_hold_t = 0.0
		return
	_sleep_hold_t += delta
	if _sleep_hold_t >= SLEEP_HOLD_S:
		_sleep_hold_t = 0.0
		_sack_out()


func _sack_out() -> void:
	if _sleeping:
		return
	_sleeping = true
	hunger = maxf(0.0, hunger - SLEEP_HUNGER_COST)
	await SLEEP_SCREEN.run(self)
	_sleeping = false


func _tick_satchel_hold(delta: float) -> void:
	if _in_tunnel != null or satchel_count <= 0 or not GameManager.can_player_act():
		_satchel_hold_t = 0.0
		return
	var entrance: Node3D = _nearby_tunnel_entrance()
	if entrance == null:
		_satchel_hold_t = 0.0
		return
	if Input.is_action_just_released("interact"):
		# Released short of the threshold: that was a tap, so go down the hole.
		if _satchel_hold_t > 0.0:
			_enter_tunnel(entrance)
		_satchel_hold_t = 0.0
		return
	if not Input.is_action_pressed("interact"):
		_satchel_hold_t = 0.0
		return
	_satchel_hold_t += delta
	if _satchel_hold_t >= _satchel_hold_seconds():
		# Consumed. Negative parks the timer so the tap-on-release branch above
		# cannot also fire from the same press.
		_satchel_hold_t = -1.0
		_satchel_the_mouth(entrance)


func _satchel_the_mouth(entrance: Node3D) -> void:
	satchel_count -= 1
	var sq: SquadSystem = _squad_ref()
	var demo: AllyBase = sq.member_by_mos("GRENADIER") if sq != null else null
	if demo != null:
		var dp: int = SquadRoster.credit_use(demo.member, "demolitions", 3)  # learn-by-doing
		if dp > 0:
			demo.on_skill_up("demolitions", dp)
	# THE FUSE IS THE POINT. The charge used to go off in the setter's hands and take
	# the squad with it. It now burns SATCHEL_CHARGE.FUSE_S with the count on the HUD.
	# Off the group first: nobody descends a charged hole and nobody charges it twice.
	entrance.remove_from_group("tunnel_entrances")
	SATCHEL_CHARGE.plant(get_tree().current_scene, entrance.global_position, entrance, self)
	_field_toast("CHARGE SET - %d SECONDS - GET BACK" % int(SATCHEL_CHARGE.FUSE_S))


## Interact: capture / loot / crate / tunnel enter-exit.
func _try_field_interact() -> void:
	# The medic's crate. First because it is the smallest, most specific target in reach -
	# a man standing over it is reaching for it, not for the MG two metres past it.
	var med_crate: MedicalCrate = MedicalCrate.nearest(self)
	if med_crate != null and health_system != null:
		var got: int = med_crate.take(health_system)
		if got > 0:
			_field_toast("TOOK %d BANDAGES" % got)
		else:
			_field_toast("CARRYING ALL YOU CAN")
		return
	# Tunnel exit (when underground).
	if _in_tunnel != null:
		if global_position.distance_to(_in_tunnel.ladder_point()) < 2.5:
			global_position = _in_tunnel.surface_return
			reset_physics_interpolation()  # teleport: do not streak across the map
			velocity = Vector3.ZERO
			_field_toast("BACK IN THE GREEN")
			_in_tunnel = null
			return
		if not _in_tunnel.looted and global_position.distance_to(_in_tunnel.cache_point()) < 2.2:
			_in_tunnel.looted = true
			CampaignState.add_intel(2)
			# The tunnel is the dungeon; this is where its reward can land.
			var fd_t: Node = get_tree().get_first_node_in_group("mission_director")
			if fd_t != null and fd_t.has_method("try_intel_stash"):
				fd_t.call("try_intel_stash")
			# Stripping the stash is one of the three things that FINISH a sweep
			# (Summoner, 2026-08-28). The director decides whether this hole is the
			# one he was sent to; here we only report that it happened.
			if fd_t != null and fd_t.has_method("report_stash_cleared"):
				fd_t.call("report_stash_cleared", _in_tunnel.surface_return)
			CampaignState.save_campaign()
			if weapon_holder:
				weapon_holder.add_found_mags(weapon_holder.current_slot,
					_seeded_partial_mags(_in_tunnel.cache_point(), 2))
			_field_toast("TUNNEL CACHE - DOCUMENTS AND AMMO (+2 INTEL)")
			return
	# Mount an unoccupied MG emplacement within reach - you are still a rifleman,
	# now behind a bigger gun, arc-limited and exposed (Pillar 4).
	var mg: Node3D = _nearby_mg_emplacement()
	if mg != null:
		mg.call("man_by_player", self)
		return
	# Aiming at your RTO within reach: the handset passes INSTANTLY - no menu (his
	# ruling 2026-08-04). Already holding it -> hand it back.
	var rto: AllyBase = _aimed_radioman()
	if rto != null:
		set_on_net(not holding_handset)
		return
	# Temple shrine: one-time offering search (intel + flavor).
	for t in get_tree().get_nodes_in_group("temple_shrines"):
		var shrine := t as Node3D
		if shrine and not shrine.has_meta("searched") \
				and global_position.distance_to(shrine.global_position) < 4.0:
			shrine.set_meta("searched", true)
			CampaignState.add_intel(1)
			_field_toast("OLD SHRINE - SOMEONE LEFT MAPS HERE (+1 INTEL)")
			return
	# Tunnel entrance (topside). With a satchel on the belt the key is shared:
	# _tick_satchel_hold owns the press so a HOLD can mean "blow it" and a TAP
	# still means "go down". Without a satchel the tap descends immediately.
	if satchel_count <= 0:
		var entrance_now: Node3D = _nearby_tunnel_entrance()
		if entrance_now != null:
			_enter_tunnel(entrance_now)
			return
	var doc: AllyBase = _nearby_medic()
	if doc != null:
		var sq: SquadSystem = _squad_ref()
		if sq != null and sq.take_medic_bandage():
			health_system.health_packs += 1
			health_system.health_pack_changed.emit(health_system.health_packs)
			_field_toast("DOC HANDED YOU A BANDAGE (%d LEFT IN HIS BAG)" % sq.medic_bandage_count())
		else:
			_field_toast("DOC IS OUT - NOTHING LEFT IN THE BAG")
		return
	var gunner: AllyBase = _nearby_gunner()
	if gunner != null:
		var sqg: SquadSystem = _squad_ref()
		if sqg != null and sqg.take_mg_belt() and weapon_holder != null:
			weapon_holder.add_full_mags(weapon_holder.current_slot, 1)
			_field_toast("%s HANDED YOU A BELT (%d LEFT ON HIS BACK)" % [
				SquadRoster.call_name(gunner.member), sqg.mg_belt_count()])
		else:
			_field_toast("%s IS OUT - NO BELTS LEFT" % SquadRoster.call_name(gunner.member))
		return
	var cache: FieldCache = _nearby_field_cache()
	if cache != null:
		_take_from_cache(cache)
		return
	# SECURE a downed-alive enemy: pins his bleed clock, joins the capture economy
	# (same +1 intel as a surrender). He stays where he fell - died already fired
	# when he went down, so the tallies hold at one.
	var downed: EnemyBase = _nearby_downed_enemy()
	if downed != null and downed.secure():
		CampaignState.add_intel(1)
		_field_toast("WOUNDS PACKED - PRISONER SECURED")
		return
	for e in get_tree().get_nodes_in_group("surrendered"):
		var prisoner := e as EnemyBase
		# A secured downed man is in this group too; he is already banked above.
		if prisoner and not prisoner.is_downed \
				and global_position.distance_to(prisoner.global_position) < 2.8:
			CampaignState.add_intel(1)
			_field_toast("PRISONER SECURED")
			prisoner.died.emit(prisoner)  # counts for mission tallies
			prisoner.queue_free()
			return
	# A fallen squadmate's kit yields ammo and frags only, never their weapon.
	for a in get_tree().get_nodes_in_group("ally_corpses"):
		var fallen := a as Node3D
		if fallen == null or not is_instance_valid(fallen) or fallen.has_meta("looted"):
			continue
		if global_position.distance_to(fallen.global_position) < 2.5:
			fallen.set_meta("looted", true)
			var member: Dictionary = {}
			if "member" in fallen:
				member = fallen.get("member") as Dictionary
			var who: String = SquadRoster.call_name(member) if not member.is_empty() else "HE"
			if weapon_holder:
				weapon_holder.add_found_mags(weapon_holder.current_slot,
					_seeded_partial_mags(fallen.global_position, 2))
			if equipment_manager:
				equipment_manager.add_grenade(1)
			# THE GUNNER'S BACK (ruling A4): his remaining belts come off the corpse -
			# but only into a gun that takes them. They NEVER convert to rifle mags,
			# and the squad stock zeroes either way: the belts were on him.
			var sq_c: SquadSystem = _squad_ref()
			if str(member.get("mos", "")) == "MG" and sq_c != null and sq_c.mg_belt_count() > 0:
				var belts: int = sq_c.mg_belt_count()
				sq_c.mg_belts = 0
				var w: WeaponData = weapon_holder.current_weapon if weapon_holder else null
				if w != null and w.feed == Enums.FeedType.BELT:
					weapon_holder.add_full_mags(weapon_holder.current_slot, belts)
					_field_toast("%s'S KIT - %d BELTS AND A FRAG RECOVERED" % [who, belts])
				else:
					_field_toast("%s'S KIT - MAGS AND A FRAG. HIS BELTS BURNED WITH HIM." % who)
				return
			_field_toast("%s'S KIT - MAGS AND A FRAG RECOVERED" % who)
			return
	for e in get_tree().get_nodes_in_group("lootable_corpses"):
		var corpse := e as EnemyBase
		if corpse == null or not is_instance_valid(corpse):
			continue
		if global_position.distance_to(corpse.global_position) < 2.5 and not corpse.has_meta("looted"):
			corpse.set_meta("looted", true)
			_take_ear(corpse)
			# THE ONLY RANDOM THING A BODY GIVES IS INTEL (Summoner, 2026-07-30). Searching
			# a man is not a slot machine: his weapon is on the ground where he fell and you
			# take it or you do not, and mags and frags are not conjured out of a roll.
			#
			# No "+1" on screen. Intel accrues SILENTLY (Summoner, 2026-07-28): a visible
			# counter turns patrolling into farming, and ADR-019 already rules that this
			# class of thing is stated in words, never as a number.
			CampaignState.add_intel(1)
			_field_toast("DOCUMENTS RECOVERED")
			var dmf: Node = MissionGenerator.dynamic_factory_ref
			if dmf is DynamicMissionFactory:
				(dmf as DynamicMissionFactory).report_camp_discovered(global_position)
			return
	# LAST, so it never steals [F] from a body, a crate or a prisoner standing on it.
	var gun: WorldWeapon = _nearby_world_weapon()
	if gun != null:
		_take_world_weapon(gun)
		return


## Hunger drains over ~45 minutes of field time. Called from _physics_process.
func _tick_hunger(delta: float) -> void:
	if SaveManager.context != "mission":
		return  # the firebase feeds you
	hunger = maxf(0.0, hunger - delta * (100.0 / (45.0 * 60.0)))
	if hunger < 25.0 and not _hunger_warned:
		_hunger_warned = true
		_field_toast("YOU NEED CHOW - YOUR HANDS ARE GETTING SHAKY [9]")


## 1.0 fed -> 0.55 starving. Applied to stamina_max (you get winded, not wounded).
func hunger_stamina_mult() -> float:
	if hunger >= 50.0:
		return 1.0
	return lerpf(0.55, 1.0, hunger / 50.0)


func _eat_ration() -> void:
	if ration_count <= 0:
		_field_toast("NO RATIONS LEFT")
		return
	if hunger > 90.0:
		return
	ration_count -= 1
	hunger = minf(100.0, hunger + 45.0)
	_hunger_warned = false
	_field_toast("C-RATS DOWN (%d LEFT)" % ration_count)


## A kit is a stopgap, never a fix: 25% and twelve seconds on your knees in the weeds.
## The armorer's bench is the only full clean, and it is back at the firebase.
## Let go and you lose the progress but keep the kit.
func _advance_repair_kit(delta: float) -> void:
	if weapon_holder == null:
		return
	if repair_kit_count <= 0:
		if _repair_progress == 0.0:
			_field_toast("NO CLEANING KIT")
		_repair_progress = 0.0
		return
	if float(weapon_holder.get("weapon_condition")) >= 99.99:
		_field_toast("WEAPON'S CLEAN")
		_repair_progress = 0.0
		return

	_repair_progress += delta / FIELD_REPAIR_SECONDS
	if _repair_progress < 1.0:
		_field_toast("FIELD-STRIPPING... %d%%" % int(_repair_progress * 100.0))
		return

	_repair_progress = 0.0
	repair_kit_count -= 1
	var cond: float = float(weapon_holder.get("weapon_condition"))
	weapon_holder.set("weapon_condition", minf(100.0, cond + FIELD_REPAIR_PCT))
	if weapon_holder.has_method("refresh_after_load"):
		weapon_holder.call("refresh_after_load")
	_field_toast("WEAPON CLEANED TO %d%% (%d KITS LEFT)" % [
		int(minf(100.0, cond + FIELD_REPAIR_PCT)), repair_kit_count])


func _cancel_repair_kit() -> void:
	if _repair_progress > 0.0:
		_repair_progress = 0.0
		_field_toast("FIELD-STRIP INTERRUPTED")


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

## Recoil system. Additive view offsets in RADIANS that decay back to zero. They
## must NEVER touch camera_rotation_x / _yaw_base, so the shot always recovers to
## the exact aim the player held.
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_recovery: float = 12.0  # exp decay per second, set per shot
var _yaw_base: float = 0.0          # body yaw from mouse look, before recoil
const RECOIL_MAX_PITCH: float = 0.35  # rad (~20 deg)

func _ready() -> void:
	_setup_suppression()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	# The player wears the same static hitzone bands as any rigless unit, so enemy
	# rounds resolve zones on HIM exactly as his do on them. Authored standing, then
	# squashed to the live capsule by _handle_crouch.
	HitzoneBuilder._build_static(self, 32, 16, ["hitzone"], true)
	for c in get_children():
		if c is Hitzone:
			hitzones.append(c)
	mouse_sensitivity = GameSettings.mouse_sensitivity
	_yaw_base = rotation.y  # seed recoil-recoverable yaw from spawn orientation

	GameManager.register_player(self)
	CombatManager.register_player(self)

	health_system.setup(self, equipment_manager)
	health_system.downed_ended.connect(_on_downed_ended)
	# Collapse must fire on EVERY door into downed/dead - take_damage() covers the
	# shot with its direction, these cover doors that bypass it (e.g. the direct
	# health_system.take_damage environmental hits). _collapsed makes double-fire moot.
	health_system.downed_started.connect(func(_secs: float) -> void:
		_collapse_camera(-global_transform.basis.z))
	health_system.died.connect(func() -> void:
		_collapse_camera(-global_transform.basis.z))
	equipment_manager.setup(self, weapon_holder, health_system, grenade_handler)
	equipment_manager.slot_changed.connect(_on_slot_changed_knife)
	grenade_handler.setup(self, equipment_manager)

	# ADR-018: every grunt has the same body. No progression touches health or stamina.
	health_system.max_hp = BASE_HP
	health_system.current_hp = health_system.max_hp
	stamina_max = BASE_STAMINA * hunger_stamina_mult()
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
	if is_manning_mg:
		# Clamp the view to the mount's traverse arc (yaw about the downrange centre,
		# pitch within the gun's elevation). No reparent - the camera contract holds.
		var rel: float = wrapf(_yaw_base - _mg_yaw_center, -PI, PI)
		_yaw_base = _mg_yaw_center + clampf(rel, -_mg_yaw_span, _mg_yaw_span)
		camera_rotation_x = clampf(camera_rotation_x, _mg_pitch_min, _mg_pitch_max)
	_apply_look()


## THE SINGLE WRITER for view angles - called from mouse look (poll rate) and
## recoil recovery (physics rate). Nothing else may write head.rotation.x or
## rotation.y directly.
func _apply_look() -> void:
	head.rotation.x = clampf(
		camera_rotation_x + _recoil_pitch,
		deg_to_rad(-MAX_LOOK_ANGLE), deg_to_rad(MAX_LOOK_ANGLE))
	rotation.y = _yaw_base + _recoil_yaw


## Seated mode: glued to a seat marker, head-look only, no collision.
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
	reset_physics_interpolation()
	velocity = Vector3.ZERO


## LADDER CLIMB. A third movement state alongside is_seated and is_manning_mg. The body
## leaves the physics solver entirely while on a rail: move_and_slide collides with the rungs
## and stalls, so the climb writes global_position directly (Ladder header, constraint 1).
var is_climbing: bool = false
var _ladder: Node3D = null


## Called by Ladder when its trigger catches the player.
func start_climbing(ladder: Node3D) -> void:
	if is_climbing or ladder == null or is_seated or is_manning_mg:
		return
	if health_system and health_system.is_downed:
		return
	is_climbing = true
	_ladder = ladder
	velocity = Vector3.ZERO
	_snap_to_rail()
	_field_toast("CLIMBING - [S] TO DROP OFF")


func stop_climbing() -> void:
	if not is_climbing:
		return
	is_climbing = false
	if _ladder != null and is_instance_valid(_ladder) and _ladder.has_method("release_climber"):
		_ladder.call("release_climber")
	_ladder = null
	velocity = Vector3.ZERO


func _snap_to_rail() -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		return
	var p: Vector3 = _ladder.call("rail_point", global_position.y)
	global_position.x = p.x
	global_position.z = p.z
	reset_physics_interpolation()


## W climbs, S descends. Position is written straight through - no move_and_slide.
func _tick_climbing(delta: float) -> void:
	if _ladder == null or not is_instance_valid(_ladder):
		stop_climbing()
		return
	var climb: float = Input.get_action_strength("move_forward") \
		- Input.get_action_strength("move_backward")
	var bot: float = float(_ladder.call("bottom_y"))
	var top: float = float(_ladder.call("top_y"))
	var speed: float = float(_ladder.get("climb_speed"))
	var new_y: float = clampf(global_position.y + climb * speed * delta, bot, top)

	# Step off the bottom.
	if climb < -0.1 and new_y <= bot + 0.1:
		global_position.y = bot
		stop_climbing()
		return
	# Top out ONTO the deck, inboard of the rail, or he slides straight back down.
	if climb > 0.1 and new_y >= top - 0.1:
		global_position = _ladder.call("dismount_point")
		reset_physics_interpolation()
		stop_climbing()
		return

	global_position.y = new_y
	_snap_to_rail()
	velocity = Vector3.ZERO


## MANNED MG. is_manning_mg is a SEPARATE state from is_seated: the seated ride
## kills the rifle (weapon_holder.gd:170), but a gunner FIRES. He is glued to the
## stand, his view clamped to the mount's arc, and he is fully exposed - his
## hitzones stay live, so being on the gun is a way to get shot (Pillar 1).
var is_manning_mg: bool = false
var _mg_emplacement: Node3D = null
var _mg_stand_pos: Vector3 = Vector3.ZERO
var _mg_yaw_center: float = 0.0
var _mg_yaw_span: float = 0.0
var _mg_pitch_min: float = 0.0
var _mg_pitch_max: float = 0.0


## Called by MGEmplacement.man_by_player: snap to the gun, borrow the M60, clamp
## the view to the arc. The emplacement owns occupancy; this owns the body.
func man_mg(emp: Node3D) -> void:
	if is_manning_mg or emp == null:
		return
	is_manning_mg = true
	_mg_emplacement = emp
	_mg_stand_pos = emp.call("gunner_stand_pos")
	_mg_yaw_center = float(emp.call("yaw_center"))
	_mg_yaw_span = float(emp.call("yaw_span_rad"))
	_mg_pitch_min = float(emp.call("pitch_min_rad"))
	_mg_pitch_max = float(emp.call("pitch_max_rad"))

	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = true
	velocity = Vector3.ZERO
	global_position = _mg_stand_pos
	reset_physics_interpolation()

	# View centred downrange, then clamped by _handle_mouse_look while manning.
	_yaw_base = _mg_yaw_center
	camera_rotation_x = clampf(camera_rotation_x, _mg_pitch_min, _mg_pitch_max)
	_recoil_yaw = 0.0
	_recoil_pitch = 0.0
	_apply_look()

	# Freeze the kit on the mounted gun (equipment_manager also guards on this flag).
	if equipment_manager:
		equipment_manager.is_switching = false
		equipment_manager.current_slot = 0
	if weapon_holder:
		weapon_holder.mount_gun(load("res://data/weapons/m60.tres"))
	_field_toast("ON THE GUN - [F] TO GET OFF")


func dismount_mg() -> void:
	if not is_manning_mg:
		return
	is_manning_mg = false
	var emp: Node3D = _mg_emplacement
	_mg_emplacement = null
	if weapon_holder:
		weapon_holder.unmount_gun()
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = false
	if emp != null and is_instance_valid(emp):
		global_position = emp.call("dismount_position")
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	if emp != null and is_instance_valid(emp):
		emp.call("dismount_player")   # release the post


## Glued-to-the-gun tick: stay put, watch for a clean eject, and take [F] to leave.
func _tick_mg_manning(_delta: float) -> void:
	# Downed/killed on the gun: eject FIRST so collision + weapon restore before the
	# downed handler runs next frame (else the mount state soft-locks the man).
	if _mg_emplacement == null or not is_instance_valid(_mg_emplacement) \
			or (health_system and health_system.is_downed):
		dismount_mg()
		return
	global_position = _mg_stand_pos
	velocity = Vector3.ZERO
	if Input.is_action_just_pressed("interact"):
		dismount_mg()


var _footstep_timer: float = 0.0


## Footstep noise for the AI ears. Crouch-walk is near-silent.
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
	# ADR-018: how quiet you are is stance, ground and speed. Never a purchased stat.
	var quiet_mult: float = 1.0
	# Wading a rice paddy throws a wake - louder than dry ground.
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


## Photo mode: free-fly spectator cam. No combat, no HUD; snaps back to where it
## was toggled on, so there is no fall damage from wherever you flew.
var _photo_mode: bool = false
var _photo_saved_pos: Vector3 = Vector3.ZERO
const PHOTO_FLY_SPEED: float = 9.0
## Combat benches disable the free-fly photo cam so a stray P can't drone off mid-firefight.
var allow_photo_mode: bool = true
## Off in VC Zombies, which has no leaning - and that is what frees E (bound to
## lean_right) to be that mode's use key. Default true so the campaign is unchanged.
var allow_lean: bool = true


func _toggle_photo_mode() -> void:
	if not allow_photo_mode:
		return
	_photo_mode = not _photo_mode
	if _photo_mode:
		_photo_saved_pos = global_position
		if weapon_holder and weapon_holder.weapon_model:
			weapon_holder.weapon_model.visible = false
	else:
		global_position = _photo_saved_pos
		reset_physics_interpolation()
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

	_prompt_poll += delta
	if _prompt_poll >= 0.2:
		_prompt_poll = 0.0
		var combat_hud: Node = get_tree().get_first_node_in_group("combat_hud")
		if combat_hud != null and combat_hud.has_method("set_field_prompt"):
			combat_hud.set_field_prompt(field_interact_prompt())

	if Input.is_action_just_pressed("photo_mode") and not is_seated and not is_manning_mg \
			and not (health_system and health_system.is_downed):
		_toggle_photo_mode()
	if _photo_mode:
		_update_photo_fly(minf(delta, 0.066))
		return

	_update_suppression(minf(delta, 0.066))
	_tick_hunger(delta)

	# On the gun: glued to the stand, kit frozen, view arc-clamped - but STILL firing
	# (weapon_holder is not gated on is_manning_mg). Handle its own dismount and stop.
	if is_manning_mg:
		_tick_mg_manning(delta)
		return

	# On a ladder: off the physics solver, riding the rail. Head-look still free.
	if is_climbing:
		_tick_climbing(minf(delta, 0.066))
		return

	# Seated (Huey ride): follow the seat, keep head-look, skip movement.
	if is_seated:
		if _seat_node != null and is_instance_valid(_seat_node):
			global_position = _seat_node.global_position
			reset_physics_interpolation()
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

	if Input.is_action_just_pressed("prone"):
		is_prone = not is_prone

	# Key 5 belongs to the fire menu while it is open.
	if Input.is_action_just_pressed("throw_smoke") and not FieldDirector.any_fire_menu_open:
		_throw_smoke()

	if Input.is_action_just_pressed("use_ration"):
		_eat_ration()

	# HOLD, not press. Cleaning a rifle in the field takes twelve seconds you may
	# not have - firing or sprinting drops it, and you keep the kit.
	if Input.is_action_pressed("use_repair_kit") and not is_sprinting \
			and GameManager.can_player_act():
		_advance_repair_kit(get_physics_process_delta_time())
	else:
		_cancel_repair_kit()

	# Key 6 doubles as CBU while the fire menu is open (cbu_strike shares the
	# physical key), so this guard keeps one press from doing both.
	if Input.is_action_just_pressed("place_claymore") and claymore_count > 0 and is_on_floor() \
			and not FieldDirector.any_fire_menu_open:
		claymore_count -= 1
		var aim := get_aim_direction()
		Claymore.place(get_tree().current_scene, global_position + Vector3(aim.x, 0, aim.z).normalized() * 1.2, aim)
		_play_claymore_plant()

	# [K] stabs without drawing the knife: reaching for a slot is exactly the half-second
	# a silent takedown does not have.
	if Input.is_action_just_pressed("melee") and not FieldDirector.any_fire_menu_open:
		MeleeVerb.strike(self)
		knife_quick_swing()

	# Dropping is a real loss, so it never fires while a menu is eating the key, and it
	# leaves the man empty-handed rather than silently conjuring a replacement.
	if Input.is_action_just_pressed("drop_weapon") and not FieldDirector.any_fire_menu_open:
		if weapon_holder != null and weapon_holder.primary_weapon != null:
			var dropped: String = weapon_holder.primary_weapon.display_name.to_upper()
			if drop_primary_weapon():
				weapon_holder.primary_weapon = null
				weapon_holder.primary_is_captured = false
				if weapon_holder.current_slot == 0:
					weapon_holder.current_weapon = null
				weapon_holder.set_slot_mags(0, [0])
				if weapon_holder.current_slot == 0 and equipment_manager != null:
					equipment_manager.switch_to_slot(1)   # no rifle: draw the sidearm
				_field_toast("DROPPED THE %s" % dropped)

	_tick_satchel_hold(delta)
	_tick_sleep_hold(delta)
	if Input.is_action_just_pressed("interact") and _sleep_hold_t <= 0.0:
		_try_field_interact()

	if Input.is_action_just_pressed("pop_flare") and flare_count > 0:
		flare_count -= 1
		var aim7 := get_aim_direction()
		IllumFlare.pop(get_tree().current_scene, global_position + Vector3(aim7.x, 0, aim7.z).normalized() * 30.0)
		_field_toast("FLARE OUT")

	_update_binoculars(delta)

	if Input.is_action_just_pressed("report_mark"):
		_report_field_mark()

	if _winded and stamina > stamina_max * 0.35:
		_winded = false
	## Wounded legs and the radio still pin you; being winded no longer does.
	# Shift is BOTH verbs, HLL-style: on the sights it holds breath, off them it
	# sprints. Aiming takes the key so one press can never mean both.
	var can_sprint := not is_crouching and not is_prone and not health_system.is_healing \
		and not wounded_legs and not FieldDirector.any_fire_menu_open \
		and not (weapon_holder != null and weapon_holder.is_aiming)
	is_sprinting = Input.is_action_pressed("sprint") and can_sprint and input_dir.y < 0

	if is_sprinting and not _winded:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		if stamina <= 0.0:
			_winded = true
	else:
		stamina = minf(stamina_max, stamina + STAMINA_REGEN * delta)

	if is_prone:
		current_speed = PRONE_SPEED
	elif is_crouching:
		current_speed = CROUCH_SPEED
	elif is_sprinting:
		current_speed = WINDED_SPEED if _winded else SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

	# On the radio you can only shuffle.
	if FieldDirector.any_fire_menu_open:
		current_speed = minf(current_speed, CROUCH_SPEED)

	# A flooded rice paddy drags at your legs.
	if _grid != null and _grid.get_terrain_type(global_position) == GameplayGrid.TerrainType.RICE_PADDY:
		current_speed /= float(GameplayGrid.MOVEMENT_COSTS[GameplayGrid.TerrainType.RICE_PADDY])

	if weapon_holder and equipment_manager.is_weapon_slot():
		var ads_move: float = weapon_holder.current_weapon.ads_move_mult if weapon_holder.current_weapon else 0.6
		var ads_mult: float = lerpf(1.0, ads_move, weapon_holder.get_ads_amount())
		current_speed *= ads_mult

	if abs(lean_amount) > 0.1:
		current_speed *= LEAN_MOVE_MULT

	# External systems (casualty drag, carrying) go LAST so they stack on top.
	current_speed *= external_speed_mult

	if direction:
		velocity.x = lerpf(velocity.x, direction.x * current_speed, delta * ACCELERATION)
		velocity.z = lerpf(velocity.z, direction.z * current_speed, delta * ACCELERATION)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * DECELERATION)
		velocity.z = lerpf(velocity.z, 0.0, delta * DECELERATION)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_prone:
		velocity.y = JUMP_VELOCITY


## "ON YOUR FEET" must mean it: stance and camera reset the moment the medic
## finishes, not whenever the crouch lerp next wins.
func _on_downed_ended(revived: bool) -> void:
	if not revived:
		return
	recover_from_collapse()
	# On your feet with your rifle: a man who was on the horn when he went down is
	# off it now (keeps holding_handset / fire_menu from surviving the revive).
	set_on_net(false)
	is_prone = false
	velocity = Vector3.ZERO
	if head != null:
		head.position.y = STAND_HEIGHT - 0.1


## LOW CEILINGS DUCK YOU. Measured 2026-09-06, tools/probe_bunker_entry.tscn, on the
## shipping compound: the navmesh reaches 36 of the 37 bunker fire points and 32 of 36
## routes clear a torso capsule - the doorways were never shut - but only 6 of 37 take a
## standing 1.8m player. 19 take him only crouched and 12 take him at neither. "The AI
## can get in and I can't" was HEADROOM, and crouch was Ctrl and only Ctrl: he walked
## into a bunker lintel and stopped, and if he ducked under it and released Ctrl he
## stood back up into the roof.
##
## Two rules, both measured against the world, neither of them an input:
##   HOLD - standing where he is would clip solid, so he stays down.
##   DUCK - standing one stride AHEAD would clip solid but crouching there would not,
##          so it is an opening he can pass rather than a wall he cannot.
## A wall fails the second test (crouching hits it too) and never makes him crouch.
const AUTO_CROUCH_LOOKAHEAD_M: float = 0.8


## Does the player's capsule at this height, standing on these feet, touch world solid?
func _capsule_clips(space: PhysicsDirectSpaceState3D, feet: Vector3, height: float) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_RADIUS
	# 4cm of daylight: a capsule resting exactly on the floor contacts the floor.
	cap.height = maxf(height - 0.04, CAPSULE_RADIUS * 2.0 + 0.01)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0.0, height * 0.5 + 0.02, 0.0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return not space.intersect_shape(q, 1).is_empty()


## True while the world, not the key, is holding him down.
var _forced_crouch: bool = false


func _auto_crouch_wanted() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return false
	if _capsule_clips(space, global_position, STAND_HEIGHT):
		return true
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.5:
		return false
	var ahead: Vector3 = global_position + flat.normalized() * AUTO_CROUCH_LOOKAHEAD_M
	return _capsule_clips(space, ahead, STAND_HEIGHT) 		and not _capsule_clips(space, ahead, CROUCH_HEIGHT)


## r4bk: a posture the player did not ask for has to be on screen, or it reads as the
## controls breaking. One line, the same channel the fuse uses.
func _hud_stance(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("mission_hud")
	if hud != null and hud.has_method("show_stance"):
		hud.call("show_stance", text)


func _handle_crouch(delta: float) -> void:
	var held: bool = Input.is_action_pressed("crouch")
	var forced: bool = false
	if not is_prone:
		forced = _auto_crouch_wanted()
	if forced != _forced_crouch:
		_forced_crouch = forced
		_hud_stance("LOW COVER - DOWN" if forced else "")
	is_crouching = (held or forced) and not is_prone
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
		# PRONE_HEIGHT 0.5 < 2*radius: the height setter silently shrinks radius to keep
		# the capsule legal (MEASURED 2026-08-04 on 4.7: r 0.4 -> 0.25) and nothing ever
		# restored it - one prone left a pencil capsule that slips mound-trimesh seams
		# ("Z put me inside the ground", his playtest). Re-assert the authored radius;
		# the setter re-clamps it while low and this returns it on the way up.
		capsule.radius = minf(CAPSULE_RADIUS, capsule.height * 0.5)
		collision_shape.position.y = capsule.height / 2.0
		# THE ZONES FOLLOW THE CAPSULE. They did not, and a prone player's fatal HEAD
		# sphere floated a metre above him while rounds through his real body found
		# nothing to hit.
		HitzoneBuilder.apply_posture_scale(self, capsule.height / STAND_HEIGHT)
		var target_head_y := target_height - 0.1
		head.position.y = lerpf(head.position.y, target_head_y, delta * CROUCH_TRANSITION_SPEED)


func _handle_lean(delta: float) -> void:
	if not allow_lean:
		# Settle upright rather than snapping - a hard zero mid-lean reads as a
		# camera glitch if the flag is ever flipped at runtime.
		lean_amount = lerpf(lean_amount, 0.0, delta * LEAN_SPEED)
		camera.rotation_degrees.z = lean_amount * LEAN_ANGLE
		camera.position.x = lean_amount * LEAN_OFFSET
		return
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


func get_aim_direction() -> Vector3:
	return -camera.global_transform.basis.z


func get_camera_position() -> Vector3:
	return camera.global_position


func is_moving() -> bool:
	return velocity.length() > 0.5


func _handle_recoil(delta: float) -> void:
	# Framerate-exact exponential decay back to the held aim.
	var decay: float = 1.0 - exp(-_recoil_recovery * delta)
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, decay)
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, decay)
	_apply_look()


## Called by WeaponHolder on every round. The kick is INSTANT; only the recovery
## is smoothed. Yaw decays back to zero - it must never permanently spin the body.
func apply_recoil(vertical: float, horizontal: float, recovery: float = 12.0) -> void:
	_recoil_pitch = minf(_recoil_pitch + deg_to_rad(vertical), RECOIL_MAX_PITCH)
	_recoil_yaw += deg_to_rad(randf_range(-horizontal, horizontal))
	_recoil_recovery = recovery
	_apply_look()


## Take damage - forwarded from health system
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null, zone: String = "BODY") -> int:
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
	var dealt: int = health_system.take_damage(amount, damage_type, attacker, zone)
	if is_dead():
		var dir: Vector3 = -global_transform.basis.z
		if attacker is Node3D:
			dir = (global_position - (attacker as Node3D).global_position).normalized()
		_collapse_camera(dir)
	return dealt


var _collapsed: bool = false
var _collapse_tween: Tween = null

## Death/downed collapse (his ruling 2026-08-24: "it should drop down and lay in
## place", never tumble). There is no player body model, so the camera IS the
## falling man: the head drops to ground height and rolls onto its side toward
## the hit, then lies STILL through the medic window. The fade to black comes
## only after force_death (BodySwapSystem's epitaph, or the end card).
func _collapse_camera(hit_dir: Vector3) -> void:
	if _collapsed or camera == null:
		return
	_collapsed = true
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	var vm: Node3D = camera.get_node_or_null("WeaponHolder") as Node3D
	if vm != null:
		vm.visible = false  # dying men do not hold a perfect sight picture
	# Fall side: roll away from the hit, so the shot reads as what put you down.
	var fwd: Vector3 = -camera.global_transform.basis.z
	fwd.y = 0.0
	var side: float = 1.0
	if fwd.length() > 0.1 and hit_dir.length() > 0.1:
		side = -signf(fwd.normalized().cross(hit_dir.normalized()).y)
		if side == 0.0:
			side = 1.0
	_collapse_tween = create_tween().set_parallel(true)
	_collapse_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if head != null:
		_collapse_tween.tween_property(head, "position:y", 0.25, 0.7)
	_collapse_tween.tween_property(camera, "rotation_degrees:z", 75.0 * side, 0.7)


## Back on your feet: the medic made it, or the lives economy woke you in
## another man. Everything _collapse_camera froze comes back in one place.
func recover_from_collapse() -> void:
	if not _collapsed:
		return
	_collapsed = false
	if _collapse_tween != null and _collapse_tween.is_valid():
		_collapse_tween.kill()
	_collapse_tween = null
	if head != null:
		head.position.y = STAND_HEIGHT - 0.1
	if camera != null:
		camera.rotation_degrees.z = 0.0
		var vm: Node3D = camera.get_node_or_null("WeaponHolder") as Node3D
		if vm != null:
			vm.visible = true
	set_physics_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)


## The AI drops a target via has_method("is_dead") + is_dead(), so this MUST
## exist or corpses keep eating fire. Downed counts as dead: the AI breaks off
## during the medic window and shifts to living threats.
func is_dead() -> bool:
	return health_system != null and (health_system.is_dead() or health_system.is_downed)


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
	_supp_rect.visible = false
	layer.add_child(_supp_rect)

	# One lowpass on Master, wide open until suppression closes it.
	var mi := AudioServer.get_bus_index("Master")
	if mi >= 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(mi, lp)
		_supp_lowpass_idx = AudioServer.get_bus_effect_count(mi) - 1


## A round cracked past. Called by enemies on a near-miss of the player.
func add_suppression(amount: float = SUPPRESS_PER_NEARMISS) -> void:
	suppression = clampf(suppression + amount, 0.0, 1.0)


## Diegetic pain (no HP bar): base level = missing HP fraction, set by the HUD on
## every health change; a pulse rides on each fresh hit and decays in ~1.5s. Both
## feed the shader's `hurt` uniform.
var _hurt_level: float = 0.0
var _hurt_pulse: float = 0.0

func set_hurt_level(missing_fraction: float) -> void:
	if missing_fraction > _hurt_level + 0.001:
		_hurt_pulse = 1.0  # fresh wound - flash
	_hurt_level = clampf(missing_fraction, 0.0, 1.0)


## Drives the overlay, camera shake and audio muffle every frame, then decays.
func _update_suppression(delta: float) -> void:
	_hurt_pulse = maxf(0.0, _hurt_pulse - delta / 1.5)
	var hurt: float = clampf(_hurt_level * 0.8 + _hurt_pulse * 0.45, 0.0, 1.0)
	if _supp_mat != null and _supp_rect != null:
		var draw_overlay: bool = suppression > SUPPRESS_OVERLAY_MIN or hurt > SUPPRESS_OVERLAY_MIN
		if draw_overlay:
			_supp_mat.set_shader_parameter("amount", suppression)
			_supp_mat.set_shader_parameter("hurt", hurt)
		if _supp_rect.visible != draw_overlay:
			_supp_rect.visible = draw_overlay

	# Camera shake: pure-visual h/v offset jitter (never touches aim direction).
	#
	# ONE OWNER. Both the suppression jitter and the treatment sway are summed here rather
	# than written from their own systems: h_offset/v_offset are cleared to zero below when
	# the source is quiet, so a second writer anywhere else would be wiped every frame.
	var treating: bool = health_system != null and health_system.is_healing
	_treat_shake = move_toward(_treat_shake, 1.0 if treating else 0.0, delta * TREAT_SHAKE_EASE)
	if camera != null:
		var hx: float = 0.0
		var vy: float = 0.0
		if suppression > 0.02:
			_shake_seed += delta * SUPPRESS_SHAKE_HZ
			var s := suppression * suppression * SUPPRESS_SHAKE_MAX  # ramp late
			hx += sin(_shake_seed) * s
			vy += cos(_shake_seed * 1.37) * s
		if _treat_shake > 0.001:
			_treat_seed += delta * TREAT_SHAKE_HZ
			# The tug envelope is what makes it read as separate pulls instead of a hum.
			var tug: float = 1.0 - TREAT_TUG_DEPTH 				+ TREAT_TUG_DEPTH * absf(sin(_treat_seed * (TREAT_TUG_HZ / TREAT_SHAKE_HZ) * PI))
			var t: float = _treat_shake * TREAT_SHAKE_MAX * tug
			hx += sin(_treat_seed * 0.83) * t
			vy += sin(_treat_seed) * t * TREAT_SHAKE_V_BIAS
		if absf(hx) > 0.0001 or absf(vy) > 0.0001:
			camera.h_offset = hx
			camera.v_offset = vy
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

	var low: bool = is_prone or is_crouching
	suppression = maxf(0.0, suppression - (SUPPRESS_DECAY_LOW if low else SUPPRESS_DECAY) * delta)
