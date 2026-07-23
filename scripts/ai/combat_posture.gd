class_name CombatPosture
## Shared low-posture decision for BOTH factions (EnemyBase + AllyBase call this,
## so the contract can never drift between them). Crouch to hold, stand to push:
## holding/reacting/at-cover crouches; advancing/flanking/routing stands; a heavy
## pin crouches anyone. SEEKING_COVER crouches only once NEAR the cover point, so a
## man no longer commits the crouch/lean 10m out and crouch-drifts to the wall.
extends RefCounted

enum Posture { STAND, CROUCH }

const CROUCH_SUPPRESS: float = 0.6   # a heavy pin crouches anyone, even mid-push
const COVER_CROUCH_RANGE: float = 3.0  # start crouching within this of the cover point

static func decide(state: int, suppression: float, near_cover: bool) -> int:
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
