## dealer_table.gd - SSG Virgil Poteet, supply: the table beside the dump (council 2026-09-14,
## ruling 3 - the FROZEN "RPG shop" thawed by the Summoner's words, under three guards).
##
## THE GUARDS. Never from corpses · everything consumable · never a weapon in either direction.
## The rack (GOODS) holds no path under data/weapons/ and tools/probe_dealer.gd asserts it.
## Prices are objects for objects and never move; what moves is which rows stand, keyed by
## which tasking ids are CLOSED - never how many (ADR-038 §2a). His lines are keyed the same way
## and tests/test_hearts_felt.gd greps LINES.
##
## The same node shape as ArmorersBench: an in-world [F] with a BenchMenu. The two asks:
##   dealer/case  - carry his case down to the ville's elder: a trade/<village>/p<n> deed
##                  (KIND_TRADE), and the same case turns up in the VC camp's cache.
##   dealer/sack  - the slick's mail sack (PilotRecovery plants it at the wreck): to Poteet it
##                  CLOSES, at the TOC's radio it is REFUSED. One object, two claimants.
## The case and the sack are flags on this node (no carried-prop idiom exists): the world dies
## with them, the taskings persist in CampaignState.
##
## ART GAP: the table is a placeholder BoxMesh with the ration case on it; no collider, so no
## garrison man can stick on it (the 9/13 census lesson).
class_name DealerTable
extends Node3D

const CASE_MODEL: String = "res://assets/us/props/interior/fb_c_ration_case.glb"
const INTERACT_RADIUS: float = 2.6
const TOC_RADIUS: float = 4.0
const UNPROMPTED_M: float = 6.0
const POLL_S: float = 1.0
const TABLE_OFF_MARKER_M: float = 3.0
const CAMP_CACHE_MIN_M: float = 4.0
const CAMP_CACHE_MAX_M: float = 14.0
const TASK_CASE: String = "dealer/case"
const TASK_SACK: String = "dealer/sack"
const CLAIMANT: String = "dealer"
const SUPPLY_MARKER: String = "USSupplyDepot_001"
const TOC_RADIO_MARKER: String = "FOOTPRINT_003"

## Writer's lines of record (analysis/writer.md §3a), verbatim, keyed by state.
const LINES: Dictionary = {
	"ask": "POTEET: MY MAN FROM THE VILLE BRINGS RICE WINE UP THE ROAD. WALK HIM A CASE DOWN. I'LL REMEMBER.",
	"refuse": "POTEET: SUIT YOURSELF, COUSIN. THE HILL DON'T CARE WHO SAYS NO TO IT.",
	"delivery": "POTEET: THAT'S A MAN WHO KNOWS WHAT A THING WEIGHS. PEACHES ARE ON THE HOUSE.",
	"conflict": "POTEET: THE TOC WANTS THAT BIRD'S PAPERS. FINE. THE MAIL SACK AIN'T PAPERS. THINK ON IT.",
	"ville_shut": "POTEET: MY MAN FROM THE VILLE DIDN'T COME UP THE ROAD. YOU DID THAT. SAIGON PRICES NOW.",
	"ville_open": "POTEET: MY MAN FROM THE VILLE CAME UP THE ROAD TODAY. YOU WANT FISH, I GOT FISH.",
	"iron": "POTEET: THAT DOOR GUN STAYS ON ITS MOUNT. I DON'T MOVE IRON. I MOVE WHAT A MAN EATS.",
	"elder_took": "THE ELDER TAKES THE CASE WITHOUT A WORD.",
	"toc_sack": "TOC: THE SACK GOES UP WITH THE MANIFEST. THE CREW'S PAPERS ARE ACCOUNTED FOR.",
}

## The rack. `needs` is a tasking id that must be CLOSED for the row to stand; `once` rows
## leave the rack when taken (the rack moves, the price does not).
const GOODS: Array[Dictionary] = [
	{"id": "chow", "label": "THE GOOD CANS - PEACHES AND POUND CAKE", "needs": "", "once": false},
	{"id": "socks", "label": "DRY SOCKS AND A BANDAGE", "needs": "", "once": true},
	{"id": "mortar", "label": "AN OFF-BOOK MORTAR ROUND", "needs": TASK_CASE, "once": true},
	{"id": "mags", "label": "MAGS OFF THE PALLET", "needs": TASK_SACK, "once": true},
]

var world: GameWorld = null
var director: FieldDirector = null
var carrying_case: bool = false
var carrying_sack: bool = false
var _taken: Dictionary = {}   ## good id -> sim_day it was taken
var _said: Dictionary = {}    ## line key -> sim_day it was said
var _prompt: Label3D = null
var _menu: BenchMenu = null
var _poll: float = 0.0
var _toc_pos: Vector3 = Vector3.ZERO
var _camp_case: Node3D = null


static func stamp(game_world: GameWorld, field_director: FieldDirector, fsb_center: Vector3) -> DealerTable:
	var table := DealerTable.new()
	table.name = "DealerTable"
	table.world = game_world
	table.director = field_director
	var marker: Vector3 = SitePlanner.fsb_marker_world(fsb_center, SUPPLY_MARKER)
	var pos: Vector3 = marker
	if marker == Vector3.ZERO:
		pos = fsb_center
	else:
		var inward := Vector3(fsb_center.x - marker.x, 0.0, fsb_center.z - marker.z)
		if inward.length() > 0.5:
			pos = marker + inward.normalized() * TABLE_OFF_MARKER_M
	game_world.add_child(table)
	pos.y = game_world.floor_y(pos + Vector3.UP * 0.5)
	table.global_position = pos
	table._toc_pos = SitePlanner.fsb_marker_world(fsb_center, TOC_RADIO_MARKER)
	print("[DEALER] Poteet's table at %s (marker %s)" % [pos, marker])
	return table


func _ready() -> void:
	add_to_group("dealer_table")
	_build_placeholder()
	_build_prompt()


func _build_placeholder() -> void:
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(1.6, 0.06, 0.8)
	top.mesh = top_mesh
	top.position = Vector3(0, 0.8, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.32, 0.22)
	mat.roughness = 0.95
	top.material_override = mat
	add_child(top)
	for x: float in [-0.7, 0.7]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.06, 0.78, 0.7)
		leg.mesh = leg_mesh
		leg.position = Vector3(x, 0.39, 0)
		leg.material_override = mat
		add_child(leg)
	var packed: PackedScene = load(CASE_MODEL) as PackedScene
	if packed != null:
		var case_node: Node3D = packed.instantiate() as Node3D
		if case_node != null:
			case_node.position = Vector3(0.3, 0.83, 0)
			add_child(case_node)


func _build_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.font_size = 26
	_prompt.pixel_size = 0.0035
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.95, 0.78, 0.42)
	_prompt.position = Vector3(0, 1.6, 0)
	_prompt.text = "SGT POTEET - SUPPLY\nPRESS [F]"
	_prompt.visible = false
	add_child(_prompt)


func _exit_tree() -> void:
	close_menu()


func _physics_process(delta: float) -> void:
	var player: Node3D = GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		close_menu()
		return
	var dist: float = player.global_position.distance_to(global_position)
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_S
		if dist <= UNPROMPTED_M:
			_say_unprompted()
	if dist > INTERACT_RADIUS:
		_prompt.visible = false
		close_menu()
		return
	_prompt.visible = true
	if Input.is_action_just_pressed("interact"):
		if _menu != null:
			close_menu()
		else:
			open_menu()


## ---------- the table ----------

func rack_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for g: Dictionary in GOODS:
		var needs: String = str(g.get("needs", ""))
		if not needs.is_empty() and CampaignState.tasking_state(needs) != CampaignState.TASKING_CLOSED:
			continue
		if bool(g.get("once", false)) and _taken.has(str(g.id)):
			continue
		rows.append({"id": "good:%s" % str(g.id), "label": str(g.label), "enabled": true})
	var case_state: StringName = CampaignState.tasking_state(TASK_CASE)
	if case_state == StringName(""):
		rows.append({"id": "case:take", "label": "TAKE HIS CASE DOWN TO THE VILLE", "enabled": true})
		rows.append({"id": "case:refuse", "label": "SAY NO", "enabled": true})
	elif case_state == CampaignState.TASKING_OPEN:
		if carrying_case:
			rows.append({"id": "case:down", "label": "SET THE CASE DOWN", "enabled": true})
		else:
			rows.append({"id": "case:pick", "label": "PICK THE CASE BACK UP", "enabled": true})
	if carrying_sack:
		rows.append({"id": "sack:hand", "label": "HAND OVER THE MAIL SACK", "enabled": true})
	return rows


func open_menu() -> void:
	if _menu != null:
		return
	_menu = BenchMenu.new()
	add_child(_menu)
	_menu.build_rows("SGT POTEET - SUPPLY", rack_rows())
	_menu.row_chosen.connect(choose)
	_menu.close_requested.connect(close_menu)
	GameManager.is_in_menu = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var wh: WeaponHolder = _weapon_holder()
	if wh != null and wh.primary_is_captured:
		_say("iron")


func close_menu() -> void:
	if _menu == null:
		return
	_menu.queue_free()
	_menu = null
	GameManager.is_in_menu = false
	if not GameManager.is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func choose(id: String) -> void:
	match id:
		"case:take":
			CampaignState.issue_tasking(TASK_CASE, CLAIMANT, SimClock.sim_hour)
			carrying_case = true
			_say("ask", true)
		"case:refuse":
			CampaignState.issue_tasking(TASK_CASE, CLAIMANT, SimClock.sim_hour)
			CampaignState.settle_tasking(TASK_CASE, CampaignState.TASKING_REFUSED, "he said no at the table")
			_say("refuse", true)
		"case:down":
			carrying_case = false
		"case:pick":
			carrying_case = true
		"sack:hand":
			if CampaignState.settle_tasking(TASK_SACK, CampaignState.TASKING_CLOSED, "the mail sack came to Poteet"):
				carrying_sack = false
				_say("delivery", true)
		_:
			if id.begins_with("good:"):
				_take_good(id.trim_prefix("good:"))
	if _menu != null:
		close_menu()
		open_menu()


func _take_good(gid: String) -> void:
	for g: Dictionary in GOODS:
		if str(g.id) != gid:
			continue
		var needs: String = str(g.get("needs", ""))
		if not needs.is_empty() and CampaignState.tasking_state(needs) != CampaignState.TASKING_CLOSED:
			return
		if bool(g.get("once", false)) and _taken.has(gid):
			return
	var player: Node = GameManager.player
	if player == null:
		return
	match gid:
		"chow":
			player.set("hunger", 100.0)
		"socks":
			var hs: HealthSystem = player.get("health_system") as HealthSystem
			if hs != null and hs.health_packs < MedicalCrate.CARRY_LIMIT:
				hs.health_packs += 1
				hs.health_pack_changed.emit(hs.health_packs)
		"mortar":
			if director != null and is_instance_valid(director):
				director.fire_support["mortar"] = int(director.fire_support.get("mortar", 0)) + 1
		"mags":
			var wh: WeaponHolder = _weapon_holder()
			if wh != null:
				wh.add_full_mags(wh.current_slot, 3)
		_:
			return
	_taken[gid] = SimClock.sim_day
	print("[DEALER] took %s" % gid)


## ---------- [F] away from the table (player.gd asks through the dealer_table group) ----------

func field_prompt(player: Node3D) -> String:
	if carrying_case and _elder_near(player) != null:
		return "[F] HAND THE CASE TO THE ELDER"
	if carrying_sack and _toc_pos != Vector3.ZERO \
			and player.global_position.distance_to(_toc_pos) <= TOC_RADIUS:
		return "[F] TURN THE SACK IN AT THE TOC"
	if not carrying_sack and not carrying_case and _sack_near(player) != null:
		return "[F] PICK UP THE MAIL SACK"
	return ""


func try_field_interact(player: Node3D) -> bool:
	if carrying_case:
		var elder: Civilian = _elder_near(player)
		if elder != null:
			_deliver_case(elder)
			return true
	if carrying_sack and _toc_pos != Vector3.ZERO \
			and player.global_position.distance_to(_toc_pos) <= TOC_RADIUS:
		if CampaignState.settle_tasking(TASK_SACK, CampaignState.TASKING_REFUSED, "turned in at the TOC"):
			carrying_sack = false
			_say("toc_sack", true)
		return true
	if not carrying_sack and not carrying_case:
		var sack: Node3D = _sack_near(player)
		if sack != null:
			pick_up_sack(sack)
			return true
	return false


func pick_up_sack(sack: Node3D) -> void:
	CampaignState.issue_tasking(TASK_SACK, CLAIMANT, SimClock.sim_hour)
	carrying_sack = true
	sack.queue_free()
	var pr: PilotRecovery = get_tree().get_first_node_in_group("pilot_recovery") as PilotRecovery
	if pr != null:
		pr.incident["crash_sack_pos"] = Vector3.ZERO
	print("[DEALER] the mail sack is on his back")


func _deliver_case(elder: Civilian) -> void:
	var key: int = HmLedger.place_key(elder.village_center)
	CampaignState.hearts.note("trade/%d/p%d" % [key, CampaignState.missions_played],
		HmLedger.KIND_TRADE, key, SimClock.sim_hour, "poteet's case handed to the elder")
	CampaignState.settle_tasking(TASK_CASE, CampaignState.TASKING_CLOSED, "the case reached the ville")
	carrying_case = false
	_say("elder_took", true)
	_seed_camp_cache()
	print("[DEALER] case delivered to %s of village %d" % [elder.name, key])


## The same case, on the enemy's side: the ville's porters carry to a hole in the ground and
## the player meets his own trade in the ZPU camp's cache, wordlessly.
func _seed_camp_cache() -> void:
	if _camp_case != null or world == null:
		return
	var gun: Vector3 = Vector3.ZERO
	for n in get_tree().get_nodes_in_group("zpu_guns"):
		var zg := n as ZpuGun
		if zg != null and is_instance_valid(zg) and not zg.ambient:
			gun = zg.global_position
			break
	if gun == Vector3.ZERO:
		print("[DEALER] no camp gun on this plan - the case goes nowhere")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.mission_seed) ^ hash("dealer/case")
	var at: Vector3 = MissionGenerator._passable_near(world, rng, gun, CAMP_CACHE_MIN_M, CAMP_CACHE_MAX_M, 40)
	if at == Vector3.ZERO:
		at = gun + Vector3(CAMP_CACHE_MIN_M, 0.0, 0.0)
	_camp_case = MissionGenerator.place_event_prop(world, CASE_MODEL, MissionGenerator._seat(world, at),
		rng.randf_range(0.0, 360.0))
	print("[DEALER] the case turned up in the camp cache at %s" % at)


func camp_case() -> Node3D:
	return _camp_case


## ---------- his voice ----------

func _say(key: String, prompted: bool = false) -> void:
	if not LINES.has(key):
		return
	if not prompted and int(_said.get(key, -1)) == SimClock.sim_day:
		return
	_said[key] = SimClock.sim_day
	if director != null and is_instance_valid(director):
		director.toast.emit(String(LINES[key]))
	print("[DEALER] %s" % String(LINES[key]))


## Within UNPROMPTED_M, one line per state key per day. Keyed by WHICH ids are settled,
## never how many.
func _say_unprompted() -> void:
	if CampaignState.tasking_state(TASK_SACK) == CampaignState.TASKING_REFUSED:
		_say("conflict")
		return
	if CampaignState.tasking_state(TASK_CASE) == CampaignState.TASKING_CLOSED \
			or CampaignState.tasking_state(TASK_SACK) == CampaignState.TASKING_CLOSED:
		_say("delivery")
		return
	if CampaignState.tasking_state(TASK_CASE) == StringName(""):
		return
	var key: int = _nearest_village_key()
	if key == 0:
		return
	_say("ville_shut" if CampaignState.hearts.band(key) != HmLedger.BAND_QUIET else "ville_open")


func _nearest_village_key() -> int:
	if director == null or not is_instance_valid(director):
		return 0
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF
	for c: Vector3 in director._known_village_centers():
		var d: float = c.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = c
	return 0 if best == Vector3.ZERO else HmLedger.place_key(best)


## ---------- lookups ----------

func _weapon_holder() -> WeaponHolder:
	var player: Node = GameManager.player
	if player == null:
		return null
	return player.get_node_or_null("Head/Camera3D/WeaponHolder") as WeaponHolder


## The elder within reach; a village with no elder left answers through any of its own.
func _elder_near(player: Node3D) -> Civilian:
	var fallback: Civilian = null
	for n in AgentRegistry.civilians:
		var civ: Civilian = n as Civilian
		if civ == null or not is_instance_valid(civ) or civ.village_center == Vector3.ZERO:
			continue
		if civ.has_method("is_dead") and bool(civ.call("is_dead")):
			continue
		if civ.global_position.distance_to(player.global_position) > INTERACT_RADIUS:
			continue
		if civ.occupation == "elder":
			return civ
		if fallback == null:
			fallback = civ
	return fallback


func _sack_near(player: Node3D) -> Node3D:
	var pr: PilotRecovery = get_tree().get_first_node_in_group("pilot_recovery") as PilotRecovery
	if pr == null:
		return null
	var sack: Node3D = pr.crash_sack
	if sack == null or not is_instance_valid(sack):
		return null
	if sack.global_position.distance_to(player.global_position) > INTERACT_RADIUS:
		return null
	return sack
