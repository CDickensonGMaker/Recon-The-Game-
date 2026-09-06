# ADR-006 — AMENDMENT B: The mission score is RE-HOSTED, not repealed. HQ is the faucet.

**Date:** 2026-09-06 · **Status:** ACCEPTED (Summoner decree, THE RPG PIVOT) ·
**Amends:** ADR-006 (the scalar), ADR-032 (what feeds `reputation`) ·
**Depends on:** ADR-019 (the province ledger already outranks the score), ADR-038 (the factions who now
speak it), ADR-029 §Q1 (the ratified "rank clock = completed patrols" default this promotes) ·
**War Room:** `production/war_room/2026-09-06_rpg_pivot/`

---

## Context

The Summoner ruled on 2026-09-06 that the ADR-006 mission score is **retired**. The score had already
been dismantled from three directions without anyone finishing the job:

- **ADR-019** demoted it — *"the mission score is a receipt; the province ledger is the game."*
- **ADR-032** stripped it of every visible number and turned the banked total into hidden reputation.
- **ADR-029** deleted the screen it was displayed on.

What survived was an orphan: a scalar nothing shows, computed by a function whose terms teach a
philosophy the game no longer holds. His ruling finishes it, and relocates the moral:

> **Fire discipline near a ville IS allegiance. Body count becomes HQ's *opinion*, not a law of the
> universe.**

## Decision

### 1 · RE-HOSTED, NOT REPEALED — say it this way in the record

> **ADR-006 is not being deleted. Its SCALAR dies; its SENSOR lives.**

`MissionState`'s contact ledger — `contacts_detected`, `_detected_groups`
(`mission_state.gd:105-110`) — keeps running exactly as built. It becomes the **conduct sensor** that
ADR-038's four faction lenses read. What is deleted is the conversion of those counters into a single
banked number the player can feel himself optimising.

**This distinction is load-bearing.** "Retired" reads to a future agent as *"delete the ledger"* — and
the ledger is the instrument everything in ADR-038 depends on. Delete it and the factions have nothing
to read.

### 2 · THE FAUCET MUST BE REPLACED, NOT REMOVED — and it feeds THREE consumers, not two

`compute_score()` banks 1:1 into `CampaignState.reputation` via `bank_reputation`, at two call sites
(`field_director.gd` at the wire, `game_flow.gd` at mission end). Standing on that faucet:

1. **Rank** — the title the player is addressed by (ADR-032).
2. **The armory rack** — `rack_for_tier(CampaignState.title_tier())`.
3. **The fire-support allotment** — `field_director.gd:1512-1518` gates it on `title_tier()`.
   **This third consumer was not in the decree's own accounting.** Retiring the score without naming a
   replacement would freeze the player at PVT *and permanently deny him fast movers* — a silent,
   catastrophic break in the shipping demo's most spectacular system.

### 3 · HQ IS THE FAUCET

The synthesis runs in both directions. If the factions are the readout for the world, then **the
faction that owns promotion is the one that pays it.** Rank stops being a score and becomes what it
actually is in an army: **your commander's opinion of you.**

```
FieldDirector._bank_patrol()
  -> HQOpinion.assess(result) -> int      # replaces DebriefScreen.compute_score
  -> CampaignState.bank_reputation()      # UNCHANGED
```

`HQOpinion.assess()` pays:

| Term | Value | Rationale |
|---|---|---|
| the excursion was committed at the wire | **the base grant** | ADR-029's own ratified Q1 default — *"rank clock = completed patrols."* **This is already canon; it is being promoted, not invented.** |
| ground covered (distinct 25m sectors) | small | already accumulated and already reported; ADR-029 Amendment C's *"reported, not yet priced"* finally prices |
| route marks walked | small | already banked |
| you brought your men back | modest | Pillar 4, and it is HQ's honest concern |
| POW lost | large negative | already a term |
| **enemy KIA** | **ZERO** | see §4 |

**Cost: a ~30-line function replacing a ~10-line one, at the same two call sites, in the same shape.
Code only, zero art-days.** Touched: `tests/test_reputation.gd`, `tools/probe_config.gd`, `debrief.gd`.

### 4 · THE LINE THAT STOPS THE OLD DISEASE COMING BACK

The decree says *"body count becomes HQ's opinion."* Read carelessly that says: HQ's opinion pays rank,
HQ likes bodies, **therefore rank pays kills** — and `kills × 10` walks back through the exact door
ADR-006 was written to shut. Because rank buys the armory *and* the fast movers, a kill-paying rank
clock would make loud play the optimal progression strategy outright, breaching ADR-006, Pillar 3, and
the standing law in one move.

> ## **BODY COUNT MAY MOVE HQ'S WORDS. IT MAY NEVER MOVE HQ'S GRANT.**

HQ can be delighted with you, say so, and still promote you on patrols walked. That is not a fudge —
it is the texture of the real thing: **the brass loves the number and promotes on time in grade.** The
rank clock is the committed patrol; the body count is dialogue. Same faction, two channels, and only
one of them is a faucet.

### 5 · THE RATCHET STAYS

A sour HQ pays **zero**; it never demotes. Reputation floors at 0 as before. Demotion would strand the
player *below his own armory tier* — his rifle would vanish off the rack between patrols — and there is
no design in which that is the intended experience.

### 6 · WHAT ADR-006 KEEPS

Its **moral**, verbatim and unchanged: *"loud play stays viable; it stops being the optimal XP
strategy. No mechanic may gate on stealth — the economy prices it, nothing forbids the gun."*
That sentence is now enforced by §4 rather than by a scoring term.

## Consequences

**Bought.** The last on-screen-invisible scalar in the game stops existing. Progression becomes
diegetic — you are promoted by a man with an opinion, not by an arithmetic you cannot see. ADR-029's
ratified rank-clock default finally becomes the actual mechanism instead of a Q-default nobody
implemented. And the contact ledger is redeployed from feeding a dead number to feeding the factions.

**Sacrificed — no free lunches.**

- **The player loses a legible sense of "how am I doing."** He had one only in the abstract (the score
  was already invisible), but the *designers* lose it too — a hidden economy fed by a new function is
  harder to reason about, and the probe carries that weight.
- **Pacing must be re-tuned.** ADR-032's curve was calibrated against *"a decent patrol banks ~150."* A
  patrol-committed base grant is a different distribution, and rank pacing will drift until re-measured.
  **`rep_for_level`'s two constants are the dial — never a UI meter.**
- **HQ becomes a load-bearing character** before ADR-038's faction system exists, so the first
  implementation is a function named after a man who is not in the game yet.
- **A future agent may read "retired" and delete the sensor.** §1 exists to prevent exactly that and
  may not be dropped from this record.

## Evidence

- Summoner decree 2026-09-06; council record `production/war_room/2026-09-06_rpg_pivot/`, specification
  in `analysis/systems_designer.md`.
- `scripts/missions/field_director.gd:1512-1518` — fire-support allotment gated on `title_tier()`
  (the third, previously uncounted consumer; verified this session).
- `scripts/missions/mission_state.gd:105-110` — the contact ledger that survives as the sensor (verified).
- `production/adr/ADR-029-open-patrol-simulator.md:51` — Q1 default, *"rank clock = completed patrols"*
  (ratified 2026-08-04).
- `production/adr/ADR-032-player-reputation-titles.md` — the three lanes standing on this faucet.
- `production/adr/ADR-019-hearts-and-minds.md` §5 — the demotion this amendment completes.

## Related

- **ADR-038** — the factions who speak what the score used to count.
- **ADR-019** — the ledger that outranks it, and always did.
- **ADR-032** — rank and armory; unchanged in shape, re-fed at the source.
- **Pillars served:** 3 (Freedom — loud stays viable and stays sub-optimal), 4 (the squad is the RPG —
  bringing men home is now paid), 5 (Fail forward).
