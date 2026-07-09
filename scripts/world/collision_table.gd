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
	"huey": {"box": Vector3(3, 3, 12), "y_offset": 1.5, "footprint": Vector2(14, 14), "scale": 1.0},  # duplicate fuselage stripped at runtime; single body ~17m
	"ch47_chinook": {"box": Vector3(4, 4, 16), "y_offset": 2.0, "footprint": Vector2(18, 18), "scale": 1.0},
	# ---- Auto-measured from GLB AABBs (headless Blender, bead f5yf). box=(x, height, depth),
	# y_offset=AABB center height. mesh:true = GLB carries -col trimesh (box = nav carve only).
	"Bomb_1000lb_Mk83": {"box": Vector3(0.8, 0.8, 2.6), "y_offset": 0.00, "footprint": Vector2(2.0, 4.0), "scale": 1.0},
	"Bomb_2000lb_Mk84": {"box": Vector3(1.0, 1.0, 3.5), "y_offset": 0.00, "footprint": Vector2(2.0, 4.5), "scale": 1.0},
	"Bomb_250lb_Mk81": {"box": Vector3(0.5, 0.5, 1.5), "y_offset": 0.00, "footprint": Vector2(1.5, 2.5), "scale": 1.0},
	"Bomb_500lb_Mk82": {"box": Vector3(0.6, 0.6, 2.0), "y_offset": 0.00, "footprint": Vector2(2.0, 3.5), "scale": 1.0},
	"Napalm_500lb_BLU27": {"box": Vector3(0.4, 0.5, 2.2), "y_offset": 0.00, "footprint": Vector2(1.5, 3.5), "scale": 1.0},
	"Napalm_750lb_BLU1": {"box": Vector3(0.5, 0.5, 2.8), "y_offset": 0.00, "footprint": Vector2(1.5, 4.0), "scale": 1.0},
	"RocketPod_LAU61_19tube": {"box": Vector3(0.5, 1.6, 0.6), "y_offset": 0.11, "footprint": Vector2(1.5, 2.0), "scale": 1.0},
	"RocketPod_LAU68_7tube": {"box": Vector3(0.4, 1.4, 0.4), "y_offset": 0.09, "footprint": Vector2(1.5, 1.5), "scale": 1.0},
	"a1_skyraider": {"box": Vector3(14.0, 5.1, 12.1), "y_offset": 0.30, "footprint": Vector2(15.0, 13.5), "scale": 1.0},
	"a4_skyhawk": {"box": Vector3(8.4, 3.6, 12.8), "y_offset": 0.82, "footprint": Vector2(9.5, 14.0), "scale": 1.0},
	"aid_station": {"box": Vector3(8.0, 3.0, 6.0), "y_offset": 1.52, "footprint": Vector2(9.0, 7.5), "scale": 1.0},
	"aircraft_revetment": {"box": Vector3(20.0, 3.0, 15.0), "y_offset": 1.50, "footprint": Vector2(21.0, 16.0), "scale": 1.0},
	"ammo_bunker": {"box": Vector3(7.6, 3.3, 6.3), "y_offset": 1.65, "footprint": Vector2(9.0, 7.5), "scale": 1.0},
	"artillery_pit": {"box": Vector3(40.0, 9.9, 55.1), "y_offset": 2.44, "footprint": Vector2(41.0, 56.5), "scale": 1.0},
	"barbed_wire": {"box": Vector3(0.7, 0.7, 1.0), "y_offset": 0.00, "footprint": Vector2(2.0, 2.5), "scale": 1.0},
	"barracks": {"box": Vector3(10.0, 3.8, 5.6), "y_offset": 1.91, "footprint": Vector2(11.0, 7.0), "scale": 1.0},
	"barracks_bunker": {"box": Vector3(6.0, 1.4, 4.0), "y_offset": 0.70, "footprint": Vector2(7.0, 5.0), "scale": 1.0},
	"bomb_crater": {"box": Vector3(9.3, 3.6, 9.1), "y_offset": -1.30, "footprint": Vector2(10.5, 10.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"brick_pile": {"box": Vector3(1.1, 0.3, 0.9), "y_offset": 0.16, "footprint": Vector2(2.5, 2.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"bunker": {"box": Vector3(3.2, 1.8, 2.7), "y_offset": 0.88, "footprint": Vector2(4.5, 4.0), "scale": 1.0},
	"burned_hut": {"box": Vector3(4.1, 1.3, 3.1), "y_offset": 0.66, "footprint": Vector2(5.5, 4.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"cham_temple_ruin": {"box": Vector3(6.0, 8.7, 6.0), "y_offset": 4.34, "footprint": Vector2(7.0, 7.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"claymore_line": {"box": Vector3(9.9, 0.1, 9.9), "y_offset": 0.07, "footprint": Vector2(11.0, 11.0), "scale": 1.0},
	"commo_bunker": {"box": Vector3(4.0, 8.8, 4.0), "y_offset": 4.40, "footprint": Vector2(5.0, 5.0), "scale": 1.0},
	"conex_bunker": {"box": Vector3(6.8, 2.5, 3.3), "y_offset": 1.25, "footprint": Vector2(8.0, 4.5), "scale": 1.0},
	"control_tower": {"box": Vector3(6.0, 17.0, 7.5), "y_offset": 8.50, "footprint": Vector2(7.0, 8.5), "scale": 1.0},
	"cultist_temple2": {"box": Vector3(16.8, 5.4, 11.8), "y_offset": 5.01, "footprint": Vector2(18.0, 13.0), "scale": 1.0},
	"destroyed_bunker": {"box": Vector3(3.4, 0.8, 3.4), "y_offset": 0.41, "footprint": Vector2(4.5, 4.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"dock_pier": {"box": Vector3(51.0, 3.7, 10.2), "y_offset": 0.84, "footprint": Vector2(52.0, 11.5), "scale": 1.0},
	"f4_phantom": {"box": Vector3(11.6, 4.5, 19.4), "y_offset": 2.29, "footprint": Vector2(13.0, 20.5), "scale": 1.0},
	"fire_direction_center": {"box": Vector3(5.4, 5.5, 4.4), "y_offset": 2.75, "footprint": Vector2(6.5, 5.5), "scale": 1.0},
	"fire_station": {"box": Vector3(16.0, 5.5, 9.0), "y_offset": 2.75, "footprint": Vector2(17.0, 10.0), "scale": 1.0},
	"french_barracks": {"box": Vector3(31.2, 9.5, 12.1), "y_offset": 4.75, "footprint": Vector2(32.5, 13.5), "scale": 1.0},
	"fuel_depot": {"box": Vector3(57.5, 29.4, 57.5), "y_offset": 14.69, "footprint": Vector2(58.5, 58.5), "scale": 1.0},
	"gate_entrance_lowpoly": {"box": Vector3(21.5, 9.1, 6.8), "y_offset": 4.47, "footprint": Vector2(23.0, 8.0), "scale": 1.0},
	"gate_fence": {"box": Vector3(5.6, 2.8, 0.3), "y_offset": 1.40, "footprint": Vector2(7.0, 1.5), "scale": 1.0},
	"government_building": {"box": Vector3(26.6, 11.8, 21.1), "y_offset": 5.10, "footprint": Vector2(28.0, 22.5), "scale": 1.0},
	"hangar": {"box": Vector3(40.0, 12.0, 30.0), "y_offset": 6.00, "footprint": Vector2(41.0, 31.0), "scale": 1.0},
	"helipad": {"box": Vector3(0, 0, 0), "y_offset": 0.0, "footprint": Vector2(27.0, 20.0), "scale": 1.0},  # walkable/decoration - no collision
	"hq_building": {"box": Vector3(12.0, 2.5, 12.0), "y_offset": 1.26, "footprint": Vector2(13.0, 13.0), "scale": 1.0},
	"latrine": {"box": Vector3(2.2, 2.5, 1.7), "y_offset": 1.25, "footprint": Vector2(3.5, 3.0), "scale": 1.0},
	"m35_deuce_truck": {"box": Vector3(2.1, 3.3, 5.8), "y_offset": 1.60, "footprint": Vector2(3.5, 7.0), "scale": 1.0},
	"market_hall": {"box": Vector3(22.0, 6.0, 17.0), "y_offset": 3.00, "footprint": Vector2(23.0, 18.0), "scale": 1.0},
	"mess_hall": {"box": Vector3(13.0, 4.5, 9.0), "y_offset": 2.25, "footprint": Vector2(14.0, 10.0), "scale": 1.0},
	"mortar_pit": {"box": Vector3(1.9, 1.5, 2.0), "y_offset": 0.51, "footprint": Vector2(3.0, 3.5), "scale": 1.0},
	"operations_building": {"box": Vector3(16.0, 6.0, 11.0), "y_offset": 3.00, "footprint": Vector2(17.0, 12.0), "scale": 1.0},
	"plantation_house": {"box": Vector3(22.0, 10.5, 19.0), "y_offset": 5.25, "footprint": Vector2(23.0, 20.0), "scale": 1.0},
	"pow_cage": {"box": Vector3(2.7, 2.0, 2.8), "y_offset": 0.99, "footprint": Vector2(4.0, 4.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"powder_bunker": {"box": Vector3(4.1, 3.1, 3.6), "y_offset": 1.55, "footprint": Vector2(5.5, 5.0), "scale": 1.0},
	"psp_helipad": {"box": Vector3(0, 0, 0), "y_offset": 0.0, "footprint": Vector2(16.0, 16.0), "scale": 1.0},  # walkable/decoration - no collision
	"punji_pit": {"box": Vector3(0, 0, 0), "y_offset": 0.0, "footprint": Vector2(3.0, 3.0), "scale": 1.0},  # walkable/decoration - no collision
	"quonset_hut": {"box": Vector3(6.0, 4.0, 12.0), "y_offset": 2.00, "footprint": Vector2(7.0, 13.0), "scale": 1.0},
	"radar_dome": {"box": Vector3(10.0, 4.5, 10.0), "y_offset": 2.25, "footprint": Vector2(11.0, 11.0), "scale": 1.0},
	"radar_network": {"box": Vector3(66.5, 13.8, 16.9), "y_offset": 6.87, "footprint": Vector2(68.0, 18.0), "scale": 1.0},
	"rubble_debris_large": {"box": Vector3(3.9, 1.6, 3.8), "y_offset": 0.80, "footprint": Vector2(5.0, 5.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"rubble_debris_small": {"box": Vector3(0, 0, 0), "y_offset": 0.0, "footprint": Vector2(2.5, 2.5), "scale": 1.0},  # walkable/decoration - no collision
	"rubble_field_wide": {"box": Vector3(4.3, 0.6, 3.9), "y_offset": 0.32, "footprint": Vector2(5.5, 5.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"rubble_heap_tall": {"box": Vector3(2.0, 2.1, 2.0), "y_offset": 1.08, "footprint": Vector2(3.5, 3.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"rubble_pile": {"box": Vector3(5.5, 2.0, 5.2), "y_offset": 1.00, "footprint": Vector2(6.5, 6.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"rubble_pile_medium": {"box": Vector3(2.3, 1.0, 1.8), "y_offset": 0.48, "footprint": Vector2(3.5, 3.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"rubble_scatter_tiny": {"box": Vector3(0, 0, 0), "y_offset": 0.0, "footprint": Vector2(2.0, 1.5), "scale": 1.0},  # walkable/decoration - no collision
	"ruin_house_half": {"box": Vector3(4.5, 2.3, 3.2), "y_offset": 1.17, "footprint": Vector2(6.0, 4.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"ruin_house_shell": {"box": Vector3(5.0, 2.6, 3.2), "y_offset": 1.29, "footprint": Vector2(6.0, 4.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"ruins_corner": {"box": Vector3(7.9, 2.9, 5.0), "y_offset": 1.32, "footprint": Vector2(9.0, 6.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"ruinset_collapsed_block": {"box": Vector3(12.6, 2.8, 8.2), "y_offset": 1.41, "footprint": Vector2(14.0, 9.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"ruinset_compound": {"box": Vector3(12.2, 2.6, 7.4), "y_offset": 1.29, "footprint": Vector2(13.5, 8.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"ruinset_courtyard": {"box": Vector3(7.3, 2.8, 6.5), "y_offset": 1.41, "footprint": Vector2(8.5, 7.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"ruinset_defense_corner": {"box": Vector3(8.1, 2.8, 7.3), "y_offset": 1.41, "footprint": Vector2(9.5, 8.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"ruinset_street_row": {"box": Vector3(12.7, 2.8, 4.2), "y_offset": 1.41, "footprint": Vector2(14.0, 5.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"runway_section": {"box": Vector3(0, 0, 0), "y_offset": 0.0, "footprint": Vector2(51.0, 52.0), "scale": 1.0},  # walkable/decoration - no collision
	"shower_point": {"box": Vector3(3.0, 3.0, 3.2), "y_offset": 1.47, "footprint": Vector2(4.0, 4.5), "scale": 1.0},
	"stone_arch_bridge": {"box": Vector3(26.0, 9.5, 6.8), "y_offset": 4.75, "footprint": Vector2(27.0, 8.0), "scale": 1.0},
	"supply_depot": {"box": Vector3(8.3, 2.0, 5.3), "y_offset": 0.92, "footprint": Vector2(9.5, 6.5), "scale": 1.0},
	"tank_revetment": {"box": Vector3(83.4, 19.0, 107.7), "y_offset": 9.50, "footprint": Vector2(84.5, 109.0), "scale": 1.0},
	"tank_trap": {"box": Vector3(10.4, 10.5, 10.5), "y_offset": 5.25, "footprint": Vector2(11.5, 11.5), "scale": 1.0},
	"tent": {"box": Vector3(10.0, 5.2, 3.9), "y_offset": 6.42, "footprint": Vector2(11.0, 5.0), "scale": 1.0},
	"toc": {"box": Vector3(6.4, 6.0, 4.4), "y_offset": 3.00, "footprint": Vector2(7.5, 5.5), "scale": 1.0},
	"uh1_huey": {"box": Vector3(14.6, 3.9, 13.3), "y_offset": 0.89, "footprint": Vector2(16.0, 14.5), "scale": 1.0},
	"underground_hospital": {"box": Vector3(4.0, 2.3, 3.5), "y_offset": 0.40, "footprint": Vector2(5.0, 4.5), "scale": 1.0},
	"us_army_bridge": {"box": Vector3(4.0, 4.2, 17.4), "y_offset": 0.88, "footprint": Vector2(5.0, 18.5), "scale": 1.0},
	"us_bulldozer": {"box": Vector3(4.5, 3.0, 6.2), "y_offset": 1.31, "footprint": Vector2(6.0, 7.5), "scale": 1.0},
	"us_jeep": {"box": Vector3(4.6, 2.0, 11.3), "y_offset": 1.00, "footprint": Vector2(6.0, 12.5), "scale": 1.0},
	"villa": {"box": Vector3(15.0, 8.5, 13.5), "y_offset": 4.25, "footprint": Vector2(16.0, 14.5), "scale": 1.0},
	"village_pagoda": {"box": Vector3(12.0, 8.4, 10.0), "y_offset": 4.20, "footprint": Vector2(13.0, 11.0), "scale": 1.0},
	"wall_corner_tall": {"box": Vector3(2.7, 2.8, 2.2), "y_offset": 1.41, "footprint": Vector2(4.0, 3.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"wall_remnant": {"box": Vector3(3.1, 1.9, 3.1), "y_offset": 0.96, "footprint": Vector2(4.5, 4.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"wall_straight_door": {"box": Vector3(4.2, 1.8, 1.6), "y_offset": 0.91, "footprint": Vector2(5.5, 3.0), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"wall_u_ruin": {"box": Vector3(3.4, 2.5, 2.3), "y_offset": 1.24, "footprint": Vector2(4.5, 3.5), "scale": 1.0, "mesh": true},  # trimesh in GLB
	"wooden_bridge": {"box": Vector3(18.9, 3.6, 4.1), "y_offset": 1.82, "footprint": Vector2(20.0, 5.5), "scale": 1.0},
}


static func get_entry(model_name: String) -> Dictionary:
	return STRUCTURES.get(model_name, {"box": Vector3(3, 2, 3), "y_offset": 1.0, "footprint": Vector2(4, 4), "scale": 1.0})
