## test_squad_identity.gd - Summoner's decree 2026-07-25: real names first,
## roles in plain words, nicknames EARNED after prolonged tours - and a grunt
## never gets one. Certifies the display layer never leaks a raw MOS key.
## Run: godot --headless --path . res://tests/test_squad_identity.tscn
extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	var failures: int = 0

	# --- 1. one role-display map: MOS keys never print raw --------------------
	if SquadRoster.mos_display("RTO") != "RADIO MAN":
		print("FAIL: mos_display(RTO) = '%s', want RADIO MAN" % SquadRoster.mos_display("RTO"))
		failures += 1
	if SquadRoster.mos_display("MG") != "MACHINE GUNNER" \
			or SquadRoster.mos_display("POINTMAN") != "POINT MAN":
		print("FAIL: MG/POINTMAN display words are wrong")
		failures += 1
	if SquadRoster.mos_display("SAPPER") != "SAPPER":
		print("FAIL: unknown MOS must pass through raw, got '%s'" % SquadRoster.mos_display("SAPPER"))
		failures += 1

	# --- 2. a new man has NO nickname -----------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rookie: Dictionary = SquadRoster.generate_member(rng, "MEDIC")
	if str(rookie.get("nick", "?")) != "":
		print("FAIL: fresh recruit spawns with nick '%s', want empty" % str(rookie.get("nick")))
		failures += 1

	# --- 3. rookie goes by his surname ----------------------------------------
	var doc := {"name": "EARL MERCER", "mos": "MEDIC", "missions": 0}
	if SquadRoster.call_name(doc) != "MERCER":
		print("FAIL: rookie call_name = '%s', want MERCER" % SquadRoster.call_name(doc))
		failures += 1

	# --- 4. the tour mark christens him, exactly once --------------------------
	doc["missions"] = SquadRoster.NICK_MISSIONS
	if not SquadRoster.christen(doc):
		print("FAIL: medic at %d missions was not christened" % SquadRoster.NICK_MISSIONS)
		failures += 1
	if str(doc.get("nick", "")) != "DOC" or SquadRoster.call_name(doc) != "DOC":
		print("FAIL: christened medic reads '%s'/'%s', want DOC" \
			% [str(doc.get("nick", "")), SquadRoster.call_name(doc)])
		failures += 1
	if not bool(doc.get("christened", false)):
		print("FAIL: christening did not set the flag")
		failures += 1
	if SquadRoster.christen(doc):
		print("FAIL: christen fired twice - the toast would repeat every patrol")
		failures += 1

	# --- 5. a grunt NEVER gets one ---------------------------------------------
	var grunt := {"name": "OTIS KILGORE", "mos": "RIFLEMAN", "missions": 99}
	if SquadRoster.nick_earned(grunt) or SquadRoster.christen(grunt):
		print("FAIL: a rifleman earned a nickname")
		failures += 1
	if SquadRoster.call_name(grunt) != "KILGORE":
		print("FAIL: 99-mission rifleman call_name = '%s', want KILGORE" % SquadRoster.call_name(grunt))
		failures += 1

	# --- 6. legacy saves migrate: RADIO -> SPARKS, GRUNT -> nothing -------------
	var old_rto := {"name": "SAL DUFFY", "nick": "RADIO", "mos": "RTO", "missions": 5}
	SquadRoster.migrate_member(old_rto)
	if str(old_rto.get("nick", "")) != "SPARKS" or SquadRoster.call_name(old_rto) != "SPARKS":
		print("FAIL: legacy RADIO nick reads '%s', want SPARKS" % str(old_rto.get("nick", "")))
		failures += 1
	if not bool(old_rto.get("christened", false)):
		print("FAIL: veteran migration must set christened quietly (no retro-toast)")
		failures += 1
	var old_grunt := {"name": "NED PHELPS", "nick": "GRUNT", "mos": "RIFLEMAN", "missions": 2}
	SquadRoster.migrate_member(old_grunt)
	if str(old_grunt.get("nick", "?")) != "":
		print("FAIL: legacy GRUNT nick survived migration as '%s'" % str(old_grunt.get("nick")))
		failures += 1

	# --- 7. bench rigs with a bare nick and no name still resolve ---------------
	var rig := {"nick": "SPARKS", "mos": "RTO"}
	if SquadRoster.call_name(rig) != "SPARKS":
		print("FAIL: nameless bench rig call_name = '%s', want SPARKS" % SquadRoster.call_name(rig))
		failures += 1
	if SquadRoster.call_name({}) != "SOLDIER":
		print("FAIL: empty member dict must fall back to SOLDIER")
		failures += 1

	# --- 8. player-facing build paths never print the raw key 'RTO' -------------
	var vet_rto := {"name": "SAL DUFFY", "mos": "RTO", "missions": 5, "nick": "SPARKS"}
	for line: String in [SquadNameplate.role_line(vet_rto), MissionHUD.squad_role_row(vet_rto)]:
		if line.contains("RTO"):
			print("FAIL: readout line '%s' leaks the raw MOS key" % line)
			failures += 1
		if not line.contains("RADIO MAN"):
			print("FAIL: readout line '%s' does not say RADIO MAN" % line)
			failures += 1
	if not MissionHUD.squad_row(vet_rto, "OK").contains("DUFFY"):
		print("FAIL: squad strip lead line '%s' is not his name" % MissionHUD.squad_row(vet_rto, "OK"))
		failures += 1
	# (RadioMenu retired 2026-08-04 - the handset passes instantly on [F]; no
	# menu labels left to leak.)

	# --- 9. drift guard: every roster screen routes through the one map ----------
	for path: String in ["res://scripts/ui/screens/barracks.gd",
			"res://scripts/ui/mission_hud.gd", "res://scripts/ui/squad_nameplate.gd"]:
		if not FileAccess.get_file_as_string(path).contains("mos_display("):
			print("FAIL: %s prints a role without mos_display - it can drift" % path)
			failures += 1
	if not FileAccess.get_file_as_string("res://scripts/squad/squad_system.gd").contains("christen("):
		print("FAIL: nothing christens a man when his missions tick over")
		failures += 1

	if failures == 0:
		print("PASS: names lead, roles are words, nicknames are earned (grunts never)")
	else:
		print("FAIL: squad identity probe had %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


