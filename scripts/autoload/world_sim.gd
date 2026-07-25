## world_sim.gd - autoload. Flat registry of the mission's spawned enemies, keyed
## by id. mission_generator registers each spawned enemy at mission start
## (_wire_systems, mission_generator.gd:207-219) and clears the registry on
## re-run; test_world_alive reads the counts.
##
## Autoload name is `WorldSim`; class_name omitted to avoid the collision.
extends Node

## id -> {kind, position, velocity, schedule, faction, id, current_ao}
var entities: Dictionary = {}


## Register an entity. `data` should carry at least kind/position/velocity/
## faction/schedule. Returns the assigned entity id.
func register(data: Dictionary) -> int:
	var id: int = entities.size() + 1
	data["id"] = id
	data["current_ao"] = false
	entities[id] = data
	return id


func count_live() -> int:
	var n: int = 0
	for id in entities.keys():
		if entities[id].get("current_ao", false):
			n += 1
	return n


## Reset the registry. Called by mission_generator._wire_systems at mission
## start so a re-run doesn't pile stale entities on top of fresh ones.
func clear_if_needed() -> void:
	entities.clear()
