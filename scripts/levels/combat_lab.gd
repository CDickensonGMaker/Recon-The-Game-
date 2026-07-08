## combat_lab.gd - AI & gunplay fine-tuning sandbox.
##
## A 40x40m white gridded box. Cover boxes at four heights, foliage with NO
## collision (matching the real game: bushes are concealment, never cover), and
## live telemetry on every enemy's goal / state / alert tier / target / accuracy.
##
## This is where we learn how the NPCs actually behave, not where we ship.
## Nothing here loads terrain, vegetation streaming, or a mission - so a
## think-loop change is a 2-second iteration instead of a 30-second world build.
##
## KEYS
##   1  spawn 1 VC rifleman        3  spawn 1 ally        R  reset everything
##   2  spawn 3 VC riflemen        4  spawn 1 NVA regular K  kill all enemies
##   F  freeze/unfreeze enemy AI   G  god mode            H  toggle HUD
##   [  slow-mo   ]  normal speed
##
## Run: godot --path . res://scenes/levels/combat_lab.tscn
class_name CombatLab
extends Node3D

const ARENA: float = 40.0
const WALL_H: float = 6.0
const LAB_SEED: int = 20260708

const VC := "res://data/enemies/vc_rifleman.tres"
const NVA := "res://data/enemies/nva_regular.tres"

const BILLBOARD_DIR := "res://terrain/textures/billboards/"
const BUSHES: Array[String] = ["bush1", "bush2", "bush3", "bush4", "bush5", "bush6", "bush7", "bush8", "bush9"]
const TREES: Array[String] = ["tree1", "tree2", "tree3", "tree4", "tree5", "tree6"]

var player: CharacterBody3D = null  ## player.gd has no class_name; it extends CharacterBody3D
var _hud: Label = null
var _help: Label = null
var _rng := RandomNumberGenerator.new()
var _frozen: bool = false
var _god: bool = false
var _foliage_root: Node3D = null
var _props_root: Node3D = null

# --- telemetry -------------------------------------------------------------
var _shots: int = 0
var _hits: int = 0
var _kills: int = 0
var _damage_taken: int = 0
var _first_shot_ms: int = -1
var _ttk: Array[float] = []          ## seconds from first shot of an engagement to each kill
var _hit_ranges: Array[float] = []   ## metres at which we connected


func _ready() -> void:
	_rng.seed = LAB_SEED
	_build_arena()
	_build_cover()
	_build_foliage()
	_build_lighting()
	_spawn_player()
	_build_hud()
	print("[COMBAT LAB] ready. 1/2 enemies, 3 ally, 4 NVA, R reset, F freeze AI, G god, H hud")


# ------------------------------------------------------------------ geometry
func _mat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 if collide else 0
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	body.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
	_props_root.add_child(body)
	body.global_position = pos
	return body


func _build_arena() -> void:
	_props_root = Node3D.new()
	_props_root.name = "Props"
	add_child(_props_root)

	# Floor: gridded, unshaded.
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA, ARENA)
	floor_mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://terrain/shaders/lab_grid.gdshader")
	floor_mi.material_override = sm
	add_child(floor_mi)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var fcs := CollisionShape3D.new()
	var fshape := BoxShape3D.new()
	fshape.size = Vector3(ARENA, 0.4, ARENA)
	fcs.shape = fshape
	fcs.position = Vector3(0, -0.2, 0)
	floor_body.add_child(fcs)
	add_child(floor_body)

	# Four walls, so nothing wanders off and LOS has a hard boundary.
	var h := ARENA * 0.5
	var wall := Color(0.97, 0.97, 0.97)
	_box(Vector3(ARENA, WALL_H, 0.4), Vector3(0, WALL_H * 0.5, -h), wall)
	_box(Vector3(ARENA, WALL_H, 0.4), Vector3(0, WALL_H * 0.5, h), wall)
	_box(Vector3(0.4, WALL_H, ARENA), Vector3(-h, WALL_H * 0.5, 0), wall)
	_box(Vector3(0.4, WALL_H, ARENA), Vector3(h, WALL_H * 0.5, 0), wall)


## Cover at four deliberate heights. These map onto the stance system:
##   0.5m - prone only        1.0m - crouch cover      1.5m - standing chest
##   2.5m - full LOS blocker (the only one that truly breaks a sight line)
## Watching which the AI picks (seek_cover / cover claims) is half the point.
func _build_cover() -> void:
	var heights: Array[float] = [0.5, 1.0, 1.5, 2.5]
	var tints: Array[Color] = [
		Color(0.80, 0.84, 0.88), Color(0.72, 0.78, 0.84),
		Color(0.64, 0.72, 0.80), Color(0.52, 0.60, 0.70),
	]
	# A scattered field...
	for i in range(26):
		var idx: int = _rng.randi() % heights.size()
		var hgt: float = heights[idx]
		var w: float = _rng.randf_range(0.8, 2.4)
		var d: float = _rng.randf_range(0.8, 2.4)
		var pos := Vector3(_rng.randf_range(-17.0, 17.0), hgt * 0.5, _rng.randf_range(-17.0, 17.0))
		if Vector2(pos.x, pos.z).length() < 4.0:
			continue  # keep the middle open
		var b := _box(Vector3(w, hgt, d), pos, tints[idx])
		b.rotation.y = _rng.randf_range(0.0, TAU)

	# ...plus two hard blocks and a raised platform for elevation duels.
	_box(Vector3(6.0, 3.0, 1.0), Vector3(-9.0, 1.5, 2.0), tints[3])
	_box(Vector3(1.0, 3.0, 6.0), Vector3(8.0, 1.5, -6.0), tints[3])
	_box(Vector3(7.0, 1.2, 7.0), Vector3(13.0, 0.6, 13.0), Color(0.58, 0.66, 0.74))
	# Ramp up to the platform (a box tilted 20 degrees).
	var ramp := _box(Vector3(3.0, 0.3, 6.0), Vector3(8.0, 0.75, 13.0), Color(0.66, 0.70, 0.74))
	ramp.rotation.z = 0.0
	ramp.rotation.x = deg_to_rad(-11.0)


## Foliage is VISUAL ONLY - collision_layer 0. In the shipped game trees and
## bushes have zero collision (they are billboards); if the lab gave them
## colliders, every gunplay conclusion drawn here would be wrong.
func _build_foliage() -> void:
	_foliage_root = Node3D.new()
	_foliage_root.name = "Foliage"
	add_child(_foliage_root)

	for i in range(34):
		var is_tree: bool = _rng.randf() < 0.35
		var names: Array[String] = TREES if is_tree else BUSHES
		var tex_name: String = names[_rng.randi() % names.size()]
		var tex: Texture2D = load(BILLBOARD_DIR + tex_name + "_billboard.png")
		if tex == null:
			continue
		var pos := Vector3(_rng.randf_range(-18.0, 18.0), 0.0, _rng.randf_range(-18.0, 18.0))
		if Vector2(pos.x, pos.z).length() < 5.0:
			continue
		var scale_v: float = _rng.randf_range(2.2, 4.5) if is_tree else _rng.randf_range(0.6, 1.9)
		_foliage_root.add_child(_cross_billboard(tex, pos, scale_v, _rng.randf_range(0.0, TAU)))


## Two intersecting quads - the same trick BillboardVegetation uses in the
## 80-800m band, so foliage reads the same here as it does in the AO.
func _cross_billboard(tex: Texture2D, pos: Vector3, size: float, yaw: float) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for i in range(2):
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		mi.mesh = q
		mi.material_override = mat
		mi.position.y = size * 0.5
		mi.rotation.y = float(i) * PI * 0.5
		root.add_child(mi)
	root.position = pos
	root.rotation.y = yaw
	return root


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false  # perf-first, and shadows muddy silhouette reading
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.88, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.82)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)


# -------------------------------------------------------------------- actors
func _spawn_player() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	player = scene.instantiate() as CharacterBody3D
	add_child(player)
	player.global_position = Vector3(0, 1.0, 16.0)
	GameManager.player = player
	# weapon_fired and target_hit are DEAD SIGNALS in the shipped game (emitted,
	# never connected). The lab is their first consumer.
	var wh: WeaponHolder = player.get("weapon_holder")
	if wh != null:
		wh.weapon_fired.connect(_on_shot)
		wh.target_hit.connect(_on_hit)


func spawn_enemy(data_path: String = VC, pos: Vector3 = Vector3.INF) -> EnemyBase:
	if pos == Vector3.INF:
		pos = Vector3(_rng.randf_range(-16.0, 16.0), 1.0, _rng.randf_range(-18.0, -10.0))
	var e := EnemyBase.spawn_enemy(self, pos, data_path)
	e.died.connect(_on_enemy_died)
	if _frozen:
		e.set_physics_process(false)
	return e


func spawn_ally() -> void:
	var pos := Vector3(_rng.randf_range(-3.0, 3.0), 1.0, 14.0)
	var a := AllyBase.spawn_ally(self, pos)
	if a != null:
		a.set_order(AllyBase.OrderMode.FOLLOW)


func _kill_all_enemies() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as EnemyBase
		if e != null and not e.is_dead():
			e.take_damage(9999, Enums.DamageType.PHYSICAL, null)


func _reset() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		(n as Node).queue_free()
	for n in get_tree().get_nodes_in_group("allies"):
		(n as Node).queue_free()
	_shots = 0
	_hits = 0
	_kills = 0
	_damage_taken = 0
	_first_shot_ms = -1
	_ttk.clear()
	_hit_ranges.clear()
	if player != null:
		player.global_position = Vector3(0, 1.0, 16.0)
	print("[COMBAT LAB] reset")


# ----------------------------------------------------------------- telemetry
func _on_shot() -> void:
	_shots += 1
	if _first_shot_ms < 0:
		_first_shot_ms = Time.get_ticks_msec()


func _on_hit(killed: bool) -> void:
	_hits += 1
	if player != null:
		var nearest: float = _nearest_enemy_distance()
		if nearest > 0.0:
			_hit_ranges.append(nearest)
	if killed:
		_kills += 1
		if _first_shot_ms >= 0:
			_ttk.append(float(Time.get_ticks_msec() - _first_shot_ms) / 1000.0)
			_first_shot_ms = -1  # next engagement re-arms on the next shot


func _on_enemy_died(_e: EnemyBase) -> void:
	pass


func _nearest_enemy_distance() -> float:
	var best: float = -1.0
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as EnemyBase
		if e == null or e.is_dead():
			continue
		var d: float = player.global_position.distance_to(e.global_position)
		if best < 0.0 or d < best:
			best = d
	return best


func _avg(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var t: float = 0.0
	for v in a:
		t += v
	return t / float(a.size())


# ----------------------------------------------------------------------- HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hud = Label.new()
	_hud.position = Vector2(14, 12)
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.08, 0.10, 0.12))
	_hud.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud)

	_help = Label.new()
	_help.position = Vector2(14, 12)
	_help.add_theme_font_size_override("font_size", 12)
	_help.add_theme_color_override("font_color", Color(0.20, 0.22, 0.26))
	_help.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	_help.add_theme_constant_override("outline_size", 3)
	_help.text = ""
	layer.add_child(_help)


func _goal_name(g: int) -> String:
	return str(Enums.AIGoal.keys()[g]) if g >= 0 and g < Enums.AIGoal.keys().size() else "?"


func _state_name(s: int) -> String:
	return str(Enums.AIState.keys()[s]) if s >= 0 and s < Enums.AIState.keys().size() else "?"


func _tier_name(t: int) -> String:
	return ["RELAXED", "SUSPICIOUS", "ALERT", "COMBAT"][t] if t >= 0 and t < 4 else "?"


func _update_hud() -> void:
	if _hud == null or not _hud.visible:
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var alive: int = 0
	for n in enemies:
		var e := n as EnemyBase
		if e != null and not e.is_dead():
			alive += 1

	var hit_pct: float = (100.0 * float(_hits) / float(_shots)) if _shots > 0 else 0.0
	var lines: Array[String] = []
	lines.append("COMBAT LAB   fps %d   %s%s%s" % [
		Engine.get_frames_per_second(),
		"[AI FROZEN] " if _frozen else "",
		"[GOD] " if _god else "",
		"[SLOWMO %.2fx] " % Engine.time_scale if not is_equal_approx(Engine.time_scale, 1.0) else "",
	])
	lines.append("shots %d  hits %d  (%.0f%%)  kills %d  dmg taken %d" % [_shots, _hits, hit_pct, _kills, _damage_taken])
	lines.append("avg TTK %.2fs   avg hit range %.1fm   enemies alive %d/%d" % [
		_avg(_ttk), _avg(_hit_ranges), alive, enemies.size()])
	lines.append("")
	lines.append("%-4s %-10s %-14s %-11s %-7s %-6s %-6s %-5s %s" % [
		"HP", "TIER", "GOAL", "STATE", "AWARE", "SUPPR", "ACCMOD", "DIST", "TARGET"])

	for n in enemies:
		var e := n as EnemyBase
		if e == null:
			continue
		var dist: float = player.global_position.distance_to(e.global_position) if player != null else 0.0
		var tgt: String = "-" if e.target == null else str(e.target.name).left(12)
		lines.append("%-4d %-10s %-14s %-11s %-7.2f %-6.2f %-6.2f %-5.1f %s" % [
			e.current_hp, _tier_name(e.alert_tier), _goal_name(e.current_goal),
			_state_name(e.current_state), e.awareness, e.suppression_level,
			e.accuracy_modifier, dist, tgt])

	lines.append("")
	lines.append("1 enemy  2 x3  3 ally  4 NVA  |  R reset  K kill all  F freeze  G god  H hud  [ / ] timescale")
	_hud.text = "\n".join(lines)


# --------------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	match k:
		KEY_1:
			spawn_enemy(VC)
		KEY_2:
			for i in range(3):
				spawn_enemy(VC)
		KEY_3:
			spawn_ally()
		KEY_4:
			spawn_enemy(NVA)
		KEY_K:
			_kill_all_enemies()
		KEY_R:
			_reset()
		KEY_F:
			_frozen = not _frozen
			for n in get_tree().get_nodes_in_group("enemies"):
				(n as Node).set_physics_process(not _frozen)
		KEY_G:
			_god = not _god
		KEY_H:
			_hud.visible = not _hud.visible
		KEY_BRACKETLEFT:
			Engine.time_scale = maxf(0.05, Engine.time_scale * 0.5)
		KEY_BRACKETRIGHT:
			Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if _god and player != null:
		# get_health_system() is another dead function -- zero callers in the game.
		var hs: HealthSystem = player.get_health_system()
		if hs != null:
			hs.current_hp = hs.max_hp
	_update_hud()
