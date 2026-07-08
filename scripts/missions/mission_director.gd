## mission_director.gd - Owns MissionState, tracked spawning (the kill-count fix:
## every kill counts via EnemyBase.died, never CombatManager's broken path),
## objective completion, mission end states (NS07).
class_name MissionDirector
extends Node

signal objective_completed(index: int, title: String)
signal mission_completed(result: Dictionary)
signal mission_failed(result: Dictionary)
signal enemy_killed(enemy: EnemyBase, group_tag: String)
signal toast(text: String)

var state := MissionState.new()
var world: GameWorld
var _ended: bool = false
var _live_enemies: Array[EnemyBase] = []


func setup(game_world: GameWorld) -> void:
	world = game_world
	state.start_time_ms = Time.get_ticks_msec()
	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)
	state.objective_met.connect(_on_objective_met)


## Spawn an enemy seated on terrain and wire its death into mission counters.
func spawn_tracked_enemy(pos: Vector3, data_path: String, group_tag: String = "") -> EnemyBase:
	var seated := pos
	if world and world.terrain_manager:
		seated.y = world.terrain_manager.get_height_at(pos) + 0.5
	var parent: Node = world if world != null else get_parent()
	var enemy: EnemyBase = EnemyBase.spawn_enemy(parent, seated, data_path)
	enemy.died.connect(_on_enemy_died.bind(group_tag))
	_live_enemies.append(enemy)
	return enemy


func _on_enemy_died(enemy: EnemyBase, group_tag: String) -> void:
	state.record_kill()
	_live_enemies.erase(enemy)
	enemy_killed.emit(enemy, group_tag)


func live_enemy_count(group_tag: String = "") -> int:
	if group_tag.is_empty():
		return _live_enemies.size()
	var count: int = 0
	for e in _live_enemies:
		if is_instance_valid(e) and e.is_in_group(group_tag):
			count += 1
	return count


func complete_objective(index: int) -> void:
	state.complete_objective(index)


func _on_objective_met(index: int) -> void:
	var title: String = str(state.objective_titles.get(index, "OBJECTIVE"))
	objective_completed.emit(index, title)
	toast.emit("OBJECTIVE COMPLETE: %s" % title)
	if state.is_exfil_unlocked():
		toast.emit("ALL OBJECTIVES COMPLETE - PROCEED TO EXFIL")


func finish_mission() -> void:
	if _ended:
		return
	_ended = true
	mission_completed.emit(state.build_result(true))


func fail_mission(reason: String) -> void:
	if _ended:
		return
	_ended = true
	mission_failed.emit(state.build_result(false, reason))


func _on_player_died() -> void:
	fail_mission("KIA")


## ABORT: hold the radio key 2s anywhere -> emergency exfil (fail-forward).
var exfil_zone: ExfilZone
var _abort_hold: float = 0.0


func _process(delta: float) -> void:
	if _ended or exfil_zone == null:
		return
	if Input.is_action_pressed("radio") and GameManager.can_player_act():
		_abort_hold += delta
		if _abort_hold >= 2.0 and not state.emergency_exfil and not state.is_exfil_unlocked():
			state.emergency_exfil = true
			exfil_zone.force_unlock = true
			toast.emit("ABORT ACKNOWLEDGED - EMERGENCY EXFIL AUTHORIZED")
	else:
		_abort_hold = 0.0


func is_ended() -> bool:
	return _ended
