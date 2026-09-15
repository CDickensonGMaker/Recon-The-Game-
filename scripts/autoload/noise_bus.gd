## noise_bus.gd - global typed sound-event bus. Weapons, footsteps and explosions
## emit; AI ears subscribe. Weather scales radii via radius_multiplier.
extends Node

## `source` is WHO MADE THE SOUND, and it exists for one reason: a man must not hear
## himself. Without it every shout an enemy makes re-anchors his own beacon on his own
## feet, which wipes the killer's position the witness rule had just written there
## (ADR-005, measured by test_witness_rule 2026-09-09). Null means "nobody in particular",
## which is right for a shell, a footstep or a bullet crack.
signal noise_emitted(type: int, position: Vector3, radius: float, source_team: int, source: Node)

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
## Weather only ever MASKS (mission_weather.gd WEATHER noise <= 1.0). The sleep-radius
## invariant below is computed against this ceiling; a multiplier above it is clamped at emit.
const RADIUS_MULTIPLIER_MAX: float = 1.0
var _ceiling_warned: bool = false


## THE SLEEP-RADIUS INVARIANT. A man past TerrainWatchdog.SUSPEND_DIST has no ears (physics
## off), so no sound may carry that far or the sleeping ring is a hearing gap rather than
## silence. Loudest table radius times the weather ceiling; overrides are clamped by the same
## line in emit_noise. tests/test_sleep_radius.gd holds it.
static func loudest_radius() -> float:
	var loudest: float = 0.0
	for r in RADII.values():
		loudest = maxf(loudest, float(r))
	return loudest * RADIUS_MULTIPLIER_MAX


func _ready() -> void:
	if loudest_radius() >= TerrainWatchdog.SUSPEND_DIST:
		push_error("[NOISE] loudest radius %.0f m reaches past the %.0f m sleep ring" % [
			loudest_radius(), TerrainWatchdog.SUSPEND_DIST])


func emit_noise(type: int, position: Vector3, source_team: int = 0, radius_override: float = -1.0,
		source: Node = null) -> void:
	var radius: float = radius_override
	if radius < 0.0:
		radius = float(RADII.get(type, 10.0))
	radius *= radius_multiplier
	if radius >= TerrainWatchdog.SUSPEND_DIST:
		if not _ceiling_warned:
			_ceiling_warned = true
			push_warning("[NOISE] type %d radius %.0f m (x%.2f) clamped under the %.0f m sleep ring" % [
				type, radius, radius_multiplier, TerrainWatchdog.SUSPEND_DIST])
		radius = TerrainWatchdog.SUSPEND_DIST - 1.0
	noise_emitted.emit(type, position, radius, source_team, source)
