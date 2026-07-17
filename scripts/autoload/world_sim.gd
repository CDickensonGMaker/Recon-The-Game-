## world_sim.gd - autoload. Owns the off-AO entities: squads, convoys, aircraft.
## Region grid: divide the world into CELL_SIZE cells. Each cell tracks its
## entities. A cell within the player's AO region is "live" (full sim). Cells
## outside are "abstract" (just position + velocity + next-event time, advanced
## on a 60s tick).
##
## Why this matters: the world is bigger than the AO. Without region LOD,
## every off-AO entity is at 60Hz physics cost. With it, the player sees ~50
## live entities at a time, and the rest are bookkeeping until they get close.
##
## Autoload name is `WorldSim`; class_name omitted to avoid the collision.
extends Node

const CELL_SIZE: float = 1000.0
## A live cell is one whose centre is within AO_RADIUS of the player.
const AO_RADIUS: float = 800.0
## Abstract cells advance at 60s real-time steps.
const ABSTRACT_TICK_S: float = 60.0

## id -> {kind, position, velocity, schedule, faction, current_ao, cell}
var entities: Dictionary = {}
## cell key (Vector2i) -> array of entity ids
var _cells: Dictionary = {}
## The current player cell; live cells are within AO_RADIUS of this centre.
var _player_cell: Vector2i = Vector2i.ZERO
## Last time the abstract cells were advanced.
var _abstract_tick_acc: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_abstract_tick_acc += delta
	if _abstract_tick_acc >= ABSTRACT_TICK_S:
		_abstract_tick_acc = 0.0
		_advance_abstract_cells()


## Register an entity. `data` should be a Dictionary with at least:
##   kind (String), position (Vector3), velocity (Vector3),
##   schedule (Dictionary), faction (String).
## Returns the assigned entity id.
func register(data: Dictionary) -> int:
	var id: int = entities.size() + 1
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var cell: Vector2i = _cell_of(pos)
	data["id"] = id
	data["cell"] = cell
	data["current_ao"] = false
	entities[id] = data
	_attach_to_cell(id, cell)
	return id


func _cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(pos.x / CELL_SIZE), int(pos.z / CELL_SIZE))


func _attach_to_cell(id: int, cell: Vector2i) -> void:
	if not _cells.has(cell):
		_cells[cell] = []
	var arr: Array = _cells[cell]
	if not id in arr:
		arr.append(id)


## Update player position. Cells within AO_RADIUS become "live".
func update_player(pos: Vector3) -> void:
	_player_cell = _cell_of(pos)
	for cell_key in _cells.keys():
		var cell_v: Vector2i = cell_key
		var arr: Array = _cells[cell_v]
		for id in arr:
			var data: Dictionary = entities.get(id, {})
			if data.is_empty():
				continue
			var cell_world: Vector3 = Vector3(float(cell_v.x) * CELL_SIZE, 0.0, float(cell_v.y) * CELL_SIZE)
			var live: bool = cell_world.distance_to(pos) <= AO_RADIUS
			data["current_ao"] = live


## Materialize the entities in cells around the player. Returns the entities
## that just transitioned to live.
func materialize_near(player_pos: Vector3, radius: float) -> Array:
	var out: Array = []
	for id in entities.keys():
		var data: Dictionary = entities[id]
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		if player_pos.distance_to(pos) <= radius:
			if not data.get("current_ao", false):
				data["current_ao"] = true
				out.append(data)
	return out


## Dematerialize far entities.
func dematerialize_far(player_pos: Vector3, radius: float) -> Array:
	var out: Array = []
	for id in entities.keys():
		var data: Dictionary = entities[id]
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		if player_pos.distance_to(pos) > radius:
			if data.get("current_ao", false):
				data["current_ao"] = false
				out.append(data)
	return out


func _advance_abstract_cells() -> void:
	for id in entities.keys():
		var data: Dictionary = entities[id]
		if data.get("current_ao", false):
			continue
		var vel: Vector3 = data.get("velocity", Vector3.ZERO)
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		var new_pos: Vector3 = pos + vel * ABSTRACT_TICK_S
		data["position"] = new_pos
		var new_cell: Vector2i = _cell_of(new_pos)
		var old_cell: Vector2i = data.get("cell", new_cell)
		if new_cell != old_cell:
			if _cells.has(old_cell):
				_cells[old_cell].erase(id)
			_attach_to_cell(id, new_cell)
			data["cell"] = new_cell


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
	_cells.clear()
