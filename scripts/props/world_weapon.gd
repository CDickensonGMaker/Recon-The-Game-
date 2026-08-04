class_name WorldWeapon
extends Node3D

## A weapon lying on the ground, waiting to be picked up. The dead leave theirs here and
## the player leaves his here when he takes another - so a gun is never destroyed by being
## swapped, and "where did my M16 go" always has an answer you can walk back to.
##
## Deliberately NOT a RigidBody: ADR-001 forbids physics gibs, and a settled prop is a
## static thing the player walks to. It is not on the blast bus either - a dropped rifle is
## not cover and has no HP.
##
## Pickup is the PROXIMITY + group scan every other [F] verb uses (player.gd:524-555 /
## :671-804), never a raycast: the prompt and the verb must share one range or the prompt
## promises a verb that will not fire.

const GROUP: StringName = &"world_weapons"
## Matches the corpse/crate reach in _try_field_interact. One number, both sides.
const PICKUP_RANGE_M: float = 2.5
## How long a dropped weapon stays before the field reclaims it. Permanence inside the
## firefight radius is the ADR-031 rule; a rifle is not a structure, but it must outlive
## the fight it was dropped in.
const LIFETIME_S: float = 600.0
## The reprieve below is capped because it is granted for STANDING NEARBY, and the wire is
## exactly where the player stands while 45 men die on it. Uncapped, a rifle dropped at the
## parapet is immortal for as long as he defends it.
const MAX_REPRIEVES: int = 3
## FIFO ceiling, the same shape GunFX uses for bullet holes. A clock alone cannot bound
## this: nothing had ever run long enough for LIFETIME_S to fire even once.
const MAX_WORLD_WEAPONS: int = 24

var weapon_data: WeaponData = null
var ammo_in_gun: int = 0
var spare_mags: int = 0
## Captured guns sound on the enemy's noise team (weapon_holder.gd:56-58). Carried through
## the ground so picking a rifle back up does not launder where it came from.
var is_captured: bool = false

var _age: float = 0.0
var _reprieves: int = 0
## Drop order, for the FIFO. A static counter and not Time: ADR-010 keeps a reloaded save
## reclaiming the same rifle first.
static var _drop_seq: int = 0
var seq: int = 0


## Drop `data` at `at`, lying flat with a deterministic yaw so a re-loaded save puts the
## same rifle at the same angle (ADR-010 - seeded from position, never Time).
static func drop(host: Node, data: WeaponData, at: Vector3, ammo: int = 0,
		mags: int = 0, captured: bool = false) -> WorldWeapon:
	if host == null or data == null:
		return null
	var w := WorldWeapon.new()
	w.weapon_data = data
	w.ammo_in_gun = ammo
	w.spare_mags = mags
	w.is_captured = captured
	host.add_child(w)
	w.global_position = at
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(at.x * 10.0), int(at.z * 10.0)))
	w.rotation.y = rng.randf() * TAU
	w.rotation.z = PI * 0.5      # a rifle on the ground lies on its side
	w.add_to_group(GROUP)
	_drop_seq += 1
	w.seq = _drop_seq
	w._build_visual()
	_enforce_ceiling(host)
	return w


## Oldest first, and never the one under the player's feet - reclaiming the rifle he is
## reaching for is worse than one extra draw call.
static func _enforce_ceiling(host: Node) -> void:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var live: Array[Node] = tree.get_nodes_in_group(GROUP)
	if live.size() <= MAX_WORLD_WEAPONS:
		return
	var p: Node3D = GameManager.player as Node3D
	var have_player: bool = p != null and is_instance_valid(p)
	var oldest: WorldWeapon = null
	for n in live:
		var w: WorldWeapon = n as WorldWeapon
		if w == null or not is_instance_valid(w):
			continue
		if have_player and p.global_position.distance_to(w.global_position) < PICKUP_RANGE_M * 2.0:
			continue
		if oldest == null or w.seq < oldest.seq:
			oldest = w
	if oldest != null:
		oldest.queue_free()


func display_name() -> String:
	return weapon_data.display_name.to_upper() if weapon_data != null else "WEAPON"


## The world mesh off the weapon's own resource. A weapon whose model is missing still
## drops - as a marker the player can see and take - because losing the gun entirely is
## worse than an ugly one.
##
## `model_path` on every weapon .tres points at its FIRST-PERSON viewmodel, which carries
## a full arms rig: ak_fp.glb is ArmsMesh + a ~40-bone skinned skeleton + 6 animations,
## and the .tscn offsets it -1.81m so the arms sit underground where nobody has ever seen
## them. Instancing that whole rig for a rifle lying in the mud is the single largest
## unbudgeted draw-call source in the game. BAKE THE GUN OUT OF IT instead: keep the gun
## meshes at their rest pose as plain unskinned MeshInstance3Ds, and drop the arms, the
## skeleton and the AnimationPlayer on the floor of the constructor.
func _build_visual() -> void:
	var scene_path: String = str(weapon_data.model_path) if weapon_data != null else ""
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed != null:
			var vis := packed.instantiate() as Node3D
			if vis != null:
				var baked: Node3D = _bake_gun_only(vis)
				vis.queue_free()
				if baked != null:
					add_child(baked)
					return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.09, 0.9)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.16, 0.13)
	mi.material_override = mat
	add_child(mi)
	push_warning("[PICKUP] %s has no world model - dropped as a marker" % display_name())


## Everything that is not the gun. Matched on the mesh resource name, not the node name:
## the exporter names the node off the object and the mesh off the data, and it is the
## MESH that says ArmsMesh.
const ARMS_HINTS: Array[String] = ["arms", "hand", "glove", "sleeve", "forearm"]

## Rebuild the gun as flat geometry. Skinned gun parts (bolt, magazine) keep their rest
## pose, which is the pose a gun in the mud should be in anyway - the alternative is
## carrying a skeleton so a dropped rifle can cycle its own bolt.
func _bake_gun_only(src: Node3D) -> Node3D:
	var root := Node3D.new()
	root.transform = src.transform
	var kept: int = 0
	for mi in _all_mesh_instances(src):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		# Both names, because the importer can rename either one and only one of them
		# has to survive for the arms to be caught.
		var names: String = (str(mesh.resource_name) + " " + str(mi.name)).to_lower()
		var is_arms: bool = false
		for hint in ARMS_HINTS:
			if names.find(hint) >= 0:
				is_arms = true
				break
		if is_arms:
			continue
		var flat := MeshInstance3D.new()
		flat.mesh = mesh
		# Relative to the instantiated root, evaluated at rest - src is not in the tree yet,
		# so this walks parents rather than reading global_transform.
		flat.transform = _relative_transform(mi, src)
		for s in range(mi.get_surface_override_material_count()):
			flat.set_surface_override_material(s, mi.get_surface_override_material(s))
		root.add_child(flat)
		kept += 1
	if kept == 0:
		root.queue_free()
		push_warning("[PICKUP] %s baked to zero meshes - falling back to the marker box"
			% display_name())
		return null
	return root


func _all_mesh_instances(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null:
		out.append(mi)
	for c in n.get_children():
		out.append_array(_all_mesh_instances(c))
	return out


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != ancestor:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t


## Recycled on a clock, not on distance: a player who walks away and comes back inside the
## fight should find his rifle. Never freed while he is standing on it - but the reprieve
## is COUNTED, because standing nearby is the default state at the wire.
func _process(delta: float) -> void:
	_age += delta
	if _age < LIFETIME_S:
		return
	var p: Node3D = GameManager.player as Node3D
	if p != null and is_instance_valid(p) \
			and p.global_position.distance_to(global_position) < 40.0 \
			and _reprieves < MAX_REPRIEVES:
		_reprieves += 1
		_age = LIFETIME_S * 0.5
		return
	queue_free()
