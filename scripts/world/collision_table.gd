## collision_table.gd - Authored meter-scale collisions + footprints for imported
## RTS structure GLBs. NEVER trust the RTS composed .tscn collisions (100x bug).
## Sizes from RealVietnamRTS game/scenes/buildings/*.tscn (verified meter-scale)
## and firebase_system/building_data.gd footprints.
class_name CollisionTable
extends RefCounted

## name -> { box: Vector3 size, y_offset: float, footprint: Vector2 (m), scale: float }
const STRUCTURES := {
	# Village
	"thatched_hut": {"box": Vector3(4, 2.5, 4), "y_offset": 1.25, "footprint": Vector2(5, 5), "scale": 1.0},
	"stilt_house": {"box": Vector3(4, 3.0, 5), "y_offset": 1.5, "footprint": Vector2(6, 6), "scale": 1.0},
	"rice_storage": {"box": Vector3(3, 2.5, 3), "y_offset": 1.25, "footprint": Vector2(4, 4), "scale": 1.0},
	"well": {"box": Vector3(1.5, 1.0, 1.5), "y_offset": 0.5, "footprint": Vector2(2, 2), "scale": 1.0},
	"communal_house": {"box": Vector3(6, 3.5, 8), "y_offset": 1.75, "footprint": Vector2(9, 9), "scale": 1.0},
	"three_room_house": {"box": Vector3(5, 2.8, 7), "y_offset": 1.4, "footprint": Vector2(8, 8), "scale": 1.0},
	"bell_tower": {"box": Vector3(2.5, 6, 2.5), "y_offset": 3.0, "footprint": Vector2(3, 3), "scale": 1.0},
	"pagoda": {"box": Vector3(4, 5, 4), "y_offset": 2.5, "footprint": Vector2(5, 5), "scale": 1.0},
	# Firebase
	"hootch": {"box": Vector3(4, 2.5, 6), "y_offset": 1.25, "footprint": Vector2(6, 4), "scale": 1.0},
	"sandbag_bunker": {"box": Vector3(3, 2, 3), "y_offset": 1.0, "footprint": Vector2(3, 3), "scale": 1.0},
	"mg_nest": {"box": Vector3(3, 1.5, 3), "y_offset": 0.75, "footprint": Vector2(2, 2), "scale": 1.0},
	"observation_tower": {"box": Vector3(3, 8, 3), "y_offset": 4.0, "footprint": Vector2(2, 2), "scale": 1.0},
	"trench_modular": {"box": Vector3(2, 1.5, 4), "y_offset": 0.75, "footprint": Vector2(4, 2), "scale": 1.0},
	"foxhole_sandbags": {"box": Vector3(2, 1, 2), "y_offset": 0.5, "footprint": Vector2(2, 2), "scale": 1.0},
	"triple_concertina": {"box": Vector3(4, 1.5, 2), "y_offset": 0.75, "footprint": Vector2(6, 1), "scale": 1.0},
	"barbed_wire_coil": {"box": Vector3(4, 1.0, 1), "y_offset": 0.5, "footprint": Vector2(4, 1), "scale": 1.0},
	"sandbag_light": {"box": Vector3(2, 1.5, 2), "y_offset": 0.75, "footprint": Vector2(3, 1), "scale": 1.0},
	"sandbag_heavy": {"box": Vector3(4, 1.2, 1.5), "y_offset": 0.6, "footprint": Vector2(4, 1.5), "scale": 1.0},
	"gate_entrance": {"box": Vector3(6, 3, 2), "y_offset": 1.5, "footprint": Vector2(6, 2), "scale": 1.0},
	# VC props
	"tunnel_entrance_hidden": {"box": Vector3(2, 0.8, 2), "y_offset": 0.4, "footprint": Vector2(2, 2), "scale": 1.0},
	"spider_hole": {"box": Vector3(1.5, 0.6, 1.5), "y_offset": 0.3, "footprint": Vector2(2, 2), "scale": 1.0},
	"weapons_cache": {"box": Vector3(2.5, 1.5, 2.5), "y_offset": 0.75, "footprint": Vector2(3, 3), "scale": 1.0},
	"punji_trap": {"box": Vector3(0, 0, 0), "y_offset": 0.0, "footprint": Vector2(2, 2), "scale": 1.0},  # no collision - trap
	# Vehicles (props)
	"us_m24_tank": {"box": Vector3(3, 2.5, 6), "y_offset": 1.25, "footprint": Vector2(7, 4), "scale": 1.0},
	"m113_apc": {"box": Vector3(2.7, 2.2, 5), "y_offset": 1.1, "footprint": Vector2(6, 3.5), "scale": 1.0},
	"us_halftrack": {"box": Vector3(2.5, 2.3, 6), "y_offset": 1.15, "footprint": Vector2(7, 3.5), "scale": 1.0},
	"m151_mutt_gun_jeep": {"box": Vector3(1.8, 1.8, 3.5), "y_offset": 0.9, "footprint": Vector2(4, 2.5), "scale": 1.0},
	"us_jeep_s3o": {"box": Vector3(1.8, 1.8, 3.5), "y_offset": 0.9, "footprint": Vector2(4, 2.5), "scale": 1.0},
	"us_m4_sherman": {"box": Vector3(3, 2.8, 6), "y_offset": 1.4, "footprint": Vector2(7, 4), "scale": 1.0},
	"huey": {"box": Vector3(3, 3, 12), "y_offset": 1.5, "footprint": Vector2(14, 14), "scale": 0.55},  # raw GLB is 30.7m; 0.55 -> ~17m
	"ch47_chinook": {"box": Vector3(4, 4, 16), "y_offset": 2.0, "footprint": Vector2(18, 18), "scale": 1.0},
}


static func get_entry(model_name: String) -> Dictionary:
	return STRUCTURES.get(model_name, {"box": Vector3(3, 2, 3), "y_offset": 1.0, "footprint": Vector2(4, 4), "scale": 1.0})
