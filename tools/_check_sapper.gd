extends SceneTree


func _init() -> void:
	var d: Resource = load("res://data/enemies/vc_sapper.tres")
	if d == null:
		print("FAIL: vc_sapper.tres did not load")
		quit(1)
		return
	print("loaded ok      id=", d.id)
	print("sprite_unit    ", d.sprite_unit)
	print("fallback       ", d.sprite_unit_fallback)
	print("variants       ", d.sprite_unit_variants, "  type=", typeof(d.sprite_unit_variants))
	for u: String in ["vc_sapper", "vc_sapper_stripped"]:
		print("model_exists(", u, ") = ", ModelActor.model_exists(u),
			"  faces=", VcNvaDresser.faces_for(u).size())
	quit(0)
