## garrison_defender.gd - The Civilian -> AllyBase hand-off that turns a firebase
## garrison man into a soldier defending his post when the wire is under attack.
##
## This is the SAME 1:1 in-place swap civilian._transform_to_vc() already does for
## the informer: one authority, one population, no second parallel spawn, and NO
## third combat brain - the promoted man reuses AllyBase's shipped fire logic whole.
## He is NOT the player's squad (squad_member=false, like friendly_patrol_group.gd),
## he holds his post (post_anchor + OrderMode.HOLD, so the perimeter never empties),
## and he can be hit and can die like any other body.
class_name GarrisonDefender
extends RefCounted

## Garrison occupation -> the man's MOS. gun_crew mans the heavy weapon; everyone
## else is a rifleman. (The firebase radioman is background - never the player's RTO.)
const MOS_FOR: Dictionary = {
	"gun_crew": "MG",
}


## Promote one garrison Civilian to an AllyBase holding his post. Returns the ally,
## or null if the civ is not a live garrison man. Tears the Civilian down SYNCHRONOUSLY
## first - queue_free() is deferred, so a free-then-spawn would leave a one-frame ghost
## still in both rosters and holding a live hitzone at the post - then stands the
## soldier in his place THE SAME FRAME (a deferred FOLLOW default would yank him to the
## player on his first tick).
static func promote(civ: Civilian, director: FieldDirector, fsb_center: Vector3) -> AllyBase:
	if civ == null or not is_instance_valid(civ) or not civ.is_garrison:
		return null
	if civ.state == Civilian.CivState.GONE:
		return null
	var parent: Node = civ.get_parent()
	if parent == null:
		return null

	# Snapshot everything the soldier inherits BEFORE teardown.
	var post: Vector3 = civ.working_point_pos if civ.working_point_pos != Vector3.ZERO else civ.global_position
	var stand: Vector3 = civ.global_position
	var unit: String = civ.actor.unit if (civ.actor != null and is_instance_valid(civ.actor)) else ""
	var occ: String = civ.occupation

	# Teardown, explicit (godot_standards: do not lean on engine auto-cleanup).
	civ.remove_from_group("firebase_garrison")
	civ.remove_from_group("civilians")
	AgentRegistry.unregister(civ)
	if NoiseBus.noise_emitted.is_connected(civ._on_noise):
		NoiseBus.noise_emitted.disconnect(civ._on_noise)
	civ.set_physics_process(false)
	civ.queue_free()

	# Stand the soldier up, configured in this same frame.
	var ally: AllyBase = AllyBase.spawn_ally(parent, stand)
	ally.squad_member = false
	# The nameplate reads this dict (squad_nameplate.gd) - without it a promoted man is
	# an unnamed US silhouette, the blue-on-blue the affordance exists to prevent.
	# Deterministic per post (ADR-010: same seed, same men).
	ally.member = SquadRoster.generate_member(_seeded_rng(stand), str(MOS_FOR.get(occ, "RIFLEMAN")))
	ally.director = director
	ally.set_order(AllyBase.OrderMode.HOLD, post)
	ally.post_anchor = post
	ally.post_leash = 8.0
	if not unit.is_empty():
		ally.set_sprite(unit, "m16a1")
	# A sentry on watch faces OUT, off the compound - not at his boots.
	var outward: Vector3 = stand - fsb_center
	outward.y = 0.0
	if outward.length() > 0.1:
		ally.current_aim_dir = outward.normalized()
	ally.add_to_group("garrison_promoted")
	return ally


static func _seeded_rng(at: Vector3) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(Vector2i(int(at.x), int(at.z))))
	return rng
