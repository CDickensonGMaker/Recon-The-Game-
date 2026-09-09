class_name InteriorPropDial
extends Node

## HIS EYES DECIDE THE DRAW DISTANCE. This is the dial for it.
##
## InteriorPropFold sets each interior-prop MultiMesh to the distance at which that prop covers
## two rendered rows. That number is arithmetic, not taste, and how far into a compound you
## should be able to see a cot is taste. The Summoner's standing law is "no numeric gate - my
## eyes decide", and a headless session cannot judge this at all, so the choice is wired to a
## key instead of guessed at and shipped silent.
##
## F11 cycles the interior-prop draw distance. It prints what it just selected, every time.

const CYCLE_KEY: Key = KEY_F11

## name, multiplier on each prop's own measured range.
const STEPS: Array = [
	["MEASURED (2 px, the default)", 1.0],
	["NEAR (about the retired 40 m)", 0.0],
	["FAR (1.5x measured)", 1.5],
]

var _mmis: Array[MultiMeshInstance3D] = []
var _base: Array[float] = []
var _step: int = 0


func setup(mmis: Array[MultiMeshInstance3D], base: Array[float]) -> void:
	_mmis = mmis
	_base = base
	print("[FSB] interior prop draw distance: press F11 to cycle (%s)" % _step_name())


func _step_name() -> String:
	return String((STEPS[_step] as Array)[0])


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != CYCLE_KEY:
		return
	_step = (_step + 1) % STEPS.size()
	var mult: float = float((STEPS[_step] as Array)[1])
	var near_m: float = 1.0e9
	var far_m: float = 0.0
	for i in _mmis.size():
		var mmi: MultiMeshInstance3D = _mmis[i]
		if not is_instance_valid(mmi):
			continue
		## A multiplier of 0 means "the retired flat 40 m", not "never draw" - the floor in
		## InteriorPropFold is what makes that the same 40 m the game shipped this morning.
		var r: float = maxf(InteriorPropFold.MIN_RANGE_M, _base[i] * mult)
		mmi.visibility_range_end = r
		near_m = minf(near_m, r)
		far_m = maxf(far_m, r)
	print("[FSB] interior prop draw distance -> %s | %.0f-%.0fm" % [_step_name(), near_m, far_m])
	get_viewport().set_input_as_handled()
