class_name FellableTree
extends StaticBody3D

## A discrete destructible tree for the fire-support bench: a standing trunk (hard cover)
## that a blast fells with a SCRIPTED HINGE (never a RigidBody), leaving a PERMANENT fallen
## log as prone hard cover — the Pillar-3 "fell a treeline into cover" verb, proven on
## discrete objects here before the live-world MultiMesh (TreeCoverLayer) path. Registered
## on the AgentRegistry.props blast bus so the existing explosion loop
## (combat_manager.gd:178-185) damages it via take_damage — no bespoke damage code.

const STANDING_GLB := "res://assets/world/vegetation/felled_tree.glb"
const LOG_GLB := "res://assets/world/vegetation/felled_trunk.glb"
const TRUNK_RADIUS := 0.4
const TRUNK_HEIGHT := 6.0
const FALL_TIME := 2.0

var hp: int = 120
var _felling: bool = false
var _fallen: bool = false
var _vis: Node3D = null
var _fall_t: float = 0.0
var _fall_axis: Vector3 = Vector3.RIGHT
var _fall_dir: Vector3 = Vector3.RIGHT


static func create(host: Node, pos: Vector3, hp_val: int = 120) -> FellableTree:
	var t := FellableTree.new()
	t.hp = hp_val
	t.collision_layer = 1
	t.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = TRUNK_RADIUS
	cyl.height = TRUNK_HEIGHT
	shape.shape = cyl
	shape.position = Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0)
	t.add_child(shape)
	host.add_child(t)
	t.global_position = pos
	t._build_visual()
	AgentRegistry.register(t, AgentRegistry.Kind.PROP)
	return t


func _build_visual() -> void:
	if ResourceLoader.exists(STANDING_GLB):
		var packed: PackedScene = load(STANDING_GLB) as PackedScene
		if packed != null:
			_vis = packed.instantiate() as Node3D
	if _vis == null:
		# Fallback so the bench still reads if the GLB is absent: a plain trunk cylinder.
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = TRUNK_RADIUS
		cm.bottom_radius = TRUNK_RADIUS
		cm.height = TRUNK_HEIGHT
		mi.mesh = cm
		mi.position = Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0)
		_vis = mi
	add_child(_vis)


## The one damage grammar (ADR-003). The blast bus calls this; a lethal hit starts the fall.
func take_damage(amount: int, _t: int = 0, attacker: Node = null, _zone: String = "BODY") -> void:
	if _felling or _fallen:
		return
	hp -= amount
	if hp <= 0:
		_begin_fall(attacker)


func _begin_fall(attacker: Node) -> void:
	_felling = true
	AgentRegistry.unregister(self)   # off the blast bus; the trunk is coming down
	# Fall AWAY from the blast when the source is positioned; otherwise a deterministic
	# direction seeded from our OWN position (ADR-010 — never Time).
	var away: Vector3 = Vector3.ZERO
	if attacker is Node3D and is_instance_valid(attacker):
		away = global_position - (attacker as Node3D).global_position
	away.y = 0.0
	if away.length() < 0.5:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(global_position.x), int(global_position.z)))
		var a: float = rng.randf() * TAU
		away = Vector3(cos(a), 0.0, sin(a))
	_fall_dir = away.normalized()
	_fall_axis = _fall_dir.cross(Vector3.UP).normalized()
	# The trunk no longer stops rounds mid-fall.
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _felling:
		set_physics_process(false)
		return
	_fall_t += delta
	var frac: float = clampf(_fall_t / FALL_TIME, 0.0, 1.0)
	# Gravity-like ease-in to ~90 degrees, hinged at the base (the node origin).
	var ang: float = (frac * frac) * (PI * 0.5)
	if _vis != null and is_instance_valid(_vis):
		_vis.transform = Transform3D(Basis(_fall_axis, ang), Vector3.ZERO)
	if frac >= 1.0:
		_settle()


func _settle() -> void:
	_felling = false
	_fallen = true
	set_physics_process(false)
	# Impact dust + a crash tick (reuse the shared explosion FX, NOT a second spawner).
	GunFX.play_explosion_3d(get_tree().current_scene, global_position)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, global_position, 0)
	# Swap the transient for the PERMANENT log + a prone-height capsule = hard cover.
	if _vis != null and is_instance_valid(_vis):
		_vis.queue_free()
		_vis = null
	if ResourceLoader.exists(LOG_GLB):
		var packed: PackedScene = load(LOG_GLB) as PackedScene
		if packed != null:
			var log_vis := packed.instantiate() as Node3D
			if log_vis != null:
				add_child(log_vis)
				log_vis.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, _fall_dir)),
					global_position + Vector3(0.0, 0.4, 0.0))
	var log_body := StaticBody3D.new()
	log_body.collision_layer = 1
	log_body.collision_mask = 0
	var cap := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.45
	cs.height = 5.0
	cap.shape = cs
	# Lay the capsule (local +Y axis) down along the fall direction, prone height ~0.5m.
	cap.transform = Transform3D(Basis(Quaternion(Vector3.UP, _fall_dir)), Vector3(0.0, 0.5, 0.0))
	log_body.add_child(cap)
	add_child(log_body)
