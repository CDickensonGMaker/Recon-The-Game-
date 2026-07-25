extends Node3D

## DEV routine-observation room: boots the full populated patrol world (villages, camps,
## civilians on their SimClock schedule, ambient patrols) through the PROVEN GameFlow path —
## the same one world-builder the game uses (world-foundation-locked, ADR-028; NO parallel
## populated world) — with the day COMPRESSED so a full routine watches in about a minute,
## and the observation instrument attached (O observer, I overlay, time keys).
##
## Run: godot --path . res://scenes/levels/observation_room_routine.tscn -- --test-save
## The --test-save flag redirects the campaign write to campaign_test.cfg so watching a
## routine never disturbs the real save. Peaceful/schedule counterpart to observation_room.
##
## Verified by launch + the existing probes: test_patrol_world covers the populated world
## build, test_observation_tools covers the instrument. This scene is the glue over both.

const DAY_COMPRESS_RATIO: float = 900.0   ## ~24h of schedule in ~1.6 real min (dial live with - / =)


func _ready() -> void:
	var flow := GameFlow.new()
	add_child(flow)
	flow._begin_operation(31337, "OBSERVATION - ROUTINE")
	SimClock.real_to_sim_ratio = DAY_COMPRESS_RATIO
	add_child(ObservationTools.new())
