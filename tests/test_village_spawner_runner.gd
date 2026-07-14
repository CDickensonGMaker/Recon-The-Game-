extends SceneTree

func _init() -> void:
	print("=== VILLAGE SPAWNER SMOKE TEST ===")
	var no_firebases: Array[Vector2] = []
	var Spawner = load("res://terrain/world/village_spawner.gd")
	var v_no: Array = Spawner.sample_world(42, 1280.0, no_firebases)
	print("Seed 42, no firebases: %d villages" % v_no.size())
	for v in v_no:
		print("  %s pos=%s families=%d villagers=%d VC=%d hideouts=%d" % [
			v.village_id, str(v.world_position), v.families.size(),
			v.total_villagers(), v.total_vc(), v.linked_hideouts.size()
		])
		for h in v.linked_hideouts:
			var tname: String = "CAMP" if h.type == 0 else "TUNNEL"
			print("    %s %s pos=%s dist=%.0fm angle=%.0fdeg defenders=%d" % [
				h.hideout_id, tname, str(h.world_position),
				h.distance_from_village, h.angle_from_village, h.defender_count
			])

	var v2: Array = Spawner.sample_world(42, 1280.0, no_firebases)
	var same: bool = v_no.size() == v2.size()
	if same:
		for i in v_no.size():
			if v_no[i].world_position != v2[i].world_position:
				same = false
				break
	print("Determinism: %s" % ("PASS" if same else "FAIL"))

	var v3: Array = Spawner.sample_world(99, 1280.0, no_firebases)
	print("Seed 99 villages: %d" % v3.size())

	var firebases: Array[Vector2] = [Vector2(640.0, 640.0)]
	var v4: Array = Spawner.sample_world(42, 1280.0, firebases)
	print("Seed 42 with 1 firebase: %d villages" % v4.size())
	for v in v4:
		print("  %s pos=%s (dist to fb: %.0fm)" % [
			v.village_id, str(v.world_position), v.world_position.distance_to(firebases[0])
		])
	print("=== SMOKE TEST COMPLETE ===")
	quit()
