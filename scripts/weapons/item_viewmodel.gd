class_name ItemViewmodel
extends Node3D

## The FP viewmodel for a NON-GUN item: grenade, bandage, claymore, radio handset, knife.
##
## Everything that is not a gun used to be a bare `Node3D` toggled `visible` — no
## AnimationPlayer lookup, no clip playback, no lens. `grenade_handler.gd` and
## `health_system.gd` each did their own version of that, and `claymore.gd` had no
## viewmodel path at all, so a perfectly authored GLB would render in bind pose and never
## move. This is the one driver they all share (ADR-023 — not a fourth copy).
##
## THE VOCABULARY IS EXACTLY THREE CLIPS, and the names are the ENGINE's, not the item's
## (production/research/equipment_viewmodels/STOCK_CLIP_SOURCES.md):
##   `rifle_idle`     the held pose (loops). weapon_holder.gd:934 asks for this literal
##                    string on every viewmodel, gun or not — an item whose idle is called
##                    anything else plays NOTHING and renders in bind pose.
##   `charge_handle`  the DRAW. weapon_holder.gd:939 already auto-plays this on equip, so
##                    the Half-Life/Counter-Strike deploy is free.
##   `fire`           the item's action: the plant, the wrap, the throw.
## There is no `equip` and no `holster` — SPEC.md asks for both and is wrong on that point.
## Holstering plays nothing anywhere in this engine; giving it a clip is new code, not new
## art, so do not author one expecting it to run.
##
## An item may name EXTRA action clips (the grenade splits pin-pull from throw) — play them
## by name through `play_action()`. Anything named must also be in the manifest entry or
## the validator fails the export, which is the point.

const CLIP_IDLE: StringName = &"rifle_idle"
const CLIP_DRAW: StringName = &"charge_handle"
const CLIP_ACTION: StringName = &"fire"

## Items render through the same per-weapon lens as guns (ADR-034). They carry no .tres, so
## this is their `viewmodel_fov`: the base, i.e. no magnification.
const ITEM_FOV: float = 75.0

var _anim: AnimationPlayer = null
var _meshes: Array[MeshInstance3D] = []
var _model: Node3D = null
var _camera: Camera3D = null
var _pending_idle: bool = false
var _stow_after: bool = false


## Build one under `parent` (normally the camera) from a packed scene path. Returns null if
## the scene is missing, so a caller can keep its own fallback.
static func create(parent: Node, scene_path: String, at: Vector3,
		cam: Camera3D = null) -> ItemViewmodel:
	if parent == null or scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	var vm := ItemViewmodel.new()
	vm.name = "ItemViewmodel"
	parent.add_child(vm)
	vm.position = at
	vm.add_child(model)
	vm._model = model
	vm._camera = cam
	vm._anim = vm._find_anim(model)
	if ViewmodelLens.ENABLED:
		vm._meshes = ViewmodelLens.apply(model)
		ViewmodelLens.set_fov(vm._meshes, ITEM_FOV)
	vm.visible = false
	return vm


func has_clips() -> bool:
	return _anim != null


func has_clip(name: StringName) -> bool:
	return _anim != null and _anim.has_animation(String(name))


## Bring the item up: draw, then settle into the idle when the draw finishes. With no draw
## clip authored it goes straight to idle, so an un-animated GLB still shows correctly.
func deploy() -> void:
	visible = true
	if _anim == null:
		return
	_anim.speed_scale = 1.0
	if not has_clip(CLIP_DRAW):
		_play_idle()
		return
	_pending_idle = true
	_anim.play(String(CLIP_DRAW))
	if not _anim.animation_finished.is_connected(_on_finished):
		_anim.animation_finished.connect(_on_finished)


## Put it away. Nothing in this engine plays a holster clip; this is the honest version of
## that - it hides. Kept as a named verb so the call sites read symmetrically and so the
## day a holster clip is wired there is one place to do it.
func stow() -> void:
	_pending_idle = false
	_stow_after = false
	visible = false
	if _anim != null and _anim.is_playing():
		_anim.stop()


## Play an action once, then fall back to the idle. Returns false when the clip is not
## authored, so the caller can decide whether that matters.
func play_action(clip: StringName = CLIP_ACTION) -> bool:
	if _anim == null or not has_clip(clip):
		return false
	_anim.speed_scale = 1.0
	_pending_idle = true
	_anim.play(String(clip))
	if not _anim.animation_finished.is_connected(_on_finished):
		_anim.animation_finished.connect(_on_finished)
	return true


## Stretch a one-shot to a gameplay duration, the way weapon_holder times a reload to its
## .tres timer. An item has no .tres, so the GAMEPLAY clock is the authority and the clip
## is scaled to it - never the other way round.
func play_action_over(clip: StringName, duration_s: float) -> bool:
	if _anim == null or not has_clip(clip) or duration_s <= 0.01:
		return play_action(clip)
	var len: float = _anim.get_animation(String(clip)).length
	_pending_idle = true
	_anim.speed_scale = len / maxf(0.05, duration_s)
	_anim.play(String(clip))
	if not _anim.animation_finished.is_connected(_on_finished):
		_anim.animation_finished.connect(_on_finished)
	return true


## Play an action and PUT IT AWAY when it finishes, instead of settling to idle. This is
## the throw: the grenade has left the hand, so returning to a held-grenade idle would
## show one that is not there. Falls back to an immediate stow when the clip is missing.
func play_action_then_stow(clip: StringName = CLIP_ACTION) -> void:
	if _anim == null or not has_clip(clip):
		stow()
		return
	_pending_idle = false
	_stow_after = true
	_anim.speed_scale = 1.0
	_anim.play(String(clip))
	if not _anim.animation_finished.is_connected(_on_finished):
		_anim.animation_finished.connect(_on_finished)


func _play_idle() -> void:
	if _anim == null or not has_clip(CLIP_IDLE):
		return
	_anim.speed_scale = 1.0
	_anim.play(String(CLIP_IDLE))


func _on_finished(_name: StringName) -> void:
	if _stow_after:
		_stow_after = false
		stow()
		return
	if not _pending_idle:
		return
	_pending_idle = false
	_anim.speed_scale = 1.0
	_play_idle()


## Keep the lens honest while the player ADSes or the camera FOV moves.
func _process(_delta: float) -> void:
	if not visible or not ViewmodelLens.ENABLED or _meshes.is_empty() or _camera == null:
		return
	ViewmodelLens.set_fov(_meshes, ViewmodelLens.effective_fov(ITEM_FOV, _camera.fov))


## The exported GLB puts its AnimationPlayer somewhere under the scene root; find it rather
## than assuming a path, because the wrapper .tscn layout is the author's choice.
func _find_anim(root: Node) -> AnimationPlayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			return n as AnimationPlayer
		for c in n.get_children():
			stack.append(c)
	return null
