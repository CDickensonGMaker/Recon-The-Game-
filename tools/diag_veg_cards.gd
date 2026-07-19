extends SceneTree
## Card-vs-solid mesh AABB truth: does a species' impostor card share the solid's
## ground anchor, or does its pivot float the quad? Pure mesh data, headless-valid.

func _init() -> void:
	var tc := TreeCoverLayer.new()
	var names: Array = []
	var dir := DirAccess.open("res://assets/world/vegetation/")
	for f in dir.get_files():
		if f.ends_with(".glb"):
			names.append(f.trim_suffix(".glb"))
	tc.load_species(names)
	print("[CARDS] species: %d solid, %d cards" % [tc._solid_mesh.size(), tc._card_mesh.size()])
	var bad: int = 0
	for nm in tc._card_mesh:
		var card: Mesh = tc._card_mesh[nm]
		var solid: Mesh = tc._solid_mesh.get(nm)
		var cb: AABB = card.get_aabb()
		var sb: AABB = solid.get_aabb() if solid != null else AABB()
		var flag := ""
		if absf(cb.position.y) > 0.35:
			flag = "  <-- CARD BASE OFF GROUND"
			bad += 1
		print("[CARDS] %-20s card_y %.2f..%.2f  solid_y %.2f..%.2f%s" % [
			nm, cb.position.y, cb.end.y, sb.position.y, sb.end.y, flag])
	print("[CARDS] cards with base offset >0.35m: %d" % bad)
	tc.free()
	quit(0)
