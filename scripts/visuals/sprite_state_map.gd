## sprite_state_map.gd - AIState (+ the flags that are not states) -> clip id.
##
## The clip set does not cover the state set, so every sprite entry is a FALLBACK
## CHAIN. resolve() must NEVER return a clip the unit lacks: it walks the chain
## and finally lands on rifle_aiming_idle, which every rendered unit carries.
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
	# Sprite renderers never got sprint/sneak/arrive art - nearest energy wins.
	"sprint": ["run_forward", "rifle_aiming_idle"],
	"sneak_l": ["stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"sneak_r": ["stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"arrive": ["rifle_aiming_idle"],
	# Low-posture family: sprites carry no crouch-walk loops, so the chain lands
	# on the crouch idle they DO have, then rifle_aiming_idle. Models take MODEL_CLIP.
	"crouch_idle": ["idle_crouching", "stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"crouch_aim": ["idle_crouching_aiming", "idle_crouching", "kneeling_pointing", "rifle_aiming_idle"],
	"crouch_fwd": ["walk_crouching_forward", "start_walking", "run_forward", "rifle_aiming_idle"],
	"crouch_l": ["walk_crouching_left", "stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"crouch_r": ["walk_crouching_right", "stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"crouch_back": ["walk_crouching_backward", "injured_walk_backwards", "rifle_aiming_idle"],
}

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


static func resolve(faction: String, unit: String, weapon: String, intent: String) -> String:
	var chain: Array = CHAINS.get(intent, [IDLE])
	for clip in chain:
		if SpriteLibrary.has_clip(faction, unit, weapon, str(clip)):
			return str(clip)
	return IDLE


## The single funnel: everything the AI is doing collapses to one intent string.
##  - is_surrendered / is_crippled are FLAGS, not states
##  - DEAD needs the hit direction, which _die() must pass in
static func intent_for(state: int, is_crippled: bool, is_surrendered: bool,
		is_firing: bool, speed: float, lateral: float = 0.0, sneaking: bool = false,
		low_posture: bool = false) -> String:
	var intent: String = _intent_core(state, is_crippled, is_surrendered, is_firing, speed, lateral, sneaking)
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


## Remap a standing-locomotion intent to its crouch-walk equivalent. Poses that
## are not locomotion (fire, cover, death, crippled, surrender, reload) pass
## through untouched. sprint/sneak_l/sneak_r stay upright: a rushing man is not
## low, and a sneaker already has the cover_sneak lateral clips.
static func _to_crouch(intent: String, speed: float, lateral: float) -> String:
	match intent:
		"run", "walk", "patrol", "aim_walk", "arrive", "start_walking":
			if speed <= 0.5:
				return "crouch_idle"
			if absf(lateral) > 0.6:
				return "crouch_l" if lateral > 0.0 else "crouch_r"
			return "crouch_fwd"
		"retreat":
			return "crouch_back"
		"idle":
			return "crouch_idle"
		"aim":
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


## Models carry all 21 authored clips, so they skip the sprite fallback CHAINS
## and map an intent straight to a clip they are guaranteed to have.
const MODEL_CLIP: Dictionary = {
	"idle": "rifle_aiming_idle", "aim": "rifle_aiming_idle",
	"fire": "firing_rifle", "reload": "reloading",
	"run": "run_forward",
	"walk": "walk_forward", "patrol": "walk_forward",
	"aim_walk": "walk_forward",  # dedicated aimed-walk clip on the art wishlist
	"strafe": "strafe", "strafe_l": "run_left", "strafe_r": "run_right",
	"cover": "kneeling_pointing",
	"retreat": "injured_walk_backwards", "crippled": "injured_walk_backwards",
	"surrender": "kneeling_pointing",
	"death_forward": "death_forward", "death_right": "death_from_right",
	"flinch": "rifle_aiming_idle",
	"sprint": "sprint_forward",
	"sneak_l": "cover_sneak_left", "sneak_r": "cover_sneak_right",
	"arrive": "run_to_stop",
	# Low-posture family (Track B2). Diagonals share the cardinal clips - the
	# standing side has no diagonal intents either, so this keeps parity.
	"crouch_idle": "idle_crouching", "crouch_aim": "idle_crouching_aiming",
	"crouch_fwd": "walk_crouching_forward", "crouch_back": "walk_crouching_backward",
	"crouch_l": "walk_crouching_left", "crouch_r": "walk_crouching_right",
}


## Rigs ship different clip GENERATIONS. ModelActor.play() consults this when the
## asked-for clip is missing, so a caller may ask in either generation's names and
## every rig answers.
const MODEL_ALIASES: Dictionary = {
	# strafe family (v1 has strafe/strafe_1; v2 has run_left/run_right)
	"run_left": ["strafe", "run_forward"],
	"run_right": ["strafe_1", "strafe", "run_forward"],
	# v1 name -> v2 equivalents
	"rifle_aiming_idle": ["idle_aiming", "idle"],
	"strafe": ["run_left", "run_forward"],
	"strafe_1": ["run_right", "run_forward"],
	"kneeling_pointing": ["idle_crouching_aiming", "idle_crouching"],
	"injured_walk_backwards": ["run_backward", "run_backward_left"],
	"death_forward": ["death_from_the_front"],
	"stand_to_cover": ["idle_crouching", "idle_crouching_aiming"],
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
}


static func model_clip_for(intent: String) -> String:
	return str(MODEL_CLIP.get(intent, "rifle_aiming_idle"))


## Per-weapon hold families. The funnel asks for "<clip>__<family>" first;
## ModelActor strips the suffix and falls back when the family clip does not
## exist, so new family clips light up the moment they land in the library.
## Rifle is the default hold = NO suffix.
const WEAPON_FAMILY: Dictionary = {
	"ppsh": "smg", "ppsh41": "smg", "thompson": "smg", "mat49": "smg",
	"mosin": "bolt", "kar98k": "bolt", "m70": "bolt",
	"m60": "mg", "rpd": "mg",
	"rpg": "launcher", "rpg2": "launcher", "rpg7": "launcher", "m72_law": "launcher",
	"m79": "launcher",
	"m1911": "pistol", "colt45": "pistol", "nagant": "pistol",
}


## One entry point both renderers use. is_model picks the model clip map (all 21
## clips present) vs the sprite fallback chain (only what was rendered).
static func clip_for(is_model: bool, faction: String, unit: String, weapon: String, intent: String) -> String:
	if is_model:
		var base: String = model_clip_for(intent)
		var family: String = str(WEAPON_FAMILY.get(weapon, ""))
		if not family.is_empty():
			return base + "__" + family
		return base
	return resolve(faction, unit, weapon, intent)
