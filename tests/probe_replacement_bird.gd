## probe_replacement_bird.gd - fresh-parses every script the replacement bird touches and
## exercises the 4/8 delivery edge without a world.
## Run: godot --headless --path . res://tests/probe_replacement_bird.tscn
extends Node

const TOUCHED: Array[String] = [
	"res://scripts/squad/squad_roster.gd",
	"res://scripts/squad/squad_system.gd",
	"res://scripts/vehicles/heli_lift.gd",
	"res://scripts/ai/air_traffic.gd",
	"res://scripts/missions/field_director.gd",
	"res://scripts/ui/screens/debrief.gd",
	"res://scripts/ui/screens/barracks.gd",
	"res://scripts/ui/screens/pause_menu.gd",
	"res://scripts/world/site_planner.gd",
	"res://scripts/world/destructible.gd",
]


func _ready() -> void:
	print("=== REPLACEMENT BIRD PROBE ===")
	var fails: int = 0
	for path in TOUCHED:
		var sc: GDScript = ResourceLoader.load(path, "GDScript",
			ResourceLoader.CACHE_MODE_IGNORE_DEEP) as GDScript
		if sc == null or not sc.can_instantiate():
			print("[FAIL] %s did not fresh-parse" % path)
			fails += 1
		else:
			print("[ok]   %s" % path)

	# THE 4/8 EDGE, measured. `n` is what one bird hands back for a given hole.
	print("--- delivery band (floor %d, squad %d) ---"
		% [FieldDirector.REPLACEMENT_FLOOR, SquadRoster.SQUAD_SIZE])
	for short in range(0, SquadRoster.SQUAD_SIZE + 1):
		var n: int = short
		if short > FieldDirector.REPLACEMENT_FLOOR:
			var rng := RandomNumberGenerator.new()
			rng.seed = short
			n = rng.randi_range(FieldDirector.REPLACEMENT_FLOOR, short)
		if n > short:
			print("[FAIL] %d vacancies -> %d men (overfills the squad)" % [short, n])
			fails += 1
		if short >= FieldDirector.REPLACEMENT_FLOOR and n < FieldDirector.REPLACEMENT_FLOOR:
			print("[FAIL] %d vacancies -> %d men (below the floor)" % [short, n])
			fails += 1
		print("  %d short -> bird brings %d" % [short, n])

	# The roster no longer refills itself.
	CampaignState.roster = []
	var first: Array = SquadRoster.ensure_roster(1)
	print("empty roster -> ensure_roster gave %d (new tour)" % first.size())
	if first.size() != SquadRoster.SQUAD_SIZE:
		print("[FAIL] a new tour must hand over a full squad")
		fails += 1
	for i in range(6):
		(CampaignState.roster[i] as Dictionary)["alive"] = false
	var after: Array = SquadRoster.ensure_roster(2)
	print("6 dead -> ensure_roster gave %d, vacancies %d"
		% [after.size(), SquadRoster.vacancies()])
	if after.size() != 2 or SquadRoster.vacancies() != 6:
		print("[FAIL] the free refill is still alive")
		fails += 1
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var cut: Array = SquadRoster.draft_replacements(rng2, 4)
	var moss: Array[String] = []
	for m in cut:
		moss.append(str((m as Dictionary).get("mos", "")))
		if int((m as Dictionary).get("missions", 0)) != 0:
			print("[FAIL] a replacement arrived with a tour behind him")
			fails += 1
	print("draft of 4 -> %s (all PVT/green)" % str(moss))

	print("=== %s ===" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit(0 if fails == 0 else 1)
