class_name FieldCache
extends Node3D

## A box a squad specialist puts on the ground for everyone else to draw from. The medic's
## MEDICAL box holds bandages; the grenadier's AMMO box holds magazines and frags.
##
## THE BAG IS A CONTAINER, NOT A TREATMENT (Summoner, 2026-07-30): "medical bags hold the
## bandages. each medic gets X bandages but they can also lay down a medical box which holds
## 10 bandages that the player and allies can pick up from. Just like we should also make a
## supply box that the m79 grenade launcher guy can drop down for ammo etc."
##
## So there is ONE deployable and two payloads, never two prop classes (ADR-023). It is a
## plain Node3D with no collider: a box you walk up to, not a thing you trip over, and the
## player's [F] finds it by proximity like every other field verb.
##
## Deliberately NOT in the `supply_crates` group. That group's verb hands over the WHOLE
## kit - mags, frags, medkits, chow, claymores, satchels - and does it without limit. A
## bandage box that refilled a man's claymores would make the whole supply economy free.

const GROUP: StringName = &"field_caches"
## Matches every other field verb's reach, and player.gd's prompt/verb contract.
const REACH_M: float = 3.0

enum Kind { MEDICAL, AMMO }

## His number: a laid-down medical box holds ten.
const MEDICAL_STOCK: int = 10
const AMMO_STOCK: int = 10

const MEDICAL_MODEL: String = "res://assets/world/props/medical_crate.glb"
const AMMO_MODEL: String = "res://assets/us/props/interior/fb_ammo_crate_stack.glb"

var kind: Kind = Kind.MEDICAL
var stock: int = MEDICAL_STOCK
## Who laid it down, so a medic can find his own box to restock from.
var owner_team: int = 0


static func deploy(host: Node, at: Vector3, of_kind: Kind) -> FieldCache:
	if host == null:
		return null
	var c := FieldCache.new()
	c.kind = of_kind
	c.stock = MEDICAL_STOCK if of_kind == Kind.MEDICAL else AMMO_STOCK
	host.add_child(c)
	var ground: Vector3 = at
	ground.y += 0.05
	c.global_position = ground
	# Deterministic yaw from position (ADR-010): the same box sits the same way on reload.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(at.x * 10.0), int(at.z * 10.0)))
	c.rotation.y = rng.randf() * TAU
	c.add_to_group(GROUP)
	c._build_visual()
	print("[CACHE] %s box down at %.0f,%.0f with %d" % [c.kind_name(), at.x, at.z, c.stock])
	return c


func kind_name() -> String:
	return "MEDICAL" if kind == Kind.MEDICAL else "AMMO"


func label() -> String:
	return "%s BOX (%d)" % [kind_name(), stock]


## Take `n` from the box. Returns how many were actually taken, which is 0 on an empty box.
## The box frees itself when it runs dry - an empty crate that still prompts is a lie.
func draw(n: int = 1) -> int:
	var got: int = mini(n, stock)
	stock -= got
	if stock <= 0:
		queue_free()
	return got


## Nearest cache of a kind within `reach` of `from`, or null.
static func nearest(from: Node3D, of_kind: Kind, reach: float = REACH_M) -> FieldCache:
	if from == null or from.get_tree() == null:
		return null
	var best: FieldCache = null
	var best_d: float = reach
	for n in from.get_tree().get_nodes_in_group(GROUP):
		var c := n as FieldCache
		if c == null or not is_instance_valid(c) or c.stock <= 0 or c.kind != of_kind:
			continue
		var d: float = from.global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


## A crate you can see from across the compound is the point - it is a rally marker as much
## as a resupply. Falls back to a coloured box rather than being invisible.
func _build_visual() -> void:
	var path: String = MEDICAL_MODEL if kind == Kind.MEDICAL else AMMO_MODEL
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var vis := packed.instantiate() as Node3D
			if vis != null:
				add_child(vis)
				return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.35, 0.4)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.72, 0.68) if kind == Kind.MEDICAL else Color(0.30, 0.33, 0.22)
	mi.material_override = mat
	mi.position.y = 0.175
	add_child(mi)
