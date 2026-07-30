class_name MeleeVerb
extends RefCounted

## The knife. One verb, two outcomes, and the difference is entirely whether he knew you
## were there: a stab from the front is a fight, a stab from behind an unalerted man is a
## silent takedown.
##
## ONE DAMAGE GRAMMAR (ADR-003/ADR-016): a strike routes through the target's own
## `take_damage`, exactly as a bullet does. There is no melee damage authority - the
## takedown is expressed as the HEAD zone, which ADR-016 already rules is fatal, so this
## file states no lethality of its own.
##
## Sound is what makes the takedown worth doing: a stab emits NOTHING on the NoiseBus,
## while a rifle shot does. Killing quietly is the whole mechanic.

## Reach and arc of the blade. Short and forgiving - a knife that needs pixel aim is a
## knife nobody uses.
const REACH_M: float = 1.9
const ARC_DEG: float = 60.0
## A frontal stab is a real wound, not a scratch: 27 is the ADR-016 base rifle round, and
## the blade matches it rather than inventing a number.
const FRONT_DAMAGE: int = 27
## How far behind the target you must be for the silent kill. Dot of his facing against
## the direction to you: 0.35 is a generous rear ~110-degree wedge.
const BEHIND_DOT: float = 0.35
const COOLDOWN_MS: float = 0.75 * 1000.0

static var _last_strike_ms: float = -1.0e9


## Swing. Returns true if the blade found a man. Safe to call from any slot.
static func strike(attacker: Node3D) -> bool:
	if attacker == null or not is_instance_valid(attacker):
		return false
	var now: float = float(Time.get_ticks_msec())
	if now - _last_strike_ms < COOLDOWN_MS:
		return false
	_last_strike_ms = now

	var victim: Node3D = _target_in_arc(attacker)
	if victim == null:
		return false
	if not victim.has_method("take_damage"):
		return false

	if _is_behind(attacker, victim) and _is_unaware(victim):
		# HEAD is the fatal zone in the one grammar - this file does not decide lethality,
		# it names where the blade went (ADR-016 Amendment D, Hitzone.zone_name_is_fatal).
		victim.call("take_damage", 999, Enums.DamageType.PHYSICAL, attacker, "HEAD")
		return true
	victim.call("take_damage", FRONT_DAMAGE, Enums.DamageType.PHYSICAL, attacker, "TORSO")
	return true


## Whether the blade would kill silently right now - drives the [F]-style prompt and the
## clip choice, and must use the SAME tests as strike() or the prompt lies.
static func takedown_ready(attacker: Node3D) -> bool:
	var v: Node3D = _target_in_arc(attacker)
	return v != null and _is_behind(attacker, v) and _is_unaware(v)


static func _target_in_arc(attacker: Node3D) -> Node3D:
	if attacker == null or attacker.get_tree() == null:
		return null
	var fwd: Vector3 = -attacker.global_transform.basis.z
	if attacker.has_method("get_aim_direction"):
		fwd = attacker.call("get_aim_direction") as Vector3
	fwd = Vector3(fwd.x, 0.0, fwd.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else -attacker.global_transform.basis.z
	var best: Node3D = null
	var best_d: float = REACH_M
	var cos_arc: float = cos(deg_to_rad(ARC_DEG))
	for e in attacker.get_tree().get_nodes_in_group("enemies"):
		var man := e as Node3D
		if man == null or not is_instance_valid(man) or man == attacker:
			continue
		if man.has_method("is_dead") and man.call("is_dead"):
			continue
		var to: Vector3 = man.global_position - attacker.global_position
		var d: float = to.length()
		if d > best_d or d < 0.01:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() < 0.01:
			continue
		if fwd.dot(flat.normalized()) < cos_arc:
			continue
		best_d = d
		best = man
	return best


## Behind = the victim is facing away from the attacker.
static func _is_behind(attacker: Node3D, victim: Node3D) -> bool:
	var face: Vector3 = -victim.global_transform.basis.z
	if "facing_dir" in victim:
		var f: Vector3 = victim.get("facing_dir")
		if f.length() > 0.01:
			face = f
	face = Vector3(face.x, 0.0, face.z)
	if face.length() < 0.01:
		return false
	var to_att: Vector3 = attacker.global_position - victim.global_position
	to_att = Vector3(to_att.x, 0.0, to_att.z)
	if to_att.length() < 0.01:
		return false
	# Negative dot = the attacker is behind the direction he faces.
	return face.normalized().dot(to_att.normalized()) < -BEHIND_DOT


## Unaware = he has not escalated past a suspicion. AlertTier is the existing authority
## for "he has not seen you" (enemy_base.gd:96) - do not invent a second one. A man who
## already holds a target is aware by definition, whatever his tier says.
static func _is_unaware(victim: Node3D) -> bool:
	if "target" in victim and victim.get("target") != null:
		return false
	if not ("alert_tier" in victim):
		return false
	return int(victim.get("alert_tier")) <= int(EnemyBase.AlertTier.SUSPICIOUS)
