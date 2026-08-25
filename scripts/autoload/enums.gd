## enums.gd - Game-wide enumerations for Hell of Duty
class_name Enums
extends RefCounted

## Damage types
enum DamageType {
	PHYSICAL,
	EXPLOSIVE,
	FIRE
}

## Weapon firing modes
enum FiringMode {
	SEMI_AUTO,
	FULL_AUTO,
	BOLT_ACTION,
	BURST
}

## How a weapon is fed. Drives the reload model: MAGAZINE/BELT carry a pouch of
## per-mag round counts, INTERNAL is a tube plus a loose-round pool, SINGLE is
## one chambered round plus loose rounds.
enum FeedType {
	MAGAZINE,
	BELT,
	INTERNAL,
	SINGLE
}

## Equipment slot types
enum SlotType {
	WEAPON,
	GRENADE,
	MEDKIT,
	MELEE
}

## Enemy AI states - low-level behavior states
enum AIState {
	IDLE,
	ALERT,
	COMBAT,
	SUPPRESSED,
	SEEKING_COVER,
	FLANKING,
	ADVANCING,
	RETREATING,
	DEAD
}

## AI Goals - high-level tactical objectives (Quake 3 inspired)
enum AIGoal {
	NONE,           # No active goal
	HOLD_POSITION,  # Stay in current area, engage targets of opportunity
	ENGAGE_TARGET,  # Actively fight current target
	SEEK_COVER,     # Find and move to cover
	SUPPRESS_TARGET,# Keep target pinned with sustained fire
	FLANK_TARGET,   # Move to side/behind target
	ADVANCE,        # Push forward aggressively
	RETREAT,        # Fall back to safer position
	INVESTIGATE     # Check last known enemy position
}

## AI Personality - affects decision weights
enum AIPersonality {
	AGGRESSIVE,     # Prefers flanking, advancing
	DEFENSIVE,      # Prefers cover, suppression
	BALANCED        # Adapts to situation
}

