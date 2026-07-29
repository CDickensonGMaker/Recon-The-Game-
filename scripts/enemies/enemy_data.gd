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
## <1 = harder for his foes to spot him. A DEFENDER multiplies its own sight cap by
## this before comparing range, so a low value shrinks the distance at which he is
## seen (sappers ~0.6). Only ever multiplies the cap DOWN - 1.0 leaves it untouched,
## so every existing .tres is unaffected. Leans on SightCap; never makes a man invisible.
@export_range(0.0, 1.0) var stealth: float = 1.0
## A demolition infiltrator, not a rifleman: he carries a satchel and NEVER fires,
## so no muzzle flash and no gunshot betray his crawl. Silence is an INVARIANT here,
## not an accident of the assault-move override - it holds even if the objective clears.
@export var silent_infiltrator: bool = false

@export_group("Behavior")
## Battlefield theater role (Summoner ruling 2026-07-29): he runs to DOWNED
## squadmates and drags them out of the fight. Flavor - he never revives them
## back into combat; the US squad medic remains the only true reviver.
@export var combat_medic: bool = false
@export var uses_cover: bool = true
@export var flanks: bool = false
@export var retreats_when_hurt: bool = false
@export var retreat_hp_threshold: float = 0.25

@export_group("Tuning")
## Seconds of CONTINUOUS exposure before this archetype's fire converges to full accuracy.
@export var exposure_ramp_time: float = 2.5
## 0 = timid, 1 = fearless. Inverse-biases char_self_preservation.
@export var courage: float = 0.5
## How long he KEEPS LOOKING FOR YOU after losing contact, and how far out he
## pushes the search net. NOT courage (that is whether he BREAKS under fire).
##   0.25 farmer (gives up) .. 0.45 VC .. 0.7 sapper .. 0.9 NVA (does NOT stop)
@export_range(0.0, 1.0) var determination: float = 0.5

@export_group("Visuals")
## Keys for 3D ModelActor clip resolution: SpriteStateMap.clip_for(is_model, weapon,
## intent) picks the anim_library clip; ModelActor.model_exists(sprite_unit)
## gates the rig, falling back to sprite_unit_fallback then the capsule placeholder.
## NOTE the hard pairing: sprite_weapon and weapon_path must be kept consistent by hand.
@export var sprite_faction: String = ""   ## "Vietcong and NVA"
@export var sprite_unit: String = ""      ## "vc_guerilla"
## ART-AHEAD WIRING: what he wears until `sprite_unit` actually exists on disk.
@export var sprite_unit_fallback: String = ""
@export var sprite_weapon: String = ""    ## "ak47"
@export var color: Color = Color(0.4, 0.4, 0.3)  ## capsule placeholder tint, and sprite base modulate
