## probe_gun_streams.gd - what does the player ACTUALLY hear per weapon?
## Reports the resolved stream resource_path for every weapon .tres, so a silent
## fall-through to the shot_rifle class bank is visible instead of merely audible.
## Run: godot --path . res://tests/probe_gun_streams.tscn
extends Node3D


func _ready() -> void:
	await get_tree().process_frame
	print("PROBE headless=%s driver=%s" % [DisplayServer.get_name(), AudioServer.get_driver_name()])

	var dir := DirAccess.open("res://data/weapons")
	var ids: PackedStringArray = []
	if dir:
		for f in dir.get_files():
			if f.ends_with(".tres"):
				ids.append(f.get_basename())
	ids.sort()

	print("%-14s %-9s %-42s %s" % ["weapon", "verdict", "near stream", "dist/mech"])
	for id in ids:
		var wd: WeaponData = load("res://data/weapons/%s.tres" % id) as WeaponData
		if wd == null:
			print("%-14s LOAD-FAIL" % id)
			continue
		AudioManager.play_shot_player(wd)
		var near: AudioStream = AudioManager.get("_p_near").stream
		var mech: AudioStream = AudioManager.get("_p_mech").stream
		var np: String = near.resource_path if near else "<null>"
		var mp: String = mech.resource_path if mech else "<null>"
		var verdict := "OK"
		if np == "<null>":
			verdict = "SILENT"
		elif np.contains("/shot_"):
			verdict = "FALLBACK"          # the old 22kHz class bank
		elif not np.contains("fire_%s_" % wd.id):
			verdict = "WRONG-ID"
		print("%-14s %-9s %-42s %s" % [wd.id, verdict, np.get_file(), mp.get_file()])

	print("PROBE done")
	get_tree().quit()
