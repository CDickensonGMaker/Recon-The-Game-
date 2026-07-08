## noise_bus.gd - Global typed sound-event bus (R13). Weapons, footsteps and
## explosions emit; AI ears subscribe. Weather (R70) scales radii via
## radius_multiplier.
extends Node

signal noise_emitted(type: int, position: Vector3, radius: float, source_team: int)

enum NoiseType { FOOTSTEP, FOOTSTEP_SPRINT, GUNSHOT, SUPPRESSED, EXPLOSION, VOICE, IMPACT }

## Base radii in meters (RECON/MoHAA-derived ratios).
const RADII := {
	NoiseType.FOOTSTEP: 8.0,
	NoiseType.FOOTSTEP_SPRINT: 16.0,
	NoiseType.GUNSHOT: 55.0,
	NoiseType.SUPPRESSED: 3.0,
	NoiseType.EXPLOSION: 110.0,
	NoiseType.VOICE: 20.0,
	NoiseType.IMPACT: 10.0,
}

## Teams: 0 = friendly (player/allies), 1 = enemy.
var radius_multiplier: float = 1.0  ## monsoon masking hook (R70)


func emit_noise(type: int, position: Vector3, source_team: int = 0, radius_override: float = -1.0) -> void:
	var radius: float = radius_override
	if radius < 0.0:
		radius = float(RADII.get(type, 10.0))
	radius *= radius_multiplier
	noise_emitted.emit(type, position, radius, source_team)
