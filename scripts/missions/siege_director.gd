## siege_director.gd - The night assault on the firebase (ADR-035). Owns cadence,
## the assault's strength ledger, the attack sector, the ranging mortars, the break
## and THE REAP. It spawns nothing itself: every body comes from
## FieldDirector.spawn_tracked_enemy through a MarchingCell, so the single spawn
## authority is untouched.
class_name SiegeDirector
extends Node

## Per-night probability by the threat tier the player earned. Named as a constant
## because a rate that is not written down ships as whatever number gets typed
## first - the deleted SAPPER_CHANCE is what this replaces.
const NIGHT_CHANCE: Dictionary = {"LOW": 0.05, "MODERATE": 0.15, "HIGH": 0.30, "CRITICAL": 0.45}
const MAX_RUN_NIGHTS: int = 3

## A roll of 1-11 is a PROBE, not a siege: 2d6 sappers can exceed a low d50, and a
## three-man "siege" reads as a broken feature rather than a quiet night.
const PROBE_MAX: int = 11

const RING_MIN: float = 300.0
const RING_MAX: float = 500.0
const CELL_MIN: int = 3
const CELL_MAX: int = 6
const SAPPER_DATA: String = "res://data/enemies/vc_sapper.tres"
const REGULAR_DATA: String = "res://data/enemies/nva_regular.tres"

## The assault breaks at 42.5% killed - inside the decreed 40-50% band. Passed as
## break_state's base_ratio: reaching it through the courage term instead would
## make every besieger individually cowardly (ADR-035 §4).
const BREAK_BASE_RATIO: float = 0.575

## Simultaneous MATERIALIZED men. The cells defer body cost, they do not delete it -
## one axis onto one objective means every cell crosses the ring inside a minute.
## Set to the d50 ceiling by the Summoner's ruling 2026-07-28: a capped assault
## trickles in and never reads as the mass attack the roll describes.
const LIVE_CAP: int = 50

## A siege is decided inside the night (600 real seconds, sim_clock.gd:17) and must
## be triggered early enough in NIGHT that this fits before dawn.
const MAX_DURATION_S: float = 480.0

const RALLY_M: float = 350.0
const REAP_RADIUS_M: float = 600.0
const REAP_TIMEOUT_S: float = 90.0

const MORTAR_SHELL: String = "res://data/projectiles/mortar_81mm.tres"
const MORTAR_DISPERSION_START: float = 50.0
const MORTAR_DISPERSION_END: float = 12.0
const MORTAR_WALK_S: float = 180.0
const MORTAR_VOLLEY: int = 3
const MORTAR_TUBE_STANDOFF: float = 700.0
const MORTAR_DAMAGE: int = 140
const MORTAR_MIN_DAMAGE: int = 40
const MORTAR_BLAST_M: float = 18.0

## ---------- THE OVERRUN ----------
## An assault that reaches the wire and trades shots is a probe with more men. The press
## is a GOAL bias, not an order that owns legs: CombatGoals scores ADVANCE above the
## ENGAGE a man is already winning with, and he crosses the ground still shooting
## (EnemyBase._execute_advancing fires on the move). Rotated over a share of the assault
## so the attack arrives in rushes rather than one line standing up together.
##
## The DEFAULT lane is the GATE (a night attack goes through one lane, not over a
## line) - but a satchel HOLE outranks it (his ruling 2026-08-13): NavBaker's breach
## re-bake makes a dead parapet segment walkable, _scan_breaches reads it, and every
## squad nearer the hole than the gate presses through the breach instead.
const PRESS_CYCLE_S: float = 8.0
## Men measurably inside the wire before the compound counts as overrun.
const OVERRUN_MEN: int = 3
## Bearing bins used to measure the perimeter. The parapet is not one radius - it runs
## 49.3 m to 96.1 m (firebase_v3_destructibles.json, 80 segments) - so "inside" is
## per-bearing or it is wrong on two thirds of the compass.
const PERIMETER_BINS: int = 36
## How far inside a bearing's own wall a man must be to count as through it.
const INSIDE_MARGIN_M: float = 6.0

## THE LIT GROUND IS THE SCOREBOARD. The assault crosses from ~200m in the dark against 56m
## night sight, so without light the whole overrun is muzzle flashes and the player cannot see
## it crest OR break. The garrison fires its own (FieldDirector.garrison_illum) - it never
## spends the player's allotment.
##
## Interval is deliberately LONGER than the burn: the gap of darkness between rounds is where
## the dread lives, and a compound lit end to end is a lit stage.
const ILLUM_INTERVAL_S: float = 70.0
## Out on the attack bearing, between the wire and the ring, so the lit circle covers the
## ground they are actually crossing rather than the compound behind you.
const ILLUM_STANDOFF_M: float = 140.0
## First round goes up shortly after stand-to - but after the first ranging shells, which start
## at zero, so the mortars still announce the night themselves.
const ILLUM_FIRST_S: float = 12.0

signal siege_began(strength: int, is_probe: bool)
signal siege_ended(reason: String, killed: int, strength: int)
## The wire is not holding. Raised once per siege, for the radio.
signal siege_overrun(inside: int)

var director: FieldDirector = null
var fsb_center: Vector3 = Vector3.ZERO
var objective: Vector3 = Vector3.ZERO

var active: bool = false
var is_probe: bool = false
var sector_bearing: float = 0.0
var cells: Array[MarchingCell] = []

## Assault geometry in metres. The constants above are authored for a kilometres-wide
## AO; a 200 m test chamber would spawn every cell outside its own walls, so a host
## with a smaller map overrides these after setup(). Distances only - the roll, the
## cell sizes and the break ratio are NOT tunable from outside.
var ring_min: float = RING_MIN
var ring_max: float = RING_MAX
var rally_m: float = RALLY_M
var mortar_standoff_m: float = MORTAR_TUBE_STANDOFF
var cell_materialize_m: float = MarchingCell.MATERIALIZE_M

## THE LEDGER. peak is fixed when the run is rolled, never observed - EnemySquad's
## own _strength counts nodes in the `enemies` group, and a dormant cell has none,
## so its ratio would be replenished by every arriving cell and the break would
## never fire (ADR-035 §4).
var run_strength: int = 0        ## d50, rolled ONCE PER RUN
var run_peak: int = 0
var nights_run: int = 0
var _rolled_this_night: bool = false
var _elapsed: float = 0.0
var _mortar_timer: float = 0.0
var _reaping: Array[EnemyBase] = []
var _reap_clock: Dictionary = {}   ## instance_id -> seconds under withdrawal
var _rng := RandomNumberGenerator.new()
var _poll: float = 0.0
var _last_sim_day: int = -1
var _illum_timer: float = ILLUM_FIRST_S
var _press_clock: float = 0.0
var _press_phase: int = 0
var _overrun_called: bool = false
## instance_id -> true for every attacker ever measured OUTSIDE the wire. An overrun counts men
## who crossed it, never men who began behind it.
var _seen_outside: Dictionary = {}
## Per-bearing wall radius, measured once from the parapet group. Empty = no wire wired
## on this map (a test chamber), and then nothing can be judged inside it.
var _wall_r: PackedFloat32Array = PackedFloat32Array()


func setup(field_director: FieldDirector, center: Vector3, aim: Vector3) -> void:
	director = field_director
	fsb_center = center
	objective = aim if aim != Vector3.ZERO else center
	_rng.seed = hash(Vector2i(int(center.x), int(center.z))) ^ 0x51E6E
	sector_bearing = _rng.randf_range(0.0, TAU)


func _physics_process(delta: float) -> void:
	_poll += delta
	if _poll < 0.5:
		return
	var step: float = _poll
	_poll = 0.0
	_process_reap(step)
	if active:
		_run_siege(step)
	else:
		_maybe_open(step)


## ---------- CADENCE ----------

func _maybe_open(_step: float) -> void:
	if director == null or fsb_center == Vector3.ZERO:
		return
	# DEMO: the arc owns every siege (open_siege driven from demo_game's clock). The
	# 1-in-20 random night roll stays full-game only - a rogue second assault mid-arc
	# re-arms strength and steps on the authored probe (decree 2026-08-04, W-6).
	if GameFlow.demo_mode:
		return
	var day: int = _sim_day()
	if day != _last_sim_day:
		_last_sim_day = day
		_rolled_this_night = false
	if not MissionWeather.is_night:
		# Dawn closes the run's window: a night that never opened breaks the chain.
		if _rolled_this_night and not active:
			nights_run = 0
		_rolled_this_night = false
		return
	if _rolled_this_night or nights_run >= MAX_RUN_NIGHTS:
		return
	if director.patrol_count < 1:
		return
	_rolled_this_night = true
	var chance: float = float(NIGHT_CHANCE.get(CampaignState.threat_label(), 0.0))
	if _rng.randf() < chance:
		open_siege()


## Public so a probe drives the assault without fighting the RNG gate.
func open_siege(forced_strength: int = 0) -> void:
	if active or director == null or fsb_center == Vector3.ZERO:
		return
	if run_strength <= 0 or nights_run == 0:
		# d50 is rolled ONCE PER RUN. Nights 2-3 come with the survivors the reap
		# collected, so breaking them on night 1 can end the run outright.
		run_strength = forced_strength if forced_strength > 0 else _rng.randi_range(1, 50)
		run_peak = run_strength
	elif forced_strength > 0:
		# PEAK MUST GROW WITH STRENGTH. Setting strength alone left run_peak at whatever the
		# LAST wave was, and every ledger reading is relative to peak: killed_count is
		# `peak - live`, so a 45-man wave forced on top of an 11-man peak reports 0 killed
		# forever, and break_state sees live/peak = 4.09 and can never fire. The assault becomes
		# unbreakable and unscored, and runs to MAX_DURATION_S past the end card.
		#
		# Reached whenever the demo's 720s escalation finds the probe already BROKEN - reinforce()
		# handles the still-active case and always got this right; this branch did not.
		run_strength = forced_strength
		run_peak = maxi(run_peak, forced_strength)
	if run_strength <= 0:
		nights_run = 0
		return
	active = true
	nights_run += 1
	is_probe = run_strength <= PROBE_MAX
	_elapsed = 0.0
	_mortar_timer = 0.0
	_press_clock = 0.0
	_press_phase = 0
	_illum_timer = ILLUM_FIRST_S
	_overrun_called = false
	_seen_outside.clear()
	_measure_perimeter()
	# Nights 2 and 3 attack where the last night worked.
	if nights_run == 1:
		sector_bearing = _rng.randf_range(0.0, TAU)
	_build_cells()
	siege_began.emit(run_strength, is_probe)


## MORE MEN ONTO A FIGHT ALREADY RUNNING. The probe was the reconnaissance and the
## assault follows it in on the same bearing.
##
## open_siege cannot do this: it returns the moment `active` is true, which is why the
## demo's own 40-man assault never existed - the 600 s probe was still up at 720 s, so
## the escalation was a toast and nothing more (demo_game.gd:197-203).
##
## run_peak MUST grow with run_strength. Raising only strength drives live/peak above 1.0
## and the break can never fire; raising only peak credits the player kills he never made.
## Deliberately does NOT touch nights_run (this is one night), _elapsed (the run's clock
## is the dawn deadline) or _mortar_timer (the ranging walk is mid-stride).
func reinforce(extra: int) -> void:
	if not active or extra <= 0:
		return
	run_strength += extra
	run_peak += extra
	var was_probe: bool = is_probe
	is_probe = run_strength <= PROBE_MAX
	if was_probe and not is_probe:
		# A probe that just became an assault gets lit and pressed from here, not on the
		# schedule a probe was keeping.
		_illum_timer = ILLUM_FIRST_S
		_press_clock = PRESS_CYCLE_S
	# THE REINFORCEMENT SPLITS TOO. This used to spawn one undifferentiated body under the
	# single "siege_assault" tag - and it is the path the demo actually takes to reach full
	# strength, so the squad split would have existed everywhere except where it is watched.
	_build_assault(extra)
	print("[Siege] reinforced +%d - the assault is now %d men (peak %d)"
		% [extra, run_strength, run_peak])
	# Announce ONLY the probe-becomes-assault moment. Re-emitting on every
	# reinforcement re-ran stand-to and the siren over a garrison already fighting.
	if was_probe and not is_probe:
		siege_began.emit(run_strength, is_probe)


## Sappers are 2d6 of the strength, clamped so a probe cannot field more sappers
## than it has men. Cells are homogeneous: while dormant a cell holds ONE EnemyData
## reference rather than six.
## ---------- FOUR SQUADS, NOT A MASS ----------
## His ruling 2026-07-30: "break the main assault force into 4 attacking squads who should
## all be trying to flank and out manuver the defenders and get inside. otherwise its just
## a large mass of attackers who dont really do anything."
##
## The whole assault used to spawn under ONE group tag, and field_director.gd:51 derives
## squad_id from `hash(group_tag)` - so 45 men were literally one squad. Everything that
## reads squad_id was therefore measuring the wrong thing: ONE grenade per 12s across the
## entire assault, every man permanently holding `has_covering_fire` (a +0.2 ADVANCE bonus
## that is supposed to be situational), force_ratio computed against the whole force rather
## than the men in contact, and the entire assault breaking as a single body.
##
## THEY CONVERGE ON THE GATE ON PURPOSE. The barbwire is one merged ring, so the gate is
## the only authored way in (backlog C3b). Four squads sent at four compass points would
## put three of them milling at impassable wire - a mass that does nothing, spread out. So
## they APPROACH wide and FIGHT toward the one opening, which is what flanking against a
## wired perimeter actually looks like.
## RULED 2026-08-13 (his words: "assault squads should be using the blown holes yes
## otherwise whats the point of blowing it up"): a dead parapet segment is a HOLE -
## NavBaker's breach re-bake makes it walkable - and squads whose lane sits nearer the
## hole than the gate re-aim through it (_scan_breaches). The gate stays the default
## lane until a hole exists.
const ASSAULT_SQUADS: int = 4
## How far apart the squads come in. Deliberately wide: the point is that they do NOT arrive
## as one wedge; each squad still spreads its own cells within its lane.
const SQUAD_SPREAD_DEG: float = 150.0
const SQUAD_LANE_DEG: float = 34.0
## One squad in four holds off and shoots instead of closing. Without a base of fire the
## other three are just a queue at the gate, and fire-and-movement is the thing that reads
## as soldiering rather than swarming.
const SUPPORT_SQUAD: int = 2
## Where a support squad sits: outside its own objective, on its lane, putting rounds on
## the parapet. Far enough to be shooting rather than assaulting.
const SUPPORT_STANDOFF_M: float = 90.0


func _build_cells() -> void:
	_build_assault(run_strength)


## Stand up `count` men: the demolition party, then the assault split into squads. Called
## by open_siege AND by reinforce, so there is one shape of assault however it is raised.
func _build_assault(count: int) -> void:
	if count <= 0:
		return
	var sappers: int = mini(_rng.randi_range(1, 6) + _rng.randi_range(1, 6), count)
	var regulars: int = count - sappers
	# Sappers stay one body: they are the demolition party, they carry the charges, and
	# _rotate_press already excludes them from the press for that reason.
	_spawn_cells_for(sappers, SAPPER_DATA, "siege_sappers", true, sector_bearing, objective)
	if regulars <= 0:
		return
	# A probe is a reconnaissance, not an assault - it stays a single body.
	if is_probe:
		_spawn_cells_for(regulars, REGULAR_DATA, "siege_assault", false, sector_bearing, objective)
		return
	var per: int = maxi(1, int(floor(float(regulars) / float(ASSAULT_SQUADS))))
	var spread: float = deg_to_rad(SQUAD_SPREAD_DEG)
	for i in range(ASSAULT_SQUADS):
		var n: int = per if i < ASSAULT_SQUADS - 1 else regulars - per * (ASSAULT_SQUADS - 1)
		if n <= 0:
			continue
		# Lanes spread evenly across the arc, centred on the chosen sector.
		var frac: float = (float(i) / float(ASSAULT_SQUADS - 1)) - 0.5
		var lane: float = sector_bearing + frac * spread
		# EVERY SQUAD OWNS ITS OWN squad_id, because the tag is what field_director hashes.
		var tag: String = "siege_assault_%d" % i
		var aim: Vector3 = objective
		if i == SUPPORT_SQUAD:
			# The base of fire holds on its own lane instead of closing on the gate. The
			# stand is measured off the MEASURED parapet on that bearing, not a mean
			# radius: the wall runs 49-96m out, so one number would put this squad inside
			# the wire on a third of the compass.
			var out: Vector3 = Vector3(cos(lane), 0.0, sin(lane))
			var wall: float = _wall_radius_at(fsb_center + out * 100.0)
			aim = fsb_center + out * (wall + SUPPORT_STANDOFF_M)
		_spawn_cells_for(n, REGULAR_DATA, tag, false, lane, aim)
	print("[Siege] assault split into %d squads on %.0f deg of arc (squad %d is the base of fire)"
		% [ASSAULT_SQUADS, SQUAD_SPREAD_DEG, SUPPORT_SQUAD])


## ---------- BREACHES ----------
## His ruling 2026-08-13: "assault squads should be using the blown holes yes
## otherwise whats the point of blowing it up." A hole is a dead FSB_PARAPET_GROUP
## member; the breach re-bake has made it walkable. Squads re-aim through it when
## the hole is nearer their bearing than the gate; the base of fire keeps
## shooting and sappers keep their own charge logic.
const BREACH_SCAN_S: float = 1.5
## How far INSIDE the wire the re-aim lands - through the hole, into the
## compound, so the press continues rather than parking men in the gap.
const BREACH_INSIDE_M: float = 12.0
var _breach_scan_t: float = 0.0
var _dead_segs: Dictionary = {}


func _scan_breaches(step: float) -> void:
	_breach_scan_t -= step
	if _breach_scan_t > 0.0:
		return
	_breach_scan_t = BREACH_SCAN_S
	var tree := get_tree()
	if tree == null:
		return
	for s in tree.get_nodes_in_group(SitePlanner.FSB_PARAPET_GROUP):
		var d := s as Destructible
		if d == null or not is_instance_valid(d) or not d.is_destroyed():
			continue
		var id: int = d.get_instance_id()
		if _dead_segs.has(id):
			continue
		_dead_segs[id] = true
		_redirect_through_breach(d.global_position)


func _redirect_through_breach(hole: Vector3) -> void:
	var th: Vector3 = hole - fsb_center
	var hole_bearing: float = atan2(th.z, th.x)
	var gate_bearing: float = hole_bearing + PI
	if director != null and director.patrol_gate_pos != Vector3.ZERO:
		var tg: Vector3 = director.patrol_gate_pos - fsb_center
		gate_bearing = atan2(tg.z, tg.x)
	var inside: Vector3 = hole + (fsb_center - hole).normalized() * BREACH_INSIDE_M
	inside.y = 0.0
	var support_tag: String = "siege_assault_%d" % SUPPORT_SQUAD
	var moved: int = 0
	for c in cells:
		var cell := c as MarchingCell
		if cell == null or not is_instance_valid(cell):
			continue
		if cell.carries_charge or cell.group_tag == support_tag:
			continue
		var cb: Vector3 = cell.global_position - fsb_center
		var cell_bearing: float = atan2(cb.z, cb.x)
		if absf(angle_difference(cell_bearing, hole_bearing)) \
				>= absf(angle_difference(cell_bearing, gate_bearing)):
			continue
		cell.objective = inside
		for m in cell.men:
			if m != null and is_instance_valid(m) and not m.is_dead():
				m.assault_objective = inside
		moved += 1
	if moved > 0:
		print("[Siege] BREACH at (%.0f,%.0f): %d cell(s) press through the hole"
			% [hole.x, hole.z, moved])


func _spawn_cells_for(count: int, data: String, tag: String, charges: bool,
		bearing: float, aim: Vector3) -> void:
	var remaining: int = count
	while remaining > 0:
		var size: int = mini(remaining, _rng.randi_range(CELL_MIN, CELL_MAX))
		if remaining - size > 0 and remaining - size < CELL_MIN:
			size = remaining
		remaining -= size
		var half: float = deg_to_rad(SQUAD_LANE_DEG) * 0.5
		var a: float = bearing + _rng.randf_range(-half, half)
		var r: float = _rng.randf_range(ring_min, ring_max)
		var at: Vector3 = fsb_center + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var cell := MarchingCell.new()
		cell.carries_charge = charges
		cell.materialize_m = cell_materialize_m
		cell.materialize_center = fsb_center
		add_child(cell)
		cell.setup(director, at, aim, size, data, tag, int(_rng.randi()))
		cells.append(cell)


## ---------- THE RUNNING FIGHT ----------

func _run_siege(step: float) -> void:
	_elapsed += step
	_walk_mortars(step)
	_walk_illum(step)
	_light_check()
	_enforce_live_cap()
	_rotate_press(step)
	_scan_breaches(step)
	_check_overrun()
	if _elapsed >= MAX_DURATION_S:
		_break_siege("dawn")
		return
	var live: int = live_strength()
	if live <= 0:
		_break_siege("wiped")
		return
	var bs: Dictionary = EnemySquad.break_state(live, run_peak, _avg_courage(), BREAK_BASE_RATIO)
	if bool(bs.broken):
		_break_siege("broken")


func live_strength() -> int:
	var n: int = 0
	for c in cells:
		if is_instance_valid(c):
			n += c.live_strength()
	return n


func killed_count() -> int:
	return maxi(0, run_peak - live_strength())


func _avg_courage() -> float:
	var sum: float = 0.0
	var n: int = 0
	for c in cells:
		if not is_instance_valid(c) or not c.materialized:
			continue
		for m in c.men:
			if is_instance_valid(m) and not m.is_dead() and m.enemy_data != null:
				sum += m.enemy_data.courage
				n += 1
	return sum / float(n) if n > 0 else 0.5


## Light reveals what the dark hid - scoped to the lit circle, so an illum round
## cannot materialize the whole assault at once.
## Light reveals what the dark hid - but never MORE than the body budget allows. A garrison illum
## round 140m out lights a 180m circle, which reaches the 190-235m assembly ring, so an unbounded
## reveal stood the entire assault up at once the first time the wire was lit. `_enforce_live_cap`
## cannot catch that: it freezes a dormant cell's physics tick, and materialize_if_lit does not
## run on that tick. So the cap is enforced HERE too, at the only other door into materialising.
func _light_check() -> void:
	var live: int = 0
	for c in cells:
		if is_instance_valid(c) and c.materialized:
			live += c.live_strength()
	for c in cells:
		if live >= LIVE_CAP:
			return
		if is_instance_valid(c) and not c.materialized and c.materialize_if_lit():
			live += c.live_strength()


## The cells defer the spike; this bounds it. A deferred cell is logged, never
## silently dropped - a silent cap reads as "we fielded everything" when we did not.
##
## THE HOLD MUST BE TWO-WAY. A dormant cell that stops ticking never marches again and
## still answers live_strength() with its full paper strength (marching_cell.gd:55-57),
## so live/peak can never fall and the assault can never break - it runs to
## MAX_DURATION_S past the end card. A cell is IDENTIFIED as held by being dormant with
## its physics off: marching_cell only stops its own tick on materialize (:71, :112), so
## that pair is unambiguous.
##
## Thawing needs headroom, not equality. Releasing at exactly LIVE_CAP-1 lets one cell
## materialize, breach the cap and be frozen again on the next tick - a thrash that
## reads as men flickering at the ring.
const THAW_HEADROOM: int = 6

func _enforce_live_cap() -> void:
	var materialized_men: int = 0
	for c in cells:
		if is_instance_valid(c) and c.materialized:
			materialized_men += c.live_strength()
	if materialized_men < LIVE_CAP:
		if materialized_men <= LIVE_CAP - THAW_HEADROOM:
			_thaw_held_cells(materialized_men)
		return
	for c in cells:
		if is_instance_valid(c) and not c.materialized and c.is_physics_processing():
			c.set_physics_process(false)
			print("[Siege] cell of %d held at the ring - live cap %d reached"
				% [c.strength, LIVE_CAP])


## The dead on the wire are what buy the held cells their room. Released one at a time
## and only while its own strength still fits, so a 12-man cell cannot resume into 4
## slots and re-breach the cap the moment it arrives.
func _thaw_held_cells(materialized_men: int) -> void:
	var room: int = LIVE_CAP - materialized_men
	for c in cells:
		if room <= 0:
			return
		if not is_instance_valid(c) or c.materialized or c.is_physics_processing():
			continue
		if c.strength > room:
			continue
		c.set_physics_process(true)
		room -= c.strength
		print("[Siege] cell of %d released from the ring - %d live of cap %d"
			% [c.strength, materialized_men, LIVE_CAP])


## ---------- LIGHTING THE WIRE ----------

## A probe is never lit: holding off in the dark for three men is what makes a probe read as a
## probe, and burning illum on it spends the moment the real assault needs.
func _walk_illum(step: float) -> void:
	if is_probe or director == null:
		return
	_illum_timer -= step
	if _illum_timer > 0.0:
		return
	_illum_timer = ILLUM_INTERVAL_S
	var out := Vector3(cos(sector_bearing), 0.0, sin(sector_bearing))
	var at: Vector3 = fsb_center + out * ILLUM_STANDOFF_M
	director.garrison_illum(at)


## ---------- THE PRESS ----------

## Raise the press on a rotating share of the assault. A satchel man is never pressed: his
## legs already belong to the objective and biasing his goals fights that contract. Probes
## do not press - holding off the wire is what makes a probe legible as a probe.
func _rotate_press(step: float) -> void:
	if is_probe:
		return
	_press_clock += step
	if _press_clock < PRESS_CYCLE_S:
		return
	_press_clock = 0.0
	_press_phase += 1
	# THE PRESS ROTATES BY SQUAD, not by man. Scattering the press across individuals put
	# a third of every squad walking while the men beside them held - which reads as
	# indecision, not as fire and movement. A whole squad rushing while the others shoot
	# is the thing that looks like soldiering, and it is why the squads exist.
	var squads: Array[String] = []
	for c in cells:
		if is_instance_valid(c) and not c.carries_charge and c.group_tag not in squads:
			squads.append(c.group_tag)
	squads.sort()   # deterministic order, so the rotation replays from the seed (ADR-010)
	# The base of fire never rushes: it is the reason the others can.
	var moving: String = ""
	if not squads.is_empty():
		moving = squads[_press_phase % squads.size()]
		if moving.ends_with("_%d" % SUPPORT_SQUAD) and squads.size() > 1:
			moving = squads[(_press_phase + 1) % squads.size()]
	var pressed: int = 0
	var total: int = 0
	for c in cells:
		if not is_instance_valid(c) or not c.materialized or c.carries_charge:
			continue
		var on: bool = c.group_tag == moving
		for m in c.men:
			if not is_instance_valid(m) or m.is_dead():
				continue
			m.siege_press = on
			if on:
				pressed += 1
			total += 1
	if pressed > 0 and _press_phase % 4 == 1:
		print("[Siege] press wave %d: %s rushing, %d of %d men crossing" % [
			_press_phase, moving, pressed, total])


## ---------- INSIDE THE WIRE ----------

## The wall's radius per bearing bin, measured from the wired parapet segments. The
## perimeter is not a circle and the compound is not centred on its own mean radius, so a
## single number would call men inside on one face and outside on the opposite one.
func _measure_perimeter() -> void:
	_wall_r = PackedFloat32Array()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var segs: Array[Node] = tree.get_nodes_in_group(SitePlanner.FSB_PARAPET_GROUP)
	if segs.is_empty():
		return
	var bins := PackedFloat32Array()
	bins.resize(PERIMETER_BINS)
	for s in segs:
		var n := s as Node3D
		if n == null:
			continue
		var d: Vector2 = Vector2(n.global_position.x - fsb_center.x,
			n.global_position.z - fsb_center.z)
		if d.length() < 0.5:
			continue
		var b: int = int(floor((fposmod(d.angle(), TAU) / TAU) * float(PERIMETER_BINS)))
		b = clampi(b, 0, PERIMETER_BINS - 1)
		bins[b] = maxf(bins[b], d.length())
	# Empty bins take the neighbourly answer: a bearing with no segment still has a wall
	# in front of it, and zero there would call the whole quadrant "inside".
	var seen: float = 0.0
	for i in range(PERIMETER_BINS):
		if bins[i] > 0.0:
			seen = bins[i]
	for i in range(PERIMETER_BINS):
		if bins[i] <= 0.0:
			bins[i] = seen
		else:
			seen = bins[i]
	_wall_r = bins
	print("[Siege] perimeter measured from %d parapet segment(s) over %d bearings"
		% [segs.size(), PERIMETER_BINS])


func _wall_radius_at(pos: Vector3) -> float:
	if _wall_r.is_empty():
		return 0.0
	var d: Vector2 = Vector2(pos.x - fsb_center.x, pos.z - fsb_center.z)
	var b: int = int(floor((fposmod(d.angle(), TAU) / TAU) * float(PERIMETER_BINS)))
	return _wall_r[clampi(b, 0, PERIMETER_BINS - 1)]


## AN OVERRUN IS MEN WHO GOT IN, NOT MEN WHO STARTED IN. A body that materialises inside the wire
## - a badly-sized materialize distance, a test chamber with no wire, a cell standing up on a
## narrow face - has not overrun anything, and counting it fires the call before a shot. So a man
## is only ever counted after he has been MEASURED OUTSIDE at least once. That makes the reading
## correct on any map instead of on maps whose geometry happens to cooperate.
func inside_count() -> int:
	if _wall_r.is_empty():
		return 0
	var n: int = 0
	for c in cells:
		if not is_instance_valid(c) or not c.materialized:
			continue
		for m in c.men:
			if not is_instance_valid(m) or m.is_dead():
				continue
			var wall: float = _wall_radius_at(m.global_position)
			if wall <= 0.0:
				continue
			var r: float = Vector2(m.global_position.x - fsb_center.x,
				m.global_position.z - fsb_center.z).length()
			var id: int = m.get_instance_id()
			if r >= wall:
				_seen_outside[id] = true
			elif r < wall - INSIDE_MARGIN_M and _seen_outside.has(id):
				n += 1
	return n


## Announced ONCE. A wire that reports itself broken every half second is a spam channel,
## and the moment only lands if it is a moment.
func _check_overrun() -> void:
	if _overrun_called or is_probe:
		return
	var n: int = inside_count()
	if n < OVERRUN_MEN:
		return
	_overrun_called = true
	print("[Siege] OVERRUN - %d attacker(s) inside the wire" % n)
	siege_overrun.emit(n)


## ---------- THE RANGING WALK ----------

func _walk_mortars(step: float) -> void:
	if _camp_mortar_silenced():
		return
	_mortar_timer -= step
	if _mortar_timer > 0.0:
		return
	_mortar_timer = _rng.randf_range(20.0, 25.0)
	var t: float = clampf(_elapsed / MORTAR_WALK_S, 0.0, 1.0)
	fire_mortar_volley(objective, lerpf(MORTAR_DISPERSION_START, MORTAR_DISPERSION_END, t))


## S27 night link (his ruling): a camp mortar silenced during the day means no
## ranging walk tonight. A map with no camp mortar keeps the walk.
func _camp_mortar_silenced() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var camps: Array[Node] = tree.get_nodes_in_group("camp_mortars")
	if camps.is_empty():
		return false
	for c in camps:
		var cm := c as CampMortar
		if cm == null or not cm.silenced():
			return false
	return true


## One volley onto `at`, dispersed by `spread` metres. The ranging walk above is the
## campaign caller; a bench calls this directly to put enemy indirect fire on the
## map without opening an assault. Shells fly from the tube on the attack bearing -
## or from `tube_from` when a real emplaced tube (the camp's pit, S27) is firing -
## so they arrive from the enemy's side and not out of the defenders' own position.
func fire_mortar_volley(at: Vector3, spread: float, tube_from: Vector3 = Vector3.ZERO) -> void:
	if director == null:
		return
	var tube: Vector3 = tube_from
	if tube == Vector3.ZERO:
		tube = fsb_center + Vector3(cos(sector_bearing), 0.0,
			sin(sector_bearing)) * mortar_standoff_m
	# The thump from the tube line, then the whistle over the impact point. The
	# gap between them is the only warning the defenders get, and it is the
	# reason a ranging round is survivable.
	AudioManager.play_mortar_tube(tube)
	AudioManager.play_incoming(at)
	# Enemy indirect fire calls out the trees over its beaten zone too (decree
	# 2026-08-04) - contact fuzing is faction-blind.
	TreeCoverLayer.threat_zone(get_tree(), at, spread + FirePlan.MORTAR_BLAST_M + 6.0, 20.0)
	for i in range(MORTAR_VOLLEY):
		var impact: Vector3 = at + Vector3(_rng.randf_range(-spread, spread), 0.0,
			_rng.randf_range(-spread, spread))
		director._fire_shell(MORTAR_SHELL, impact, _mortar_impact, tube)


## The enemy's own ranging rounds must not break the enemy's own siege, and the
## break counts every attacker death - so this shell excludes them explicitly.
func _mortar_impact(pos: Vector3) -> void:
	if director == null or director.world == null or not is_instance_valid(director.world):
		return
	# Contact fuse: burst where it stopped; only a floor burst digs.
	var ground: Vector3 = pos
	var floor_y: float = pos.y
	var tm: Object = director.world.terrain_manager
	if tm != null:
		floor_y = director.world.terrain_manager.get_height_at(pos)
		ground.y = maxf(pos.y, floor_y)
	GunFX.play_explosion_3d(get_tree().current_scene, ground, "explosion_mortar")
	if ground.y - floor_y <= 2.0:
		DamageSystem.apply_damage(Vector3(pos.x, floor_y, pos.z),
			DamageSystem.DamageType.MEDIUM_EXPLOSION, 1.0)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 1)
	_blast_defenders_only(ground)


func _blast_defenders_only(at: Vector3) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var victims: Array[Node] = []
	victims.append_array(tree.get_nodes_in_group("allies"))
	victims.append_array(tree.get_nodes_in_group("garrison_promoted"))
	victims.append_array(tree.get_nodes_in_group("civilians"))
	if GameManager.player != null and is_instance_valid(GameManager.player):
		victims.append(GameManager.player as Node)
	var seen: Dictionary = {}
	for v in victims:
		if v == null or not is_instance_valid(v) or not (v is Node3D):
			continue
		var id: int = v.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		var d: float = (v as Node3D).global_position.distance_to(at)
		if d > MORTAR_BLAST_M:
			continue
		var falloff: float = 1.0 - clampf(d / MORTAR_BLAST_M, 0.0, 1.0)
		var dmg: int = maxi(MORTAR_MIN_DAMAGE, int(lerpf(float(MORTAR_MIN_DAMAGE),
			float(MORTAR_DAMAGE), falloff)))
		if v.has_method("take_damage"):
			v.call("take_damage", dmg, Enums.DamageType.EXPLOSIVE, null)


## ---------- THE BREAK AND THE REAP ----------

func _break_siege(reason: String) -> void:
	if not active:
		return
	active = false
	var killed: int = killed_count()
	var survivors: int = live_strength()
	var rally: Vector3 = fsb_center + Vector3(cos(sector_bearing), 0.0,
		sin(sector_bearing)) * rally_m
	for c in cells:
		if not is_instance_valid(c):
			continue
		if c.materialized:
			# The press dies with the assault. A withdrawing man carries assault_driven,
			# and leaving the press up would have his goal brain scoring ADVANCE at the
			# rally he is running to - the reap would never collect him.
			for m in c.men:
				if is_instance_valid(m):
					m.siege_press = false
			for m in c.withdraw_to(rally):
				_reaping.append(m)
				_reap_clock[m.get_instance_id()] = 0.0
		c.queue_free()
	cells.clear()
	# The run's pool carries: nights 2-3 field the survivors, and a wiped assault
	# ends the run rather than re-rolling a fresh fifty.
	run_strength = survivors
	if survivors <= 0 or reason == "wiped":
		nights_run = MAX_RUN_NIGHTS
	siege_ended.emit(reason, killed, run_peak)


## Withdrawal is a real terminal state, not a bearing. Untouched, EnemyBase flees
## forever with no destination and is never freed - three nights of this leaves the
## AO full of permanent full-cost ghosts.
func _process_reap(step: float) -> void:
	if _reaping.is_empty():
		return
	var still: Array[EnemyBase] = []
	for m in _reaping:
		if not is_instance_valid(m):
			continue
		if m.is_dead():
			continue
		var id: int = m.get_instance_id()
		var t: float = float(_reap_clock.get(id, 0.0)) + step
		_reap_clock[id] = t
		var from_base: float = Vector2(m.global_position.x - fsb_center.x,
			m.global_position.z - fsb_center.z).length()
		var at_rally: bool = m.assault_objective != Vector3.ZERO \
			and m.global_position.distance_to(m.assault_objective) <= 20.0
		if at_rally or from_base >= REAP_RADIUS_M or t >= REAP_TIMEOUT_S:
			_reap_clock.erase(id)
			if director != null:
				director.despawn_tracked_enemy(m)
			else:
				m.despawn()
			continue
		still.append(m)
	_reaping = still


func _sim_day() -> int:
	var clock: Node = get_node_or_null(^"/root/SimClock")
	if clock == null:
		return 1
	return int(clock.sim_day)
