## noise_bus.gd - global typed sound-event bus. Weapons, footsteps and explosions
## emit; AI ears subscribe. Weather scales radii via radius_multiplier.
extends Node

signal noise_emitted(type: int, position: Vector3, radius: float, source_team: int)

enum NoiseType { FOOTSTEP, FOOTSTEP_SPRINT, GUNSHOT, SUPPRESSED, EXPLOSION, VOICE, IMPACT }

## Base radii in METRES - the values of record (ADR-005: noise is the price of
## violence, and stealth is an economy rather than a gate).
##
## These depend on the WITNESS RULE and are meaningless without it: a heard shot
## only wakes the jungle to SUSPICIOUS/ALERT - `enemy_base._on_noise_heard` must
## NEVER escalate to COMBAT on sound alone. Only a man who SEES you goes COMBAT.
const RADII := {
	NoiseType.FOOTSTEP: 8.0,
	NoiseType.FOOTSTEP_SPRINT: 16.0,
	NoiseType.GUNSHOT: 150.0,
	NoiseType.SUPPRESSED: 3.0,
	NoiseType.EXPLOSION: 110.0,
	NoiseType.VOICE: 20.0,
	NoiseType.IMPACT: 10.0,
}

## Teams: 0 = friendly (player/allies), 1 = enemy.
var radius_multiplier: float = 1.0  ## monsoon masking hook


func emit_noise(type: int, position: Vector3, source_team: int = 0, radius_override: float = -1.0) -> void:
	var radius: float = radius_override
	if radius < 0.0:
		radius = float(RADII.get(type, 10.0))
	radius *= radius_multiplier
	noise_emitted.emit(type, position, radius, source_team)
