## probe_config.gd - is the new config LIVE at runtime, not just written to a file?
## Reads the settings back out of the running engine and confirms the classes the
## audit fixes introduced actually register.
##   godot --headless --path . -s res://tools/probe_config.gd
extends SceneTree

func _initialize() -> void:
	print("\n=== ENGINE (live values, read back from the running engine) ===")
	var phys: String = str(ProjectSettings.get_setting("physics/3d/physics_engine", "(default)"))
	print("  physics engine     : %s   %s" % [phys,
		"<-- JOLT IS LIVE" if phys.contains("Jolt") else "<-- STILL GODOT PHYSICS"])
	print("  physics server     : %s" % PhysicsServer3D.get_class())
	print("  interpolation      : %s" % str(ProjectSettings.get_setting("physics/common/physics_interpolation", false)))
	print("  scaling_3d mode    : %s (0=bilinear 1=FSR1 2=FSR2)" % str(ProjectSettings.get_setting("rendering/scaling_3d/mode", 0)))
	print("  scaling_3d scale   : %s" % str(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)))
	print("  mesh LOD threshold : %s px" % str(ProjectSettings.get_setting("rendering/mesh_lod/lod_change/threshold_pixels", 1.0)))
	print("  debanding          : %s" % str(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_debanding", false)))
	print("  max_fps            : %s" % str(ProjectSettings.get_setting("application/run/max_fps", 0)))

	print("\n=== AUDIT-FIX CLASSES REGISTER ===")
	for cls in ["PauseMenu", "MissionState", "GameFlow"]:
		print("  %-16s %s" % [cls, "OK" if ClassDB.class_exists(cls) or _script_class(cls) else "MISSING"])

	print("\n=== CONTACT LEDGER (ADR-006) ===")
	var ms := MissionState.new()
	ms.register_group(101)
	ms.register_group(202)
	ms.register_group(303)
	ms.report_detected(202)
	ms.report_detected(202)   # same group twice = still one contact
	var r: Dictionary = ms.build_result(true, "")
	print("  3 groups, 1 went loud -> detected=%d avoided=%d" % [
		int(r.contacts_detected), int(r.contacts_avoided)])
	var score: int = DebriefScreen.compute_score({
		"kills": 9, "damage_taken": 0,
		"time_sec": 800.0, "success": true, "emergency_exfil": false, "shots": 200,
		"contacts_avoided": int(r.contacts_avoided), "contacts_detected": int(r.contacts_detected),
	})
	print("  score for 9 kills + that ledger = %d" % score)
	print("  (kills pay NOTHING: 2x25 avoided - 1x25 detected + 50 fast = 75)")
	quit(0)


func _script_class(n: String) -> bool:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == n:
			return true
	return false
