## probe_lab_model.gd - MODEL mode builds a normalised, animated 3D enemy.
extends Node
func _ready() -> void:
	var lab: CombatLab = load("res://scenes/levels/combat_lab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	lab.visual_mode = CombatLab.VisualMode.MODEL
	var e := await lab.spawn_enemy("res://data/enemies/nva_rpg.tres", Vector3(0,1,-5))
	await get_tree().process_frame
	var holder := e.get_node_or_null("LabModel")
	if holder == null: print("FAIL: no LabModel node built"); get_tree().quit(1); return
	var anim: AnimationPlayer = e.get_meta("lab_anim") if e.has_meta("lab_anim") else null
	if anim == null: print("FAIL: model has no AnimationPlayer"); get_tree().quit(1); return
	# height normalised to ~1.71m?
	var inst := holder.get_child(0) as Node3D
	print("  vc6_heavy model: scale=%.3f playing=%s clips=%d" % [inst.scale.y, anim.current_animation, anim.get_animation_list().size()])
	if anim.current_animation == "": print("FAIL: not playing an idle"); get_tree().quit(1); return
	print("PASS: lab model mode")
	get_tree().quit(0)
