# ADR-037: The route is an order, the pencil is yours, and the enemy hunts what you left
**Date:** 2026-07-28 · **Status:** Accepted (Summoner decrees, this session) · **Depends on:** ADR-022 (the map is your memory), ADR-021 (the intel a patrol earns), ADR-006 (avoidance pays), ADR-029 (open patrol) · **Supersedes:** the freehand M-map pencil route of the 2026-07-24 patrol-contract decree

## Context

Three things were true at the start of this session and all three were invisible from the docs:

1. ADR-022 promised a two-layer map. Only one layer was ever built. The shipped "grease pencil" is
   `FieldMarkVerb` (`scripts/player/field_mark_verb.gd`), which requires the player to be LOOKING at a
   real thing — an OBSERVED-layer tool wearing the ANNOTATED layer's name. **Marking a suspected
   location was impossible.**
2. `topo_map.gd`'s `_unhandled_input` did exactly one thing: toggle visibility. **The map had no input
   layer at all**, which is why the route planner, the pencil and suspected locations were all missing —
   they are three features of one absent system.
3. Hunter teams already existed (`FieldDirector._process_escalation`) and **spawned in a ring around
   `world.player.global_position`, seeded with the player's live position.** The game was handing the
   enemy the player's transform.

## Decision

### 1 · THE ROUTE IS AN ORDER, NOT A LINE

> *"instead of drawing lines on this patrol route you choose X amount of locations that get tagged with
> a circle and than the palyer chooses in what order they go to hit those spots and make it back to the
> firebase"* — Summoner, 2026-07-28

The world offers `FieldDirector.PATROL_OBJECTIVE_COUNT` circles, spread by distance from the wire so
sequencing is a real decision. The player assigns order by clicking; the line closes at the firebase.

**The circles are OFFERED, never REQUIRED.** Skipping is legal, costs nothing, and has no fail-state.
The AAR reports `PLANNED n, WALKED n` and **scores nothing** — ADR-006 pays for what was learned, not
what was ticked.

*Named cost:* this re-introduces a shape ADR-029 deliberately removed. A list of sites the game picked
is a briefing, diegetic and on paper though it is. Ruled in deliberately, with offered-not-required as
the mitigation that keeps Pillar 3 intact.

### 2 · THE SHEET IS A HELD OBJECT, AND THE WORLD DOES NOT PAUSE

> *"the world doesnt pause when you open the map"* · *"i like it being a held object"* — Summoner

The full-screen dim is **deleted**, not shrunk. Reading the sheet is a real-time vulnerability: you are
standing still, the squad keeps moving, hunters keep hunting, and you can still see the treeline over
the top of the paper.

### 3 · THE ANNOTATED LAYER, FINALLY BUILT

Right-click anywhere on the sheet places a pencil mark — **no line of sight required**, including on
ground the player has never walked. Four words only (`AMBUSH · DANGER · RALLY · AVOID`), because ADR-022
warns the vocabulary will want to grow and must not. Free text is typed onto the mark and persists in
`CampaignState.pencil_marks` for the tour.

**THE GREASE-PENCIL LAW binds absolutely:** nothing in the game validates, corrects, moves or erases a
player mark. `_draw_pencil_marks()` checks nothing against the world, by design.

### 4 · THE SHEET IS AN ACCURATE SURVEY

> *"i think from a gaming perspective it should be an accurate map of the game they are playing on just
> like arma does"* — Summoner

The council proposed deliberate 1950s-survey error (ghost hamlets, unprinted hamlets). **Ruled against.**
A map that lies about geometry is not fog of war — it is the game cheating, indistinguishable from a bug,
and it steals the one power ADR-022 reserves for the player: being wrong is HIS error on HIS pencil.

The firebase and surveyed villages print as base sheet — the same argument `topo_map.gd:7-15` already
ratified for roads. VC camps, LZs and deep-bush temples never print: the line is **surveyed vs. found**,
which preserves ADR-021's reason to walk.

### 5 · HUNTERS CONVERGE ON EVIDENCE, NEVER ON THE PLAYER

> *"theres small dedicated ambush HUNTER teams of the enemy that actively seek to get the players and
> squad. but only so many can exist during a single patrol"* — Summoner

`EvidenceLedger` (`scripts/enemies/evidence_ledger.gd`) records what the player LEFT — gunfire, blasts,
bodies — as **dated, scattered, decaying fixes**. `_process_escalation` now draws its spawn ring and its
`last_known_target_pos` from `evidence.best_fix()` instead of the player's transform.

- Noise carries ~55 m of error and dies in 4 minutes. Bodies carry ~8 m and last 15.
- Co-located fixes MERGE: one firefight is one strong lead, not two hundred weak ones.
- Enemy-team noise is never evidence, or a firefight would feed the hunters that came to it.
- **No evidence, no lead, nobody sent.** A genuinely quiet patrol is never hunted.

The cap was already real (`_hunter_pool`) and is kept. Guarded by `tests/test_evidence_ledger.tscn`.

## Consequences

**Bought:** the compounding loop ADR-022 was written for. Intel found on patrol 3 changes which circles
you sequence on patrol 4. Stealth stops being a score and becomes the thing that keeps two teams off
your back — "hit the noisy site last" is now a decision a player can actually make.

**Sacrificed:**
- Difficulty variance rises sharply. A quiet player may never meet a hunter; a loud one meets them far
  from the wire. That is the design working, and it will read as unfair to someone.
- Free text is a moderation/localisation surface if sharing ever exists. It will not at launch.
- Three layers on one sheet (printed / observed / annotated) is a harder legibility problem than the two
  ADR-022 already called "a real UI problem, not a small one."

**FOSSIL LAW (ADR-023):** the freehand-pencil route concept from the 2026-07-24 patrol-contract decree
is **DEAD**. Do not build it, do not restore it, and do not read that decree's route section as live.

## Evidence
- Summoner decrees, 2026-07-28, quoted verbatim above
- `production/war_room/2026-07-28_topo_map_period_sheet/` — briefing, synthesis, patrol_route_and_hunters,
  intel_stashes, ear_necklace, world_sim_group_sizes, FINDINGS_the_look, IMPLEMENTATION_PLAN
- `tests/test_evidence_ledger.tscn` — 6 assertions, all passing
