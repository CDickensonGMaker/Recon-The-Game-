## A body that is only a position and a pulse. player.gd _friendly_in_lane reads
## global_position and is_dead() off whatever is in AgentRegistry.allies, so the probe
## does not need a real AllyBase - and must not have one: AllyBase drags in the model
## actor, the anim library and the router, none of which this measures.
extends CharacterBody3D

var dead: bool = false


func is_dead() -> bool:
	return dead
