## test_handset_fire_net.gd - the handset IS the net.
##
## The Summoner grabbed the radio and had no fire options: player.holding_handset
## (player.gd) and FieldDirector.fire_menu_open (field_director.gd) were two unrelated
## "on the net" states. This probe holds the unification: ON THE NET <=> HANDSET IN
## HAND <=> FIRE OPTIONS VISIBLE, one truth (holding_handset) mirrored to the menu.
##
## EVERY assertion here has been mutation-checked - the real source was broken by hand,
## this probe was run, and the FAIL was observed before the revert (see the build
## report for the quoted failures). A green probe against both the fix and its absence
## proves nothing; this suite has been burned by exactly that all week.
##
## Run: godot --headless --path . res://tests/test_handset_fire_net.tscn
extends Node

var _fails: int = 0
var _menu_events: Array[bool] = []


func _ready() -> void:
	print("=== HANDSET <=> FIRE NET (unification) ===")
	await get_tree().physics_frame
	await _test_grab_opens_menu()
	await _test_return_closes_menu()
	await _test_t_path_open_close()
	await _test_cord_stretch_keeps_the_handset()
	await _test_radio_check_gates_on_living_rto()
	await _test_invariant_never_desyncs()

	if _fails == 0:
		print("=== HANDSET FIRE NET PASS ===")
	else:
		print("=== HANDSET FIRE NET FAIL (%d) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fails += 1


## ---------- the rig: player + director(in "mission_director") + squad + RTO + handset ----------
## Mirrors what ai_stress_arena wires (hosted FieldDirector, SPARKS the RTO, a bound
## PRC-25) with the minimum a probe needs. RTO sits 2m off so the cord (3m) reaches.
class Rig:
	var player: CharacterBody3D
	var director: FieldDirector
	var squad: SquadSystem
	var rto: AllyBase
	var handset: RadioHandset
	var world: GameWorld


func _make_rig() -> Rig:
	var r := Rig.new()

	r.player = load("res://scenes/player/player.tscn").instantiate() as CharacterBody3D
	add_child(r.player)
	r.player.set_physics_process(false)
	r.player.global_position = Vector3.ZERO
	await get_tree().physics_frame

	# Inert GameWorld: NOT added to the tree, so _ready() (world generation) never runs.
	# FieldDirector._radio_check / _open_net / _close_net read only world.player.
	r.world = GameWorld.new()
	r.world.player = r.player
	r.world.map_size = 500.0

	r.director = FieldDirector.new()
	r.director.name = "ProbeFieldDirector"
	add_child(r.director)
	r.director.setup(r.world)   # adds to group "mission_director" -> player._notify_net finds it
	r.director._hunter_pool = 0
	r.director.fire_support = {"bombs": 9, "napalm": 9, "arty": 9, "mortar": 9, "spectre": 9, "cbu": 9}
	r.director.fire_menu_changed.connect(func(open: bool) -> void: _menu_events.append(open))

	r.squad = SquadSystem.new()
	r.squad.set_physics_process(false)
	r.squad.set_process(false)
	add_child(r.squad)

	r.rto = AllyBase.spawn_ally(self, Vector3(2.0, 0.0, 0.0))
	r.rto.set_physics_process(false)
	r.rto.add_to_group("radioman")
	r.rto.member = {"nick": "SPARKS", "mos": "RTO"}
	r.squad.members.append(r.rto)
	r.director.squad_system = r.squad

	r.handset = _build_handset_on(r.rto)
	r.player.call("bind_radio_handset", r.handset)
	r.rto.set_meta("handset", r.handset)
	await get_tree().physics_frame
	return r


func _tear_down(r: Rig) -> void:
	if r.world != null and is_instance_valid(r.world):
		r.world.free()      # never entered the tree
	for n in [r.rto, r.squad, r.director, r.player]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_menu_events.clear()
	await get_tree().physics_frame


func _rifle_hidden(player: Node) -> bool:
	var wh: Node = player.get_node("Head/Camera3D/WeaponHolder")
	var wm = wh.get("weapon_model")
	return wm != null and not (wm as Node3D).visible


## 1. Grab the handset (the single entry set_on_net(true), the path the RTO menu's GRAB
## now takes) -> the fire menu opens: options visible, rifle slung, handset HELD.
func _test_grab_opens_menu() -> void:
	print("[1] GRAB HANDSET opens the fire menu")
	var r := await _make_rig()

	_ok(not bool(r.player.get("holding_handset")), "before: handset NOT in hand")
	_ok(not r.director.fire_menu_open, "before: fire menu CLOSED")

	r.player.call("set_on_net", true)

	_ok(bool(r.player.get("holding_handset")), "after: handset IN HAND")
	_ok(r.director.fire_menu_open, "after: fire menu OPEN (the options are visible)")
	_ok(r.handset.state == RadioHandset.State.HELD, "physical handset is HELD")
	_ok(_rifle_hidden(r.player), "rifle is SLUNG (weapon model hidden)")
	_ok(_menu_events.has(true), "fire_menu_changed(true) fired for the HUD")

	await _tear_down(r)


## 2. Hang up (set_on_net(false)) -> the menu closes and the rifle comes back up.
func _test_return_closes_menu() -> void:
	print("[2] RETURN handset closes the fire menu")
	var r := await _make_rig()
	r.player.call("set_on_net", true)
	_ok(r.director.fire_menu_open and bool(r.player.get("holding_handset")), "on the net first")

	r.player.call("set_on_net", false)

	_ok(not bool(r.player.get("holding_handset")), "handset OUT of hand")
	_ok(not r.director.fire_menu_open, "fire menu CLOSED")
	_ok(r.handset.state == RadioHandset.State.STOWED, "physical handset back STOWED")
	_ok(not _rifle_hidden(r.player), "rifle is BACK UP")
	await _tear_down(r)


## 3. The [T] key path: FieldDirector._open_net / _close_net drive the player, and the
## player mirrors the menu back. Both ends move together from the director side too.
func _test_t_path_open_close() -> void:
	print("[3] [T] path (director _open_net / _close_net) stays coherent")
	var r := await _make_rig()

	r.director._open_net()
	_ok(bool(r.player.get("holding_handset")) and r.director.fire_menu_open,
		"director._open_net raised the handset AND opened the menu")

	r.director._close_net()
	_ok(not bool(r.player.get("holding_handset")) and not r.director.fire_menu_open,
		"director._close_net lowered the handset AND closed the menu")
	await _tear_down(r)


## 4. THE CORD NEVER TAKES THE HANDSET AWAY. Walk past cord stretch on the net and he KEEPS
## it — the call is not dropped by geometry.
##
## This section asserted the opposite: that stretching the cord ripped the handset back to
## STOWED and closed the menu with it. That snap was DELETED on his 2026-08-04 ruling ("the
## cord NEVER rips the handset away") along with the cord_snapped signal, and cord_length
## went 3 -> 8m to cover the RTO's 4.5m leash. radio_handset.gd carries no snap logic at all
## now, so the probe was demanding a behaviour the code was deliberately relieved of.
##
## Inverted, because the guarantee is worth a probe: the leash that governs the net is the
## RTO (section 5), never the wire between them.
func _test_cord_stretch_keeps_the_handset() -> void:
	print("[4] CORD STRETCH does not take the handset")
	var r := await _make_rig()
	r.player.call("set_on_net", true)
	_ok(r.director.fire_menu_open, "on the net before the stretch")

	# Drag the held end 10m from the radio - well past the 8m cord.
	r.handset.held_endpoint.global_position = r.handset.cord.port.global_position + Vector3(10, 0, 0)
	r.handset._physics_process(0.016)

	_ok(r.handset.state == RadioHandset.State.HELD, "he still has the handset")
	_ok(bool(r.player.get("holding_handset")), "holding_handset survives the stretch")
	_ok(r.director.fire_menu_open, "the fire menu is still open - geometry does not drop the call")
	await _tear_down(r)


## 5. The leash is a MAN: _radio_check must fail with a dead/absent RTO or out of range,
## and pass only with a living RTO within reach. This is the Fairness/RTO canon and it
## must survive the unification untouched.
func _test_radio_check_gates_on_living_rto() -> void:
	print("[5] fire support stays gated on a living RTO (_radio_check)")
	var r := await _make_rig()

	_ok(str(r.director.call("_radio_check")) == "", "living RTO within 10m -> usable")

	# Out of range: shove the player 30m off.
	r.player.global_position = Vector3(0, 0, 30)
	await get_tree().physics_frame
	_ok(str(r.director.call("_radio_check")) != "", "player 30m away -> gated (too far)")
	r.player.global_position = Vector3.ZERO
	await get_tree().physics_frame

	# RTO ABSENT. _radio_check resolves through nearest_radioman() - the "radioman" GROUP -
	# not member_by_mos, so clearing his MOS no longer takes him off the net. That is the
	# intended shape ("should be any radioman"), so take him out the way the code actually
	# looks for him. MOS stays cleared too, so this holds if the resolver ever changes back.
	r.rto.member = {"nick": "SPARKS", "mos": ""}
	r.rto.remove_from_group("radioman")
	_ok(str(r.director.call("_radio_check")) != "", "RTO down/absent -> gated (no radio)")
	await _tear_down(r)


## 6. THE INVARIANT: holding_handset and fire_menu_open are ONE state. After ANY
## transition they must be EQUAL. This is the assertion the desync mutations bite:
## break the mirror (_notify_net) or the hang-up (_close_net) and one moves without the
## other, and holding_handset == fire_menu_open goes false.
func _test_invariant_never_desyncs() -> void:
	print("[6] on-net and handset-in-hand NEVER disagree")
	var r := await _make_rig()

	var seq: Array[bool] = [true, false, true, true, false, false]
	for want in seq:
		r.player.call("set_on_net", want)
		var hold: bool = bool(r.player.get("holding_handset"))
		var menu: bool = r.director.fire_menu_open
		_ok(hold == menu, "after set_on_net(%s): handset=%s menu=%s (must match)" % [
			str(want), str(hold), str(menu)])
	await _tear_down(r)


## Minimal RTO-side handset built on a real ally body (port/guide/stow anchors + cord),
## the held mesh/endpoint supplied by player.bind_radio_handset. Mirrors
## ai_stress_arena._attach_radio_to_rto.
func _build_handset_on(rto: AllyBase) -> RadioHandset:
	var stowed := MeshInstance3D.new()
	stowed.mesh = BoxMesh.new()
	rto.add_child(stowed)
	stowed.position = Vector3(0.14, 1.2, -0.12)

	var port := Marker3D.new()
	rto.add_child(port)
	port.position = Vector3(0, 1.25, -0.18)
	var guide := Marker3D.new()
	rto.add_child(guide)
	guide.position = Vector3(0.16, 1.4, -0.05)
	var stow_ep := Marker3D.new()
	rto.add_child(stow_ep)
	stow_ep.position = Vector3(0.14, 1.2, -0.12)

	var cord := RadioCord.new()
	cord.port = port
	cord.guide = guide
	cord.endpoint = stow_ep
	rto.add_child(cord)

	var h := RadioHandset.new()
	h.stowed_mesh = stowed
	h.cord = cord
	h.stowed_endpoint = stow_ep
	rto.add_child(h)
	return h
