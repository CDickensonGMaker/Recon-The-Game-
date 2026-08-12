extends Node3D

## Support Fire Range — the fire-support + destruction bench (ADR-031 PROPOSED), upgraded
## into a live-fire COVER LAB (Summoner ruling 2026-08-04). Player + RTO + 4 riflemen behind
## a low sandbag arc facing a breakable tree field, every fire-support tier on tap via the
## shared FireSupportBench rig (ADR-023). [9] sends a 5-man VC squad in from the far tree
## line; the proof is WATCHING the squad break to cover — each claimed cover point gets a
## marker sphere + nick label (bench-only witness, this scene script gates it).
## Keys: T open the net · 1 bombs / 2 napalm / 3 arty / 4 mortar / 5 spectre / 6 CBU /
## 7 willy-pete / 8 illum · 9 enemy assault · LMB send while a call is placed · RMB back out.
## Run: godot --path . res://scenes/levels/support_fire_range.tscn
## Probe: godot --headless --path . res://scenes/levels/support_fire_range.tscn ++ --cover-probe
## NOT the worst-case PERF rig — that is the AI arena (18v18 + this same bench). Measure the
## napalm+AC-47+firefight single-frame spike THERE, on the Intel-UHD floor, before P4/P5 ship.

const FIELD := 200.0

## The friendly line: low segments arced around the player spawn, facing the tree field.
## Collider must reach past the 1.3m cover-ray eye (ally_base.gd:1402) or it is scenery.
## Height is bounded by where rounds actually leave the player: the muzzle rides the
## viewmodel (weapon_holder._get_muzzle_position) well below the 1.7m eye, so cover
## the camera clears is not automatically cover the barrel clears.
const SANDBAG_BOX := Vector3(2.6, 1.1, 0.9)
const SANDBAG_LINE: Array[Dictionary] = [
	{"pos": Vector3(-7.0, 0.0, 1.2), "yaw": 0.5},
	{"pos": Vector3(-3.5, 0.0, -0.3), "yaw": 0.22},
	{"pos": Vector3(0.0, 0.0, -0.8), "yaw": 0.0},
	{"pos": Vector3(3.5, 0.0, -0.3), "yaw": -0.22},
	{"pos": Vector3(7.0, 0.0, 1.2), "yaw": -0.5},
	# One bag BEHIND the spawn: gives the RTO cord a hard-cover spot in the player's
	# shadow so the W-13 tuck-in ("behind me relative to the threat") is witnessable here.
	{"pos": Vector3(1.5, 0.0, 10.5), "yaw": 0.0},
]

## Riflemen courage is pinned LOW: with the 6m rally bonus (+0.25) the CombatGoals
## cover-vs-engage margin sits on a knife edge near nerve 0.55, and this lab exists
## to witness the cover trip, so every man stays clearly on the cover side of it.
const RIFLEMEN: Array[Dictionary] = [
	{"nick": "TEX", "courage": 0.20},
	{"nick": "PREACHER", "courage": 0.24},
	{"nick": "JUNIOR", "courage": 0.28},
	{"nick": "MOOSE", "courage": 0.32},
]

## Assault composition (his addendum 2026-08-04: "maybe the assault size is too small"):
## two 2-man fire-support bases hold the tree line, two 3-man maneuver elements bound in.
## Repeated [9] presses STACK waves.
const ENEMY_LINE_Z := -72.0
## Rosters are read by size, not by a hardcoded element count - add or remove men
## and the frontage redistributes.
const ASSAULT_MANEUVER: Array[String] = [
	"res://data/enemies/vc_rifleman.tres", "res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/nva_regular.tres", "res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/vc_rifleman.tres", "res://data/enemies/nva_regular.tres",
	"res://data/enemies/vc_rifleman.tres", "res://data/enemies/nva_regular.tres",
	"res://data/enemies/vc_rifleman.tres", "res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/nva_regular.tres", "res://data/enemies/vc_rifleman.tres",
]
const ASSAULT_BASE_OF_FIRE: Array[String] = [
	"res://data/enemies/nva_mg.tres", "res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_mg.tres", "res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_mg.tres", "res://data/enemies/nva_regular.tres",
	"res://data/enemies/nva_regular.tres", "res://data/enemies/nva_regular.tres",
]
## Total width the assault deploys across, both element and base-of-fire lines.
const ASSAULT_FRONTAGE_M: float = 96.0

var player: CharacterBody3D = null
var _director: FieldDirector = null
var _toast: Label = null
var _toast_t: float = 0.0
var _nav_region: NavigationRegion3D = null
var _squad: Array[AllyBase] = []            ## RTO + riflemen, marker-witnessed
var _cover_line: Array[Destructible] = []   ## the friendly sandbag arc
var _trees: Array[Vector3] = []             ## planted tree positions (cover-probe report)
var _tree_layer: TreeCoverLayer = null
var _tree_scatter: Array = []
var _probe_tree_chunk: int = 100            ## next spare chunk key for single probe trees
var _enemies: Array[EnemyBase] = []
var _assault_wave: int = 0
var _markers: Dictionary = {}               ## ally instance_id -> {node, mat, label}
## Squirrelliness instruments (his verdict 2026-08-04): goal/state switch counts,
## cover dwell seconds, RTO max distance from the player while enemies live.
var _metrics: Dictionary = {}               ## ally instance_id -> counters
var _fight_start_ms: int = -1
var _rto_max_d: float = 0.0
var _enemy_adv_under_fire_s: float = 0.0    ## man-seconds advancing while suppressed >0.3
var _ally_adv_under_fire_s: float = 0.0
var _enemy_min_line_d: float = 9999.0       ## closest any attacker got to the arc centre
var _lp: Dictionary = {}                    ## lethality-probe live counters


func _ready() -> void:
	_build_ground()
	_build_light()
	_build_target_field()
	_build_cover_line()
	_build_bunkers()
	_bake_navmesh()
	# The navigation server needs physics frames to register the baked region before
	# agents can resolve paths on it (same wait the AI arena takes).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_player_and_rto()
	if player != null:
		_director = FireSupportBench.wire(self, player, FIELD)
		_director.toast.connect(_on_toast)
	_spawn_ally_squad()
	_build_hint()
	if OS.get_cmdline_user_args().has("--cover-probe"):
		_run_cover_probe()
	elif OS.get_cmdline_user_args().has("--lethality-probe"):
		_run_lethality_probe()
	elif OS.get_cmdline_user_args().has("--strike-probe"):
		_run_strike_probe()
	elif OS.get_cmdline_user_args().has("--airburst-probe"):
		_run_airburst_probe()
	elif OS.get_cmdline_user_args().has("--corridor-probe"):
		_run_corridor_probe()


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("nav_source")
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
	mat.albedo_color = Color(0.28, 0.30, 0.18)
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = DAY_SUN_ENERGY
	sun.shadow_enabled = false   # ADR-026: no dynamic shadow on the bench
	add_child(sun)
	_sun = sun
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = DAY_AMBIENT
	env.environment = e
	add_child(env)
	_env = e


## Illum and any other light-emitting ordnance cannot be judged in daylight, so the
## bench carries its own night. Values match the world's night, not black.
const DAY_SUN_ENERGY: float = 1.1
const DAY_AMBIENT: float = 0.6
const NIGHT_SUN_ENERGY: float = 0.035
const NIGHT_AMBIENT: float = 0.02
const NIGHT_SUN_TINT: Color = Color(0.55, 0.62, 0.95)

var _sun: DirectionalLight3D = null
var _env: Environment = null
var _is_night: bool = false


func toggle_night() -> void:
	_is_night = not _is_night
	if _sun != null:
		_sun.light_energy = NIGHT_SUN_ENERGY if _is_night else DAY_SUN_ENERGY
		_sun.light_color = NIGHT_SUN_TINT if _is_night else Color(1.0, 1.0, 1.0)
	if _env != null:
		_env.ambient_light_energy = NIGHT_AMBIENT if _is_night else DAY_AMBIENT
		var sky_mat: ProceduralSkyMaterial = _env.sky.sky_material as ProceduralSkyMaterial
		if sky_mat != null:
			sky_mat.sky_top_color = Color(0.01, 0.02, 0.05) if _is_night else Color(0.385, 0.454, 0.55)
			sky_mat.sky_horizon_color = Color(0.04, 0.05, 0.09) if _is_night else Color(0.646, 0.656, 0.671)
			sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.03) if _is_night else Color(0.2, 0.169, 0.133)
			sky_mat.ground_horizon_color = Color(0.04, 0.05, 0.09) if _is_night else Color(0.646, 0.656, 0.671)


## Same rig as the AI arena: one region in "lab_navmesh" so NavRouter routes every
## agent on it, baked from the "nav_source" colliders (ground, sandbags, trunks).
func _bake_navmesh() -> void:
	var region := NavigationRegion3D.new()
	_nav_region = region
	region.add_to_group("lab_navmesh")
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	region.navigation_mesh = nm
	add_child(region)
	region.bake_navigation_mesh(false)
	print("[SUPPORT FIRE RANGE] navmesh baked: %d polys" % region.navigation_mesh.get_polygon_count())


func _spawn_player_and_rto() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	if scene == null:
		return
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.set("allow_photo_mode", false)
	player.global_position = Vector3(0.0, 1.0, 6.0)
	GameManager.player = player
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam != null:
		cam.current = true
	# The RTO: a commandable radioman carrying the PRC-25, within the 10m leash so the net
	# is always up. Same pattern as the arena — no bespoke entity.
	var rto: AllyBase = AllyBase.spawn_ally(self, player.global_position + Vector3(2.0, 0.0, 1.0))
	if rto == null:
		return
	rto.add_to_group("radioman")
	rto.member = {"nick": "SPARKS", "mos": "RTO"}
	rto.set_sprite("us_grunt_rto", "m16a1", "US")
	rto.set_order(AllyBase.OrderMode.FOLLOW)
	rto.courage = 0.30   # pinned like the riflemen: the W-13 tuck-in must be witnessable every run
	_squad.append(rto)
	var handset := RadioHandset.attach_to(rto)
	if handset != null:
		player.call("bind_radio_handset", handset)


## Four riflemen on the BenchSquad roster, same seam the RTO occupies, FOLLOW mode.
func _spawn_ally_squad() -> void:
	if player == null or _director == null or _director.squad_system == null:
		return
	for i in range(RIFLEMEN.size()):
		var spec: Dictionary = RIFLEMEN[i]
		var pos: Vector3 = player.global_position \
			+ Vector3(-3.0 + float(i) * 2.0, 0.0, 2.0 + float(i % 2) * 1.5)
		var ally: AllyBase = AllyBase.spawn_ally(self, pos)
		if ally == null:
			continue
		ally.member = {"nick": str(spec["nick"]), "mos": "RIFLEMAN"}
		ally.set_sprite("us_grunt_rifleman", SquadSystem.weapon_for_mos("RIFLEMAN"), "US")
		ally.set_order(AllyBase.OrderMode.FOLLOW)
		ally.courage = float(spec["courage"])
		ally.skill = 0.55
		_director.squad_system.members.append(ally)
		_squad.append(ally)
	print("[SUPPORT FIRE RANGE] ally squad up: %d men + SPARKS on the net" % RIFLEMEN.size())


## Trees the player breaks (S29 segmented system - registered, unbodied at rest), and
## fort segments a blast tears out — the destruction targets. Denser than the original
## 4x6 grid, plus near clumps so cover choices are non-trivial.
const BENCH_TREE_SPECIES := "broadleaf_a"


func _build_target_field() -> void:
	_tree_layer = TreeCoverLayer.new()
	_tree_layer.name = "TargetTreeField"
	add_child(_tree_layer)
	_tree_layer.load_species([BENCH_TREE_SPECIES])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260804   # one seed per operation (ADR-010)
	for row in range(6):
		var z: float = -20.0 - float(row) * 12.0
		for col in range(8):
			var x: float = -42.0 + float(col) * 12.0
			var jitter := Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
			_plant_tree(Vector3(x, 0.0, z) + jitter)
	for clump in [Vector3(-14.0, 0.0, -10.0), Vector3(11.0, 0.0, -12.0), Vector3(-2.0, 0.0, -15.0)]:
		for i in range(3):
			var off := Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
			_plant_tree(clump + off)
	_tree_layer.generate_for_chunk(Vector2i(0, 0), _tree_scatter)
	var wall := BoxMesh.new()
	wall.size = Vector3(3.0, 2.0, 1.0)
	FireSupportBench.spawn_fort(self, Vector3(-8.0, 0.0, -14.0), wall, Vector3(3.0, 2.0, 1.0), "sandbag", 110)
	FireSupportBench.spawn_fort(self, Vector3(8.0, 0.0, -14.0), wall, Vector3(3.0, 2.0, 1.0), "sandbag", 110)


func _plant_tree(pos: Vector3) -> void:
	_tree_scatter.append({"name": BENCH_TREE_SPECIES, "xf": Transform3D(Basis.IDENTITY, pos)})
	_trees.append(pos)


## One tree at an exact spot, mid-probe: its own chunk key so it never rebuilds the field.
func _plant_probe_tree(pos: Vector3) -> void:
	_probe_tree_chunk += 1
	_tree_layer.generate_for_chunk(Vector2i(_probe_tree_chunk, 0),
		[{"name": BENCH_TREE_SPECIES, "xf": Transform3D(Basis.IDENTITY, pos)}])
	_trees.append(pos)


## His two ORIGINAL hand-built fighting bunkers (exported from the firebase truth
## source 2026-08-04), flanking the line facing the tree field so he can walk in
## and shoot out of the slits. The -colonly twins import as real collision with
## the slits OPEN. Kit facing convention: Blender +Y = Godot -Z, so yaw 0 should
## point the front at the field - tell him to say so if a slit faces the wrong way.
const BUNKERS: Array = [
	["res://assets/world/building models/structures/firebase/kit/fb_bunker_mg.glb",
		Vector3(-14.0, 0.0, 5.0)],
	["res://assets/world/building models/structures/firebase/kit/fb_bunker_fighting.glb",
		Vector3(14.0, 0.0, 5.0)],
]


func _build_bunkers() -> void:
	for spec in BUNKERS:
		if not ResourceLoader.exists(str(spec[0])):
			print("[SUPPORT FIRE RANGE] bunker GLB not imported yet: %s" % str(spec[0]))
			continue
		var packed := load(str(spec[0])) as PackedScene
		if packed == null:
			continue
		var b := packed.instantiate() as Node3D
		add_child(b)
		b.global_position = spec[1] as Vector3
		b.add_to_group("nav_source")


## The friendly line. spawn_fort centres the mesh on the node, so the visual box is
## doubled in Y to match the 0..1.4 collider instead of sinking half underground.
func _build_cover_line() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SANDBAG_BOX.x, SANDBAG_BOX.y * 2.0, SANDBAG_BOX.z)
	for spec in SANDBAG_LINE:
		var fort: Destructible = FireSupportBench.spawn_fort(
			self, spec["pos"] as Vector3, mesh, SANDBAG_BOX, "sandbag", 110)
		fort.rotation.y = float(spec["yaw"])
		fort.add_to_group("nav_source")
		_cover_line.append(fort)


## The rounds board (his ruling 2026-08-04: "i need to be told what buttons to hit
## to switch to whatever rounds I have available"). Live: reads the director's
## actual stock every refresh, so an expended tier reads OUT instead of lying.
const _LEGEND_ROWS: Array = [
	["1", "SNAKE EYE BOMBS", "bombs"], ["2", "NAPALM", "napalm"],
	["3", "ARTILLERY", "arty"], ["4", "MORTARS", "mortar"],
	["5", "SPECTRE", "spectre"], ["6", "CBU CLUSTER", "cbu"],
	["7", "WILLY PETE", "wp"], ["8", "ILLUM", "illum"],
]
var _legend: Label = null
var _legend_t: float = 0.0


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_legend = Label.new()
	_legend.position = Vector2(16.0, 12.0)
	layer.add_child(_legend)
	_toast = Label.new()
	_toast.position = Vector2(16.0, 240.0)
	layer.add_child(_toast)
	_update_legend()


func _update_legend() -> void:
	if _legend == null or _director == null:
		return
	var lines: PackedStringArray = [
		"SUPPORT FIRE RANGE - press the number, it fires 60m ahead of your aim"]
	for row in _LEGEND_ROWS:
		var count: int = int(_director.fire_support.get(str(row[2]), 0))
		lines.append("[%s] %s %s" % [str(row[0]), str(row[1]),
			("x%d" % count) if count > 0 else "- OUT"])
	lines.append("[9] ENEMY ASSAULT   [N] day-night   LMB send / RMB back out   [T] net on-off")
	_legend.text = "\n".join(lines)


## BENCH SHORTCUT: number keys fire the mission DIRECTLY at a point 60m along the
## player's look direction — no net, no menu, no placement flow. The run axis is
## broadside to his look, and FieldDirector's overfly guard enforces it besides.
const _DIRECT_KEYS: Dictionary = {KEY_1: "bombs", KEY_2: "napalm", KEY_3: "arty",
	KEY_4: "mortar", KEY_5: "spectre", KEY_6: "cbu", KEY_7: "wp", KEY_8: "illum"}

func _unhandled_input(event: InputEvent) -> void:
	if _director == null or player == null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var keycode: Key = (event as InputEventKey).keycode
		if keycode == KEY_9:
			_launch_assault()
			return
		if keycode == KEY_N:
			toggle_night()
			return
		var kind: String = _DIRECT_KEYS.get(keycode, "")
		if kind == "":
			return
		var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
		var fwd: Vector3 = -cam.global_transform.basis.z if cam != null \
			else -player.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var target: Vector3 = player.global_position + fwd * 60.0
		target.y = 0.0
		# Run axis is BROADSIDE (his ruling 2026-08-04): aircraft cross the front,
		# never fly in over the player's head.
		var run := Vector3(-fwd.z, 0.0, fwd.x)
		_director.request_fire_support(kind, target, run)


## [9]. A 10-man platoon slice at the far tree line — the arena's enemy spawn pattern
## (alert tier + last-known point + explicit nav map binding). Maneuver elements bound
## on the arc via `assault_driven` (sapper_room/MarchingCell doctrine); the bases of
## fire hold at the trees and shoot.
func _launch_assault() -> void:
	if player == null:
		return
	_assault_wave += 1
	var spawned: int = 0
	var total: int = ASSAULT_MANEUVER.size() + ASSAULT_BASE_OF_FIRE.size()
	for i in range(total):
		var maneuver: bool = i < ASSAULT_MANEUVER.size()
		var path: String
		var pos: Vector3
		if maneuver:
			# 3-man elements spread evenly across the frontage.
			@warning_ignore("integer_division")
			var element: int = i / 3
			var slot: int = i % 3
			var elements: int = int(ceil(float(ASSAULT_MANEUVER.size()) / 3.0))
			var span: float = ASSAULT_FRONTAGE_M / maxf(1.0, float(elements))
			var ex: float = -ASSAULT_FRONTAGE_M * 0.5 + span * (float(element) + 0.5)
			pos = Vector3(ex + float(slot - 1) * 5.0, 0.6,
				ENEMY_LINE_Z + (2.0 if slot % 2 == 0 else -2.0))
			path = ASSAULT_MANEUVER[i]
		else:
			# 2-man bases of fire, on a wider frontage than the manoeuvre elements.
			var k: int = i - ASSAULT_MANEUVER.size()
			var bases: int = int(ceil(float(ASSAULT_BASE_OF_FIRE.size()) / 2.0))
			var wide: float = ASSAULT_FRONTAGE_M + 24.0
			var bspan: float = wide / maxf(1.0, float(bases))
			@warning_ignore("integer_division")
			var bpair: int = k / 2
			var bx: float = -wide * 0.5 + bspan * (float(bpair) + 0.5)
			pos = Vector3(bx + float(k % 2) * 4.0, 0.6, ENEMY_LINE_Z - 4.0)
			path = ASSAULT_BASE_OF_FIRE[k]
		var enemy := EnemyBase.spawn_enemy(self, pos, path)
		if enemy == null:
			continue
		enemy.squad_id = 900 + _assault_wave
		enemy.alert_tier = EnemyBase.AlertTier.ALERT
		enemy.last_known_target_pos = Vector3(0.0, 0.0, 0.0)   # the sandbag arc
		enemy.target_last_seen_time = 0.0
		if maneuver:
			@warning_ignore("integer_division")
			var obj_elem: int = i / 3
			var obj_elems: int = int(ceil(float(ASSAULT_MANEUVER.size()) / 3.0))
			var fan: float = (float(obj_elem) - (float(obj_elems) - 1.0) * 0.5) * 8.0
			enemy.assault_objective = Vector3(-3.0 + float(i % 3) * 3.0 + fan, 0.0, -8.0)
			# NOT assault_driven: that flag is the sapper's, and it makes a man ignore
			# contact all the way to the objective. MarchingCell sets it from
			# carries_charge; the bench must match or it tests a wave that never fights.
		enemy.rotation.y = atan2(player.global_position.x - pos.x, player.global_position.z - pos.z)
		var nav_agent := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if nav_agent != null and _nav_region != null:
			nav_agent.set_navigation_map(_nav_region.get_navigation_map())
		_enemies.append(enemy)
		spawned += 1
	# Arena hot-start seam (ai_stress_arena._hot_start_combat): seed the squad's contact
	# FRESH at the moment the assault steps off. Left to the perception ramp, contact_conf
	# crosses the scorer's 0.4 gate only after the <5s cover-first window has expired, so
	# the break-to-cover this lab exists to witness never runs.
	for a in _squad:
		if a == null or not is_instance_valid(a) or a.is_dead():
			continue
		var nearest: EnemyBase = _nearest_enemy_node(a.global_position)
		if nearest == null:
			continue
		a.target = nearest
		a.last_known_target_pos = nearest.global_position
		a.contact_conf = 1.0
		a.target_last_seen_time = 0.0
		# The opening volley: without incoming pressure the scorer's cover-vs-engage
		# margin is a per-run coin flip (threat_level 0). Half a bar of suppression is
		# below both the 0.6 seek band and the pin gate — it only weights the choice
		# the way real first contact does, and it decays in seconds.
		a.apply_suppression(0.5)
		a._change_state(Enums.AIState.COMBAT)
	if _fight_start_ms < 0:
		_fight_start_ms = Time.get_ticks_msec()
	_on_toast("ASSAULT: %d MEN AT THE FAR TREE LINE" % spawned)
	print("[SUPPORT FIRE RANGE] wave %d: %d attackers advancing on the line" % [_assault_wave, spawned])


## ---------- THE COVER WITNESS (bench-only) ----------
## "Supposed place" vs where the man went: a sphere at each claimed cover point,
## nick above it. Yellow = moving to the claim, green = holding it, cyan = the RTO
## (whose claim must sit near the player, behind him relative to the threat — W-13).

func _update_cover_markers() -> void:
	var live_ids: Dictionary = {}
	for a in _squad:
		if a == null or not is_instance_valid(a) or a.is_dead():
			continue
		var claimed: Vector3 = a.current_cover \
			if (a.has_cover or a._moving_to_cover) else Vector3.ZERO
		if claimed == Vector3.ZERO:
			continue
		var id: int = a.get_instance_id()
		live_ids[id] = true
		var nick: String = str(a.member.get("nick", "?"))
		if not _markers.has(id):
			_markers[id] = _make_marker(nick)
		var m: Dictionary = _markers[id]
		# Claim/hold transitions go to the console so a headless probe run carries the
		# whole story even when the firefight is over before a sample lands.
		if (m["claim"] as Vector3).distance_to(claimed) > 0.5:
			m["claim"] = claimed
			m["held_logged"] = false
			var extra: String = ""
			if str(a.member.get("mos", "")) == "RTO" and player != null:
				extra = "  d(claim->player)=%.1fm  shadow_dot=%.2f" % [
					claimed.distance_to(player.global_position),
					_shadow_dot(claimed, player.global_position, _nearest_enemy_pos(claimed))]
			print("[COVER] %s CLAIMS %s  d(claim->sandbag)=%.1fm  d(claim->tree)=%.1fm%s" % [
				nick, _fmt(claimed),
				_nearest_dist(claimed, _sandbag_positions()),
				_nearest_dist(claimed, _tree_positions()), extra])
		if a.has_cover and not bool(m["held_logged"]):
			m["held_logged"] = true
			print("[COVER] %s HOLDS %s  man at %s" % [nick, _fmt(claimed), _fmt(a.global_position)])
		(m["node"] as Node3D).global_position = claimed + Vector3.UP * 0.35
		var is_rto: bool = str(a.member.get("mos", "")) == "RTO"
		var color: Color
		if is_rto:
			color = Color(0.2, 0.9, 1.0)
		elif a.has_cover:
			color = Color(0.25, 1.0, 0.25)
		else:
			color = Color(1.0, 0.9, 0.2)
		(m["mat"] as StandardMaterial3D).albedo_color = color
	for id_v: Variant in _markers.keys():
		if not live_ids.has(id_v):
			var m: Dictionary = _markers[id_v]
			print("[COVER] %s RELEASES %s" % [(m["label"] as String), _fmt(m["claim"] as Vector3)])
			(m["node"] as Node3D).queue_free()
			_markers.erase(id_v)


func _update_metrics(delta: float) -> void:
	if _fight_start_ms < 0:
		return
	var now: int = Time.get_ticks_msec()
	for e in _enemies:
		if e == null or not is_instance_valid(e) or e.is_dead():
			continue
		_enemy_min_line_d = minf(_enemy_min_line_d, e.global_position.distance_to(Vector3.ZERO))
		if e.suppression_level > 0.3 and not e.assault_driven \
				and (e.current_state == Enums.AIState.ADVANCING
				or e.current_state == Enums.AIState.FLANKING):
			_enemy_adv_under_fire_s += delta
	for a in _squad:
		if a == null or not is_instance_valid(a) or a.is_dead():
			continue
		var id: int = a.get_instance_id()
		if not _metrics.has(id):
			_metrics[id] = {"nick": str(a.member.get("nick", "?")), "goal": a.current_goal,
				"state": a.current_state, "goal_sw": 0, "state_sw": 0,
				"hold_ms": -1, "dwells": [] as Array[float]}
		var m: Dictionary = _metrics[id]
		if a.current_goal != int(m["goal"]):
			m["goal"] = a.current_goal
			m["goal_sw"] = int(m["goal_sw"]) + 1
		if a.current_state != int(m["state"]):
			m["state"] = a.current_state
			m["state_sw"] = int(m["state_sw"]) + 1
		if a.has_cover and int(m["hold_ms"]) < 0:
			m["hold_ms"] = now
		elif not a.has_cover and int(m["hold_ms"]) >= 0:
			(m["dwells"] as Array[float]).append(float(now - int(m["hold_ms"])) / 1000.0)
			m["hold_ms"] = -1
		if a.suppression_level > 0.3 \
				and (a.current_state == Enums.AIState.ADVANCING
				or a.current_state == Enums.AIState.FLANKING):
			_ally_adv_under_fire_s += delta
		if str(a.member.get("mos", "")) == "RTO" and player != null \
				and _living_enemy_count() > 0:
			_rto_max_d = maxf(_rto_max_d, a.global_position.distance_to(player.global_position))


func _print_metrics_report() -> void:
	if _fight_start_ms < 0:
		return
	var minutes: float = float(Time.get_ticks_msec() - _fight_start_ms) / 60000.0
	var ally_dead: int = 0
	for a in _squad:
		if a == null or not is_instance_valid(a) or a.is_dead():
			ally_dead += 1
	print("[SQUIRRELLY-METER] fight window %.1fs  RTO max dist from player %.1fm" % [
		minutes * 60.0, _rto_max_d])
	print("[DOCTRINE] adv-under-fire man-s: enemy %.1f  ally %.1f  |  casualties: enemy %d/%d  ally %d/%d  |  closest attacker to arc %.1fm (%s)" % [
		_enemy_adv_under_fire_s, _ally_adv_under_fire_s,
		_enemies.size() - _living_enemy_count(), _enemies.size(),
		ally_dead, _squad.size(), _enemy_min_line_d,
		"REACHED THE LINE" if _enemy_min_line_d <= 10.0 else "held off"])
	for id_v: Variant in _metrics:
		var m: Dictionary = _metrics[id_v]
		var dwells: Array[float] = (m["dwells"] as Array[float]).duplicate()
		if int(m["hold_ms"]) >= 0:
			dwells.append(float(Time.get_ticks_msec() - int(m["hold_ms"])) / 1000.0)
		var dstr: String = "none"
		if not dwells.is_empty():
			var parts: PackedStringArray = []
			for d in dwells:
				parts.append("%.1fs" % d)
			dstr = ", ".join(parts)
		print("  %-9s goal_sw=%d (%.1f/min)  state_sw=%d (%.1f/min)  cover dwells: %s" % [
			str(m["nick"]), int(m["goal_sw"]), float(int(m["goal_sw"])) / maxf(0.017, minutes),
			int(m["state_sw"]), float(int(m["state_sw"])) / maxf(0.017, minutes), dstr])


func _make_marker(nick: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	root.add_child(mi)
	var lbl := Label3D.new()
	lbl.text = nick
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 0.55, 0.0)
	root.add_child(lbl)
	return {"node": root, "mat": mat, "label": nick, "claim": Vector3.ZERO, "held_logged": false}


## ---------- LETHALITY PROBE (--lethality-probe, headless) ----------
## The "star wars blaster" instrument: player stands STILL in the open, three VC
## riflemen with clear LOS at 40/50/60m. Window 1 = clean fire; window 2 = the same
## men held at 0.9 suppression, so cover's protection (degraded fire) is verified in
## the same sitting. Every hit is healed back so the sample never ends early.

const LP_WINDOW_S: float = 15.0
const LP_LANE_X: float = 60.0

func _run_lethality_probe() -> void:
	if player == null:
		return
	# The squad would fight the shooters and pollute both counters: the lane is
	# player-vs-rifles only.
	for a in _squad:
		if a != null and is_instance_valid(a):
			a.queue_free()
	_squad.clear()
	player.global_position = Vector3(LP_LANE_X, 1.0, 20.0)
	var hs: HealthSystem = player.get_node("HealthSystem") as HealthSystem
	var shooters: Array[EnemyBase] = []
	for i in range(3):
		var pos := Vector3(LP_LANE_X, 0.6, -20.0 - float(i) * 10.0)
		var e := EnemyBase.spawn_enemy(self, pos, "res://data/enemies/vc_rifleman.tres")
		if e == null:
			continue
		e.squad_id = -1
		e.target = player
		e.last_known_target_pos = player.global_position
		e.target_last_seen_time = 0.0
		e._set_tier(EnemyBase.AlertTier.COMBAT, false)
		e._change_state(Enums.AIState.COMBAT)
		e.rotation.y = atan2(player.global_position.x - pos.x, player.global_position.z - pos.z)
		shooters.append(e)
	_lp = {"hs": hs, "last_hp": hs.current_hp, "t0": Time.get_ticks_msec(),
		"shots": [0, 0], "hits": [0, 0], "first_hit_s": -1.0, "window": 0,
		"shooters": shooters}
	NoiseBus.noise_emitted.connect(_on_lp_noise)
	print("[LETHALITY] 3 shooters at 40/50/60m, player exposed + still, %ds windows" % int(LP_WINDOW_S))
	for tick in range(int(LP_WINDOW_S / 3.0)):
		await get_tree().create_timer(3.0).timeout
		for i in range(shooters.size()):
			var s: EnemyBase = shooters[i]
			if s == null or not is_instance_valid(s) or s.is_dead():
				continue
			print("  [LP t+%ds] #%d %s los=%s can_fire=%s burst=%d supp=%.2f goal=%s" % [
				(tick + 1) * 3, i, Enums.AIState.keys()[s.current_state],
				s.has_line_of_sight, s.can_fire, s.burst_count, s.suppression_level,
				Enums.AIGoal.keys()[s.current_goal]])
	_lp["window"] = 1
	print("[LETHALITY] window 2: shooters held at 0.9 suppression")
	await get_tree().create_timer(LP_WINDOW_S).timeout
	for w in range(2):
		var sh: int = (_lp["shots"] as Array)[w]
		var ht: int = (_lp["hits"] as Array)[w]
		print("[LETHALITY] W%d (%s): rounds %d  hits %d  hits/100 %.1f" % [
			w + 1, "clean" if w == 0 else "suppressed", sh, ht,
			(float(ht) / float(maxi(1, sh))) * 100.0])
	print("[LETHALITY] time-to-first-hit: %s" % (
		("%.1fs" % float(_lp["first_hit_s"])) if float(_lp["first_hit_s"]) >= 0.0 else "NEVER"))
	get_tree().quit()


func _on_lp_noise(type: int, _pos: Vector3, _radius: float, _team: int) -> void:
	if _lp.is_empty() or type != NoiseBus.NoiseType.GUNSHOT:
		return
	var w: int = int(_lp["window"])
	(_lp["shots"] as Array)[w] = int((_lp["shots"] as Array)[w]) + 1


func _update_lethality_poll() -> void:
	if _lp.is_empty():
		return
	var hs: HealthSystem = _lp["hs"] as HealthSystem
	if hs.current_hp < int(_lp["last_hp"]):
		var w: int = int(_lp["window"])
		(_lp["hits"] as Array)[w] = int((_lp["hits"] as Array)[w]) + 1
		if float(_lp["first_hit_s"]) < 0.0:
			_lp["first_hit_s"] = float(Time.get_ticks_msec() - int(_lp["t0"])) / 1000.0
		hs.current_hp = hs.max_hp   # heal back so the sample never ends early
		hs.is_bleeding = false
	_lp["last_hp"] = hs.current_hp
	if int(_lp["window"]) == 1:
		for s in (_lp["shooters"] as Array):
			var man := s as EnemyBase
			if man != null and is_instance_valid(man) and not man.is_dead() \
					and man.suppression_level < 0.85:
				man.apply_suppression(0.9)


## ---------- STRIKE PROBE (--strike-probe, headless) ----------
## Conviction 2026-08-04: "the artillery didnt seem to do anything." Every mission kind
## is fired at a frozen standing cluster and the damage ledger printed per man; rounds
## landed are counted via EXPLOSION noise events, so a dispatch that never reaches its
## impact callback reads as zero rounds, and rounds that land without hurting anyone
## read as rounds>0 hits=0 (the LOS/layer suspects).

const SP_OPEN := Vector3(60.0, 0.0, -40.0)     ## open lane, no trees within 15m
const SP_TREES := Vector3(0.0, 0.0, -44.0)     ## mid tree field
const SP_WAIT: Dictionary = {"arty": 24.0, "mortar": 18.0, "bombs": 16.0,
	"napalm": 14.0, "cbu": 14.0, "wp": 14.0, "spectre": 38.0}
var _sp_explosions: int = 0


var _sp_rto: AllyBase = null


func _run_strike_probe() -> void:
	# Keep the RTO (the net's radio check needs him alive within 10m), drop the rest.
	for a in _squad:
		if a == null or not is_instance_valid(a):
			continue
		if str(a.member.get("mos", "")) == "RTO":
			_sp_rto = a
			_sp_freeze(a)
		else:
			a.queue_free()
	_squad.clear()
	if _director != null and _director.squad_system != null:
		_director.squad_system.members.clear()
		if _sp_rto != null:
			_director.squad_system.members.append(_sp_rto)
	player.global_position = Vector3(-85.0, 1.0, 85.0)
	if _sp_rto != null:
		_sp_rto.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
	NoiseBus.noise_emitted.connect(_on_sp_noise)
	await get_tree().create_timer(1.0).timeout
	for kind: String in ["arty", "mortar", "bombs", "napalm", "cbu", "wp", "spectre"]:
		await _sp_strike_enemies(kind, SP_OPEN, "OPEN")
	await _sp_strike_enemies("arty", SP_TREES, "TREELINE")
	await _sp_ally_mitigation()
	await _sp_enemy_mortars()
	print("\n[STRIKE-PROBE] done")
	get_tree().quit()


var _sp_expl_pos: Array[Vector3] = []


func _on_sp_noise(type: int, pos: Vector3, _radius: float, _team: int) -> void:
	if type == NoiseBus.NoiseType.EXPLOSION:
		_sp_explosions += 1
		_sp_expl_pos.append(pos)


func _sp_freeze(n: Node) -> void:
	n.set_physics_process(false)
	n.set_process(false)


## One dispatch through the REAL net: zero the cooldown (25s green-RTO net time
## would gate a back-to-back probe), and answer the danger-close confirm if it pends.
func _sp_call(kind: String, at: Vector3) -> void:
	_director._cas_cooldown = 0.0
	_director.request_fire_support(kind, at, Vector3.RIGHT)
	if str(_director._pending_danger_close) == kind:
		await get_tree().create_timer(0.3).timeout
		_director._cas_cooldown = 0.0
		_director.request_fire_support(kind, at, Vector3.RIGHT)


func _sp_cluster_offsets(n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(n):
		var ang: float = TAU * float(i) / float(n)
		var r: float = 2.5 if i % 2 == 0 else 5.0
		out.append(Vector3(cos(ang) * r, 0.0, sin(ang) * r))
	return out


func _sp_strike_enemies(kind: String, at: Vector3, tag: String) -> void:
	var men: Array[EnemyBase] = []
	var hp0: Array[int] = []
	for off in _sp_cluster_offsets(6):
		var e := EnemyBase.spawn_enemy(self, at + off + Vector3(0.0, 0.6, 0.0),
			"res://data/enemies/vc_rifleman.tres")
		if e == null:
			continue
		_sp_freeze(e)
		men.append(e)
		hp0.append(e.current_hp)
	await get_tree().physics_frame
	_sp_explosions = 0
	await _sp_call(kind, at)
	await get_tree().create_timer(float(SP_WAIT.get(kind, 15.0))).timeout
	var killed: int = 0
	var hurt: int = 0
	var total_dmg: int = 0
	for i in range(men.size()):
		var e: EnemyBase = men[i]
		if e == null or not is_instance_valid(e):
			killed += 1
			continue
		var dmg: int = hp0[i] - e.current_hp
		var dead: bool = e.is_dead()
		if dead:
			killed += 1
		if dmg > 0:
			hurt += 1
			total_dmg += dmg
		print("  %-8s %-8s man %d  d(aim)=%4.1fm  hp %d->%d  dmg %3d  %s" % [
			kind, tag, i, e.global_position.distance_to(at), hp0[i], e.current_hp, dmg,
			"DEAD" if dead else ("hit" if dmg > 0 else "UNTOUCHED")])
	print("[STRIKE %s @ %s] rounds(explosions)=%d  in-cluster 6  hurt=%d  killed=%d  total_dmg=%d\n" % [
		kind.to_upper(), tag, _sp_explosions, hurt, killed, total_dmg])
	for e in men:
		if e != null and is_instance_valid(e):
			e.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## The ~0.4x indirect-fire mitigation must discount FRIENDLIES only.
func _sp_ally_mitigation() -> void:
	var at := Vector3(60.0, 0.0, 40.0)
	var men: Array[AllyBase] = []
	var hp0: Array[int] = []
	for off in _sp_cluster_offsets(4):
		var a: AllyBase = AllyBase.spawn_ally(self, at + off)
		if a == null:
			continue
		a.member = {"nick": "DUMMY", "mos": "RIFLEMAN"}
		_sp_freeze(a)
		men.append(a)
		hp0.append(a.current_hp)
	await get_tree().physics_frame
	_sp_explosions = 0
	await _sp_call("arty", at)
	await get_tree().create_timer(24.0).timeout
	var killed: int = 0
	var total_dmg: int = 0
	for i in range(men.size()):
		var a: AllyBase = men[i]
		if a == null or not is_instance_valid(a) or a.is_dead():
			killed += 1
			continue
		total_dmg += hp0[i] - a.current_hp
	print("[STRIKE ARTY @ ALLY BYSTANDERS] rounds=%d  4 men  killed=%d  total_dmg=%d (expect ~0.4x of enemy ledger)\n" % [
		_sp_explosions, killed, total_dmg])
	for a in men:
		if a != null and is_instance_valid(a):
			a.queue_free()
	await get_tree().process_frame


## Enemy side: the siege's mortar volley must hurt player + allies.
func _sp_enemy_mortars() -> void:
	var at := Vector3(0.0, 0.0, 6.0)
	player.global_position = at + Vector3(2.0, 1.0, 0.0)
	var hs: HealthSystem = player.get_node("HealthSystem") as HealthSystem
	var p_hp0: int = hs.current_hp
	var men: Array[AllyBase] = []
	var hp0: Array[int] = []
	for off in _sp_cluster_offsets(3):
		var a: AllyBase = AllyBase.spawn_ally(self, at + off)
		if a == null:
			continue
		a.member = {"nick": "DEF", "mos": "RIFLEMAN"}
		_sp_freeze(a)
		men.append(a)
		hp0.append(a.current_hp)
	var siege := SiegeDirector.new()
	siege.name = "ProbeSiege"
	add_child(siege)
	siege.setup(_director, at, at)
	siege.set_physics_process(false)
	await get_tree().physics_frame
	_sp_explosions = 0
	siege.fire_mortar_volley(at, 4.0)
	await get_tree().create_timer(16.0).timeout
	var total_dmg: int = 0
	var killed: int = 0
	for i in range(men.size()):
		var a: AllyBase = men[i]
		if a == null or not is_instance_valid(a) or a.is_dead():
			killed += 1
			continue
		total_dmg += hp0[i] - a.current_hp
	print("[ENEMY MORTARS @ DEFENDERS] rounds=%d  player hp %d->%d  3 allies: killed=%d total_dmg=%d\n" % [
		_sp_explosions, p_hp0, hs.current_hp, killed, total_dmg])


## ---------- CORRIDOR PROBE (--corridor-probe, headless) ----------
## Threat-corridor decree 2026-08-04: batched live-jungle trees get REAL trunk
## colliders promoted inside a strike's footprint for its duration, then parked.
## Verifies: promote counts on dispatch, a contact burst on a PROMOTED trunk,
## leak-proof demotion after expiry, and no growth across 10 consecutive strikes.

const CP_GROVE := Vector3(60.0, 0.0, -40.0)

func _run_corridor_probe() -> void:
	for a in _squad:
		if a == null or not is_instance_valid(a):
			continue
		if str(a.member.get("mos", "")) == "RTO":
			_sp_rto = a
			_sp_freeze(a)
		else:
			a.queue_free()
	_squad.clear()
	if _director != null and _director.squad_system != null:
		_director.squad_system.members.clear()
		if _sp_rto != null:
			_director.squad_system.members.append(_sp_rto)
	player.global_position = Vector3(-85.0, 1.0, 85.0)
	if _sp_rto != null:
		_sp_rto.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
	NoiseBus.noise_emitted.connect(_on_sp_noise)

	var layer := TreeCoverLayer.new()
	layer.name = "ProbeTreeCover"
	add_child(layer)
	layer.load_species(["broadleaf_a"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260804
	var scatter: Array = []
	# One KNOWN trunk the contact shell is aimed at, then a grove around it.
	var known: Vector3 = CP_GROVE
	scatter.append({"name": "broadleaf_a", "xf": Transform3D(Basis.IDENTITY, known)})
	for i in range(39):
		var off := Vector3(rng.randf_range(-18.0, 18.0), 0.0, rng.randf_range(-18.0, 18.0))
		scatter.append({"name": "broadleaf_a", "xf": Transform3D(Basis.IDENTITY, CP_GROVE + off)})
	layer.generate_for_chunk(Vector2i(0, 0), scatter)
	await get_tree().physics_frame
	print("[CORRIDOR] baseline colliders=%d (player 150m out - expect 0)" % layer.collider_count())

	await _sp_call("arty", CP_GROVE)
	await get_tree().create_timer(0.5).timeout
	print("[CORRIDOR] after arty dispatch: colliders=%d (expect ~40 promoted)" % layer.collider_count())

	# Contact burst on a PROMOTED trunk: shell aimed 2m past the known trunk along
	# the controlled azimuth crosses its 3m collider at ~2.3m up.
	_sp_explosions = 0
	_sp_expl_pos.clear()
	_director._fire_shell(FieldDirector.ARTY_SHELL, known + SP_AZ * 2.0,
		_director._arty_impact, known - SP_AZ * 300.0)
	await get_tree().create_timer(7.0).timeout
	var burst_y: float = -99.0
	for p in _sp_expl_pos:
		burst_y = maxf(burst_y, p.y)
	print("[CORRIDOR] contact shell burst_y=%.1fm (expect >0.5: burst ON the promoted trunk)" % burst_y)

	await get_tree().create_timer(22.0).timeout
	print("[CORRIDOR] after expiry: colliders=%d (expect 0 - demotion leak-proof)" % layer.collider_count())

	_director.fire_support["arty"] = 99   # the probe outspends the 9-mission stock
	for i in range(10):
		await _sp_call("arty", CP_GROVE)
		await get_tree().create_timer(0.6).timeout
		print("[CORRIDOR] strike %d: colliders=%d  zones=%d" % [
			i + 1, layer.collider_count(), layer._zones.size()])
	print("[CORRIDOR] during 10 stacked strikes: colliders=%d  zones=%d (cap %d)  pool=%d (cap %d)" % [
		layer.collider_count(), layer._zones.size(), TreeCoverLayer.ZONE_MAX,
		layer._pool.size(), TreeCoverLayer.POOL_MAX])
	await get_tree().create_timer(26.0).timeout
	print("[CORRIDOR] after all expiries: colliders=%d  zones=%d  pool=%d (must be 0 / 0 / stable)" % [
		layer.collider_count(), layer._zones.size(), layer._pool.size()])
	print("\n[CORRIDOR-PROBE] done")
	get_tree().quit()


## ---------- AIRBURST PROBE (--airburst-probe, headless) ----------
## Contact-fuse decree 2026-08-04: "if a bomb hits the tree above you thats gonna blow
## up and force that pressure and blast downward." Three single-shell cases:
##   A: shell into a tree crown, man beside the trunk -> AIRBURST kills him
##   B: ground burst, man behind a SANDBAG_BOX.y sandbag -> SHIELDED (all 8 LOS points blocked)
##   C: crown burst above the SAME wall geometry -> the elevated burst sees over it
## The shell is aimed 4m PAST the trunk along the incoming azimuth so the ~48 deg
## descent line crosses the trunk at ~4.5m (aimed at the base it lands beside it).

func _run_airburst_probe() -> void:
	for a in _squad:
		if a != null and is_instance_valid(a):
			a.queue_free()
	_squad.clear()
	player.global_position = Vector3(-85.0, 1.0, 85.0)
	NoiseBus.noise_emitted.connect(_on_sp_noise)
	await get_tree().create_timer(1.0).timeout

	var tree_a := Vector3(70.0, 0.0, -30.0)
	_plant_probe_tree(tree_a)
	var man_a := _sp_one_man(tree_a + Vector3(0.0, 0.0, 1.5))
	await _sp_single_shell(_sp_crown_aim(tree_a))
	_sp_airburst_report("A crown burst, man beside trunk (expect DEAD)", man_a)

	var bp := Vector3(80.0, 0.0, 20.0)
	_sp_wall(bp + Vector3(0.0, 0.0, 6.0))
	var man_b := _sp_one_man(bp + Vector3(0.0, 0.0, 7.6))
	await _sp_single_shell(bp)
	_sp_airburst_report("B ground burst, man behind sandbag (expect UNTOUCHED)", man_b)

	var tree_c := Vector3(90.0, 0.0, 20.0)
	_plant_probe_tree(tree_c)
	_sp_wall(tree_c + Vector3(0.0, 0.0, 6.0))
	var man_c := _sp_one_man(tree_c + Vector3(0.0, 0.0, 7.6))
	await _sp_single_shell(_sp_crown_aim(tree_c))
	_sp_airburst_report("C crown burst over the wall (expect HIT past cover)", man_c)

	print("\n[AIRBURST-PROBE] done")
	get_tree().quit()


## The probe owns the gun azimuth (passed as `source`), so the descent plane is
## guaranteed to contain the trunk instead of riding the bench's fallback bearing.
const SP_AZ := Vector3(0.6, 0.0, -0.8)


func _sp_crown_aim(trunk: Vector3) -> Vector3:
	return trunk + SP_AZ * 4.0


func _sp_one_man(at: Vector3) -> EnemyBase:
	var e := EnemyBase.spawn_enemy(self, at + Vector3(0.0, 0.6, 0.0),
		"res://data/enemies/vc_rifleman.tres")
	if e != null:
		_sp_freeze(e)
	return e


func _sp_wall(at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SANDBAG_BOX.x, SANDBAG_BOX.y * 2.0, SANDBAG_BOX.z)
	var fort: Destructible = FireSupportBench.spawn_fort(self, at, mesh, SANDBAG_BOX, "sandbag", 110)
	fort.add_to_group("nav_source")


func _sp_single_shell(aim: Vector3) -> void:
	await get_tree().physics_frame
	_sp_explosions = 0
	_sp_expl_pos.clear()
	_director._fire_shell(FieldDirector.ARTY_SHELL, aim, _director._arty_impact,
		aim - SP_AZ * 300.0)
	await get_tree().create_timer(7.0).timeout


func _sp_airburst_report(tag: String, man: EnemyBase) -> void:
	var burst_y: float = -99.0
	for p in _sp_expl_pos:
		burst_y = maxf(burst_y, p.y)
	var state: String = "MISSING"
	if man != null and is_instance_valid(man):
		state = "DEAD" if man.is_dead() else ("hp=%d/%d" % [man.current_hp, man.max_hp])
	print("[AIRBURST %s] bursts=%d  burst_y=%.1fm  man: %s" % [tag, _sp_explosions, burst_y, state])


## ---------- COVER PROBE (--cover-probe, headless) ----------
## Drives the [9] path with no hands and prints each man's claim + distance to the
## nearest sandbag/tree — measured proof the squad falls into places (ADR-015).

func _run_cover_probe() -> void:
	await get_tree().create_timer(1.0).timeout
	_launch_assault()
	# The fight can be over inside 10s, so sample DURING it — the [COVER] event log
	# above carries the claim story regardless of timing.
	await get_tree().create_timer(3.0).timeout
	_print_cover_report("T+3s")
	await get_tree().create_timer(7.0).timeout
	_print_cover_report("T+10s")
	await get_tree().create_timer(10.0).timeout
	_print_cover_report("T+20s")
	await get_tree().create_timer(10.0).timeout
	_print_cover_report("T+30s")
	_print_metrics_report()
	get_tree().quit()


func _print_cover_report(tag: String) -> void:
	print("\n[COVER-PROBE %s] enemies alive: %d" % [tag, _living_enemy_count()])
	for a in _squad:
		if a == null or not is_instance_valid(a):
			continue
		var nick: String = str(a.member.get("nick", "?"))
		var mos: String = str(a.member.get("mos", "?"))
		if a.is_dead():
			print("  %-9s %-9s DEAD" % [nick, mos])
			continue
		var claimed: Vector3 = a.current_cover \
			if (a.has_cover or a._moving_to_cover) else Vector3.ZERO
		var state: String = Enums.AIState.keys()[a.current_state]
		if claimed == Vector3.ZERO:
			print("  %-9s %-9s NO CLAIM   state=%s at %s  cover_fails=%d supp=%.2f" % [nick, mos,
				state, _fmt(a.global_position), a._cover_fail_count, a.suppression_level])
			continue
		var held: String = "HELD" if a.has_cover else "MOVING"
		var line: String = "  %-9s %-9s %s %s  man at %s  d(man->claim)=%.1fm  d(claim->sandbag)=%.1fm  d(claim->tree)=%.1fm" \
			% [nick, mos, held, _fmt(claimed), _fmt(a.global_position),
			a.global_position.distance_to(claimed),
			_nearest_dist(claimed, _sandbag_positions()),
			_nearest_dist(claimed, _tree_positions())]
		if mos == "RTO" and player != null:
			var threat: Vector3 = _nearest_enemy_pos(claimed)
			line += "  d(claim->player)=%.1fm  shadow_dot=%.2f" \
				% [claimed.distance_to(player.global_position),
				_shadow_dot(claimed, player.global_position, threat)]
		print(line)


func _fmt(v: Vector3) -> String:
	return "(%.1f, %.1f)" % [v.x, v.z]


func _sandbag_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in _cover_line:
		if f != null and is_instance_valid(f):
			out.append(f.global_position)
	return out


func _tree_positions() -> Array[Vector3]:
	return _trees


func _nearest_dist(from: Vector3, points: Array[Vector3]) -> float:
	var best: float = 9999.0
	for p in points:
		var flat := Vector3(p.x, from.y, p.z)
		best = minf(best, from.distance_to(flat))
	return best


func _living_enemy_count() -> int:
	var n: int = 0
	for e in _enemies:
		if e != null and is_instance_valid(e) and not e.is_dead():
			n += 1
	return n


func _nearest_enemy_node(from: Vector3) -> EnemyBase:
	var best: EnemyBase = null
	var best_d: float = 1e9
	for e in _enemies:
		if e == null or not is_instance_valid(e) or e.is_dead():
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _nearest_enemy_pos(from: Vector3) -> Vector3:
	var n: EnemyBase = _nearest_enemy_node(from)
	return n.global_position if n != null else Vector3(0.0, 0.0, ENEMY_LINE_Z)


## Flat-plane dot of claim->player vs claim->threat: 1.0 = the player sits exactly
## between the RTO's cover and the threat (the W-13 doctrine, probe_rto_cover.gd).
func _shadow_dot(claim: Vector3, player_pos: Vector3, threat_pos: Vector3) -> float:
	var to_player: Vector3 = player_pos - claim
	var to_threat: Vector3 = threat_pos - claim
	to_player.y = 0.0
	to_threat.y = 0.0
	if to_player.length() < 0.05 or to_threat.length() < 0.05:
		return 0.0
	return to_player.normalized().dot(to_threat.normalized())


func _on_toast(text: String) -> void:
	if _toast != null:
		_toast.text = text
		_toast_t = 4.0


func _process(delta: float) -> void:
	_update_cover_markers()
	_update_metrics(delta)
	_update_lethality_poll()
	_legend_t -= delta
	if _legend_t <= 0.0:
		_legend_t = 0.5
		_update_legend()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast != null:
			_toast.text = ""
