## test_radio_handset.gd - the RTO handset loop (per-man follow, aim-to-open, grab,
## cord snap). Holds the wiring that buries radio_handset.gd's TEST-ONLY fossils.
##
## Every assertion here has been mutation-checked: the real source was broken by
## hand, this probe was run, and the FAIL was observed before the revert. See the
## build report for the quoted failures - a green probe against both the fix and its
## absence proves nothing.
##
## Run: godot --headless --path . res://tests/test_radio_handset.tscn
extends Node

var _fails: int = 0
var _taken_fired: int = 0
var _snapped_fired: int = 0


func _ready() -> void:
	print("=== RADIO HANDSET (RTO loop) ===")
	await get_tree().physics_frame
	await _test_per_man_follow_only()
	await _test_aim_opens_only_on_rto()
	await _test_grab_swaps_and_slings_rifle()
	_test_cord_snap_returns_to_stowed()

	if _fails == 0:
		print("=== RADIO HANDSET PASS ===")
	else:
		print("=== RADIO HANDSET FAIL (%d) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fails += 1


## A: pressing FOLLOW ME in the real radio menu moves the RTO ONLY - the rest of the
## squad is untouched. Drives the actual production path (player._open_radio_menu ->
## the menu's follow_requested lambda), not a hand-copy of it.
func _test_per_man_follow_only() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as CharacterBody3D
	add_child(player)
	player.set_physics_process(false)
	await get_tree().physics_frame

	var allies: Array[AllyBase] = []
	for i in range(3):
		var a := AllyBase.spawn_ally(self, Vector3(float(i) * 2.0, 0, 0))
		a.set_physics_process(false)  # order logic only; no think/move noise
		a.set_order(AllyBase.OrderMode.HOLD)
		allies.append(a)
	var rto: AllyBase = allies[1]
	rto.add_to_group("radioman")

	player.call("_open_radio_menu", rto)
	var menu = player.get("_radio_menu")
	_ok(menu != null, "the radio menu opened")
	if menu != null:
		menu.emit_signal("follow_requested")

	_ok(rto.order_mode == AllyBase.OrderMode.FOLLOW, "RTO is now FOLLOW")
	_ok(allies[0].order_mode == AllyBase.OrderMode.HOLD
		and allies[2].order_mode == AllyBase.OrderMode.HOLD,
		"the other two men are STILL HOLD - the squad was not ordered")

	for a in allies:
		a.queue_free()
	player.queue_free()
	await get_tree().physics_frame


## B: player._aimed_radioman() returns the RTO ONLY when a radioman is aimed at
## within reach - not a far radioman, not a near NON-radioman.
func _test_aim_opens_only_on_rto() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as CharacterBody3D
	add_child(player)
	player.set_physics_process(false)  # keep him still; _aimed_radioman is a plain call
	player.global_position = Vector3(0, 0, 50)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var fwd: Vector3 = player.call("get_aim_direction")
	var base: Vector3 = player.global_position

	# In reach (2m), tagged radioman -> found.
	var rto := AllyBase.spawn_ally(self, base + fwd * 2.0)
	rto.set_physics_process(false)
	rto.add_to_group("radioman")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok(player.call("_aimed_radioman") == rto, "aim at radioman in reach -> found")

	# Same man, out of reach (6m > RADIO_REACH 3m) -> null.
	rto.global_position = base + fwd * 6.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok(player.call("_aimed_radioman") == null, "aim at radioman out of reach -> null")

	# A NON-radioman ally in reach at the same spot -> null (the group gate bites).
	rto.global_position = base + fwd * 40.0  # get him out of the lane
	var grunt := AllyBase.spawn_ally(self, base + fwd * 2.0)
	grunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok(player.call("_aimed_radioman") == null, "aim at a NON-radioman in reach -> null")

	rto.queue_free()
	grunt.queue_free()
	player.queue_free()
	await get_tree().physics_frame


## C: GRAB HANDSET -> take() swaps the meshes, fires handset_taken, and the player's
## rifle is slung (weapon model hidden, holding_handset true, placeholder shown).
func _test_grab_swaps_and_slings_rifle() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as CharacterBody3D
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0, 0)
	await get_tree().physics_frame

	var h := _build_handset(Vector3.ZERO)
	player.call("bind_radio_handset", h)
	h.handset_taken.connect(func(_by: Node3D) -> void: _taken_fired += 1)

	var stowed: MeshInstance3D = h.stowed_mesh
	var held: MeshInstance3D = h.held_mesh   # the player's viewmodel placeholder
	_ok(stowed.visible and not held.visible, "before grab: stowed shown, held hidden")

	var took: bool = h.take(player)
	_ok(took, "take() accepted (was STOWED)")
	_ok(not stowed.visible, "stowed handset mesh went INVISIBLE")
	_ok(held.visible, "held placeholder went VISIBLE")
	_ok(_taken_fired == 1, "handset_taken fired exactly once")
	_ok(bool(player.get("holding_handset")), "player.holding_handset is true")

	var wh: Node = player.get_node("Head/Camera3D/WeaponHolder")
	var wm = wh.get("weapon_model")
	_ok(wm != null and not (wm as Node3D).visible, "rifle viewmodel is HIDDEN (rifle slung)")

	# Stash for the snap test (same player, same handset).
	_snap_player = player
	_snap_handset = h
	_snap_stowed = stowed
	_snap_held = held


var _snap_player: CharacterBody3D = null
var _snap_handset: RadioHandset = null
var _snap_stowed: MeshInstance3D = null
var _snap_held: MeshInstance3D = null


## D: walk past full cord stretch -> the handset is ripped back to STOWED and the
## rifle comes back up.
func _test_cord_snap_returns_to_stowed() -> void:
	var h: RadioHandset = _snap_handset
	if h == null:
		_ok(false, "no handset carried over from grab test")
		return
	h.cord_snapped.connect(func() -> void: _snapped_fired += 1)

	# Drag the held end 10m from the radio: past cord_length (3m) => tension >= 1.
	h.held_endpoint.global_position = h.cord.port.global_position + Vector3(10, 0, 0)
	h._physics_process(0.016)  # the cord/snap tick

	_ok(h.state == RadioHandset.State.STOWED, "handset is back to STOWED after the snap")
	_ok(_snapped_fired == 1, "cord_snapped fired once")
	_ok(_snap_stowed.visible and not _snap_held.visible, "stowed shown, held hidden again")
	_ok(not bool(_snap_player.get("holding_handset")), "player.holding_handset cleared")
	var wh: Node = _snap_player.get_node("Head/Camera3D/WeaponHolder")
	var wm = wh.get("weapon_model")
	_ok(wm != null and (wm as Node3D).visible, "rifle viewmodel is BACK UP")

	_snap_player.queue_free()


## Minimal RTO-side handset: a stowed mesh, a cord with real anchors. The held mesh
## and held endpoint are supplied by player.bind_radio_handset(). Mirrors what
## ai_stress_arena._attach_radio_to_rto builds on a real RTO body.
func _build_handset(at: Vector3) -> RadioHandset:
	var rto := Node3D.new()
	add_child(rto)
	rto.global_position = at

	var stowed := MeshInstance3D.new()
	stowed.mesh = BoxMesh.new()
	rto.add_child(stowed)
	stowed.position = Vector3(0.14, 1.2, -0.12)

	var port := Marker3D.new()
	rto.add_child(port)
	port.position = Vector3(0, 1.25, -0.18)
	var stow_ep := Marker3D.new()
	rto.add_child(stow_ep)
	stow_ep.position = Vector3(0.14, 1.2, -0.12)

	var cord := RadioCord.new()
	cord.port = port
	cord.endpoint = stow_ep
	rto.add_child(cord)

	var h := RadioHandset.new()
	h.stowed_mesh = stowed
	h.cord = cord
	h.stowed_endpoint = stow_ep
	rto.add_child(h)
	return h
