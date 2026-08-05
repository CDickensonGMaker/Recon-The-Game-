extends Node3D

## CRATER PROBE (headless). Answers one question with numbers instead of opinion:
## with craters capped per 64m cell (his ruling 2026-08-05), does re-shelling one patch
## stop digging while fresh ground still does - and does the jungle come down with it?
##
##   godot --headless --path . res://tools/crater_probe.tscn ++ --crater-probe
##
## Bombards a real GameWorld: one cell shelled far past its cap, then a walking barrage
## across fresh cells. Reports digs, refusals, and what the fell registry caught.

const ROUNDS_ON_ONE_SPOT: int = 25
const WALK_ROUNDS: int = 10
const WALK_STEP_M: float = 70.0     ## > DEFORM_CELL_M, so every round lands in a new cell


func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/levels/game_world.tscn") as PackedScene
	var world: Node3D = packed.instantiate() as Node3D
	add_child(world)

	# Terrain builds asynchronously; DamageSystem is wired in _on_terrain_ready.
	var waited: int = 0
	while DamageSystem.terrain_manager == null and waited < 1200:
		await get_tree().process_frame
		waited += 1
	if DamageSystem.terrain_manager == null:
		print("[CRATER-PROBE] FAIL: terrain never became ready after %d frames" % waited)
		get_tree().quit()
		return
	print("[CRATER-PROBE] world up after %d frames" % waited)

	var veg: Node = DamageSystem.vegetation_manager
	var centre := Vector3(32.0, 0.0, 32.0)   ## middle of cell (0,0), jitter stays inside it

	# --- 1. HAMMER ONE PATCH. Every round lands inside a single 64m cell.
	var before_digs: int = DamageSystem._deforms_this_mission
	for i in ROUNDS_ON_ONE_SPOT:
		var jitter := Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
		DamageSystem.apply_damage(centre + jitter, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	var one_spot: int = DamageSystem._deforms_this_mission - before_digs
	print("[CRATER-PROBE] one patch: %d rounds -> %d craters dug, %d refused (cap %d/cell)"
		% [ROUNDS_ON_ONE_SPOT, one_spot, ROUNDS_ON_ONE_SPOT - one_spot,
			DamageSystem.MAX_DEFORMS_PER_CELL])

	# --- 2. WALK THE BARRAGE. Each round lands in ground that has never been hit.
	before_digs = DamageSystem._deforms_this_mission
	for i in WALK_ROUNDS:
		var at := Vector3(300.0 + i * WALK_STEP_M, 0.0, 300.0)
		DamageSystem.apply_damage(at, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	var walked: int = DamageSystem._deforms_this_mission - before_digs
	print("[CRATER-PROBE] fresh ground: %d rounds -> %d craters dug, %d refused"
		% [WALK_ROUNDS, walked, WALK_ROUNDS - walked])

	print("[CRATER-PROBE] cells touched=%d  total digs=%d  global backstop=%d"
		% [DamageSystem._deforms_by_cell.size(), DamageSystem._deforms_this_mission,
			DamageSystem.MAX_DEFORMS_PER_MISSION])

	# --- 3. WHAT THE JUNGLE DID. Felled logs and standing snags are registry DATA.
	if veg != null:
		var reg: Array = veg._fell_registry
		var snags: int = 0
		var logs: int = 0
		for e: Dictionary in reg:
			if String(e.get("name", "")).ends_with("_low"):
				snags += 1
			elif e.has("trunk_r"):
				logs += 1
		print("[CRATER-PROBE] vegetation: holes=%d  fell_registry=%d entries (%d snags, %d cover pieces)"
			% [veg._veg_holes.size(), reg.size(), snags, logs])
		print("[CRATER-PROBE] hole buckets=%d (spatial index; a linear scan would be %d compares/plant)"
			% [veg._veg_hole_buckets.size(), veg._veg_holes.size()])
	else:
		print("[CRATER-PROBE] no vegetation manager wired")

	# Let the fall tweens land so the registry sees resting logs, then re-read.
	await get_tree().create_timer(3.0).timeout
	if veg != null:
		print("[CRATER-PROBE] after the falls settled: fell_registry=%d entries"
			% (veg._fell_registry as Array).size())

	# --- 4. AIRBURSTS. A burst ABOVE the base is what picks a joint; a ground burst is
	# meant to take the whole tree, which is why the runs above show no snags.
	var reg_before: int = (veg._fell_registry as Array).size() if veg != null else 0
	print("[CRATER-PROBE] loaded terrain chunks=%d" % (veg._chunk_terrain as Dictionary).size())
	for i in 6:
		var at := Vector3(300.0 + i * 70.0, 0.0, 430.0)   ## beside the walked line, in loaded chunks
		at.y = DamageSystem.terrain_manager.heightmap.sample_world(at.x, at.z) + 6.0
		DamageSystem.apply_damage(at, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	await get_tree().create_timer(3.0).timeout
	if veg != null:
		var snag2: int = 0
		var cover2: int = 0
		for e: Dictionary in (veg._fell_registry as Array):
			if String(e.get("name", "")).ends_with("_low"):
				snag2 += 1
			elif e.has("trunk_r"):
				cover2 += 1
		print("[CRATER-PROBE] airburst x6: registry %d -> %d  (%d snags, %d cover pieces total)"
			% [reg_before, (veg._fell_registry as Array).size(), snag2, cover2])

	print("[CRATER-PROBE] done")
	get_tree().quit()
