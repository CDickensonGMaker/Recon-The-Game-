# DECREE — The route is an ORDER, not a line. And the enemy hunts back.

**Date:** 2026-07-28 · **Status:** Summoner's design input, awaiting ratification
**Amends:** the 2026-07-24 patrol-contract decree (freehand M-map pencil route)
**Touches:** ADR-029 (open patrol, no briefing UI) · ADR-006 (avoidance pays) · ADR-021 (intel economy)

---

## 1 · THE ROUTE — Summoner, verbatim

> *"instead of drawing lines on this patrol route you choose X amount of locations that get tagged with
> a circle and than the palyer chooses in what order they go to hit those spots and make it back to the
> firebase"*

The world tags N locations with grease-pencil circles. The player assigns **visit order**, and the route
closes back at the firebase.

### Why this is stronger than freehand

- **The input layer collapses.** Freehand demanded a pencil: cursor capture, stroke smoothing, undo,
  storage of arbitrary polylines, and a legibility fight against the printed linework. Ordering demands
  a click on a circle and a number. This is the difference between an epic and a slice.
- **It is a real decision with a legible strategy space.** Order governs exposure, which leg you walk in
  what light, which ground you cross between sites, and how long the walk home is. Freehand mostly
  produced "draw a line roughly at the thing."
- **It makes the sheet load-bearing.** You choose order by *reading the paper* — take the valley, avoid
  the ridge, cross the stream at the ford. This is the direct payoff for fixing the smush and printing
  the villages, and it is why the map slice is correctly sequenced first.

### What is sacrificed (named, per the Laws)

**This re-introduces the shape ADR-029 deliberately removed.** ADR-029 killed the briefing UI and the
objective counter; `"PATROL"` is the only mission type the generator produces. A list of N sites the game
picked, that the player then sequences, **is a briefing** — a diegetic one, drawn on paper instead of
rendered in a menu, but a briefing.

That may be exactly what the Summoner wants. It must not happen by accident. **The mitigation that keeps
Pillar 3 intact: the circles are OFFERED, never REQUIRED.** Skipping a site is legal, costs no
fail-state, and ADR-006 already pays for what you learned rather than what you completed. The sheet
suggests; the man decides; the AAR banks whatever actually happened.

## 2 · THE HUNTERS — Summoner, verbatim

> *"maybe the enemy patrols set up ambushes along those patrols. like theres small dedicated ambush
> HUNTER teams of the enemy that actively seek to get the players and squad. but only so many can exist
> during a single patrol"*

Small dedicated VC teams whose goal is *you*, not a post to stand at. **Hard cap per patrol.**

### The cap is the whole design, and the instinct is right

An uncapped hunter system is a spawn grinder: the world stops being a place and becomes a faucet.
A capped one is a **finite adversary** — killing a hunter team is a permanent win for that patrol, and
the player can feel the pressure ease. Proposed: **2 teams**, not respawned when destroyed.

Ties to the FROZEN finite-VC-pool work (Claude memory: *RECON VC manpower research* — capped pool with
trickle refill). Hunters should draw from that pool when it thaws, not from a separate spawner, or we
grow the fourteenth parallel world-build system.

### The critical question: how do hunters know where you are?

**They must NOT read your chosen order.** An enemy that ambushes the route you privately picked is
telepathic, and the player will read it as the game cheating — the same objection that killed the
false-map proposal earlier today.

**They hunt EVIDENCE, and the evidence already exists in this game:**

| What you leave | What it buys the hunters |
|---|---|
| gunfire (noise, direction, time) | a bearing and a stale fix |
| bodies you left behind | ADR-022 already calls a body a liability; the witness rule is written |
| villages that saw you, and how they felt about it | ADR-019 sentiment, already modelled |
| burned/damaged structures | a location and a grudge |
| tracks through worked ground | a direction of travel |

This makes hunters the **teeth** of the stealth economy. ADR-006 pays +25 for a contact avoided; right
now that is a number in a debrief. With hunters, avoiding contact is what stops two dedicated teams from
converging on your route — stealth becomes mechanically load-bearing instead of merely scored.

And it interlocks with §1: **hit the noisy site last.** Order stops being a travelling-salesman puzzle
and becomes a risk sequencing decision. That is the good version of this feature.

### What is sacrificed

- **Difficulty variance goes up sharply.** A quiet player may never meet a hunter team; a loud one meets
  both, possibly at once, possibly far from the wire. That is the design working, and it will read as
  "unfair" to someone. Same class of complaint ADR-022 already accepted.
- **Hunter AI is not the existing patrol AI.** Standing patrols walk a fixed route; hunters need
  converge-on-evidence behaviour with stale, wrong-able fixes. This is new AI work, not a reskin, and it
  must not be built by widening `patrol_generator` until it does both.
- **Two teams is a guess.** It needs playtest, and the number should live in one named constant, not
  scattered.

## 3 · ORDER OF WORK — unchanged

The map slice still comes first and is now more clearly the precondition: you cannot sequence circles on
paper you cannot read, and you cannot decide "take the valley" if the valley is a smear.

1. Look at the sheet (in progress) · 2. Fix the render defects · 3. Print firebase + major villages
4. **Map input layer — reduced to click-to-order by this decree**
5. Hunter teams, gated on the finite-VC-pool thaw
