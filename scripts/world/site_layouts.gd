## site_layouts.gd - Data-driven site layouts stamped by SitePlanner.
## Offsets in meters relative to site center; rotation in degrees.
class_name SiteLayouts
extends RefCounted

const VILLAGE_HUT_MODELS: Array[String] = [
	"res://assets/building models/structures/village/thatched_hut.glb",
	"res://assets/building models/structures/village/stilt_house.glb",
	"res://assets/building models/structures/village/three_room_house.glb",
	"res://assets/building models/structures/village/rice_storage.glb",
]

const VILLAGE_CENTER_MODELS: Array[String] = [
	"res://assets/building models/structures/village/well.glb",
	"res://assets/building models/structures/village/communal_house.glb",
]

const CACHE_MODEL: String = "res://assets/building models/structures/vc_nva/weapons_cache.glb"
const TUNNEL_MODEL: String = "res://assets/building models/structures/vc_nva/tunnel_entrance_hidden.glb"

## Firebase layout: [model_path, offset(Vector2), rotation_deg]
## Perimeter pieces are generated procedurally (rings); these are the interior.
const FIREBASE_INTERIOR := [
	["res://assets/building models/structures/firebase/observation_tower.glb", Vector2(0, 0), 0.0],
	["res://assets/building models/structures/firebase/hootch.glb", Vector2(-12, -6), 0.0],
	["res://assets/building models/structures/firebase/hootch.glb", Vector2(-12, 6), 0.0],
	["res://assets/building models/structures/firebase/sandbag_bunker.glb", Vector2(10, -10), 45.0],
	["res://assets/building models/structures/firebase/sandbag_bunker.glb", Vector2(10, 10), -45.0],
]

const FIREBASE_MG_NEST: String = "res://assets/building models/structures/firebase/mg_nest.glb"
const FIREBASE_SANDBAG: String = "res://assets/building models/structures/firebase/sandbag_light.glb"
const FIREBASE_WIRE: String = "res://assets/building models/structures/firebase/triple_concertina.glb"

## Vehicle props parked in firebases.
const FIREBASE_VEHICLES: Array[String] = [
	"res://assets/building models/vehicles/m151_mutt_gun_jeep.glb",
	"res://assets/building models/vehicles/m113_apc.glb",
]

const FIREBASE_PERIMETER_RADIUS: float = 30.0
const FIREBASE_WIRE_RADIUS: float = 38.0
const FIREBASE_HELIPAD_OFFSET := Vector2(18, 0)
const VILLAGE_RING_RADIUS_MIN: float = 8.0
const VILLAGE_RING_RADIUS_MAX: float = 18.0
