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
const FIREBASE_HELIPAD_MODEL: String = "res://assets/building models/structures/airfield/psp_helipad.glb"

## Optional interior extras: each firebase rolls 2-4 of these into spare slots so
## no two bases read the same (RTS copy-ins, previously unused).
const FIREBASE_EXTRA_MODELS: Array[String] = [
	"res://assets/building models/structures/firebase/aid_station.glb",
	"res://assets/building models/structures/firebase/ammo_bunker.glb",
	"res://assets/building models/structures/firebase/commo_bunker.glb",
	"res://assets/building models/structures/firebase/mess_hall.glb",
	"res://assets/building models/structures/firebase/mortar_pit.glb",
	"res://assets/building models/structures/firebase/latrine.glb",
	"res://assets/building models/structures/firebase/quonset_hut.glb",
	"res://assets/building models/structures/firebase/toc.glb",
	"res://assets/building models/structures/firebase/supply_depot.glb",
]
## Spare interior slots (clear of tower/hootches/bunkers/vehicles/helipad).
const FIREBASE_EXTRA_SLOTS: Array[Vector2] = [
	Vector2(0, 14), Vector2(-18, 0), Vector2(14, -2), Vector2(-4, -20), Vector2(-20, 12),
]

## Vehicle props parked in firebases.
const FIREBASE_VEHICLES: Array[String] = [
	"res://assets/building models/vehicles/m151_mutt_gun_jeep.glb",
	"res://assets/building models/vehicles/m113_apc.glb",
]

const FIREBASE_PERIMETER_RADIUS: float = 30.0
const FIREBASE_WIRE_RADIUS: float = 38.0
const FIREBASE_HELIPAD_OFFSET := Vector2(18, 0)

## Villages scatter their huts across a footprint with a hard minimum separation
## between any two structures (no tight ring). ADR-027-D: use the space.
const VILLAGE_MIN_STRUCTURE_SEP: float = 14.0
const VILLAGE_FOOTPRINT_RADIUS: float = 34.0
