## test_mortar_beaten_zone.gd - the mortar counterplay probe.
## Raised from the Summoner's live findings, 2026-09-09, on the stress bench:
##   "the mortar strikes are too violent and wiping out the player right away"
##   "the mortar just keeps lasering right into where the player is and 3 out of 3
##    tests has wiped the squad almost instantly"
##   "yeah prone should protect you but not from a direct hit. and the npcs should
##    be reacting to the mortar rounds too yes"
##
## The shells were never homing - Ballistics.solve_velocity fires once and the round
## flies a fixed arc (ballistics.gd:16-46), and _mortar_impact reads the SHELL's
## position, never the player's (siege_director.gd). The defect was one level up, in
## the FIRE MISSION: the aim point WAS the defended point, every round of a volley
## detonated in the same frame, the floor of the damage curve was lethal three rounds
## over, and the whistle fell silent before anything landed.
##
## Every assertion below was RED against the code of 2026-09-09 and must go red again
## if the fix is reverted (ADR-015): a probe that passes before the fix proves nothing.
##
## Run: godot --headless --path . res://tests/test_mortar_beaten_zone.tscn
extends Node

## Law duplicated on purpose, exactly as test_flat_damage.gd does it - retuning the
## law without amending the doc must turn this suite red.
##   player max_hp 100          scripts/player/health_system.gd:19
##   SPRINT_SPEED 8.0 m/s       scripts/player/player.gd:13
##   ally max_hp 80             scripts/allies/ally_base.gd:11
const PLAYER_HP: int = 100
const SPRINT_MS: float = 8.0
const ALLY_HP: int = 80
## Indirect fire from a null attacker is bled to 0.4x on friendlies
## (combat_manager.gd, the danger-close branch).
const DANGER_CLOSE_MULT: float = 0.4

const SAMPLES: int = 60000
## A man standing in the open under a mortar volley SHOULD die - that is the game.
## What he must not eat is three-and-a-half times his own body, which is what makes
## the volley read as a delete key rather than as ordnance (Pillar 5: escalation,
## not a sadism simulator).
const MAX_MEAN_ON_AIM_POINT: float = 200.0
## ...and it must not become decorative either. Standing on the point a ranged-in
## tube is firing at has to be very likely death, or the fix overcorrected - the
## Summoner's own test: "if he can stand still and survive, you overcorrected".
const MIN_DEATH_PCT_RANGED_IN: float = 60.0
## A man who hears the tube and runs must live. 3.3s of reaction-plus-sprint at
## SPRINT_MS is the window the thump buys him.
const REACT_S: float = 3.3
const MAX_DEATH_PCT_IF_HE_MOVES: float = 10.0
## The volley must have a survivable fringe. If N x MIN_DAMAGE already exceeds a
## man, there is no distance inside the beaten zone that is not a kill.
const FRINGE_HEADROOM: float = 0.9
## Rounds landing inside one frame are one event, not a volley.
const MIN_VOLLEY_SPAN_S: float = 1.5
## The whistle must still be sounding when the round lands. A cue that resolves early
## teaches the player that the danger has passed (Fairness Law).
const MIN_WHISTLE_OVERLAP_S: float = 0.4
## ...and it must start early enough to be a warning and not an epitaph.
const MIN_WHISTLE_LEAD_S: float = 1.5
## The aim point of a fire mission is where an OBSERVER put the target, never the
## target's own coordinates. Without this the tube cannot miss.
const MIN_AIM_OFFSET_M: float = 25.0
## ...and the bracket must still CLOSE, or the tube never threatens anything.
const MAX_RESIDUAL_OFFSET_M: float = 20.0

var _rng := RandomNumberGenerator.new()
var _failures: int = 0


func _ready() -> void:
	_rng.seed = 0x4D4F5254  # one seed per operation (ADR-010)
	_run()


func _run() -> void:
	print("--- MORTAR BEATEN ZONE PROBE ---")
	_check_fringe_stacking()
	_check_volley_time_span()
	_check_whistle_covers_impact()
	_check_aim_point_is_offset()
	_check_open_ground_is_punishing_not_absolute()
	_check_moving_saves_you()
	_check_radius_has_one_source_of_truth()
	_check_prone_protects_but_not_from_a_direct_hit()
	_check_npcs_react_but_imperfectly()
	_check_the_pin_is_audible()
	if _failures == 0:
		print("PASS: mortar volley leaves counterplay (10 assertions)")
	else:
		print("FAIL: %d mortar counterplay assertion(s) red" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL: " + msg)


## Damage at range through the REAL curve the shell uses - a falloff or grammar
## retune must reach this probe.
func _dmg(dist: float) -> int:
	if dist > FirePlan.MORTAR_BLAST_M:
		return 0
	return CombatManager._explosion_damage_at(dist, FirePlan.MORTAR_BLAST_M,
		FirePlan.MORTAR_DAMAGE, FirePlan.MORTAR_MIN_DAMAGE, 0.4, 1.0)


## 1. THE FLOOR MUST NOT BE LETHAL BY STACKING.
## MORTAR_VOLLEY x MORTAR_MIN_DAMAGE is what a man eats at the OUTER EDGE of every
## round in the volley - the best outcome short of being missed entirely. It was
## 3 x 40 = 120 on a 100 hp man: the grazing case was a kill and the beaten zone had
## no survivable band anywhere in it.
func _check_fringe_stacking() -> void:
	var floor_total: int = FirePlan.MORTAR_VOLLEY * FirePlan.MORTAR_MIN_DAMAGE
	var ceiling: float = float(PLAYER_HP) * FRINGE_HEADROOM
	print("  fringe: %d rounds x %d min = %d vs %d hp, ceiling %.0f"
		% [FirePlan.MORTAR_VOLLEY, FirePlan.MORTAR_MIN_DAMAGE, floor_total,
			PLAYER_HP, ceiling])
	if float(floor_total) > ceiling:
		_fail("volley FLOOR %d kills a %d hp player - no survivable fringe exists"
			% [floor_total, PLAYER_HP])


## 2. THE VOLLEY MUST BE THREE ROUNDS, NOT ONE.
## fire_mortar_volley fired every round in one frame and _fire_shell handed each the
## same SHELL_FLIGHT_S, so all three solved to the same time of flight and detonated
## in the SAME PHYSICS FRAME - one instantaneous deletion with no gap to react in, and
## three blast passes, three suppression sweeps and three queued chunk deforms on a
## single tick, which is why the frame collapsed as well as the player.
func _check_volley_time_span() -> void:
	var span: float = FirePlan.MORTAR_VOLLEY_STAGGER_S * float(FirePlan.MORTAR_VOLLEY - 1)
	print("  volley time span: %.2fs across %d rounds (need >= %.2fs)"
		% [span, FirePlan.MORTAR_VOLLEY, MIN_VOLLEY_SPAN_S])
	if span < MIN_VOLLEY_SPAN_S:
		_fail("all %d rounds land within %.2fs - one frame, one event, no reaction window"
			% [FirePlan.MORTAR_VOLLEY, span])


## 3. THE WHISTLE MUST STILL BE IN THE AIR WHEN THE SHELL IS.
## It used to be played once, over the aim point, on the same line as the tube thump -
## so it started 4.0s out, ran its 2.60s and FELL SILENT 1.4s before the burst. It now
## rides each round down to that round's own impact point, starting MORTAR_WHISTLE_LEAD_S
## before it lands, which also gives the cue a DIRECTION it never had.
func _check_whistle_covers_impact() -> void:
	var w: AudioStream = load("res://assets/audio/sfx/weapons/shell_incoming.wav") as AudioStream
	if w == null:
		_fail("shell_incoming.wav missing - the mortar has NO audible telegraph at all")
		return
	var whistle: float = w.get_length()
	var lead: float = FirePlan.MORTAR_WHISTLE_LEAD_S
	var overlap: float = whistle - lead   # still sounding this long past the burst
	print("  telegraph: whistle %.2fs, lead %.2fs -> %.2fs still sounding at impact"
		% [whistle, lead, overlap])
	if lead < MIN_WHISTLE_LEAD_S:
		_fail("whistle leads the burst by only %.2fs - not a warning, an epitaph" % lead)
	if overlap < MIN_WHISTLE_OVERLAP_S:
		_fail("whistle ends %.2fs BEFORE the round lands - the cue resolves, then he dies"
			% [-overlap])


## 4. THE TUBE MUST BE ABLE TO MISS, AND MUST STILL RANGE IN.
## _walk_mortars aimed every volley at `objective` itself and the bench aimed at
## player.global_position. Only the dispersion moved - MORTAR_WALK_S shrank it 50m ->
## 12m - so the CENTRE of the beaten zone was nailed to the defended point all night.
## A ranging walk that never walks is a guided weapon with extra steps.
func _check_aim_point_is_offset() -> void:
	var first: float = absf(SiegeDirector.walk_aim_offset_m(0.0))
	var last: float = absf(SiegeDirector.walk_aim_offset_m(1.0))
	print("  bracket: %.1fm on the first volley -> %.1fm once ranged in" % [first, last])
	if first < MIN_AIM_OFFSET_M:
		_fail("volley centre sits on the target at t=0 (%.1fm) - the tube cannot miss" % first)
	if last > MAX_RESIDUAL_OFFSET_M:
		_fail("bracket never closes (%.1fm residual) - the tube never threatens the position"
			% last)
	if last <= 0.0:
		_fail("bracket closes to ZERO - the late walk is the original defect again")


## 5. OPEN GROUND MUST BE PUNISHING, NOT ABSOLUTE.
## A man who stands on the point a ranged-in tube is firing at dies - this probe does
## not argue with that, and asserts it in both directions. What it refuses is the mean
## overkill: at the tight end a man at the aim point used to eat ~3.4x his own body.
func _check_open_ground_is_punishing_not_absolute() -> void:
	var opening := _volley_outcome(SiegeDirector.MORTAR_DISPERSION_START,
		SiegeDirector.walk_aim_offset_m(0.0), 0.0)
	var ranged := _volley_outcome(SiegeDirector.MORTAR_DISPERSION_END,
		SiegeDirector.walk_aim_offset_m(1.0), 0.0)
	for row: Dictionary in [opening, ranged]:
		print("  spread %5.1fm / bracket %4.1fm: P(die) %5.1f%%  mean %6.1f  ally P %5.1f%%"
			% [row["spread"], row["offset"], row["death_pct"], row["mean"], row["ally_pct"]])
		if row["mean"] > MAX_MEAN_ON_AIM_POINT:
			_fail("spread %.0fm delivers mean %.0f dmg (%.1fx a man) onto the aim point"
				% [row["spread"], row["mean"], row["mean"] / float(PLAYER_HP)])
	if ranged["death_pct"] < MIN_DEATH_PCT_RANGED_IN:
		_fail("a ranged-in tube kills a man standing on its aim point only %.1f%% of the time - overcorrected"
			% ranged["death_pct"])


## 6. AND MOVING MUST SAVE YOU.
## The thump is at the tube, seconds out. A man who hears it and runs must live, or
## the telegraph is decoration. He runs AWAY from the whistle, which now plays over
## the impact points and therefore carries a bearing.
func _check_moving_saves_you() -> void:
	var run_m: float = SPRINT_MS * REACT_S
	var moved := _volley_outcome(SiegeDirector.MORTAR_DISPERSION_END,
		SiegeDirector.walk_aim_offset_m(1.0), run_m)
	print("  reacts: sprints %.0fm off the aim point -> P(die) %5.1f%%  mean %6.1f"
		% [run_m, moved["death_pct"], moved["mean"]])
	if moved["death_pct"] > MAX_DEATH_PCT_IF_HE_MOVES:
		_fail("a man who hears the tube and runs still dies %.1f%% of the time - no counterplay"
			% moved["death_pct"])


## One volley, `SAMPLES` times: bracket on a random bearing, MORTAR_VOLLEY rounds
## scattered in a `spread` box around it, a man at the objective who has run `escape`
## metres directly away from the whistle.
func _volley_outcome(spread: float, offset: float, escape: float) -> Dictionary:
	var dead: int = 0
	var ally_dead: int = 0
	var total: float = 0.0
	for _s in range(SAMPLES):
		var b: float = _rng.randf_range(0.0, TAU)
		var ox: float = cos(b) * offset
		var oz: float = sin(b) * offset
		var n: float = maxf(0.001, sqrt(ox * ox + oz * oz))
		var px: float = (-ox / n) * escape
		var pz: float = (-oz / n) * escape
		var took: int = 0
		var ally_took: int = 0
		for _r in range(FirePlan.MORTAR_VOLLEY):
			var ix: float = ox + _rng.randf_range(-spread, spread)
			var iz: float = oz + _rng.randf_range(-spread, spread)
			took += _dmg(sqrt((px - ix) * (px - ix) + (pz - iz) * (pz - iz)))
			ally_took += _dmg(sqrt(ix * ix + iz * iz))
		total += float(took)
		if took >= PLAYER_HP:
			dead += 1
		if float(ally_took) * DANGER_CLOSE_MULT >= float(ALLY_HP):
			ally_dead += 1
	return {
		"spread": spread,
		"offset": offset,
		"mean": total / float(SAMPLES),
		"death_pct": 100.0 * float(dead) / float(SAMPLES),
		"ally_pct": 100.0 * float(ally_dead) / float(SAMPLES),
	}


## 7. ONE RADIUS, ONE NUMBER (NO MORE DRIFT).
## Three live numbers described one blast: the shell resource said 10m, the code that
## applied the enemy's damage said 18m, and the player's own fire mission plus the
## tree threat zone read FirePlan's 10m.
func _check_radius_has_one_source_of_truth() -> void:
	var shell: ProjectileData = load("res://data/projectiles/mortar_81mm.tres") as ProjectileData
	var res_r: float = shell.aoe_radius if shell != null else -1.0
	print("  radius: shell.tres %.1fm | FirePlan %.1fm | SiegeDirector %.1fm"
		% [res_r, FirePlan.MORTAR_BLAST_M, SiegeDirector.MORTAR_BLAST_M])
	if not is_equal_approx(res_r, FirePlan.MORTAR_BLAST_M) \
			or not is_equal_approx(SiegeDirector.MORTAR_BLAST_M, FirePlan.MORTAR_BLAST_M):
		_fail("mortar blast radius has more than one source of truth (%.1f / %.1f / %.1f)"
			% [res_r, FirePlan.MORTAR_BLAST_M, SiegeDirector.MORTAR_BLAST_M])


## 8. PRONE PROTECTS, BUT NOT FROM A DIRECT HIT (Summoner, 2026-09-09).
## Measures the SILHOUETTE, which is the mechanism - there is no prone damage
## multiplier to test because building one would have been the wrong fix.
##   * a standing man's samples must be EXACTLY what shipped, so no explosive in the
##     game changes behaviour against a man on his feet;
##   * a prone man's samples must hug the ground, so intervening earth blocks rays
##     that clear a standing chest;
##   * and a prone man must present MORE ground length, because he is lying out.
## The direct hit needs no assertion of its own: with nothing between the burst and
## the body every ray is clear at any height, so the multiplier is 1.0 for every
## stance and the plateau lands in full. That is the property being preserved by
## refusing to write `if prone: damage *= x`.
func _check_prone_protects_but_not_from_a_direct_hit() -> void:
	var standing: Array[Vector3] = CombatManager.blast_sample_offsets(null)
	var pd := _StanceDummy.new()
	pd.is_prone = true
	var cd := _StanceDummy.new()
	cd.is_crouching = true
	var prone_pts: Array[Vector3] = CombatManager.blast_sample_offsets(pd)
	var crouch_pts: Array[Vector3] = CombatManager.blast_sample_offsets(cd)

	var shipped: Array[Vector3] = [
		Vector3.ZERO, Vector3(0, 1.0, 0), Vector3(0, 0.5, 0), Vector3(0.3, 0.5, 0),
		Vector3(-0.3, 0.5, 0), Vector3(0, 0.5, 0.3), Vector3(0, 0.5, -0.3),
		Vector3(0, 0.1, 0),
	]
	var stand_h: float = _max_y(standing)
	var prone_h: float = _max_y(prone_pts)
	var crouch_h: float = _max_y(crouch_pts)
	print("  silhouette height: standing %.2fm | crouched %.2fm | prone %.2fm"
		% [stand_h, crouch_h, prone_h])
	print("  silhouette length: standing %.2fm | prone %.2fm"
		% [_max_lateral(standing), _max_lateral(prone_pts)])

	if standing.size() != shipped.size():
		_fail("blast sample count changed - every explosive in the game just moved")
	else:
		for i in range(shipped.size()):
			if not standing[i].is_equal_approx(shipped[i]):
				_fail("a STANDING man's blast samples changed at index %d (%s vs %s) - this fix must be a no-op on its feet"
					% [i, standing[i], shipped[i]])
				break
	if prone_h >= stand_h * 0.5:
		_fail("prone silhouette %.2fm is not meaningfully lower than standing %.2fm - the ground cannot shield him"
			% [prone_h, stand_h])
	if crouch_h >= stand_h or crouch_h <= prone_h:
		_fail("crouch (%.2fm) must sit between prone (%.2fm) and standing (%.2fm)"
			% [crouch_h, prone_h, stand_h])
	if _max_lateral(prone_pts) <= _max_lateral(standing):
		_fail("a prone man must lie OUT - his silhouette is longer, not just shorter")


func _max_y(pts: Array[Vector3]) -> float:
	var m: float = 0.0
	for p in pts:
		m = maxf(m, p.y)
	return m


func _max_lateral(pts: Array[Vector3]) -> float:
	var m: float = 0.0
	for p in pts:
		m = maxf(m, maxf(absf(p.x), absf(p.z)))
	return m


## 9. NPCS REACT TO INCOMING - AND NOT PERFECTLY (Summoner, 2026-09-09).
## siege_director used to say the opposite in as many words: "No AI consumes it: a
## garrison man has no pre-impact reaction". That is why one volley onto the defended
## point wiped the squad three times out of three - nobody ever moved.
##
## The reaction must exist AND must leak. A man who always hears the tube and always
## reaches the deck makes the mortar decorative and leaves the player as the only man
## in the game who can die, which is the opposite unfairness.
func _check_npcs_react_but_imperfectly() -> void:
	if not (AllyBase as GDScript).get_script_method_list().any(
			func(m: Dictionary) -> bool: return m.get("name", "") == "warn_incoming"):
		_fail("AllyBase has no warn_incoming - the men still cannot consume the whistle")
	if not (EnemyBase as GDScript).get_script_method_list().any(
			func(m: Dictionary) -> bool: return m.get("name", "") == "warn_incoming"):
		_fail("EnemyBase has no warn_incoming - the attackers cannot flinch from their own barrage")

	# A man standing on the impact point must be able to hear it, and one out past the
	# hearing range must not.
	var heard: int = 0
	var committed_heard: int = 0
	for _i in range(SAMPLES / 10):
		if CombatPosture.hears_incoming(Enums.AIState.COMBAT, 5.0, _rng.randf()):
			heard += 1
		if CombatPosture.hears_incoming(Enums.AIState.ADVANCING, 5.0, _rng.randf()):
			committed_heard += 1
	var n: float = float(SAMPLES / 10)
	var pct: float = 100.0 * float(heard) / n
	var cpct: float = 100.0 * float(committed_heard) / n
	print("  reaction: %.1f%% of men in contact answer the whistle, %.1f%% of men mid-assault"
		% [pct, cpct])
	print("  answer delay: %.2fs - %.2fs, then down for %.1fs (whistle leads by %.2fs)"
		% [CombatPosture.INCOMING_REACT_MIN_S, CombatPosture.INCOMING_REACT_MAX_S,
			CombatPosture.INCOMING_HOLD_S, FirePlan.MORTAR_WHISTLE_LEAD_S])

	if pct < 50.0:
		_fail("only %.1f%% of men react to a round landing on them - the squad still cannot move" % pct)
	if pct > 90.0:
		_fail("%.1f%% of men react - a mortar nobody can be caught by is decoration" % pct)
	if cpct >= pct:
		_fail("men crossing open ground react as readily as men in contact (%.1f%% vs %.1f%%) - nobody is ever committed"
			% [cpct, pct])
	if CombatPosture.hears_incoming(Enums.AIState.COMBAT,
			CombatPosture.INCOMING_HEAR_M + 10.0, 0.99):
		_fail("a man past INCOMING_HEAR_M still hears the round - the cue has no range")
	# The slowest reactor must still be settling when the round lands, or nobody is
	# ever caught on his feet by a round he DID hear.
	if CombatPosture.INCOMING_REACT_MAX_S <= FirePlan.MORTAR_WHISTLE_LEAD_S * 0.5:
		_fail("every man who hears the whistle is flat long before impact - no one is ever caught late")
	# THE WAY OUT MUST NEVER BE BLOCKED (combat_posture.gd's own law). A warned man is
	# held down for the volley plus a tail, which can exceed the dwell ceiling - so the
	# ceiling must remain the binding release, and wanting to move must still free him.
	var volley_s: float = FieldDirector.SHELL_FLIGHT_S \
		+ float(FirePlan.MORTAR_VOLLEY - 1) * FirePlan.MORTAR_VOLLEY_STAGGER_S
	var held_s: float = volley_s + CombatPosture.INCOMING_HOLD_S
	print("  incoming hold: %.1fs vs prone dwell ceiling %.1fs (ceiling must bind)"
		% [held_s, CombatPosture.PRONE_DWELL_MAX_S])
	if not CombatPosture.must_rise(1.0, true, 0.0):
		_fail("a warned man who wants to move is not freed - prone-with-no-exit bug class")
	if not CombatPosture.must_rise(1.0, false, CombatPosture.PRONE_DWELL_MAX_S):
		_fail("the dwell ceiling no longer frees a warned man - prone-with-no-exit bug class")
	if held_s <= volley_s:
		_fail("the hold ends before the last round of the volley lands (%.1fs vs %.1fs)"
			% [held_s, volley_s])


## 10. THE PIN MUST BE AUDIBLE (Summoner, 2026-09-09: "make the suppression visible on
## the enemy too"). Everything suppression does to an enemy was already simulated and
## already visible IF you could see him - the move multiplier, the fire ceiling, the
## spread, the drop to prone. None of it reaches a player fighting at 100m at night
## through canopy, which is where this game is played.
##
## The tell must exist in all three Vietnamese banks (the speaker is chosen by instance
## id, so a line missing from one bank silently mutes a third of the enemy), and it must
## carry past speech range or it is the same defect as no tell at all.
func _check_the_pin_is_audible() -> void:
	for dir: String in VOManager.ENEMY_DIRS:
		if not ResourceLoader.exists("%s/%s/enemy_reload.wav" % [VOManager.VO_ROOT, dir]):
			_fail("bank %s has no enemy_reload.wav - a third of the enemy pins silently" % dir)
	print("  pin bark: %.0fm shout range vs %.0fm field default, one bark per %.0fs"
		% [VOManager.SHOUT_MAX_D, VOManager.FIELD_MAX_D, EnemyBase.PIN_BARK_COOLDOWN_S])
	if VOManager.SHOUT_MAX_D <= VOManager.FIELD_MAX_D:
		_fail("the pin bark carries no further than a spoken line - it will not reach the player")
	# It marks the TRANSITION, not the state. Without a cooldown the bark becomes a live
	# "still harmless" meter and the player stops having to look at the man he pinned.
	if EnemyBase.PIN_BARK_COOLDOWN_S < 5.0:
		_fail("pin bark cooldown %.1fs is short enough to read as a live suppression meter"
			% EnemyBase.PIN_BARK_COOLDOWN_S)


## A bare object carrying only a stance, so the sampler can be measured without
## standing up a player or an NPC in a headless scene.
class _StanceDummy extends RefCounted:
	var is_prone: bool = false
	var is_crouching: bool = false
