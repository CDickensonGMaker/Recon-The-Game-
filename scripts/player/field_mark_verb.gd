## field_mark_verb.gd - The report verb's noun inference (ADR-022 Amendment A).
## One verb, world-inferred noun: the kind comes from the highest-priority markable
## thing under the reticle. FOUR nouns only - the vocabulary is the world's, not a menu.
## Static and tree-free on purpose so the probe can exercise it without a world.
class_name FieldMarkVerb
extends RefCounted

## Priority: a man beats the hole he crawled out of; a hole beats the huts around it.
const TUNNEL_NEAR_M: float = 8.0
const CAMP_NEAR_M: float = 30.0
const TRAIL_NEAR_M: float = 6.0

## The circle IS the uncertainty (ADR-022 Amdt A #3): rough by design, wider with range.
const AREA_R_MIN: float = 40.0
const AREA_R_MAX: float = 120.0
const AREA_R_PER_M: float = 0.3


static func infer(collider: Object, hit: Vector3, tunnels: Array,
		camp_centers: Array, road_segments: Array) -> String:
	if collider is EnemyBase and not (collider as EnemyBase).is_dead():
		return "CONTACT"
	if collider is Node and (collider as Node).is_in_group("tunnel_entrances"):
		return "TUNNEL"
	for t in tunnels:
		var tn := t as Node3D
		if tn != null and tn.is_inside_tree() and tn.global_position.distance_to(hit) < TUNNEL_NEAR_M:
			return "TUNNEL"
	if collider is Node and (collider as Node).is_in_group("flammable_structures"):
		return "CAMP"
	var hit2 := Vector2(hit.x, hit.z)
	for c in camp_centers:
		var cv: Vector3 = c
		if Vector2(cv.x, cv.z).distance_to(hit2) < CAMP_NEAR_M:
			return "CAMP"
	# Distance to the trail LINE, not to its vertices. A polyline's points can sit
	# tens of metres apart, so measuring to them alone made the whole middle of a
	# segment unmarkable while its two ends worked.
	for seg in road_segments:
		var pts := seg as PackedVector3Array
		if pts.is_empty():
			continue
		if pts.size() == 1:
			if Vector2(pts[0].x, pts[0].z).distance_to(hit2) < TRAIL_NEAR_M:
				return "TRAIL"
			continue
		for i in range(pts.size() - 1):
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			if Geometry2D.get_closest_point_to_segment(hit2, a, b).distance_to(hit2) < TRAIL_NEAR_M:
				return "TRAIL"
	return ""


static func area_radius(dist: float) -> float:
	return clampf(AREA_R_MIN + dist * AREA_R_PER_M, AREA_R_MIN, AREA_R_MAX)
