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

var weapon_data: WeaponData = null
var ammo_in_gun: int = 0
var spare_mags: int = 0
## Captured guns sound on the enemy's noise team (weapon_holder.gd:56-58). Carried through
## the ground so picking a rifle back up does not launder where it came from.
var is_captured: bool = false

var _age: float = 0.0


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
	w._build_visual()
	return w


func display_name() -> String:
	return weapon_data.display_name.to_upper() if weapon_data != null else "WEAPON"


## The world mesh off the weapon's own resource. A weapon whose model is missing still
## drops - as a marker the player can see and take - because losing the gun entirely is
## worse than an ugly one.
func _build_visual() -> void:
	var scene_path: String = str(weapon_data.model_path) if weapon_data != null else ""
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed != null:
			var vis := packed.instantiate() as Node3D
			if vis != null:
				add_child(vis)
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


## Recycled on a clock, not on distance: a player who walks away and comes back inside the
## fight should find his rifle. Never freed while he is standing on it.
func _process(delta: float) -> void:
	_age += delta
	if _age < LIFETIME_S:
		return
	var p: Node3D = GameManager.player as Node3D
	if p != null and is_instance_valid(p) \
			and p.global_position.distance_to(global_position) < 40.0:
		_age = LIFETIME_S * 0.5
		return
	queue_free()
