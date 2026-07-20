## projectile_pool.gd - Object pooling for projectile performance
class_name ProjectilePool
extends Node

## Pool configuration
const MAX_ACTIVE_PROJECTILES := 30

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
	# Enforce max active projectiles
	if _active_projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		var oldest := _active_projectiles[0]
		_return_to_pool(oldest)

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
