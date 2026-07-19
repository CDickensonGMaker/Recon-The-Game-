extends Node
## Crater retune truth: dig one of each profile on live terrain, measure the
## actual depth/rim in meters against the approved table (0.6 / 2.0 / 8.0).

func _ready() -> void:
	var world := (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	world.mission_seed = 47225
	world.spawn_player_on_ready = false
	add_child(world)
	while not world.is_world_ready:
		await get_tree().create_timer(0.25).timeout
	var tm: TerrainManager = world.terrain_manager
	DamageSystem.set_terrain_manager(tm)
	var fail := false
	var cases: Array = [
		[DamageSystem.DamageType.SMALL_EXPLOSION, 0.6, "SMALL"],
		[DamageSystem.DamageType.MEDIUM_EXPLOSION, 2.0, "MEDIUM"],
		[DamageSystem.DamageType.LARGE_EXPLOSION, 8.0, "LARGE"],
	]
	var at := Vector3(300.0, 0.0, 300.0)
	for c in cases:
		at.x += 120.0   # fresh ground per dig
		var pre := PackedFloat32Array()
		for dx in range(-8, 9):
			for dz in range(-8, 9):
				pre.append(tm.get_height_at(at + Vector3(float(dx) * 2.0, 0.0, float(dz) * 2.0)))
		DamageSystem.apply_damage(at, c[0], 1.0)
		var lo: float = 1.0e9
		var hi: float = -1.0e9
		var idx: int = 0
		for dx in range(-8, 9):
			for dz in range(-8, 9):
				var p := at + Vector3(float(dx) * 2.0, 0.0, float(dz) * 2.0)
				var h: float = tm.get_height_at(p) - pre[idx]
				idx += 1
				lo = minf(lo, h)
				hi = maxf(hi, h)
		var want: float = c[1]
		# the falloff curve peaks below the authored depth (smoothstep x pow) -
		# accept 45-100% of authored; catches both a x350 blowout and a no-op
		var ok: bool = -lo >= want * 0.45 and -lo <= want * 1.05 and hi < want * 0.3
		print("[CRATER] %-7s authored=%.1fm  dug=%.2fm  rim=+%.2fm  %s" % [
			c[2], want, -lo, hi, "OK" if ok else "FAIL"])
		if not ok:
			fail = true
	print("[CRATER] keepout grow now: %.0fm" % MissionGenerator._crater_keepout_grow())
	print("[CRATER] VERDICT -> %s" % ("FAIL" if fail else "PASS"))
	get_tree().quit(1 if fail else 0)
