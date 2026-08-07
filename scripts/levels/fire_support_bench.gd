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


## The destructible structure segment folded into the general Destructible (ADR-023) —
## scripts/world/destructible.gd. spawn_fort() below builds one; there is no second path.


## THE REAL FIREBASE ART, NOT A STAND-IN. A bench that proves a grey box breaks has proved
## nothing about the thing that has to break. Both benches lift their targets out of the
## shipped GLBs through here, so there is ONE lifter and no second target vocabulary.
const FSB_PATH: String = "res://assets/world/building models/structures/firebase/fsb_main_v3.glb"
## The wire is NOT taken from the firebase: gen_firebase_v3 bakes all ~450 cards into one
## merged `bwire_card_ring` measuring 230 x 4 x 169 m, and a box hull off that AABB is a
## map-sized wall. This is the single card the ring is built from.
const WIRE_PATH: String = "res://assets/us/props/emplacements/barbwire_card.glb"

## prefix -> [kind, source]. The HP for each kind lives in Destructible.HP_FOR - one table,
## because this list and the arena's and the world's all carried the same numbers by hand.
const TARGET_KINDS: Array[Dictionary] = [
	{"prefix": "fb_sbg_seg_", "kind": "sandbag_wall", "src": "fsb"},
	{"prefix": "fb_sandbag_stack_i", "kind": "sandbag_stack", "src": "fsb"},
	{"prefix": "fb_bunker_fighting_i", "kind": "bunker", "src": "fsb"},
	{"prefix": "fb_bunker_mg_i", "kind": "bunker_mg", "src": "fsb"},
	{"prefix": "fb_tower_i", "kind": "tower", "src": "fsb"},
	{"prefix": "bwire_card", "kind": "wire", "src": "wire"},
]


## Pull up to `want` authored meshes whose name starts with `prefix` out of the shipped GLB.
## Returns duplicated meshes, never the instantiated nodes: the caller stands its own
## Destructibles up and the source instance is freed here, so nothing leaks a 100 m-away
## transform or a second collider into the bench.
static func lift_meshes(prefix: String, want: int, src: String = "fsb") -> Array[Mesh]:
	var out: Array[Mesh] = []
	var path: String = WIRE_PATH if src == "wire" else FSB_PATH
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[BENCH] %s missing - cannot lift '%s' targets" % [path, prefix])
		return out
	var inst := packed.instantiate() as Node3D
	var stack: Array[Node] = [inst]
	while not stack.is_empty() and out.size() < want:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm := String(mi.name)
		# `-colonly` nodes are Godot's import-time collision proxies, never renderable art.
		if not nm.begins_with(prefix) or nm.contains("-colonly"):
			continue
		out.append(mi.mesh)
	inst.free()
	return out


## Stand one lifted mesh up as a Destructible on the blast bus. The collider is a box from
## the mesh's own AABB — the shipped firebase gives these a box hull anyway, and a bench
## tests DESTRUCTION, not shot-through-the-slit geometry.
##
## The AABB CENTRE is what gets registered, not the mesh origin: combat_manager.gd:176-185
## damages a prop on a pure radius test against global_position with no LOS and no bounds
## check, so a 9.6 m tower keyed off its foot is spared by a blast that visibly engulfs it.
static func spawn_lifted(host: Node, mesh: Mesh, at: Vector3, kind: String, hp: int) -> Destructible:
	var box: AABB = mesh.get_aabb()
	var centre: Vector3 = box.position + box.size * 0.5
	var d := Destructible.new()
	d.kind = kind
	d.hp = hp
	d.collision_layer = 1
	d.collision_mask = 0
	host.add_child(d)
	# `at` is where the caller wants the piece to STAND: centred horizontally, base on the
	# ground. The node itself sits at the AABB centre, half the mesh's height above that.
	d.global_position = Vector3(at.x, at.y + box.size.y * 0.5, at.z)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -centre      # mesh AABB centre onto the node origin
	d.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	d.add_child(cs)
	AgentRegistry.register(d, AgentRegistry.Kind.PROP)
	return d


## Build the rig as children of `host`, wire the RTO net (needs a "radioman" already in the
## tree), stock every tier including WP, and return the live FieldDirector. The caller
## connects director.toast to its own readout.
static func wire(host: Node, player: CharacterBody3D, map_size: float) -> FieldDirector:
	var tm := BenchTerrain.new()
	tm.name = "BenchTerrain"
	host.add_child(tm)
	# Point the destruction authority at the bench ground. Without this every
	# DamageSystem.apply_damage from bench ordnance early-returns UNRECORDED -
	# no scar, no ledger entry - and the bench lies about destruction parity.
	# BenchTerrain.modify_terrain is a no-op, so no real digging happens.
	DamageSystem.set_terrain_manager(tm)
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
	d.fire_support = {"bombs": 9, "napalm": 9, "arty": 9, "mortar": 9, "spectre": 9, "cbu": 9,
		"wp": 9, "illum": 9}
	d._hunter_pool = 0   # no escalation hunters on the inert host
	return d


## Create a destructible fort segment at `pos` and register it on the props blast bus.
static func spawn_fort(host: Node, pos: Vector3, mesh: Mesh, box: Vector3, kind: String, hp: int) -> Destructible:
	var fort := Destructible.new()
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
