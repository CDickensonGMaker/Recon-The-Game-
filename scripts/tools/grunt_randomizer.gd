## grunt_randomizer.gd - seeded random-grunt builder for the Grunt Viewer bench
## and its probe. Consumer of GruntDresser/ModelActor only (scripts/visuals/ is
## owned elsewhere - never edit it from here).
##
## Skin/face law: face index is ONE number driving ONE material offset
## (grunt_face_skin) - skin tone and face are the same pixels and can never
## mismatch. This class never touches skin separately from face.
class_name GruntRandomizer
extends RefCounted

## Units that are not dressable roles: base rigs, legacy exports without the
## stock-helmet contract, and aircrew (own skin materials, flight helmet).
const NON_ROLES: Array[String] = [
	"us_grunt_v2", "us_grunt_v3",
	"us_grunt_m14", "us_grunt_m60", "us_grunt_m79",
	"us_pilot_white", "us_pilot_black",
]

const RUCK_CHANCE: float = 0.5
const RADIO_CHANCE: float = 0.35


## Dressable US roles on disk, sorted. Derived from the filesystem so a new
## export appears here with no code change.
static func roles() -> Array[String]:
	var out: Array[String] = []
	for u in ModelActor.all_units():
		if u.begins_with("us_") and not u in NON_ROLES:
			out.append(u)
	out.sort()
	return out


## Spawn + dress one grunt under `parent`. `role` empty = random role.
## Returns {} on failure, else {"unit", "actor", "loadout"}.
static func spawn(parent: Node, rng: RandomNumberGenerator, role: String = "") -> Dictionary:
	var pool: Array[String] = roles()
	if pool.is_empty():
		return {}
	var unit: String = role
	if unit.is_empty():
		unit = pool[rng.randi() % pool.size()]
	elif not pool.has(unit):
		return {}

	var actor := ModelActor.new()
	parent.add_child(actor)
	if not actor.setup(unit):
		actor.queue_free()
		return {}

	var opts: Dictionary = {
		"helmet": true,
	}
	if _has_mesh(actor, "ruck_pack_worn"):
		opts["ruck"] = rng.randf() < RUCK_CHANCE
	if _radio_legal(actor):
		opts["radio"] = rng.randf() < RADIO_CHANCE

	var loadout: Dictionary = GruntDresser.dress(actor, rng, opts)
	loadout["unit"] = unit
	_psx_filter_attachments(actor)
	return {"unit": unit, "actor": actor, "loadout": loadout}


## ModelActor applies PSX NEAREST filtering during setup(), BEFORE dress() hangs
## the helmet variant - filter the late arrivals or they render smeared.
static func _psx_filter_attachments(actor: ModelActor) -> void:
	var skel: Skeleton3D = actor.skeleton()
	if skel == null:
		return
	var socket: Node = skel.find_child("HelmetSocket", false, false)
	if socket == null:
		return
	var stack: Array[Node] = [socket]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat != null:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


## radio:true is only offered where it can physically work: the GLB carries a
## PRC-25 and the unit is neither forbidden (no radio in mesh, dresser refuses)
## nor already the radioman (carries it with no dresser call).
static func _radio_legal(actor: ModelActor) -> bool:
	if actor.unit in ModelActor.RADIO_FORBIDDEN or actor.unit in ModelActor.CARRIES_RADIO:
		return false
	return _has_mesh(actor, "prc25_pack")


static func _has_mesh(actor: ModelActor, needle: String) -> bool:
	var root: Node3D = actor.instance_root()
	if root == null:
		return false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D and String(n.name).contains(needle):
			return true
	return false
