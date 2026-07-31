## sprite_state_map.gd - AIState (+ the flags that are not states) -> clip id.
##
## The clip set does not cover the state set, so every sprite entry is a FALLBACK
## CHAIN. resolve() must NEVER return a clip the unit lacks: it walks the chain
## and finally lands on rifle_aiming_idle, which every rendered unit carries.
class_name SpriteStateMap
extends RefCounted

const IDLE := "rifle_aiming_idle"


## Above this ground speed (m/s) a man reads as SPRINTING. Enemy move_speed is
## 4.0-4.4, so only BOOSTED movement (the rush, the rout) reaches here.
const SPRINT_SPEED_MIN: float = 4.6


## Speed below which "running" reads as a walk. Enemy move_speed is 4.0-4.4 m/s.
const WALK_SPEED_MAX: float = 2.6


## Above this ground speed, low-posture is IGNORED: a man moving faster than a
## crouch-walk stays upright (a rush or a rout reads as aggression, not caution).
## This is the kinematic backstop the War Room named - crouch cannot leak onto a
## fast push no matter how the low_posture flag is keyed.
const LOW_POSTURE_SPEED_MAX: float = 2.6



## The single funnel: everything the AI is doing collapses to one intent string.
##  - is_surrendered / is_crippled are FLAGS, not states
##  - DEAD needs the hit direction, which _die() must pass in
static func intent_for(state: int, is_crippled: bool, is_surrendered: bool,
		is_firing: bool, speed: float, lateral: float = 0.0, sneaking: bool = false,
		low_posture: bool = false, prone: bool = false) -> String:
	var intent: String = _intent_core(state, is_crippled, is_surrendered, is_firing, speed, lateral, sneaking)
	# PRONE outranks crouch: he is already on the ground. Added as its own flag rather
	# than by widening low_posture to an int, so every existing crouch assertion in
	# tests/test_low_posture.gd keeps passing unchanged.
	if prone:
		return _to_prone(intent)
	# Low-posture swap: a slow, cautious/pinned man moves in a crouch. Gated on
	# speed so a fast push (sprint/rout) can NEVER be dragged low - aggression
	# stays the default. The caller decides WHEN low_posture is on (where the
	# suppression/alert-tier signals live); this only decides HOW it looks.
	if low_posture and speed <= LOW_POSTURE_SPEED_MAX:
		return _to_crouch(intent, speed, lateral)
	return intent


static func _intent_core(state: int, is_crippled: bool, is_surrendered: bool,
		is_firing: bool, speed: float, lateral: float = 0.0, sneaking: bool = false) -> String:
	if is_surrendered:
		return "surrender"
	if is_crippled:
		return "crippled"

	match state:
		Enums.AIState.DEAD:
			return "death_forward"
		Enums.AIState.COMBAT:
			# MOVEMENT OWNS THE LEGS: a MOVING man must never play the stationary
			# fire pose (he would glide). Muzzle flash/tracers sell the shooting;
			# the fire clip is only for a planted man. Still = aim; lateral-and-
			# slow = strafe; slow forward = aim-walk; fast = run.
			if speed <= 0.5:
				return "fire" if is_firing else "aim"
			if speed <= 3.2 and absf(lateral) > 0.7:
				return "strafe_l" if lateral > 0.0 else "strafe_r"
			if speed <= 3.2:
				return "aim_walk"
			return "run"
		Enums.AIState.SUPPRESSED:
			return "cover"
		Enums.AIState.SEEKING_COVER, Enums.AIState.FLANKING, Enums.AIState.ADVANCING:
			# Boosted movement plays the sprint family; a cautious unshot approach
			# SNEAKS. No forward-sneak loop is authored, so slow forward walks.
			if speed > SPRINT_SPEED_MIN:
				return "sprint"
			if sneaking:
				if absf(lateral) > 0.7:
					return "sneak_l" if lateral > 0.0 else "sneak_r"
				if speed <= WALK_SPEED_MAX:
					return "walk"
			return "run"
		Enums.AIState.RETREATING:
			# A ROUTED man sprints for the rear; a tactical withdrawal keeps the
			# wary backward hobble.
			return "sprint" if speed > SPRINT_SPEED_MIN else "retreat"
		Enums.AIState.ALERT:
			# Walking to last_known_target_pos. There is NO INVESTIGATING state -
			# INVESTIGATE is an AIGoal, and it maps onto AIState.ALERT.
			return "walk" if speed <= WALK_SPEED_MAX else "run"
		_:
			# IDLE: standing sentry, or walking a patrol route.
			if speed > 0.3:
				return "patrol"
			return "idle"


## Remap a standing intent to its crouch equivalent (locomotion, aim/fire, and
## the suppressed "cover" hunker). death/crippled/surrender pass through
## untouched. sprint/sneak_l/sneak_r stay upright: a rushing man is not low, and
## a sneaker already has the cover_sneak lateral clips.
static func _to_crouch(intent: String, speed: float, lateral: float) -> String:
	match intent:
		"run", "walk", "patrol", "aim_walk", "arrive":
			if speed <= 0.5:
				return "crouch_idle"
			if absf(lateral) > 0.6:
				return "crouch_l" if lateral > 0.0 else "crouch_r"
			return "crouch_fwd"
		"retreat":
			return "crouch_back"
		"idle":
			return "crouch_idle"
		"aim", "fire":
			return "crouch_aim"
		"cover":
			# SUPPRESSED resolves to "cover" at any speed; a DISPLACING suppressed
			# man must crouch-move, not glide in a planted kneel. Still = hunker.
			if speed <= 0.5:
				return "crouch_idle"
			if absf(lateral) > 0.6:
				return "crouch_l" if lateral > 0.0 else "crouch_r"
			return "crouch_fwd"
		_:
			return intent


## Remap a standing intent to its PRONE equivalent. Deliberately narrow: prone is a
## STATIONARY posture, because the library carries no prone locomotion clip and
## wounded_crawl is a hands-and-knees casualty crawl (measured 36 degrees off the
## prone hip line), not a soldier crawling to a firing position.
##
## Anything that implies MOVEMENT passes through STANDING and unchanged. The caller
## is expected to have dropped the latch already - CombatPosture.must_rise() releases
## on `moving` - so this is the second line of defence, not the first. Getting it
## wrong does not freeze a man; it makes him stand up, which is recoverable.
## death / crippled / surrender pass through untouched: dying outranks posture.
static func _to_prone(intent: String) -> String:
	match intent:
		"idle", "patrol", "cover", "arrive":
			return "prone_idle"
		"aim", "aim_walk":
			return "prone_aim"
		"fire":
			return "prone_fire"
		_:
			return intent


## Models carry all 21 authored clips, so they skip the sprite fallback CHAINS
## and map an intent straight to a clip they are guaranteed to have.
const MODEL_CLIP: Dictionary = {
	"idle": "idle_aiming", "aim": "idle_aiming",
	"fire": "firing_rifle",
	"run": "run_forward",
	"walk": "walk_forward", "patrol": "walk_forward",
	"aim_walk": "walk_forward",  # dedicated aimed-walk clip on the art wishlist
	"strafe": "strafe", "strafe_l": "run_left", "strafe_r": "run_right",
	"cover": "kneeling_pointing",
	"retreat": "injured_walk_backwards", "crippled": "wounded_crawl",
	"surrender": "kneeling_pointing",
	"death_forward": "death_forward", "death_right": "death_from_right",
	"death_left": "death_from_the_left",
	"sprint": "sprint_forward",
	"sneak_l": "cover_sneak_left", "sneak_r": "cover_sneak_right",
	"arrive": "run_to_stop",
	# Low-posture family (Track B2). Diagonals share the cardinal clips - the
	# standing side has no diagonal intents either, so this keeps parity.
	"crouch_idle": "idle_crouching", "crouch_aim": "idle_crouching_aiming",
	"crouch_fwd": "walk_crouching_forward", "crouch_back": "walk_crouching_backward",
	"crouch_l": "walk_crouching_left", "crouch_r": "walk_crouching_right",
	# Prone family (War Room 2026-07-31). prone_idle carries both the hunker and the
	# aim: there is no separate prone aiming pose, and the man is already behind his
	# sights. The two transitions are ONE-SHOTS and are asked for by name, never
	# through an intent - see the timed-window latch on the AI side.
	"prone_idle": "prone_idle", "prone_aim": "prone_idle",
	"prone_fire": "prone_firing_rifle",
	"to_prone": "crouch_to_prone", "from_prone": "prone_to_crouch",
}


## Rigs ship different clip GENERATIONS. ModelActor.play() consults this when the
## asked-for clip is missing, so a caller may ask in either generation's names and
## every rig answers.
const MODEL_ALIASES: Dictionary = {
	# strafe family (v1 has strafe; v2 has run_left/run_right)
	"run_left": ["strafe", "run_forward"],
	"run_right": ["strafe", "run_forward"],
	# v1 name -> v2 equivalents
	"rifle_aiming_idle": ["idle_aiming", "idle"],
	"strafe": ["run_left", "run_forward"],
	"kneeling_pointing": ["idle_crouching_aiming", "idle_crouching"],
	"injured_walk_backwards": ["run_backward", "run_backward_left"],
	"wounded_crawl": ["injured_walk_backwards", "walk_crouching_forward"],
	"death_forward": ["death_from_the_front"],
	"death_from_the_left": ["death_from_right", "death_from_the_front", "death_forward"],
	"stand_to_cover": ["idle_crouching", "idle_crouching_aiming"],
	"cover_to_stand": ["cover_to_stand_2", "idle_aiming"],
	"start_walking": ["run_forward"],
	# v2 name -> v1 equivalents
	"walk_forward": ["start_walking", "run_forward"],  # v1 rigs have no walk loop
	"idle": ["rifle_aiming_idle"],
	"idle_aiming": ["rifle_aiming_idle"],
	"idle_crouching": ["kneeling_pointing"],
	"idle_crouching_aiming": ["kneeling_pointing"],
	"run_backward": ["injured_walk_backwards"],
	"death_from_the_front": ["death_forward"],
	"sprint_forward": ["run_forward"],
	"falling_to_roll": ["stand_to_cover", "kneeling_pointing"],
	# A rig with no prone set degrades to its lowest posture rather than T-posing.
	"prone_idle": ["idle_crouching", "kneeling_pointing"],
	"prone_firing_rifle": ["idle_crouching_aiming", "idle_crouching", "kneeling_pointing"],
	"crouch_to_prone": ["idle_crouching", "kneeling_pointing"],
	"prone_to_crouch": ["idle_crouching", "kneeling_pointing"],
}


## The default must be a clip the shipped library actually CARRIES. `rifle_aiming_idle` is a
## v1 rig name that survives only through MODEL_ALIASES, so an unmapped intent spent a
## resolution hop to land where `idle_aiming` was all along.
static func model_clip_for(intent: String) -> String:
	return str(MODEL_CLIP.get(intent, "idle_aiming"))


## Per-weapon hold families. The funnel asks for "<clip>__<family>" first;
## ModelActor strips the suffix and falls back when the family clip does not
## exist, so new family clips light up the moment they land in the library.
## Rifle is the default hold = NO suffix.
const WEAPON_FAMILY: Dictionary = {
	"ppsh": "smg", "ppsh41": "smg",
	"mosin": "bolt", "m70": "bolt",
	"m60": "mg", "rpd": "mg",
	"rpg": "launcher", "rpg2": "launcher", "rpg7": "launcher", "m72_law": "launcher",
	"m79": "launcher",
	"m1911": "pistol", "colt45": "pistol", "nagant": "pistol",
}


## One entry point both renderers use. is_model picks the model clip map (all 21
## clips present) vs the sprite fallback chain (only what was rendered).
static func clip_for(is_model: bool, weapon: String, intent: String) -> String:
	if not is_model:
		return IDLE  # capsule fallback has no clips (ADR-001: the sprite renderer is dead)
	var base: String = model_clip_for(intent)
	var family: String = str(WEAPON_FAMILY.get(weapon, ""))
	if not family.is_empty():
		return base + "__" + family
	return base
