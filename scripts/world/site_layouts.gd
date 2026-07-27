## site_layouts.gd - Data-driven site layouts stamped by SitePlanner.
## Offsets in meters relative to site center; rotation in degrees.
class_name SiteLayouts
extends RefCounted

## The generated village set (tools/gen_village.py + village_set.json). Fifteen huts
## against a 7-10 hut stamp, so a village no longer repeats itself - the old pool was
## six models for the same draw. Damage tiers are IN the pool on purpose: a burned
## husk beside a lived-in house is the story the seed tells for free.
const VILLAGE_HUT_MODELS: Array[String] = [
	"res://assets/world/building models/structures/village/nha_tranh_01.glb",
	"res://assets/world/building models/structures/village/nha_tranh_02.glb",
	"res://assets/world/building models/structures/village/nha_tranh_03.glb",
	"res://assets/world/building models/structures/village/nha_san_01.glb",
	"res://assets/world/building models/structures/village/nha_san_02.glb",
	"res://assets/world/building models/structures/village/nha_san_03.glb",
	"res://assets/world/building models/structures/village/nha_ruong_01.glb",
	"res://assets/world/building models/structures/village/nha_ruong_02.glb",
	"res://assets/world/building models/structures/village/bo_lua_01.glb",
	"res://assets/world/building models/structures/village/bo_lua_02.glb",
	"res://assets/world/building models/structures/village/lean_to_01.glb",
	"res://assets/world/building models/structures/village/lean_to_02.glb",
	"res://assets/world/building models/structures/village/buffalo_shed_01.glb",
	"res://assets/world/building models/structures/village/pigsty_01.glb",
	"res://assets/world/building models/structures/village/drying_rack_01.glb",
]

## Centre pieces - the dinh's roof is the one silhouette visible over the thatch.
const VILLAGE_CENTER_MODELS: Array[String] = [
	"res://assets/world/building models/structures/village/dinh_01.glb",
	"res://assets/world/building models/structures/village/chua_01.glb",
	"res://assets/world/building models/structures/village/village_well_01.glb",
	"res://assets/world/building models/structures/village/bell_frame_01.glb",
]

## Boundary and paddy-edge pieces. The bamboo hedge is the real Vietnamese village
## wall and it is genuine cover, so it is placed, not painted on.
const VILLAGE_EDGE_MODELS: Array[String] = [
	"res://assets/world/building models/structures/village/bamboo_hedge_01.glb",
	"res://assets/world/building models/structures/village/village_gate_01.glb",
	"res://assets/world/building models/structures/village/ancestor_tomb_01.glb",
	"res://assets/world/building models/structures/village/fence_run_01.glb",
	"res://assets/world/building models/structures/village/paddy_bund_01.glb",
]

## Yard clutter - what a working village leaves lying between the houses. Placed in
## the yard band, not the edge, because a cart parked 40m out reads as abandoned.
const VILLAGE_YARD_MODELS: Array[String] = [
	"res://assets/world/building models/structures/village/haystack_01.glb",
	"res://assets/world/building models/structures/village/ox_cart_01.glb",
	"res://assets/world/building models/structures/village/fence_run_01.glb",
]

const CACHE_MODEL: String = "res://assets/world/building models/structures/vc_nva/weapons_cache.glb"
const TUNNEL_MODEL: String = "res://assets/world/building models/structures/vc_nva/tunnel_entrance_hidden.glb"

## VC village scatter props. 0-2 of these get sprinkled between huts per village —
## spider holes tucked behind a hut, a punji pit on an approach. These are read
## by stamp_village() in addition to the hut ring + center model.
const VILLAGE_SCATTER_MODELS: Array[String] = [
	"res://assets/world/building models/structures/vc_nva/spider_hole.glb",
	"res://assets/world/building models/structures/vc_nva/punji_pit.glb",
]


## Villages scatter their huts across a footprint with a hard minimum separation
## between any two structures (no tight ring) - use the space.
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
## prop_class (baked onto prop_* marker empties by gen_village.py) -> candidate props.
## Interior dressing anchors to these markers instead of the radial annuli below, which
## is why village props used to float in the open with no relation to the buildings.
## storage_low is the crawl space under a stilt deck - only low items belong there.
const INTERIOR_PROPS: Dictionary = {
	"hearth": ["cooking_hearth"],
	"sleep": ["produce_mat"],
	"storage": ["rice_basket_full", "flour_sacks", "veg_basket", "water_jars"],
	"storage_low": ["firewood", "rice_basket_full"],
	"altar": ["clay_bowls"],
	"offering": ["clay_bowls"],
	"furniture": ["market_table_fish"],
	"floor": ["produce_mat"],
}

const VILLAGE_PROP_ZONES: Dictionary = {
	"center": Vector2(0.0, 0.35),
	"yard":   Vector2(0.35, 0.8),
	"edge":   Vector2(0.8, 1.1),
}

## Rigged farm animals (Quaternius CC0, recolored): Idle anim v1, wander later.
const VILLAGE_ANIMAL_DIR: String = "res://assets/world/animals/"
## Free-roaming counts. These are the animals that are NOT already placed at a
## home_<species> marker - the homes seed the herd, this is the overflow wandering
## the village. Chickens were missing entirely; only mission_generator ever spawned one.
const VILLAGE_ANIMALS: Dictionary = {
	"pig": [0, 1],
	"cow": [0, 1],
	"water_buffalo": [0, 1],
	"chicken": [2, 4],
}

## Animals bed down at the home_<species> markers gen_village.py bakes into the
## buildings that house them - the pigsty, the buffalo shed, under a stilt deck, beside
## the haystack. A day/night routine has somewhere to return TO, and graze_* markers on
## the paddy give it somewhere to go by day.
const ANIMAL_HOME_PREFIX: String = "home_"
const ANIMAL_GRAZE_PREFIX: String = "graze_"
