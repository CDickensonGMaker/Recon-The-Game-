## terrain_watchdog.gd - Re-seats bodies that fall through the terrain, and
## freezes physics+brain on NPCs past SUSPEND_DIST (they cannot see or hear
## you from there anyway).
class_name TerrainWatchdog
extends Node

const POLL_SECONDS: float = 2.0
const UNDER_DEPTH: float = 5.0
const SUSPEND_DIST: float = 240.0
const RESUME_DIST: float = 210.0  # hysteresis

var world: GameWorld
var _timer: float = 0.0


func setup(game_world: GameWorld) -> void:
	world = game_world


func _physics_process(delta: float) -> void:
	if world == null:
		return
	_timer += delta
	if _timer < POLL_SECONDS:
		return
	_timer = 0.0
	var player := GameManager.player as Node3D
	for group in ["enemies", "allies", "civilians"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as CharacterBody3D
			if body == null or not is_instance_valid(body):
				continue
			if body.has_method("is_dead") and body.is_dead():
				continue
			# Distance suspension. The player's own squad is exempt - it follows
			# orders far from him. An ambient friendly patrol is not his and must
			# LOD like anyone else, or it runs full AI across the whole AO.
			var squad_ally: bool = group == "allies" \
				and (body as AllyBase) != null and (body as AllyBase).squad_member
			if player != null and not squad_ally:
				var dist: float = body.global_position.distance_to(player.global_position)
				var suspended: bool = body.has_meta("suspended")
				if not suspended and dist > SUSPEND_DIST:
					body.set_meta("suspended", true)
					body.set_physics_process(false)
					body.visible = false
					continue
				elif suspended and dist < RESUME_DIST:
					body.remove_meta("suspended")
					body.set_physics_process(true)
					# A spider-hole ambusher must STAY hidden until he triggers at 7m:
					# never blanket-restore visible on resume.
					var hidden_hole: bool = body.get("is_spider_hole") and not body.get("_spider_triggered")
					body.visible = not hidden_hole
					# surface_y(), not raw terrain height - the firebase mound model
					# IS the floor and sits ABOVE bare terrain there (one-ground law).
					body.global_position.y = world.surface_y(body.global_position) + 0.5
				elif suspended:
					continue
			# Fall-through re-seat.
			var ground_y: float = world.surface_y(body.global_position)
			if body.global_position.y < ground_y - UNDER_DEPTH:
				body.global_position.y = ground_y + 0.5
				body.velocity = Vector3.ZERO
