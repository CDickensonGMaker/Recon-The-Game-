## working_point_resolver.gd - lifts NodePath working_points from a site
## dict into world Vector3 positions. The paddy stamper writes NodePaths
## (because the world is unstable at plan-time), and the village stamp
## preserves them on the site dict. build() resolves them once the world
## is in place and stashes world positions back on the site for the BT
## schedule to read.
class_name WorkingPointResolver
extends RefCounted


## Resolve a single site's working_points NodePaths to world Vector3
## positions. Mutates the site dict in place, adding `working_point_positions`.
## Returns the resolved positions.
static func resolve(site: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not site.has("working_points"):
		site["working_point_positions"] = out
		return out
	var paths: Array = site.working_points
	for p in paths:
		if p is NodePath:
			var node: Node = site.get("root", null)
			if node == null:
				continue
			var resolved: Node = node.get_node_or_null(p)
			if resolved and resolved is Node3D:
				out.append((resolved as Node3D).global_position)
	site["working_point_positions"] = out
	return out


## Resolve all sites in a plan dict in place. Each site that has
## working_points gets `working_point_positions` written. The site must
## have `root` set to its world node for path resolution to work.
static func resolve_plan(plan: Dictionary) -> void:
	for site in plan.get("sites", []):
		if site is Dictionary:
			resolve(site)
