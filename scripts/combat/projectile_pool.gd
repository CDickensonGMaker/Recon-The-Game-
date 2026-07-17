## projectile_pool.gd - Object pooling for projectile performance
class_name ProjectilePool
extends Node

## Pool configuration
const DEFAULT_POOL_SIZE := 50
const MAX_ACTIVE_PROJECTILES := 30

## Pool storage
var _pool: Array[ProjectileBase] = []
var _active_projectiles: Array[ProjectileBase] = []

## Statistics
var _total_spawned: int = 0
var _total_recycled: int = 0

func _ready() -> void:
	# Lazy pool: spawn() grows on demand, so nothing is pre-allocated at boot.
	# Call warm_pool() when projectiles actually go live.
	pass


## Pre-spawn the pool. Call from M5 when ballistic weapons come online; not at boot.
func warm_pool(count: int = DEFAULT_POOL_SIZE) -> void:
	for i in range(count):
		var projectile := _create_projectile()
		projectile.deactivate()
		_pool.append(projectile)


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
		_total_recycled += 1
	else:
		projectile = _create_projectile()
		_total_spawned += 1

	projectile.global_position = spawn_position
	projectile.initialize(data, source, direction, target)
	projectile.activate()

	_active_projectiles.append(projectile)

	return projectile


## Spawn a projectile aimed at a specific target position
func spawn_at_target(data: ProjectileData, source: Node, spawn_position: Vector3, target_position: Vector3, target: Node3D = null) -> ProjectileBase:
	var direction := (target_position - spawn_position).normalized()
	return spawn(data, source, spawn_position, direction, target)


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


## Get count of active projectiles
func get_active_count() -> int:
	return _active_projectiles.size()


## Get count of pooled (inactive) projectiles
func get_pooled_count() -> int:
	return _pool.size()


## Get pool statistics
func get_stats() -> Dictionary:
	return {
		"active": _active_projectiles.size(),
		"pooled": _pool.size(),
		"total_spawned": _total_spawned,
		"total_recycled": _total_recycled
	}
