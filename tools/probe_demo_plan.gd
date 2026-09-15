## probe_demo_plan.gd - prints every position plan_demo_world resolves, so two map sizes
## (or two commits) can be diffed line by line.
##
## Run: godot --headless --path . res://tools/probe_demo_plan.tscn -- --demo-map=512 [--demo-seed=N]
extends Node

const DEMO_SEED: int = 29072026


func _ready() -> void:
	var seed_v: int = DEMO_SEED
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--demo-seed="):
			seed_v = int(a.get_slice("=", 1))
	var packed: PackedScene = load("res://scenes/levels/game_world.tscn") as PackedScene
	var world: GameWorld = packed.instantiate() as GameWorld
	world.mission_seed = seed_v
	world.map_size = GameFlow.demo_map_size()
	world.spawn_player_on_ready = false
	add_child(world)
	var waited: float = 0.0
	while not world.is_world_ready and waited < 90.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if not world.is_world_ready:
		print("[DEMO-PLAN] terrain never came up")
		get_tree().quit(1)
		return
	var p: Dictionary = MissionGenerator.plan_demo_world(world, seed_v)
	var fc: Vector3 = p.fsb_center
	print("[DEMO-PLAN] map %.0f seed %d fsb %s gate %s" % [
		world.map_size, seed_v, _xz(fc), _xz(p.gate_pos)])
	for s in (p.sites as Array):
		var sd: Dictionary = s
		print("[DEMO-PLAN] site %-8s %s r=%.0f" % [str(sd.kind), _xz(sd.center), _r(fc, sd.center)])
	for g in (p.enemy_groups as Array):
		var gd: Dictionary = g
		print("[DEMO-PLAN] group %-18s %s r=%.0f n=%d" % [
			str(gd.tag), _xz(gd.pos), _r(fc, gd.pos), int(gd.count)])
	for a: Vector3 in (p.get("ambient_aa", []) as Array):
		print("[DEMO-PLAN] aa %s r=%.0f" % [_xz(a), _r(fc, a)])
	for s2: Vector3 in (p.get("first_signs", []) as Array):
		print("[DEMO-PLAN] sign %s r=%.0f" % [_xz(s2), _r(fc, s2)])
	if p.has("stream"):
		var stream: Dictionary = p.stream
		var pts: PackedVector2Array = stream.points
		print("[DEMO-PLAN] stream %d pts from %.1f,%.1f to %.1f,%.1f" % [
			pts.size(), pts[0].x, pts[0].y, pts[pts.size() - 1].x, pts[pts.size() - 1].y])
		for fname: String in (stream.fords as Dictionary).keys():
			var f: Vector3 = (stream.fords as Dictionary)[fname]
			print("[DEMO-PLAN] ford %s %s r=%.0f" % [fname, _xz(f), _r(fc, f)])
		print("[DEMO-PLAN] runner %s" % _xz(stream.runner_stand))
	if p.has("way_station"):
		var ws: Vector3 = (p.way_station as Dictionary).center
		print("[DEMO-PLAN] way_station %s r=%.0f" % [_xz(ws), _r(fc, ws)])
	get_tree().quit(0)


static func _xz(v: Vector3) -> String:
	return "%.1f,%.1f" % [v.x, v.z]


static func _r(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
