class_name FoliageWind
extends Node
## Feeds the jungle's `foliage_pushers` global shader uniform so vegetation parts around
## whoever is moving through it.
##
## Drop ONE of these in the mission scene. It does not care how much vegetation there is
## (the jungle is ~2.36M tris of MultiMesh) because it never touches the plants - it
## writes a single array of 8 vec4s that EVERY foliage material reads. Cost is 8 vector
## writes per frame, total, forever.
##
## WHY 8: because at any moment only a handful of bodies are close enough to a given
## blade of grass to matter, and a shader loop of 8 is free. We pick the 8 nearest the
## camera, so the ones you can actually SEE parting are the ones that get slots.
##
## The parting is not decoration. In a stealth game the wake something leaves in
## elephant grass is how the player reads "someone is out there" - and how the enemy
## reads the same about him. It is a detection cue you can see from 100 m.

const MAX_PUSHERS: int = 8
const UNIFORM_NAME: StringName = &"foliage_pushers"

## Anything in these groups parts the vegetation.
@export var pusher_groups: Array[StringName] = [&"player", &"enemies", &"civilians"]
## How wide a body's wake is, in metres.
@export var push_radius: float = 0.85
## Bodies further than this from the camera do not get a slot - you cannot see their wake.
@export var cull_distance: float = 45.0
## Wind, fed to every foliage material at once.
@export var wind_direction: Vector2 = Vector2(1.0, 0.35)
@export_range(0.0, 1.0) var wind_strength: float = 0.16

var _slots: PackedVector4Array = PackedVector4Array()


func _ready() -> void:
	_slots.resize(MAX_PUSHERS)
	_ensure_global(UNIFORM_NAME, RenderingServer.GLOBAL_VAR_TYPE_VEC4)
	_clear()


func _ensure_global(n: StringName, t: RenderingServer.GlobalShaderParameterType) -> void:
	# A global uniform that was never declared in project settings silently reads as zero,
	# which looks exactly like "the effect is off" - so declare it if it is missing.
	if RenderingServer.global_shader_parameter_get_list().has(n):
		return
	RenderingServer.global_shader_parameter_add(n, t, Vector4.ZERO)


func _clear() -> void:
	for i in range(MAX_PUSHERS):
		_slots[i] = Vector4.ZERO          # w = 0 -> the shader skips this slot
		RenderingServer.global_shader_parameter_set(
			_indexed(i), Vector4.ZERO)


func _indexed(i: int) -> StringName:
	return StringName("%s[%d]" % [UNIFORM_NAME, i])


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye: Vector3 = cam.global_position

	var bodies: Array[Node3D] = []
	for g: StringName in pusher_groups:
		for n: Node in get_tree().get_nodes_in_group(g):
			if n is Node3D:
				var b: Node3D = n as Node3D
				if eye.distance_to(b.global_position) <= cull_distance:
					bodies.append(b)

	# nearest to the camera win the slots - those are the wakes the player can see
	bodies.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return eye.distance_squared_to(a.global_position) \
			< eye.distance_squared_to(b.global_position))

	for i in range(MAX_PUSHERS):
		var v: Vector4 = Vector4.ZERO
		if i < bodies.size():
			var p: Vector3 = bodies[i].global_position
			v = Vector4(p.x, p.y, p.z, push_radius)
		if _slots[i] != v:
			_slots[i] = v
			RenderingServer.global_shader_parameter_set(_indexed(i), v)
