## test_perf_timebase.gd - the time-base contract for the live profiling HUD.
##
## The overlay used to print `TIME_PROCESS + TIME_PHYSICS_PROCESS` as "CPU ms" and label the
## frame CPU-BOUND or GPU-BOUND from that sum. Both monitors are one-second bucket MAXIMA
## (main.cpp: `process_max = MAX(process_ticks, process_max)`), they need not come from the
## same frame, and TIME_PROCESS's span contains RenderingServer::sync/draw - so the sum was
## not a quantity and the verdict was unsupportable. This probe fails the build if either
## comes back.
##
## Nothing on the headless boot path loads arena_perf_overlay.gd, frame_sentinel.gd or
## stall_ledger.gd, so `--quit-after` cannot catch a parse error in them either. Loading
## them here is half the point.
extends Node

var _fails: PackedStringArray = []
var _checks: int = 0


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)


func _ready() -> void:
	await get_tree().process_frame

	# 1. The sentinels arm, and they are idempotent by tree state.
	_ok(not StallLedger.armed(), "StallLedger reported armed before any sentinel ticked")
	FrameSentinel.install(self)
	FrameSentinel.install(self)
	var sentinels: int = get_tree().get_nodes_in_group(FrameSentinel.GROUP).size()
	_ok(sentinels == 2, "expected exactly 2 sentinels after a double install, got %d" % sentinels)

	for i in 5:
		await get_tree().process_frame
		await get_tree().physics_frame

	_ok(StallLedger.armed(), "sentinels ticked but StallLedger.armed() stayed false")
	_ok(StallLedger.last_idle_ms() > 0.0, "last_idle_ms() is 0 after 5 idle frames")
	_ok(StallLedger.last_phys_ms() > 0.0, "last_phys_ms() is 0 after 5 physics frames")

	# 2. The overlay's readout obeys the time-base contract.
	var overlay := ArenaPerfOverlay.new()
	add_child(overlay)
	for i in 3:
		await get_tree().process_frame
	var label: Label = null
	for c: Node in overlay.get_children():
		if c is Label:
			label = c as Label
	_ok(label != null, "overlay built no Label to read")
	var txt: String = label.text if label != null else ""

	_ok(not txt.contains("CPU-BOUND"),
		"overlay printed a CPU-BOUND verdict - it cannot prove which cpu worker holds a frame")
	_ok(not txt.contains("GPU-BOUND"),
		"overlay printed GPU-BOUND - the supportable claim is saturation share, not boundness")
	_ok(txt.contains("1s MAXIMA"),
		"overlay printed the Performance monitors without saying they are 1s bucket maxima")
	# Under the dummy renderer the driver timer is silent, and the overlay must say so
	# rather than derive a number from the monitors the way the old version did.
	_ok(txt.contains("BOUND-NESS UNPROVEN"),
		"driver GPU timer is silent here and the overlay did not say bound-ness is unproven")
	_ok(not txt.contains("ai/agents"),
		"the fabricated `ai/agents` remainder (bucket-max minus per-frame spans) is back")

	overlay.queue_free()

	# 3. The shipped printer shares the ONE sentinel pair. It attaches deep inside
	# GameFlow.enter_hub, so a --quit-after boot never loads it and a parse error in it is
	# invisible to the standing headless check. Instantiating it here is that check.
	var printer := FpsPrinter.new()
	add_child(printer)
	await get_tree().process_frame
	var after: int = get_tree().get_nodes_in_group(FrameSentinel.GROUP).size()
	_ok(after == 2, "FpsPrinter installed a second sentinel pair - spans would double-close (got %d)" % after)
	printer.queue_free()
	await get_tree().process_frame

	if _fails.is_empty():
		print("[TEST perf_timebase] PASS - %d checks" % _checks)
	else:
		for f: String in _fails:
			printerr("[TEST perf_timebase] FAIL: %s" % f)
		printerr("[TEST perf_timebase] FAIL - %d of %d checks failed" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)
