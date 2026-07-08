## rescue_objective.gd - Free the POW (W48). He joins on the ally AI stack and
## must reach exfil alive for full credit.
class_name RescueObjective
extends ObjectiveSensor

const FREE_RADIUS: float = 3.0
const HOLD_SECONDS: float = 2.5

var world: GameWorld
var pow_ally: AllyBase = null
var _progress: float = 0.0
var _cage: Node3D = null


func setup_camp(game_world: GameWorld) -> void:
	world = game_world
	# Cage placeholder: a rice-storage crib. The POW paces inside (capsule).
	var planner_cage := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 1.8, 2.2)
	planner_cage.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.28, 0.18, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	planner_cage.material_override = mat
	add_child(planner_cage)
	planner_cage.position = Vector3(0, 0.9, 0)
	_cage = planner_cage


func _physics_process(delta: float) -> void:
	if is_complete():
		set_physics_process(false)
		return
	var player := _find_player()
	if player == null:
		return
	if player.global_position.distance_to(global_position) <= FREE_RADIUS \
			and Input.is_action_pressed("interact") and GameManager.can_player_act():
		advance_free(delta)
	elif _progress > 0.0:
		_progress = 0.0


func advance_free(delta: float) -> void:
	if is_complete():
		return
	_progress += delta / HOLD_SECONDS
	if _progress >= 1.0:
		_free_pow()


func _free_pow() -> void:
	if _cage:
		_cage.queue_free()
	# The aviator joins the squad on the normal ally stack.
	var pos := global_position + Vector3(1.5, 0.5, 0)
	if world:
		pos.y = world.terrain_manager.get_height_at(pos) + 0.5
	pow_ally = AllyBase.spawn_ally(get_parent(), pos)
	pow_ally.member = {"name": "LT. HARLAN", "mos": "RESCUED", "nick": "PILOT", "st": 90, "ag": 90, "al": 90, "skills": {}, "kills": 0, "missions": 0, "alive": true}
	var tag := Label3D.new()
	tag.text = "PILOT (RESCUED)"
	tag.font_size = 22
	tag.pixel_size = 0.004
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.9, 0.85, 0.5)
	pow_ally.add_child(tag)
	tag.position = Vector3(0, 2.2, 0)
	pow_ally.died.connect(func(_a: AllyBase) -> void:
		if director:
			director.state.flags["pow_lost"] = true
			director.toast.emit("THE PILOT IS DOWN - GET HIS TAGS AND KEEP MOVING"))
	if director:
		director.toast.emit("POW FREED - HE'S WITH US. GET TO EXFIL.")
	complete()
	set_physics_process(false)
