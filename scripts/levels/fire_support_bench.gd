class_name FireSupportBench
extends Node

## The shared fire-support rig: an inert GameWorld + flat terrain + a frozen SquadSystem
## holding the RTO + a FieldDirector stocked on every tier. Extracted from
## ai_stress_arena._wire_fire_support so the AI arena and the support-fire range share ONE
## rig (ADR-023 — no second FieldDirector-on-inert-world clone).


## Inert GameWorld host. FieldDirector.world is typed GameWorld; a bench is not a real
## world. FieldDirector reads only .terrain_manager / .player / .map_size / .add_child().
class BenchWorld extends GameWorld:
	func _ready() -> void:
		pass  # not in the "game_world" group; no terrain/veg/water build


## Flat terrain: get_height_at is a constant 0, no heightmap allocation. FieldDirector
## seats its impacts through this.
class BenchTerrain extends TerrainManager:
	func _ready() -> void:
		pass

	func get_height_at(_world_pos: Vector3) -> float:
		return 0.0

	func get_normal_at(_world_pos: Vector3) -> Vector3:
		return Vector3.UP

	func modify_terrain(_center: Vector3, _radius_meters: float, _modifier: Callable) -> void:
		pass


## A destructible props-bus segment (sandbag / wire / bunker) an explosion tears out. The
## existing blast loop (combat_manager.gd:178-185) damages it via AgentRegistry.props — no
## bespoke damage code. Hard cover until blown. ADR-003: take_damage is the one grammar.
class DestructibleFortification extends StaticBody3D:
	var kind: String = ""
	var hp: int = 110
	var _destroyed: bool = false

	func take_damage(amount: int, _t: int = 0, _attacker: Node = null, _zone: String = "BODY") -> void:
		if _destroyed:
			return
		hp -= amount
		if hp <= 0:
			_blow()

	func _blow() -> void:
		_destroyed = true
		AgentRegistry.unregister(self)
		GunFX.impact(get_tree().current_scene, global_position + Vector3.UP * 0.3, Vector3.UP, true)
		queue_free()


## Build the rig as children of `host`, wire the RTO net (needs a "radioman" already in the
## tree), stock every tier including WP, and return the live FieldDirector. The caller
## connects director.toast to its own readout.
static func wire(host: Node, player: CharacterBody3D, map_size: float) -> FieldDirector:
	var tm := BenchTerrain.new()
	tm.name = "BenchTerrain"
	host.add_child(tm)
	var fw := BenchWorld.new()
	fw.name = "BenchWorld"
	host.add_child(fw)
	fw.terrain_manager = tm
	fw.player = player
	fw.map_size = map_size
	# The net is a MAN: a frozen SquadSystem holding the RTO so member_by_mos finds him and
	# the 10m radio leash is real. setup() is skipped — it would spawn a fresh squad and its
	# update loops fault with no world/director; here it is only a roster holder.
	var ss := SquadSystem.new()
	ss.name = "BenchSquad"
	host.add_child(ss)
	ss.set_physics_process(false)
	ss.set_process(false)
	for r in host.get_tree().get_nodes_in_group("radioman"):
		if r is AllyBase and is_instance_valid(r):
			ss.members.append(r as AllyBase)
			break
	var d := FieldDirector.new()
	d.name = "BenchFieldDirector"
	host.add_child(d)
	d.setup(fw)
	d.squad_system = ss
	# T opens the net; 1 bombs / 2 napalm / 3 arty / 4 mortar / 5 spectre / 6 CBU. WP is
	# stocked for a bench that drives it directly (request_fire_support("wp", target)).
	d.fire_support = {"bombs": 9, "napalm": 9, "arty": 9, "mortar": 9, "spectre": 9, "cbu": 9, "wp": 9}
	d._hunter_pool = 0   # no escalation hunters on the inert host
	return d


## Create a destructible fort segment at `pos` and register it on the props blast bus.
static func spawn_fort(host: Node, pos: Vector3, mesh: Mesh, box: Vector3, kind: String, hp: int) -> DestructibleFortification:
	var fort := DestructibleFortification.new()
	fort.kind = kind
	fort.hp = hp
	fort.collision_layer = 1
	fort.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	fort.add_child(mi)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box
	shape.shape = bs
	shape.position = Vector3(0.0, box.y * 0.5, 0.0)
	fort.add_child(shape)
	host.add_child(fort)
	fort.global_position = pos
	AgentRegistry.register(fort, AgentRegistry.Kind.PROP)
	return fort
