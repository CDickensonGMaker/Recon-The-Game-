## frame_sentinel.gd - the two bookends that let StallLedger measure SCRIPT time honestly.
##
## Godot's `TIME_PROCESS` / `TIME_PHYSICS_PROCESS` cannot answer "how long did our own
## code take", because main.cpp's timed spans also contain RenderingServer::sync/draw,
## the navigation servers and Jolt's PhysicsServer3D::step (see stall_ledger.gd's header).
##
## The SceneTree runs a frame's callbacks in `process_priority` order (lowest value
## first). Two sentinels, one pinned to the front of the order and one to the back,
## therefore bracket every other node's _process / _physics_process in the main process
## group. The span between them IS the script time, and the gap between that span and the
## Performance monitor is everything the engine did outside our code.
##
## KNOWN LIMIT, stated so nobody over-reads the number: a node placed in its own
## `process_thread_group` runs outside this bracket and will not be counted. The project
## uses no thread groups today; if one is ever added, this instrument silently under-reads
## and the comment must be corrected with it.
class_name FrameSentinel
extends Node

const FRONT: int = -100000
const BACK: int = 100000
const GROUP: StringName = &"stall_sentinel"

## true = the opening bookend, false = the closing one.
var _is_front: bool = false


## ONE way to arm the instrument, so two hosts cannot install two overlapping pairs (a
## second front sentinel overwrites the first's t0 and a second back sentinel re-closes the
## same span, which inflates every span it reports). Idempotent by tree state, not by a
## static flag, so a scene reload that frees the old host can re-arm.
static func install(host: Node) -> void:
	if host.get_tree() != null and not host.get_tree().get_nodes_in_group(GROUP).is_empty():
		return
	StallLedger.enable()
	host.add_child(make(true))
	host.add_child(make(false))


static func make(front: bool) -> FrameSentinel:
	var s := FrameSentinel.new()
	s._is_front = front
	s.name = "StallSentinelFront" if front else "StallSentinelBack"
	s.process_priority = FRONT if front else BACK
	s.process_physics_priority = FRONT if front else BACK
	## Must keep ticking through pause, or a paused frame silently drops out of the span.
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	s.add_to_group(GROUP)
	return s


## The property is `process_physics_priority`, NOT `physics_process_priority` - the wrong
## name is a parse error, this script then never compiles, and a dead instrument reports
## a confident 0.00ms that reads exactly like a frame which cost nothing. The standing
## headless boot check does not cover it: nothing on the boot path loads this file. That
## is why processing is asked for out loud here and why StallLedger.report() shouts
## INSTRUMENT FAILED instead of printing zeros.
func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	print("[STALL] sentinel %s live (process=%s physics=%s prio=%d/%d)"
		% [name, is_processing(), is_physics_processing(),
			process_priority, process_physics_priority])


func _process(_delta: float) -> void:
	if _is_front:
		StallLedger.idle_frame_begin()
		StallLedger.mark("<front sentinel>")
	else:
		StallLedger.idle_frame_end()


## ---------- THE MARKS ----------
## A FrameMark is a priority-0 node placed as the FIRST child of a subtree. The SceneTree
## runs equal-priority nodes in tree order, parent before children, so the mark fires when
## the tree ENTERS that subtree - everything since the previous mark is the subtree before
## it, late-added children included (they are appended after the mark, inside their own
## parent, and finish before the next sibling's mark). Installed under every child of the
## root and of the current scene, and refreshed each window so a subtree built after boot
## gets one too. Costs one static call per mark per frame.
const MARK_GROUP: StringName = &"stall_mark"
const MARK_DEPTH: int = 2


static func refresh_marks(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	_mark_children(tree.root, 1)


static func _mark_children(parent: Node, depth: int) -> void:
	for c in parent.get_children():
		if c is FrameSentinel or c.is_in_group(MARK_GROUP):
			continue
		var has: bool = c.get_child_count() > 0 and (c.get_child(0) as Node).is_in_group(MARK_GROUP)
		if not has:
			var m := Mark.new()
			# Name + script, because a script-made node is "@Node@5" and that names nothing.
			var scr: Script = c.get_script() as Script
			m.label = String(c.name) + ("" if scr == null else "[" + scr.resource_path.get_file() + "]")
			m.name = "StallMark_" + String(c.name)
			m.add_to_group(MARK_GROUP)
			m.process_mode = Node.PROCESS_MODE_ALWAYS
			c.add_child(m)
			c.move_child(m, 0)
		if depth < MARK_DEPTH:
			_mark_children(c, depth + 1)


func _physics_process(_delta: float) -> void:
	if _is_front:
		StallLedger.physics_frame_begin()
	else:
		StallLedger.physics_frame_end()


## One clock stamp as the SceneTree enters a subtree. An inner class, not a class_name: a
## headless run does not rescan the global class cache, so a new class_name is a parse
## error everywhere until the editor has been opened once.
class Mark extends Node:
	var label: String = ""

	func _ready() -> void:
		set_process(true)

	func _process(_delta: float) -> void:
		StallLedger.mark(label)
