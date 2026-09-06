# ADR-040: Lethality is not negotiable — the DOWN state gets verbs, not the health pool more points

**Date:** 2026-09-06 · **Status:** ACCEPTED as canon; **POST-DEMO — BUILD NOTHING** (Summoner decree,
THE RPG PIVOT, under his own scope wall) ·
**Reaffirms:** Pillar 1 · ADR-016 (one damage grammar) · the headshot law · his own lethality ruling of
2026-08-04 · **Amends:** nothing — this ADR exists to *prevent* an amendment ·
**War Room:** `production/war_room/2026-09-06_rpg_pivot/`

---

## Context

In the 2026-09-06 pivot conversation the Summoner asked for **the player to be more durable — less
instant-death.** The request is honest and its cause is real: dying instantly to a shooter you never saw,
with no save nearby, is the least fun the game currently produces.

**The Arbiter pushed back**, and this ADR records why, because the reasoning must survive the session:

- Pillar 1 is *"HLL lethality; death from **situation**, never bullet sponges / hit-point math."* A
  bigger player health pool is hit-point math and nothing else.
- It reverses **his own lethality ruling of 2026-08-04.**
- ADR-016's flat base × zone grammar is deterministic and shared by every actor. Raising the player's
  pool means the same bullet means two different things depending on who it hits — the beginning of the
  parallel damage path ADR-016 exists to forbid.
- The headshot law would have to be carved out, or it would become the only thing that kills the player,
  which is *worse* — it makes every death feel arbitrary rather than earned.

**He accepted the counter-proposal.** This ADR is that counter-proposal, recorded as law.

## Decision

### 1 · THE HEALTH POOL DOES NOT MOVE. THE HEADSHOT LAW DOES NOT MOVE.

ADR-016 stands unamended: **one damage grammar, flat base × zone, deterministic, no dice and no parallel
damage path.** No player-specific damage multiplier, no damage reduction curve, no "second wind" hit
points, no regenerating buffer. **A future request to make the player tougher is answered with this ADR,
not with a number.**

### 2 · THE FOUR THINGS THAT ANSWER HIS ACTUAL COMPLAINT

The complaint was never *"I want more hit points."* It was *"dying costs me too much and tells me too
little."* Four answers, none of which touches damage:

1. **Save anywhere** (ADR-039 §7 / ADR-007 Amendment A) removes most of the pain. **Most of his problem
   is a save problem wearing a lethality costume.**
2. **Extend the DOWN state** — §3 below.
3. **The Fairness Law's near-miss must actually fire** — §4 below.
4. **Turn the muzzle flash up** — a shooter you never saw is a *telegraphing* failure, not a damage
   failure. The Fairness Law already requires that flash, tracers and voices always telegraph.
   *(In progress by the Summoner's own hand, this session.)*

### 3 · "EXTEND THE DOWN STATE" MEANS GIVE IT VERBS — IT IS ALREADY LONG ENOUGH

**The measured finding, and it changes the shape of the work:** the down state already exists and is
already about thirty tense seconds. **It simply has zero verbs.** `_collapse_camera`
(`scripts/player/player.gd:1922-1945`) kills physics, input and unhandled-input outright; the viewmodel
is hidden; and `is_dead()` returns true while downed, so the AI correctly de-targets you.

So the player is not dying too fast. **He is spending thirty seconds as furniture.** That is the defect.

**The ruling: restore agency, not time.**

- **BUILD: LOOK and VOICE.** Restore **camera look only** — he can turn his head, watch the fight he is
  no longer in, see whether Doc is coming — plus **a call** that re-points the medic. That is the whole
  first version. It is cheap, it is tense, and it is Pillar 4 by geometry: *the squad is the RPG, and
  this is the moment the squad is the only thing that matters.*
- **DO NOT BUILD: the sidearm.** A downed man who can shoot but cannot be shot is a turret. Fixing that
  (making him targetable) collapses the thirty-second window into nothing, which is the opposite of the
  decree.
- **DO NOT BUILD: crawl — and know why.** Crawling is **a reversal of his own 2026-08-24 "drop down and
  lay in place" ruling**, not an extension of it. It needs his explicit word before anyone writes it.

### 4 · THE FAIRNESS LAW — VERIFIED FIRING, WITH ONE REAL HOLE

The decree required this be checked rather than assumed. It was, by reading the code and its probes:

**VERDICT: IMPLEMENTED, WIRED ON BOTH SHOOTER PATHS, AND PROBE-COVERED.**

- `scripts/combat/ai_marksmanship.gd:53-60` — `_first_shot_nudge()`, a deliberate **5–9° miss biased
  high and wide**; applied at `:94-96` inside `aim_with_spread()`, gated on
  `force_first_miss and is_player_target`.
- Enemy wiring `scripts/enemies/enemy_base.gd:2417-2420`, re-armed at `:1313`
  (*"new fight, new warning shot"*). Allies share the path at `scripts/allies/ally_base.gd:2039-2041`.
- The law's other half is live too: `ai_marksmanship.gd:68-77` ramps spread ×2.4 fresh → ×1.0 converged
  with player exposure, per archetype — **and the cap breathes with the ramp** (`:90`), a past defect
  where a capped cone made the opening volley as lethal as the converged one.
- Probes: `tests/test_firefight_len.gd:62,80-82` (first-shot deviation ≥ 5°) and
  `tests/test_ai_fairness.gd:52-62` (ramp endpoints and monotonicity).

**THE HOLE, named because it is exactly the case the law was written for:**

> The trigger is **the shooter entering COMBAT**, not **the player being unaware.** So a shooter
> **already in COMBAT** — one already fighting your squad — **spends no warning shot when he swings onto
> you**, even if you never knew he existed. **That is the ambush death the Summoner is complaining
> about, and it is the one case the code does not cover.**

**This is the highest-value single fix available against his durability complaint, and it is a bug fix,
not a feature** — therefore exempt from the gate. Two further facts recorded, neither ruled:

- The flag is **per-man, not per-engagement**: a six-man ambush opens with six independent near-misses,
  so opening lethality scales *inversely* with ambush size. Generous and atmospheric; nobody ruled it.
- Verification standing is **implemented and probe-covered; last full suite run unverified** (last
  baseline 2026-07-27). Not "green today" (ADR-015).

### 5 · ONE STRUCTURAL FACT THAT MAKES THIS URGENT LATER

**`BodySwapSystem` — the pool of four teammates you become on death — is demo-only, and its pool does
not exist out on patrol.** In the RPG world this decree describes, **the down state IS the entire safety
net.** That is why §3 is canon now even though it builds nothing now.

## FROZEN FILES (the scope wall's enforcement surface)

**§3 is not authorised.** These paths are FROZEN against it:

- `scripts/player/player.gd` — `_collapse_camera` and the down-state block
- `scripts/player/body_swap_system.gd` — **except** the daylight-pool defect recorded in the playtest
  queue, which is a **bug fix** and therefore GATE-exempt

**The named leak risk:** extending the down state will arrive dressed as *"death feel"* or *"a bug in
how dying reads"*, which sounds GATE-exempt and is not. **§4's near-miss hole IS a genuine bug fix and
IS exempt. §3's verbs are a feature and are NOT.** That line is the whole of it.

A *parked-but-built* constant in the `SLEEP_POST_LAUNCH` style is forbidden here for the same reason it
is forbidden in ADR-039.

## Consequences

**Bought.** The player's complaint is answered without touching the damage grammar, the headshot law, or
Pillar 1. Thirty seconds of furniture become thirty seconds of the most Pillar-4 experience in the game.
The Fairness Law gets a measured verdict instead of an assumption, and a specific, cheap, high-value hole
to close.

**Sacrificed — no free lunches.**

- **He asked to be tougher and the answer is "no, but here are four other things."** If the four do not
  land, the complaint returns, and it will be a legitimate complaint. **This ADR is a promise; failing to
  build LOOK + VOICE turns it into a refusal.**
- **LOOK + VOICE is less than he imagined.** A player expecting to crawl to cover will find he can only
  watch and shout. That is the deliberate line, and it may need his eye to confirm it is enough.
- **The near-miss hole's fix makes every fight slightly less lethal**, which is a real cost against
  Pillar 1 paid to buy fairness — the Fairness Law's whole purpose, but a cost nonetheless.
- **Fixing the hole may make ambushes feel soft**, given the per-man flag already grants one near-miss
  per attacker. The two interact and should be measured together, not separately.

## Evidence

- Summoner decree and the Arbiter's accepted counter-proposal, 2026-09-06; council record
  `production/war_room/2026-09-06_rpg_pivot/`, `analysis/systems_designer.md` §4.
- `scripts/player/player.gd:1922-1945` — `_collapse_camera`: physics, input and unhandled-input all
  killed; viewmodel hidden (verified).
- `scripts/combat/ai_marksmanship.gd:53-60, 68-77, 85-92, 94-96` (verified).
- `scripts/enemies/enemy_base.gd:1313, 2411, 2417-2420` · `scripts/allies/ally_base.gd:2039-2041` (verified).
- `tests/test_firefight_len.gd:62, 76-82` · `tests/test_ai_fairness.gd:39-62` (verified).
- His lethality ruling 2026-08-04; his "drop down and lay in place" ruling 2026-08-24.

## Related

- **ADR-016** — the one damage grammar this ADR exists to defend.
- **ADR-007 Amendment A / ADR-039 §7** — save anywhere, the largest part of the real answer.
- **ADR-038** — the factions; a man who watched you go down has an opinion about it.
- **Pillars served:** 1 (Outstanding gunplay — defended against its most sympathetic attack),
  4 (the squad is the RPG), 5 (Fail forward — going down is not a reload).
