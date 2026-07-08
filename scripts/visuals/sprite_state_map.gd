## sprite_state_map.gd - AIState (+ the flags that are not states) -> clip id.
##
## The clip set does not cover the state set. DESIGN.md:84 specs
## idle/walk/run/crouch/aim/fire/reload/flinch/death x2/prone. We rendered 20
## clips, and four things the AI actually does have no clip at all:
##
##   looping walk  - start_walking is a one-shot transition (hold_last_frame),
##                   so patrol falls back to run_forward at reduced fps
##   flinch        - a hit is currently a fire-rate stall, invisible to the player
##   surrender     - try_surrender() ships TODAY and is visible (CHIEU HOI)
##   prone / crawl - is_crippled borrows injured_walk_backwards
##
## Every fallback below is deliberate and commented. resolve() never returns a
## clip that does not exist for the unit: it walks a chain and finally lands on
## rifle_aiming_idle, which every rendered unit has.
class_name SpriteStateMap
extends RefCounted

const IDLE := "rifle_aiming_idle"

## Ordered fallbacks. First existing clip wins.
const CHAINS: Dictionary = {
	"idle": ["rifle_aiming_idle", "action_idle_to_standing_idle"],
	"patrol": ["start_walking", "run_forward", "rifle_aiming_idle"],
	"walk": ["start_walking", "run_forward", "rifle_aiming_idle"],
	"run": ["run_forward", "start_walking", "rifle_aiming_idle"],
	"fire": ["firing_rifle", "rifle_aiming_idle"],
	"aim": ["rifle_aiming_idle"],
	"reload": ["reloading", "rifle_aiming_idle"],
	"cover": ["stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"strafe": ["strafe", "run_forward", "rifle_aiming_idle"],
	"retreat": ["injured_walk_backwards", "run_forward", "rifle_aiming_idle"],
	"crippled": ["injured_walk_backwards", "laying_breathless", "rifle_aiming_idle"],
	"surrender": ["kneeling_pointing", "rifle_aiming_idle"],  # no surrender clip yet
	"death_forward": ["death_forward", "laying_breathless"],
	"death_right": ["death_from_right", "death_forward", "laying_breathless"],
	"flinch": ["rifle_aiming_idle"],  # no flinch clip yet
}


## Speed below which "running" reads as a walk. Enemy move_speed is 4.0-4.4 m/s.
const WALK_SPEED_MAX: float = 2.6


static func resolve(faction: String, unit: String, weapon: String, intent: String) -> String:
	var chain: Array = CHAINS.get(intent, [IDLE])
	for clip in chain:
		if SpriteLibrary.has_clip(faction, unit, weapon, str(clip)):
			return str(clip)
	return IDLE


## The single funnel. Everything the AI is doing collapses to one intent string.
##  - is_surrendered / is_crippled are FLAGS, not states (enemy_base.gd:129,1347)
##  - DEAD needs the hit direction, which _die() must pass in
static func intent_for(state: int, is_crippled: bool, is_surrendered: bool,
		is_firing: bool, speed: float) -> String:
	if is_surrendered:
		return "surrender"
	if is_crippled:
		return "crippled"

	match state:
		Enums.AIState.DEAD:
			return "death_forward"
		Enums.AIState.COMBAT:
			if is_firing:
				return "fire"
			if speed > 0.3:
				return "strafe"
			return "aim"
		Enums.AIState.SUPPRESSED:
			return "cover"
		Enums.AIState.SEEKING_COVER, Enums.AIState.FLANKING, Enums.AIState.ADVANCING:
			return "run"
		Enums.AIState.RETREATING:
			return "retreat"
		Enums.AIState.ALERT:
			# Walking to last_known_target_pos. (There is no INVESTIGATING state;
			# INVESTIGATE is an AIGoal, and it maps onto AIState.ALERT.)
			return "walk" if speed <= WALK_SPEED_MAX else "run"
		_:
			# IDLE: standing sentry, or walking a patrol route.
			if speed > 0.3:
				return "patrol"
			return "idle"
