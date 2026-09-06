## probe_chowhall_nav.gd - CAN A MAN WALK INTO THE CHOW HALL?
## Diagnostic for item 27 (no mess hall animations playing). Boots the demo world,
## waits for the nav bake, then asks the navigation server whether every work_chow_*
## and work_eat/work_queue marker resolves to a nearby walkable polygon - the same
## question a Civilian's path-to-post request asks. A marker with no nearby polygon
## is a marker no AI can ever reach, so the clip keyed to it can never play.
##   godot --headless --path . res://tools/probe_chowhall_nav.tscn
extends Node

const REACH_TOL_M: float = 1.6
const SAMPLE_UP_M: float = 0.4
const PREFIXES: Array[String] = ["work_chow", "work_eat", "work_queue", "work_cook",
	"work_traycollector", "work_trayhandoff"]

func _ready() -> void:
	await get_tree().process_frame
	print("\n=== CHOW HALL NAV ===\n")
	var scene: PackedScene = load("res://scenes/levels/demo_game.tscn") as PackedScene
	add_child(scene.instantiate())
	var spins: int = 0
	while spins < 400 and get_tree().get_nodes_in_group(&"nav_baker").is_empty():
		spins += 1
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(6.0).timeout
	await get_tree().create_timer(3.0).timeout

	var map: RID = get_viewport().world_3d.navigation_map
	if not map.is_valid():
		print("  [FAIL] no navigation map")
		get_tree().quit(1)
		return

	var markers: Array[Node3D] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Node3D:
			var nm: String = String(n.name)
			for p in PREFIXES:
				if nm.begins_with(p):
					markers.append(n as Node3D)
					break

	if markers.is_empty():
		print("  [FAIL] no chow markers found in the live world - the hall did not stamp")
		get_tree().quit(1)
		return

	markers.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
	print("chow markers found: %d\n" % markers.size())
	print("  %-28s %-22s %-8s %s" % ["marker", "world pos", "d(nav)", "verdict"])

	var reachable: int = 0
	var sealed: int = 0
	for m in markers:
		var p: Vector3 = m.global_position + Vector3.UP * SAMPLE_UP_M
		var got: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
		var d: float = Vector2(got.x - p.x, got.z - p.z).length()
		var dy: float = got.y - p.y
		var ok: bool = d <= REACH_TOL_M
		if ok:
			reachable += 1
		else:
			sealed += 1
		print("  %-28s (%7.2f,%7.2f,%6.2f)  %-8.2f dy=%-6.2f %-9s nearest=(%.2f,%.2f,%.2f)" % [
			String(m.name).left(28), p.x, p.z, p.y, d, dy,
			"reachable" if ok else "SEALED", got.x, got.z, got.y])

	print("\n%d reachable, %d SEALED, of %d chow markers" % [reachable, sealed, markers.size()])
	get_tree().quit(1 if sealed > 0 else 0)
