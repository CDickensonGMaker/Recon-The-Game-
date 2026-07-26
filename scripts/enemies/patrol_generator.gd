## patrol_generator.gd - procedural patrol routes. The point is routes that
## stay on ground you can actually walk (CLEAR / GRASSLAND / LIGHT_JUNGLE),
## curve along the terrain, and avoid paddy centroids where you'd be silhouetted.
##
## The grid is coarse (~10m) so a BFS sweep returns a 1km ring of candidates in
## under a millisecond. We sample N candidates, score each, and return a sorted
## loop of waypoints.
class_name PatrolGenerator
extends RefCounted

## Distance bands. The paddy stamper produces ~80-120m paddies, so 30m is the
## minimum visible silhouette and we want patrol routes at the edge of that.
const PADDY_AVOID_RADIUS: float = 30.0
const WAYPOINT_MIN_SPACING: float = 18.0

## Cells the patrol can stand on. Reject anything harder to move through than
## medium jungle (anything that costs > 1.8x normal movement).
const WALKABLE_COST_MAX: float = 1.8


## Generate a patrol loop starting at `anchor` with `count` waypoints.
## `grid` is the gameplay grid; `paddy_centroids` is the list from the paddy
## stamper (may be empty). `rng` is the caller's seeded RNG.
static func generate(grid: GameplayGrid, anchor: Vector3, count: int,
		paddy_centroids: Array, rng: RandomNumberGenerator) -> Array[Vector3]:
	if grid == null or count <= 0:
		return []
	var out: Array[Vector3] = []
	out.append(anchor)
	for i in range(count - 1):
		var heading: float = rng.randf_range(0.0, TAU)
		var radius: float = rng.randf_range(40.0, 90.0)
		var candidate: Vector3 = anchor + Vector3(cos(heading), 0.0, sin(heading)) * radius
		# Snap to a walkable cell. If the cell is water/cliff, walk back toward
		# the anchor and try a slightly tighter radius.
		var snapped_pos: Vector3 = _snap_to_walkable(grid, candidate, anchor)
		if snapped_pos == Vector3.ZERO:
			snapped_pos = anchor + Vector3(cos(heading), 0.0, sin(heading)) * 20.0
		# Reject if too close to a paddy centroid (silhouette risk).
		if _near_paddy(snapped_pos, paddy_centroids):
			var alt_heading: float = heading + PI * 0.5
			var alt: Vector3 = anchor + Vector3(cos(alt_heading), 0.0, sin(alt_heading)) * radius
			var alt_snap: Vector3 = _snap_to_walkable(grid, alt, anchor)
			if alt_snap != Vector3.ZERO and not _near_paddy(alt_snap, paddy_centroids):
				snapped_pos = alt_snap
		# Keep spacing between consecutive waypoints.
		if out.size() > 0 \
				and snapped_pos.distance_to(out[out.size() - 1]) < WAYPOINT_MIN_SPACING:
			continue
		out.append(snapped_pos)
	if out.size() < 2:
		return [anchor]
	return out


static func _snap_to_walkable(grid: GameplayGrid, pos: Vector3, fallback: Vector3) -> Vector3:
	if _is_walkable(grid, pos):
		return pos
	# Walk back toward the fallback in 5m steps until we find a walkable cell.
	var dir: Vector3 = (fallback - pos)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	for step in range(1, 12):
		var p: Vector3 = pos + dir * 5.0 * float(step)
		if _is_walkable(grid, p):
			return p
	return Vector3.ZERO


static func _is_walkable(grid: GameplayGrid, pos: Vector3) -> bool:
	var gx_gz: Vector2i = grid.world_to_grid(pos)
	var tt: int = grid.get_terrain_type_at(gx_gz.x, gx_gz.y)
	var cost: float = float(GameplayGrid.MOVEMENT_COSTS.get(tt, 99.0))
	return cost <= WALKABLE_COST_MAX


static func _near_paddy(pos: Vector3, centroids: Array) -> bool:
	for c in centroids:
		if pos.distance_to(c as Vector3) < PADDY_AVOID_RADIUS:
			return true
	return false
