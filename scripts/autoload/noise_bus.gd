## noise_bus.gd - Global typed sound-event bus (R13). Weapons, footsteps and
## explosions emit; AI ears subscribe. Weather (R70) scales radii via
## radius_multiplier.
extends Node

signal noise_emitted(type: int, position: Vector3, radius: float, source_team: int)

enum NoiseType { FOOTSTEP, FOOTSTEP_SPRINT, GUNSHOT, SUPPRESSED, EXPLOSION, VOICE, IMPACT }

## Base radii in meters (RECON/MoHAA-derived ratios).
##
## NOISE IS THE HONEST PRICE OF VIOLENCE (ADR-005, decree pwu5). GUNSHOT was 55m,
## which made an unsuppressed rifle a local event and gutted the entire stealth
## economy: there was no reason to ever carry a suppressor, because a loud kill
## cost you almost nothing. It is now ~150m — a rifle report carries, and firing
## one is a decision with a radius.
##
## The chain that makes stealth an ECONOMY instead of a GATE: a shot at 150m wakes
## the jungle to SUSPICIOUS/ALERT (`enemy_base._on_noise_heard` deliberately never
## escalates to COMBAT on sound alone) — they know something happened, they do NOT
## know where you are, and they come looking. Only a man who SEES you goes COMBAT
## and stamps the detection beacon. So a loud kill gets you made in a few seconds
## instead of instantly, and those seconds are the game: move, or be found.
##
## SUPPRESSED stays 3m and is deliberately not even identifiable as gunfire.
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
var radius_multiplier: float = 1.0  ## monsoon masking hook (R70)


func emit_noise(type: int, position: Vector3, source_team: int = 0, radius_override: float = -1.0) -> void:
	var radius: float = radius_override
	if radius < 0.0:
		radius = float(RADII.get(type, 10.0))
	radius *= radius_multiplier
	noise_emitted.emit(type, position, radius, source_team)
