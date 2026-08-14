## spectre_gunship.gd - AC-130 "Spectre": orbits the target pouring down a mixed
## battery. Two guns with two rhythms is the whole identity of the aircraft:
##
##   20mm Vulcan - saturation. A continuous sheet of tracer into a wide beaten
##     zone. Individual rounds are not modelled; a burst lands as one small blast.
##   40mm Bofors - punch. Real shells on real arcs, slow enough to hear coming and
##     to count, each one a shell the pool will not recycle out from under you.
class_name SpectreGunship
extends Node3D

const AIRFRAME_SCENE: PackedScene = preload("res://assets/us/aircraft/ac47_spooky_v2.glb")
## The authored port-battery muzzle empties (gun_muzzle_1..3), cached at _ready.
var _muzzles: Array[Node3D] = []
var _muzzle_i: int = 0
## Night orbit bird, heard more than seen: cull the airframe past ~1200m.
const VIS_END_M: float = 1200.0
const VIS_MARGIN_M: float = 80.0

const ORBIT_RADIUS: float = 160.0
const ORBIT_ALT: float = 130.0
## Pylon-turn bank: left wing low toward the orbit centre. Applied after
## look_at, so it is pure lean - the flight path is unchanged.
const BANK_LEFT_RAD: float = 0.26  # ~15 degrees
const DURATION: float = 30.0

## ---- THE VULCAN, FOR REAL ----
## It used to pick a ground point, paint three decorative tracers at it and apply a small
## explosion there: the tracers carried no damage, and a man behind the berm was spared by a
## visibility guess instead of by the berm. The Bofors below has always fired real arcing
## shells, so one aircraft held two different ideas of what a round is. His ruling,
## 2026-07-29: "what if we made the rounds from all planes real projectiles that travel from
## their points of origin."
##
## Fired per PHYSICS TICK, not on an interval. A 0.35 s interval would have to batch ~32
## rounds into one tick to reach a minigun's rate, and they would all arrive together.
## Slant range sqrt(160^2 + 130^2) = 206 m at 1030 m/s = 0.20 s of flight, so 90 rounds/s
## leaves ~18 in the air: 18 segment raycasts a tick against a whole-level baseline of a
## few, and MAX_BULLETS 500 is nowhere near binding. 90/s is chosen for the ROPE - a tracer
## streak is speed*0.016 = 16.5 m and at tracer_ratio 2 that lights ~148 m of the 206 m line.
const VULCAN_ROUNDS_PER_TICK: int = 3
const VULCAN_HOT_S: float = 2.0
const VULCAN_COLD_S: float = 2.5
## The report keeps its own slower clock: _play_gun reuses ONE voice, so retriggering it
## ninety times a second would leave the aircraft silent.
const VULCAN_REPORT_S: float = 0.35
const VULCAN_WEAPON: String = "res://data/weapons/aircraft_20mm.tres"
## Same universal mask the CAS gun run uses: world, player, hurtboxes, civilians. A gunship's
## fire is as indiscriminate as any other fire in this war (his ruling 2026-07-30 - air can
## kill him; the discipline is in where it is AIMED, and AirTraffic keeps ambient orbits off
## him entirely).
const VULCAN_MASK: int = 1 | 32 | 64 | 512
## BulletSystem suppresses nobody, and the old fake explosion was this gun's only source of
## it. Suppression is most of what makes Spooky frightening from the ground, so it is applied
## per burst from the aim point rather than lost with the explosion.
const VULCAN_SUPPRESS_M: float = 18.0
## The beaten zone must LOOK beaten (decree 2026-08-04: a gunship pass that leaves
## no marks is convicted): every few seconds of hot gun, one shallow scrape +
## veg-clear + scar somewhere in the zone. ~5 over a 30s orbit.
const VULCAN_CHEW_S: float = 4.0

const BOFORS_INTERVAL: float = 1.2
## The 40mm walks the inner half of the zone - the heavy gun is aimed, the Vulcan
## saturates.
const BOFORS_ZONE_FRAC: float = 0.55
const BOFORS_SHELL: String = "res://data/projectiles/spectre_40mm.tres"
const BOFORS_BLAST_M: float = 5.0
const BOFORS_DAMAGE: int = 120

var target: Vector3
var terrain: TerrainManager
var _angle: float = 0.0
var _age: float = 0.0
var _bofors_timer: float = 0.6
var _bofors_count: int = 0
var _chew_timer: float = VULCAN_CHEW_S
var _duty: float = 0.0            ## seconds into the current hot/cold cycle
var _report_timer: float = 0.0
static var _vulcan_wd: WeaponData = null
var _drone: AudioStreamPlayer3D
var _gun_audio: AudioStreamPlayer3D = null

const PROP_LOOP := preload("res://assets/audio/sfx/aircraft/prop_loop.wav")
const VULCAN_SFX := preload("res://assets/audio/sfx/aircraft/vulcan_burst.wav")
const BOFORS_SFX := preload("res://assets/audio/sfx/aircraft/bofors_40mm.wav")


## The gun fires from the AIRCRAFT, and that report is the whole reason Spooky is
## frightening from the ground. Impact FX alone left the gunship mute.
func _build_gun_audio() -> void:
	if DisplayServer.get_name() == "headless" or _gun_audio != null:
		return
	_gun_audio = AudioStreamPlayer3D.new()
	_gun_audio.bus = "Weapons" if AudioServer.get_bus_index("Weapons") >= 0 else "SFX"
	_gun_audio.max_distance = 1600.0
	_gun_audio.unit_size = 90.0
	_gun_audio.max_db = 0.0
	add_child(_gun_audio)


func _play_gun(stream: AudioStream, db: float) -> void:
	if _gun_audio == null or not is_instance_valid(_gun_audio):
		return
	_gun_audio.stream = stream
	_gun_audio.volume_db = db
	_gun_audio.pitch_scale = randf_range(0.97, 1.03)
	_gun_audio.play()


static func call_in(parent: Node, terrain_manager: TerrainManager, target_pos: Vector3) -> SpectreGunship:
	SpawnLedger.note("spectre")
	var ship := SpectreGunship.new()
	ship.terrain = terrain_manager
	ship.target = target_pos
	parent.add_child(ship)
	ship.global_position = target_pos + Vector3(ORBIT_RADIUS, ORBIT_ALT, 0)
	return ship


func _ready() -> void:
	var airframe := AIRFRAME_SCENE.instantiate() as Node3D
	airframe.name = "Airframe"
	# NO flip. The 2026-08-12 bake made the GLB conform (nose -Z) and this
	# rotation was missed then - the gunship flew its airframe BACKWARDS until
	# the 2026-08-14 v2 measurement caught it. v2 conforms at identity.
	add_child(airframe)
	# The three port miniguns author their muzzles as gun_muzzle_1..3 empties
	# (bore = local -Z). Cached here; _fire_vulcan round-robins them.
	for i in range(1, 4):
		var m := airframe.find_child("gun_muzzle_%d" % i, true, false) as Node3D
		if m != null:
			_muzzles.append(m)
	var stack: Array[Node] = [airframe]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null:
			mi.visibility_range_end = VIS_END_M
			mi.visibility_range_end_margin = VIS_MARGIN_M
		for c in n.get_children():
			stack.push_back(c)
	var anim := airframe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation("prop_spin"):
		anim.get_animation("prop_spin").loop_mode = Animation.LOOP_LINEAR
		anim.play("prop_spin")
	_build_gun_audio()
	# A C-130 is four turboprops, not a rotor. The old drone was the Huey loop at
	# half pitch, which reads as a helicopter no matter how far it is pitched
	# down; prop_loop is keyed to the T56's 68 Hz blade passage. Its loop points
	# come from the .import sidecar, so nothing here mutates a shared stream.
	_drone = AudioStreamPlayer3D.new()
	_drone.stream = PROP_LOOP
	_drone.bus = "Vehicles" if AudioServer.get_bus_index("Vehicles") >= 0 else "SFX"
	_drone.pitch_scale = 1.0
	_drone.volume_db = 2.0
	_drone.max_distance = 1200.0
	_drone.unit_size = 70.0
	_drone.max_db = 0.0
	_drone.attenuation_filter_cutoff_hz = 3000.0
	add_child(_drone)
	_drone.play()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		var out_dir := Vector3(1, 0.2, 0.3).normalized()
		global_position += out_dir * 60.0 * delta
		look_at(global_position + out_dir, Vector3.UP)
		if _age > DURATION + 8.0:
			queue_free()
		return
	# Left pylon turn: the angle runs backwards so the port side - where an
	# AC-47's miniguns point - faces the orbit centre while the nose leads.
	_angle -= delta * 0.35
	var desired := target + Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_ALT, sin(_angle) * ORBIT_RADIUS)
	global_position = global_position.lerp(desired, delta * 2.0)
	look_at(global_position + Vector3(sin(_angle), 0.0, -cos(_angle)), Vector3.UP)
	rotate_object_local(Vector3(0, 0, 1), BANK_LEFT_RAD)

	# The gun works in bursts, not a continuous hose: hot, then cold long enough for the
	# ground to be quiet and the drone to be the only thing left.
	_duty = fmod(_duty + delta, VULCAN_HOT_S + VULCAN_COLD_S)
	if _duty < VULCAN_HOT_S:
		_fire_vulcan()
		_report_timer -= delta
		if _report_timer <= 0.0:
			_report_timer = VULCAN_REPORT_S
			_play_gun(VULCAN_SFX, 4.0)
		_chew_timer -= delta
		if _chew_timer <= 0.0:
			_chew_timer = VULCAN_CHEW_S
			DamageSystem.apply_damage(_zone_point(1.0), DamageSystem.DamageType.SMALL_EXPLOSION, 0.6)

	_bofors_timer -= delta
	if _bofors_timer <= 0.0:
		_bofors_timer = BOFORS_INTERVAL
		_fire_bofors()


## A point inside the beaten zone, uniformly distributed over the disc.
func _zone_point(frac: float) -> Vector3:
	var a := randf_range(0.0, TAU)
	var r := sqrt(randf()) * FirePlan.SPECTRE_BEATEN_M * frac
	var p := target + Vector3(cos(a) * r, 0.0, sin(a) * r)
	if terrain:
		p.y = terrain.get_height_at(p)
	return p


## One tick of the port battery. Rounds leave the AIRCRAFT and fly, so the berm stops them
## because it is in the way and not because a radius said so.
func _fire_vulcan() -> void:
	if CombatManager.bullets == null:
		return
	if _vulcan_wd == null:
		_vulcan_wd = load(VULCAN_WEAPON) as WeaponData
	if _vulcan_wd == null:
		push_warning("[SPECTRE] %s missing - the battery has no weapon card" % VULCAN_WEAPON)
		return
	# Rounds leave the AUTHORED muzzles (round-robin across the three-gun
	# battery) so the tracer rope comes off the visible barrels. The aim-derived
	# offset survives only as the fallback for an airframe with no muzzle
	# empties - it fired from 0.9m UNDER the belly with no reference to the
	# model at all.
	var muzzle: Vector3
	if not _muzzles.is_empty():
		var mn: Node3D = _muzzles[_muzzle_i % _muzzles.size()]
		_muzzle_i += 1
		muzzle = mn.global_position
	else:
		var inward: Vector3 = target - global_position
		inward.y = 0.0
		inward = inward.normalized() if inward.length() > 0.01 else Vector3.RIGHT
		muzzle = global_position + inward * 3.2 + Vector3(0.0, -0.9, 0.0)
	var aim: Vector3 = _zone_point(1.0)
	for i in range(VULCAN_ROUNDS_PER_TICK):
		var dir: Vector3 = (aim - muzzle).normalized()
		CombatManager.bullets.fire(_vulcan_wd, self, muzzle, dir, VULCAN_MASK, [self], true, false)
	CombatManager.apply_suppression_in_area(aim, VULCAN_SUPPRESS_M, 0.2)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, aim, 0, 80.0)


func _fire_bofors() -> void:
	var data: ProjectileData = load(BOFORS_SHELL) as ProjectileData
	if data == null:
		return
	var impact := _zone_point(BOFORS_ZONE_FRAC)
	_play_gun(BOFORS_SFX, 6.0)
	var flight: float = maxf(0.6, global_position.distance_to(impact) / data.speed)
	# Destruction parity (decree 2026-08-04: the chain must chew the treeline like
	# napalm chews it): every 3rd shell scars/clears ground - throttled so a 25-shell
	# orbit does not drain the per-mission deform budget alone.
	_bofors_count += 1
	var crater: bool = (_bofors_count % 3 == 0)
	Ballistics.fire_arc(data, global_position, impact, flight, terrain, func(at: Vector3) -> void:
		@warning_ignore("integer_division")
		CombatManager.apply_explosion_damage(at, BOFORS_DAMAGE, BOFORS_DAMAGE / 4, BOFORS_BLAST_M, null)
		if crater:
			DamageSystem.apply_damage(at, DamageSystem.DamageType.SMALL_EXPLOSION, 1.0)
		GunFX.play_explosion_3d(get_tree().current_scene, at, "explosion_40mm")
		NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, at, 0))
