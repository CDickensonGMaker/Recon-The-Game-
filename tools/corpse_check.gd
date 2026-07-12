## corpse_check.gd - do dead men lie ON the ground? Spawns two dummies and
## kills them through both death paths: LEFT = clean kill (ragdoll), RIGHT =
## limb-popped first (death animation). Screenshot it with screenshot_runner:
##   SHOT_TARGET=res://tools/corpse_check.tscn SHOT_FRAMES=300
##   SHOT_CAM=0,1.6,1.5@0,0.3,-4
extends Node3D


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://terrain/shaders/lab_grid.gdshader")
	mi.material_override = sm
	floor_body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	cs.shape = box
	cs.position.y = -0.1
	floor_body.add_child(cs)
	add_child(floor_body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.88, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.environment = e
	add_child(env)

	var rag := GoreDummy.new()
	rag.unit_id = "vc_guerilla"
	add_child(rag)
	rag.global_position = Vector3(-1.5, 0, -4)
	var anim := GoreDummy.new()
	anim.unit_id = "vc_guerilla"
	add_child(anim)
	anim.global_position = Vector3(1.5, 0, -4)

	var t: SceneTreeTimer = get_tree().create_timer(0.6)
	t.timeout.connect(func() -> void:
		rag.take_damage(200, 0, null, "BODY")          # clean kill -> ragdoll
		anim.take_damage(60, 0, null, "ARM_L_UP")      # pop a limb first...
		anim.take_damage(200, 0, null, "BODY")         # ...gibbed kill -> death anim
		print("[CORPSE CHECK] both dummies killed - left ragdoll, right death anim"))
