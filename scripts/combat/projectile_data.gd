## projectile_data.gd - Resource definition for bullet projectile types
@tool
class_name ProjectileData
extends Resource

@export var id: String = ""
@export var display_name: String = ""

@export_group("Movement")
@export var speed: float = 200.0  ## Bullet speed in m/s
@export var gravity_scale: float = 0.0  ## 0 = no drop, 1 = full gravity
@export var lifetime: float = 3.0  ## Max time before expiring

@export_group("Damage")
## ADR-016: flat base damage per hit — deterministic (see WeaponData.base_damage).
@export var base_damage: int = 8
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL

@export_group("Status Effects")
@export var stagger_power: float = 0.0
@export var knockback_force: float = 0.0

@export_group("Area of Effect")
@export var aoe_radius: float = 0.0  ## 0 = no AOE (for grenades/explosives)

@export_group("Fuze")
## ARMING DISTANCE, in METRES. A real RPG warhead is DROP-SAFE - it arms only
## after launch and a short travel. Inside this distance the round is an inert
## lump of steel: it strikes, it does NOT detonate. 0 = armed at the muzzle
## (thrown grenades run on a TIME fuze instead and are unaffected).
@export var arming_distance: float = 0.0
## Kinetic bite of an UNARMED strike, as a fraction of base_damage. A 1.8kg
## warhead at 84 m/s still ruins the man it hits - it just does not explode.
@export_range(0.0, 1.0) var dud_impact_frac: float = 0.2
## Self-destruct at the end of the run (real PG-7 rounds burn out and detonate
## at 3.8-6s). Requires the round to have ARMED first; a dud never blows.
@export var self_destruct: bool = true

@export_group("Collision")
@export var collision_radius: float = 0.05  ## Bullet is small
@export var hits_enemies: bool = true
@export var hits_players: bool = false
@export var hits_world: bool = true

@export_group("Visuals")
@export var mesh_path: String = ""
@export var scale: Vector3 = Vector3(0.1, 0.1, 0.1)
## rad/s of end-over-end spin for a FINLESS store (napalm can, CBU dispenser):
## it renders as a tumbling canister instead of a warhead cone. 0 = flies true.
@export var tumble_rate: float = 0.0

@export_group("Trail Effect")
@export var has_trail: bool = true
@export var trail_color: Color = Color(1.0, 0.9, 0.5, 0.8)
@export var trail_lifetime: float = 0.1
@export var trail_width: float = 0.02


## Flat per-hit damage (ADR-016). Deterministic.
func get_damage() -> int:
	return maxi(1, base_damage)
