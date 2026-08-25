## save_manager.gd - save orchestrator.
## JSON slots in user://saves/. Slots 0-7 manual (0 = quicksave), 8 = periodic
## autosave, 9 = exit autosave. Collect/apply brokers SaveData sections to the
## live systems; each system serializes itself (CampaignState.to_dict etc).
##
## SAVE TIERS derive from existing settings (no new knobs):
##   IRONMAN  (CampaignState.iron_man)  - saves only at the firebase hub
##   HARD     (GameSettings.hardcore)   - hub saves only (the wheels-down
##            checkpoint died with ADR-029's insertion cut; never rebuilt)
##   REGULAR  (everything else)         - quicksave/quickload anywhere (F5/F9)
extends Node

## THE FRESH-PLAYER LAW (Summoner, 2026-07-18): the dev's save is a lie about
## the fresh player. Tests run in their own slot dir and start VIRGIN; they can
## never touch - or lean on - the player's real saves.
## The player's real slots. Named so a caller that sandboxes this (the demo, the suite) has
## something to restore it TO - two hardcoded copies of the string is how one of them drifts.
const DEFAULT_SAVE_DIR := "user://saves"
var save_dir: String = DEFAULT_SAVE_DIR
const QUICK_SLOT := 0
const AUTOSAVE_SLOT := 8
const EXIT_SLOT := 9
const AUTOSAVE_INTERVAL_S := 30.0

enum Tier { REGULAR, HARD, IRONMAN }

## Where the player is right now: "menu" | "hub" | "mission". GameFlow maintains it.
var context: String = "menu"
## Hub board state, maintained by GameFlow (operation seed/name, offers, accepted).
var hub_snapshot: Dictionary = {}
## Section stashed by load_game() for GameFlow to consume once the world exists.
## Deferred-apply: NEVER apply a position into a dead scene.
var pending_player: SaveData.PlayerSection = null

var _autosave_t: float = 0.0
var _session_started_ms: int = 0


func _ready() -> void:
	if CampaignState.is_test_run():
		save_dir = "user://saves_test"
	DirAccess.make_dir_recursive_absolute(save_dir)
	get_tree().set_auto_accept_quit(false)
	_session_started_ms = Time.get_ticks_msec()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Exit autosave - wrapped so a failed save can never block quitting.
		if context != "menu" and _player_alive():
			save_game(EXIT_SLOT, "EXIT")
		get_tree().quit()


func _process(delta: float) -> void:
	if context == "menu":
		return
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL_S:
		_autosave_t = 0.0
		# Autosave obeys the tier: hub is always fine; in-mission only on REGULAR.
		if (context == "hub" or tier() == Tier.REGULAR) and _player_alive() \
				and GameManager.can_player_act():
			save_game(AUTOSAVE_SLOT, "AUTOSAVE")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		if can_manual_save():
			if save_game(QUICK_SLOT, "QUICKSAVE"):
				_toast("SAVED")
		else:
			_toast("NO SAVING IN THE FIELD ON THIS DIFFICULTY - GET BACK TO BASE")
	elif event.is_action_pressed("quickload"):
		var flow := _flow()
		if flow != null and has_save(QUICK_SLOT) and flow.has_method("load_from_slot"):
			flow.call("load_from_slot", QUICK_SLOT)


func tier() -> int:
	if CampaignState.iron_man:
		return Tier.IRONMAN
	if GameSettings.hardcore:
		return Tier.HARD
	return Tier.REGULAR


func can_manual_save() -> bool:
	if not _player_alive() and context != "hub":
		return false
	match tier():
		Tier.REGULAR:
			return context != "menu"
		_:
			return context == "hub"


## ------------------------------------------------------------------ save

## Atomic write-and-swap: the slot file always holds a COMPLETE save. Write to
## .tmp, verify, rotate the previous good file to .bak, then rename .tmp into
## place - a crash at any step leaves either the old save or the .bak intact.
func save_game(slot: int, save_name: String = "") -> bool:
	var data := collect()
	data.meta.save_name = save_name if save_name != "" else "SLOT %d" % slot
	var json := JSON.stringify(data.to_dict(), "\t")
	var path := _slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[SAVE] cannot open %s" % tmp)
		return false
	f.store_string(json)
	f.flush()
	var write_err: Error = f.get_error()
	f.close()
	if write_err != OK:
		DirAccess.remove_absolute(tmp)
		push_error("[SAVE] write failed for %s (err %d)" % [tmp, write_err])
		return false
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		# Windows rename refuses an existing target - clear the old .bak first.
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var swap_err: Error = DirAccess.rename_absolute(tmp, path)
	if swap_err != OK:
		push_error("[SAVE] cannot swap %s into place (err %d)" % [tmp, swap_err])
		return false
	return true


func collect() -> SaveData:
	var s := SaveData.new()
	s.campaign.data = CampaignState.to_dict()
	s.hub = SaveData.HubSection.from_dict(hub_snapshot)
	s.meta.timestamp = int(Time.get_unix_time_from_system())
	s.meta.missions_played = CampaignState.missions_played
	s.meta.playtime_s = float(Time.get_ticks_msec() - _session_started_ms) / 1000.0
	s.player = _collect_player()
	return s


func _collect_player() -> SaveData.PlayerSection:
	var p := SaveData.PlayerSection.new()
	p.context = context
	var player: Node = GameManager.player
	if player == null or not is_instance_valid(player) or not (player is Node3D):
		return p
	p.position = (player as Node3D).global_position
	p.rotation_y = (player as Node3D).rotation.y
	p.stamina = float(player.get("stamina") if player.get("stamina") != null else 100.0)
	p.smoke_count = int(player.get("smoke_count") if player.get("smoke_count") != null else 2)
	p.claymore_count = int(player.get("claymore_count") if player.get("claymore_count") != null else 2)
	p.satchel_count = int(player.get("satchel_count") if player.get("satchel_count") != null else 2)
	p.flare_count = int(player.get("flare_count") if player.get("flare_count") != null else 3)
	p.hunger = float(player.get("hunger") if player.get("hunger") != null else 100.0)
	var hs: Node = player.get("health_system")
	if hs != null and is_instance_valid(hs):
		p.hp = int(hs.get("current_hp"))
		p.health_packs = int(hs.get("health_packs"))
	var wh: Node = player.get_node_or_null("Head/Camera3D/WeaponHolder")
	if wh != null:
		var prim: Resource = wh.get("primary_weapon")
		var sec: Resource = wh.get("secondary_weapon")
		p.primary_path = prim.resource_path if prim != null else ""
		p.secondary_path = sec.resource_path if sec != null else ""
		p.primary_ammo = (wh.get("primary_mags") as Array).duplicate()
		p.secondary_ammo = (wh.get("secondary_mags") as Array).duplicate()
		p.weapon_condition = float(wh.get("weapon_condition") if wh.get("weapon_condition") != null else 100.0)
	var eq: Node = player.get("equipment_manager")
	if eq != null and is_instance_valid(eq):
		p.grenade_count = int(eq.get("grenade_count"))
	p.ration_count = int(player.get("ration_count") if player.get("ration_count") != null else 2)
	p.repair_kit_count = int(player.get("repair_kit_count") if player.get("repair_kit_count") != null else 1)
	return p


## ------------------------------------------------------------------ load

func load_game(slot: int) -> SaveData:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return null
	var d: Dictionary = _read_slot_dict(path)
	if d.is_empty():
		d = _read_slot_dict(path + ".bak")
		if d.is_empty():
			print("[SAVE] slot %d is corrupt - load refused (handled)" % slot)
			return null
		print("[SAVE] slot %d primary is corrupt - loaded from .bak (handled)" % slot)
	var file_version: int = int(d.get("version", 1))
	if file_version > SaveData.SCHEMA_VERSION:
		# A future-version primary is intact, not corrupt - refuse it outright
		# rather than silently rolling back to an older .bak.
		print("[SAVE] slot %d is save v%d, this build reads v%d - load refused (handled)" % [
			slot, file_version, SaveData.SCHEMA_VERSION])
		return null
	if file_version < SaveData.SCHEMA_VERSION:
		d = _migrate(d, file_version)
	var s := SaveData.from_dict(d)
	if not s.is_valid():
		print("[SAVE] slot %d failed validation - load refused (handled)" % slot)
		return null
	return s


## Apply everything that is safe WITHOUT a live world: the hub section lands in
## hub_snapshot (enter_hub reads operation seed/name from it); the player section
## is stashed for GameFlow (pending_player, applied after the hub spawns).
func apply(s: SaveData) -> void:
	# Load-safety: reset interaction state before touching anything.
	GameManager.is_paused = false
	GameManager.is_in_menu = false
	CampaignState.from_dict(s.campaign.data)
	CampaignState.save_campaign()
	hub_snapshot = s.hub.to_dict()
	pending_player = s.player


## Restore the player's carried state + position. Called by GameFlow after the
## hub world is ready and the player spawned. Consumes pending_player.
func apply_pending_player(player: Node3D) -> void:
	var p := pending_player
	pending_player = null
	if p == null or player == null or not is_instance_valid(player):
		return
	if p.context == "hub" and p.position != Vector3.ZERO:
		player.global_position = p.position
		player.rotation.y = p.rotation_y
	if player.get("stamina") != null:
		player.set("stamina", p.stamina)
	player.set("smoke_count", p.smoke_count)
	player.set("claymore_count", p.claymore_count)
	player.set("satchel_count", p.satchel_count)
	player.set("flare_count", p.flare_count)
	if player.get("hunger") != null:
		player.set("hunger", p.hunger)
	if player.get("ration_count") != null:
		player.set("ration_count", p.ration_count)
	if player.get("repair_kit_count") != null:
		player.set("repair_kit_count", p.repair_kit_count)
	var hs: Node = player.get("health_system")
	if hs != null and is_instance_valid(hs):
		hs.set("current_hp", maxi(1, p.hp))
		hs.set("health_packs", p.health_packs)
	var wh: Node = player.get_node_or_null("Head/Camera3D/WeaponHolder")
	if wh != null:
		if p.primary_path != "" and ResourceLoader.exists(p.primary_path):
			wh.set("primary_weapon", load(p.primary_path))
		if p.secondary_path != "" and ResourceLoader.exists(p.secondary_path):
			wh.set("secondary_weapon", load(p.secondary_path))
		# Through set_slot_mags, not set(): it re-types the JSON ints and keeps
		# pooled feeds shaped, and weapons were installed just above.
		wh.call("set_slot_mags", 0, p.primary_ammo)
		wh.call("set_slot_mags", 1, p.secondary_ammo)
		if wh.get("weapon_condition") != null:
			wh.set("weapon_condition", p.weapon_condition)
		if wh.has_method("refresh_after_load"):
			wh.call("refresh_after_load")


## ------------------------------------------------------------------ info

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot)) \
		or FileAccess.file_exists(_slot_path(slot) + ".bak")


## Newest slot by timestamp - what CONTINUE loads.
func latest_slot() -> int:
	var best := -1
	var best_ts := -1
	for slot in range(10):
		var info := get_save_info(slot)
		if not info.is_empty() and int(info.get("timestamp", 0)) > best_ts:
			best_ts = int(info.get("timestamp", 0))
			best = slot
	return best


## Metadata-only read for menus (no full deserialize).
func get_save_info(slot: int) -> Dictionary:
	var d: Dictionary = _read_slot_dict(_slot_path(slot))
	if d.is_empty():
		d = _read_slot_dict(_slot_path(slot) + ".bak")
	return d.get("meta", {}) as Dictionary


## ------------------------------------------------------------------ internals

func _migrate(d: Dictionary, from_version: int) -> Dictionary:
	push_warning("[SAVE] migrating save v%d -> v%d" % [from_version, SaveData.SCHEMA_VERSION])
	if from_version < 2:
		# ADR-029: the offer board died with the briefing. A v1 save with an
		# unresolved checkpoint resumes at the firebase - the world is the world.
		var hub: Dictionary = d.get("hub", {})
		hub.erase("offers")
		hub.erase("accepted_offer")
		hub.erase("checkpoint_offer")
		d["hub"] = hub
	d["version"] = SaveData.SCHEMA_VERSION
	return d


func _slot_path(slot: int) -> String:
	return "%s/save_%d.sav" % [save_dir, slot]


## Parse one slot file to its raw dict; {} for missing/unreadable/zero-byte/
## garbage. Instance JSON.parse(), NOT static parse_string(): a corrupt save is
## a HANDLED runtime condition, and parse_string() pushes an engine ERROR on
## bad input (louder on 4.7), which reads as a crash in logs/test scans.
func _read_slot_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var parse_err: Error = json.parse(f.get_as_text())
	f.close()
	if parse_err != OK or not (json.data is Dictionary):
		return {}
	return json.data as Dictionary


func _player_alive() -> bool:
	var player: Node = GameManager.player
	if player == null or not is_instance_valid(player):
		return false
	var hs: Node = player.get("health_system")
	return hs == null or not bool(hs.get("is_downed"))


func _flow() -> Node:
	var nodes := get_tree().get_nodes_in_group("game_flow")
	return nodes[0] if nodes.size() > 0 else null


func _toast(msg: String) -> void:
	var flow := _flow()
	if flow != null and flow.get("director") != null and is_instance_valid(flow.get("director")):
		(flow.get("director") as Node).emit_signal("toast", msg)
	else:
		print("[SAVE] ", msg)
