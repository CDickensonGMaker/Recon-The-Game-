## body_swap_system.gd - THE LIVES ECONOMY (ruled 2026-08-22, pool sized 2026-08-24).
## A life is a NAMED MAN, never a number: on force_death the player wakes in the
## eyes of the nearest living man of a pre-picked pool, with that man's kit. The
## war never pauses under the epitaph - the black is a card over a running fight.
## Pool exhausted -> try_swap() refuses and the existing KIA chain runs unchanged.
##
## The pool is picked ONCE, preferring the promoted garrison and falling back to
## the living men around you when stand-to has not run yet (daylight). No count
## is ever rendered - the card carries names (ADR-032 extension, R4 8/24).
class_name BodySwapSystem
extends Node

const POOL_SIZE: int = 3          ## swaps beyond the first body: 4 men total (his ruling 8/24)
const BLACK_SECONDS: float = 3.5

var player: Node3D = null
var bodies_spent: Array[String] = []   ## "RANK Name" per body burned - the end card's KIA rows

var _hs: HealthSystem = null
var _blocked: Callable = Callable()    ## host says "the run already ended" (end card up)
var _pool: Array[AllyBase] = []
var _picked: bool = false
var _identity: String = ""             ## who the player IS right now, card idiom
var _unit: String = ""                 ## the current body's model, for the corpse it leaves
var _swapping: bool = false


func setup(p: Node3D, hs: HealthSystem, first_identity: String, blocked: Callable) -> void:
	player = p
	_hs = hs
	_identity = first_identity
	_blocked = blocked
	hs.swap_handler = self


## HealthSystem.force_death() consults this. True = the death was spent on the
## body and the player wakes elsewhere; false = let the real KIA chain run.
func try_swap() -> bool:
	if _swapping or player == null or not is_instance_valid(player):
		return false
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	if not _picked:
		_pick_pool()
	var target: AllyBase = _nearest_living()
	if target == null:
		return false
	_swapping = true
	_run_swap(target)
	return true


## The pool is fixed at first need: the POOL_SIZE living men nearest the player.
## Fixed men, not a refilling slot - a pool that re-picks every death is a ticket
## dispenser wearing names. It latches only once men are actually in it.
func _pick_pool() -> void:
	if player.get_tree() == null:
		return
	var candidates: Array[AllyBase] = _living_in("garrison_promoted")
	if candidates.is_empty():
		# Daylight: stand-to has not run, so nobody is promoted yet. The pool
		# falls back to the men actually beside you.
		candidates = _living_in("allies")
	if candidates.is_empty():
		return    # nothing to latch onto; a later death re-scans
	candidates.sort_custom(func(x: AllyBase, y: AllyBase) -> bool:
		return x.global_position.distance_squared_to(player.global_position) \
			< y.global_position.distance_squared_to(player.global_position))
	for i in range(mini(POOL_SIZE, candidates.size())):
		_pool.append(candidates[i])
	_picked = true


func _living_in(group: String) -> Array[AllyBase]:
	var out: Array[AllyBase] = []
	for n in player.get_tree().get_nodes_in_group(group):
		var a := n as AllyBase
		if a != null and is_instance_valid(a) and not a.is_dead():
			out.append(a)
	return out


func _nearest_living() -> AllyBase:
	var best: AllyBase = null
	var best_d: float = INF
	for a in _pool:
		if a == null or not is_instance_valid(a) or a.is_dead():
			continue
		var d: float = a.global_position.distance_squared_to(player.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _run_swap(target: AllyBase) -> void:
	# god_mode across the blind seconds is a re-entry guard (a hit at 0 HP would
	# re-run force_death mid-swap), not a mercy - the council accepted being shot
	# at while blind; being KILLED twice in one death is the thing this forbids.
	_hs.set_god_mode(true)
	var died_as: String = _identity
	bodies_spent.append(died_as)
	_spawn_corpse()
	var overlay: CanvasLayer = _make_epitaph(died_as, _name_of(target), target)
	await get_tree().create_timer(BLACK_SECONDS).timeout
	if not is_instance_valid(target) or target.is_dead():
		# He died under the black: wake in the next living man. The card named a
		# dead man for 3.5s - truthful when shown, and the fight explains it.
		target = _nearest_living()
	if target == null:
		# Every man in the pool died while the card was up: this death was the
		# last one after all. _swapping still true, so the re-entry falls through
		# to the real KIA chain instead of consulting us again.
		overlay.queue_free()
		_hs.set_god_mode(false)
		_hs.force_death()
		_swapping = false
		return
	_identity = _name_of(target)
	_unit = str(target.get_meta("garrison_unit", ""))
	_take_over(target)
	if player.has_method("recover_from_collapse"):
		player.call("recover_from_collapse")
	overlay.queue_free()
	_hs.set_god_mode(false)
	_hs.current_hp = _hs.max_hp
	_hs.health_changed.emit(_hs.current_hp, _hs.max_hp)
	_swapping = false


func _name_of(a: AllyBase) -> String:
	return "%s %s" % [SquadRoster.rank_for(a.member), str(a.member.get("name", "?"))]


## Move the PLAYER NODE into the man's place and retire the man - squad wiring,
## medic chain and rank all stay bound to "you" (ADR-032's disembodied rank).
func _take_over(target: AllyBase) -> void:
	var manning: Variant = player.get("is_manning_mg")
	if manning is bool and manning and player.has_method("dismount_mg"):
		player.call("dismount_mg")
	var stand: Vector3 = target.global_position
	var face: Vector3 = target.current_aim_dir
	var wp: WeaponData = target.weapon_data
	# Same explicit teardown as GarrisonDefender.stand_down - his station goes
	# back to the pit and the registry forgets him, or the next stand-to finds
	# a ghost holding the tube.
	var pit := (target.get_meta("mortar_pit") if target.has_meta("mortar_pit") else null) as MortarPit
	if pit != null and is_instance_valid(pit):
		pit.release(str(target.get_meta("mortar_station", "")))
	_pool.erase(target)
	target.remove_from_group("garrison_promoted")
	AgentRegistry.unregister(target)
	target.set_physics_process(false)
	target.queue_free()
	player.global_position = stand
	var flat := Vector3(face.x, 0.0, face.z)
	if flat.length() > 0.1:
		player.look_at(player.global_position + flat.normalized())
	if wp != null and player.has_method("give_weapon") and not wp.resource_path.is_empty():
		player.call("give_weapon", wp.resource_path)


## The body you leave behind. The player has no third-person model, so the
## corpse wears the body's unit model (previous swap target's, or a garrison
## man's for the first body) - honest enough at PSX fidelity for the ledger
## claim "he fell here" and the recover-your-rifle window allies already get.
func _spawn_corpse() -> void:
	var parent: Node = player.get_parent()
	if parent == null:
		return
	var corpse: AllyBase = AllyBase.spawn_ally(parent, player.global_position)
	corpse.squad_member = false
	corpse.member = {"name": _identity}
	var unit: String = _unit
	if unit.is_empty() and not Civilian.GARRISON_MEN.is_empty():
		unit = Civilian.GARRISON_MEN[0]
	if not unit.is_empty():
		corpse.set_sprite(unit, "m16a1")
	corpse.last_hit_dir = Vector3.DOWN
	corpse.take_damage(99999)


## Amber-on-black, the end card's exact idiom. Layer 85: under the end card
## (90), over the HUD. The war runs beneath it - that is the read. FADES in
## (his ruling 2026-08-24: lay in place, "than fade to black AFTER they die");
## the wake side stays a hard cut - the disorientation is the feature.
func _make_epitaph(died_as: String, wake_as: String, becoming: AllyBase) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 85
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.modulate.a = 0.0
	create_tween().tween_property(black, "modulate:a", 1.0, 0.8)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(ReconUI.make_label("%s - KIA" % died_as, 30, ReconUI.AMBER))
	col.add_child(ReconUI.make_label("THE LINE HOLDS", 16, ReconUI.DIM))
	col.add_child(ReconUI.make_label("YOU ARE %s" % wake_as, 22, ReconUI.AMBER))
	var holding: Array[String] = []
	for a in _pool:
		if a != null and is_instance_valid(a) and not a.is_dead() and a != becoming:
			holding.append(str(a.member.get("name", "?")))
	if not holding.is_empty():
		col.add_child(ReconUI.make_label("HOLDING: %s" % " · ".join(holding), 14, ReconUI.DIM))
	cc.add_child(col)
	black.add_child(cc)
	layer.add_child(black)
	add_child(layer)
	return layer
