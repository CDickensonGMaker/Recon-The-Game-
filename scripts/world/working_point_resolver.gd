## working_point_resolver.gd - lifts NodePath working_points from a site
## dict into world Vector3 positions. The paddy stamper writes NodePaths
## (because the world is unstable at plan-time), and the village stamp
## preserves them on the site dict. build() resolves them once the world
## is in place and stashes world positions back on the site for the BT
## schedule to read.
class_name WorkingPointResolver
extends RefCounted


## THE DROP LEDGER. Every point this resolver loses is a man with nowhere to work, and
## until 2026-08-28 each one was lost on a bare `continue` with no warning at all - the
## prime suspect for "far under 75% of the place-nodes fire" and for men performing at
## nothing. A drop is a WIRING fault, never a tuning one, so it is loud and it is counted.
static var offered: int = 0
static var resolved_ok: int = 0
static var dropped_no_root: int = 0     ## the site dict carries no `root` to resolve against
static var dropped_missing: int = 0     ## the NodePath names a node that is not in the tree
static var dropped_not_node3d: int = 0  ## the path resolved, but to something with no position
static var dropped_not_path: int = 0    ## the array held something that is not a NodePath


static func reset_ledger() -> void:
	offered = 0
	resolved_ok = 0
	dropped_no_root = 0
	dropped_missing = 0
	dropped_not_node3d = 0
	dropped_not_path = 0


static func ledger_line() -> String:
	return "[WORKPOINTS] offered %d, resolved %d (%.0f%%) - dropped: no_root %d, missing %d, not_node3d %d, not_path %d" % [
		offered, resolved_ok,
		100.0 * float(resolved_ok) / float(maxi(1, offered)),
		dropped_no_root, dropped_missing, dropped_not_node3d, dropped_not_path]


## Resolve a single site's working_points NodePaths to world Vector3
## positions. Mutates the site dict in place, adding `working_point_positions`.
## Returns the resolved positions.
static func resolve(site: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not site.has("working_points"):
		site["working_point_positions"] = out
		return out
	var paths: Array = site.working_points
	var node: Node = site.get("root", null)
	for p in paths:
		offered += 1
		if not (p is NodePath):
			dropped_not_path += 1
			continue
		if node == null:
			dropped_no_root += 1
			continue
		var resolved: Node = node.get_node_or_null(p)
		if resolved == null:
			dropped_missing += 1
			continue
		if not (resolved is Node3D):
			dropped_not_node3d += 1
			continue
		out.append((resolved as Node3D).global_position)
		resolved_ok += 1
	site["working_point_positions"] = out
	if out.size() < paths.size():
		push_warning("[WORKPOINTS] site dropped %d of %d working point(s)" % [
			paths.size() - out.size(), paths.size()])
	return out


