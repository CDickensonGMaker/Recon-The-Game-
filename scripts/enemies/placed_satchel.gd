class_name PlacedSatchel
extends Node3D

## A satchel charge lying against what it is going to bring down, burning its fuse while the
## man who set it runs.
##
## The sapper used to BE the bomb: SapperCharge detonated at his own feet and then called
## take_damage(9999) on him. Three sappers on one objective therefore died together in one
## blast, which reads as a suicide squad rather than as demolition men (Summoner, 2026-07-30:
## "they should try to self preservate, just like all AI should... there should be a placing
## of a charge or something than them getting away and the building blowing up").
##
## So the charge is a THING now, not an event. It sits where it was placed - not where the
## sapper happens to be when the timer runs out - and that separation is the whole point: he
## can be a hundred metres away and it still takes the wall down.
##
## It does NOT spare him. Getting clear is a race he can lose, and a man caught by his own
## charge is a fair death rather than a scripted one.

## Long enough to clear SATCHEL_RADIUS at a run (14 m at ~4 m/s is ~3.5 s) with margin, short
## enough that the player who sees it placed has to decide something.
const FUSE_S: float = 5.0

var damage: int = 250
var min_damage: int = 70
var radius: float = 14.0
## Who set it - credited with the kills, and excluded from nothing.
var placer: Node = null

var _fuse: float = FUSE_S


static func place(host: Node, at: Vector3, by: Node, dmg: int, dmg_min: int,
		blast_radius: float) -> PlacedSatchel:
	if host == null:
		return null
	var s := PlacedSatchel.new()
	s.damage = dmg
	s.min_damage = dmg_min
	s.radius = blast_radius
	s.placer = by
	host.add_child(s)
	s.global_position = at
	s._build_visual()
	NoiseBus.emit_noise(NoiseBus.NoiseType.VOICE, at, 1, 25.0)   # the scuffle of setting it
	print("[SATCHEL] placed at %.0f,%.0f - %.1fs fuse" % [at.x, at.z, FUSE_S])
	return s


func _physics_process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0:
		_blow()


func _blow() -> void:
	set_physics_process(false)
	var pos: Vector3 = global_position
	# spare_garrison FALSE: the garrison are participants - the charge does not discriminate,
	# and neither does it spare the sappers who set it.
	CombatManager.apply_explosion_damage(pos, damage, min_damage, radius, placer, 1.0, false)
	DamageSystem.apply_damage(pos, DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	# A satchel is a demolition charge, not a frag: explosion_heavy is the biggest
	# authored bank (GunFX scale 1.9) and the one that sounds like a wall coming down.
	GunFX.play_explosion_3d(get_tree().current_scene, pos, "explosion_heavy")
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, pos, 1)
	# The breach is the point: the satchel blew the firebase's munitions. Tell the director so
	# the cost lands (docked fire support, next patrol short of steel).
	var d: Node = get_tree().get_first_node_in_group("mission_director")
	if d is FieldDirector:
		(d as FieldDirector).on_firebase_breach(pos)
	queue_free()


## A charge you can SEE is a charge you can shoot at, run from, or fail to notice. Falls back
## to a dark box rather than being an invisible timer.
func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.20, 0.16)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.17, 0.13)
	mi.material_override = mat
	mi.position.y = 0.10
	add_child(mi)
