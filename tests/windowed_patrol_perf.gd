## windowed_patrol_perf.gd - ONE brief windowed sample of the populated patrol
## world at NATIVE scale, current renderer. Boots the real GameFlow entry,
## settles, samples ~12s, prints the row, quits itself. No toggles, no claims
## beyond this scene.
extends Node

const OP_SEED: int = 47225
const WARMUP_S: float = 8.0
const SAMPLE_S: float = 20.0
## Fewer draw calls than this in a second and the window was not drawing the world.
const MIN_DRAWS: int = 100


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(OP_SEED, "OPERATION PERF ROW")
	# THE WINDOW IS INERT TO KEYS (2026-09-11). GameFlow._ready puts the title splash up and its
	# "any key" dismiss runs show_menu(), which tears the sampled world down - one key on his
	# screen and the row reads a menu: draws=11, fps=360, "every time i move the game goes back
	# to the main menu". The splash has no business in a measurement; it goes.
	for c in flow.get_children():
		var scr: Script = c.get_script() as Script
		if scr != null and scr.resource_path.ends_with("title_splash.gd"):
			c.queue_free()
	var waited := 0.0
	while waited < 180.0:
		if flow.world != null and flow.world.is_world_ready and flow.world.player != null:
			break
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if flow.world == null:
		print("[PERFROW] FAIL: world never ready")
		get_tree().quit(1)
		return
	get_viewport().scaling_3d_scale = 1.0
	await get_tree().create_timer(WARMUP_S).timeout
	# ONE SECOND AT A TIME, and a second in which the window drew nothing is not a sample
	# (2026-09-11: two of four renderer runs reported draws=5 and draws=11 at the end of their
	# sample with fps of 1.2 and 52.7 - the window had been covered or minimised on his screen
	# while the harness counted, and one number was the loop idling, the other a viewport with
	# nothing in it). Each second prints its own row so a reader can see WHICH seconds were
	# blind, and the headline row is the mean of the seconds that drew the world.
	var frames: int = 0
	var t0: float = Time.get_ticks_msec() / 1000.0
	var gpu_accum: float = 0.0
	var gpu_samples: int = 0
	var elapsed: float = 0.0
	var sec_frames: int = 0
	var sec_t0: float = t0
	var good_fps: Array[float] = []
	var blind: int = 0
	var draws_last: int = 0
	var prims_last: int = 0
	while elapsed < SAMPLE_S:
		await get_tree().process_frame
		frames += 1
		sec_frames += 1
		var g: float = float(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		if g > 0.0:
			gpu_accum += g
			gpu_samples += 1
		elapsed = Time.get_ticks_msec() / 1000.0 - t0
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - sec_t0 >= 1.0:
			var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var prims: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			var sec_fps: float = float(sec_frames) / (now - sec_t0)
			var drew: bool = draws >= MIN_DRAWS
			print("[PERFSEC] %s | fps=%.1f | draws=%d | prims=%d%s" % [
				RenderingServer.get_current_rendering_method(), sec_fps, draws, prims,
				"" if drew else "  <- BLIND (window not drawing the world), excluded"])
			if drew:
				good_fps.append(sec_fps)
				draws_last = draws
				prims_last = prims
			else:
				blind += 1
			sec_frames = 0
			sec_t0 = now
	var fps: float = float(frames) / elapsed
	if not good_fps.is_empty():
		var sum: float = 0.0
		for v in good_fps:
			sum += v
		fps = sum / float(good_fps.size())
	var gpu_ms: float = (gpu_accum / float(gpu_samples)) if gpu_samples > 0 else -1.0
	if blind > 0:
		print("[PERFROW] %d blind second(s) excluded from the row below" % blind)
	if good_fps.is_empty():
		print("[PERFROW] FAIL: every sampled second was blind - the window never drew the world")
	## The renderer is read from the RENDERING SERVER, not from ProjectSettings. Godot strips
	## `rendering/renderer/rendering_method` on save when it equals the desktop default, so the
	## setting reads "forward_plus" whether or not that is what is running - it agrees with
	## reality by luck. `get_current_rendering_method()` is what the process actually booted.
	print("[PERFROW] patrol_world seed=%d | scale=%.2f | renderer=%s/%s | fps=%.1f | gpu_ms=%.2f | draws=%d | prims=%d" % [
		OP_SEED, get_viewport().scaling_3d_scale,
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		fps, gpu_ms, draws_last, prims_last])
	get_tree().quit(0)
