## The armorer's bench: the only place a rifle gets fully cleaned (ADR-018, Summoner's
## decree 2026-07-13). Weapon condition persists across missions; hold [interact] here
## for BENCH_SECONDS to take it back to 100. It cannot be done in the field - out there
## a repair kit buys you 25% and nothing more.
##
## ART GAP: the table is a placeholder BoxMesh. It needs a real bench model (bead).
class_name ArmorersBench
extends Node3D

const BENCH_SECONDS: float = 20.0
const INTERACT_RADIUS: float = 2.6

var _progress: float = 0.0
var _prompt: Label3D


func _ready() -> void:
	add_to_group("armorers_bench")
	_build_placeholder()
	_build_prompt()


## PLACEHOLDER. Replace with the authored bench model - see the art bead.
func _build_placeholder() -> void:
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.2, 0.08, 0.9)
	top.mesh = top_mesh
	top.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.27, 0.18)
	mat.roughness = 0.95
	top.material_override = mat
	add_child(top)

	for x: float in [-0.95, 0.95]:
		for z: float in [-0.35, 0.35]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.09, 0.86, 0.09)
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.43, z)
			leg.material_override = mat
			add_child(leg)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 0.94, 0.9)
	col.shape = box
	col.position = Vector3(0, 0.47, 0)
	body.add_child(col)
	add_child(body)


func _build_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.font_size = 26
	_prompt.pixel_size = 0.0035
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.95, 0.78, 0.42)
	_prompt.position = Vector3(0, 1.6, 0)
	_prompt.visible = false
	add_child(_prompt)


func _physics_process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var wh: Node = player.get_node_or_null("Head/Camera3D/WeaponHolder")
	if wh == null:
		return

	var in_range: bool = player.global_position.distance_to(global_position) <= INTERACT_RADIUS
	var cond: float = float(wh.get("weapon_condition"))

	if not in_range:
		_prompt.visible = false
		_progress = 0.0
		return

	_prompt.visible = true
	if cond >= 99.99:
		_prompt.text = "ARMORER'S BENCH\nWEAPON IS CLEAN"
		return

	if Input.is_action_pressed("interact"):
		_progress += delta / BENCH_SECONDS
		_prompt.text = "CLEANING... %d%%" % int(_progress * 100.0)
		if _progress >= 1.0:
			_progress = 0.0
			wh.set("weapon_condition", 100.0)
			if wh.has_method("refresh_after_load"):
				wh.call("refresh_after_load")
			_prompt.text = "WEAPON CLEAN"
	else:
		_progress = 0.0
		_prompt.text = "ARMORER'S BENCH  %d%%\nHOLD [F] TO STRIP AND CLEAN" % int(cond)
