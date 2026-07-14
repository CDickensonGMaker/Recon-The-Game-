extends Resource
## One VC hideout linked to a village. Either a surface camp (satchel on a
## commo bunker / ammo stash) or an underground tunnel (satchel at the back
## of a modular tile cave).

enum HideoutType { CAMP, TUNNEL }

@export var hideout_id: String
@export var world_position: Vector2
@export var type: int = HideoutType.CAMP
@export var defender_count: int = 2
## Local-space offset from world_position to the satchel objective.
@export var satchel_target_local: Vector2 = Vector2.ZERO
## Angle from the village, in degrees, captured at spawn time. Useful for
## the player UI ("third hideout is 220m to the northeast").
@export var angle_from_village: float = 0.0
## Distance from the village at spawn. Same use as angle.
@export var distance_from_village: float = 0.0
## True once the player has placed and detonated the satchel. Persists with
## the mission state, so re-visiting the village keeps the hideout dead.
@export var is_cleared: bool = false
