## ballistics.gd - launch an unguided warhead onto a chosen point.
##
## Indirect fire is aimed at a MAP POINT, not down a barrel: the gun is off the
## map, the sheaf is already scattered, and the round has to arrive where the
## player was shown it would. So the launch velocity is SOLVED backwards from the
## impact point rather than fired and hoped for.
class_name Ballistics


## Velocity that carries a round from `from` to `to` in exactly `flight_time`.
##
## Solved against the integrator ProjectileBase actually runs, not the continuous
## equation: it steps velocity first and then position, which lands a round short
## by g*t*dt/2 over the flight. Ignoring that puts a 6-second shell half a metre
## deep. `dt` is the physics tick.
static func solve_velocity(from: Vector3, to: Vector3, flight_time: float, gravity: float, dt: float) -> Vector3:
	var t: float = maxf(0.05, flight_time)
	var v: Vector3 = (to - from) / t
	v.y += gravity * (t + dt) * 0.5
	return v


## Spawn a warhead already on the arc that ends at `to`. `terminal` is the
## detonation effect (see ProjectileBase.terminal_effect); `terrain` is the ground
## authority that guarantees the round stops there.
static func fire_arc(
		data: ProjectileData,
		from: Vector3,
		to: Vector3,
		flight_time: float,
		terrain: TerrainManager,
		terminal: Callable,
		source: Node = null) -> ProjectileBase:
	if data == null:
		return null
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * data.gravity_scale
	var dt: float = 1.0 / float(maxi(1, Engine.physics_ticks_per_second))
	var v: Vector3 = solve_velocity(from, to, flight_time, g, dt)
	var shell: ProjectileBase = CombatManager.spawn_projectile(data, source, from, v.normalized())
	if shell == null:
		return null
	shell.velocity = v
	shell.current_speed = v.length()
	shell.terrain = terrain
	shell.terminal_effect = terminal
	return shell


## Where an off-map gun's round comes from: high on the incoming azimuth, far
## enough out that it is a falling shell and not a mortar bomb appearing overhead.
static func firing_point(impact: Vector3, azimuth: Vector3, height: float, offset: float) -> Vector3:
	var flat: Vector3 = Vector3(azimuth.x, 0.0, azimuth.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	return impact - flat * offset + Vector3.UP * height
