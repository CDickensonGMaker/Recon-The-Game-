extends Node
## Clearing System - Jungle clearing with progressive stages
## Handles vegetation removal and terrain flattening for firebase construction

signal vegetation_updated(region: Rect2i)

enum ClearingStage {
	JUNGLE,              # Full vegetation
	PARTIALLY_CLEARED,   # Trees down, stumps remain
	CLEARED,             # Open ground
	FORTIFIED,           # Flattened and prepared
}

class ClearingZone:
	var id: int
	var center: Vector3
	var radius: float
	var stage: ClearingStage = ClearingStage.JUNGLE
	var progress: float = 0.0  # 0-1 within current stage
	var shape: String = "circle"  # "circle" or "rectangle"
	var rect_size: Vector2 = Vector2.ZERO  # For rectangular zones

# Stage visual parameters
const STAGE_PARAMS: Dictionary = {
	ClearingStage.JUNGLE: {
		"vegetation_density": 1.0,
		"height_flattening": 0.0,
		"ground_color": Color(0.12, 0.28, 0.08),  # Dense jungle green
		"tree_scale": 1.0,
	},
	ClearingStage.PARTIALLY_CLEARED: {
		"vegetation_density": 0.25,
		"height_flattening": 0.2,
		"ground_color": Color(0.3, 0.25, 0.15),  # Muddy brown-green
		"tree_scale": 0.3,  # Stumps only
	},
	ClearingStage.CLEARED: {
		"vegetation_density": 0.05,
		"height_flattening": 0.7,
		"ground_color": Color(0.45, 0.38, 0.28),  # Exposed dirt
		"tree_scale": 0.0,
	},
	ClearingStage.FORTIFIED: {
		"vegetation_density": 0.0,
		"height_flattening": 1.0,
		"ground_color": Color(0.52, 0.45, 0.35),  # Packed earth
		"tree_scale": 0.0,
	},
}

var zones: Dictionary = {}  # id -> ClearingZone
var next_zone_id: int = 0

# CLEARING MASK, not a density: starts at 1.0 everywhere and is only ever LOWERED inside a
# clearing zone. Callers must MERGE it as a minimum -- never read it as terrain density.
var vegetation_map: Image
var vegetation_size: int = 512

var clearing_texture: Image

# Set by game_world during world build.
var terrain_manager: Node


func _ready() -> void:
	_init_vegetation_map()


func set_terrain_manager(manager: Node) -> void:
	terrain_manager = manager


func _init_vegetation_map() -> void:
	vegetation_map = Image.create(vegetation_size, vegetation_size, false, Image.FORMAT_RF)
	vegetation_map.fill(Color(1.0, 1.0, 1.0, 1.0))  # Full vegetation

	clearing_texture = Image.create(vegetation_size, vegetation_size, false, Image.FORMAT_RGBA8)
	clearing_texture.fill(Color(0, 0, 0, 0))


func create_zone(center: Vector3, radius: float, shape: String = "circle", rect_size: Vector2 = Vector2.ZERO) -> int:
	var zone := ClearingZone.new()
	zone.id = next_zone_id
	zone.center = center
	zone.radius = radius
	zone.shape = shape
	zone.rect_size = rect_size if shape == "rectangle" else Vector2.ZERO

	zones[zone.id] = zone
	next_zone_id += 1

	return zone.id


## Set zone directly to a stage (for testing)
func set_zone_stage(zone_id: int, stage: ClearingStage) -> void:
	if not zones.has(zone_id):
		return

	var zone: ClearingZone = zones[zone_id]
	zone.stage = stage
	zone.progress = 0.0

	_apply_stage_changes(zone)
	_update_vegetation_map(zone)


## Apply terrain modifications for current stage
func _apply_stage_changes(zone: ClearingZone) -> void:
	if not terrain_manager:
		push_warning("ClearingSystem: TerrainManager not set")
		return

	var params: Dictionary = STAGE_PARAMS[zone.stage]
	var flattening: float = params.height_flattening

	if flattening <= 0.0:
		return

	var cell_size: float = terrain_manager.cell_size
	var heightmap = terrain_manager.heightmap
	var center := Vector2i(
		int(zone.center.x / cell_size),
		int(zone.center.z / cell_size)
	)
	var radius_cells: int = int(zone.radius / cell_size)

	var total_height: float = 0.0
	var count: int = 0

	for y in range(max(0, center.y - radius_cells), min(heightmap.size, center.y + radius_cells)):
		for x in range(max(0, center.x - radius_cells), min(heightmap.size, center.x + radius_cells)):
			if _is_in_zone(zone, x, y, center, radius_cells):
				total_height += heightmap.get_cell(x, y)
				count += 1

	if count == 0:
		return

	var target_height: float = total_height / float(count)

	# Apply flattening via terrain_manager (this also rebuilds chunks)
	var flatten_func := func(current_height: float, falloff_amount: float,
			_wx: float, _wz: float) -> float:
		var blend: float = flattening * falloff_amount
		return lerp(current_height, target_height, blend)

	terrain_manager.modify_terrain(zone.center, zone.radius, flatten_func)


## Check if heightmap cell is within zone
func _is_in_zone(zone: ClearingZone, x: int, y: int, center: Vector2i, radius_cells: int) -> bool:
	if zone.shape == "rectangle" and terrain_manager:
		var half_w: int = int(zone.rect_size.x / (terrain_manager.cell_size * 2))
		var half_h: int = int(zone.rect_size.y / (terrain_manager.cell_size * 2))
		return abs(x - center.x) <= half_w and abs(y - center.y) <= half_h
	else:
		var dist: float = Vector2(x - center.x, y - center.y).length()
		return dist <= radius_cells


func _update_vegetation_map(zone: ClearingZone) -> void:
	if not terrain_manager:
		return

	var params: Dictionary = STAGE_PARAMS[zone.stage]
	var density: float = params.vegetation_density
	var ground_color: Color = params.ground_color

	var scale: float = float(vegetation_size) / terrain_manager.map_size

	var tex_center := Vector2i(
		int(zone.center.x * scale),
		int(zone.center.z * scale)
	)
	var tex_radius: int = int(zone.radius * scale) + 1

	for y in range(max(0, tex_center.y - tex_radius), min(vegetation_size, tex_center.y + tex_radius)):
		for x in range(max(0, tex_center.x - tex_radius), min(vegetation_size, tex_center.x + tex_radius)):
			var in_zone: bool = false

			if zone.shape == "rectangle":
				var half_w: int = int(zone.rect_size.x * scale * 0.5)
				var half_h: int = int(zone.rect_size.y * scale * 0.5)
				in_zone = abs(x - tex_center.x) <= half_w and abs(y - tex_center.y) <= half_h
			else:
				var dist: float = Vector2(x - tex_center.x, y - tex_center.y).length()
				in_zone = dist <= tex_radius

			if in_zone:
				var edge_dist: float
				if zone.shape == "rectangle":
					var half_w: float = zone.rect_size.x * scale * 0.5
					var half_h: float = zone.rect_size.y * scale * 0.5
					var dx: float = abs(x - tex_center.x)
					var dy: float = abs(y - tex_center.y)
					edge_dist = min((half_w - dx) / (half_w * 0.2), (half_h - dy) / (half_h * 0.2))
				else:
					var dist: float = Vector2(x - tex_center.x, y - tex_center.y).length()
					edge_dist = (tex_radius - dist) / (tex_radius * 0.2)

				var falloff: float = clampf(edge_dist, 0.0, 1.0)

				var current_density: float = vegetation_map.get_pixel(x, y).r
				var new_density: float = lerp(current_density, density, falloff)
				vegetation_map.set_pixel(x, y, Color(new_density, new_density, new_density, 1.0))

				var current_color: Color = clearing_texture.get_pixel(x, y)
				var alpha: float = (1.0 - density) * falloff
				var new_color := Color(
					lerp(current_color.r, ground_color.r, alpha),
					lerp(current_color.g, ground_color.g, alpha),
					lerp(current_color.b, ground_color.b, alpha),
					max(current_color.a, alpha)
				)
				clearing_texture.set_pixel(x, y, new_color)

	vegetation_updated.emit(Rect2i(tex_center - Vector2i(tex_radius, tex_radius),
								  Vector2i(tex_radius * 2, tex_radius * 2)))


## Get vegetation density at world position (0-1)
func get_vegetation_density(world_pos: Vector3) -> float:
	if not terrain_manager:
		return 1.0

	var scale: float = float(vegetation_size) / terrain_manager.map_size
	var x: int = clampi(int(world_pos.x * scale), 0, vegetation_size - 1)
	var y: int = clampi(int(world_pos.z * scale), 0, vegetation_size - 1)

	return vegetation_map.get_pixel(x, y).r


## Get clearing color overlay texture
## STAMP GROUND, without a zone. A ClearingZone is a circle or a rectangle with a stage,
## which is the right shape for a cleared LZ and the wrong one for a road: a road is a
## polyline, it has no stage, and it must not touch vegetation_map (RoadNetwork already
## pulled the plants, and writing density here a second time would fight the AI's own
## reading of that ground).
##
## Feathered over the outer FEATHER_FRAC of the half-width so the band has an edge rather
## than a cut. Alpha only ever RISES - a road crossing a cleared zone must not erase it.
const FEATHER_FRAC: float = 0.35


func stamp_ground_line(a: Vector3, b: Vector3, half_width: float, tint: Color,
		strength: float) -> void:
	if clearing_texture == null or terrain_manager == null:
		return
	var scale: float = float(vegetation_size) / terrain_manager.map_size
	var pa := Vector2(a.x * scale, a.z * scale)
	var pb := Vector2(b.x * scale, b.z * scale)
	var hw: float = maxf(1.0, half_width * scale)
	var lo := Vector2i(int(floor(minf(pa.x, pb.x) - hw)), int(floor(minf(pa.y, pb.y) - hw)))
	var hi := Vector2i(int(ceil(maxf(pa.x, pb.x) + hw)), int(ceil(maxf(pa.y, pb.y) + hw)))
	var seg: Vector2 = pb - pa
	var seg_len2: float = maxf(0.0001, seg.length_squared())

	for y in range(maxi(0, lo.y), mini(vegetation_size, hi.y + 1)):
		for x in range(maxi(0, lo.x), mini(vegetation_size, hi.x + 1)):
			var p := Vector2(float(x), float(y))
			var t: float = clampf((p - pa).dot(seg) / seg_len2, 0.0, 1.0)
			var d: float = p.distance_to(pa + seg * t)
			if d > hw:
				continue
			var feather: float = clampf((hw - d) / maxf(0.001, hw * FEATHER_FRAC), 0.0, 1.0)
			var alpha: float = strength * feather
			if alpha <= 0.002:
				continue
			var cur: Color = clearing_texture.get_pixel(x, y)
			clearing_texture.set_pixel(x, y, Color(
				lerpf(cur.r, tint.r, alpha),
				lerpf(cur.g, tint.g, alpha),
				lerpf(cur.b, tint.b, alpha),
				maxf(cur.a, alpha)))


## Push a batch of stamps to the terrain material. Called ONCE after a run of
## stamp_ground_line - game_world rebuilds an ImageTexture from the whole image on this
## signal, so emitting per segment would rebuild it hundreds of times for one road.
func flush_ground() -> void:
	vegetation_updated.emit(Rect2i(0, 0, vegetation_size, vegetation_size))


func get_clearing_texture() -> ImageTexture:
	return ImageTexture.create_from_image(clearing_texture)


## Clear all zones (for testing reset)
func clear_all_zones() -> void:
	zones.clear()
	vegetation_map.fill(Color(1.0, 1.0, 1.0, 1.0))
	clearing_texture.fill(Color(0, 0, 0, 0))
	vegetation_updated.emit(Rect2i(Vector2i.ZERO, Vector2i(vegetation_size, vegetation_size)))
