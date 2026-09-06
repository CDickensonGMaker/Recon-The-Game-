## A body that is only a posture. AllyBase._mirrors_player_low reads two properties off
## GameManager.player and nothing else, so the probe does not need the real Player - and
## must not have it: player.tscn drags in the weapon holder, the equipment manager and
## the hitzone tree, none of which this measures.
extends CharacterBody3D

var is_crouching: bool = false
var is_prone: bool = false
