## weapon_data.gd - Resource class for FPS weapon definitions
@tool
class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var armory_tier: int = 0  ## Title tier (CampaignState.title_tier) required on the armory rack

@export_group("Firing Properties")
@export var firing_mode: Enums.FiringMode = Enums.FiringMode.SEMI_AUTO
@export var fire_rate: float = 600.0  ## Rounds per minute
@export var magazine_size: int = 30
@export var reload_time: float = 2.5  ## Seconds
@export var empty_reload_time: float = 0.0  ## Seconds from an empty magazine; 0 = same as reload_time
@export var jam_clear_time: float = 1.1  ## Seconds - tap-rack duration, authored to the clear animation

@export_group("Damage")
## ADR-016: flat damage per hit, deterministic. All variance comes from range
## falloff, hitzone multipliers and the situation sim — never from a roll.
@export var base_damage: int = 27
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
## >1 = rays per trigger pull; base_damage is PER PELLET and aggregates per
## target+zone, so one shell is one hit event (ADR-016 amendment).
@export var pellet_count: int = 1
@export var pellet_spread_deg: float = 5.5

@export_group("Accuracy")
@export var base_spread: float = 2.0  ## Degrees of spread at hip
@export var ads_spread_mult: float = 0.3  ## Multiplier when ADS (30%)
@export var recoil_vertical: float = 2.5  ## Degrees kick up
@export var recoil_horizontal: float = 0.5  ## Degrees random horizontal

## THE VIEWMODEL LENS (ADR-034): the gun renders through its own NARROWER
## camera via the lens shader. LOWER = bigger, closer to the screen. Applied by
## ViewmodelLens, shared by weapon_holder.gd and the bench.
@export_range(35.0, 90.0) var viewmodel_fov: float = 60.0

@export_group("ADS Properties")
@export var ads_fov: float = 55.0  ## FOV when aiming down sights
@export var ads_move_mult: float = 0.6  ## Movement speed multiplier when ADS
## Optical scope: when set, full ADS swaps the viewmodel for this fullscreen
## overlay (transparent circle in a dark frame; ScopeOverlay draws the reticle)
## and ads_fov carries the magnification. Null = iron sights.
@export var scope_overlay: Texture2D = null

@export_group("Range")
@export var effective_range: float = 50.0  ## Meters - full damage range
@export var max_range: float = 100.0  ## Meters - damage falloff beyond
## Damage retained at max_range (linear falloff from effective_range). Author
## HIGH for rifles (a Mauser stays lethal), LOW for pistols/SMG. 1.0 = no falloff.
@export_range(0.2, 1.0) var min_damage_mult: float = 0.6

@export_group("Projectile")
@export var projectile_speed: float = 400.0  ## m/s
## SIGHT ZERO: the muzzle rides fractionally high so the falling round crosses
## the sightline at THIS range. Beyond the zero you hold over, as in life.
@export var zero_range: float = 200.0  ## m (pistols ~25, MGs ~300)
@export var projectile_data_path: String = ""  ## Path to ProjectileData resource

@export_group("Tracer")
## Every Nth round streaks (1 = all, 0 = never). The streak IS the bullet and
## flies at projectile_speed. MG belts 1-in-4, rifles 1-in-5, pistols dark.
@export var tracer_ratio: int = 4
## US = red-orange, ComBloc = green.
@export var tracer_color: Color = Color(1.0, 0.5, 0.3, 1.0)

@export_group("Feel")
## First aimed shot kicks harder than sustained fire - rewards trigger discipline.
@export var recoil_first_shot_mult: float = 1.5
## Muzzle climb per round under sustained auto fire (+fraction/round).
@export var recoil_climb_per_shot: float = 0.06
@export var recoil_climb_max: float = 1.8
## Exponential recovery constant (per second). Higher = snappier return to aim.
@export var recoil_recovery: float = 12.0

@export_group("Audio")
## NAMING CONTRACT: audio is resolved from `id` alone — AudioManager looks for
## res://assets/audio/sfx/weapons/fire_<id>_1..3.wav, fire_<id>_dist.wav,
## mech_<id>.wav, reload_<id>.wav, bolt_<id>.wav. These fields are only the mix.
@export_range(-24.0, 12.0) var fire_volume_db: float = 0.0
@export_range(0.0, 0.25) var fire_pitch_variance: float = 0.04
@export var audio_max_distance: float = 350.0
@export var audio_unit_size: float = 16.0
## Supersonic rounds add a ballistic crack for shots passing near the listener.
## .45 ACP / 9mm ball are subsonic -> false -> muzzle report only.
@export var is_supersonic: bool = true

@export_group("Visuals")
@export var model_path: String = ""  ## Path to weapon GLTF model
## Bench-calibrated bore direction, viewmodel-local (viewmodel_editor: I/K/U/O).
## HIP: used when ads_transition = 0. ZERO = fall back to the contract axis (root -Z).
@export var bore_dir: Vector3 = Vector3.ZERO
## ADS: separate bore zero used when fully aimed. ZERO = fall back to bore_dir.
## Two independent aiming systems so hip crosshair and ADS sights can each be
## tuned without breaking the other.
@export var ads_bore_dir: Vector3 = Vector3.ZERO
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


## Get fire rate in seconds between shots
func get_fire_delay() -> float:
	return 60.0 / fire_rate


## Calculate spread based on ADS state (0-1 lerp value)
func get_spread(ads_amount: float) -> float:
	return base_spread * lerp(1.0, ads_spread_mult, ads_amount)


## Sight-zero elevation in RADIANS: the flat-fire launch angle that puts the round
## back on the sightline at zero_range. theta = g*R / (2*v^2).
func zero_elevation() -> float:
	if projectile_speed < 1.0 or zero_range < 1.0:
		return 0.0
	return (9.8 * zero_range) / (2.0 * projectile_speed * projectile_speed)


## Elevation (radians) to put the round ON a target at `dist` - the hold-over.
## The AI uses this; the player gets the fixed zero and holds over himself.
func elevation_for(dist: float) -> float:
	if projectile_speed < 1.0 or dist < 1.0:
		return 0.0
	return (9.8 * dist) / (2.0 * projectile_speed * projectile_speed)
