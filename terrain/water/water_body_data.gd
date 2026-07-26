extends Resource
class_name WaterBodyData
## Data container for a single water body (river, pond, lake, coastal zone)
## Used by WaterSystem for tracking and rendering water features

enum Type {
	NONE = 0,
	CREEK = 1,      # Width < 6m, flowing
	RIVER = 2,      # Width 6-50m, flowing
	POND = 3,       # Area < 2500 m^2, static
	LAKE = 4,       # Area >= 2500 m^2, static
	SWAMP = 5,      # Shallow, vegetated wetland
	COASTAL = 6,    # Ocean/sea edge
}

@export var id: int = -1

@export var type: Type = Type.NONE

## Water surface elevation in meters
@export var elevation: float = 0.0

## Bounding box in world coordinates (x, z)
@export var bounds: Rect2 = Rect2()

## Shoreline polygon for static bodies (ponds, lakes, coastal)
## Points are in world coordinates (x, z)
@export var polygon: PackedVector2Array = PackedVector2Array()

## Center path for flowing water (rivers, creeks)
## Points are in world coordinates (x, z)
@export var path: PackedVector2Array = PackedVector2Array()

## Width at each path point (for rivers/creeks)
@export var widths: PackedFloat32Array = PackedFloat32Array()

## Average flow direction (normalized, for shader)
@export var flow_direction: Vector2 = Vector2.RIGHT

## Flow speed in m/s (affects shader animation)
@export var flow_speed: float = 0.5

## Average depth in meters
@export var depth: float = 1.0

## Generated mesh (set by WaterMeshBuilder)
var mesh: Mesh = null

## Mesh instance in scene (set by WaterSystem)
var mesh_instance: MeshInstance3D = null


func is_flowing() -> bool:
	return type == Type.CREEK or type == Type.RIVER


## Get area in square meters
func get_area() -> float:
	if is_flowing():
		# Approximate area from path and widths
		var area: float = 0.0
		for i in range(path.size() - 1):
			var segment_length: float = path[i].distance_to(path[i + 1])
			var avg_width: float = (widths[i] + widths[i + 1]) * 0.5
			area += segment_length * avg_width
		return area
	else:
		# Use bounding box as approximation (polygon area calculation is expensive)
		return bounds.get_area()


## Get center point in world coordinates
func get_center() -> Vector2:
	if is_flowing() and path.size() > 0:
		@warning_ignore("integer_division")
		return path[path.size() / 2]
	else:
		return bounds.get_center()


static func type_name(t: Type) -> String:
	match t:
		Type.NONE: return "None"
		Type.CREEK: return "Creek"
		Type.RIVER: return "River"
		Type.POND: return "Pond"
		Type.LAKE: return "Lake"
		Type.SWAMP: return "Swamp"
		Type.COASTAL: return "Coastal"
	return "Unknown"


func _to_string() -> String:
	return "[WaterBody %d: %s, elev=%.1fm, area=%.0fm²]" % [
		id, type_name(type), elevation, get_area()
	]
