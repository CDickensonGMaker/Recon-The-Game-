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

## THE VIEWMODEL LENS (Caleb: "guns look small - other games put them way closer
## to the screen, you see little of the arms"). That look is not a POSITION, it
## is a FOCAL LENGTH: the gun is rendered by its own camera with a NARROWER field
## of view than the world. A wide world lens (75) makes anything near it look
## small and far; a 60 lens magnifies the receiver toward the screen and crops
## the arms out of frame, which is exactly the Half-Life / Counter-Strike read.
## CS2 ships 68 (54-68 range) against a 90 world; CoD-likes sit near 65.
## LOWER = bigger, closer, more in-your-face. Per weapon, because a pistol wants
## a different framing than an M60.
@export_range(35.0, 90.0) var viewmodel_fov: float = 60.0

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
## SIGHT ZERO (ballistics audit 2026-07-12, F2): the sights are zeroed at this
## range - the muzzle rides fractionally high so the falling round crosses the
## sightline HERE. Without it a rifle shoots 0.5m low at 300m and cannot hit a
## standing man (we were effectively zeroed at 0m). Every reference milsim
## zeroes: Red Orchestra, Arma, HLL. Beyond the zero you hold over, as in life.
@export var zero_range: float = 200.0  ## m (pistols ~25, MGs ~300)
@export var projectile_data_path: String = ""  ## Path to ProjectileData resource

@export_group("Tracer")
## nx9n (data-driven tracers): every Nth round streaks (1 = all, 0 = never).
## The streak IS the bullet (BulletSystem) - it flies at projectile_speed.
## Doctrine: MG belts 1-in-4, rifles 1-in-5, bolt guns and pistols dark.
@export var tracer_ratio: int = 4
## US = red-orange, ComBloc = green (nx9n; kills the hardcoded enemy green).
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
## Bench-calibrated bore direction, viewmodel-local (viewmodel_editor I/K/U/O:
## lay the laser along the barrel by eye, Ctrl+S persists). ZERO = fall back
## to the contract axis (root -Z). Needed because arms viewmodels are baked
## POSED holds - no scene axis is guaranteed parallel to the barrel, and the
## Blender muzzle empties were never aimed down the bore (2026-07-11).
@export var bore_dir: Vector3 = Vector3.ZERO
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


## Sight-zero elevation (radians): the flat-fire launch angle that puts the
## round back on the sightline at zero_range. theta = g*R / (2*v^2) - exact
## enough at rifle speeds, and it is the same maths the armorer uses.
func zero_elevation() -> float:
	if projectile_speed < 1.0 or zero_range < 1.0:
		return 0.0
	return (9.8 * zero_range) / (2.0 * projectile_speed * projectile_speed)


## Elevation to put the round ON a target at `dist` (the trained soldier's
## hold-over). AI uses this; the player gets the fixed zero above and holds
## over himself.
func elevation_for(dist: float) -> float:
	if projectile_speed < 1.0 or dist < 1.0:
		return 0.0
	return (9.8 * dist) / (2.0 * projectile_speed * projectile_speed)
