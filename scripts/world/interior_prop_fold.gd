class_name InteriorPropFold
extends RefCounted

## THE 545 FIREBASE INTERIOR PROPS, FOLDED INTO ONE MULTIMESH PER TYPE.
##
## The problem, counted (tools/probe_interior_pop.gd, tools/probe_interior_fold.gd):
## 545 `fb_int_` nodes, 1,010 surfaces, 43,941 triangles of baked copies - but only
## **69 distinct meshes** and **5,471 triangles** of unique geometry. The compound ships
## eleven identical hooch sets, so almost every prop in it is a copy of one of 69 things.
##
## The old fix was a range cull at 40 m with no fade mode, which meant all 545 arrived in a
## SINGLE frame as you closed on a hooch. FADE_SELF is refused: it alpha-dithers a prop
## see-through, the ADR-026 opacity bug the Summoner already rejected.
##
## THE RANGE COMES OFF THE PROP'S OWN SIZE NOW, NOT OFF A NUMBER SOMEBODY LIKED. 40 m was a
## guess made when every prop cost its own draw call, so the range had to be short. With the
## surfaces folded it no longer does, and each type is shown out to the distance at which it
## covers two rendered rows - the same screen error `mesh_lod/lod_change/threshold_pixels`
## already accepts for swapping a whole LOD level. A helmet earns 15 m, a cot 230 m.
##
## AND THAT IS WHERE THE STAGGER COMES FROM NOW. It used to be a 6 m spread of 545 thresholds,
## deterministic in each prop's name (ADR-010), so they arrived over ~10 frames instead of one.
## Sixty-nine measured per-type ranges spread the same arrival over ~150 m instead of 6 m, and
## every one of them lands while the prop covers two pixels or less - so there is nothing left
## to see arrive. The name-derived determinism is kept as a small per-type jitter, so the same
## compound always resolves in the same order. Banding types further was measured and rejected:
## with 69 types, 4 bands costs 528 draw calls and 6 costs 792, against 132 for one - it
## quadruples the bill to stagger an arrival that is already invisible.
##
## THE FOLD DOES NOT PAY FOR ITSELF - IT PAYS FOR THE RANGE MOVE. Measured 2026-09-09 at the
## compound centre, draw calls against what shipped that morning: folding at the OLD 40 m range
## COSTS +50 calls, because a MultiMesh gives up the per-node frustum culling that was quietly
## doing the work - 545 nodes cull individually, 69 MultiMeshes each span all eleven hooches and
## draw whole. What the fold buys is the price of the range move: pushing the range out to the
## measured distance costs +110 calls on the baked nodes and only +17 on the folded ones. Net
## against today, +67 calls for a pop that is gone. If the 40 m range is ever restored, this
## fold must be restored with it or it is a straight loss.
##
## SCOPE OF THOSE NUMBERS: draw calls and surfaces from a STATIC camera in an empty compound.
## The Summoner ruled that bench unrepresentative the same day - "its just terrain with no
## action so its not really gauging anything" - so the counts stand as structural facts and NO
## frame or gpu figure is claimed from it. What the change feels like is unmeasured, and F11
## exists so he can settle it himself.
##
## WHAT THIS DOES NOT TOUCH. Colliders are separate `StaticBody3D` siblings in the flat GLB, so
## ballistics (which reads COLLIDER names) and the navmesh (which reads `CollisionShape3D`) are
## untouched - a footlocker is still solid and still in the bake. Nothing here matches a
## `FSB_STRUCTURE_KINDS` or `FSB_SOFT_PREFIXES` prefix, so the destructible contract sees no
## change. It must run AFTER `_stamp_hooch_radios`, which reads the eleven `fb_int_radio`
## MESH positions to place the voices.

const PREFIX: String = "fb_int_"

## The shipped projection: vertical FOV 75 (ADR-004 hip lens), 720 rows at the ratified 0.75
## render scale = 540 rendered rows. A thing h metres tall covers h * PX_PER_M_AT_1M / d rows.
const ROWS: float = 540.0
const FOV_DEG: float = 75.0
## Two rendered rows. Matches `mesh_lod/lod_change/threshold_pixels=2.0` deliberately - this
## reuses the screen error the project already accepts; it does NOT change that setting, which
## is an open ruling of the Summoner's.
const TARGET_PX: float = 2.0

## Never pull a prop in closer than the range it already had, whatever the arithmetic says.
const MIN_RANGE_M: float = 40.0
## A prop may never outlive the building it sits inside: SitePlanner.STRUCTURE_VISIBILITY_END.
const MAX_RANGE_M: float = 230.0
const RANGE_MARGIN_M: float = 8.0
## Per-TYPE jitter, deterministic in the representative mesh's name (ADR-010).
const JITTER_M: float = 6.0


static func px_factor() -> float:
	return ROWS / (2.0 * tan(deg_to_rad(FOV_DEG) * 0.5) * TARGET_PX)


## The distance at which this mesh covers TARGET_PX rendered rows, jittered deterministically
## by `name` (ADR-010) and clamped so a prop is never pulled nearer than it already was nor
## shown further than the building around it. Shared by the fold and by the plain range pass,
## so the two can never disagree about how far a cot is worth drawing.
static func measured_range(mesh: Mesh, name: String) -> float:
	var box: Vector3 = mesh.get_aabb().size.abs()
	var size: float = maxf(box.x, maxf(box.y, box.z))
	var jitter: float = float(absi(name.hash()) % 1000) / 1000.0 * JITTER_M
	return clampf(size * px_factor() + jitter, MIN_RANGE_M, MAX_RANGE_M)


## Set the measured range on the BAKED prop nodes, folding nothing. Keeps all 545 nodes and
## therefore keeps per-node frustum culling, which is the thing the fold gives up.
static func apply_range_only(root: Node3D) -> Dictionary:
	var n: int = 0
	var near_m: float = MAX_RANGE_M
	var far_m: float = 0.0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).begins_with(PREFIX):
			continue
		var r: float = measured_range(mi.mesh, String(mi.name))
		mi.visibility_range_end = r
		mi.visibility_range_end_margin = RANGE_MARGIN_M
		near_m = minf(near_m, r)
		far_m = maxf(far_m, r)
		n += 1
	return {"props": n, "near_m": near_m, "far_m": far_m}


## Fold every `fb_int_` MeshInstance3D under `root` into one MultiMesh per distinct mesh, then
## REMOVE the originals. Removing them is not optional and not a separate change: leaving the
## baked nodes in place draws every prop twice.
static func apply(root: Node3D) -> Dictionary:
	var groups: Dictionary = {}          ## mesh RID string -> Array[MeshInstance3D]
	var order: Array[String] = []
	var surfaces_before: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not String(mi.name).begins_with(PREFIX):
			continue
		surfaces_before += mi.mesh.get_surface_count()
		var key: String = str(mi.mesh.get_rid())
		if not groups.has(key):
			groups[key] = ([] as Array[MeshInstance3D])
			order.append(key)
		(groups[key] as Array[MeshInstance3D]).append(mi)

	if order.is_empty():
		return {"props": 0, "meshes": 0, "surfaces_before": 0, "surfaces_after": 0}

	var inv: Transform3D = root.global_transform.affine_inverse()
	var surfaces_after: int = 0
	var props: int = 0
	var dial_mmis: Array[MultiMeshInstance3D] = []
	var dial_base: Array[float] = []
	var near_m: float = MAX_RANGE_M
	var far_m: float = 0.0
	for key: String in order:
		var members: Array[MeshInstance3D] = groups[key]
		var first: MeshInstance3D = members[0]
		var mesh: Mesh = first.mesh
		var range_m: float = measured_range(mesh, String(first.name))
		near_m = minf(near_m, range_m)
		far_m = maxf(far_m, range_m)

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = members.size()
		for i in members.size():
			mm.set_instance_transform(i, inv * members[i].global_transform)

		var mmi := MultiMeshInstance3D.new()
		## Keeps the fb_int_ prefix so every audit that counts interior props still finds them,
		## and adds `_mm_` so a folded node is never mistaken for a baked one in a log.
		mmi.name = "fb_int_mm_%s" % String(first.name).substr(PREFIX.length())
		mmi.multimesh = mm
		mmi.cast_shadow = first.cast_shadow
		mmi.gi_mode = first.gi_mode
		mmi.visibility_range_end = range_m
		mmi.visibility_range_end_margin = RANGE_MARGIN_M
		root.add_child(mmi)
		mmi.global_transform = root.global_transform
		surfaces_after += mesh.get_surface_count()
		dial_mmis.append(mmi)
		dial_base.append(range_m)

		## REMOVE THE BAKE. Detached from the tree first rather than queue_free()d alone, so
		## the very next walk in this same frame cannot still find it and count it twice.
		for mi: MeshInstance3D in members:
			props += 1
			var parent: Node = mi.get_parent()
			if parent != null:
				parent.remove_child(mi)
			mi.queue_free()

	var dial := InteriorPropDial.new()
	dial.name = "InteriorPropDial"
	root.add_child(dial)
	dial.setup(dial_mmis, dial_base)

	return {
		"props": props,
		"meshes": order.size(),
		"surfaces_before": surfaces_before,
		"surfaces_after": surfaces_after,
		"near_m": near_m,
		"far_m": far_m,
	}
