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
	# Sprite renderers never got sprint/sneak/arrive art - nearest energy wins.
	"sprint": ["run_forward", "rifle_aiming_idle"],
	"sneak_l": ["stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"sneak_r": ["stand_to_cover", "kneeling_pointing", "rifle_aiming_idle"],
	"arrive": ["rifle_aiming_idle"],
}

## Above this ground speed a man reads as SPRINTING (enemy move_speed is
## 4.0-4.4; only boosted movement - the numbers-press rush, the rout - gets
## here, so the sprint clip marks genuine urgency).
const SPRINT_SPEED_MIN: float = 4.6


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
		is_firing: bool, speed: float, lateral: float = 0.0, sneaking: bool = false) -> String:
	if is_surrendered:
		return "surrender"
	if is_crippled:
		return "crippled"

	match state:
		Enums.AIState.DEAD:
			return "death_forward"
		Enums.AIState.COMBAT:
			# War-room anim policy (Caleb): MOVEMENT OWNS THE LEGS. A moving
			# man never plays the stationary fire pose (that was the gliding-
			# statue bug) - muzzle flash/tracers sell the shooting; the fire
			# clip is only for a planted man. Still = aim; lateral-and-slow =
			# strafe (L/R honest); slow forward = aim-walk; fast = run.
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
			# The rush reads as a RUSH: boosted movement (numbers-press bounds)
			# plays the sprint family. A cautious unshot approach SNEAKS -
			# lateral sneak clips by direction; no forward-sneak loop is
			# authored yet, so slow forward reads as the walk.
			if speed > SPRINT_SPEED_MIN:
				return "sprint"
			if sneaking:
				if absf(lateral) > 0.7:
					return "sneak_l" if lateral > 0.0 else "sneak_r"
				if speed <= WALK_SPEED_MAX:
					return "walk"
			return "run"
		Enums.AIState.RETREATING:
			# A ROUTED man (boosted flight) sprints for the rear; the tactical
			# withdrawal keeps the wary backward hobble.
			return "sprint" if speed > SPRINT_SPEED_MIN else "retreat"
		Enums.AIState.ALERT:
			# Walking to last_known_target_pos. (There is no INVESTIGATING state;
			# INVESTIGATE is an AIGoal, and it maps onto AIState.ALERT.)
			return "walk" if speed <= WALK_SPEED_MAX else "run"
		_:
			# IDLE: standing sentry, or walking a patrol route.
			if speed > 0.3:
				return "patrol"
			return "idle"

## Models carry all 21 authored clips, so they skip the sprite fallback CHAINS
## and map an intent straight to a clip they are guaranteed to have.
const MODEL_CLIP: Dictionary = {
	"idle": "rifle_aiming_idle", "aim": "rifle_aiming_idle",
	"fire": "firing_rifle", "reload": "reloading",
	"run": "run_forward",
	# T1.6: the walk band plays an actual walk cycle now (the library ships a
	# full walk_* family) - run_forward at walk speed was half the skating.
	"walk": "walk_forward", "patrol": "walk_forward",
	"aim_walk": "walk_forward",  # dedicated aimed-walk clip on the art wishlist
	"strafe": "strafe", "strafe_l": "run_left", "strafe_r": "run_right",
	"cover": "kneeling_pointing",
	"retreat": "injured_walk_backwards", "crippled": "injured_walk_backwards",
	"surrender": "kneeling_pointing",
	"death_forward": "death_forward", "death_right": "death_from_right",
	"flinch": "rifle_aiming_idle",
	# 2026-07-12 audit wiring: the library authored these; nothing asked.
	"sprint": "sprint_forward",
	"sneak_l": "cover_sneak_left", "sneak_r": "cover_sneak_right",
	"arrive": "run_to_stop",
}


## Rigs ship different clip generations (us_grunt v1: rifle_aiming_idle/
## strafe/kneeling_pointing; us_grunt_v2: idle_aiming/run_left/idle_crouching).
## ModelActor.play() consults this when the asked-for clip is missing, so any
## caller can ask in either generation's names and every rig answers.
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


## Per-weapon hold families (Caleb: "the way I'd hold the PPSh is different
## than the Mosin"). The funnel asks for "<clip>__<family>" first; ModelActor
## strips the suffix and falls back when the family clip does not exist yet -
## so Batch 7 clips (bead ou5q) light up the moment they land in the library,
## zero further engine work. Rifle is the default hold = no suffix.
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
