## patrol_lab.gd - THE GOD'S-EYE VIEW. Watch the VC live.
##
## A probe proves make_patrol_circuit()'s star stride is coprime with n. It cannot
## show you a file of four men walking a treeline, or the moment they lose you and
## fan into wedges. This can. It is the eyeball companion to probe_patrol/probe_hunt.
##
## IT DRIVES THE REAL CODE. Real EnemyBase, real EnemySquad, real make_patrol_circuit,
## real perception, real hunt. A visualiser with its own private simulation is a lie
## that will happily show you a bug working perfectly.
##
##   godot --path . res://tools/patrol_lab.tscn
##
## CONTROLS
##   WASD ....... drive the ghost (you). They can SEE you. They cannot hurt you.
##   SHIFT ...... run (louder, more visible)
##   CTRL ....... crouch (harder to see)
##   TAB ........ toggle route lines
##   1/2/3/4 .... time scale x1 / x3 / x8 / x20   (watch a whole circuit in a minute)
##   R .......... regenerate the province with a new seed
##   ESC ........ quit
extends Node3D

const PATROLS: int = 3
const MEN_PER: int = 4
const AO: float = 260.0        ## half-extent of the lab ground

const TIER_COLOR: Array[Color] = [
	Color(0.35, 0.85, 0.40),   # RELAXED    - green
	Color(0.95, 0.85, 0.25),   # SUSPICIOUS - yellow
	Color(1.00, 0.55, 0.15),   # ALERT      - orange (this is THE HUNT)
	Color(1.00, 0.25, 0.20),   # COMBAT     - red
]
const SQUAD_COLOR: Array[Color] = [
	Color(0.45, 0.70, 1.00), Color(0.80, 0.55, 1.00), Color(0.45, 0.95, 0.85),
]

var _rng := RandomNumberGenerator.new()
var _seed: int = 1
var _ghost: CharacterBody3D
var _lines: MeshInstance3D
var _im := ImmediateMesh.new()
var _hud: Label
var _show_routes: bool = true
var _squads: Array = []        ## [{id, route, men: Array[EnemyBase], color}]


func _ready() -> void:
	_build_ground()
	_build_camera()
	_build_ghost()
	_build_lines()
	_build_hud()
	_generate(_seed)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1     # the world layer every LOS ray tests against
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(AO * 2.0, 2.0, AO * 2.0)
	col.shape = box
	col.position = Vector3(0, -1, 0)
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(AO * 2.0, AO * 2.0)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.13, 0.09)   # jungle floor, seen from a Huey
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, 30, 0)
	sun.light_energy = 1.1
	add_child(sun)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = AO * 2.1
	cam.position = Vector3(0, 220, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.far = 600.0
	cam.current = true
	add_child(cam)


## You. They can see you; they cannot hurt you. The point of the lab is to be seen
## and then to break contact and watch what they do about it.
func _build_ghost() -> void:
	_ghost = CharacterBody3D.new()
	_ghost.name = "Ghost"
	_ghost.add_to_group("player")
	_ghost.collision_layer = 0    # bullets and rays pass straight through
	_ghost.collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.7
	cap.radius = 0.35
	col.shape = cap
	_ghost.add_child(col)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 3.2
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1)
	mi.material_override = mat
	mi.position = Vector3(0, 3, 0)
	_ghost.add_child(mi)
	_ghost.position = Vector3(0, 1, 0)
	add_child(_ghost)
	GameManager.player = _ghost


func _build_lines() -> void:
	_lines = MeshInstance3D.new()
	_lines.mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 10
	_lines.material_override = mat
	add_child(_lines)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.add_theme_color_override("font_color", Color(0.9, 0.92, 0.85))
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud)


## ---------------------------------------------------------------- generation

func _generate(s: int) -> void:
	for sq in _squads:
		for m in sq.men:
			if is_instance_valid(m):
				m.queue_free()
	_squads.clear()
	EnemySquad.clear()
	EnemyBase.unreported_corpses.clear()
	EnemyBase.last_combat_contact_ms = -1.0
	_rng.seed = s

	# The anchor pool the generator would build from real map features - a cache, a
	# ville, a ford, a trail junction. Spread, so the circuits have to cross ground.
	var pool: Array[Vector3] = []
	var guard: int = 0
	while pool.size() < 10 and guard < 400:
		guard += 1
		var c := Vector3(_rng.randf_range(-AO + 30, AO - 30), 0, _rng.randf_range(-AO + 30, AO - 30))
		var ok := true
		for e in pool:
			if e.distance_to(c) < 55.0:
				ok = false
				break
		if ok:
			pool.append(c)

	var archetypes: Array[String] = [
		"res://data/enemies/vc_farmer.tres",      # determination 0.25 - goes home
		"res://data/enemies/vc_rifleman.tres",    # 0.45
		"res://data/enemies/nva_regular.tres",    # 0.90 - does NOT go home
	]
	for si in range(PATROLS):
		# REAL generator call. Each patrol gets its own zig-zag.
		var route: Array[Vector3] = EnemyBase.make_patrol_circuit(pool, _rng, _rng.randi_range(5, 7))
		var men: Array = []
		for i in range(MEN_PER):
			var at: Vector3 = route[0] - Vector3(0, 0, 1) * (float(i) * 4.0)
			var e: EnemyBase = EnemyBase.spawn_enemy(self, at, archetypes[si % archetypes.size()])
			e.squad_id = si
			e.patrol_route = route.duplicate()
			e.patrol_file_slot = i        # 0 walks point; the rest trail him
			e._patrol_index = 0
			men.append(e)
		_squads.append({"id": si, "route": route, "men": men,
			"color": SQUAD_COLOR[si % SQUAD_COLOR.size()],
			"archetype": archetypes[si % archetypes.size()].get_file().get_basename()})


## ---------------------------------------------------------------- input & ghost

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	match (e as InputEventKey).keycode:
		KEY_TAB:
			_show_routes = not _show_routes
		KEY_1:
			Engine.time_scale = 1.0
		KEY_2:
			Engine.time_scale = 3.0
		KEY_3:
			Engine.time_scale = 8.0
		KEY_4:
			Engine.time_scale = 20.0
		KEY_R:
			_seed += 1
			_generate(_seed)
		KEY_ESCAPE:
			get_tree().quit()


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): dir.z += 1.0
	if Input.is_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): dir.x += 1.0
	var run: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = (9.0 if run else 4.5) * (0.5 if is_crouching() else 1.0)
	_ghost.velocity.x = dir.normalized().x * speed
	_ghost.velocity.z = dir.normalized().z * speed
	_ghost.velocity.y = -2.0
	_ghost.move_and_slide()


## EnemyBase perception reads these off the player by duck-typing.
func is_crouching() -> bool:
	return Input.is_key_pressed(KEY_CTRL)


func is_moving() -> bool:
	return _ghost != null and Vector2(_ghost.velocity.x, _ghost.velocity.z).length() > 0.3


## ---------------------------------------------------------------- the drawing

func _process(_d: float) -> void:
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var now: float = float(Time.get_ticks_msec())

	for sq in _squads:
		var col: Color = sq.color
		var route: Array = sq.route

		# THE CIRCUIT. Watch it cross the middle - that is the star stride.
		if _show_routes:
			for i in range(route.size()):
				var a: Vector3 = route[i]
				var b: Vector3 = route[(i + 1) % route.size()]
				_line(a, b, Color(col.r, col.g, col.b, 0.5))
				_ring(a, 4.0, col)          # the node
				_ring(a, 1.2, col)

		var det: float = 0.5
		var hunting: bool = false
		for m in sq.men:
			var man := m as EnemyBase
			if man == null or not is_instance_valid(man) or man.is_dead():
				continue
			det = man._determination()
			var tier: int = clampi(int(man.alert_tier), 0, 3)
			var c: Color = TIER_COLOR[tier]

			# THE MAN. Dot + the direction he is actually looking.
			_ring(man.global_position, 2.0, c)
			_line(man.global_position + Vector3.UP * 0.5,
				man.global_position + Vector3.UP * 0.5 + man.facing_dir.normalized() * 7.0, c)

			# WHERE HE IS GOING. On patrol this is his slot in the file; in the hunt
			# it is HIS WEDGE of the net. This line is the whole demo.
			if man.alert_tier >= EnemyBase.AlertTier.ALERT:
				var hp := EnemySquad.hunt_point(man.squad_id, man, now, det)
				if hp != Vector3.ZERO:
					hunting = true
					_line(man.global_position, hp, Color(1.0, 0.55, 0.15, 0.75))
					_ring(hp, 3.0, Color(1.0, 0.55, 0.15, 0.9))
			elif not route.is_empty():
				_line(man.global_position, route[man._patrol_index],
					Color(col.r, col.g, col.b, 0.25))

		# THE NET. The ring they are pushing outward, and where it is anchored.
		if hunting:
			var r: float = EnemySquad.hunt_radius(sq.id, now, det)
			if r > 0.0:
				var anchor: Vector3 = EnemySquad.shared_last_known(sq.id)
				var hs: Dictionary = EnemySquad._squads.get(sq.id, {})
				if hs.has("hunt_anchor"):
					anchor = hs.hunt_anchor
				_ring(anchor, r, Color(1.0, 0.35, 0.1, 0.55), 48)
				_ring(anchor, 2.0, Color(1.0, 0.35, 0.1, 0.9))

	_im.surface_end()
	_hud.text = _readout(now)


func _readout(now: float) -> String:
	var made: bool = EnemyBase.last_combat_contact_ms > 0.0
	var s := "PATROL LAB   [WASD] move  [SHIFT] run  [CTRL] crouch  [TAB] routes  [1-4] speed x%.0f  [R] reseed %d\n" % [Engine.time_scale, _seed]
	s += "%s\n\n" % ("*** YOU'VE BEEN MADE ***" if made else "undetected - they do not know you exist")
	for sq in _squads:
		var alive: int = 0
		var worst: int = 0
		var det: float = 0.5
		for m in sq.men:
			var man := m as EnemyBase
			if man == null or not is_instance_valid(man) or man.is_dead():
				continue
			alive += 1
			worst = maxi(worst, int(man.alert_tier))
			det = man._determination()
		var tier_name: String = ["RELAXED", "SUSPICIOUS", "ALERT (HUNTING)", "COMBAT"][clampi(worst, 0, 3)]
		var hunt := ""
		if EnemySquad.hunt_active(sq.id, now, det):
			var persist: float = EnemySquad.HUNT_BASE_S + EnemySquad.HUNT_DET_S * det
			var start: float = float(EnemySquad._squads[sq.id].get("hunt_start", 0.0))
			var left: float = persist - (now - start) / 1000.0
			hunt = "   net %.0fm, gives up in %.0fs" % [
				EnemySquad.hunt_radius(sq.id, now, det), maxf(0.0, left)]
		s += "SQUAD %d  %-12s  %d men  det %.2f  %s%s\n" % [
			sq.id, sq.archetype, alive, det, tier_name, hunt]
	s += "\nBreak line of sight and WATCH: they fan into wedges and the net grows.\n"
	s += "The farmer gives up in ~41s. The NVA hunts you for 84."
	return s


## ---------------------------------------------------------------- line helpers

func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_im.surface_set_color(c)
	_im.surface_add_vertex(a + Vector3.UP * 0.4)
	_im.surface_set_color(c)
	_im.surface_add_vertex(b + Vector3.UP * 0.4)


func _ring(at: Vector3, r: float, c: Color, seg: int = 16) -> void:
	for i in range(seg):
		var a0: float = TAU * float(i) / float(seg)
		var a1: float = TAU * float(i + 1) / float(seg)
		_line(at + Vector3(cos(a0) * r, 0, sin(a0) * r),
			at + Vector3(cos(a1) * r, 0, sin(a1) * r), c)
