## campaign_state.gd - persistent campaign layer: AA threat level with decaying
## modifiers, player reputation, roster, mission history. Saved to user://.
extends Node

## Bump when the on-disk shape changes, and add a branch to _migrate().
const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH := "user://campaign.cfg"
const TEST_SAVE_PATH := "user://campaign_test.cfg"
const BASE_THREAT: float = 0.35

## Resolved in _ready() BEFORE load_campaign(): the headless suite passes
## `-- --test-save` so tests can never touch the player's real campaign.
var save_path: String = DEFAULT_SAVE_PATH

## Mid-mission writes are held in memory until the debrief commits them - a
## mission is ALL-OR-NOTHING. Squad code mutates LIVE references into `roster`,
## so an un-deferred save mid-mission would persist a KIA without the reputation,
## missions_played and mission log that must land with it.
var _defer_saves: bool = false
var _dirty: bool = false

var threat_level: float = BASE_THREAT
var threat_modifiers: Array = []  ## [{delta: float, missions_left: int, reason: String}]
## The player's HIDDEN reputation (ADR-032): banked AAR score. NEVER shown as a
## number anywhere - it surfaces only as title() and the armory tiers it opens.
var reputation: int = 0
var roster: Array = []            ## SquadMember dicts
var missions_played: int = 0
var mission_log: Array = []       ## trimmed result dicts
var iron_man: bool = false
var player_data: Dictionary = {"mos": "RIFLEMAN"}
var intel_points: int = 0  ## looted docs/captures sharpen the next briefing
## Tunnel mouths the player has satchelled, as world positions rounded to the
## metre. ADR-029 Amendment B: the world remembers a world verb. Never surfaced
## as a count, a panel or a marker - only as ground that is no longer there.
var collapsed_tunnels: Array = []
## The player's field marks (ADR-022 Amendment A) - the INTEL layer of his paper
## map, kept for the tour. Pure {kind, area:{x,z,r}, placed_at} dicts, never a
## count, never a tally by kind (§4).
var field_marks: Array = []
## The player's OWN pencil marks (ADR-022's ANNOTATED layer) - what he THINKS, placed
## from the sheet with no line of sight required, and kept for the whole tour. These
## are allowed to be wrong forever; nothing in the game may correct one.
var pencil_marks: Array = []
## REPORTED intel - the THIRD ink (ADR-022 has two layers; this is neither). A captured
## document is somebody else's CLAIM, dated, and it may be stale or flatly wrong. The
## game never reconciles one: walk there, find nothing, and the mark stays until the
## player rubs it out himself. {x, z, kind, patrol_no}
var reported_marks: Array = []
## THE BUTCHER'S BILL. His decree 2026-07-30: the aid station fills from REAL casualties, and
## the dead stack up as body bags beside it - a cumulative scoreboard of the player's own failure
## with NO UI, which is the only kind ADR-029 permits.
##
## `kia_total` NEVER decrements. Bags may be lifted out by graves registration, but the count of
## men the player got killed is not a resource and does not heal.
var kia_total: int = 0
## Men currently in the ward. Seeded 1-2 at the start of a tour on his ruling - an empty aid
## station in a war is the fresh-player failure, and the seed IS the fix. Grows with casualties
## taken in the field and DRAINS when bearers carry a man out to a dustoff.
var ward_wounded: int = 0
## Bags not yet flown out. Distinct from kia_total: this is what is STACKED and visible.
var bags_unlifted: int = 0
## Downed aircrew walked back to the wire alive (S28). A count, not a score - like
## ears_taken, the world may have an opinion about it before the economy does.
var pilots_recovered: int = 0
## Beds already occupied when a new tour opens. A fixed number, not a roll: ADR-010 forbids an
## unseeded one, and there is nothing to seed from on a wipe.
const WARD_SEED_ON_NEW_TOUR: int = 2
## Wounded per man killed. Roughly the real ratio for US infantry in Vietnam, and the reason the
## ward fills faster than the bag stack.
const WIA_PER_KIA: int = 3
## The aid station holds 8-12 stretchers (his brief). The ward saturates rather than growing
## without bound, because the twelfth bed is the last thing there is to look at.
const WARD_BEDS_MAX: int = 12

## Intel accrues SILENTLY (Summoner, 2026-07-28). This only ever counts UP - it is not
## the spendable pool. `intel_points` is still burned at the wire for S2's bearing
## toast, and a pool that drains every patrol could never reach a 20-30 threshold.
var lifetime_intel: int = 0
## Ears taken from enemy dead, strung on the necklace. A COUNT, never a score: nothing
## in the game rewards it, and the world is allowed to have an opinion about the man
## wearing it (village sentiment, squad barks). See war_room ear_necklace.md.
var ears_taken: int = 0
## The next silent threshold at which a real intel piece becomes findable. Rolled once
## per campaign inside the Summoner's 20-30 band, then re-rolled after each stash.
var next_stash_at: int = 0


## The ONE way intel is earned. Routing every source through here is what keeps the
## spendable pool and the silent accumulator from drifting apart.
func add_intel(amount: int) -> void:
	intel_points += amount
	lifetime_intel += amount
	if next_stash_at <= 0:
		_roll_next_stash()
	save_campaign()


func _roll_next_stash() -> void:
	next_stash_at = lifetime_intel + randi_range(20, 30)


## True when the player has quietly earned a real intel piece. Consumed by the site
## that hands it over - a tunnel cache or a large camp, never a routine body check.
func stash_is_due() -> bool:
	if next_stash_at <= 0:
		_roll_next_stash()
	return lifetime_intel >= next_stash_at


func consume_stash() -> void:
	_roll_next_stash()
	save_campaign()
## Armorer's rack fouling, weapon id -> condition 0-100. A weapon you rack dirty
## is still dirty when you draw it again; swapping is never a free clean.
var rack_condition: Dictionary = {}
## The cost of a firebase breach: what a sapper's satchel took out of the depot,
## as an ordnance-kind -> count dict. Read and CONSUMED by FieldDirector on the
## next walk-out (persistent, not permanent - it is one patrol's short allotment).
var depot_loss: Dictionary = {}


## The AC-47 was replaced by the AC-130, and the fire-support key went with it. A
## save written before that carries a dock against a call that no longer exists;
## dropping it silently would refund the player a strike he lost to a breach.
static func _migrate_depot_loss(loss: Dictionary) -> Dictionary:
	if not loss.has("spooky"):
		return loss
	var out: Dictionary = loss.duplicate(true)
	out["spectre"] = int(out.get("spectre", 0)) + int(out["spooky"])
	out.erase("spooky")
	return out




## The player's earned rank per tier (ADR-032, Summoner's ruling: real ranks, not
## slang). Same short-form vocabulary as SquadRoster.rank_for - one rank language.
const TITLES: Array[String] = ["PVT", "PFC", "SP4", "SGT", "SSG"]
## Internal pacing skeleton (ADR-032): reputation converts to a level, capped at 40.
## The level is NEVER shown, same law as the reputation number. Ranks and armory
## tiers pin to it; the levels between milestones are reserved for future smaller
## kit unlocks. Milestones widen on purpose - fewer rewards per gate, better ones.
const MAX_LEVEL: int = 40
const TITLE_LEVELS: Array[int] = [1, 3, 8, 18, 30]


## Cumulative reputation (banked AAR score, ~150/decent patrol) to REACH level n:
## quadratic, so early levels come ~1/patrol and the last ones take 3-4 patrols each.
static func rep_for_level(n: int) -> int:
	var k: int = clampi(n, 1, MAX_LEVEL) - 1
	return 75 * k + 6 * k * k


func level() -> int:
	var lvl: int = 1
	while lvl < MAX_LEVEL and reputation >= rep_for_level(lvl + 1):
		lvl += 1
	return lvl


func title_tier() -> int:
	var lvl: int = level()
	var tier: int = 0
	for i in range(TITLE_LEVELS.size()):
		if lvl >= TITLE_LEVELS[i]:
			tier = i
	return tier


func title() -> String:
	return TITLES[title_tier()]


## The ONE bank point for AAR score. True = the rank rose, so the caller can
## toast the promotion - the only tell the player ever gets.
func bank_reputation(points: int) -> bool:
	var before: int = title_tier()
	reputation += maxi(0, points)
	return title_tier() > before


## The living squadmate of a MOS owns his role's skill. Used at world-gen, before
## SquadSystem has spawned any AllyBase - reads the persistent roster directly.
## In-mission, prefer SquadRoster.skill_level(member_by_mos(mos).member, skill).
func roster_skill(mos: String, skill: String) -> int:
	for m in roster:
		var d: Dictionary = m
		if str(d.get("mos", "")) == mos and bool(d.get("alive", true)):
			return int((d.get("skills", {}) as Dictionary).get(skill, 0))
	return 0


func _ready() -> void:
	if is_test_run():
		save_path = TEST_SAVE_PATH
		# Never inherit a previous run's leftovers - the suite must start clean.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	load_campaign()


## True when launched by run_all_tests.ps1 (`-- --test-save`).
func is_test_run() -> bool:
	return OS.get_cmdline_user_args().has("--test-save")


func effective_threat() -> float:
	var total: float = threat_level
	for m in threat_modifiers:
		total += float(m.delta)
	return clampf(total, 0.0, 1.0)


func threat_label() -> String:
	var t := effective_threat()
	if t < 0.25:
		return "LOW"
	elif t < 0.5:
		return "MODERATE"
	elif t < 0.75:
		return "HIGH"
	return "CRITICAL"


func add_threat_modifier(delta: float, missions: int, reason: String) -> void:
	threat_modifiers.append({"delta": delta, "missions_left": missions, "reason": reason})


## Called by GameFlow at debrief time.
func on_mission_end(result: Dictionary) -> void:
	# The mission is over: writes go through again, and the save_campaign() at the
	# bottom of this function commits everything the op changed.
	_defer_saves = false
	_dirty = false
	missions_played += 1
	# Decay modifiers.
	var kept: Array = []
	for m in threat_modifiers:
		m.missions_left = int(m.missions_left) - 1
		if int(m.missions_left) > 0:
			kept.append(m)
	threat_modifiers = kept
	# Outcome nudges the baseline: loud missions attract attention, clean work cools the AO.
	var kills: int = int(result.get("kills", 0))
	if kills >= 12:
		threat_level = clampf(threat_level + 0.05, 0.1, 0.9)
	elif bool(result.get("success", false)) and kills <= 3:
		threat_level = clampf(threat_level - 0.03, 0.1, 0.9)
	# AA killed opportunistically cools the AO (writer: zpu_gun.gd:127).
	if int(result.get("aa_killed", 0)) > 0:
		add_threat_modifier(-0.08 * float(result.aa_killed), 2, "AA SITE DESTROYED")
	# S28: a pilot walked home is COUNTED, never priced - what he pays stays the
	# Summoner's open call. A pilot who died in the AO enters the butcher's bill:
	# he is a bagged American whether he wore the squad's patch or not.
	if int(result.get("pilot_recovered", 0)) > 0:
		pilots_recovered += 1
	if int(result.get("pilot_lost", 0)) > 0:
		kia_total += 1
		bags_unlifted += 1
	# THE DEAD ARE BANKED. squad_system.gd:443 has always named every man lost into
	# state.flags["squad_kia"], and this function threw the list away - then
	# SquadRoster.ensure_roster deleted the bodies, so nothing in the campaign remembered
	# that anyone died. The ward and the bag stack both read these.
	var lost: int = (result.get("squad_kia", []) as Array).size()
	if lost > 0:
		kia_total += lost
		bags_unlifted += lost
		# THE WOUNDED ARE DERIVED, and deliberately so. `ally_base.gd:41` states it plainly -
		# "Allies have no alert tier or downed state" - so a squad member is alive or dead and
		# there is no per-man WIA anywhere to read. Rather than invent a tracker nobody feeds,
		# the ward fills from the FIGHT: a firefight that killed men wounded more of them, at
		# roughly the real ratio. The men in those beds were never squad members the player
		# knew, which is why he never had to watch them get hit.
		# DELETE THIS DERIVATION the day allies gain a real wounded state, and read that instead.
		ward_wounded += lost * WIA_PER_KIA
	# An explicit count always wins over the derivation above, so a caller that DOES know
	# (a future wounded state, a scripted event) is authoritative without touching this.
	ward_wounded += int(result.get("friendly_wia", 0))
	ward_wounded = mini(ward_wounded, WARD_BEDS_MAX)
	# Log (trimmed).
	mission_log.append({
		"type": str(result.get("mission_type", "?")),
		"success": bool(result.get("success", false)),
		"kills": kills,
		"seed": int(result.get("seed", 0)),
	})
	if mission_log.size() > 40:
		mission_log = mission_log.slice(mission_log.size() - 40)
	save_campaign()


## Called by GameFlow when a mission starts. Everything written between here and
## commit_mission() stays in memory.
func begin_mission() -> void:
	_defer_saves = true
	_dirty = false


## Called at the debrief (or on abort). Flushes whatever the mission changed.
func commit_mission() -> void:
	_defer_saves = false
	if _dirty:
		_dirty = false
		save_campaign()


func save_campaign() -> void:
	if _defer_saves:
		_dirty = true
		return
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "version", SAVE_VERSION)
	cfg.set_value("campaign", "threat_level", threat_level)
	cfg.set_value("campaign", "threat_modifiers", threat_modifiers)
	cfg.set_value("campaign", "reputation", reputation)
	cfg.set_value("campaign", "roster", roster)
	cfg.set_value("campaign", "missions_played", missions_played)
	cfg.set_value("campaign", "mission_log", mission_log)
	cfg.set_value("campaign", "iron_man", iron_man)
	cfg.set_value("campaign", "player_data", player_data)
	cfg.set_value("campaign", "intel_points", intel_points)
	cfg.set_value("campaign", "collapsed_tunnels", collapsed_tunnels)
	cfg.set_value("campaign", "field_marks", field_marks)
	cfg.set_value("campaign", "pencil_marks", pencil_marks)
	cfg.set_value("campaign", "reported_marks", reported_marks)
	cfg.set_value("campaign", "lifetime_intel", lifetime_intel)
	cfg.set_value("campaign", "next_stash_at", next_stash_at)
	cfg.set_value("campaign", "ears_taken", ears_taken)
	cfg.set_value("campaign", "kia_total", kia_total)
	cfg.set_value("campaign", "ward_wounded", ward_wounded)
	cfg.set_value("campaign", "bags_unlifted", bags_unlifted)
	cfg.set_value("campaign", "pilots_recovered", pilots_recovered)
	cfg.set_value("campaign", "rack_condition", rack_condition)
	cfg.set_value("campaign", "depot_loss", depot_loss)
	var err: int = cfg.save(save_path)
	if err != OK:
		push_error("[SAVE] could not write %s (err %d) - campaign progress lost" % [save_path, err])


func load_campaign() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(save_path)
	if err != OK:
		# ERR_FILE_NOT_FOUND is the normal first-boot path. Anything else means the
		# file exists and is unreadable. Keep a copy before we overwrite it.
		if err != ERR_FILE_NOT_FOUND:
			var bak := save_path + ".bak"
			if FileAccess.file_exists(save_path):
				DirAccess.copy_absolute(save_path, bak)
			push_error("[SAVE] %s failed to load (err %d). Backed up to %s; starting fresh." % [save_path, err, bak])
		return

	var file_version: int = int(cfg.get_value("campaign", "version", 0))
	if file_version > SAVE_VERSION:
		push_error("[SAVE] %s is version %d, this build understands %d. Refusing to load rather than corrupt it." % [
			save_path, file_version, SAVE_VERSION])
		return
	if file_version < SAVE_VERSION:
		_migrate(cfg, file_version)
	threat_level = float(cfg.get_value("campaign", "threat_level", BASE_THREAT))
	threat_modifiers = cfg.get_value("campaign", "threat_modifiers", [])
	# Pre-ADR-032 saves banked this pool under "team_xp" - same points, new name.
	reputation = int(cfg.get_value("campaign", "reputation", cfg.get_value("campaign", "team_xp", 0)))
	roster = cfg.get_value("campaign", "roster", [])
	missions_played = int(cfg.get_value("campaign", "missions_played", 0))
	mission_log = cfg.get_value("campaign", "mission_log", [])
	iron_man = bool(cfg.get_value("campaign", "iron_man", false))
	player_data = cfg.get_value("campaign", "player_data", {"mos": "RIFLEMAN"})
	intel_points = int(cfg.get_value("campaign", "intel_points", 0))
	collapsed_tunnels = cfg.get_value("campaign", "collapsed_tunnels", []) as Array
	field_marks = cfg.get_value("campaign", "field_marks", []) as Array
	pencil_marks = cfg.get_value("campaign", "pencil_marks", []) as Array
	reported_marks = cfg.get_value("campaign", "reported_marks", []) as Array
	lifetime_intel = int(cfg.get_value("campaign", "lifetime_intel", 0))
	next_stash_at = int(cfg.get_value("campaign", "next_stash_at", 0))
	ears_taken = int(cfg.get_value("campaign", "ears_taken", 0))
	# Absent from a pre-2026-07-30 save, which is the correct answer for one: nobody was
	# counting, so the tour starts its bill at zero rather than inventing a past.
	kia_total = int(cfg.get_value("campaign", "kia_total", 0))
	ward_wounded = int(cfg.get_value("campaign", "ward_wounded", 0))
	bags_unlifted = int(cfg.get_value("campaign", "bags_unlifted", 0))
	pilots_recovered = int(cfg.get_value("campaign", "pilots_recovered", 0))
	rack_condition = cfg.get_value("campaign", "rack_condition", {}) as Dictionary
	depot_loss = _migrate_depot_loss(cfg.get_value("campaign", "depot_loss", {}) as Dictionary)
	# Persist a migrated save immediately - otherwise the migrate warning fires on
	# EVERY boot until the next natural save.
	if file_version < SAVE_VERSION:
		save_campaign()


## v0 (unversioned) had no `version` key and no sprite fields on the roster.
## Nothing structural changed, so v0 loads as-is. The branch exists so the NEXT
## shape change has somewhere to live instead of silently half-loading.
func _migrate(_cfg: ConfigFile, from_version: int) -> void:
	push_warning("[SAVE] migrating campaign save v%d -> v%d" % [from_version, SAVE_VERSION])


## SaveData contract (SaveManager slots). Mirrors exactly what the cfg persists,
## so the two stores can never disagree about what campaign state IS.
func to_dict() -> Dictionary:
	return {
		"threat_level": threat_level,
		"threat_modifiers": threat_modifiers.duplicate(true),
		"reputation": reputation,
		"roster": roster.duplicate(true),
		"missions_played": missions_played,
		"mission_log": mission_log.duplicate(true),
		"iron_man": iron_man,
		"player_data": player_data.duplicate(true),
		"intel_points": intel_points,
		"collapsed_tunnels": collapsed_tunnels,
		"field_marks": field_marks.duplicate(true),
		"pencil_marks": pencil_marks.duplicate(true),
		"rack_condition": rack_condition.duplicate(true),
		"depot_loss": depot_loss.duplicate(true),
		"kia_total": kia_total,
		"ward_wounded": ward_wounded,
		"bags_unlifted": bags_unlifted,
		"pilots_recovered": pilots_recovered,
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	threat_level = float(d.get("threat_level", BASE_THREAT))
	threat_modifiers = d.get("threat_modifiers", [])
	reputation = int(d.get("reputation", d.get("team_xp", 0)))
	roster = d.get("roster", [])
	missions_played = int(d.get("missions_played", 0))
	mission_log = d.get("mission_log", [])
	iron_man = bool(d.get("iron_man", false))
	player_data = d.get("player_data", {"mos": "RIFLEMAN"})
	intel_points = int(d.get("intel_points", 0))
	collapsed_tunnels = d.get("collapsed_tunnels", []) as Array
	# field_marks was absent from BOTH sides of this pair while being written to the
	# .cfg - a snapshot round trip silently dropped the player's whole intel layer.
	field_marks = d.get("field_marks", []) as Array
	pencil_marks = d.get("pencil_marks", []) as Array
	rack_condition = d.get("rack_condition", {}) as Dictionary
	depot_loss = _migrate_depot_loss(d.get("depot_loss", {}) as Dictionary)
	kia_total = int(d.get("kia_total", 0))
	ward_wounded = int(d.get("ward_wounded", 0))
	bags_unlifted = int(d.get("bags_unlifted", 0))
	pilots_recovered = int(d.get("pilots_recovered", 0))


func reset_campaign() -> void:
	# A wipe must hit the disk even if a mission is mid-flight (Iron Man death).
	_defer_saves = false
	_dirty = false
	threat_level = BASE_THREAT
	threat_modifiers = []
	reputation = 0
	roster = []
	missions_played = 0
	mission_log = []
	# iron_man is a PLAYER SETTING, not campaign progress - do NOT clear it here,
	# or an Iron Man death silently disables the very mode that caused the wipe.
	player_data = {"mos": "RIFLEMAN"}
	intel_points = 0
	collapsed_tunnels = []
	field_marks = []
	pencil_marks = []
	reported_marks = []
	lifetime_intel = 0
	next_stash_at = 0
	ears_taken = 0
	kia_total = 0
	bags_unlifted = 0
	pilots_recovered = 0
	# SEEDED, not zeroed - his ruling 2026-07-30: "we could have 1 to 2 wounded when the player
	# first appears". A brand-new tour with an EMPTY aid station reads as a war nobody is
	# fighting, and this is the fresh-player failure the standing law warns about. The men in
	# those first two beds were hurt before the player arrived, which is true of every war.
	ward_wounded = WARD_SEED_ON_NEW_TOUR
	rack_condition = {}
	depot_loss = {}
	save_campaign()


## A weapon never drawn is a fresh weapon.
func rack_condition_of(weapon_id: String) -> float:
	return float(rack_condition.get(weapon_id, 100.0))


func store_rack_condition(weapon_id: String, condition: float) -> void:
	rack_condition[weapon_id] = clampf(condition, 0.0, 100.0)
	save_campaign()


## Record a satchelled tunnel mouth so the next patrol finds it still collapsed.
func remember_collapsed_tunnel(world_pos: Vector3) -> void:
	var key := Vector3(roundf(world_pos.x), roundf(world_pos.y), roundf(world_pos.z))
	if not collapsed_tunnels.has(key):
		collapsed_tunnels.append(key)
		save_campaign()


## True if this mouth was blown on an earlier patrol. Tolerant to the metre so a
## re-generated world places the entrance close enough to still match.
func tunnel_is_collapsed(world_pos: Vector3) -> bool:
	for c in collapsed_tunnels:
		if (c as Vector3).distance_to(world_pos) < 3.0:
			return true
	return false
