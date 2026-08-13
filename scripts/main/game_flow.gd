## game_flow.gd - Persistent root: menu -> select -> briefing -> world -> debrief
## loop (NS18/NS21). Swaps a single current_screen child; owns mission context.
class_name GameFlow
extends Node

## Preloaded, not by class_name: a global class is not registered until the editor
## rescans, so a fresh script fails every headless run.
const TITLE_SPLASH := preload("res://scripts/ui/screens/title_splash.gd")

var current_screen: Node = null
var world: GameWorld = null
var director: FieldDirector = null
var mission_hud: MissionHUD = null
var squad: SquadSystem = null
var _debrief_pending: bool = false

## Strength the [J] dev lens forces. The d50 ceiling, so the trigger exercises the
## assault at its worst case rather than an average night.
const DEV_SIEGE_STRENGTH: int = 50

## THE WAY OUT (audit L1). GameFlow owns the pause menu because GameFlow is the
## only thing that knows where you are and what leaving means.
var _pause_menu: PauseMenu = null
var _in_world: bool = false     ## a mission or the hub is loaded
var _in_mission: bool = false   ## ...and it is a MISSION (not the hub)


func _ready() -> void:
	add_to_group("game_flow")
	process_mode = Node.PROCESS_MODE_ALWAYS   # Esc must work while paused
	# DemoGame sets demo_mode before adding its flow and drives _begin_operation
	# itself - booting the default operation here would build a second world on
	# the wrong seed and throw it away.
	if GameFlow.demo_mode:
		return
	# THE TITLE CARD COMES FIRST. Boot used to land straight in the patrol, so the first
	# thing anyone saw was terrain streaming in. The card holds until he clicks, then the
	# menu comes up behind it.
	show_title()


## Splash -> menu. The card is added over whatever is there and frees itself on dismiss,
## so it never has to know what it is covering - which is why the demo can reuse it.
func show_title() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var splash: Control = TITLE_SPLASH.new()
	splash.dismissed.connect(show_menu)
	add_child(splash)


func _unhandled_input(event: InputEvent) -> void:
	if _dev_keys(event):
		return
	if not event.is_action_pressed("pause") or not _in_world:
		return
	get_viewport().set_input_as_handled()
	if _pause_menu != null:
		_close_pause()
	else:
		_open_pause()


## THE DEV LENSES, debug builds only. [J] siege · [H] three sappers at the nearest real
## parapet segment · [G] gun-and-napalm pass on your bearing · [O] +1 hour · [I] next period ·
## [U] cycle the clock speed. Time skips route through SimClock.advance(), NEVER
## set_time(): set_time moves the clock without emitting time_period_changed, so the
## sun and the sight caps would stay on the old period.
func _dev_keys(event: InputEvent) -> bool:
	if not OS.is_debug_build() or not _in_world:
		return false
	if not (event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo):
		return false
	match (event as InputEventKey).physical_keycode:
		KEY_J:
			get_viewport().set_input_as_handled()
			return _dev_force_siege()
		KEY_H:
			get_viewport().set_input_as_handled()
			return _dev_sapper_run()
		KEY_G:
			get_viewport().set_input_as_handled()
			return _dev_gun_run()
		KEY_O:
			get_viewport().set_input_as_handled()
			_dev_skip_hours(1.0)
			return true
		KEY_I:
			get_viewport().set_input_as_handled()
			_dev_skip_to_next_period()
			return true
		KEY_U:
			get_viewport().set_input_as_handled()
			_dev_cycle_clock_speed()
			return true
	return false


## Sim-hours at which the world changes period (sim_clock.gd:57-64).
const DEV_PERIOD_BOUNDS: Array[float] = [5.0, 7.0, 17.0, 19.0]
## Clock speeds the [U] lens cycles. 60 is the shipped rate: one sim-hour a minute.
const DEV_CLOCK_SPEEDS: Array[float] = [60.0, 600.0, 3600.0]


func _dev_skip_hours(hours: float) -> void:
	# advance() takes REAL seconds and scales by the ratio, so invert it to move a
	# known number of SIM hours whatever the clock speed currently is.
	SimClock.advance(hours * 3600.0 / maxf(0.001, SimClock.real_to_sim_ratio))
	_dev_report_time("SKIPPED %.0fH" % hours)


func _dev_skip_to_next_period() -> void:
	var here: float = SimClock.sim_hour
	var best: float = 24.0
	for b in DEV_PERIOD_BOUNDS:
		var d: float = b - here if b > here else b + 24.0 - here
		best = minf(best, d)
	_dev_skip_hours(best + 0.01)


func _dev_cycle_clock_speed() -> void:
	var i: int = DEV_CLOCK_SPEEDS.find(SimClock.real_to_sim_ratio)
	SimClock.real_to_sim_ratio = DEV_CLOCK_SPEEDS[(i + 1) % DEV_CLOCK_SPEEDS.size()]
	_dev_report_time("CLOCK %.0fx" % (SimClock.real_to_sim_ratio / 60.0))


## Say it where he is - the field toast, not just stdout.
func _dev_report_time(what: String) -> void:
	var names: Array[String] = ["DAWN", "DAY", "DUSK", "NIGHT"]
	var line: String = "[TIME-DEV] %s -> DAY %d, %02d:%02d (%s)" % [
		what, SimClock.sim_day, int(SimClock.sim_hour),
		int(fposmod(SimClock.sim_hour, 1.0) * 60.0),
		names[SimClock.period_at(SimClock.sim_hour)]]
	print(line)
	if director != null and is_instance_valid(director):
		director.toast.emit(line.substr(11))


## A cot inside a firebase hootch, or ZERO if the base authored none.
##
## fsb_main_v3 carries 68 `prop_sleep` markers - the bunks - and each keeps its own
## authored height, which is the floor it stands on. The nearest one to the base centre
## is taken so a village hootch elsewhere in the AO can never win. The returned Y is
## USED, not re-seated: probing down from above would find the hootch roof.
## How far under a cot marker to look for a floor. Must clear the drop from a hootch's authored
## cot height down to the mound surface it stands on; 0.8m only ever worked because terrain used
## to be sculpted up to meet it.
const BUNK_FLOOR_REACH_M: float = 5.5


func _firebase_bunk(fsb_center: Vector3) -> Vector3:
	if world == null or fsb_center == Vector3.ZERO:
		return Vector3.ZERO
	# HIS MARKERS WIN, AND THEY ARE NOT SECOND-GUESSED.
	#
	# A Marker3D named spawn_bunk* in scenes/world/firebase_main.tscn is a position a human
	# placed on purpose, in the editor, looking at the geometry. It is used EXACTLY as placed:
	# no floor raycast, no reseating. Every time this function has tried to be clever about
	# where a man should stand it has put him somewhere worse - under the mound, or in a
	# village 142m away - and the authored answer was right the whole time.
	#
	# The prop_sleep sweep below stays as the fallback for a world with no authored markers.
	var authored: Array[Vector3] = []
	var cands: Array[Vector3] = []
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D:
			var nm: String = String(n.name)
			if nm.begins_with("spawn_bunk"):
				authored.append((n as Node3D).global_position)
			elif nm.begins_with("prop_sleep"):
				cands.append((n as Node3D).global_position)
		for c in n.get_children():
			stack.append(c)
	if not authored.is_empty():
		authored.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return Vector2(a.x - fsb_center.x, a.z - fsb_center.z).length_squared() \
				< Vector2(b.x - fsb_center.x, b.z - fsb_center.z).length_squared())
		var pick: Vector3 = authored[0]
		print("[SPAWN] authored bunk marker at %s (%d placed, %.0fm from fsb centre)" % [
			pick, authored.size(),
			Vector2(pick.x - fsb_center.x, pick.z - fsb_center.z).length()])
		return pick
	if cands.is_empty():
		push_warning("[SPAWN] no prop_sleep marker in the world - falling back to the field spawn")
		return Vector3.ZERO
	cands.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x - fsb_center.x, a.z - fsb_center.z).length_squared() \
			< Vector2(b.x - fsb_center.x, b.z - fsb_center.z).length_squared())

	# The bunk must have a FLOOR under it. fsb_main_v3 ships 8 hootch visuals against
	# 4 `-colonly` bodies, so half of them are scenery a man falls straight through.
	# Take the nearest cot that can actually hold him, never just the nearest cot.
	# REACH FAR ENOUGH TO FIND THE MOUND. The probe used to look 0.8m down, which worked only
	# while the terrain was sculpted up to the mound's surface and put ground directly under
	# every cot. Since the model became the ground (2026-07-29) the terrain sits at the TOE,
	# ~3.4m lower, and the real floor is the mound trimesh - out of reach of a 0.8m ray. Every
	# cot inside the wire failed the test and the spawn walked out to candidate 69 of 72, a
	# village 142m away: "i was spawned outside at a village there."
	#
	# THE MARKER IS THE SPAWN. Reach further for the TEST, and nothing else. Seating him on the
	# ray hit instead put him under the mound - the authored cot position was never the problem,
	# and this spawn was correct for weeks before the ground moved beneath it.
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for i in range(cands.size()):
		var p: Vector3 = cands[i]
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.4,
				p + Vector3.DOWN * BUNK_FLOOR_REACH_M)
			q.collision_mask = 1
			if space.intersect_ray(q).is_empty():
				continue   # genuinely nothing under this cot
		print("[SPAWN] bunk spawn at %s, candidate %d of %d (%.0fm from fsb centre)" % [
			p, i + 1, cands.size(),
			Vector2(p.x - fsb_center.x, p.z - fsb_center.z).length()])
		return p
	push_warning("[SPAWN] %d bunks found, NONE with collision under them - field spawn" % cands.size())
	return Vector3.ZERO


## [H] THREE SAPPERS AT THE REAL WALL. The bench proved the chain on segments lifted out of the
## GLB; this proves it on the firebase the player is standing in, which is what the Summoner
## asked for: "i need to prove sappers can blow up the sandbags of the blender firebase model"
## and "we should really make the ai test scene the firebase from the demo and game world".
##
## It picks a LIVE parapet Destructible off the blast bus - the same 80 segments
## site_planner wired from firebase_v3_destructibles.json - and drives three satchel men at it
## from outside the wire. No siege, no cells, no waiting on the arc: the shortest path from
## keypress to a hole in the sandbags.
## [G] A GUN-AND-NAPALM PASS ON DEMAND. The arc puts one at 13 minutes; feel is tuning work and
## tuning work needs repetition, so this calls the same authored_strike from wherever you stand.
## Aimed 210m out on the bearing you are FACING, so you can put the run where you can see it.
const DEV_STRIKE_RANGE_M: float = 210.0


func _dev_gun_run() -> bool:
	if director == null or world == null or world.player == null:
		print("[CAS-DEV] no world yet")
		return true
	var cam := world.player.get_node_or_null("Head/Camera3D") as Camera3D
	var facing: Vector3 = -cam.global_transform.basis.z if cam != null else Vector3.FORWARD
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.1 else Vector3.FORWARD
	var at: Vector3 = world.player.global_position + facing * DEV_STRIKE_RANGE_M
	at.y = world.surface_y(at)
	# Run the pass ACROSS the line of sight so the strafe and the strip read broadside.
	var across := Vector3(-facing.z, 0.0, facing.x)
	# Pressing [G] IS calling it in danger close: the axis you chose is the axis that flies,
	# because the whole point of the key is repeating the same pass until the feel is right.
	director.authored_strike(at, CASAirplane.Ordnance.GUNS_NAPALM, across, true)
	director.toast.emit("GUN RUN INBOUND")
	print("[CAS-DEV] gun+napalm pass at %.0f,%.0f (%.0fm on your bearing)" % [
		at.x, at.z, DEV_STRIKE_RANGE_M])
	return true


const DEV_SAPPERS: int = 3
const DEV_SAPPER_DATA: String = "res://data/enemies/vc_sapper.tres"
const DEV_SAPPER_STANDOFF_M: float = 55.0


func _dev_sapper_run() -> bool:
	if director == null or world == null:
		print("[SAPPER-DEV] no world yet")
		return true
	# Any standing structure on the bus - parapet, bunker, tower - chosen as the one nearest
	# the player so he can watch it go. is_destroyed() is the test, not is_instance_valid:
	# _do_destroy never frees the node, so a blown structure stays "valid" forever.
	var target: Destructible = null
	var best: float = INF
	var eye: Vector3 = world.player.global_position if world.player != null else director.fsb_center
	for p in AgentRegistry.props:
		var d := p as Destructible
		if d == null or not is_instance_valid(d) or d.is_destroyed():
			continue
		var dist: float = d.global_position.distance_to(eye)
		if dist < best:
			best = dist
			target = d
	if target == null:
		print("[SAPPER-DEV] no standing Destructible on the bus - the firebase is not wired")
		return true
	print("[SAPPER-DEV] target: %s at %.0fm" % [target.kind, best])
	# Stand them off OUTSIDE the wire, on the bearing from the compound centre through the
	# target, so the run crosses the wire and the berm exactly as a real breach would.
	var out: Vector3 = target.global_position - director.fsb_center
	out.y = 0.0
	out = out.normalized() if out.length() > 1.0 else Vector3.FORWARD
	var objective: Vector3 = target.global_position
	for i in range(DEV_SAPPERS):
		var side: Vector3 = Vector3(-out.z, 0.0, out.x) * (float(i) - 1.0) * 5.0
		var at: Vector3 = objective + out * DEV_SAPPER_STANDOFF_M + side
		at.y = world.surface_y(at) + 0.5
		var man: EnemyBase = director.spawn_tracked_enemy(at, DEV_SAPPER_DATA, "dev_sappers")
		if man == null:
			continue
		man.assault_objective = objective
		man.assault_driven = true
		var charge := SapperCharge.new()
		man.add_child(charge)
		charge.setup(objective)
	print("[SAPPER-DEV] %d sappers away at '%s' (%.0fm out, %.0fm from you) - watch the wall"
		% [DEV_SAPPERS, target.name, DEV_SAPPER_STANDOFF_M, best])
	director.toast.emit("SAPPERS ON THE WIRE")
	return true


func _dev_force_siege() -> bool:
	if director == null or director.siege == null:
		print("[SIEGE-DEV] no siege attached - the firebase has not been built yet")
		return true
	var s: SiegeDirector = director.siege
	if s.active:
		print("[SIEGE-DEV] a siege is already running (%d still on the wire)" % s.live_strength())
		return true
	# Re-arm a spent run so the assault can be called repeatedly in one sitting.
	s.nights_run = 0
	s.run_strength = 0
	s.open_siege(DEV_SIEGE_STRENGTH)
	print("[SIEGE-DEV] forced siege: %d attackers in %d cells, bearing %.0f deg" % [
		s.run_strength, s.cells.size(), rad_to_deg(s.sector_bearing)])
	if not MissionWeather.is_night:
		# The 80 m materialize ring is derived from the NIGHT sight cap. Called in
		# daylight the cells become men in plain view, which is the trigger's
		# artefact and not a bug in the assault.
		print("[SIEGE-DEV] DAYLIGHT - cells will pop into view at 80m; judge the pop at night only")
	return true


func _open_pause() -> void:
	if _pause_menu != null:
		return
	GameManager.pause_game()
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.build(_in_mission)
	_pause_menu.resume_pressed.connect(_close_pause)
	_pause_menu.barracks_pressed.connect(_pause_barracks)
	_pause_menu.save_pressed.connect(_pause_save)
	_pause_menu.abandon_pressed.connect(_pause_abandon)
	_pause_menu.quit_to_menu_pressed.connect(_pause_quit)


func _close_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	GameManager.resume_game()


## Barracks OVER the paused world: check the roster without leaving the campaign.
## The world stays loaded underneath; BACK returns to the pause menu.
func _pause_barracks() -> void:
	if _pause_menu != null:
		_pause_menu.teardown()
	var barracks := BarracksScreen.new()
	barracks.process_mode = Node.PROCESS_MODE_ALWAYS
	barracks.back_pressed.connect(func() -> void:
		barracks.queue_free()
		if _pause_menu != null:
			_pause_menu.build(_in_mission))
	add_child(barracks)


func _pause_save() -> void:
	var slot: int = SaveManager.latest_slot() if SaveManager.latest_slot() >= 0 else 0
	var ok: bool = SaveManager.save_game(slot, "MANUAL")
	_close_pause()
	var hud: Node = get_tree().get_first_node_in_group("mission_hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "SAVED" if ok else "SAVE FAILED")


## Abandoning is a DEBRIEF, not a delete (Pillar 5: fail forward). Route through
## the director's own abort so the roster consequences are the real ones.
func _pause_abandon() -> void:
	_close_pause()
	if director != null and director.has_method("fail_mission"):
		director.fail_mission("ABANDONED")


func _pause_quit() -> void:
	_close_pause()
	# The demo has no menu front door: routing its quit into the real MainMenu
	# let NEW GAME rebuild a demo-planned world with the arc clock half-spent
	# and death rewired to the real debrief (audit 2026-08-13, D-1). A demo
	# quit is a clean fresh day.
	if GameFlow.demo_mode:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/levels/demo_game.tscn")
		return
	show_menu()


func _swap_screen(screen: Node) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = screen
	if screen != null:
		add_child(screen)


func _teardown_world() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	_in_world = false
	_in_mission = false
	if world != null:
		world.queue_free()
		world = null
	director = null
	mission_hud = null
	squad = null
	GameManager.player = null
	GameManager.is_paused = false
	get_tree().paused = false
	MissionScope.reset()
	# Whatever the mission changed (KIA, replacements, intel) commits here or not
	# at all. on_mission_end() has already run for a completed op.
	CampaignState.commit_mission()


func show_menu() -> void:
	_teardown_world()
	SaveManager.context = "menu"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var menu := MainMenuScreen.new()
	menu.continue_pressed.connect(continue_campaign)
	menu.new_pressed.connect(start_default_operation)
	menu.barracks_pressed.connect(show_barracks)
	menu.record_pressed.connect(show_service_record)
	menu.settings_pressed.connect(show_settings)
	_swap_screen(menu)


func show_barracks() -> void:
	var barracks := BarracksScreen.new()
	barracks.back_pressed.connect(show_menu)
	_swap_screen(barracks)


func show_service_record() -> void:
	var record := ServiceRecordScreen.new()
	record.back_pressed.connect(show_menu)
	_swap_screen(record)


func show_settings() -> void:
	var settings := SettingsScreen.new()
	settings.back_pressed.connect(show_menu)
	_swap_screen(settings)


func _on_mission_ended(result: Dictionary) -> void:
	if _debrief_pending:
		return
	_debrief_pending = true
	if squad != null and is_instance_valid(squad):
		squad.on_mission_end()
	# W75: marksmanship into the report.
	result["shots"] = WeaponHolder.session_shots
	result["hits"] = WeaponHolder.session_hits
	# The AAR score banks as hidden reputation (ADR-032) - the only tell is the title.
	if CampaignState.bank_reputation(DebriefScreen.compute_score(result)) and director != null:
		director.toast.emit("FIELD PROMOTION: %s" % CampaignState.title())
	CampaignState.on_mission_end(result)
	# W32: Iron Man - KIA archives the whole campaign.
	if CampaignState.iron_man and not bool(result.get("success", true)) and str(result.get("reason", "")) == "KIA":
		result["iron_man_wipe"] = true
		CampaignState.reset_campaign()
	_show_debrief_delayed(result)


func _show_debrief_delayed(result: Dictionary) -> void:
	await get_tree().create_timer(3.0).timeout
	_debrief_pending = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_teardown_world()
	var debrief := DebriefScreen.new()
	debrief.set_result(result)
	var back_to_hub: bool = int(SaveManager.hub_snapshot.get("operation_seed", 0)) != 0 \
		and not bool(result.get("iron_man_wipe", false))
	debrief.continue_pressed.connect(enter_hub if back_to_hub else show_menu)
	_swap_screen(debrief)


## ---------------- THE OPEN PATROL WORLD (ADR-029, Accepted 2026-08-04) ----------------
## menu -> NEW/CONTINUE -> live at the firebase inside the populated AO ->
## walk out the wire -> patrol. One world, one build, one operation seed.

## The single fixed operation the game boots into. The operation-select screen is
## retired (fossil law): NEW GAME drops you straight at the firebase hub. One seed
## per operation (ADR-010) - the same firebase and AO every launch.
const DEFAULT_OPERATION_SEED: int = 47225
## Loading-screen fact column width. Long lines are unreadable at a glance and the
## player only has the length of a world build to read one.
const FACT_WRAP_PX: float = 760.0

func start_default_operation() -> void:
	# `--perf-seed=N` benches a seed other than the shipped one. Levers that exist only
	# under some conditions (campfires are NIGHT/DUSK/DAWN only) are unmeasurable at
	# 47225, which rolls DAY. Measurement override only - the shipped default is 47225.
	var op_seed: int = DEFAULT_OPERATION_SEED
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--perf-seed="):
			op_seed = int(a.get_slice("=", 1))
	_begin_operation(op_seed, MissionGenerator.codename_for(op_seed))


func _begin_operation(op_seed: int, op_name: String) -> void:
	SaveManager.hub_snapshot = {
		"operation_seed": op_seed, "operation_name": op_name,
	}
	enter_hub()


func continue_campaign() -> void:
	var slot := SaveManager.latest_slot()
	if slot < 0:
		start_default_operation()
		return
	load_from_slot(slot)


func load_from_slot(slot: int) -> void:
	var s: SaveData = SaveManager.load_game(slot)
	if s == null:
		show_menu()
		return
	SaveManager.apply(s)
	if int(SaveManager.hub_snapshot.get("operation_seed", 0)) == 0:
		start_default_operation()
		return
	enter_hub()


## The array (get_height_at) and the baked chunk mesh MUST agree at the player's
## feet, and the log proves it on every deploy - the probe suite once said "level"
## while the live player stood under the hillside (verify in object space).
func _report_spawn_truth(spawn: Vector3, op_seed: int) -> void:
	if world == null or world.player == null:
		return
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(spawn.x, 400.0, spawn.z), Vector3(spawn.x, -100.0, spawn.z))
	q.exclude = [world.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	var phys_y: float = -999.0
	var cname: String = "NO-HIT"
	if hit.has("position"):
		phys_y = (hit.position as Vector3).y
		if hit.collider is Node:
			cname = (hit.collider as Node).name
	var arr_y: float = world.terrain_manager.get_height_at(spawn)
	print("[SPAWN-TRUTH] seed=%d spawn=%.0f,%.0f physics_y=%.2f array_y=%.2f delta=%.2f top_hit=%s player_y=%.2f" % [
		op_seed, spawn.x, spawn.z, phys_y, arr_y, phys_y - arr_y, cname,
		world.player.global_position.y])


## Re-entrancy generation. enter_hub AWAITS while the world builds, so a second
## entry that arrives mid-build (boot auto-starts a patrol in _ready, and any
## menu path can call in on top of it) used to interleave with the first: the
## older coroutine resumed past its await and added a SECOND FieldDirector.
## Two directors both poll the wire and both bank, which double-counted every
## patrol - rank and missions_played advanced twice per walk-out.
var _world_entry: int = 0

## DEMO GAME (War Room 2026-07-29): demo_game.tscn sets this before booting the
## SAME flow - one world-build path, never a parallel copy (ADR-028).
static var demo_mode: bool = false
const DEMO_MAP_SIZE: float = 512.0


func enter_hub() -> void:
	_world_entry += 1
	var entry: int = _world_entry
	_teardown_world()
	SaveManager.context = "hub"
	var op_seed: int = int(SaveManager.hub_snapshot.get("operation_seed", 0))
	var op_name: String = str(SaveManager.hub_snapshot.get("operation_name", "OPERATION"))
	# The loading screen is the only place this game has the player's attention and
	# nothing to ask of him. It carries history instead of a progress noun: the war did
	# not start in 1965, and a man who knows why the village hates him is playing a
	# different game than one who does not. (WarFacts holds the rules for that file.)
	var loading := ReconUI.make_screen_root(load("res://assets/ui/loading_bg.png"))
	var lc := CenterContainer.new()
	lc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	col.custom_minimum_size = Vector2(FACT_WRAP_PX, 0)
	var fact := ReconUI.make_label(WarFacts.random_fact(), 17, ReconUI.AMBER)
	fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact.custom_minimum_size = Vector2(FACT_WRAP_PX, 0)
	fact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(fact)
	var back := ReconUI.make_label("BACK TO %s..." % op_name, 15, ReconUI.DIM)
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(back)
	lc.add_child(col)
	loading.add_child(lc)
	_swap_screen(loading)
	world = (load("res://scenes/levels/game_world.tscn") as PackedScene).instantiate() as GameWorld
	# GameFlow runs ALWAYS so Esc works while paused - but INHERIT resolves to the
	# parent, so without this the entire war kept running behind the pause menu.
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.mission_seed = op_seed
	world.spawn_player_on_ready = false
	if demo_mode:
		world.map_size = DEMO_MAP_SIZE
	add_child(world)
	while not world.is_world_ready:
		await get_tree().create_timer(0.25).timeout
		if world == null or entry != _world_entry:
			return
	if entry != _world_entry:
		return
	director = FieldDirector.new()
	world.add_child(director)
	director.setup(world)
	director.state.seed_value = op_seed
	# THE OPEN PATROL WORLD (ADR-029): the firebase and its populated AO are
	# ONE build - form up, walk out the wire, go find problems.
	# DEMO GAME rides this same boot with an authored small-slice plan; the
	# patrol planner's 240-560m bands collapse under ~900m maps.
	var patrol_plan: Dictionary = MissionGenerator.plan_demo_world(world, op_seed) \
		if demo_mode else MissionGenerator.plan_patrol_world(world, op_seed)
	var built: Dictionary = MissionGenerator.build_patrol_world(world, director, patrol_plan)
	# THE COLLIDER RACE (2026-07-30): build_patrol_world() just added the firebase's own
	# colliders (its baked mound/floor body, the remeshed vegetation/parapet trimeshes) via
	# add_child(), synchronously, no await anywhere in that chain. PhysicsServer3D does not
	# guarantee a just-added collider is queryable by intersect_ray() until its pending-add
	# queue is processed at the next physics step - so surface_y()'s raycast, fired below for
	# player/squad/garrison seating, could miss the firebase's own floor entirely and fall
	# through to whatever WAS already registered (bare terrain, well below the real floor).
	# Two physics frames closes the window with margin.
	await get_tree().physics_frame
	if world == null or entry != _world_entry:
		return
	await get_tree().physics_frame
	if world == null or entry != _world_entry:
		return
	var spawn: Vector3 = built.spawn_pos
	# THE BUNK SPAWN: start the man on a cot inside the wire, not in a field outside it.
	# Also the only spawn that is PROVABLY on the firebase - fsb_main_v3 is authored with
	# y=0 at the mound TOE, so terrain height buries anything seated inside the base.
	var bunk: Vector3 = _firebase_bunk(patrol_plan.get("fsb_center", Vector3.ZERO))
	var spawn_seated: bool = bunk == Vector3.ZERO
	if not spawn_seated:
		spawn = bunk
	# Dev lens: `--spawn-at-village` drops the patrol at the nearest village edge so
	# the living world can be judged without the walk (temporary, Summoner 2026-07-18).
	if OS.get_cmdline_user_args().has("--spawn-at-village"):
		var best: Vector3 = spawn
		var best_d: float = INF
		for s in patrol_plan.sites:
			var site: Dictionary = s
			if str(site.get("kind", "")) == "village":
				var c: Vector3 = site.center
				var dist: float = Vector2(c.x - spawn.x, c.z - spawn.z).length()
				if dist < best_d:
					best_d = dist
					best = c
		if best_d < INF:
			var away: Vector3 = (spawn - best).normalized()
			spawn = best + Vector3(away.x, 0.0, away.z) * 60.0
			spawn.y = world.terrain_manager.get_height_at(spawn)
			print("[SPAWN-DEV] --spawn-at-village: dropped %.0fm from village at %.0f,%.0f" % [
				60.0, best.x, best.z])
	world.spawn_player_at(spawn, spawn_seated)
	# SPAWN-TRUTH PROBE (2026-07-30): one line, printed once, that answers the "is
	# it still burying people" question without guesswork. spawn.y is what we ASKED
	# for; surface_y(spawn) is what the physics world says is ACTUALLY solid there,
	# probed fresh right now (after the collider-race yields above); player.
	# global_position.y is where the player ACTUALLY landed. If surface_y disagrees
	# with spawn.y by more than a meter or so, the marker/floor mismatch is real. If
	# player.y disagrees with spawn.y, something moved him after spawn_player_at
	# returned (move_and_slide, gravity, another reseat) - check for that next.
	if world.player != null:
		print("[SPAWN-TRUTH] asked spawn.y=%.2f | surface_y(spawn) now=%.2f | player landed at y=%.2f | seated=%s" % [
			spawn.y, world.surface_y(spawn), world.player.global_position.y, spawn_seated])
	if world.hud != null:
		world.hud.managed_by_flow = true
	squad = SquadSystem.new()
	world.add_child(squad)
	squad.setup(world, director, spawn)
	director.squad_system = squad
	director.setup_patrol(built)
	# Death outside the wire is a field AAR, then you wake at the firebase
	# (Pillar 5) - same debrief pipeline, patrol framing.
	director.mission_failed.connect(_on_mission_ended)
	# The field HUD: toasts/barks/compass/squad strip. No objective panel exists
	# to show - the patrol world plans none.
	mission_hud = MissionHUD.new()
	world.add_child(mission_hud)
	mission_hud.setup(world, director, patrol_plan)
	mission_hud.squad = squad
	var weather := MissionWeather.new()
	world.add_child(weather)
	weather.setup(world, str(patrol_plan.weather), str(patrol_plan.time))
	if MissionWeather.is_night:
		world.start_night_ambience()
	MissionGenerator.apply_veg_boosts(world,
		(built.gate_pos as Vector3) + (built.gate_out as Vector3) * 90.0, patrol_plan.sites)
	WeaponHolder.session_shots = 0
	WeaponHolder.session_hits = 0
	# A restored position is X/Z memory, never Y truth: the world reseats terrain
	# every build, so a stale saved height puts the player under the ground. Only
	# a RESTORED save needs this - a fresh boot already has the correct bunk seat
	# from spawn_player_at(). floor_y, not surface_y: the saved point can be under a
	# hootch roof, and surface_y's top-down ray would stand him on it.
	var had_save: bool = SaveManager.pending_player != null
	SaveManager.apply_pending_player(world.player)
	if had_save and world.player != null:
		var pp: Vector3 = world.player.global_position
		world.player.global_position.y = world.floor_y(pp) + 1.0
	# Hot chow is free. YOUR RIFLE IS NOT (Summoner's decree, 2026-07-13): weapon
	# condition persists across missions and is only restored by working the
	# armorer's bench - it costs time, and it cannot be done in the field.
	if world.player != null:
		world.player.set("hunger", 100.0)
		var wh: Node = world.player.get_node_or_null("Head/Camera3D/WeaponHolder")
		if wh != null and wh.has_method("refresh_after_load"):
			wh.call("refresh_after_load")
	await get_tree().physics_frame  # settle cover colliders before reveal (no first-frame resettle)
	# Ray where the player ACTUALLY stands (post save-restore), not the planned
	# spawn - the save teleport was invisible to a spawn-point ray.
	_report_spawn_truth(world.player.global_position if world.player != null else spawn, op_seed)
	# Instruments attach to the world the player actually walks - never a world of
	# their own. `--print-fps` is the export-safe printer (M-2/M-3); `--perf-probe`
	# samples, `--perf-cycle` runs the attribution phases.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--print-fps"):
		world.add_child(FpsPrinter.new())
	if args.has("--perf-probe"):
		# res://tests ships in no export, so this load returns null in a shipped build -
		# it must degrade to a warning, never instantiate on null (audit 2026-08-04, W-4).
		var packed_probe: PackedScene = load("res://tests/perf_probe.tscn") as PackedScene
		if packed_probe == null:
			push_warning("[PERF] perf_probe.tscn absent in this build - use --print-fps")
		else:
			var probe: Node = packed_probe.instantiate()
			probe.set("cycle_systems", args.has("--perf-cycle"))
			probe.set("siege_study", args.has("--perf-siege"))
			probe.set("shadow_study", args.has("--shadow-study"))
			world.add_child(probe)
			probe.call("attach", world)
	if args.has("--roof-probe"):
		# res://tools ships in no export - degrade to a warning, never instantiate on null.
		var roof: GDScript = load("res://tools/probe_roof_spawn.gd") as GDScript
		if roof == null:
			push_warning("[ROOF-PROBE] probe_roof_spawn.gd absent in this build")
		else:
			world.add_child(roof.new())
	_swap_screen(null)
	_in_world = true
	_in_mission = false   # the hub: Esc offers Barracks, SAVE and QUIT TO MENU
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "FIREBASE")
