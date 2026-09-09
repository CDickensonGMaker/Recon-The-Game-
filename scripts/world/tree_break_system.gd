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
## Trunks a blast has claimed, each with the wall-clock second it goes over. Scheduled by
## apply_blast, drained by _process. See _fall_delay for why it is a window and not a queue.
var _fall_queue: Array[Dictionary] = []


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
		if not is_breakable(nm):
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


## FILTER EACH TOUCHED CELL ONCE, do not erase entry by entry. Array.erase is a linear scan,
## so unregistering a chunk that has many trees in one cell was quadratic in that cell - and
## every chunk rebuild in a crater or a tree break calls this first. Marking dead and then
## rebuilding each touched cell in one pass is the same answer at O(entries).
func unregister_chunk(layer: Node3D, coord: Vector2i) -> void:
	var key: String = _chunk_key(layer, coord)
	if not _chunks.has(key):
		return
	var touched: Dictionary = {}
	for entry: Dictionary in _chunks[key]:
		entry["dead"] = true
		touched[entry["cell"]] = true
	for cell: Vector2i in touched:
		if not _cells.has(cell):
			continue
		var kept: Array = []
		for e: Dictionary in (_cells[cell] as Array):
			if not bool(e.get("dead", false)):
				kept.append(e)
		if kept.is_empty():
			_cells.erase(cell)
		else:
			_cells[cell] = kept
	_chunks.erase(key)


func unregister_layer(layer: Node3D) -> void:
	var prefix: String = "%d|" % layer.get_instance_id()
	## Both caches are keyed on this layer's instance id and would otherwise outlive it.
	## A scheduled trunk in this layer is left in _fall_queue and skipped on the `dead`
	## test below when its moment comes - a torn-down layer has no scatter to fell into.
	for k: String in _parts_loaded.keys():
		if k.begins_with(prefix):
			_parts_loaded.erase(k)
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
					# Undergrowth is not a fuze. bush_c is 0.93m and banana_a 1.64m across,
					# so without this a rocket detonates in the weeds a metre from the
					# muzzle instead of on the man standing behind them.
					if _is_bush(String(entry["species"])):
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
				## `dead` = already gone. `doomed` = claimed by an earlier canister in this
				## same strip and still standing. Both are skipped so nine canisters
				## 22 m apart cannot fell the same trunk nine times.
				if bool(entry["dead"]) or bool(entry.get("doomed", false)):
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
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for entry: Dictionary in doomed:
		entry["doomed"] = true
		_fall_queue.append({"entry": entry, "blast": center,
			"at": now + _fall_delay(entry, center, radius)})
	return doomed.size()


## WHEN this trunk goes over, in seconds after the canister lands.
##
## HIS RULING 2026-09-09: "why dont we stagger the trees falling for a few seconds after
## the explosions so its not just a all at once thing." It is the art answer and the perf
## answer in one - a treeline that goes down over three seconds is what napalm looks like,
## and the per-chunk scatter regen it drives is spread over ~100 frames instead of landing
## in the one frame the canister lands in.
##
## Shape: the fire takes the middle first and works outward, so delay rises with distance
## from the burst. Undergrowth goes FASTER than timber at the same radius (BUSH_HASTE) -
## the grass catches before the trunk does, which is also what makes the sweep read as
## fire rather than as a queue draining.
##
## DETERMINISM (ADR-010, and replays). The jitter is a hash of the trunk's own quantised
## position, NOT `randf()`. It therefore does not consume the operation's RNG stream, does
## not depend on how many other systems drew from it first, and gives the same tree the
## same fall time on every replay of the same seed.
const FALL_WINDOW_S: float = 3.0    ## edge of the blast falls this long after the centre
const FALL_JITTER_S: float = 0.7    ## deterministic per-trunk scatter on top of that
const BUSH_HASTE: float = 0.45      ## undergrowth burns through in this fraction of the time


func _fall_delay(entry: Dictionary, center: Vector3, radius: float) -> float:
	var o: Vector3 = (entry["xf"] as Transform3D).origin
	var frac: float = clampf(Vector2(o.x - center.x, o.z - center.z).length()
		/ maxf(radius, 0.001), 0.0, 1.0)
	## sqrt, not linear: the near half of a disc holds a quarter of its area, so a linear
	## ramp drops most of the trees in the first third of the window and the tail reads
	## empty. This spreads them evenly over the seconds instead of over the metres.
	var base: float = sqrt(frac) * FALL_WINDOW_S
	if _is_bush(String(entry["species"])):
		base *= BUSH_HASTE
	return base + _jitter01(o) * FALL_JITTER_S


## Stable [0,1) from a position. Quantised to 10 cm so float drift in a transform cannot
## move a tree to a different fall time between runs.
static func _jitter01(p: Vector3) -> float:
	var h: int = hash(Vector2i(roundi(p.x * 10.0), roundi(p.z * 10.0)))
	return float(absi(h) % 10000) / 10000.0


## ---- THE SILENT FALL (his ruling 2026-09-09) ----
##
## "can we just silently have trees fall if the players far away, since it doesnt really
## matter if the player sees that or not. but anything within a 350 sightline or less does
## actually fall over."
##
## 350 m is the canopy draw radius (TreeCoverLayer.view_distance). Past it the standing
## tree is not drawn, so the falling tree is being animated for nobody: three
## MeshInstance3D children, a StaticBody3D snag registered with Jolt and torn out again
## two seconds later, and a Tween ticking every frame - per trunk, and a napalm strip
## claims hundreds.
##
## WHAT IS IDENTICAL EITHER SIDE OF THE LINE, and this is the whole design (the
## coordinator's law: outcome identical, presentation degraded):
##   * WHICH trunks fall - chosen by apply_blast, which never sees the player;
##   * WHEN each one leaves the registry, the scatter and the trunk-collider ring -
##     _fall_delay, which never sees the player;
##   * WHEN the lying log becomes cover - the silent path waits the same
##     BrokenTree.FELL_TIME the animated one spends falling, so the world changes at the
##     same instant on both paths, not two seconds earlier for being unwatched;
##   * WHERE the halves come to rest - _settle derives the resting transform from
##     source_xf, the blast bearing and a ground probe. No physics, no RNG, no camera.
## Only the two seconds of falling timber are skipped.
##
## DISTANCE, NOT LINE OF SIGHT - and I would argue against sight even if it were free.
## True occlusion means a tree behind a ridge 200 m out is "unseen", so it skips its fall,
## and then SNAPS into its fallen state the instant he crests the ridge - a state change
## caused by the camera moving rather than by the world changing, which is a worse
## artefact than the one being fixed and is exactly what the r4bk Law forbids. Plain
## distance can never do that: nothing the player does with his eyes changes a metre.
##
## FEATHERED, so the boundary is not a line he can stand on and watch a batch snap: each
## trunk's own threshold is drawn deterministically from its position across
## [SILENT_FALL_M, SILENT_FALL_M + SILENT_FEATHER_M). Walking the band changes which
## SCATTERED trunks animate, never a whole rank at once.
const SILENT_FALL_M: float = 350.0
const SILENT_FEATHER_M: float = 70.0


func _is_silent_fall(at: Vector3) -> bool:
	var p: Node = GameManager.player
	## No player (a bench, a headless probe, the menu) means nobody to spare the work for
	## AND nobody to see it. Animate: it is the path with the stronger guarantees, and a
	## bench that silently took the cheap road would be measuring the wrong game.
	if not is_instance_valid(p) or not p is Node3D or not (p as Node3D).is_inside_tree():
		return false
	var d: float = Vector2(at.x - (p as Node3D).global_position.x,
		at.z - (p as Node3D).global_position.z).length()
	return d > SILENT_FALL_M + _jitter01(at) * SILENT_FEATHER_M


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


## CLOSED 2026-09-09 - the chunk rebuild IS coalesced now, and this comment used to say the
## opposite. _consume updates the stored scatter immediately and marks the chunk dirty;
## TreeCoverLayer._flush_regen rebuilds ONE chunk per frame (tree_cover_layer.gd:340-352).
## The precondition this block set - "measure the assault frame first; if it is real, batch
## it" - was met: treebreak.consume measured 55.4 ms worst in the 45-man assault and is now
## gone from the report, replaced by veg.regen_flush at 19.6 mean / 24.7 worst.
## Deferring is safe because the felled entry leaves the registry, _chunks and _chunk_scatter
## BEFORE _consume returns, so every other path that rebuilds the chunk in the window already
## reads a scatter it is absent from.
## THE HALF-STATE INVARIANT, and why the consume moved in here from apply_blast.
##
## A trunk waiting its turn in `_fall_queue` is STANDING IN EVERY SYSTEM: it is still in
## `_cells` (so `query_ahead` still fuzes a rocket on it), still in the layer's stored
## scatter (so it still draws), and still inside the trunk-collider ring (so rounds still
## stop on it). It leaves all three in the same call that spawns its BrokenTree. There is
## therefore no instant at which a tree is felled-but-standing or standing-but-shot-through:
## `_consume` and `_spawn_broken` are one atomic pair, they just happen LATER than the
## blast that scheduled them. The only thing `apply_blast` writes early is the `doomed`
## flag, which nothing but the blast selector reads.
func _process(_delta: float) -> void:
	if _fall_queue.is_empty():
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	## Due entries only, oldest-due first, and never more than the per-frame cap. The cap
	## is the floor under a pathological case (a dozen canisters on one grove); the WINDOW
	## is what normally paces this, which is why the drain is authored and not metered.
	var due: Array[Dictionary] = []
	var i: int = 0
	while i < _fall_queue.size() and due.size() < BREAKS_PER_FRAME:
		var job: Dictionary = _fall_queue[i]
		if float(job["at"]) > now:
			i += 1
			continue
		_fall_queue.remove_at(i)
		var entry: Dictionary = job["entry"]
		## A chunk unload or layer teardown can kill an entry while it waits its turn.
		if bool(entry["dead"]):
			continue
		due.append(job)
	if due.is_empty():
		return
	var entries: Array[Dictionary] = []
	for job: Dictionary in due:
		entries.append(job["entry"])
	## Batched: `_consume` groups by chunk, so up to BREAKS_PER_FRAME trunks cost ONE
	## `remove_scatter_entries` scan per touched chunk per frame, not one per trunk.
	StallLedger.begin("treebreak.consume")
	_consume(entries)
	StallLedger.end()
	StallLedger.begin("treebreak.spawn")
	for job: Dictionary in due:
		var entry: Dictionary = job["entry"]
		var bt: BrokenTree = _spawn_broken(entry)
		if bt != null:
			var blast: Vector3 = job["blast"]
			StallLedger.begin("tb.break_at")
			bt.break_at(blast.y - (entry["xf"] as Transform3D).origin.y, blast)
			StallLedger.end()
	StallLedger.end()


## Trunks scheduled to fall but still standing. For the probe: the stagger is real only if
## this is non-empty for frames after the blast.
func pending_falls() -> int:
	return _fall_queue.size()


func _spawn_broken(entry: Dictionary) -> BrokenTree:
	var layer: Node3D = entry["layer"]
	if not is_instance_valid(layer) or not layer.is_inside_tree():
		return null
	var nm: String = entry["species"]
	StallLedger.begin("tb.load_species")
	_ensure_parts_loaded(layer, nm)
	StallLedger.end()
	SpawnLedger.note("tree_break")
	StallLedger.begin("tb.new_broken")
	var bt := BrokenTree.new()
	bt.silent = _is_silent_fall((entry["xf"] as Transform3D).origin)
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
	StallLedger.end()
	return bt


## PER-SPECIES, ONCE, FOR THE LIFE OF THE LAYER - not once per felled tree.
##
## MEASURED DEFECT (his live log, 2026-09-09 night, the ambient napalm at 256,466):
## `_spawn_broken` used to call `layer.load_species([stump, stem, crown])` for EVERY tree
## it promoted. `TreeCoverLayer.load_species` caches the mesh, so the second call onward
## loaded nothing - but it still ran `_report_cover_split`, which builds two sorted
## PackedStringArrays, joins them and `print()`s. A 9-canister napalm strip fells up to
## `MAX_TREES_PER_BLAST + MAX_BUSH_PER_BLAST` = 20 per canister; his log carried 145
## `[TreeCover]` lines in that one event and the [PERF] row beside them read FPS=1.
##
## The dedupe lives HERE, in the caller, and not in `load_species`: the printed cover/
## concealment split is ADR-042 clause 1 reporting that the vegetation layer owes on a
## GENUINE species load, and silencing it there would hide a real "no 3D model" gap.
## What was never owed is re-asking for a species this system already asked for.
##
## Keyed by layer instance id, because `_solid_mesh` is per-TreeCoverLayer: a second layer
## has its own cache and must still be allowed its own first load.
var _parts_loaded: Dictionary = {}   ## "layer_id|species" -> true


func _ensure_parts_loaded(layer: Node3D, nm: String) -> void:
	if not layer.has_method("load_species"):
		return
	var key: String = "%d|%s" % [layer.get_instance_id(), nm]
	if _parts_loaded.has(key):
		return
	_parts_loaded[key] = true
	layer.call("load_species", [nm + "_stump", nm + "_stem", nm + "_crown"] as Array[String])


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
	## Set by _spawn_broken from TreeBreakSystem._is_silent_fall. True = this trunk is
	## beyond the canopy draw radius, so it skips the two seconds of visible timber and
	## nothing else. See the SILENT FALL block above for what stays identical.
	var silent: bool = false
	var _mis: Dictionary = {}   ## part suffix -> MeshInstance3D
	## The standing stump's collider, kept so the ground probe can exclude it.
	var _snag: StaticBody3D = null

	func _ready() -> void:
		## Nothing draws these past the canopy radius, and _settle re-registers the parts
		## as scatter entries anyway - the MeshInstance3Ds only ever existed to carry the
		## fall. Skipping them also skips three solid_mesh_for lookups per trunk.
		if silent:
			return
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

		var away0: Vector3 = global_position - blast
		away0.y = 0.0
		if away0.length() < 0.5:
			var rng0 := RandomNumberGenerator.new()
			rng0.seed = hash(Vector2i(int(global_position.x), int(global_position.z)))
			var a0: float = rng0.randf() * TAU
			away0 = Vector3(cos(a0), 0.0, sin(a0))
		away0 = away0.normalized()
		var axis0: Vector3 = away0.cross(Vector3.UP).normalized()

		## SILENT PATH. No snag body, no pivot, no mesh instances, no tween - but the SAME
		## `away`/`axis`/`cut_w`/`radius` the animated path computed above, handed to the
		## SAME _settle, at the SAME FELL_TIME. The resulting fell entries are therefore
		## identical to the metre; only the falling is skipped.
		if silent:
			get_tree().create_timer(FELL_TIME).timeout.connect(
				_settle.bind(standing, falling, away0, axis0, cut_w, radius),
				CONNECT_ONE_SHOT)
			return

		if radius > 0.0:
			var snag := StaticBody3D.new()
			_snag = snag
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

		## The SAME two vectors the silent branch above already passed to _settle. Computed
		## once and shared on purpose: two copies of this derivation is exactly how the
		## near and far paths would drift apart and start resting logs in different
		## places depending on where the player stood.
		var away: Vector3 = away0
		var axis: Vector3 = axis0
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

	## MEASURED DEFECT, found by tests/probe_napalm_stall.tscn's near/far equivalence check
	## 2026-09-09: this ray is cast from a point `away * cut_w * 0.5` from the trunk base,
	## which on a wide stump is still INSIDE the snag's own cylinder - so the log settled on
	## top of the stump it had just broken off, 1.601 m above the ground, and only on the
	## animated path (the silent path has no snag to hit). It was never a distance bug; the
	## silent path was right and the animated one had been laying logs in the air.
	func _probe_ground(p: Vector3) -> float:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 60.0)
		q.collision_mask = 1
		if _snag != null and is_instance_valid(_snag):
			q.exclude = [_snag.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		return float((hit["position"] as Vector3).y) if hit.has("position") else p.y
