extends Resource
## One discrete paddy polygon: a connected RICE_PADDY cluster on the GameplayGrid.
## No class_name (registration-order hazard).
## The working_point NodePath is a write-only contract the activity system reads;
## an empty path means no behavior change today.

var paddy_id: StringName = &""
var world_position: Vector3 = Vector3.ZERO
var cell_count: int = 0
var bounds_min: Vector2i = Vector2i.ZERO
var bounds_max: Vector2i = Vector2i.ZERO
var working_point: NodePath = NodePath()
