## probe_dealer.gd - THE DEALER and the two beats, headless (council 2026-09-14, rulings 3 + 6).
##
##   godot --headless --path . res://scenes/levels/demo_game.tscn -- --dealer-probe --test-save
##   ... --dealer-probe-toc      (the sack's other claimant: turned in at the TOC)
##
## Attached to the live demo world by game_flow.gd under `--dealer-probe`. Holds the stand-to
## off. Then, at Poteet's table:
##   1. the rack shows consumables only - no row names a path or an id under data/weapons/;
##   2. dealer/case issues at the table, the case reaches the ville's elder: a trade/<village>/p<n>
##      deed with a cause, the band still not wary, the same case standing in the camp's cache;
##   3. dealer/sack: the sack planted at a wreck seat, picked up, and settled ONE way (to Poteet,
##      or at the TOC under --dealer-probe-toc) - the other way is then refused;
##   4. the beats: each fires once on demand, its lines go out once on toast, a second fire is
##      refused.
## Exit 1 on any failure.
extends Node

const SETTLE_S: float = 20.0
const LINE_WAIT_S: float = 14.0

var _fail: int = 0
var _director: FieldDirector = null
var _toasts: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		print("  FAIL: %s" % msg)
		_fail += 1


func _ready() -> void:
	print("\n=== DEALER PROBE ===")
	var waited: float = 0.0
	while waited < SETTLE_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if _director == null:
			_director = get_tree().get_first_node_in_group("mission_director") as FieldDirector
			if _director != null:
				_director.stand_to_held = true
				_director.toast.connect(func(t: String) -> void: _toasts.append(t))
	if _director == null:
		print("  FAIL: no FieldDirector")
		_finish()
		return
	var table: DealerTable = get_tree().get_first_node_in_group("dealer_table") as DealerTable
	_check(table != null, "Poteet's table stands in the world")
	var player: Node3D = GameManager.player as Node3D
	_check(player != null, "a player walks it")
	if table == null or player == null:
		_finish()
		return
	_rack(table, player)
	await _case(table, player)
	await _sack(table, player)
	await _beats(player)
	_finish()


## ---------- 1. the rack ----------

func _rack(table: DealerTable, player: Node3D) -> void:
	player.global_position = table.global_position + Vector3(1.0, 0.6, 0.0)
	table.open_menu()
	var rows: Array[Dictionary] = table.rack_rows()
	_check(not rows.is_empty(), "the rack has rows (%d)" % rows.size())
	var weapon_ids: Array[String] = _weapon_ids()
	_check(weapon_ids.size() >= 5, "data/weapons/ read for the guard (%d ids)" % weapon_ids.size())
	var armed: int = 0
	for r: Dictionary in rows:
		var id: String = str(r.get("id", "")).to_lower()
		var label: String = str(r.get("label", "")).to_lower()
		if id.contains("data/weapons") or label.contains(".tres"):
			armed += 1
		for wid: String in weapon_ids:
			if id.trim_prefix("good:") == wid:
				armed += 1
		print("    row %s | %s" % [str(r.get("id", "")), str(r.get("label", ""))])
	_check(armed == 0, "never a weapon on his rack (%d rows named one)" % armed)
	for g: Dictionary in DealerTable.GOODS:
		_check(not weapon_ids.has(str(g.id)), "good '%s' is not a weapon id" % str(g.id))
	table.close_menu()


func _weapon_ids() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://data/weapons")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres") or f.ends_with(".tres.remap"):
			out.append(f.get_basename().get_basename())
	return out


## ---------- 2. the case ----------

func _case(table: DealerTable, player: Node3D) -> void:
	table.choose("case:take")
	_check(CampaignState.tasking_state(DealerTable.TASK_CASE) == CampaignState.TASKING_OPEN,
		"dealer/case issued at the table")
	_check(table.carrying_case, "the case is on his back")
	_check(_toasts.has(String(DealerTable.LINES["ask"])), "Poteet asked in his own words")
	var elder: Civilian = _find_elder()
	_check(elder != null, "the ville has an elder to hand it to")
	if elder == null:
		return
	var key: int = HmLedger.place_key(elder.village_center)
	var band_before: StringName = CampaignState.hearts.band(key)
	player.global_position = elder.global_position + Vector3(1.2, 0.3, 0.0)
	await get_tree().physics_frame
	var prompt: String = str(table.field_prompt(player))
	_check(prompt == "[F] HAND THE CASE TO THE ELDER", "the [F] verb reads '%s'" % prompt)
	_check(table.try_field_interact(player), "[F] hands the case over")
	var deed_id: String = "trade/%d/p%d" % [key, CampaignState.missions_played]
	_check(CampaignState.hearts.has(deed_id), "deed %s noted" % deed_id)
	var deed: Dictionary = CampaignState.hearts.deeds.get(deed_id, {})
	_check(deed.get("kind", &"") == HmLedger.KIND_TRADE and not str(deed.get("cause", "")).is_empty(),
		"the deed is a trade with a cause: '%s'" % str(deed.get("cause", "")))
	_check(CampaignState.hearts.band(key) == band_before and CampaignState.hearts.band(key) != HmLedger.BAND_WARY,
		"the band did not move (%s)" % String(CampaignState.hearts.band(key)))
	_check(CampaignState.hearts.traded(key), "the ville reads traded")
	_check(CampaignState.tasking_state(DealerTable.TASK_CASE) == CampaignState.TASKING_CLOSED,
		"dealer/case closed: %s" % str((CampaignState.taskings.get(DealerTable.TASK_CASE, {}) as Dictionary).get("cause", "")))
	_check(not table.carrying_case, "his hands are empty")
	var camp_case: Node3D = table.camp_case()
	_check(camp_case != null and is_instance_valid(camp_case), "the same case stands in the camp cache")
	if camp_case != null:
		var gun: Vector3 = Vector3.ZERO
		for n in get_tree().get_nodes_in_group("zpu_guns"):
			var zg := n as ZpuGun
			if zg != null and not zg.ambient:
				gun = zg.global_position
		_check(gun != Vector3.ZERO and camp_case.global_position.distance_to(gun) <= DealerTable.CAMP_CACHE_MAX_M + 2.0,
			"the cache is at the camp (%.1f m off the gun)" % camp_case.global_position.distance_to(gun))
	player.global_position = table.global_position + Vector3(1.0, 0.6, 0.0)
	table.open_menu()
	var ids: Array[String] = []
	for r: Dictionary in table.rack_rows():
		ids.append(str(r.get("id", "")))
	_check(ids.has("good:mortar"), "the rack moved: the off-book round stands now (%s)" % ", ".join(ids))
	var before: int = int(_director.fire_support.get("mortar", 0))
	table.choose("good:mortar")
	_check(int(_director.fire_support.get("mortar", 0)) == before + 1, "the round is his")
	table.close_menu()


func _find_elder() -> Civilian:
	var fallback: Civilian = null
	for n in AgentRegistry.civilians:
		var civ: Civilian = n as Civilian
		if civ == null or civ.village_center == Vector3.ZERO:
			continue
		if civ.occupation == "elder":
			return civ
		if fallback == null:
			fallback = civ
	return fallback


## ---------- 3. the sack ----------

func _sack(table: DealerTable, player: Node3D) -> void:
	var pr: PilotRecovery = get_tree().get_first_node_in_group("pilot_recovery") as PilotRecovery
	_check(pr != null, "PilotRecovery rides the world")
	if pr == null:
		return
	var seat: Vector3 = _director.patrol_gate_pos + _director.patrol_gate_out * 60.0
	var sack: Node3D = pr.place_crash_sack(MissionGenerator._seat(_director.world, seat), 0.0)
	_check(sack != null and pr.incident.get("crash_sack_pos", Vector3.ZERO) != Vector3.ZERO,
		"a sack lies at the wreck seat %s" % str(pr.incident.get("crash_sack_pos", Vector3.ZERO)))
	if sack == null:
		return
	player.global_position = sack.global_position + Vector3(1.0, 0.5, 0.0)
	await get_tree().physics_frame
	_check(str(table.field_prompt(player)) == "[F] PICK UP THE MAIL SACK", "the [F] verb offers the sack")
	_check(table.try_field_interact(player), "[F] picks it up")
	_check(table.carrying_sack and CampaignState.tasking_state(DealerTable.TASK_SACK) == CampaignState.TASKING_OPEN,
		"dealer/sack issued on pickup")
	var to_toc: bool = OS.get_cmdline_user_args().has("--dealer-probe-toc")
	if to_toc:
		player.global_position = table._toc_pos + Vector3(0.5, 0.5, 0.0)
		await get_tree().physics_frame
		_check(str(table.field_prompt(player)) == "[F] TURN THE SACK IN AT THE TOC", "the [F] verb offers the TOC")
		_check(table.try_field_interact(player), "[F] turns it in")
		_check(CampaignState.tasking_state(DealerTable.TASK_SACK) == CampaignState.TASKING_REFUSED,
			"the TOC's way: dealer/sack REFUSED (%s)" % str((CampaignState.taskings.get(DealerTable.TASK_SACK, {}) as Dictionary).get("cause", "")))
		_check(not CampaignState.settle_tasking(DealerTable.TASK_SACK, CampaignState.TASKING_CLOSED, "probe twin"),
			"Poteet's twin is refused after the TOC has it")
		_check(_toasts.has(String(DealerTable.LINES["toc_sack"])), "the TOC took it in its own words")
		player.global_position = table.global_position + Vector3(1.0, 0.6, 0.0)
		await get_tree().create_timer(2.5).timeout
		_check(_toasts.has(String(DealerTable.LINES["conflict"])), "Poteet says the conflict line unprompted at the table")
	else:
		player.global_position = table.global_position + Vector3(1.0, 0.6, 0.0)
		table.open_menu()
		var ids: Array[String] = []
		for r: Dictionary in table.rack_rows():
			ids.append(str(r.get("id", "")))
		_check(ids.has("sack:hand"), "the table offers the hand-over")
		table.choose("sack:hand")
		_check(CampaignState.tasking_state(DealerTable.TASK_SACK) == CampaignState.TASKING_CLOSED,
			"Poteet's way: dealer/sack CLOSED (%s)" % str((CampaignState.taskings.get(DealerTable.TASK_SACK, {}) as Dictionary).get("cause", "")))
		_check(not CampaignState.settle_tasking(DealerTable.TASK_SACK, CampaignState.TASKING_REFUSED, "probe twin"),
			"the TOC's twin is refused after Poteet has it")
		_check(_toasts.has(String(DealerTable.LINES["delivery"])), "Poteet paid in his own words")
		ids.clear()
		for r: Dictionary in table.rack_rows():
			ids.append(str(r.get("id", "")))
		_check(ids.has("good:mags"), "the rack moved: mags off the pallet stand now")
		table.close_menu()
	_check(not table.carrying_sack, "the sack is off his back")


## ---------- 4. the beats ----------

func _beats(player: Node3D) -> void:
	var book: BeatBook = get_tree().get_first_node_in_group("beat_book") as BeatBook
	_check(book != null, "the BeatBook rides the demo world")
	if book == null:
		return
	_check(book.beats.has("barrels") and book.beats.has("wire_at_dusk"), "both beats loaded (%s)" % ", ".join(book.beats.keys()))
	_check(book._triggers.has("barrels"), "the barrels trigger is armed at the burn pad")
	player.global_position = _director.fsb_center + Vector3(2.0, 0.5, 0.0)
	for id: String in ["barrels", "wire_at_dusk"]:
		var lines: Dictionary = (book.beats.get(id, {}) as Dictionary).get("lines", {})
		var before: Array[String] = _toasts.duplicate()
		_check(book.fire(id), "%s fires on demand" % id)
		await get_tree().create_timer(LINE_WAIT_S).timeout
		for k in lines.keys():
			var line: String = str(lines[k])
			var n: int = _toasts.count(line) - before.count(line)
			_check(n == 1, "%s.%s went out once (%d)" % [id, str(k), n])
		_check(not book.fire(id), "%s refuses a second fire today" % id)
		await get_tree().create_timer(1.0).timeout
		for k in lines.keys():
			var line: String = str(lines[k])
			_check(_toasts.count(line) - before.count(line) == 1, "%s.%s did not go out twice" % [id, str(k)])
	_check(not book.probe_man_inside_wire(), "no probe man inside the wire while the dusk line was said")


func _finish() -> void:
	if _fail == 0:
		print("=== DEALER PROBE PASS ===")
	else:
		print("=== DEALER PROBE FAILED (%d) ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
