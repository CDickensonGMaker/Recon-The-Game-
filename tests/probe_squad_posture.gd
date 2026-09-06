## probe_squad_posture.gd - item 28: "the squad does not crouch when you crouch, and
## they stand on top of you."
##
## Two defects in one line, and both were evidence-of-absence before this ran:
##   POSTURE - player.is_crouching had no reader on the ally side at all. Only
##             enemy_base.gd:1224,1254 read it, and only to shoot at him.
##   SPACING - _refresh_separation walks AgentRegistry.allies, and the PLAYER IS NOT
##             IN IT, so no squadmate ever felt a push off the body he was standing
##             in. It is also only refreshed once contact opens, so before a shot was
##             fired nothing kept a man off you at all.
##
## Drives the real AllyBase against a stand-in player. No world boot: both defects
## live in two functions that read GameManager.player and nothing else.
##   godot --headless --path . res://tests/probe_squad_posture.tscn
extends Node

var _failures: int = 0
var _ally: AllyBase = null
var _player: CharacterBody3D = null


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== SQUAD POSTURE PROBE (item 28) ===")
	_player = CharacterBody3D.new()
	_player.set_script(load("res://tests/stubs/crouch_stub.gd"))
	add_child(_player)
	_player.global_position = Vector3.ZERO
	GameManager.player = _player

	_ally = AllyBase.new()
	add_child(_ally)
	await get_tree().physics_frame
	_ally.current_state = Enums.AIState.IDLE

	# ---- POSTURE ----
	_ally.global_position = Vector3(2.0, 0.0, 0.0)
	_player.is_crouching = false
	_player.is_prone = false
	if _ally._is_low_posture(false):
		_fail("the ally is low while the player stands - the mirror is inverted")
	_player.is_crouching = true
	if not _ally._is_low_posture(false):
		_fail("the player crouched at 2m and the ally stayed up")
	else:
		print("  player crouches at 2m -> squadmate goes low")
	_player.is_prone = true
	_player.is_crouching = false
	if not _ally._is_low_posture(false):
		_fail("the player went prone at 2m and the ally stayed up")
	_player.is_prone = false
	_player.is_crouching = true

	# Out of sight of him is out of the mirror.
	_ally.global_position = Vector3(AllyBase.CROUCH_MIRROR_M + 5.0, 0.0, 0.0)
	if _ally._is_low_posture(false):
		_fail("an ally %.0fm away mirrored the crouch - the range gate does nothing"
			% (AllyBase.CROUCH_MIRROR_M + 5.0))
	else:
		print("  a man %.0fm off does not copy it" % (AllyBase.CROUCH_MIRROR_M + 5.0))

	# A committed push outranks copying you, or taking a knee stalls the squad.
	_ally.global_position = Vector3(2.0, 0.0, 0.0)
	_ally.current_state = Enums.AIState.ADVANCING
	if _ally._is_low_posture(false):
		_fail("an ADVANCING man crouched because you did - the mirror is outranking the push")
	else:
		print("  an advancing man keeps going")
	_ally.current_state = Enums.AIState.IDLE

	# ---- SPACING ----
	# Standing in him. He must step OFF, and away from the player, not anywhere.
	_ally.global_position = Vector3(0.3, 0.0, 0.0)
	_ally.velocity = Vector3.ZERO
	_ally._apply_player_standoff(0.05)
	var away: float = Vector3(_ally.velocity.x, 0.0, _ally.velocity.z).dot(Vector3.RIGHT)
	if away <= 0.0:
		_fail("a squadmate standing 0.3m inside the player got no push off him (%.3f m/s outward)"
			% away)
	else:
		print("  0.3m inside the player -> %.2f m/s straight off him" % away)

	# At arm's length and beyond, he is left alone: this must not become a repulsor
	# field that pushes the squad out of the formation slots.
	_ally.global_position = Vector3(AllyBase.PLAYER_SPACING_M + 1.0, 0.0, 0.0)
	_ally.velocity = Vector3.ZERO
	_ally._apply_player_standoff(0.05)
	if _ally.velocity.length() > 0.001:
		_fail("a man %.1fm away was still being pushed - the bubble has no edge"
			% (AllyBase.PLAYER_SPACING_M + 1.0))
	else:
		print("  %.1fm away -> no push at all" % (AllyBase.PLAYER_SPACING_M + 1.0))

	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
