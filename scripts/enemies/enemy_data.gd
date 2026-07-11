## enemy_data.gd - Resource class for enemy definitions
@tool
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Stats")
@export var max_hp: int = 80
@export var move_speed: float = 4.0
@export var preferred_range: float = 15.0  ## Ideal combat distance
@export var alert_range: float = 20.0  ## Detection range

@export_group("Combat")
@export var weapon_path: String = ""  ## Path to WeaponData resource
@export var accuracy_modifier: float = 1.0  ## spread MULTIPLIER: >1 = LESS accurate (VC 1.15), <1 = crack shot (NVA 0.95)
@export var aggression: float = 0.5  ## 0 = defensive, 1 = aggressive

@export_group("Behavior")
@export var uses_cover: bool = true
@export var flanks: bool = false
@export var retreats_when_hurt: bool = false
@export var retreat_hp_threshold: float = 0.25

@export_group("Tuning")
## Seconds of CONTINUOUS exposure before this archetype's fire converges to
## full accuracy (DESIGN 4.2: accuracy ramps with exposure time, never with
## alertness). NVA lock on fast; a farmer gives you a long window.
@export var exposure_ramp_time: float = 2.5
## 0 = timid, 1 = fearless. Inverse-biases char_self_preservation the same way
## aggression biases char_aggression - archetype identity, not pure spawn RNG.
@export var courage: float = 0.5

@export_group("Visuals")
## 8-directional billboard sprites, NOT a GLTF. Resolves to
## res://assets/NPCs/<sprite_faction>/<sprite_unit>/<sprite_weapon>/<action>/
##
## Three fields rather than one path string: SpriteLibrary needs the unit id for
## its cache key anyway, and a single path invites typos that fail silently at
## runtime. Leave sprite_unit empty to keep the capsule placeholder (units that
## are still rendering, or the WW2 holdovers).
##
## NOTE the hard pairing: each unit was rendered holding exactly one weapon, so
## sprite_weapon and weapon_path must be kept consistent by hand. A sprite
## holding a PPSh while the ballistics say AK-47 is the kind of thing nobody
## notices for six months and then cannot unsee.
@export var sprite_faction: String = ""   ## "Vietcong and NVA"
@export var sprite_unit: String = ""      ## "vc1_farmer"
@export var sprite_weapon: String = ""    ## "ak47"
@export var color: Color = Color(0.4, 0.4, 0.3)  ## capsule placeholder tint, and sprite base modulate
