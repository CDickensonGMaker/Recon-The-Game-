## weapon_data.gd - Resource class for FPS weapon definitions
@tool
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Firing Properties")
@export var firing_mode: Enums.FiringMode = Enums.FiringMode.SEMI_AUTO
@export var fire_rate: float = 600.0  ## Rounds per minute
@export var magazine_size: int = 30
@export var reload_time: float = 2.5  ## Seconds

@export_group("Damage")
## ADR-016: flat base damage per hit — deterministic. All variance comes from
## range falloff, hitzone multipliers, and the situation sim (never from rolls).
## Values derived from the retired RECON dice averages (e.g. 5d10 -> 28).
@export var base_damage: int = 20
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
## ADR-016 amendment (shotguns): >1 = fire this many rays per trigger pull,
## base_damage is PER PELLET, and damage aggregates per target+zone so
## locational rules and gore thresholds see one hit event. Spread is spatial
## variance (like recoil), not a damage roll — determinism holds per pellet.
@export var pellet_count: int = 1
@export var pellet_spread_deg: float = 5.5

@export_group("Accuracy")
@export var base_spread: float = 2.0  ## Degrees of spread at hip
@export var ads_spread_mult: float = 0.3  ## Multiplier when ADS (30%)
@export var recoil_vertical: float = 2.5  ## Degrees kick up
@export var recoil_horizontal: float = 0.5  ## Degrees random horizontal

@export_group("ADS Properties")
@export var ads_fov: float = 55.0  ## FOV when aiming down sights
@export var ads_move_mult: float = 0.6  ## Movement speed multiplier when ADS

@export_group("Range")
@export var effective_range: float = 50.0  ## Meters - full damage range
@export var max_range: float = 100.0  ## Meters - damage falloff beyond
## Damage retained at max_range (linear falloff from effective_range). Author
## HIGH for rifles (a Mauser stays lethal), LOW for pistols/SMG. 1.0 = no falloff.
@export_range(0.2, 1.0) var min_damage_mult: float = 0.6

@export_group("Projectile")
@export var projectile_speed: float = 400.0  ## m/s
@export var projectile_data_path: String = ""  ## Path to ProjectileData resource

@export_group("Feel")
## First aimed shot kicks harder than sustained fire - rewards trigger discipline.
@export var recoil_first_shot_mult: float = 1.5
## Muzzle climb per round under sustained auto fire (+fraction/round).
@export var recoil_climb_per_shot: float = 0.06
@export var recoil_climb_max: float = 1.8
## Exponential recovery constant (per second). Higher = snappier return to aim.
@export var recoil_recovery: float = 12.0

@export_group("Audio")
## Audio is resolved BY CONVENTION from `id`: AudioManager looks for
## res://assets/audio/sfx/weapons/fire_<id>_1..3.wav, fire_<id>_dist.wav,
## mech_<id>.wav, reload_<id>.wav, bolt_<id>.wav. Drop a real recording at the
## same path to replace the synth render -- no code or resource change.
## These fields are just the per-weapon mix.
@export_range(-24.0, 12.0) var fire_volume_db: float = 0.0
@export_range(0.0, 0.25) var fire_pitch_variance: float = 0.04
@export var audio_max_distance: float = 350.0
@export var audio_unit_size: float = 16.0
## Supersonic rounds add a ballistic crack for shots passing near the listener.
## .45 ACP / 9mm ball are subsonic -> false -> muzzle report only.
@export var is_supersonic: bool = true

@export_group("Visuals")
@export var model_path: String = ""  ## Path to weapon GLTF model
@export var viewmodel_scale: float = 1.0  ## Relative scale (1.0 = reference size like Thompson)
@export var hip_position: Vector3 = Vector3(0.3, -0.2, -0.4)
@export var ads_position: Vector3 = Vector3(0, -0.15, -0.3)
@export var hip_rotation: Vector3 = Vector3(0, 0, 0)
@export var ads_rotation: Vector3 = Vector3(0, 0, 0)


## Flat per-hit damage (ADR-016). Deterministic — same weapon, same base, every hit.
func get_damage() -> int:
	return maxi(1, base_damage)


## Damage scale at a given distance. Full damage to effective_range, then linear
## falloff to min_damage_mult at max_range. Applied to the flat base BEFORE
## the hitzone multiplier, so a headshot stays a headshot at any range.
func damage_multiplier_at(distance: float) -> float:
	if distance <= effective_range:
		return 1.0
	if distance >= max_range:
		return min_damage_mult
	var t: float = (distance - effective_range) / maxf(0.001, max_range - effective_range)
	return lerpf(1.0, min_damage_mult, t)


## Get damage string for UI display (e.g., "28")
func get_damage_string() -> String:
	return "%d" % base_damage


## Get fire rate in seconds between shots
func get_fire_delay() -> float:
	return 60.0 / fire_rate


## Calculate spread based on ADS state (0-1 lerp value)
func get_spread(ads_amount: float) -> float:
	return base_spread * lerp(1.0, ads_spread_mult, ads_amount)
