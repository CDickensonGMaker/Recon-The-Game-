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
##   4. is the HOLE WALKABLE afterwards  (NavBaker.breach_at re-bakes; ASSAULTERS walk it)
##
## Question 4 is the one that makes the other three matter. His ruling 2026-07-30: "the
## sappers are supposed to be able to blow up the barbwire and sandbags and bunkers etc...
## then we can have attacks from all over." Until the navmesh was rebuilt on destroy, a
## breach was scenery: the wall vanished and the men still walked to the gate, because
## nothing had told the mesh the wall was gone. The wall here is a SOLID LINE with no gate,
## so the only way to the far side is a hole the sappers made.
##
## Sterile by decree: no squad, no other enemies, no jungle, no weather. Anything that fails
## here is the sapper chain, not the world. (ADR-028 keeps the WORLD on one build path; a bench
## is not a world - it stands up three men and a wall.)
##
## Keys: [R] respawn the wave · [K] kill the standing sappers · [T] blow one wall for reference
##       [B] send the assault NOW (tests the lane whether or not a hole exists yet)
## Run: godot --path . res://scenes/levels/sapper_room.tscn

const FIELD: float = 120.0
const SAPPER_DATA: String = "res://data/enemies/vc_sapper.tres"
const SAPPERS: int = 3
## Where the sappers start, and where the wall stands. Far enough that the walk is the test.
const APPROACH_M: float = 45.0
## How many of each kind stand in the rank, keyed by FireSupportBench.TARGET_KINDS order.
const PER_KIND: Dictionary = {
	"sandbag_wall": 4, "sandbag_stack": 2, "bunker": 2, "bunker_mg": 1, "tower": 1, "wire": 4,
}
const KIND_SPAN_M: float = 7.0
## The wire stands short of the rest so the sappers have to cross it to reach the structures.
const WIRE_STANDOFF_M: float = 9.0

var player: CharacterBody3D = null
var _director: FieldDirector = null
var _readout: Label = null
var _sappers: Array[EnemyBase] = []
var _walls: Array[Destructible] = []
var _target_total: int = 0
var _wave: int = 0
## ---- THE BREACH PROOF ----
## Men who must cross the wall line. They are given an objective BEHIND it and no gate, so
## "arrived" can only mean they walked through a hole.
const ASSAULT_MEN: int = 4
const ASSAULT_DATA: String = "res://data/enemies/nva_regular.tres"
## Far side of the wall: they start short of it, the objective is past it.
const ASSAULT_START_Z: float = 14.0
const ASSAULT_GOAL_Z: float = -APPROACH_M - 14.0
## Inside this of the goal counts as through.
const THROUGH_M: float = 4.0
## Sent automatically once something has actually been destroyed, so the bench answers
## the whole chain in one sitting without a keypress.
const ASSAULT_AFTER_BREACH_S: float = 6.0

var _nav: NavBaker = null
## Everything the navmesh is allowed to treat as an obstacle. The bake walks a collider
## ROOT, and NAV_IGNORE_PREFIXES only skips vegetation and interior props - it has no idea
## what a person is. Handed the whole scene it baked the player and every soldier in as
## holes in the floor, and each new wave carved more: colliders 59 -> 133 -> 221 while
## walkable polys FELL 107 -> 90 -> 87, the exact opposite of what a breach should do.
var _targets_root: Node3D = null
var _assault: Array[EnemyBase] = []
var _assault_sent: bool = false
var _breach_clock: float = -1.0
var _through_peak: int = 0
var _t: float = 0.0


func _ready() -> void:
	_build_ground()
	_build_light()
	_spawn_player()
	_build_director()
	_build_targets()
	_build_nav()
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


## THE REAL FIREBASE ART, NOT A GREY BOX. The Summoner's note, 2026-07-29: "the models in this
## stress test were not the sandbag models of the firebase." A bench that proves a placeholder
## breaks has proved nothing about the thing that has to break.
##
## The lifting lives in FireSupportBench so this bench and the AI arena share ONE target
## vocabulary (ADR-023). Everything here is layout: one rank per kind, wire out front.
func _build_targets() -> void:
	_targets_root = Node3D.new()
	_targets_root.name = "Targets"
	add_child(_targets_root)
	var built: Array[String] = []
	var lane: int = 0
	for spec in FireSupportBench.TARGET_KINDS:
		var kind: String = str(spec["kind"])
		var want: int = int(PER_KIND.get(kind, 0))
		if want <= 0:
			continue
		var meshes: Array[Mesh] = FireSupportBench.lift_meshes(
			str(spec["prefix"]), want, str(spec["src"]))
		if meshes.is_empty():
			push_warning("[SAPPER-ROOM] no '%s' mesh in the source - that kind is untested"
				% str(spec["prefix"]))
			continue
		var is_wire: bool = kind == "wire"
		var z: float = -APPROACH_M + (WIRE_STANDOFF_M if is_wire else 0.0)
		# Wire spreads across the whole rank; structures take one lane each.
		var span: float = 4.0 if is_wire else 2.4
		var base_x: float = 0.0 if is_wire else (float(lane) - 2.0) * KIND_SPAN_M
		# The source may hold fewer distinct meshes than the rank wants (the wire is ONE
		# card), so cycle the pool rather than shrinking the test.
		for i in range(want):
			var x: float = base_x + (float(i) - float(want - 1) * 0.5) * span
			_walls.append(FireSupportBench.spawn_lifted(
				_targets_root, meshes[i % meshes.size()], Vector3(x, 0.0, z),
				kind, int(spec["hp"])))
		if not is_wire:
			lane += 1
		built.append("%d %s" % [want, kind])
	_target_total = _walls.size()
	print("[SAPPER-ROOM] targets on the bus: %s" % ", ".join(built))


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


## A navmesh over the bench, baked from the TARGETS' OWN COLLIDERS. That is what makes this
## a proof rather than a demo: it is the same `_add_colliders` path the firebase uses, so a
## hole here means a hole there. NavBaker skips DISABLED shapes and _do_destroy disables
## them, so the wall is solid until a satchel takes it down.
func _build_nav() -> void:
	_nav = NavBaker.new()
	_nav.name = "NavBaker"
	add_child(_nav)
	# _start_bake RETURNS EARLY on a null terrain, so the bench must hand it one. The shared
	# flat bench terrain (get_height_at = 0) is exactly that and already exists.
	var flat := FireSupportBench.BenchTerrain.new()
	add_child(flat)
	_nav.setup(flat)
	# Quiets "TerrainManager not set" on every single destruction: the blast still scars
	# nothing, because a bench has no heightmap, but the warning is not news.
	DamageSystem.set_terrain_manager(flat)
	# The TARGETS ONLY. The floor comes from the flat terrain sampler, so the ground body
	# is not needed here either - and a man is never an obstacle.
	_nav.queue_site_with_colliders(Vector3.ZERO, FIELD * 0.5, _targets_root)


## Men on the NEAR side, objective on the FAR side. THERE IS NO GATE IN THIS WALL, so every
## arrival is a man who walked through a hole the sappers made.
func _send_assault() -> void:
	if _assault_sent:
		return
	_assault_sent = true
	for i in range(ASSAULT_MEN):
		var at := Vector3((float(i) - 1.5) * 3.0, 0.6, ASSAULT_START_Z)
		var man: EnemyBase = _director.spawn_tracked_enemy(at, ASSAULT_DATA, "breach_assault")
		if man == null:
			continue
		man.assault_objective = Vector3(0.0, 0.0, ASSAULT_GOAL_Z)
		man.assault_driven = true
		_assault.append(man)
	print("[SAPPER-ROOM] assault away: %d men must cross the wall line" % _assault.size())


func _through_count() -> int:
	var n: int = 0
	for m in _assault:
		if m == null or not is_instance_valid(m) or m.is_dead():
			continue
		if absf(m.global_position.z - ASSAULT_GOAL_Z) <= THROUGH_M:
			n += 1
	return n


func _destroyed_count() -> int:
	var n: int = 0
	for w in _walls:
		if w != null and is_instance_valid(w) and w.is_destroyed():
			n += 1
	return n


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(16, 12)
	_readout.add_theme_font_size_override("font_size", 15)
	layer.add_child(_readout)


func _process(delta: float) -> void:
	_t += delta
	# Once something is actually down, send the assault: the bench answers the whole chain
	# in one sitting rather than waiting on a keypress nobody knew to press.
	if not _assault_sent and _destroyed_count() > 0:
		if _breach_clock < 0.0:
			_breach_clock = ASSAULT_AFTER_BREACH_S
		_breach_clock -= delta
		if _breach_clock <= 0.0:
			_send_assault()
	# PEAK, not live: a man who crosses and then walks on has still proved the hole, and
	# the point of the bench is that the crossing HAPPENED.
	_through_peak = maxi(_through_peak, _through_count())
	if _readout == null:
		return
	var alive: int = 0
	var nearest: float = 9999.0
	for s in _sappers:
		if s == null or not is_instance_valid(s) or s.is_dead():
			continue
		alive += 1
		nearest = minf(nearest, s.global_position.distance_to(Vector3(0, 0, -APPROACH_M)))
	# is_instance_valid is USELESS here: _do_destroy never frees the node, so a blown
	# structure passes it forever. is_destroyed() is the only honest answer.
	var standing: int = 0
	var down_by_kind: Dictionary = {}
	for w in _walls:
		if w == null or not is_instance_valid(w):
			continue
		if w.is_destroyed():
			down_by_kind[w.kind] = int(down_by_kind.get(w.kind, 0)) + 1
		else:
			standing += 1
	var killed: Array[String] = []
	for k in down_by_kind:
		killed.append("%s x%d" % [k, int(down_by_kind[k])])
	_readout.text = ("SAPPER BENCH   wave %d\n"
		+ "sappers up: %d/%d      nearest to objective: %s\n"
		+ "targets standing: %d/%d\n"
		+ "blown: %s\n"
		+ "BREACH: %s      THROUGH THE WALL: %d/%d\n"
		+ "[R] new wave  [K] kill wave  [T] blow one  [B] send assault  [F5] rebuild") % [
			_wave, alive, SAPPERS,
			"-" if nearest > 9000.0 else "%.1fm" % nearest,
			standing, _target_total,
			"nothing yet" if killed.is_empty() else ", ".join(killed),
			("OPEN - %d down" % _destroyed_count()) if _destroyed_count() > 0 else "CLOSED",
			_through_peak, _assault.size()]


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
		KEY_B:
			_send_assault()
			get_viewport().set_input_as_handled()
		KEY_T:
			# Reference blast: proves the TARGET side independently of the sapper side, so a
			# silent bench never leaves both halves suspect at once.
			for w in _walls:
				if w != null and is_instance_valid(w) and not w.is_destroyed():
					CombatManager.apply_explosion_damage(w.global_position, 250, 70, 14.0, null)
					break
			get_viewport().set_input_as_handled()
