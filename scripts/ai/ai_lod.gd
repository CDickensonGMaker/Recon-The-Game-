## ai_lod.gd - THE BEHAVIOURAL LOD. Summoner's ruling, 2026-09-09:
##
##   "make the assault waves just attack head on in two large waves that just run in a
##    straight line and shoot toward the firebase and the sappers are trying to break in
##    and than once an enemy npc gets within 40-80ms of the player the turn into a real
##    thinking enemy to attack the player"
##
## WHY IT EXISTS. The 45-man assault runs at ~2.7 fps and `ai.execute` is the dominant
## exclusive span in every measured window (2,650-3,010 ms per 5 s over ~4,408 calls =
## 0.60-0.68 ms PER MAN PER TICK). GPU is under a third of the frame. Forty-five men each
## paying a full tactical brain, a navmesh query, a per-frame animation decision and a
## firefight fire cadence is the cost, and forty of them are doing it where the player
## cannot read a single one of their decisions.
##
## WHAT IT IS NOT. It is not a sleep, a freeze, or a stand-in. ADR-026 Part B's hot-set
## already existed and was DEAD in this fight: HOT_CAP is 50 and the assault fields 45, so
## every man was hot and the tier never engaged. This gives the tier the axis it always
## needed - distance from the player - instead of a global headcount.
##
## THE THREE GUARDS (they are the design, not garnish):
##   1. THE HANDOFF MUST NOT BE VISIBLE. Promote at 80 m, demote past 105 m, and only
##      after DEMOTE_DWELL_S of quiet - a man cannot flicker across the band. Distance is
##      not the only promoter: anyone shooting at the player, shot BY the player or his
##      squad, or holding one of them as a target is a near man wherever he stands
##      (bounded by STICKY_MAX_M so the count stays finite).
##   2. CHEAP IS NOT ABSENT (Pillar 1). A far man walks his lane, goes to ground under
##      fire, fires toward the firebase in bursts, and dies convincingly. Suppression and
##      fear are what make a wave look like men rather than a queue and they are cheap -
##      they stay. What he stops paying for is the path query, the per-frame animation
##      decision, the per-frame look_at and the per-man tactical evaluation.
##   3. OUTCOMES STAY COHERENT. Nothing here touches take_damage, _die, _become_downed,
##      the casualty ledger, sapper charges or the wire. A cheap attacker still kills and
##      still dies. If the far tier changed who wins the siege it would be a different
##      game, not an optimisation.
##
## SAPPERS ARE EXEMPT. They are few and they are doing the one thing that decides the
## siege. `silent_infiltrator` is the marker (data/enemies/*_sapper.tres) and it is never
## demoted by distance.
class_name AILod
extends RefCounted

enum Tier { FAR = 0, NEAR = 1 }

## Promote here. His words were "40-80m"; 80 is the outer edge of that band, so the
## handoff has always happened by the time he could plausibly read a man's decisions.
const PROMOTE_M: float = 80.0
## Demote only past here. The 25 m gap IS the hysteresis - a man walking the boundary
## cannot oscillate between two brains.
const DEMOTE_M: float = 105.0
## ...and only after this long beyond DEMOTE_M with no player involvement. A man who
## breaks contact and runs 40 m keeps his brain long enough to finish what he started.
const DEMOTE_DWELL_S: float = 3.0
## The ceiling on stickiness. Past this, distance wins whatever he is doing - otherwise
## one squad adopting the player as a shared target promotes six men at 300 m and the
## promoted count is unbounded, which is the whole thing this is meant to bound.
const STICKY_MAX_M: float = 160.0
## How long a hit from the player's side keeps a man promoted after the fact.
const STICKY_MS: float = 6000.0
## How often a man re-decides his own tier. Staggered per man by instance hash so 45 of
## them never land on one physics frame.
const EVAL_INTERVAL_S: float = 0.25

## The near-tier roster: instance_id -> true. Membership changes only on a tier CHANGE,
## which is rare, so this costs nothing per frame. Read it with `promoted_count()`.
static var _near: Dictionary = {}
## The high-water mark for the run. THIS is the number that decides whether the design
## works, and it is measured, never assumed (the Summoner's standing ask, 2026-09-09).
static var peak_near: int = 0
## Sum/count for a mean across the run, so one spike cannot masquerade as the norm.
static var _census_sum: int = 0
static var _census_n: int = 0

## A/B switch. `--ai-lod-off` restores the pre-LOD behaviour - every man NEAR - so the
## before and the after come out of ONE build and cannot be two different games.
static var _enabled: bool = true
static var _flag_read: bool = false


## True while the LOD is live. Reads the command line ONCE, and says so on stdout: a
## measurement run whose log does not state which side of the A/B it is proves nothing
## (PERF WAVE 2026-09-08 - both probes read the document instead of the machine).
static func is_enabled() -> bool:
	if not _flag_read:
		_flag_read = true
		_enabled = not GameSettings.has_flag("--ai-lod-off")
		print("[AILOD] behavioural LOD %s | promote %.0fm / demote %.0fm / dwell %.1fs / sticky ceiling %.0fm"
			% ["ON" if _enabled else "OFF (--ai-lod-off: every man runs the full brain)",
				PROMOTE_M, DEMOTE_M, DEMOTE_DWELL_S, STICKY_MAX_M])
	return _enabled


## For tests and probes that must pin a side of the A/B without a command line.
static func force(on: bool) -> void:
	_flag_read = true
	_enabled = on


static func set_tier(who: Object, tier: int) -> void:
	if who == null:
		return
	var id: int = who.get_instance_id()
	if tier == Tier.NEAR:
		_near[id] = true
	else:
		_near.erase(id)


## Drop dead and freed men. Bounded by the live roster, and only ever called from the
## census (once per report), never from a per-man path.
static func _prune() -> void:
	for id in _near.keys():
		var o: Object = instance_from_id(int(id))
		if o == null or not is_instance_valid(o) or (o.has_method("is_dead") and o.is_dead()):
			_near.erase(id)


## HOW MANY MEN ARE THINKING RIGHT NOW. The answer to the Summoner's question.
static func promoted_count() -> int:
	_prune()
	return _near.size()


## Window-local, so a 5 s row reports what happened IN that window and not a single
## instant of it. A once-per-window sample would have missed every peak by construction
## - the same class of instrument defect as the spike catcher that averaged over its own
## one-second window (2026-09-09).
static var window_peak: int = 0
static var _window_sum: int = 0
static var _window_n: int = 0


## Take one census sample. Called EVERY FRAME by the FPS printer: pruning a roster
## bounded by the live enemy count is a few instance_from_id calls, and it is the only
## way the peak is real.
static func census() -> int:
	var n: int = promoted_count()
	peak_near = maxi(peak_near, n)
	window_peak = maxi(window_peak, n)
	_census_sum += n
	_census_n += 1
	_window_sum += n
	_window_n += 1
	return n


static func window_mean() -> float:
	return float(_window_sum) / float(maxi(1, _window_n))


static func flush_window() -> void:
	window_peak = 0
	_window_sum = 0
	_window_n = 0


static func mean_near() -> float:
	return float(_census_sum) / float(maxi(1, _census_n))


static func reset() -> void:
	_near.clear()
	peak_near = 0
	_census_sum = 0
	_census_n = 0
	flush_window()
