## windowed_patrol_perf.gd - ONE brief windowed sample of the populated patrol
## world at NATIVE scale, current renderer. Boots the real GameFlow entry,
## settles, samples ~12s, prints the row, quits itself. No toggles, no claims
## beyond this scene.
extends Node

const OP_SEED: int = 47225
const WARMUP_S: float = 8.0
const SAMPLE_S: float = 12.0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var flow := GameFlow.new()
	add_child(flow)
	await get_tree().process_frame
	flow._begin_operation(OP_SEED, "OPERATION PERF ROW")
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
	var frames: int = 0
	var t0: float = Time.get_ticks_msec() / 1000.0
	var gpu_accum: float = 0.0
	var gpu_samples: int = 0
	var elapsed: float = 0.0
	while elapsed < SAMPLE_S:
		await get_tree().process_frame
		frames += 1
		var g: float = float(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		if g > 0.0:
			gpu_accum += g
			gpu_samples += 1
		elapsed = Time.get_ticks_msec() / 1000.0 - t0
	var fps: float = float(frames) / elapsed
	var gpu_ms: float = (gpu_accum / float(gpu_samples)) if gpu_samples > 0 else -1.0
	print("[PERFROW] patrol_world seed=%d | scale=%.2f | renderer=%s | fps=%.1f | gpu_ms=%.2f | draws=%d | prims=%d" % [
		OP_SEED, get_viewport().scaling_3d_scale,
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		fps, gpu_ms,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit(0)
