class_name Destructible
extends StaticBody3D

## The ONE destructible-structure component (ADR-031/ADR-023 — folds in the old
## DestructibleFortification). Hard cover until a blast breaks its HP; then a cheap STATE
## SWAP — hide the intact mesh, scatter shared-MultiMesh rubble, scar/crater the ground —
## NEVER a physics fracture (PSX + the perf floor). Rides the AgentRegistry.props blast bus
## (combat_manager.gd:178-185 calls take_damage). Area-leveling is THROTTLED: a lethal hit
## queues the swap and DamageSystem drains WorldConfig.STRUCTURE_LEVELS_PER_FRAME per frame,
## so napalm over a village never pops every structure on one frame.

## Shared rubble across ALL destructibles: ONE MultiMesh / one draw call, rebuilt from the
## authoritative transform list (grow-in-place on a MultiMesh is unreliable; a rebuild is not).
static var _rubble_mm: MultiMesh = null
static var _rubble_mmi: MultiMeshInstance3D = null
static var _rubble_xforms: Array[Transform3D] = []
static var _destroy_queue: Array[Node] = []   ## doomed destructibles awaiting the throttled swap

var kind: String = ""
var hp: int = 110
var destroyed_mesh: Mesh = null   ## optional rubble mesh to swap in; null = just clear the intact one
var _dying: bool = false
var _dead: bool = false


## bullet_system reads the soft_cover/hard_surface group off the collider a round hits.
## Every kind this class wraps is sandbag/earth/timber - real cover - except wire, which
## blocks a man and not a bullet. Every spawn site sets `kind` before add_child.
func _ready() -> void:
	add_to_group("soft_cover" if kind == "wire" else "hard_surface")


## The one damage grammar as a receiver (ADR-003). Only explosions reach it (no Hitzone, so
## rifle fire is merely blocked by the collider — cover). A lethal hit queues the swap.
func take_damage(amount: int, _t: int = 0, _attacker: Node = null, _zone: String = "BODY") -> void:
	if _dying or _dead:
		return
	hp -= amount
	if hp <= 0:
		_dying = true
		AgentRegistry.unregister(self)        # off the bus the frame it is doomed
		if self not in _destroy_queue:
			_destroy_queue.append(self)


## Drain up to n queued destructions this frame — called by DamageSystem._process (the single
## destruction/terrain drainer, ADR-031). Static: no per-instance _process.
static func drain(n: int) -> void:
	var count: int = 0
	while count < n and not _destroy_queue.is_empty():
		var d: Node = _destroy_queue.pop_front()
		if d != null and is_instance_valid(d) and d is Destructible:
			(d as Destructible)._do_destroy()
		count += 1


## Whether the state swap has run. The intact mesh and its collider are the only visible
## difference, so nothing outside this class could otherwise ask.
func is_destroyed() -> bool:
	return _dead


## Test/scene-reset hook: drop all shared static state (rubble + queue).
static func reset_all() -> void:
	_destroy_queue.clear()
	_rubble_xforms.clear()
	if _rubble_mmi != null and is_instance_valid(_rubble_mmi):
		_rubble_mmi.queue_free()
	_rubble_mmi = null
	_rubble_mm = null


func _do_destroy() -> void:
	if _dead:
		return
	_dead = true
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
		elif c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true   # rubble is not full cover
	if destroyed_mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = destroyed_mesh
		add_child(mi)
	remove_from_group("soft_cover")
	remove_from_group("hard_surface")
	# THE HOLE MUST BE WALKABLE, or destruction is decoration. The colliders above are now
	# disabled and NavBaker._add_colliders already skips disabled shapes, so the navmesh is
	# correct the moment it is rebuilt - nothing ever rebuilt it. Debounced inside the baker:
	# one satchel kills several segments and they all name the same ground.
	var baker: NavBaker = NavBaker.instance(self)
	if baker != null:
		baker.breach_at(global_position)
	_scatter_rubble()
	# The blast that killed it also scars the ground (this crater rides the terrain throttle).
	DamageSystem.apply_damage(global_position, DamageSystem.DamageType.BUNKER_COLLAPSE, 1.0)
	# visual_mult 1.0: collapse dust, not ordnance - the x5 spectacle stays off.
	GunFX.play_explosion_3d(get_tree().current_scene, global_position, "explosion_grenade", 1.0)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, global_position, 0)


func _scatter_rubble() -> void:
	_ensure_rubble_mm()
	if _rubble_mm == null:
		return
	# Deterministic scatter from position (ADR-010 — never Time).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(global_position.x), int(global_position.z)))
	for _i in range(4):
		var off := Vector3(rng.randf_range(-1.2, 1.2), 0.1, rng.randf_range(-1.2, 1.2))
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.4, 0.9))
		_rubble_xforms.append(Transform3D(b, global_position + off))
	_rubble_mm.instance_count = _rubble_xforms.size()
	for i in range(_rubble_xforms.size()):
		_rubble_mm.set_instance_transform(i, _rubble_xforms[i])


func _ensure_rubble_mm() -> void:
	if _rubble_mmi != null and is_instance_valid(_rubble_mmi):
		return
	_rubble_mm = MultiMesh.new()
	_rubble_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.5, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.28, 0.22)
	bm.material = mat
	_rubble_mm.mesh = bm
	_rubble_mm.instance_count = 0
	_rubble_mmi = MultiMeshInstance3D.new()
	_rubble_mmi.multimesh = _rubble_mm
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		tree.current_scene.add_child(_rubble_mmi)
	else:
		add_child(_rubble_mmi)
