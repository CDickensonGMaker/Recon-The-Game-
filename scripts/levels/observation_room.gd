extends Node3D

## DEV observation room: the AI stress arena (two sides fighting + firebase/village/cover)
## with the observation instrument attached. Watch AI-vs-AI combat and structured life, with
## the free-fly observer (O), the state overlay (I) and time controls — debug builds only.
## Run: godot --path . res://scenes/levels/observation_room.tscn
##
## Reuses the arena wholesale (ADR-023 — one rig, not a second sandbox). The full civilian
## daily-routine schedule lives in a booted patrol world; ObservationTools drops into that
## scene the same way for routine-watching (see the report's gated room note).

func _ready() -> void:
	var packed: PackedScene = load("res://scenes/levels/ai_stress_arena.tscn") as PackedScene
	if packed != null:
		var arena := packed.instantiate() as AIStressArena
		if arena != null:
			arena.set("spawn_cover", true)   # build firebase + village + cover: a world to watch
			add_child(arena)
	add_child(ObservationTools.new())
