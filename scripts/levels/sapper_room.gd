extends Node3D

## sapper_room.gd - THE SAPPER BENCH. The Summoner's spec, verbatim intent (2026-07-29):
## "a targeted clean AI STRESS TEST that's just me and the blank room and three sappers with
## some barbwires and sandbags that they are trying to blow up. I won't need any squad mates or
## other enemies. I'm just watching that they can get up and blow things up."
##
## It exists because nobody has ever confirmed a sapper detonates. The siege sits at 600s on the
## demo arc, so the one behaviour the whole "fall of the firebase" rests on has never been
## watched land. This answers three questions in one sitting, in this order:
##
##   1. does he REACH the objective       (assault_objective drives his legs)
##   2. does the satchel DETONATE         (SapperCharge, 5m trigger)
##   3. does anything actually BREAK      (Destructible on the AgentRegistry.props blast bus)
##
## Sterile by decree: no squad, no other enemies, no jungle, no weather. Anything that fails
## here is the sapper chain, not the world. (ADR-028 keeps the WORLD on one build path; a bench
## is not a world - it stands up three men and a wall.)
##
## Keys: [R] respawn the wave · [K] kill the standing sappers · [T] blow one wall for reference
## Run: godot --path . res://scenes/levels/sapper_room.tscn

const FIELD: float = 120.0
const SAPPER_DATA: String = "res://data/enemies/vc_sapper.tres"
const SAPPERS: int = 3
## Where the sappers start, and where the wall stands. Far enough that the walk is the test.
const APPROACH_M: float = 45.0
const WALL_SEGMENTS: int = 5
const WALL_SPAN_M: float = 3.0
const WIRE_SEGMENTS: int = 4

var player: CharacterBody3D = null
var _director: FieldDirector = null
var _readout: Label = null
var _sappers: Array[EnemyBase] = []
var _walls: Array[Destructible] = []
var _wave: int = 0
var _t: float = 0.0


func _ready() -> void:
	_build_ground()
	_build_light()
	_spawn_player()
	_build_director()
	_build_targets()
	_build_readout()
	_spawn_wave()


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FIELD, 1.0, FIELD)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(FIELD, FIELD)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.31, 0.20)
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -40.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false   # ADR-026: no dynamic shadow on a bench
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.48, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.60)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)


func _spawn_player() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	if scene == null:
		return
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.set("allow_photo_mode", false)
	# Stand him BESIDE the lane, not in it: he is watching the run, not blocking it.
	player.global_position = Vector3(14.0, 1.0, 8.0)
	GameManager.player = player
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.current = true


## The sapper chain reads a FieldDirector: spawn_tracked_enemy books the man, and
## SapperCharge._detonate calls on_firebase_breach through the mission_director group. Without
## one the satchel would still blow but the breach would go nowhere.
func _build_director() -> void:
	_director = FieldDirector.new()
	_director.name = "FieldDirector"
	add_child(_director)
	_director.add_to_group("mission_director")


## THE REAL WALL, NOT A GREY BOX. The Summoner's note, 2026-07-29: "the models in this stress
## test were not the sandbag models of the firebase." A bench that proves a placeholder breaks
## has proved nothing about the thing that has to break - the authored 9-course revetment with
## its real silhouette and its real collision.
##
## So the targets are lifted straight out of fsb_main_v3.glb: instantiate it, take the parapet
## segments and a wire card, reparent them onto Destructibles, and free the rest of the model.
const FSB_PATH: String = "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
const WALL_MESH_PREFIX: String = "fb_sbg_seg_"
const WIRE_MESH_PREFIX: String = "bwire_card"


func _build_targets() -> void:
	var packed: PackedScene = load(FSB_PATH) as PackedScene
	if packed == null:
		push_error("[SAPPER-ROOM] firebase GLB missing - cannot build the real targets")
		return
	var inst := packed.instantiate() as Node3D
	var walls: Array[MeshInstance3D] = []
	var wires: Array[MeshInstance3D] = []
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm := String(mi.name)
		if nm.begins_with(WALL_MESH_PREFIX) and walls.size() < WALL_SEGMENTS:
			walls.append(mi)
		elif nm.begins_with(WIRE_MESH_PREFIX) and wires.size() < WIRE_SEGMENTS:
			wires.append(mi)
	for i in range(walls.size()):
		var x: float = (float(i) - float(walls.size() - 1) * 0.5) * WALL_SPAN_M
		_walls.append(_adopt(walls[i], Vector3(x, 0.0, -APPROACH_M), 140))
	for i in range(wires.size()):
		var x2: float = (float(i) - float(wires.size() - 1) * 0.5) * 4.0
		_walls.append(_adopt(wires[i], Vector3(x2, 0.0, -APPROACH_M + 9.0), 60))
	inst.queue_free()      # everything not adopted goes with it
	print("[SAPPER-ROOM] targets: %d parapet segment(s) + %d wire card(s) lifted from the GLB"
		% [walls.size(), wires.size()])


## Reparent one authored mesh onto a Destructible and stand it at `at`. The collider is a box
## from the mesh's own AABB: the shipped GLB gives these segments a box hull anyway, and the
## bench is testing DESTRUCTION, not the shot-through-the-slit geometry.
func _adopt(mi: MeshInstance3D, at: Vector3, hp: int) -> Destructible:
	var d := Destructible.new()
	d.kind = "sandbag_wall"
	d.hp = hp
	d.collision_layer = 1
	d.collision_mask = 0
	add_child(d)
	d.global_position = at
	var box: AABB = mi.mesh.get_aabb()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	cs.position = box.position + box.size * 0.5
	d.add_child(cs)
	mi.get_parent().remove_child(mi)
	d.add_child(mi)
	mi.transform = Transform3D.IDENTITY      # the model's own placement is 100m away
	AgentRegistry.register(d, AgentRegistry.Kind.PROP)
	return d


## Stand up the wave. Each man gets the objective AND the charge - the same two calls
## MarchingCell.materialize makes, so this bench tests the shipped path, not a copy.
func _spawn_wave() -> void:
	_wave += 1
	for i in range(SAPPERS):
		var at := Vector3((float(i) - 1.0) * 4.0, 0.6, 6.0)
		var man: EnemyBase = _director.spawn_tracked_enemy(at, SAPPER_DATA, "bench_sappers")
		if man == null:
			continue
		man.add_to_group("bench_sappers")
		var objective := Vector3(0.0, 0.0, -APPROACH_M)
		man.assault_objective = objective
		man.assault_driven = true          # satchel doctrine: push THROUGH contact
		var charge := SapperCharge.new()
		man.add_child(charge)
		charge.setup(objective)
		_sappers.append(man)
	print("[SAPPER-ROOM] wave %d: %d sappers up, objective %.0fm out, %d targets on the bus"
		% [_wave, _sappers.size(), APPROACH_M, _walls.size()])


## RESTART THE WHOLE TEST. [R] only stands up a new wave - the walls stay blown, so the second
## run tests nothing. This reloads the scene outright, which matters because the thing under
## test is a BLENDER ASSET: re-export fsb_main_v3.glb, hit F5, and the bench rebuilds its
## targets from the new file. Static rubble and the destroy queue are shared across all
## Destructibles, so they must be dropped BEFORE the reload or they leak into the next run.
func _full_restart() -> void:
	print("[SAPPER-ROOM] full restart - rebuilding targets from the GLB on disk")
	Destructible.reset_all()
	get_tree().reload_current_scene()


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(16, 12)
	_readout.add_theme_font_size_override("font_size", 15)
	layer.add_child(_readout)


func _process(delta: float) -> void:
	_t += delta
	if _readout == null:
		return
	var alive: int = 0
	var nearest: float = 9999.0
	for s in _sappers:
		if s == null or not is_instance_valid(s) or s.is_dead():
			continue
		alive += 1
		nearest = minf(nearest, s.global_position.distance_to(Vector3(0, 0, -APPROACH_M)))
	var standing: int = 0
	for w in _walls:
		if w != null and is_instance_valid(w):
			standing += 1
	_readout.text = ("SAPPER BENCH   wave %d\n"
		+ "sappers up: %d/%d      nearest to objective: %s\n"
		+ "targets standing: %d/%d\n"
		+ "[R] new wave   [K] kill wave   [T] blow one wall") % [
			_wave, alive, SAPPERS,
			"-" if nearest > 9000.0 else "%.1fm" % nearest,
			standing, WALL_SEGMENTS + WIRE_SEGMENTS]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_R:
			_sappers.clear()
			_spawn_wave()
			get_viewport().set_input_as_handled()
		KEY_F5:
			_full_restart()
			get_viewport().set_input_as_handled()
		KEY_K:
			for s in _sappers:
				if s != null and is_instance_valid(s) and not s.is_dead():
					s.take_damage(9999, Enums.DamageType.EXPLOSIVE, null)
			get_viewport().set_input_as_handled()
		KEY_T:
			# Reference blast: proves the TARGET side independently of the sapper side, so a
			# silent bench never leaves both halves suspect at once.
			for w in _walls:
				if w != null and is_instance_valid(w):
					CombatManager.apply_explosion_damage(w.global_position, 250, 70, 14.0, null)
					break
			get_viewport().set_input_as_handled()
