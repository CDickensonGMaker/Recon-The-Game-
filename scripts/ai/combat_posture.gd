class_name CombatPosture
## Shared low-posture decision for BOTH factions (EnemyBase + AllyBase call this,
## so the contract can never drift between them). Crouch to hold, stand to push:
## holding/reacting/at-cover crouches; advancing/flanking/routing stands; a heavy
## pin crouches anyone. SEEKING_COVER crouches only once NEAR the cover point, so a
## man no longer commits the crouch/lean 10m out and crouch-drifts to the wall.
extends RefCounted

enum Posture { STAND, CROUCH, PRONE }

const CROUCH_SUPPRESS: float = 0.6   # a heavy pin crouches anyone, even mid-push
const SUPPRESS_PIN: float = 0.7      # engaged + above this = the SUPPRESSED freeze (both factions)
const COVER_CROUCH_RANGE: float = 3.0  # start crouching within this of the cover point

## PRONE (War Room 2026-07-31). A LATCH, not a per-frame decision: a man commits to
## the deck under a heavy pin and stays there while the pin lasts, so as suppression
## decays back through COMBAT he is still down and CAN return fire from it. That is
## what gives prone_firing_rifle a caller - _execute_suppressed is a pure freeze
## (enemy_base.gd:1598-1604) and a man who only went prone while SUPPRESSED would
## never fire a shot from the deck.
##
## ENTER sits ABOVE SUPPRESS_PIN deliberately. tests/test_low_posture.gd:52-59 asserts
## suppression 0.7 -> CROUCH on both factions - the 2026-07-23 faction-merge contract -
## and that assertion must keep passing untouched.
const PRONE_SUPPRESS_ENTER: float = 0.85
const PRONE_SUPPRESS_EXIT: float = 0.6
## How long the pin must HOLD before he commits. Going down is a 1.833 s animation;
## a man who face-plants for a single spike reads as a glitch.
const PRONE_ENTER_HOLD_S: float = 1.2
## The ceiling. THERE IS NO PRONE LOCOMOTION CLIP (measured - wounded_crawl is a
## casualty crawl, 36 degrees off), so a prone man cannot move, and a prone man who
## cannot get up is a man deleted from the firefight.
const PRONE_DWELL_MAX_S: float = 8.0

static func decide(state: int, suppression: float, near_cover: bool,
		prone_latched: bool = false) -> int:
	# The latch outranks everything: he is already on the ground.
	if prone_latched:
		return Posture.PRONE
	if suppression >= CROUCH_SUPPRESS:
		return Posture.CROUCH
	match state:
		Enums.AIState.ADVANCING, Enums.AIState.FLANKING, Enums.AIState.RETREATING:
			return Posture.STAND
		Enums.AIState.SUPPRESSED, Enums.AIState.COMBAT:
			return Posture.CROUCH
		Enums.AIState.SEEKING_COVER:
			return Posture.CROUCH if near_cover else Posture.STAND
		_:
			return Posture.STAND


## Should a man who is NOT yet down commit to the deck? Shared by both factions so
## the rule can never drift between them.
##
## A MOVING man never goes prone. That is not a nicety - there is no prone
## locomotion clip, so a prone man who still wants to move can only ice-skate.
static func wants_prone(state: int, suppression: float, moving: bool) -> bool:
	if moving:
		return false
	return state == Enums.AIState.SUPPRESSED and suppression >= PRONE_SUPPRESS_ENTER


## Must a man who IS down get up?
##
## THE WAY OUT MUST NEVER BE BLOCKED. Three independent releases - he wants to move,
## the pin lifted, or he has simply been down too long - because a prone man with no
## exit is the recorded bug class: he looks alive, he animates perfectly, and he has
## left the fight. Any ONE of them frees him.
static func must_rise(suppression: float, moving: bool, dwell_s: float) -> bool:
	return moving or suppression < PRONE_SUPPRESS_EXIT or dwell_s >= PRONE_DWELL_MAX_S
