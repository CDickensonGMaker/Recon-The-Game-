## probe_observatory.gd - the observatory's gate (council 2026-09-14 ruling 7). Boots the demo
## world like tools/observatory.tscn, then proves, headless:
##   1. a GUNSHOT on NoiseBus beside a relaxed enemy lands in his snapshot() as the last noise and
##      in his decision ring with cause heard_gunshot, within 1 s;
##   2. a forced _change_state with a cause shows in the ring;
##   3. a civilian set_civ_state with a cause shows in HIS ring;
##   4. CampaignState.hearts.note(... cause) reaches the ledger pane's data source with cause + band;
##   5. the pane's STUCK line and the census's classify() agree on the same man (one classifier);
##   6. the ring adds no per-frame work: no ring symbol inside any _physics_process/_process body
##      of enemy_base.gd or civilian.gd (by grep of the source).
## Exit 0 on all green, 1 otherwise.
##
##   godot --headless --path . res://tools/probe_observatory.tscn -- --test-save
extends "res://tools/observatory.gd"

const CensusS := preload("res://tools/probe_npc_census.gd")
const HmS := preload("res://scripts/world/hm_ledger.gd")

var _fail: int = 0


func _check(ok: bool, msg: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", msg])
	if not ok:
		_fail += 1


func _on_world_up() -> void:
	_run()


func _run() -> void:
	print("\n=== OBSERVATORY PROBE ===")
	await get_tree().create_timer(3.0).timeout
	_check(bool(tools.call("is_on")), "overlay is on in the booted world")
	await _noise_gate()
	_state_gate()
	_civilian_gate()
	_ledger_gate()
	_stuck_gate()
	_zero_per_frame_gate()
	print(tools.call("dump_selected"))
	if _fail == 0:
		print("=== OBSERVATORY PROBE PASS ===")
	else:
		print("=== OBSERVATORY PROBE FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _pick_enemy() -> EnemyBase:
	var best: EnemyBase = null
	for n in AgentRegistry.enemies:
		var e := n as EnemyBase
		if e == null or not is_instance_valid(e) or not e.is_inside_tree() or e.is_dead():
			continue
		if e.global_position.y < -100.0:
			continue
		if best == null or int(e.alert_tier) < int(best.alert_tier):
			best = e
	return best


func _noise_gate() -> void:
	var e: EnemyBase = _pick_enemy()
	_check(e != null, "an enemy exists to listen")
	if e == null:
		return
	tools.call("select", e)
	e._set_tier(EnemyBase.AlertTier.RELAXED, false, &"probe_reset")
	var at: Vector3 = e.global_position + Vector3(6.0, 0.0, 0.0)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, at, 0, -1.0, null)
	await get_tree().create_timer(0.5).timeout
	var s: Dictionary = e.snapshot()
	_check(int(s.last_noise_type) == NoiseBus.NoiseType.GUNSHOT,
		"snapshot last noise is GUNSHOT (got %d)" % int(s.last_noise_type))
	_check(float(s.last_noise_age) >= 0.0 and float(s.last_noise_age) < 1.0,
		"the noise is under 1 s old (%.2f s)" % float(s.last_noise_age))
	_check(String(s.tier) == "SUSPICIOUS", "RELAXED -> SUSPICIOUS on the shot (tier %s)" % String(s.tier))
	var ring: PackedStringArray = s.ring
	_check(not ring.is_empty() and ring[ring.size() - 1].contains("heard_gunshot"),
		"ring's newest entry carries cause heard_gunshot: %s" % (ring[ring.size() - 1] if not ring.is_empty() else "(empty)"))
	var pane: String = tools.call("man_text", e)
	_check(pane.contains("HEARD   GUNSHOT") and pane.contains("heard_gunshot"),
		"the MAN pane text names the shot and the cause")


func _state_gate() -> void:
	var e: EnemyBase = _pick_enemy()
	if e == null:
		return
	var before: int = int(e.current_state)
	var want: int = Enums.AIState.ALERT if before != Enums.AIState.ALERT else Enums.AIState.IDLE
	e._change_state(want as Enums.AIState, &"corpse_found")
	var s: Dictionary = e.snapshot()
	var ring: PackedStringArray = s.ring
	_check(not ring.is_empty() and ring[ring.size() - 1].contains("corpse_found")
		and ring[ring.size() - 1].contains(String(s.state)),
		"forced _change_state shows state + cause in the ring: %s" % (ring[ring.size() - 1] if not ring.is_empty() else "(empty)"))
	_check(ring.size() <= 10, "ring holds at most 10 (%d)" % ring.size())
	for i in range(12):
		e._change_state((Enums.AIState.IDLE if i % 2 == 0 else Enums.AIState.ALERT) as Enums.AIState, &"probe_churn")
	_check(e._ring_what.size() == 10 and e._ring_when.size() == 10, "ring caps at 10 after 12 more transitions")


func _civilian_gate() -> void:
	var civ: Civilian = null
	for n in AgentRegistry.civilians:
		var c := n as Civilian
		if c != null and is_instance_valid(c) and c.is_inside_tree() and c.state == Civilian.CivState.WANDER:
			civ = c
			break
	_check(civ != null, "a wandering civilian exists")
	if civ == null:
		return
	civ.set_civ_state(Civilian.CivState.COWER, &"probe_cower")
	civ.set_civ_state(Civilian.CivState.WANDER, &"probe_calm")
	var s: Dictionary = civ.snapshot()
	var ring: PackedStringArray = s.ring
	_check(ring.size() >= 2 and ring[ring.size() - 2].contains("COWER") and ring[ring.size() - 2].contains("probe_cower")
		and ring[ring.size() - 1].contains("WANDER"), "civilian ring shows COWER<-probe_cower then WANDER")
	_check(String(s.state) == "WANDER" and String(s.kind) == "civilian", "civilian snapshot reads state + kind")


func _ledger_gate() -> void:
	var civ: Civilian = null
	for n in AgentRegistry.civilians:
		var c := n as Civilian
		if c != null and is_instance_valid(c) and c.village_center != Vector3.ZERO:
			civ = c
			break
	var center: Vector3 = civ.village_center if civ != null else Vector3(100.0, 0.0, 100.0)
	var key: int = HmS.place_key(center)
	CampaignState.hearts.note("probe/%d/fire" % key, HmS.KIND_FIRE, key, float(SimClock.sim_hour),
		"probe: a burst near the ville")
	var rows: Array[Dictionary] = tools.call("ledger_rows")
	var found: bool = false
	var band: String = ""
	for row in rows:
		if int(row.key) != key:
			continue
		band = String(row.band)
		for d in (row.deeds as Array):
			if String(d.id) == "probe/%d/fire" % key and String(d.cause) == "probe: a burst near the ville":
				found = true
	_check(found, "the ledger pane's data source carries the deed with its cause")
	_check(band == "wary" or band == "hostile", "and the village reads %s" % band)
	var text: String = tools.call("ledger_text")
	_check(text.contains("cause: probe: a burst near the ville"), "the LEDGER pane text prints the cause")
	CampaignState.hearts.deeds.erase("probe/%d/fire" % key)


func _stuck_gate() -> void:
	var civ: Civilian = null
	for n in AgentRegistry.civilians:
		var c := n as Civilian
		if c != null and is_instance_valid(c) and c.is_inside_tree():
			civ = c
			break
	if civ == null:
		_check(false, "a civilian exists for the STUCK comparison")
		return
	var space: PhysicsDirectSpaceState3D = civ.get_world_3d().direct_space_state
	var census: Dictionary = CensusS.classify(civ, space)
	var pane: String = tools.call("stuck_line", civ)
	var expect: String = ""
	if String(census.skip) != "":
		expect = "not measured (%s)" % String(census.skip)
	elif String(census.flag) == "":
		expect = "in place" if bool(census.bound) else "- (not post-bound this hour)"
	else:
		expect = String(census.flag)
	_check(pane == expect, "pane STUCK line == census classify() for %s: '%s'" % [civ.name, pane])
	# A synthetic case: a man told to walk to a post he is not aiming at must read WRONG-TARGET
	# in both readers.
	var saved_wp: Vector3 = civ.working_point_pos
	var saved_tgt: Vector3 = civ._wander_target
	var saved_action: Variant = civ._bt_bb.get("scheduled_action", &"")
	civ._bt_bb["scheduled_action"] = &"work"
	civ.working_point_pos = civ.global_position + Vector3(40.0, 0.0, 0.0)
	civ._wander_target = civ.global_position + Vector3(-40.0, 0.0, 0.0)
	var c2: Dictionary = CensusS.classify(civ, space)
	var p2: String = tools.call("stuck_line", civ)
	_check(String(c2.skip) != "" or (String(c2.flag) == "WRONG-TARGET" and p2 == "WRONG-TARGET"),
		"synthetic wrong-target reads the same in both (census '%s' pane '%s')" % [String(c2.flag), p2])
	civ.working_point_pos = saved_wp
	civ._wander_target = saved_tgt
	civ._bt_bb["scheduled_action"] = saved_action


## No ring symbol may sit inside a per-frame body. Read the source, find each _process /
## _physics_process, and scan until the next top-level func.
func _zero_per_frame_gate() -> void:
	for path in ["res://scripts/enemies/enemy_base.gd", "res://scripts/world/civilian.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_check(false, "%s readable" % path)
			continue
		var lines: PackedStringArray = f.get_as_text().split("\n")
		var in_frame: bool = false
		var hits: PackedStringArray = PackedStringArray()
		for i in range(lines.size()):
			var l: String = lines[i]
			if l.begins_with("func ") or l.begins_with("static func "):
				in_frame = l.begins_with("func _physics_process(") or l.begins_with("func _process(")
				continue
			if in_frame and (l.contains("_ring_") or l.contains("DecisionRingS") or l.contains("snapshot(")):
				hits.append("%s:%d" % [path, i + 1])
		_check(hits.is_empty(), "%s: no ring work in a per-frame body%s" % [path.get_file(),
			"" if hits.is_empty() else " (" + ", ".join(hits) + ")"])
	var ring_writes: int = 0
	var f2 := FileAccess.open("res://scripts/enemies/enemy_base.gd", FileAccess.READ)
	if f2 != null:
		for l in f2.get_as_text().split("\n"):
			if l.contains("DecisionRingS.push("):
				ring_writes += 1
	_check(ring_writes == 3, "enemy_base.gd writes the ring at exactly 3 choke points (%d)" % ring_writes)
