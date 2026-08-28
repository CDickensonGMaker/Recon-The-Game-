## satchel_charge.gd - a demolition charge burning on a fuse at a tunnel mouth.
## The charge is a THING IN THE WORLD, not a player state: it keeps burning if the
## man who set it walks away or dies, and the count is on his HUD the whole time -
## a fuse he cannot read is a fuse that kills his squad (his playtest, 2026-08-27).
class_name SatchelCharge
extends Node3D

const FUSE_S: float = 30.0
const BLAST_DAMAGE: int = 200
const BLAST_RIM: int = 60
const BLAST_RADIUS_M: float = 9.0

var entrance: Node3D = null
var attacker: Node = null

var _left: float = FUSE_S
var _shown: int = -1


static func plant(scene_root: Node, at: Vector3, mouth: Node3D, who: Node) -> SatchelCharge:
	var c := SatchelCharge.new()
	c.name = "SatchelCharge"
	c.entrance = mouth
	c.attacker = who
	scene_root.add_child(c)
	c.global_position = at
	return c


func _process(delta: float) -> void:
	_left -= delta
	var whole: int = maxi(0, int(ceil(_left)))
	if whole != _shown:
		_shown = whole
		_hud_fuse("CHARGE SET - FUSE %02d" % whole)
	if _left <= 0.0:
		_detonate()


func _hud_fuse(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("mission_hud")
	if hud != null and hud.has_method("show_fuse"):
		hud.call("show_fuse", text)


func _exit_tree() -> void:
	_hud_fuse("")


func _detonate() -> void:
	set_process(false)
	var at: Vector3 = global_position
	var by: Node = null
	if attacker != null and is_instance_valid(attacker):
		by = attacker
	CombatManager.apply_explosion_damage(at, BLAST_DAMAGE, BLAST_RIM, BLAST_RADIUS_M, by)
	if DamageSystem.has_method("apply_damage"):
		DamageSystem.apply_damage(at, DamageSystem.DamageType.SMALL_EXPLOSION, 1.4)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, at, 0)
	GunFX.play_explosion_3d(get_tree().current_scene, at)
	CampaignState.remember_collapsed_tunnel(at)
	_collapse_mouth()
	queue_free()


## Take the mouth out of the world: no descent, no spider-hole surfacing
## (enemy_base.gd:662 reads this same group), no mesh.
func _collapse_mouth() -> void:
	if entrance == null or not is_instance_valid(entrance):
		return
	entrance.remove_from_group("tunnel_entrances")
	if entrance.has_meta("tunnel_room"):
		var room: Variant = entrance.get_meta("tunnel_room")
		if room is Node and is_instance_valid(room):
			(room as Node).queue_free()
		entrance.remove_meta("tunnel_room")
	entrance.queue_free()
