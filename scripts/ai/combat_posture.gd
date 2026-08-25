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

## THE FIRE CEILING, one value for both factions. A suppressed man fires WORSE and
## WILDER, he does not go silent - a silent squad is a disarmed squad. Above this he is
## face-down (PRONE_SUPPRESS_ENTER) and the freeze owns him.
const SUPPRESS_FIRE_CEILING: float = 0.85

## Cover multiplies BOTH sides of the suppression ledger (Company of Heroes doctrine):
## a man behind something fills slower and empties faster, so four metres of movement
## is a tactical decision. cover01: 0 = open ground, 1 = hard cover.
const SUPPRESS_ACCRUAL_OPEN: float = 1.35
const SUPPRESS_ACCRUAL_COVERED: float = 0.35
const SUPPRESS_RECOVERY_OPEN: float = 0.7
const SUPPRESS_RECOVERY_COVERED: float = 3.0

## Grace on a fresh pin (CoH gives 4 s): rounds aimed at a newly-pinned man fly wide, so
## being pinned buys a beat to plan instead of being a death sentence (Pillar 5).
## Symmetric - both factions grant it and both receive it.
const PIN_MERCY_S: float = 4.0
const PIN_MERCY_SPREAD: float = 2.2


static func suppress_accrual_mult(cover01: float) -> float:
	return lerpf(SUPPRESS_ACCRUAL_OPEN, SUPPRESS_ACCRUAL_COVERED, clampf(cover01, 0.0, 1.0))


static func suppress_recovery_mult(cover01: float) -> float:
	return lerpf(SUPPRESS_RECOVERY_OPEN, SUPPRESS_RECOVERY_COVERED, clampf(cover01, 0.0, 1.0))


## Decay is throttled while rounds still crack past: within CRACK_RECENT_S of the last
## suppression event a man sheds at CRACK_DECAY_MULT of the full rate (covered 0.9/s
## -> ~0.15/s), so the FEAR gate (>0.25) HOLDS between bursts of recurring fire
## instead of toggling every 0.4-1.2s fire pause (War Room 2026-08-24 Phase 1).
const CRACK_RECENT_S: float = 2.0
const CRACK_DECAY_MULT: float = 0.17


static func suppress_decay_recency_mult(last_crack_ms: float, now_ms: float) -> float:
	if now_ms - last_crack_ms < CRACK_RECENT_S * 1000.0:
		return CRACK_DECAY_MULT
	return 1.0


## How much wider a suppressed man's cone gets. x1 calm -> x3.2 at the fire ceiling.
static func suppress_spread_mult(suppression: float) -> float:
	return 1.0 + clampf(suppression, 0.0, 1.0) * 2.6


## The shooter's side of the mercy window: widen the cone at a target who was pinned
## within the last PIN_MERCY_S. `pinned_since_ms` <= 0 means he is not pinned.
static func pin_mercy_mult(pinned_since_ms: float, now_ms: float) -> float:
	if pinned_since_ms <= 0.0:
		return 1.0
	if now_ms - pinned_since_ms >= PIN_MERCY_S * 1000.0:
		return 1.0
	return PIN_MERCY_SPREAD

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
## LOW COVER IS PRONE COVER. A felled tree is a real hard_surface collider (tree_break_
## system.gd:450-463) whose capsule tops out about 0.85m, and a cover ray cast from a
## standing 1.3m eye passes clean over it - so timber that stops rounds was never once
## claimed. Measured: 5 logs inside the squad's reach, 0 of 4 men on one.
##
## A man who has taken low cover goes DOWN, whatever his suppression. That is the whole
## difference between a log being cover and being scenery.
static func wants_prone(state: int, suppression: float, moving: bool,
		at_low_cover: bool = false) -> bool:
	if moving:
		return false
	if at_low_cover and state != Enums.AIState.ADVANCING and state != Enums.AIState.FLANKING:
		return true
	return state == Enums.AIState.SUPPRESSED and suppression >= PRONE_SUPPRESS_ENTER


## Must a man who IS down get up?
##
## THE WAY OUT MUST NEVER BE BLOCKED. Three independent releases - he wants to move,
## the pin lifted, or he has simply been down too long - because a prone man with no
## exit is the recorded bug class: he looks alive, he animates perfectly, and he has
## left the fight. Any ONE of them frees him.
static func must_rise(suppression: float, moving: bool, dwell_s: float) -> bool:
	return moving or suppression < PRONE_SUPPRESS_EXIT or dwell_s >= PRONE_DWELL_MAX_S
