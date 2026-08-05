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
## us_grunt_v3 dropped 2026-08-04 - retired, the file is gone. us_surgeon has no
## helmet_shell_worn (a surgeon in a field hospital wears none), so the helmet swap
## has nothing to hang on and the dresser would warn on every spawn.
const NON_ROLES: Array[String] = [
	"us_grunt_rifleman",
	"us_pilot_white", "us_pilot_black", "us_surgeon",
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
## `opts` is handed straight to the dresser, so a bench can pin one variable
## (helmet_id, face, ruck, radio) and let the rng roll the rest.
## Returns {} on failure, else {"unit", "actor", "loadout"}.
static func spawn(parent: Node, rng: RandomNumberGenerator, role: String = "",
		opts: Dictionary = {}) -> Dictionary:
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

	var loadout: Dictionary = dress_actor(actor, rng, opts)
	return {"unit": unit, "actor": actor, "loadout": loadout}


## Dress an EXISTING ModelActor - THE one shared core (bench + game spawn path
## both land here; fork this and the two drift). NOT re-entrant: one dress per
## actor instance (helmet sockets stack), guarded by the "dressed" meta.
static func dress_actor(actor: ModelActor, rng: RandomNumberGenerator,
		opts: Dictionary = {}) -> Dictionary:
	if actor.get_meta("dressed", false):
		return {}
	actor.set_meta("dressed", true)

	# Capability-gated, never list-gated (lists drift): helmet swap only where
	# the stock-helmet contract exists. Legacy bodies (m14/m60/m79) dress
	# face-only and keep their welded pot.
	var can_helmet: bool = _has_mesh(actor, GruntDresser.STOCK_HELMET)
	# SAY SO WHEN THE CONTRACT IS ABSENT. A body without the stock helmet dresses face-only
	# and keeps its welded pot - correct for the legacy m14/m60/m79 bodies, and INVISIBLE when
	# it happens to a body that was supposed to carry it. Fifteen authored helmet variants sat
	# on disk unused through the 2026-07-29 playtests ("they are still all spawning with white
	# helmets, none of the variants I made have appeared") because this returned false and told
	# nobody. A capability that silently degrades is the capsule-village failure again.
	if not can_helmet and not _helmet_gap_reported.has(actor.unit):
		_helmet_gap_reported[actor.unit] = true
		push_warning(("[DRESSER] '%s' has no '%s' mesh - keeping its welded pot, and none of "
			+ "the %d authored helmet variants can be hung on it. Re-export the body with the "
			+ "stock-helmet contract, or this unit wears one helmet forever.")
			% [actor.unit, GruntDresser.STOCK_HELMET, GruntDresser.HELMETS.size()])
	var merged: Dictionary = {"helmet": can_helmet}
	if _has_mesh(actor, "ruck_pack_worn"):
		merged["ruck"] = rng.randf() < RUCK_CHANCE
	if _radio_legal(actor):
		merged["radio"] = rng.randf() < RADIO_CHANCE
	for k in opts:
		merged[k] = opts[k]

	var loadout: Dictionary = GruntDresser.dress(actor, rng, merged)
	loadout["unit"] = actor.unit
	_psx_filter_attachments(actor)
	return loadout


## True for units the dresser can fully work: US grunts with the stock-helmet
## contract. Pilots keep flight gear; VC/NVA wait on the atlas cell map.
static func is_dressable(unit: String) -> bool:
	return unit.begins_with("us_") and not unit.begins_with("us_pilot")


## Seed sequence for memberless men (benches, POWs, arena allies). Deterministic
## while spawn order is (ADR-010: one seed per operation); MissionScope.reset()
## rewinds it so mission N+1 does not inherit mission N's position in the walk.
static var _bench_serial: int = 0

## One line per unit, not per man: 21 garrison + a squad would otherwise bury the log.
static var _helmet_gap_reported: Dictionary = {}


static func next_bench_seed() -> int:
	_bench_serial += 1
	return 48151623 + _bench_serial * 2654435761


static func reset_bench() -> void:
	_bench_serial = 0


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
