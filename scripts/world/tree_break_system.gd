extends Node

## S29 destructible jungle (his 8/7 ruling): the live canopy stays MultiMesh with ZERO
## standing colliders; ordnance finds trees by SPATIAL LOOKUP against this registry, never
## physics. Only a hit tree is promoted to its 3-part segmented form (_stump/_stem/_crown
## break bands), breaks at the joint nearest the hit height, and the parts above hinge-fall
## as cover - state-swap only, never RigidBody (ADR-031). Bullets do not fell trees: only
## blasts (apply_blast) and AOE warheads (query_ahead from projectile_base.gd) reach this.
## Band data comes from data/veg_break_bands.json, GENERATED from the segment art by
## tools/gen_veg_break_bands.py - re-run it after re-exporting any *_stump/_stem/_crown
## GLB. Without that file _bands is empty, register_chunk drops every instance and the
## jungle is silently unbreakable (it was, from 8/7 until 8/11). Covered by
## tests/test_support_fire_bench.gd. Instances come from TreeCoverLayer.generate_for_chunk.

const BANDS_JSON := "res://data/veg_break_bands.json"
const CELL_M: float = 16.0
const MAX_TREES_PER_BLAST: int = 12
const MAX_BUSH_PER_BLAST: int = 8
const BREAKS_PER_FRAME: int = 6
const QUERY_RANGE_CAP: float = 300.0

var _bands: Dictionary = {}        ## species -> {parts, cut_low, cut_high, top, trunk_r}
var _cells: Dictionary = {}        ## Vector2i -> Array[Dictionary] live entries
var _chunks: Dictionary = {}       ## "layer_id|coord" -> Array[Dictionary]
var _break_queue: Array[Dictionary] = []


func _ready() -> void:
	_load_bands()


func _load_bands() -> void:
	_bands.clear()
	var f: FileAccess = FileAccess.open(BANDS_JSON, FileAccess.READ)
	if f == null:
		push_warning("[TreeBreak] %s missing - jungle is unbreakable this run" % BANDS_JSON)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_warning("[TreeBreak] %s unparseable" % BANDS_JSON)
		return
	var species: Dictionary = (parsed as Dictionary).get("species", {})
	for nm: String in species:
		var d: Dictionary = species[nm]
		_bands[nm] = {
			"cut_low": float(d.get("cut_low_m", 0.0)),
			"cut_high": float(d.get("cut_high_m", 0.0)),
			"top": float(d.get("top_m", 0.0)),
			"trunk_r": float(d.get("trunk_r_m", 0.0)),
		}


func species_count() -> int:
	return _bands.size()


func is_breakable(nm: String) -> bool:
	return _bands.has(nm)


static func _is_bush(nm: String) -> bool:
	return nm.begins_with("bush_") or nm.begins_with("lp_bush_")


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL_M), floori(p.z / CELL_M))


static func _chunk_key(layer: Node, coord: Vector2i) -> String:
	return "%d|%d,%d" % [layer.get_instance_id(), coord.x, coord.y]


## TreeCoverLayer calls this per generate_for_chunk. Only species with a segment set
## register; grass/fern/vine and re-emitted parts (snags, lying logs) are not breakable.
func register_chunk(layer: Node3D, coord: Vector2i, scatter: Array) -> void:
	unregister_chunk(layer, coord)
	var list: Array = []
	for i in scatter.size():
		var e: Dictionary = scatter[i]
		var nm: String = String(e.get("name", ""))
		if not _bands.has(nm):
			continue
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		var entry: Dictionary = {
			"species": nm, "xf": xf, "layer": layer, "coord": coord, "idx": i,
			"cell": _cell_of(xf.origin), "dead": false,
		}
		list.append(entry)
		var cell: Vector2i = entry["cell"]
		if not _cells.has(cell):
			_cells[cell] = []
		(_cells[cell] as Array).append(entry)
	if not list.is_empty():
		_chunks[_chunk_key(layer, coord)] = list


func unregister_chunk(layer: Node3D, coord: Vector2i) -> void:
	var key: String = _chunk_key(layer, coord)
	if not _chunks.has(key):
		return
	for entry: Dictionary in _chunks[key]:
		entry["dead"] = true
		var cell: Vector2i = entry["cell"]
		if _cells.has(cell):
			(_cells[cell] as Array).erase(entry)
			if (_cells[cell] as Array).is_empty():
				_cells.erase(cell)
	_chunks.erase(key)


func unregister_layer(layer: Node3D) -> void:
	var prefix: String = "%d|" % layer.get_instance_id()
	for key: String in _chunks.keys():
		if key.begins_with(prefix):
			for entry: Dictionary in _chunks[key]:
				entry["dead"] = true
				var cell: Vector2i = entry["cell"]
				if _cells.has(cell):
					(_cells[cell] as Array).erase(entry)
					if (_cells[cell] as Array).is_empty():
						_cells.erase(cell)
			_chunks.erase(key)


func registered_count() -> int:
	var n: int = 0
	for key: String in _chunks:
		n += (_chunks[key] as Array).size()
	return n


## Nearest standing trunk a ray crosses within `range_m`. Pure data - no physics query.
## Trunk = vertical cylinder at the instance origin, radius trunk_r x scale, full band
## height (a shell into the crown must contact - airburst decree 2026-08-04). Returns
## {} or {position, distance, entry}.
func query_ahead(from: Vector3, dir: Vector3, range_m: float) -> Dictionary:
	if _cells.is_empty() or range_m <= 0.0:
		return {}
	var d: Vector3 = dir.normalized()
	var r: float = minf(range_m, QUERY_RANGE_CAP)
	var best: Dictionary = {}
	var best_t: float = r + 1.0
	var seen: Dictionary = {}
	var march: float = 0.0
	while march <= r:
		var p: Vector3 = from + d * march
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				var cell: Vector2i = _cell_of(p) + Vector2i(ox, oz)
				if seen.has(cell) or not _cells.has(cell):
					continue
				seen[cell] = true
				for entry: Dictionary in _cells[cell]:
					if bool(entry["dead"]):
						continue
					var t: float = _ray_hits_trunk(from, d, r, entry)
					if t >= 0.0 and t < best_t:
						best_t = t
						best = entry
		march += CELL_M * 0.5
	if best.is_empty():
		return {}
	return {"position": from + d * best_t, "distance": best_t, "entry": best}


## Smallest t in [0, range] where the ray crosses the entry's trunk cylinder, or -1.
func _ray_hits_trunk(from: Vector3, d: Vector3, range_m: float, entry: Dictionary) -> float:
	var band: Dictionary = _bands[entry["species"]]
	var s: float = (entry["xf"] as Transform3D).basis.get_scale().y
	var radius: float = float(band["trunk_r"]) * s
	if radius <= 0.0:
		return -1.0
	var o: Vector3 = (entry["xf"] as Transform3D).origin
	var top: float = o.y + float(band["top"]) * s
	var fx: float = from.x - o.x
	var fz: float = from.z - o.z
	var a: float = d.x * d.x + d.z * d.z
	var b: float = 2.0 * (fx * d.x + fz * d.z)
	var c: float = fx * fx + fz * fz - radius * radius
	var t: float
	if a < 0.000001:
		# Vertical ray: inside the disc or a miss.
		if c > 0.0:
			return -1.0
		t = 0.0
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc < 0.0:
			return -1.0
		t = (-b - sqrt(disc)) / (2.0 * a)
		if t < 0.0:
			t = (-b + sqrt(disc)) / (2.0 * a)
	if t < 0.0 or t > range_m:
		return -1.0
	var y: float = from.y + d.y * t
	if y < o.y or y > top:
		return -1.0
	return t


## Blast entry point (wired in combat_manager.apply_explosion_damage and
## damage_system.apply_damage - consumption makes the double call idempotent).
## Trees and bushes spend separate budgets: the undergrowth is far more numerous
## and must not eat the treeline's allowance.
func apply_blast(center: Vector3, radius: float) -> int:
	if _cells.is_empty() or radius <= 0.0:
		return 0
	var trees: Array[Dictionary] = []
	var bushes: Array[Dictionary] = []
	var lo: Vector2i = _cell_of(center - Vector3(radius, 0.0, radius))
	var hi: Vector2i = _cell_of(center + Vector3(radius, 0.0, radius))
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			var cell := Vector2i(cx, cz)
			if not _cells.has(cell):
				continue
			for entry: Dictionary in _cells[cell]:
				if bool(entry["dead"]):
					continue
				var o: Vector3 = (entry["xf"] as Transform3D).origin
				if Vector2(o.x - center.x, o.z - center.z).length() > radius:
					continue
				if _is_bush(String(entry["species"])):
					if bushes.size() < MAX_BUSH_PER_BLAST:
						bushes.append(entry)
				elif trees.size() < MAX_TREES_PER_BLAST:
					trees.append(entry)
	var doomed: Array[Dictionary] = trees + bushes
	if doomed.is_empty():
		return 0
	_consume(doomed)
	for entry: Dictionary in doomed:
		_break_queue.append({"entry": entry, "blast": center})
	return doomed.size()


## Front door for a resolved single hit (query_ahead result): consume the instance and
## return its segmented stand-in, still whole. Caller then break_at()s it.
func promote(hit: Dictionary) -> BrokenTree:
	var entry: Dictionary = hit.get("entry", hit)
	if entry.is_empty() or bool(entry.get("dead", true)):
		return null
	_consume([entry])
	return _spawn_broken(entry)


## Pull consumed entries out of the registry AND out of their layers' stored scatter
## (one chunk regen per touched chunk), so nothing re-renders the standing original.
func _consume(doomed: Array[Dictionary]) -> void:
	var by_chunk: Dictionary = {}
	for entry: Dictionary in doomed:
		entry["dead"] = true
		var cell: Vector2i = entry["cell"]
		if _cells.has(cell):
			(_cells[cell] as Array).erase(entry)
			if (_cells[cell] as Array).is_empty():
				_cells.erase(cell)
		var layer: Node3D = entry["layer"]
		if not is_instance_valid(layer):
			continue
		var key: String = _chunk_key(layer, entry["coord"])
		if _chunks.has(key):
			(_chunks[key] as Array).erase(entry)
		if not by_chunk.has(key):
			by_chunk[key] = {"layer": layer, "coord": entry["coord"], "idx": []}
		((by_chunk[key] as Dictionary)["idx"] as Array).append(int(entry["idx"]))
		var vm: Node = layer.get_parent()
		if vm != null and vm.has_method("add_break_hole"):
			vm.add_break_hole((entry["xf"] as Transform3D).origin)
	for key: String in by_chunk:
		var job: Dictionary = by_chunk[key]
		var layer: Node3D = job["layer"]
		if is_instance_valid(layer) and layer.has_method("remove_scatter_entries"):
			layer.remove_scatter_entries(job["coord"] as Vector2i, job["idx"] as Array)


func _process(_delta: float) -> void:
	var n: int = mini(BREAKS_PER_FRAME, _break_queue.size())
	for _i in n:
		var job: Dictionary = _break_queue.pop_front()
		var entry: Dictionary = job["entry"]
		var bt: BrokenTree = _spawn_broken(entry)
		if bt != null:
			var blast: Vector3 = job["blast"]
			bt.break_at(blast.y - (entry["xf"] as Transform3D).origin.y, blast)


func _spawn_broken(entry: Dictionary) -> BrokenTree:
	var layer: Node3D = entry["layer"]
	if not is_instance_valid(layer) or not layer.is_inside_tree():
		return null
	var nm: String = entry["species"]
	var parts: Array[String] = [nm + "_stump", nm + "_stem", nm + "_crown"]
	if layer.has_method("load_species"):
		layer.call("load_species", parts)
	var bt := BrokenTree.new()
	bt.species = nm
	bt.source_xf = entry["xf"]
	bt.band = _bands[nm]
	bt.layer = layer
	var vm: Node = layer.get_parent()
	if vm != null and vm.has_method("add_fell_entries"):
		bt.vm = vm
	var host: Node = vm if bt.vm != null else layer
	host.add_child(bt)
	bt.global_position = (entry["xf"] as Transform3D).origin
	return bt


## The promoted tree: 3 part meshes seated in the whole tree's object space, a resident
## trunk collider only while this transient lives. break_at() hinges everything above the
## nearest joint away from the blast (FellableTree's scripted hinge, ADR-031: state-swap,
## never RigidBody). With a VegetationManager above it, the settled halves become
## _fell_registry DATA (snag + lying log, bodied on demand by the pooled 70m ring) and
## this node frees itself; on a bare bench the node stays resident as the cover.
class BrokenTree:
	extends Node3D

	const FELL_TIME: float = 2.0
	const FALL_ANG: float = PI * 0.47
	## A log lying in the grass is crouch cover, not a 3m post.
	const LOG_TRUNK_H: float = 0.9

	var species: String = ""
	var source_xf: Transform3D = Transform3D.IDENTITY
	var band: Dictionary = {}
	var layer: Node3D = null
	var vm: Node = null
	var broken: bool = false
	var _mis: Dictionary = {}   ## part suffix -> MeshInstance3D

	func _ready() -> void:
		for suffix: String in ["stump", "stem", "crown"]:
			var m: Mesh = null
			if is_instance_valid(layer) and layer.has_method("solid_mesh_for"):
				m = layer.call("solid_mesh_for", "%s_%s" % [species, suffix]) as Mesh
			if m == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.transform = Transform3D(source_xf.basis, Vector3.ZERO)
			add_child(mi)
			_mis[suffix] = mi

	## height_m is metres above this tree's own base; blast picks the fall direction.
	func break_at(height_m: float, blast: Vector3) -> void:
		if broken:
			return
		broken = true
		var s: float = source_xf.basis.get_scale().y
		var lo: float = float(band["cut_low"]) * s
		var hi: float = float(band["cut_high"]) * s
		var at_high: bool = absf(height_m - hi) < absf(height_m - lo)
		var cut_obj: float = float(band["cut_high"] if at_high else band["cut_low"])
		var cut_w: float = cut_obj * s
		# A ternary over two array literals yields an untyped Array, which cannot be
		# assigned to Array[String] - it throws at runtime, not at parse.
		var standing: Array[String] = ["stump", "stem"]
		var falling: Array[String] = ["crown"]
		if not at_high:
			standing = ["stump"]
			falling = ["stem", "crown"]
		var radius: float = float(band["trunk_r"]) * s

		if radius > 0.0:
			var snag := StaticBody3D.new()
			snag.name = "SnagTrunk"
			snag.collision_layer = 1
			snag.collision_mask = 0
			# Solid trunk stops rounds - timber is hard, like the FSB tagger's timber bunkers.
			snag.add_to_group("hard_surface")
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = radius
			cyl.height = cut_w
			cs.shape = cyl
			cs.position = Vector3(0.0, cut_w * 0.5, 0.0)
			snag.add_child(cs)
			add_child(snag)

		var away: Vector3 = global_position - blast
		away.y = 0.0
		if away.length() < 0.5:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(int(global_position.x), int(global_position.z)))
			var a: float = rng.randf() * TAU
			away = Vector3(cos(a), 0.0, sin(a))
		away = away.normalized()
		var axis: Vector3 = away.cross(Vector3.UP).normalized()
		var up_local: Vector3 = source_xf.basis * Vector3(0.0, cut_obj, 0.0)

		var pivot := Node3D.new()
		pivot.position = up_local
		add_child(pivot)
		for suffix: String in falling:
			if not _mis.has(suffix):
				continue
			var mi: MeshInstance3D = _mis[suffix]
			mi.get_parent().remove_child(mi)
			pivot.add_child(mi)
			mi.transform = Transform3D(source_xf.basis, -up_local)

		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_method(func(ang: float) -> void:
			if is_instance_valid(pivot):
				pivot.basis = Basis(axis, ang),
			0.0, FALL_ANG, FELL_TIME)
		tw.finished.connect(_settle.bind(standing, falling, away, axis, cut_w, radius),
			CONNECT_ONE_SHOT)

	func _settle(standing: Array[String], falling: Array[String], away: Vector3,
			axis: Vector3, cut_w: float, radius: float) -> void:
		if not is_inside_tree():
			return
		var fall_len: float = float(band["top"]) * source_xf.basis.get_scale().y - cut_w
		if vm != null and is_instance_valid(vm):
			var rest: Vector3 = global_position + Vector3(0.0, cut_w, 0.0) \
				+ away * (cut_w * 0.5)
			rest.y = _probe_ground(rest)
			var lying := Transform3D(Basis(axis, FALL_ANG) * source_xf.basis, rest)
			var chunk_size: float = 256.0
			var tm: Variant = vm.get("_terrain_manager")
			if tm != null:
				chunk_size = float((tm as Node).get("chunk_size"))
			var chunk := Vector2i(floori(global_position.x / chunk_size),
				floori(global_position.z / chunk_size))
			var entries: Array = []
			for i in standing.size():
				var e: Dictionary = {"name": "%s_%s" % [species, standing[i]],
					"xf": source_xf, "chunk": chunk}
				if i == 0 and radius > 0.0:
					e["trunk_r"] = radius
					e["trunk_h"] = cut_w
				entries.append(e)
			for i in falling.size():
				var e2: Dictionary = {"name": "%s_%s" % [species, falling[i]],
					"xf": lying, "chunk": chunk}
				if i == 0 and radius > 0.0:
					e2["trunk_r"] = radius
					e2["trunk_h"] = LOG_TRUNK_H
				entries.append(e2)
			vm.call("add_fell_entries", entries)
			vm.call("rebuild_chunk", chunk)
			queue_free()
			return
		# Bench (no VegetationManager): the node IS the permanence. Lay a prone-height
		# capsule under the fallen top so it works as hard cover, like the old felled log.
		if radius > 0.0 and fall_len > 0.5:
			var log_body := StaticBody3D.new()
			log_body.name = "FelledLogTrunk"
			log_body.collision_layer = 1
			log_body.collision_mask = 0
			log_body.add_to_group("hard_surface")
			var cap := CollisionShape3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = maxf(0.35, radius)
			shape.height = fall_len
			cap.shape = shape
			cap.transform = Transform3D(Basis(Quaternion(Vector3.UP, away)),
				away * (fall_len * 0.5) + Vector3(0.0, 0.5, 0.0))
			log_body.add_child(cap)
			add_child(log_body)

	func _probe_ground(p: Vector3) -> float:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 60.0)
		q.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(q)
		return float((hit["position"] as Vector3).y) if hit.has("position") else p.y
