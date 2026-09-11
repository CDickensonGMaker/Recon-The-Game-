class_name TreeCoverLayer
extends Node3D

## Individual-species vegetation instancing + trunk collision for the live AO.
##
## THE CANOPY IS REAL 3D AT EVERY DISTANCE (Summoner, 2026-09-08: "no more 2d terrain
## cards, or 3d plane spliced cards or whatever. all 3d blender models only in game",
## sharpened to "i do not want the old 2d made 3d terrain art pieces"). Barbwire is the
## single exemption and it does not live here. ADR-001 Amendment A revoked the sprite
## carve-out; ADR-026 Amendment D killed the canopy card atlas.
##
## WHAT THIS USED TO DO, and why it is gone: 0-65 m drew the real species GLB, 65-350 m
## swapped it for a 4-triangle impostor CARD out of assets/world/vegetation/cards/. That
## boundary was a HARD SNAP (see _multimesh) and it changed DIMENSION - a solid plant
## became a flat picture in one frame. That is the popping Caleb reported. There is now
## ONE MultiMeshInstance3D per (species x 64 m bucket) drawing the real model from 0 to
## view_distance, so there is no 65 m boundary left to pop across, and HALF the canopy
## nodes and draw calls of the old two-ring build.
##
## THE FAR RING IS NOT FULL DETAIL. Every vegetation GLB imports with
## meshes/generate_lods=true, so each ArrayMesh carries an import-generated LOD ladder and
## the renderer picks a level by screen coverage (measured 2026-09-09 by
## tools/probe_far_ring_meshes.gd: broadleaf_a 752 tris -> 12, bamboo_a 830 -> 86). Two
## live species, rice_a and elephant_grass_b, generated NO ladder and draw full detail at
## every range - they are 84 and 160 tris, which is why that is tolerated and recorded
## rather than papered over.
##
## NO QUAD MAY COME BACK AS AN OPTIMISATION. If a distance cannot afford these meshes the
## answer is a lower-poly real MESH.
##
## project.godot:331 `mesh_lod/lod_change/threshold_pixels=2.0` is now LOAD-BEARING for the
## whole canopy, where before it only touched the 0-65 m band. Godot's default is 1.0; 2.0
## swaps a level at twice the screen error, which is the aggressive end and the first place
## to look if the far ring is seen changing shape. Lowering it trades frames for smoothness
## and is the Summoner's call, not a silent tweak.
##
## Trunk COLLISION comes from a player-keyed pooled body ring (RING_RADIUS) so the player
## can physically hide behind cover (Pillar 3) without the AO holding thousands of
## resident StaticBody3D.

const SOLID_DIR := "res://assets/world/vegetation/"

## Cover-givers ONLY: a solid a bullet stops and a body hides behind. Value = trunk
## collider radius (m). Everything NOT listed (grass, fern, vine, moss, rice, bush,
## sapling, liana) is CONCEALMENT - it cuts sight via the veg grid, never a collider.
const COVER_TRUNK := {
	"broadleaf_a": 0.30, "broadleaf_b": 0.30, "broadleaf_c": 0.30,
	"banana_a": 0.26, "banana_b": 0.26,
	"bamboo_a": 0.34, "bamboo_b": 0.34, "bamboo_c": 0.34,
	"jungle_palm_a1": 0.30, "jungle_palm_a2": 0.30, "jungle_palm_a3": 0.30,
	"jungle_palm_b1": 0.30, "jungle_palm_b2": 0.30, "jungle_palm_b3": 0.30,
	"fallen_log_a": 0.45, "fallen_log_b": 0.45, "tree_stump": 0.34,
}

## World-geometry layer: bullets and the player capsule test this, so a trunk stops both.
const COVER_COLLISION_LAYER: int = 1
const TRUNK_HEIGHT: float = 3.0

## Collision ring (Caleb's ruling 2026-07-25): "the physics should only apply to trees
## within a 70m radius of the player." Solid render ring is 65m, so collision always
## covers what looks solid.
const RING_RADIUS := 70.0
## Measured worst 70m-ring demand (seed 47225, whole AO, mission density boost applied):
## 919 candidates. 1280 = ~40% headroom.
const POOL_MAX: int = 1280
## Trunk index cell for the ring walk (see generate_for_chunk). 32 m against a 70 m ring means
## a walk touches ~25 cells instead of a chunk's every trunk.
const TRUNK_CELL_M: float = 32.0
const RING_INTERVAL: float = 0.25
const RING_MOVE_EPS: float = 2.0
const PARK_POS := Vector3(0.0, -4000.0, 0.0)

## No longer a RENDER boundary - kept as the documented radius the trunk-collider ring
## must cover. RING_RADIUS (70 m) still exceeds it, so anything close enough to hide
## behind is bodied.
@export var near_distance: float = 65.0
@export var view_distance: float = 350.0  ## whole canopy ring (fog transmittance <=10%)

## GROUND COVER draws to here instead of view_distance. Grass tufts, rice and ferns are
## 0.5-1.5 m tall, so past ~150 m they are a pixel of noise costing a real mesh each - and the
## conversion to real meshes (his ruling, no cards) is what made that expensive. The number is
## NOT taste: it sits just outside the AI's open-ground sight cap (SIGHT_CAP_OPEN 140 m), so
## every metre of ground anyone can see you across, or shoot you across, still has its cover
## drawn. Shortening it further would start deciding fights.
##
## Canopy species (trees, bamboo, palms, banana, bushes, vines) are untouched at 350 m.
const SMALL_RING_M: float = 150.0
const SMALL_PREFIXES: Array[String] = ["rice_", "tall_grass_", "elephant_grass_", "fern_"]
## 0 disables the short ring entirely, for the A/B. Set by --small-ring=<m>.
var small_ring: float = SMALL_RING_M

## BUSHES DRAW TO 350 m AND STAY THERE (his ruling, 2026-09-09: "bushes keep drawing to 350,
## dont cut em"). The question was whether the 10,938 bush instances belonged on the ground-cover
## ring with the grass; they do not, and it is settled. This stays a KEY, not a decision: the
## dial is here so he can look again on his own eyes, and the shipped default is UNCUT.
const BUSH_PREFIXES: Array[String] = ["bush_"]
const BUSH_RING_M: float = 0.0   ## 0 = uncut; bushes draw with the trees
var bush_ring: float = BUSH_RING_M

## visibility_range is per-NODE against the transformed AABB (godot#79471 - the
## docs say origin and are wrong). Chunk-sized nodes quantize both rings by
## +/-181m - that WAS the invisible-jungle bug. 64m buckets bound the error to
## +/-45m without exploding the node count.
const BUCKET: float = 64.0
## THE CANOPY GETS A BIGGER BUCKET, and the audit that decided it is
## production/PERF_AUDIT_2026-09-10.md section 3.3. The demo world held 3,631
## MultiMeshInstance3D nodes averaging 7.8 instances each - 27 species x 64 m cells - and
## that is where the 1,200-2,400 draw calls came from: a node per species per cell, every one
## culled and submitted on its own. MultiMesh exists to make thousands of instances ONE draw.
##
## The 64 m cell was chosen for visibility_range, which culls against a node's whole AABB
## (godot#79471): small cells cull tight. That still matters for the GROUND COVER, whose
## 150 m ring is short enough that a 256 m node would draw grass a whole cell past it. It
## does NOT matter for the canopy, which draws to 350 m into fog - a 128 m cell whose near
## edge is inside the ring draws at most ~128 m of extra depth that is already fogged out.
## Canopy species (trees, bamboo, palms, banana, bushes, vines) take this bucket; the
## SMALL_PREFIXES keep 64 m. Four cells become one for 12 of the 27 species.
const CANOPY_BUCKET: float = 128.0
const RANGE_MARGIN: float = 8.0   ## hysteresis on the hard PS2 snap

var _solid_mesh: Dictionary = {}   ## name -> Mesh (the real model; there is no second tier)
var _chunk_nodes: Dictionary = {}  ## coord -> Array[Node] (MMIs)
## coord -> { [species, cx, cz] -> {"node": MultiMeshInstance3D, "origin": Vector3} }. The
## bucket a felled tree came out of is rebuilt alone (remove_scatter_entries); nothing else in
## the chunk is touched.
var _chunk_buckets: Dictionary = {}
## coord -> Dictionary(scatter idx -> trunk idx), so a felled entry can retire its own trunk
## without rebuilding the chunk's trunk arrays.
var _chunk_trunk_of: Dictionary = {}
## coord -> the vegetation manager's 32 m cell index over the SAME scatter array this layer
## holds (indices -> entries). The manager keeps it in step when it appends a settled log.
## With it, a local update reads the cells a rect touches instead of the whole chunk.
var _chunk_cells: Dictionary = {}
## coord -> how many entries of the shared array this layer has already taken in. Anything
## appended past it is a newcomer (a settled log's snag or lying trunk).
var _chunk_known: Dictionary = {}
## Cell size of that index - must match VegetationManager.CACHE_CELL_M.
const CACHE_CELL_M: float = 32.0
var _chunk_scatter: Dictionary = {}  ## coord -> Array (the scatter as built, for single-instance removal)
## coord -> PackedVector3Array of placed WORLD origins (probe truth; MultiMesh
## transform read-back is blind headless in this build)
var chunk_origins: Dictionary = {}

## coord -> {positions: PackedVector3Array, radii: PackedFloat32Array, bounds: Rect2 (XZ)}
## for COVER_TRUNK instances - pure candidate data, bodied only inside the ring.
var _chunk_trunks: Dictionary = {}
## Last update's placement count, for the probe/ledger reader.
var _ring_stat_wanted: int = 0
var _chunk_bodies: Dictionary = {}         ## coord -> Dictionary(candidate idx -> StaticBody3D)
var _pool: Array[StaticBody3D] = []
var _free_bodies: Array[StaticBody3D] = []
var _shape_by_radius: Dictionary = {}      ## radius -> shared CylinderShape3D
## Vector3.INF = unset -> ring keys off GameManager.player; no player = no bodies.
var ring_center_override := Vector3.INF
var _last_center := Vector3.INF
var _ring_elapsed: float = 0.0
var _ring_dirty: bool = false
var _pool_starved: bool = false


## THREAT ZONES (decree 2026-08-04: "anything with explosives / heavy ordnance is
## being called out to the tree"). Ordnance promotes trunk colliders wherever it
## flies, so a contact fuze has something to strike beyond the player ring. A zone
## is just another reason a candidate is wanted - same pool, same park path, so
## expiry parks bodies through the existing delta pass and nothing can leak.
const ZONE_MAX: int = 16
const ZONE_DEDUPE_M: float = 4.0
var _zones: Array[Dictionary] = []   ## {a: Vector3, b: Vector3, r: float, until_ms: int}


static func threat_zone(tree: SceneTree, center: Vector3, radius: float, duration_s: float) -> void:
	threat_corridor(tree, center, center, radius, duration_s)


static func threat_corridor(tree: SceneTree, from: Vector3, to: Vector3,
		half_width: float, duration_s: float) -> void:
	if tree == null:
		return
	for layer in tree.get_nodes_in_group("tree_cover"):
		(layer as TreeCoverLayer)._add_zone(from, to, half_width, duration_s)


func _add_zone(a: Vector3, b: Vector3, r: float, duration_s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(duration_s * 1000.0)
	for z: Dictionary in _zones:
		if (z["a"] as Vector3).distance_to(a) < ZONE_DEDUPE_M \
				and (z["b"] as Vector3).distance_to(b) < ZONE_DEDUPE_M:
			z["until_ms"] = maxi(int(z["until_ms"]), until)
			z["r"] = maxf(float(z["r"]), r)
			return
	if _zones.size() >= ZONE_MAX:
		# Evict the soonest-to-expire, never the oldest-added: shell-corridor churn
		# must not knock a live dispatch footprint out mid-barrage.
		var evict: int = 0
		for i in range(1, _zones.size()):
			if int(_zones[i]["until_ms"]) < int(_zones[evict]["until_ms"]):
				evict = i
		_zones.remove_at(evict)
	_zones.append({"a": a, "b": b, "r": r, "until_ms": until})
	# COALESCED, not immediate. bullet_system files a shooter zone on EVERY shot; with 45 men
	# firing, an immediate full ring update per new zone was ~3 scans a second on top of the
	# interval (430 scans in a 150 s siege, 3.2 ms each - the whole veg.trunk_ring cost). The
	# next physics tick picks the flag up, which is inside the flight time of any round.
	_ring_dirty = true


func _prune_zones() -> void:
	var now: int = Time.get_ticks_msec()
	var i: int = _zones.size() - 1
	while i >= 0:
		if int(_zones[i]["until_ms"]) <= now:
			_zones.remove_at(i)
		i -= 1


## XZ distance from p to the zone's segment <= its radius.
func _zone_wants(p: Vector3) -> bool:
	var p2 := Vector2(p.x, p.z)
	for z: Dictionary in _zones:
		var a2 := Vector2((z["a"] as Vector3).x, (z["a"] as Vector3).z)
		var b2 := Vector2((z["b"] as Vector3).x, (z["b"] as Vector3).z)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p2, a2, b2)
		if p2.distance_to(closest) <= float(z["r"]):
			return true
	return false


func _zone_overlaps(bounds: Rect2) -> bool:
	for z: Dictionary in _zones:
		var a2 := Vector2((z["a"] as Vector3).x, (z["a"] as Vector3).z)
		var b2 := Vector2((z["b"] as Vector3).x, (z["b"] as Vector3).z)
		var grown: Rect2 = bounds.grow(float(z["r"]))
		if grown.has_point(a2) or grown.has_point(b2) \
				or grown.intersects(Rect2(a2, Vector2.ZERO).expand(b2)):
			return true
	return false


## HIS DIALS, live, mid-walk. The bench that would have decided these runs a fixed camera on
## quiet terrain, which is a scene nobody plays; his own law is that his eyes decide.
##
## F9 IS NOT FREE, and the note that used to sit here saying "F9 and F10 are unbound anywhere
## else in the project" was wrong when it was written. `quickload` is bound to F9 in
## project.godot (physical_keycode 4194340) and SaveManager acts on it
## (scripts/autoload/save_manager.gd:74) - so cycling the ground-cover ring mid-walk could also
## reload his quicksave. The dial keys now mark the event handled, and because the world scene
## takes _unhandled_input before an autoload does, SaveManager never sees the press. Which key
## should keep F9 permanently is his call, not a silent rebind of his save keys.
##
## F12 is the bush ring. F11 is interior props (scripts/world/interior_prop_dial.gd:14); F1-F5
## and F9 are the only other F-keys the input map binds, and F12 is bound by nothing.
const RING_STEPS: Array[float] = [150.0, 100.0, 250.0, 0.0]
const LOD_STEPS: Array[float] = [2.0, 1.0, 4.0]
## 0 = uncut, and it is FIRST because uncut is what ships (his ruling). The rest are there so
## he can see the price with his own eyes without a rebuild.
const BUSH_STEPS: Array[float] = [0.0, 250.0, 200.0, 150.0]
var _ring_step: int = 0
var _lod_step: int = 0
var _bush_step: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_F9:
		_ring_step = (_ring_step + 1) % RING_STEPS.size()
		small_ring = RING_STEPS[_ring_step]
		apply_rings()
		_say("GROUND COVER (grass/rice/fern) draws to %s   [F9]"
			% ("%.0f m" % small_ring if small_ring > 0.0 else "%.0f m - same as the trees" % view_distance))
		get_viewport().set_input_as_handled()   # F9 is also `quickload` - do not reload his save
	elif k.keycode == KEY_F10:
		_lod_step = (_lod_step + 1) % LOD_STEPS.size()
		get_viewport().mesh_lod_threshold = LOD_STEPS[_lod_step]
		_say("MESH LOD swaps at %.0f px   %s   [F10]" % [LOD_STEPS[_lod_step],
			"(smoother, costs frames)" if LOD_STEPS[_lod_step] < 2.0
			else ("(shipped)" if LOD_STEPS[_lod_step] == 2.0 else "(coarser, cheaper)")])
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_F12:
		_bush_step = (_bush_step + 1) % BUSH_STEPS.size()
		bush_ring = BUSH_STEPS[_bush_step]
		apply_rings()
		_say("BUSHES draw to %s   [F12]"
			% ("%.0f m - SHIPPED, uncut" % view_distance if bush_ring <= 0.0
				else "%.0f m (trees still %.0f)" % [bush_ring, view_distance]))
		get_viewport().set_input_as_handled()


## Console AND screen: he is playing, not reading a terminal.
func _say(msg: String) -> void:
	print("[LOOK] %s" % msg)
	var hud: Node = get_tree().get_first_node_in_group("mission_hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", msg)


## Push the current ring radii onto the nodes that are already drawn.
func apply_rings() -> void:
	for coord: Vector2i in _chunk_nodes:
		for n in (_chunk_nodes[coord] as Array):
			var mmi := n as MultiMeshInstance3D
			if mmi != null and is_instance_valid(mmi):
				mmi.visibility_range_end = _ring_for(String(mmi.get_meta("species", "")))


## Debug builds only, like every other dev lens (game_flow.gd:61). Ungated until
## 2026-09-09 this printed a toast of perf dials into a SHIPPING player's face four
## seconds into the arc, and left F9/F10/F12 live for him to press.
func _announce_keys() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().create_timer(4.0).timeout
	_say("F9 ground-cover draw distance  |  F10 mesh LOD sharpness  |  F12 bush draw distance")


func _ready() -> void:
	add_to_group("tree_cover")
	_ring_step = RING_STEPS.find(small_ring)
	if _ring_step < 0:
		_ring_step = 0
	_bush_step = BUSH_STEPS.find(bush_ring)
	if _bush_step < 0:
		_bush_step = 0
	_announce_keys()
	for a: String in OS.get_cmdline_user_args():
		# --card-dist= is kept as the spelling the bench scripts already pass; what it
		# moves is the canopy draw radius, and there are no cards left behind it.
		if a.begins_with("--card-dist=") or a.begins_with("--canopy-dist="):
			view_distance = maxf(near_distance, float(a.split("=")[1]))
			print("[TreeCover] canopy draw radius lever: view_distance=%.0f" % view_distance)
		if a.begins_with("--small-ring="):
			small_ring = float(a.split("=")[1])
			print("[TreeCover] ground-cover ring lever: small_ring=%.0f" % small_ring)
		if a.begins_with("--bush-ring="):
			bush_ring = float(a.split("=")[1])
			print("[TreeCover] bush ring lever: bush_ring=%.0f" % bush_ring)


## Load the real model for each species name (idempotent). A species with no GLB is not
## drawn at all - it is never substituted with a plane, and the gap is named out loud.
func load_species(names: Array) -> void:
	for n: String in names:
		if not _solid_mesh.has(n):
			var sm: Mesh = _extract_mesh(SOLID_DIR + n + ".glb")
			if sm != null:
				_solid_mesh[n] = sm
			else:
				push_warning("[TreeCover] no 3D model for species '%s' - NOT DRAWN" % n)
	_report_cover_split(names)


## ADR-042 clause 1. COVER_TRUNK is a hand-maintained allow-list keyed on species NAME, and
## a name it has never heard of gets no collider at all - the player walks through the tree.
## The default here is the SAFE one (concealment, not bulletproof), so this reports rather
## than warns; what it must never do is stay silent about which half a species landed in.
func _report_cover_split(names: Array) -> void:
	var cover: PackedStringArray = PackedStringArray()
	var conceal: PackedStringArray = PackedStringArray()
	for n: String in names:
		if float(COVER_TRUNK.get(n, 0.0)) > 0.0:
			cover.append(n)
		else:
			conceal.append(n)
	cover.sort()
	conceal.sort()
	print("[TreeCover] %d species give COVER (trunk collider): %s | %d give CONCEALMENT only: %s"
		% [cover.size(), ", ".join(cover), conceal.size(), ", ".join(conceal)])


## How far this species draws. Ground cover stops at small_ring, bushes at bush_ring when he
## has dialled one in, everything else is canopy out to view_distance.
## The bucket a plant of species `nm` at `origin` draws from: [species, cell x, cell z].
func _bucket_key(nm: String, origin: Vector3) -> Array:
	var cell: float = _bucket_for(nm)
	return [nm, int(floor(origin.x / cell)), int(floor(origin.z / cell))]


## Cell size for a species' MultiMesh buckets - see CANOPY_BUCKET.
func _bucket_for(nm: String) -> float:
	for pre in SMALL_PREFIXES:
		if nm.begins_with(pre):
			return BUCKET
	return CANOPY_BUCKET


func _ring_for(nm: String) -> float:
	if bush_ring > 0.0 and bush_ring < view_distance:
		for b: String in BUSH_PREFIXES:
			if nm.begins_with(b):
				return bush_ring
	if small_ring <= 0.0 or small_ring >= view_distance:
		return view_distance
	for p: String in SMALL_PREFIXES:
		if nm.begins_with(p):
			return small_ring
	return view_distance


## The near-solid mesh for a species, for a one-off visual (the felling swap).
func solid_mesh_for(species: String) -> Mesh:
	return _solid_mesh.get(species) as Mesh


## scatter: Array of {name: String, xf: Transform3D}. Builds, for this chunk:
##   - ONE MultiMesh per (species, 64 m bucket) drawing the real model 0..view_distance
##   - trunk collider CANDIDATES per COVER instance (bodied by the ring, not here)
func generate_for_chunk(coord: Vector2i, scatter: Array, cache_cells: Dictionary = {}) -> void:
	StallLedger.begin("mmi.clear")
	clear_chunk(coord)
	StallLedger.end()
	_chunk_scatter[coord] = scatter
	_chunk_cells[coord] = cache_cells
	_chunk_known[coord] = scatter.size()
	StallLedger.begin("mmi.register")
	TreeBreakSystem.register_chunk(self, coord, scatter)
	StallLedger.end()
	StallLedger.begin("mmi.group")
	var groups: Dictionary = {}   ## [name, bucket_x, bucket_z] -> Array[Transform3D]
	var origins := PackedVector3Array()
	var trunk_pos := PackedVector3Array()
	var trunk_rad := PackedFloat32Array()
	var trunk_hgt := PackedFloat32Array()
	var trunk_of: Dictionary = {}
	for si: int in scatter.size():
		var e: Dictionary = scatter[si]
		# A felled entry stays in the array at its index (stable identity for TreeBreakSystem's
		# idx and for _chunk_trunk_of) and is simply not drawn.
		if bool(e.get("dead", false)):
			continue
		var nm: String = String(e.get("name", ""))
		if not _solid_mesh.has(nm):
			continue
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		var key: Array = _bucket_key(nm, xf.origin)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
		e["drawn"] = true
		origins.append(xf.origin)
		# Collider per ENTRY, not per species: a blast-shortened snag and a lying log are
		# the same species as the tree they came from and must not inherit its full post.
		# trunk_r/trunk_h ride on the scatter entry; a plain plant falls back to the table.
		var r: float = float(e.get("trunk_r", COVER_TRUNK.get(nm, 0.0)))
		if r > 0.0:
			trunk_of[si] = trunk_pos.size()
			trunk_pos.append(xf.origin)
			trunk_rad.append(r)
			trunk_hgt.append(float(e.get("trunk_h", TRUNK_HEIGHT)))

	StallLedger.end()
	StallLedger.begin("mmi.build")
	var nodes: Array[Node] = []
	var buckets: Dictionary = {}
	for key: Array in groups:
		var nm: String = key[0]
		var xforms: Array = groups[key]
		# Bucket node origin = member centroid, so the node's transformed AABB
		# (what visibility_range actually measures) hugs the real instances.
		var centroid := Vector3.ZERO
		for xf: Transform3D in xforms:
			centroid += xf.origin
		centroid /= float(xforms.size())
		var local: Array = []
		for xf: Transform3D in xforms:
			local.append(Transform3D(xf.basis, xf.origin - centroid))
		# The real model, all the way out. One node, one mesh, no boundary to pop across.
		var mmi_node: MultiMeshInstance3D = _multimesh(
			_solid_mesh[nm], local, 0.0, _ring_for(nm), centroid)
		# The species is what decides this node's draw radius, and a node name cannot carry it
		# (Godot uniquifies duplicates). The live toggle re-reads it.
		mmi_node.set_meta("species", nm)
		nodes.append(mmi_node)
		buckets[key] = {"node": mmi_node, "origin": centroid}
	StallLedger.end()
	StallLedger.begin("mmi.addchild")
	for node: Node in nodes:
		add_child(node)
	StallLedger.end()
	_chunk_nodes[coord] = nodes
	_chunk_buckets[coord] = buckets
	_chunk_trunk_of[coord] = trunk_of
	chunk_origins[coord] = origins
	if trunk_pos.size() > 0:
		var bounds := Rect2(Vector2(trunk_pos[0].x, trunk_pos[0].z), Vector2.ZERO)
		for p: Vector3 in trunk_pos:
			bounds = bounds.expand(Vector2(p.x, p.z))
		# CELL INDEX for the ring walk. _update_ring used to test every trunk in every near
		# chunk against the player on every update - thousands of distance checks each
		# quarter second, 5 ms mean and 18 ms worst in the siege ledger (veg.trunk_ring,
		# 1.5 s over one run). Bucketed by TRUNK_CELL_M the walk touches only the cells the
		# ring actually covers.
		# Built as plain Arrays and packed at the end: a PackedInt32Array is a VALUE in
		# GDScript, so `(cells[ck] as PackedInt32Array).append(i)` appends to a copy and the
		# dictionary keeps an empty one - which is exactly how the first version of this
		# index placed zero cover bodies and three tree-cover tests went red.
		var lists: Dictionary = {}
		for i: int in trunk_pos.size():
			var ck := Vector2i(int(floor(trunk_pos[i].x / TRUNK_CELL_M)),
				int(floor(trunk_pos[i].z / TRUNK_CELL_M)))
			if not lists.has(ck):
				lists[ck] = []
			(lists[ck] as Array).append(i)
		var cells: Dictionary = {}
		for ck_any in lists.keys():
			cells[ck_any] = PackedInt32Array(lists[ck_any] as Array)
		_chunk_trunks[coord] = {"positions": trunk_pos, "radii": trunk_rad,
			"heights": trunk_hgt, "bounds": bounds, "cells": cells}
	# Same-frame refresh so a blast rebuild never leaves in-ring trunks bodiless.
	StallLedger.begin("mmi.ring")
	_update_ring(_resolve_center())
	StallLedger.end()


func clear_chunk(coord: Vector2i) -> void:
	chunk_origins.erase(coord)
	_chunk_trunks.erase(coord)
	_chunk_buckets.erase(coord)
	_chunk_trunk_of.erase(coord)
	_chunk_cells.erase(coord)
	_chunk_known.erase(coord)
	_chunk_scatter.erase(coord)
	TreeBreakSystem.unregister_chunk(self, coord)
	_release_chunk(coord)
	if not _chunk_nodes.has(coord):
		return
	for node: Node in _chunk_nodes[coord]:
		if is_instance_valid(node):
			node.queue_free()
	_chunk_nodes.erase(coord)


func clear_all() -> void:
	for coord: Vector2i in _chunk_nodes.keys():
		clear_chunk(coord)


func _exit_tree() -> void:
	TreeBreakSystem.unregister_layer(self)


## A FELLED TREE COSTS ITS OWN BUCKET, NOT ITS CHUNK (perf audit 2026-09-10, item 3 of the
## plan: "make vegetation/destruction updates local and bounded").
##
## This used to compact the chunk's scatter and mark it dirty, and the flush rebuilt the WHOLE
## chunk: every bucket freed and re-instanced, the trunk arrays re-derived, TreeBreakSystem
## re-registered - mmi.group + mmi.register + mmi.ring + mmi.build, ~40 ms in one frame for one
## tree, ~65 times across the siege. Now the entry is marked dead IN PLACE (its index stays
## valid for the break registry's `idx` and for _chunk_trunk_of), its trunk is retired by
## zeroing its radius, and only the MultiMesh bucket it drew from is rebuilt from the bucket's
## survivors - one buffer write. Nothing else in the chunk is touched. The vegetation manager
## already files a break hole for the same tree, so a later FULL rebuild of the chunk from its
## cache omits it there too.
##
## chunk_origins is left as built: it is probe truth for placed origins, not a live list.
func remove_scatter_entries(coord: Vector2i, indices: Array) -> void:
	if not _chunk_scatter.has(coord):
		return
	StallLedger.begin("veg.partial_regen")
	var scatter: Array = _chunk_scatter[coord]
	var trunk_of: Dictionary = _chunk_trunk_of.get(coord, {})
	var trunks: Dictionary = _chunk_trunks.get(coord, {})
	var assigned: Dictionary = _chunk_bodies.get(coord, {})
	var keys: Dictionary = {}
	for i_any in indices:
		var i: int = int(i_any)
		if i < 0 or i >= scatter.size():
			continue
		var e: Dictionary = scatter[i]
		if bool(e.get("dead", false)):
			continue
		e["dead"] = true
		var nm: String = String(e.get("name", ""))
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		keys[_bucket_key(nm, xf.origin)] = true
		if trunk_of.has(i) and not trunks.is_empty():
			var t: int = int(trunk_of[i])
			# Read out, write, store back: a PackedFloat32Array is a VALUE, so indexing through
			# `as` would retire a copy and leave the real radius standing (the exact slip that
			# emptied the trunk index earlier today).
			var radii: PackedFloat32Array = trunks["radii"]
			radii[t] = 0.0   # retired: the ring skips r <= 0
			trunks["radii"] = radii
			if assigned.has(t):
				_park_body(assigned[t])
				assigned.erase(t)
	_rebuild_buckets(coord, keys)
	StallLedger.end()


## True when this layer draws `coord` and holds its scatter - the precondition for a local
## update instead of a rebuild.
func has_chunk(coord: Vector2i) -> bool:
	return _chunk_nodes.has(coord) and _chunk_scatter.has(coord) and _chunk_buckets.has(coord)


## THE LOCAL REDRAW (perf audit 2026-09-10, plan item 3). `scatter_new` is the vegetation
## manager's current list for this chunk: the same plant dictionaries the layer drew (they
## carry a `uid`), re-seated on the current heightmap, minus whatever a hole took, plus any
## log that settled. `rect` is the ground that moved. Three diffs, each touching only the
## MultiMesh bucket(s) involved:
##   ADDED   - in the new list, not in ours: appended to our stored scatter at the END (every
##             existing index stays valid for the break registry), given a trunk if it has one,
##             registered with TreeBreakSystem, its bucket rebuilt or created.
##   REMOVED - in ours, live, not in the new list: marked dead in place, trunk retired, body
##             parked, unregistered, bucket rebuilt.
##   MOVED   - live and standing inside `rect`: bucket rebuilt at the new Y, trunk re-seated,
##             body parked so the ring re-places it on the new ground.
## Nothing else in the chunk is freed, instanced, re-registered or re-derived.
func update_chunk(coord: Vector2i, scatter_new: Array, rect: Rect2, cache_cells: Dictionary = {}) -> void:
	if not has_chunk(coord):
		generate_for_chunk(coord, scatter_new, cache_cells)
		return
	StallLedger.begin("veg.partial_update")
	var old: Array = _chunk_scatter[coord]
	if not cache_cells.is_empty():
		_chunk_cells[coord] = cache_cells
	var index: Dictionary = _chunk_cells.get(coord, {})
	if not is_same(scatter_new, old) or index.is_empty():
		_update_chunk_full(coord, scatter_new, rect)
		StallLedger.end()
		return
	# THE FAST SHAPE (2026-09-11): the manager and this layer hold the SAME array now (the
	# prune marks dead in place, a settled log appends), so nothing has to be diffed by uid.
	# Newcomers are the tail past _chunk_known; removals are dead-since-drawn entries in the
	# cells the blast could reach; moved plants are the live ones in the edited rect. Nothing
	# outside those cells is read. The first version of this walked the chunk twice per
	# update - 9,700 entries each - for a 20 m hole: veg.partial_update 970 ms over a siege.
	var trunks: Dictionary = _chunk_trunks.get(coord, {})
	var trunk_of: Dictionary = _chunk_trunk_of.get(coord, {})
	if not _chunk_trunk_of.has(coord):
		_chunk_trunk_of[coord] = trunk_of
	var assigned: Dictionary = _chunk_bodies.get(coord, {})
	var keys: Dictionary = {}
	# ADDED - the tail.
	var known: int = int(_chunk_known.get(coord, old.size()))
	var added_pairs: Array = []
	for idx in range(known, old.size()):
		var e: Dictionary = old[idx]
		if bool(e.get("dead", false)):
			continue
		var nm: String = String(e.get("name", ""))
		if not _solid_mesh.has(nm):
			continue
		added_pairs.append([idx, e])
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		keys[_bucket_key(nm, xf.origin)] = true
		var r: float = float(e.get("trunk_r", COVER_TRUNK.get(nm, 0.0)))
		if r > 0.0:
			trunks = _add_trunk(coord, trunks, xf.origin, r, float(e.get("trunk_h", TRUNK_HEIGHT)))
			trunk_of[idx] = (trunks["positions"] as PackedVector3Array).size() - 1
	_chunk_known[coord] = old.size()
	# REMOVED and MOVED - the cells the rect (grown for the footprint's feather) can reach.
	var reach: Rect2 = rect.grow(10.0)
	var moved_in: Rect2 = rect.grow(2.0)
	var removed_idx: Array = []
	var c0 := Vector2i(floori(reach.position.x / CACHE_CELL_M), floori(reach.position.y / CACHE_CELL_M))
	var c1 := Vector2i(floori(reach.end.x / CACHE_CELL_M), floori(reach.end.y / CACHE_CELL_M))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var ck := Vector2i(cx, cz)
			if not index.has(ck):
				continue
			for i: int in (index[ck] as PackedInt32Array):
				if i >= known:
					continue   # a newcomer, handled above
				var e: Dictionary = old[i]
				var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
				var nm: String = String(e.get("name", ""))
				if bool(e.get("dead", false)):
					if not bool(e.get("drawn", false)):
						continue
					removed_idx.append(i)
					keys[_bucket_key(nm, xf.origin)] = true
					if trunk_of.has(i) and not trunks.is_empty():
						var t: int = int(trunk_of[i])
						var radii: PackedFloat32Array = trunks["radii"]
						radii[t] = 0.0
						trunks["radii"] = radii
						if assigned.has(t):
							_park_body(assigned[t])
							assigned.erase(t)
					continue
				if moved_in.has_point(Vector2(xf.origin.x, xf.origin.z)):
					keys[_bucket_key(nm, xf.origin)] = true
					if trunk_of.has(i) and not trunks.is_empty():
						var t2: int = int(trunk_of[i])
						var positions: PackedVector3Array = trunks["positions"]
						positions[t2] = xf.origin
						trunks["positions"] = positions
						if assigned.has(t2):
							_park_body(assigned[t2])
							assigned.erase(t2)
	_rebuild_buckets(coord, keys)
	if not added_pairs.is_empty():
		TreeBreakSystem.register_entries(self, coord, added_pairs)
	if not removed_idx.is_empty():
		TreeBreakSystem.unregister_entries(self, coord, removed_idx)
	_ring_dirty = true
	StallLedger.end()


## The general diff, for a caller that hands over a DIFFERENT array than the one this layer
## drew, or a chunk with no index. Every entry is visited; correct, and the slow shape.
func _update_chunk_full(coord: Vector2i, scatter_new: Array, rect: Rect2) -> void:
	var old: Array = _chunk_scatter[coord]
	var trunks: Dictionary = _chunk_trunks.get(coord, {})
	var trunk_of: Dictionary = _chunk_trunk_of.get(coord, {})
	if not _chunk_trunk_of.has(coord):
		_chunk_trunk_of[coord] = trunk_of
	var assigned: Dictionary = _chunk_bodies.get(coord, {})
	var keys: Dictionary = {}
	var have: Dictionary = {}
	for i: int in old.size():
		var e0: Dictionary = old[i]
		if e0.has("uid"):
			have[int(e0["uid"])] = i
	# ADDED
	var seen: Dictionary = {}
	var added_pairs: Array = []
	for e: Dictionary in scatter_new:
		var uid: int = int(e.get("uid", -1))
		seen[uid] = true
		if uid < 0 or have.has(uid):
			continue
		var nm: String = String(e.get("name", ""))
		if not _solid_mesh.has(nm):
			continue
		var idx: int = old.size()
		old.append(e)
		have[uid] = idx
		added_pairs.append([idx, e])
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		keys[_bucket_key(nm, xf.origin)] = true
		var r: float = float(e.get("trunk_r", COVER_TRUNK.get(nm, 0.0)))
		if r > 0.0:
			trunks = _add_trunk(coord, trunks, xf.origin, r, float(e.get("trunk_h", TRUNK_HEIGHT)))
			trunk_of[idx] = (trunks["positions"] as PackedVector3Array).size() - 1
	# REMOVED
	var removed_idx: Array = []
	var grown: Rect2 = rect.grow(2.0)
	for i: int in old.size():
		var e: Dictionary = old[i]
		var uid: int = int(e.get("uid", -1))
		var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
		var nm: String = String(e.get("name", ""))
		# The manager's prune marks a plant dead IN the shared dictionary; if it was drawn
		# when that happened it is a removal here, whatever list it is still listed in.
		var died_drawn: bool = bool(e.get("dead", false)) and bool(e.get("drawn", false))
		if bool(e.get("dead", false)) and not died_drawn:
			continue
		if died_drawn or (uid >= 0 and not seen.has(uid)):
			e["dead"] = true
			removed_idx.append(i)
			keys[_bucket_key(nm, xf.origin)] = true
			if trunk_of.has(i) and not trunks.is_empty():
				var t: int = int(trunk_of[i])
				var radii: PackedFloat32Array = trunks["radii"]
				radii[t] = 0.0
				trunks["radii"] = radii
				if assigned.has(t):
					_park_body(assigned[t])
					assigned.erase(t)
			continue
		# MOVED: standing on the ground that changed. The new Y is already in xf (the cache
		# hit re-seated it in place); the bucket and the trunk just have to catch up.
		if grown.has_point(Vector2(xf.origin.x, xf.origin.z)):
			keys[_bucket_key(nm, xf.origin)] = true
			if trunk_of.has(i) and not trunks.is_empty():
				var t2: int = int(trunk_of[i])
				var positions: PackedVector3Array = trunks["positions"]
				positions[t2] = xf.origin
				trunks["positions"] = positions
				if assigned.has(t2):
					_park_body(assigned[t2])
					assigned.erase(t2)
	_rebuild_buckets(coord, keys)
	if not added_pairs.is_empty():
		TreeBreakSystem.register_entries(self, coord, added_pairs)
	if not removed_idx.is_empty():
		TreeBreakSystem.unregister_entries(self, coord, removed_idx)
	_ring_dirty = true


## Append one trunk to a chunk's collider arrays (creating them for a chunk that had none),
## keeping the cell index and bounds in step. Returns the (possibly new) trunks dictionary.
func _add_trunk(coord: Vector2i, trunks: Dictionary, pos: Vector3, r: float, h: float) -> Dictionary:
	if trunks.is_empty():
		trunks = {"positions": PackedVector3Array(), "radii": PackedFloat32Array(),
			"heights": PackedFloat32Array(), "bounds": Rect2(Vector2(pos.x, pos.z), Vector2.ZERO),
			"cells": {}}
		_chunk_trunks[coord] = trunks
	var positions: PackedVector3Array = trunks["positions"]
	var radii: PackedFloat32Array = trunks["radii"]
	var heights: PackedFloat32Array = trunks["heights"]
	var t: int = positions.size()
	positions.append(pos)
	radii.append(r)
	heights.append(h)
	trunks["positions"] = positions
	trunks["radii"] = radii
	trunks["heights"] = heights
	trunks["bounds"] = (trunks["bounds"] as Rect2).expand(Vector2(pos.x, pos.z))
	var cells: Dictionary = trunks["cells"]
	var ck := Vector2i(int(floor(pos.x / TRUNK_CELL_M)), int(floor(pos.z / TRUNK_CELL_M)))
	var packed: PackedInt32Array = cells.get(ck, PackedInt32Array())
	packed.append(t)
	cells[ck] = packed
	return trunks


## ONE pass over the chunk's scatter for every touched bucket at once, then each bucket is
## rebuilt from its own members. The first version of this scanned the whole chunk - 9,700
## plants - once PER bucket, and a crater touching a few dozen (species, cell) keys cost 138 ms,
## more than the full rebuild it replaced. Touched keys x plants is the wrong shape; plants +
## touched keys is the right one.
func _rebuild_buckets(coord: Vector2i, keys: Dictionary) -> void:
	if keys.is_empty() or not _chunk_scatter.has(coord):
		return
	var members: Dictionary = {}
	for key_any in keys.keys():
		members[key_any] = []
	var scatter: Array = _chunk_scatter[coord]
	var index: Dictionary = _chunk_cells.get(coord, {})
	if index.is_empty():
		for e: Dictionary in scatter:
			_member_of(e, members)
	else:
		# Only the index cells under the touched buckets, each visited once.
		var wanted: Dictionary = {}
		for key_any in keys.keys():
			var key: Array = key_any
			var size: float = _bucket_for(String(key[0]))
			var x0: float = float(key[1]) * size
			var z0: float = float(key[2]) * size
			var c0 := Vector2i(floori(x0 / CACHE_CELL_M), floori(z0 / CACHE_CELL_M))
			var c1 := Vector2i(floori((x0 + size - 0.001) / CACHE_CELL_M), floori((z0 + size - 0.001) / CACHE_CELL_M))
			for cx in range(c0.x, c1.x + 1):
				for cz in range(c0.y, c1.y + 1):
					wanted[Vector2i(cx, cz)] = true
		for ck_any in wanted.keys():
			if not index.has(ck_any):
				continue
			for i: int in (index[ck_any] as PackedInt32Array):
				_member_of(scatter[i], members)
	for key_any in keys.keys():
		_rebuild_bucket(coord, key_any as Array, members[key_any] as Array)


## Sort one entry into `members` if its bucket is being rebuilt; keeps the `drawn` mark honest.
func _member_of(e: Dictionary, members: Dictionary) -> void:
	var nm: String = String(e.get("name", ""))
	var xf: Transform3D = e.get("xf", Transform3D.IDENTITY)
	var key: Array = _bucket_key(nm, xf.origin)
	if not members.has(key):
		return
	if bool(e.get("dead", false)):
		e.erase("drawn")
		return
	(members[key] as Array).append(xf)
	e["drawn"] = true


## Rebuild ONE bucket's MultiMesh from `members` (its live transforms) - or create the bucket
## when a settled log opens a (species, cell) the chunk did not have, or free it when the last
## member is gone. An existing node keeps the origin it was built with, so the locals below
## are relative to that: the node does not move, its AABB only ever shrinks.
func _rebuild_bucket(coord: Vector2i, key: Array, members: Array) -> void:
	var buckets: Dictionary = _chunk_buckets.get(coord, {})
	var nm: String = String(key[0])
	var mmi: MultiMeshInstance3D = null
	var origin: Vector3 = Vector3.ZERO
	if buckets.has(key):
		var rec: Dictionary = buckets[key]
		mmi = rec["node"] as MultiMeshInstance3D
		origin = rec["origin"]
		if mmi == null or not is_instance_valid(mmi):
			buckets.erase(key)
			mmi = null
	if members.is_empty():
		if mmi != null:
			buckets.erase(key)
			(_chunk_nodes[coord] as Array).erase(mmi)
			mmi.queue_free()
		return
	if mmi == null:
		if not _solid_mesh.has(nm):
			return
		for xf: Transform3D in members:
			origin += xf.origin
		origin /= float(members.size())
		var locals0: Array = []
		for xf: Transform3D in members:
			locals0.append(Transform3D(xf.basis, xf.origin - origin))
		mmi = _multimesh(_solid_mesh[nm], locals0, 0.0, _ring_for(nm), origin)
		mmi.set_meta("species", nm)
		add_child(mmi)
		(_chunk_nodes[coord] as Array).append(mmi)
		buckets[key] = {"node": mmi, "origin": origin}
		return
	var locals: Array = []
	for xf: Transform3D in members:
		locals.append(Transform3D(xf.basis, xf.origin - origin))
	var mm: MultiMesh = mmi.multimesh
	mm.instance_count = locals.size()
	for i in locals.size():
		mm.set_instance_transform(i, locals[i])


## Assigned pool bodies right now (cover exists inside the ring). For the probe.
func collider_count() -> int:
	return _pool.size() - _free_bodies.size()


## Ledger span for this script's whole physics step - the 2026-09-11 audit read 100+ of 150
## physics steps over 20 ms mid-assault with the named spans summing to ~3 ms of them.
## The step name is per script on purpose: a shared virtual name would let a subclass's
## body be dispatched from its parent's wrapper.
func _physics_process(delta: float) -> void:
	StallLedger.begin("phys.tree_cover_layer")
	_physics_step_tree_cover_layer(delta)
	StallLedger.end()


func _physics_step_tree_cover_layer(delta: float) -> void:
	_ring_elapsed += delta
	var center: Vector3 = _resolve_center()
	var moved: bool = center != _last_center and (
		center == Vector3.INF or _last_center == Vector3.INF
		or (Vector2(center.x, center.z) - Vector2(_last_center.x, _last_center.z)).length_squared()
			> RING_MOVE_EPS * RING_MOVE_EPS)
	if _ring_elapsed < RING_INTERVAL and not moved and not _ring_dirty:
		return
	_ring_dirty = false
	StallLedger.begin("veg.trunk_ring")
	_update_ring(center)
	StallLedger.end()


func _resolve_center() -> Vector3:
	if ring_center_override != Vector3.INF:
		return ring_center_override
	var p: Node = GameManager.player
	if is_instance_valid(p) and p is Node3D and (p as Node3D).is_inside_tree():
		return (p as Node3D).global_position
	return Vector3.INF


## Delta pass: release bodies whose candidate left the ring AND every threat zone,
## body candidates that entered either. Nearest-first only when demand exceeds the
## pool (logged once).
func _update_ring(center: Vector3) -> void:
	_last_center = center
	_ring_elapsed = 0.0
	_prune_zones()
	if center == Vector3.INF and _zones.is_empty():
		if collider_count() > 0:
			for coord: Vector2i in _chunk_bodies.keys():
				_release_chunk(coord)
		return
	var has_player: bool = center != Vector3.INF
	var c2 := Vector2(center.x, center.z) if has_player else Vector2.ZERO
	var r2: float = RING_RADIUS * RING_RADIUS
	var wanted: Array = []   ## [dist2, coord, idx] per wanted candidate without a body
	# Attributed in two halves: the SCAN (which trunks want a body) and the PLACE (moving pool
	# bodies through the physics server). The cell index made the scan cheap and the total did
	# not move, which is how the ledger learned the cost was never the scan.
	StallLedger.begin("ring.scan")
	# Each zone's XZ footprint once per update, so a cell can be rejected against zones the
	# same way it is rejected against the ring - before any trunk in it is tested.
	var zone_rects: Array[Rect2] = []
	for z: Dictionary in _zones:
		var za: Vector3 = z["a"]
		var zb: Vector3 = z["b"]
		var zr: float = float(z["r"])
		var zrect := Rect2(Vector2(minf(za.x, zb.x), minf(za.z, zb.z)), Vector2.ZERO)
		zrect = zrect.expand(Vector2(maxf(za.x, zb.x), maxf(za.z, zb.z))).grow(zr)
		zone_rects.append(zrect)
	for coord: Vector2i in _chunk_trunks:
		var data: Dictionary = _chunk_trunks[coord]
		var assigned: Dictionary = _chunk_bodies.get(coord, {})
		var near_player: bool = has_player \
			and (data["bounds"] as Rect2).grow(RING_RADIUS).has_point(c2)
		var near_zone: bool = not _zones.is_empty() and _zone_overlaps(data["bounds"] as Rect2)
		if not near_player and not near_zone:
			if not assigned.is_empty():
				_release_chunk(coord)
			continue
		var positions: PackedVector3Array = data["positions"]
		# TWO PASSES, NEITHER OVER THE WHOLE CHUNK. First the bodies already out: each is
		# re-tested and parked if it left the ring and every zone. Then the candidates: only
		# the trunks in index cells the ring (or a zone) can reach are looked at. Same
		# decisions as the old single pass over every trunk; a fraction of the work.
		var radii: PackedFloat32Array = data["radii"]
		var stale: Array = []
		for i_any in assigned.keys():
			var i: int = int(i_any)
			var p: Vector3 = positions[i]
			var d2: float = (Vector2(p.x, p.z) - c2).length_squared() if near_player else 1e18
			if radii[i] <= 0.0 or not (d2 <= r2 or (near_zone and _zone_wants(p))):
				stale.append(i)
		for i_any in stale:
			_park_body(assigned[i_any])
			assigned.erase(i_any)
		var cells: Dictionary = data.get("cells", {})
		for ck_any in cells.keys():
			var ck: Vector2i = ck_any
			var cx0: float = float(ck.x) * TRUNK_CELL_M
			var cz0: float = float(ck.y) * TRUNK_CELL_M
			var cell_in_ring: bool = false
			if near_player:
				# Nearest point of the cell's square to the player, against the ring radius.
				var nx: float = clampf(c2.x, cx0, cx0 + TRUNK_CELL_M)
				var nz: float = clampf(c2.y, cz0, cz0 + TRUNK_CELL_M)
				cell_in_ring = (Vector2(nx, nz) - c2).length_squared() <= r2
			var cell_in_zone: bool = false
			if near_zone:
				var crect := Rect2(cx0, cz0, TRUNK_CELL_M, TRUNK_CELL_M)
				for zrect: Rect2 in zone_rects:
					if zrect.intersects(crect):
						cell_in_zone = true
						break
			if not cell_in_ring and not cell_in_zone:
				continue
			for i: int in (cells[ck] as PackedInt32Array):
				if assigned.has(i) or radii[i] <= 0.0:
					continue
				var p: Vector3 = positions[i]
				var d2: float = (Vector2(p.x, p.z) - c2).length_squared() if near_player else 1e18
				if (cell_in_ring and d2 <= r2) or (cell_in_zone and _zone_wants(p)):
					wanted.append([d2, coord, i])
	StallLedger.end()
	StallLedger.begin("ring.place")
	var capacity: int = _free_bodies.size() + (POOL_MAX - _pool.size())
	if wanted.size() > capacity:
		if not _pool_starved:
			_pool_starved = true
			push_warning("[TreeCover] ring demand %d exceeds POOL_MAX %d - bodying nearest only"
					% [wanted.size(), POOL_MAX])
		wanted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for w: Array in wanted:
		var body: StaticBody3D = _acquire_body()
		if body == null:
			break
		var coord: Vector2i = w[1]
		var idx: int = w[2]
		var data: Dictionary = _chunk_trunks[coord]
		_place_body(body, (data["positions"] as PackedVector3Array)[idx],
				(data["radii"] as PackedFloat32Array)[idx],
				(data["heights"] as PackedFloat32Array)[idx])
		if not _chunk_bodies.has(coord):
			_chunk_bodies[coord] = {}
		(_chunk_bodies[coord] as Dictionary)[idx] = body
	StallLedger.end()
	_ring_stat_wanted = wanted.size()


func _release_chunk(coord: Vector2i) -> void:
	if not _chunk_bodies.has(coord):
		return
	for body: StaticBody3D in (_chunk_bodies[coord] as Dictionary).values():
		_park_body(body)
	_chunk_bodies.erase(coord)


func _acquire_body() -> StaticBody3D:
	if not _free_bodies.is_empty():
		var b: StaticBody3D = _free_bodies.pop_back()
		return b
	if _pool.size() >= POOL_MAX:
		return null
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0   ## static cover reacts to nothing; things test IT
	body.add_to_group("hard_surface")   ## solid timber: rounds stop, wood FX resolve
	body.add_child(CollisionShape3D.new())
	add_child(body)
	body.position = PARK_POS
	_pool.append(body)
	return body


func _place_body(body: StaticBody3D, pos: Vector3, radius: float, height: float = TRUNK_HEIGHT) -> void:
	var h: float = maxf(0.2, height)
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	shape.shape = _shape_for(radius, h)
	body.position = pos + Vector3(0.0, h * 0.5, 0.0)
	body.collision_layer = COVER_COLLISION_LAYER


func _park_body(body: StaticBody3D) -> void:
	body.collision_layer = 0
	body.position = PARK_POS
	_free_bodies.append(body)


## One shared CylinderShape3D per distinct radius+height pair. Snags and lying logs add
## a handful of heights, not one shape per instance.
func _shape_for(radius: float, height: float = TRUNK_HEIGHT) -> CylinderShape3D:
	var key: Vector2 = Vector2(snappedf(radius, 0.001), snappedf(height, 0.05))
	if not _shape_by_radius.has(key):
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		_shape_by_radius[key] = cyl
	return _shape_by_radius[key]


func _multimesh(mesh: Mesh, xforms: Array, vis_begin: float, vis_end: float,
		origin: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	# NOT `multimesh.buffer`. That one-write path was tried on 2026-09-10 and REVERTED the next
	# day: under the headless RendererDummy `buffer` is a silent no-op (a written buffer reads
	# back as every instance at the origin, and the engine's own getter returns []), so every
	# headless probe of the canopy measured nothing and the shipping renderer was never checked.
	# set_instance_transform goes through the server the same way on both. Buckets are small
	# now (a local rebuild touches tens of instances), so the per-instance call is not the cost
	# it was when a whole chunk went through here.
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = origin
	# Shadow casting stays ON across the whole ring. The shipped world sun has shadows off
	# (game_world.gd:65), so this is inert today; if directional shadows are ever turned
	# back on, directional_shadow_max_distance is the engine's own bound on the cost - not
	# a per-node cutoff that would make distant trees stop casting mid-view.
	if vis_begin > 0.0:
		mmi.visibility_range_begin = vis_begin
		mmi.visibility_range_begin_margin = RANGE_MARGIN
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_end_margin = RANGE_MARGIN
	# Hard cut at view_distance (ADR-026), NEVER a fade: VISIBILITY_RANGE_FADE_SELF
	# alpha-dithers the mesh across the fade margin, so foliage at the boundary renders
	# SEE-THROUGH. That was the old "opacity" bug. With the card ring retired there is only
	# ONE boundary left - the far edge of the canopy, out in the fog.
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return mmi


## First MeshInstance3D's mesh (with its own materials) from a GLB; null if absent.
func _extract_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	var mesh: Mesh = MaterialBudget.foliage(_first_mesh(root))
	root.queue_free()
	return mesh


func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for c: Node in node.get_children():
		var m: Mesh = _first_mesh(c)
		if m != null:
			return m
	return null
