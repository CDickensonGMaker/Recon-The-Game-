## combat_goals.gd - The ONE combat goal scorer, shared by EnemyBase and AllyBase.
##
## Part B of the posture merge (Part A shipped the shared CombatPosture 2026-07-23).
## Before this, allies ran a priority LADDER with five verbs and enemies ran a scored
## brain with nine: the friendly half of every firefight could not flank, could not
## lay suppressive fire, could not fall back and could not investigate. Pillar 1 says
## believable firefights and Pillar 4 says the squad IS the RPG - both were being met
## on one side of the fight only.
##
## The scoring math here is lifted VERBATIM from EnemyBase._evaluate_goals so the
## extraction cannot move enemy behaviour. Each class still owns what it feeds in,
## and still owns execution: this answers WHAT to want, never HOW to do it.
class_name CombatGoals
extends RefCounted


## Everything the scorer reads. The caller fills it; the scorer touches no node.
class Context:
	var current_goal: int = Enums.AIGoal.NONE
	var dist: float = 0.0
	var preferred_range: float = 30.0
	## DEBOUNCED contact confidence resolved to a bool by the caller - never raw LOS.
	var eyes_on: bool = false
	var target_last_seen: float = 99.0
	var has_cover: bool = false
	var threat_level: float = 0.0
	var suppression: float = 0.0
	var contact_time: float = 0.0
	var cover_fail_count: int = 0
	var full_auto: bool = false
	var hp_frac: float = 1.0

	## Temperament, 0-1. Enemies read EnemyData; allies derive from courage.
	var aggression: float = 0.5
	var self_preservation: float = 0.5

	## Doctrine gates. A false gate scores its goal -1 (never chosen).
	var uses_cover: bool = true
	var flanks: bool = true
	var retreats_when_hurt: bool = true
	var retreat_hp_frac: float = 0.35

	## Squad facts. Defaults are the "no squad support known" case.
	var has_covering_fire: bool = false
	var squad_broken: bool = false
	var force_ratio: float = 1.0


## Score every goal. Returns {Enums.AIGoal: float}; -1.0 means doctrinally forbidden.
static func score(c: Context) -> Dictionary:
	var scores: Dictionary = {}

	# ENGAGE - direct combat. COVER-FIRST: caught in the open on fresh contact the
	# duel can wait; fighting FROM cover is the preferred engagement.
	var engage: float = 0.5
	if c.eyes_on:
		engage += 0.3
	if c.dist < c.preferred_range * 1.2 and c.dist > c.preferred_range * 0.5:
		engage += 0.2
	if c.has_cover:
		engage += 0.15
	elif c.contact_time < 5.0 and c.aggression < 0.75 and c.cover_fail_count < 2:
		engage *= 0.55
	scores[Enums.AIGoal.ENGAGE_TARGET] = engage * (1.0 - c.threat_level * 0.3)

	# SEEK COVER - preemptive on fresh contact in the open, not just reactive.
	var cover: float = c.threat_level * 0.7 + c.self_preservation * 0.3
	if c.suppression > 0.5:
		cover += 0.3
	if not c.has_cover:
		cover += 0.2
		if c.contact_time < 6.0 and c.cover_fail_count < 2:
			cover += 0.4 * (1.0 - c.aggression * 0.7)
	scores[Enums.AIGoal.SEEK_COVER] = cover if c.uses_cover else -1.0

	# SUPPRESS - pin down target.
	var suppress: float = 0.3
	if c.eyes_on and c.full_auto:
		suppress += 0.3
	if c.dist > c.preferred_range:
		suppress += 0.2
	scores[Enums.AIGoal.SUPPRESS_TARGET] = suppress * (1.0 - c.aggression * 0.3)

	# FLANK - move to better position.
	var flank: float = c.aggression * 0.4
	if not c.eyes_on and c.target_last_seen < 3.0:
		flank += 0.3
	if c.threat_level < 0.3:
		flank += 0.2
	scores[Enums.AIGoal.FLANK_TARGET] = flank if c.flanks else -1.0

	# ADVANCE - push forward. OPEN-GROUND DISCIPLINE: crossing needs covering fire
	# or real aggression; a lone unsupported man holds and shoots.
	var advance: float = c.aggression * 0.4
	if c.dist > c.preferred_range * 1.5:
		advance += 0.25
	if c.threat_level < 0.2 and c.dist < c.preferred_range * 2.0:
		advance += 0.15
	if c.has_covering_fire:
		advance += 0.2
	elif c.aggression < 0.7:
		advance *= 0.45
	if c.force_ratio >= 2.0:
		advance += 0.15  # weight of numbers: press the lone shooter
	scores[Enums.AIGoal.ADVANCE] = advance

	# RETREAT - fall back. The wounded-man break is what retreats_when_hurt gates;
	# the tactical withdrawal above it is separate.
	var retreat: float = 0.0
	if c.threat_level > 0.7:
		retreat = 0.6
	if c.retreats_when_hurt and c.hp_frac < c.retreat_hp_frac:
		retreat += 0.4
	if c.squad_broken:
		retreat += 0.7
	# Outnumbering men hold: ~3:1 quarters the retreat urge; outnumbered men break.
	var numbers: float = clampf(1.6 - c.force_ratio * 0.45, 0.25, 1.4)
	scores[Enums.AIGoal.RETREAT] = retreat * c.self_preservation * numbers

	return scores


## The winning goal, with the 25% incumbent hysteresis that stops goal flutter.
static func pick(c: Context) -> int:
	var scores: Dictionary = score(c)
	if scores.has(c.current_goal):
		scores[c.current_goal] *= 1.25
	var best_goal: int = Enums.AIGoal.NONE
	var best_score: float = 0.0
	for goal in scores:
		if scores[goal] > best_score:
			best_score = scores[goal]
			best_goal = goal
	return best_goal
