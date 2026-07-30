## sapper_charge.gd - A behaviour node parented to a sapper. It drives the man's
## legs to the objective through EnemyBase.assault_objective (which pushes through
## contact), and blows the satchel when he reaches it. The blast is a full-lethality
## breach: the garrison are participants now (war-room decree 2026-07-20), so it
## spares no one, and it costs the player fire support (FieldDirector.on_firebase_breach).
##
## The player is NOT told from here: notification is the RTO net's job
## (FieldDirector.raise_crisis), so no marker ever appears from nothing.
class_name SapperCharge
extends Node

# Satchel = placed demolition charge. Damage sits at the LAW/RPG-2 tier (ADR-016:
# 250) - a rocket-warhead equivalent, below the RPG-7 (290) which stays the king;
# its identity is the wide 14m radius, not a new above-canon damage record.
## HE HAS TO REACH IT. 5m let a man drop a charge from outside arm's length, which read as
## bombs appearing before he arrived (Summoner, 2026-07-30). 2m is against the thing.
const PLACE_RANGE: float = 2.0
## Kneeling over it, working. Long enough to be a moment you can shoot him during.
const PLANT_SECONDS: float = 3.0
## The pose while he works. cargo_unload_stack is the library's crouch-and-set-down; the
## crouch idle is the fallback for a rig that lacks it.
const PLANT_CLIP: String = "cargo_unload_stack"
const SATCHEL_DAMAGE: int = 250
const SATCHEL_MIN: int = 70
const SATCHEL_RADIUS: float = 14.0
## How far out he runs. Comfortably past the blast, so the survivable case is the DEFAULT
## and getting caught means something went wrong for him.
const WITHDRAW_M: float = 26.0

var target_pos: Vector3 = Vector3.ZERO
var _armed: bool = false


## ZERO is "no objective": an unset satchel must never arm, or it detonates at
## the world origin. Silent and pure so a probe can assert the invariant without
## the shout below turning the whole suite red.
static func is_valid_objective(objective_center: Vector3) -> bool:
	return objective_center != Vector3.ZERO


func setup(objective_center: Vector3) -> void:
	if not is_valid_objective(objective_center):
		push_error("[SapperCharge] refused a ZERO objective - would detonate at origin")
		return
	_objective = objective_center
	target_pos = objective_center
	_armed = true
	var enemy := get_parent() as EnemyBase
	if enemy != null:
		_retarget(enemy)
		enemy.assault_objective = target_pos
		enemy.assault_driven = true   # the satchel pushes THROUGH contact, by doctrine


## ---------- WHAT HE GOES FOR ----------
## THE WIRE FIRST (Summoner, 2026-07-30: "they should be clearing the wire to get closer to
## the buildings"). That is the actual job: the wire is what stands between the assault and
## everything behind it, and a sapper who walks past it to bomb a bunker has left the lane
## shut for the men following him.
##
## Also fixes three men stacking one charge on one point: each CLAIMS his target, so a
## three-man party opens three holes instead of blowing the same wall three times.
const TARGET_SEARCH_M: float = 70.0
## Claim marker. Meta, not a set: it dies with the target and cannot outlive a scene.
const CLAIM_META: StringName = &"sapper_claimed_by"
## What a sapper prefers, in order. Anything not named here is last.
const TARGET_PRIORITY: Array[String] = ["wire", "sandbag_wall", "sandbag_stack",
	"bunker_mg", "bunker", "tower"]

var _objective: Vector3 = Vector3.ZERO
var _claimed: Destructible = null


func _priority_of(kind: String) -> int:
	var i: int = TARGET_PRIORITY.find(kind)
	return i if i >= 0 else TARGET_PRIORITY.size()


## Pick the best STANDING, UNCLAIMED target near the objective and walk to that instead of
## to the objective point. Falls back to the objective when nothing is on the bus, so a
## bench or a map with no destructibles behaves exactly as it did before.
func _retarget(enemy: EnemyBase) -> void:
	_release()
	var best: Destructible = null
	var best_rank: int = 1 << 30
	var best_d: float = INF
	for p in AgentRegistry.props:
		var d := p as Destructible
		if d == null or not is_instance_valid(d) or d.is_destroyed():
			continue
		if d.global_position.distance_to(_objective) > TARGET_SEARCH_M:
			continue
		# has_meta FIRST. get_meta(key, null) is indistinguishable from "no default given"
		# because the default IS null, so Godot errors instead of returning it.
		if d.has_meta(CLAIM_META):
			var claimer: Variant = d.get_meta(CLAIM_META)
			if claimer != null and is_instance_valid(claimer) and claimer != self:
				continue
		var rank: int = _priority_of(d.kind)
		var dist: float = enemy.global_position.distance_to(d.global_position)
		# Priority first, distance only to break ties WITHIN a priority band: a man does
		# not skip the wire because a bunker happens to be nearer.
		if rank < best_rank or (rank == best_rank and dist < best_d):
			best_rank = rank
			best_d = dist
			best = d
	if best == null:
		target_pos = _objective
		return
	_claimed = best
	best.set_meta(CLAIM_META, self)
	target_pos = best.global_position
	print("[SAPPER] %s -> %s at %.0f,%.0f" % [enemy.name, best.kind,
		target_pos.x, target_pos.z])


func _release() -> void:
	if _claimed != null and is_instance_valid(_claimed) 			and _claimed.has_meta(CLAIM_META) and _claimed.get_meta(CLAIM_META) == self:
		_claimed.remove_meta(CLAIM_META)
	_claimed = null


## Make the satchel inert THIS frame. queue_free alone is deferred, so a charge
## dropped during a withdrawal would still get a physics tick at its old aim point
## and detonate on the way out - and _detonate clears the rally the reap just set.
func disarm() -> void:
	_armed = false
	_planting = false
	var e := get_parent() as EnemyBase
	if e != null and is_instance_valid(e):
		e.work_clip = ""      # never leave a live man frozen in the planting pose
	_release()
	target_pos = Vector3.ZERO
	set_physics_process(false)


var _planting: bool = false
var _plant_timer: float = 0.0


## Down on one knee against the thing, working. He STOPS here - a man setting a charge is
## not still walking - and the pose is what makes the three seconds read as work rather
## than as a pause.
func _begin_planting(enemy: EnemyBase) -> void:
	_planting = true
	_plant_timer = PLANT_SECONDS
	enemy.work_clip = PLANT_CLIP
	# Objective = where he stands, so the legs stop without touching assault_driven.
	enemy.assault_objective = enemy.global_position
	print("[SAPPER] planting - %.0fs" % PLANT_SECONDS)


func _physics_process(_delta: float) -> void:
	if not _armed:
		return
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.is_dead():
		# A sapper cut down before the wire never detonates - that is the win. Killing him
		# DURING the three-second plant is the window that makes the timer matter.
		if enemy != null:
			enemy.work_clip = ""
		_planting = false
		_release()
		set_physics_process(false)
		return
	# His target may have gone up under another man's charge while he was still walking.
	# Standing over rubble with a live satchel is the thing that reads as broken.
	if _claimed != null and (not is_instance_valid(_claimed) or _claimed.is_destroyed()):
		_retarget(enemy)
		enemy.assault_objective = target_pos
	if _planting:
		_plant_timer -= _delta
		if _plant_timer <= 0.0:
			enemy.work_clip = ""
			_detonate(enemy)
		return
	if enemy.global_position.distance_to(target_pos) <= PLACE_RANGE:
		_begin_planting(enemy)


## SET IT AND RUN. He places the charge against the thing and withdraws; the satchel keeps
## its own fuse and brings the wall down behind him.
##
## This used to detonate at the man's own feet and then kill him outright, so three sappers
## on one objective died in one blast - a suicide squad, not demolition men. The charge is a
## THING now (PlacedSatchel), which is what lets him live through his own work.
func _detonate(enemy: EnemyBase) -> void:
	_armed = false
	var host: Node = get_tree().current_scene
	if host == null:
		set_physics_process(false)
		return
	# On the OBJECTIVE, not on the man: what it is meant to bring down is what it sits against.
	var at: Vector3 = target_pos
	at.y = enemy.global_position.y
	PlacedSatchel.place(host, at, enemy, SATCHEL_DAMAGE, SATCHEL_MIN, SATCHEL_RADIUS)
	_release()
	_withdraw(enemy, at)
	set_physics_process(false)


## Turn him around and send him out past the blast. He is NOT made safe - the fuse is a race
## he can lose, and a man caught by his own charge is a fair death rather than a scripted one.
func _withdraw(enemy: EnemyBase, from: Vector3) -> void:
	var away: Vector3 = enemy.global_position - from
	away.y = 0.0
	# Placed at point-blank he may be standing ON it; fall back to the way he came in.
	if away.length() < 0.5:
		away = -enemy.global_transform.basis.z
	away = away.normalized()
	enemy.assault_objective = from + away * WITHDRAW_M
	# assault_driven stays TRUE so the withdrawal outranks the fight the same way the
	# approach did - a man running from his own satchel does not stop to trade shots.
	enemy.assault_driven = true
