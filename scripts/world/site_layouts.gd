## site_layouts.gd - Data-driven site layouts stamped by SitePlanner.
## Offsets in meters relative to site center; rotation in degrees.
class_name SiteLayouts
extends RefCounted

const VILLAGE_HUT_MODELS: Array[String] = [
	"res://assets/building models/structures/village/thatched_hut.glb",
	"res://assets/building models/structures/village/stilt_house.glb",
	"res://assets/building models/structures/village/three_room_house.glb",
	"res://assets/building models/structures/village/rice_storage.glb",
	"res://assets/building models/structures/village/bell_tower.glb",
	"res://assets/building models/structures/village/village_pagoda.glb",
]

const VILLAGE_CENTER_MODELS: Array[String] = [
	"res://assets/building models/structures/village/well.glb",
	"res://assets/building models/structures/village/communal_house.glb",
	"res://assets/building models/structures/village/pagoda.glb",
	"res://assets/building models/structures/village/bell_tower.glb",
]

const CACHE_MODEL: String = "res://assets/building models/structures/vc_nva/weapons_cache.glb"
const TUNNEL_MODEL: String = "res://assets/building models/structures/vc_nva/tunnel_entrance_hidden.glb"

## VC village scatter props. 0-2 of these get sprinkled between huts per village —
## spider holes tucked behind a hut, a punji pit on an approach. These are read
## by stamp_village() in addition to the hut ring + center model.
const VILLAGE_SCATTER_MODELS: Array[String] = [
	"res://assets/building models/structures/vc_nva/spider_hole.glb",
	"res://assets/building models/structures/vc_nva/punji_pit.glb",
]

## The procedural firebase died with fsb_main.glb (task 6b, ADR-029). The one
## surviving piece: sandbags, still stamped by outposts and AA sites.
const FIREBASE_SANDBAG: String = "res://assets/building models/structures/firebase/sandbag_light.glb"

## Villages scatter their huts across a footprint with a hard minimum separation
## between any two structures (no tight ring). ADR-027-D: use the space.
const VILLAGE_MIN_STRUCTURE_SEP: float = 14.0
const VILLAGE_FOOTPRINT_RADIUS: float = 34.0

## Caleb-authored market/life props (source: production/props_workshop/village_market.blend).
## DRESSING v1 by Summoner decree: no colliders; a cover pass is a later bead.
## zone: annulus of the village footprint - center [0, 0.35) / yard [0.35, 0.8) /
## edge [0.8, 1.1). count: [min, max] per village.
const VILLAGE_PROP_DIR: String = "res://assets/civilians/props/market/"
const VILLAGE_PROPS: Dictionary = {
	"market_table_fish": {"zone": "center", "count": [1, 1]},
	"hanging_rack":      {"zone": "center", "count": [1, 1]},
	"cooking_hearth":    {"zone": "center", "count": [1, 2]},
	"produce_mat":       {"zone": "center", "count": [1, 2]},
	"clay_bowls":        {"zone": "center", "count": [1, 2]},
	"flour_sacks":       {"zone": "yard", "count": [1, 3]},
	"water_jars":        {"zone": "yard", "count": [2, 4]},
	"rice_basket_full":  {"zone": "yard", "count": [1, 3]},
	"veg_basket":        {"zone": "yard", "count": [1, 2]},
	"firewood":          {"zone": "yard", "count": [1, 3]},
	"water_buckets":     {"zone": "yard", "count": [1, 2]},
	"chicken_coop":      {"zone": "edge", "count": [1, 2]},
}
const VILLAGE_PROP_ZONES: Dictionary = {
	"center": Vector2(0.0, 0.35),
	"yard":   Vector2(0.35, 0.8),
	"edge":   Vector2(0.8, 1.1),
}

## Rigged farm animals (Quaternius CC0, recolored): Idle anim v1, wander later.
const VILLAGE_ANIMAL_DIR: String = "res://assets/world/animals/"
const VILLAGE_ANIMALS: Dictionary = {
	"pig": [1, 2],
	"cow": [0, 1],
	"water_buffalo": [0, 1],
}
