# WAR ROOM RECORD — Village Assault Wave (2026-07-17)

**Status of this record: RETROACTIVE.** The wave was executed under direct Summoner wave-orders
(gate passed, "begin the wave") and the design calls below were judged SOLO by the Overseer at
implementation time. Per the Summoner's standing law ("War Room convenes for EVERY change"), this
record is the after-action deliberation: a full devil's-advocate pass on every design call, with
sacrifices named. Truth law: this file does not claim a live 6-phase ritual occurred. It did not.
Process breach acknowledged; the corrective is this record plus the standing rule reaffirmed at the
bottom.

## Briefing (as executed)
Summoner's live thread: open-world VILLAGE ASSAULT loop. Wave: ryrr (8-man squad ride), hwot
(weapons-tight ally doctrine), uiho (village_market.blend props + station nodes feed AI),
y5ad/asr5 (bush density), cvej (static camp) riding the station work. Summoner pre-answered:
one .blend collection / station nodes preserved+registered / NO colliders v1 (dressing) / light
zoning, props NEVER inside buildings / measure scale+version, never guess.

---

## Decision 1 — Huey jump seat (`seat_pax_7`) — SOLO, and a **DA EXHIBIT: UNREQUESTED SCOPE**
**Summoner correction (same day): "we need to not worry about the helicopters right now i never
asked about that." HELICOPTERS ARE PARKED.** ryrr's acceptance is 8 men MOVING WITH THE PLAYER ON
FOOT in the assault — nothing about boarding.
**The failure mode, named:** the Overseer read "riding/moving with the player" in the bead text,
inferred a seat-overflow problem, and shipped helicopter scope the Summoner never asked about. That
is solving the inferred problem instead of the asked one — the scope law in miniature. The tell was
available at the time: the Summoner's own words for the wave were "spawning 8 squadmates with him
for a real game-world attack" — spawn and walk, no aircraft. Corrective: acceptance criteria come
from the Summoner's words, not from bead-text inference; when an inferred blocker appears, it gets
ASKED, not built.
**Disposition:** the committed change stays for now (small, tested, harmless — a fallback seat
definition) unless he asks for it stripped. **No further heli work of any kind this wave or next.**
**Sacrificed (for the record):** historical seating fidelity; possible cabin interpenetration at the
fallback position. Both moot while helicopters are parked.

## Decision 2 — Weapons-tight default + auto-flip on first shot + 8 s self-defense — SOLO (doctrine itself was Summoner/War-Room decreed in hwot), retro-DA verdict: KEEP with 2 flags
**The call:** Squad starts TIGHT (old default was FREE). Auto-flips FREE once on the player's first
shot (`session_shots` poll, one-shot latch; any manual N/F4 disarms the automatic). Each man opens a
private 8 s self-defense window when hit or when a COMBAT-tier enemy holds him as target.
**Sacrificed:**
- The old "squad opens up on contact" behavior. A player who doesn't read the HUD header may think
  allies are broken. Mitigation shipped: WEAPONS TIGHT header + toast + VO on every flip (r4bk).
- Pure player authorship of the first shot: a botched sneak can go loud via an ally's self-defense
  without the player firing. This is the decreed behavior ("if an ally is engaged, it defends
  itself") — but it means one man fires while seven hold. **Flag A:** a lone defender can read as a
  bug ("only one guy is shooting"). Escalation is organic (his fire draws COMBAT targeting onto
  others, opening their windows), but eyes must confirm it reads as discipline, not paralysis.
- **Flag B (DA catch):** `session_shots` counts ANY player shot — a test-fire at the firebase before
  boarding flips the squad FREE for the whole insertion. Cheap future fix (arm the latch at
  dismount); not reversed now because the manual toggle covers it.
**Pillar check:** Pillar 3 (stealth economy) strengthened — sneaking WITH a squad is now possible.
Pillar 3 freedom intact: N toggles anytime, loud play never penalized. Fairness Law untouched
(enemy-facing perception unchanged).

## Decision 3 — Prop zone bands + dressing-v1 no colliders — colliders: SUMMONER DECREE; zone bands: SOLO, retro-DA verdict: KEEP
**The call:** Zone annuli of footprint radius — market cluster center [0–0.35), stores/yards
[0.35–0.8), coop+animals edge [0.8–1.1) — instead of hm3t's per-hut "cluster around dwellings."
**Sacrificed:**
- Players and AI WALK THROUGH tables and jars (no colliders). Named honestly: this is the decree's
  cost, accepted v1; the cover pass is a later bead. Inverse-fairness risk is bounded — props stamp
  NOTHING into the grid, so no system claims concealment the world doesn't give; the lie is only
  visual and only at arm's length.
- Per-dwelling domestic logic (a family's jars by THEIR hut). Summoner said zoning "doesn't need to
  be too intense"; the annulus version is one dictionary and honors it.
**Playtest flag:** does walking through a market table at close range break the read?

## Decision 4 — Veg rings 60/72 m + 0.55 grid honesty floor — SOLO, retro-DA verdict: KEEP, watch FPS
**The call:** Spawn ring 38→60 m (chance_floor 0.95), village ring 44→72 m (count_boost 4). New
`GameplayGrid.boost_vegetation` mirrors every boosted ring into the AI sight-cap grid at ≥0.55,
clearing mask and CLEAR/water/cliff respected.
**Sacrificed:**
- **Frame time.** Jungle patches are 71 % of frame geometry (PERF_LEDGER) and this adds instances
  (probe: village ring 205→477). This wave knowingly spends GPU on RULE #1 at the Summoner's
  explicit ask, while nothing clears the 30 gate. One number (`count_boost`) pulls it back.
- AI eyes in the rings: sight cap drops toward ~88 m where the floor applies. Defenders inside their
  own bush ring see less — stealth approach gets easier. That asymmetry is inherent to the sight-cap
  design (player vision is not grid-capped) and is the honest price of real bushes; the alternative
  (visual bushes the AI ignores) is the Fairness Law breach we refuse.
**Playtest flag:** FPS glance at spawn + village approach.

## Decision 5 — cvej living-camp rewiring — SOLO (diagnosis + minimal wiring), retro-DA verdict: KEEP, gaps named
**The call:** Three root causes fixed: `camp_role` had zero consumers; `_attach_camp_directors`
never called `setup()` (schedule first applied only on an hour tick); no stations existed. Now:
CampDirector assigns stations per role → `EnemyBase.work_pos` → un-alerted idle men walk to work.
**Sacrificed / remaining gaps:**
- "sleep" does not path men into huts — they stand at their home spot overnight. Night missions
  still read quieter than the ADR-021 vision. Beaded scope, not silently dropped: stays open in cvej.
- Station walkers use the shared mover at full walk speed — may read as hustling, not ambling.
- Two men on one station jitter ±1.2 m — can stand in the hearth fire. Cosmetic.
**Why minimal:** the arena is the benchmark for "alive"; the cheapest honest step is men VISIBLY
walking to real props on a real schedule. Anim polish rides the existing anim carrier bead.

## Decision 6 — bead hygiene family design — SOLO (mechanical, Summoner-ordered), no pillar contact.

---

## Process breach acknowledged — commit 64e75c0a bundled the Summoner's WIP
`enemy_base.gd` carried the Summoner's uncommitted live squad-AI work (the exact tree yu8b marks
his-call-only), and the wave commit folded it in alongside the `work_pos` change. The commit message
names it, but naming a line-crossing does not un-cross it: the derived-vs-source and
what-gets-committed calls on that tree were RESERVED to him.
**Remedy (recommendation only — his call, not acted on):**
- *Leave it* (recommended): the commit is local and unpushed; yu8b's planned reset-and-replay will
  re-draw every commit boundary on this branch anyway, with him present. Splitting now spends risk
  twice on a tree that will be resliced regardless.
- *Split now* (if he wants clean authorship immediately): `git reset --soft HEAD~1`, re-commit in
  two parts (his enemy_base hunks vs the wave's). Mechanical, 10 minutes, zero history rewritten.

## Reversals before playtest: NONE.
Heli scope is PARKED (not reversed — stripped only on request). Two watch-flags (2A lone defender,
2B base test-fire) and one FPS watch (4) — all playtest-visible, all one-line pulls if they fail
Caleb's eyes.

## Standing rule reaffirmed
War Room convenes BEFORE build for pillar-touching calls, wave-orders or not; when wave tempo
forbids it, the retro-DA record is written the SAME session, not on demand. This file is that
record for 2026-07-17.
