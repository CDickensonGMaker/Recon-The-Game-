## projectile_pool.gd - Object pooling for projectile performance
class_name ProjectilePool
extends Node

## Pool configuration
const MAX_ACTIVE_PROJECTILES := 64

## Pool storage
var _pool: Array[ProjectileBase] = []
var _active_projectiles: Array[ProjectileBase] = []

## Statistics

func _ready() -> void:
	# Lazy pool: spawn() grows on demand, so nothing is pre-allocated at boot.
	pass


func _create_projectile() -> ProjectileBase:
	var projectile := ProjectileBase.new()
	projectile.set_pool(self)
	projectile.returned_to_pool.connect(_on_projectile_returned.bind(projectile))
	add_child(projectile)
	return projectile


## Spawn a projectile from the pool
func spawn(data: ProjectileData, source: Node, spawn_position: Vector3, direction: Vector3, target: Node3D = null) -> ProjectileBase:
	if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		_evict_one()

	var projectile: ProjectileBase = null

	if _pool.size() > 0:
		projectile = _pool.pop_back()
	else:
		projectile = _create_projectile()

	projectile.global_position = spawn_position
	projectile.initialize(data, source, direction, target)
	projectile.activate()

	_active_projectiles.append(projectile)

	return projectile


## An armed warhead in flight has already been promised to a point on the ground:
## a fire mission's shell, a bomb off the rack, the footprint the player was shown.
## Recycling it silently deletes an explosion he was told to expect, so the pool
## sheds bullets first and only takes a warhead when there is nothing else to shed.
func _evict_one() -> void:
	for p in _active_projectiles:
		if not _is_live_warhead(p):
			_return_to_pool(p)
			return
	_return_to_pool(_active_projectiles[0])


func _is_live_warhead(p: ProjectileBase) -> bool:
	if p == null or p.projectile_data == null:
		return false
	return p.projectile_data.aoe_radius > 0.0 and p.is_armed()


## Return a projectile to the pool
func _return_to_pool(projectile: ProjectileBase) -> void:
	if projectile in _active_projectiles:
		_active_projectiles.erase(projectile)

	projectile.deactivate()

	if projectile not in _pool:
		_pool.append(projectile)


## Called when a projectile signals it's returning to pool
func _on_projectile_returned(projectile: ProjectileBase) -> void:
	_return_to_pool(projectile)


## Clear all active projectiles
func clear_all() -> void:
	for projectile in _active_projectiles.duplicate():
		_return_to_pool(projectile)
	_active_projectiles.clear()
