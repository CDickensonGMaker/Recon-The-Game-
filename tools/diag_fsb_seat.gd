extends Node
## FSB seat truth (council decree 2026-07-18). Two verdicts, both must PASS:
##   CRATER-CLEAR - no first-sign inside the keep-out, plateau holds.
##   MODEL-SEAT   - HARD CLEAN assert (promoted 2026-07-18 after the corrected
##                  selection export landed): no unsupported floating clusters,
##                  wire ring base on the ground. The signature-locked KNOWN-BAD
##                  ratchet era is over; any regression goes red.
## Plus: FSB contract consts vs the loaded GLB, and a near-spawn floating-mesh
## census (which cause owns any future screenshot).

const CLEAN_MAX_UNSUPPORTED: int = 5

func _ready() -> void:
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(47225, "DIAG-SEAT")
	var waited := 0.0
	while waited < 180.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(1.0).timeout
	for i in range(5):
		await get_tree().physics_frame
	var world: GameWorld = flow.world
	var tm: TerrainManager = world.terrain_manager
	var fsb: Node3D = _find_fsb(world)
	if fsb == null:
		print("[SEAT] FAIL fsb_main missing")
		get_tree().quit(1)
		return
	var fail := false

	# ---- Contract consts vs the loaded model (a re-export must not silently
	# invalidate the keep-out rect or the clear discs).
	var boxes: Array = _mesh_boxes(fsb)
	var combined: AABB = boxes[0][1]
	for m in boxes:
		combined = combined.merge(m[1])
	var half := Vector2(combined.size.x * 0.5, combined.size.z * 0.5)
	var center_off := Vector2(combined.get_center().x - fsb.global_position.x,
		combined.get_center().z - fsb.global_position.z)
	if absf(half.x - SitePlanner.FSB_HALF.x) > 4.0 or absf(half.y - SitePlanner.FSB_HALF.y) > 4.0:
		print("[SEAT] FAIL model half-extent %.1f,%.1f vs FSB_HALF %s - remeasure site_planner consts" % [
			half.x, half.y, str(SitePlanner.FSB_HALF)])
		fail = true
	if center_off.length() > 2.0:
		print("[SEAT] FAIL model AABB center off origin by %.1fm - recenter contract broken" % center_off.length())
		fail = true

	# ---- CRATER-CLEAR
	var plan: Dictionary = MissionGenerator.plan_patrol_world(world, 47225)
	var fc: Vector3 = plan.fsb_center
	var crater_rect := Rect2(fc.x - SitePlanner.FSB_HALF.x, fc.z - SitePlanner.FSB_HALF.y,
		SitePlanner.FSB_HALF.x * 2.0, SitePlanner.FSB_HALF.y * 2.0).grow(
		MissionGenerator._crater_keepout_grow())
	var crater_ok := true
	for s: Vector3 in (plan.first_signs as Array):
		if crater_rect.has_point(Vector2(s.x, s.z)):
			print("[SEAT] first_sign at %.0f,%.0f INSIDE keep-out" % [s.x, s.z])
			crater_ok = false
	var o: Vector3 = fsb.global_position
	var hmin: float = 1.0e9
	var hmax: float = -1.0e9
	# Guaranteed-flat region = crater keep-out minus crater radius = rect.grow(40)
	# (also inside the flatten's full-seat circle). Sample just inside it.
	var span_x: float = SitePlanner.FSB_HALF.x + 35.0
	var span_z: float = SitePlanner.FSB_HALF.y + 35.0
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			var pp := o + Vector3(float(dx) * 15.0, 0, float(dz) * 15.0)
			if absf(pp.x - o.x) > span_x or absf(pp.z - o.z) > span_z:
				continue
			var h: float = tm.get_height_at(pp)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
	if hmax - hmin > 2.5:
		print("[SEAT] plateau spread %.2fm (want <=2.5) - something re-dug the seat" % (hmax - hmin))
		crater_ok = false
	print("[SEAT] CRATER-CLEAR %s (signs=%d, plateau spread %.2fm, seat %.2f)" % [
		"PASS" if crater_ok else "FAIL", (plan.first_signs as Array).size(), hmax - hmin, o.y])
	if not crater_ok:
		fail = true

	# ---- MODEL-SEAT (model-space, terrain-independent: fresh instantiate)
	var scene: PackedScene = load(SitePlanner.FSB_MAIN_PATH)
	var mroot := scene.instantiate() as Node3D
	var mboxes: Array = _mesh_boxes(mroot)
	var unsupported: Array = []
	for m in mboxes:
		var b: AABB = m[1]
		if b.position.y <= 0.5:
			continue
		if not _supported(m, mboxes):
			unsupported.append([b.position.y, m[0]])
	var wire_base: float = 1.0e9
	for m2 in mboxes:
		if str(m2[0]).begins_with("bwire_card"):
			wire_base = minf(wire_base, (m2[1] as AABB).position.y)
	mroot.free()
	var seat_verdict: String
	if unsupported.size() <= CLEAN_MAX_UNSUPPORTED and wire_base < 0.05:
		seat_verdict = "CLEAN"
		print("[SEAT] MODEL-SEAT CLEAN (unsupported=%d, wire base %.3f)" % [
			unsupported.size(), wire_base])
	else:
		seat_verdict = "FAIL"
		print("[SEAT] MODEL-SEAT FAIL (hard-clean assert): unsupported=%d (max %d), wire base %.3f (max 0.05)" % [
			unsupported.size(), CLEAN_MAX_UNSUPPORTED, wire_base])
		for u2: Array in unsupported.slice(0, 12):
			print("[SEAT]   unsupported bottom=%.2f %s" % [u2[0], str(u2[1])])
		fail = true

	# ---- Near-spawn census: what a standing player actually sees floating.
	var spawn: Vector3 = world.player.global_position
	var census: int = 0
	for m3 in boxes:
		var b3: AABB = m3[1]
		var cx := Vector2(b3.get_center().x, b3.get_center().z)
		if cx.distance_to(Vector2(spawn.x, spawn.z)) > 60.0:
			continue
		var gap: float = b3.position.y - tm.get_height_at(Vector3(cx.x, 0, cx.y))
		if gap > 1.0 and not _supported(m3, boxes):
			census += 1
			if census <= 10:
				print("[SEAT] near-spawn floater: %s gap=%.2fm at %.0f,%.0f" % [str(m3[0]), gap, cx.x, cx.y])
	print("[SEAT] near-spawn unsupported floaters (60m): %d" % census)

	# ---- Gate-cluster material truth (the "gray" question, DA).
	var gate_untex: int = 0
	var gate_surf: int = 0
	for m4 in boxes:
		var name4: String = str(m4[0])
		if not (name4.begins_with("gate_") or name4.begins_with("watchtower") or name4.begins_with("claymore")):
			continue
		var mi4: MeshInstance3D = m4[2]
		for si in range(mi4.mesh.get_surface_count()):
			gate_surf += 1
			var mat: Material = mi4.get_active_material(si)
			var sm := mat as StandardMaterial3D
			if sm == null or sm.albedo_texture == null:
				gate_untex += 1
	print("[SEAT] gate-cluster surfaces: %d, untextured: %d" % [gate_surf, gate_untex])

	var pp2: Vector3 = world.player.global_position
	print("[SEAT] player delta vs terrain: %.2f" % (pp2.y - tm.get_height_at(pp2)))
	print("[SEAT] VERDICT crater=%s model=%s -> %s" % [
		"PASS" if crater_ok else "FAIL", seat_verdict, "FAIL" if fail else "PASS"])
	get_tree().quit(1 if fail else 0)


func _find_fsb(world: Node) -> Node3D:
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("model_name") and str(n.get_meta("model_name")) == "fsb_main":
			return n as Node3D
		for c in n.get_children():
			stack.append(c)
	return null


## [name, world-or-model-space AABB, MeshInstance3D]
func _mesh_boxes(root: Node3D) -> Array:
	var out: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or not mi.visible or mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		if root.is_inside_tree():
			xf = root.global_transform * xf
		out.append([mi.name, xf * mi.mesh.get_aabb(), mi])
	return out


func _supported(m: Array, boxes: Array) -> bool:
	var b: AABB = m[1]
	var c := Vector2(b.get_center().x, b.get_center().z)
	for o in boxes:
		if o[0] == m[0]:
			continue
		var ob: AABB = o[1]
		var oc := Vector2(ob.get_center().x, ob.get_center().z)
		if absf(oc.x - c.x) < (b.size.x + ob.size.x) * 0.5 \
				and absf(oc.y - c.y) < (b.size.z + ob.size.z) * 0.5 \
				and ob.position.y < b.position.y - 0.3 and ob.end.y >= b.position.y - 1.0:
			return true
	return false
