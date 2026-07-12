## screenshot_runner.gd - boots a scene, waits for it to come alive, captures
## the viewport to PNG, quits. Remote-eyes tool: lets Caleb SEE the build from
## his phone. Target/output/camera via environment variables:
##   SHOT_TARGET  res:// scene path (default gore_lab)
##   SHOT_OUT     absolute output .png
##   SHOT_CAM     "overview" adds a high vantage camera; empty keeps the
##                scene's own camera
##   SHOT_FRAMES  frames to wait before capture (default 60)
## Run: godot --path . res://tools/screenshot_runner.tscn  (NOT headless -
## rendering needs a window)
extends Node


func _ready() -> void:
	var target: String = OS.get_environment("SHOT_TARGET")
	if target.is_empty():
		target = "res://scenes/levels/gore_lab.tscn"
	var out: String = OS.get_environment("SHOT_OUT")
	if out.is_empty():
		out = "shot.png"
	var frames: int = 60
	var frames_env: String = OS.get_environment("SHOT_FRAMES")
	if not frames_env.is_empty():
		frames = int(frames_env)

	var scene: Node = (load(target) as PackedScene).instantiate()
	add_child(scene)

	# Let the scene spawn its world (AI, vegetation, HUD)
	for i in range(frames):
		await get_tree().process_frame

	# SHOT_CAM: "overview" = high vantage; "x,y,z@tx,ty,tz" = free camera at
	# position looking at target (close-ups of one model, corner checks, ...).
	var cam_env: String = OS.get_environment("SHOT_CAM")
	if cam_env == "overview" or cam_env.contains("@"):
		var pos := Vector3(16.0, 10.0, 20.0)
		var aim := Vector3(0.0, 1.0, -2.0)
		if cam_env.contains("@"):
			var halves: PackedStringArray = cam_env.split("@")
			var p: PackedStringArray = halves[0].split(",")
			var t: PackedStringArray = halves[1].split(",")
			if p.size() == 3 and t.size() == 3:
				pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
				aim = Vector3(float(t[0]), float(t[1]), float(t[2]))
		var cam := Camera3D.new()
		add_child(cam)
		cam.global_position = pos
		cam.look_at(aim)
		cam.fov = 60.0
		cam.make_current()
		# Show the hitzone wireframes in the lab shot if the scene supports it
		if scene.get("_zones_visible") != null:
			scene.set("_zones_visible", true)
		for i in range(10):
			await get_tree().process_frame

	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(out)
	print("[SHOT] %s -> %s (err=%d)" % [target, out, err])
	get_tree().quit(0 if err == OK else 1)
