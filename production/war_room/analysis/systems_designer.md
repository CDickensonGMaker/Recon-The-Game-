# SYSTEMS DESIGNER — the replacement economy
**Query (Summoner, 2026-08-28):** *"On patrol everyone but 2 other guys died. How does the player get more units back?"*
**Verified against code 2026-08-28.** Every claim below carries a `file:line` (POINTER LAW).

---

## 1 · WHAT THE CODE DOES TODAY

**The field is already honest. The screens are not.**

- `scripts/squad/squad_system.gd:70` calls `SquadRoster.ensure_roster()` inside `setup()`, and `setup()`
  runs **exactly once per world build** (`scripts/main/game_flow.gd:685-687`). Nothing re-spawns a dead
  ally between excursions. So inside one operation, 2-of-8 **stays** 2-of-8 across every walk-out. That is
  already the right feeling and nobody designed it — it is a side effect of where the call sits.
- `scripts/squad/squad_roster.gd:165-203` `ensure_roster()` is the vending machine: drop the dead, refill
  every missing MOS from `MOS_ORDER` with `generate_member()`, pad to `SQUAD_SIZE=8` with riflemen, then
  `CampaignState.save_campaign()`. **Instant, free, silent, and it commits to disk immediately.**
- `scripts/ui/screens/barracks.gd:50` calls it **from a screen repaint** (`_refresh()`). Opening the
  barracks manufactures men. A UI paint is a content-generation event.
- The dead are banked properly: `squad_system.gd:753-763` names the man into `state.flags["squad_kia"]`;
  `scripts/autoload/campaign_state.gd:256-277` turns that into `kia_total` (never decrements),
  `bags_unlifted` (stacked, visible) and derived `ward_wounded` (capped at `WARD_BEDS_MAX`).
- The AAR bank is `scripts/missions/field_director.gd:1817-1849` `_bank_patrol()` — the only per-excursion
  commit point. It banks reputation, calls `CampaignState.on_mission_end()` + `commit_mission()`, then
  **resets `state.seed_value = patrol_count`** (`:1845`).

**Systemic verdict: we do not have a replacement economy. We have a `SQUAD_SIZE` invariant that a
constructor enforces.** `ensure_roster` is not a game rule, it is an array-length assertion. Losing six
men costs the player one screen repaint.

### Two live defects any option must fix first

**D1 — the barracks is a rookie vending machine.** `barracks.gd:50` generates men on paint. Nothing gates
it, it is not on the mission commit path, and it writes to disk. Whatever we build, generation moves off
UI code entirely.

**D2 — replacement generation violates ADR-010 today.** Two call sites feed `ensure_roster()` two
*different* seeds for the same men: the field passes `director.state.seed_value + 12345`
(`squad_system.gd:70`), the barracks passes `CampaignState.missions_played + 1` (`barracks.gd:50`). And
`state.seed_value` is itself re-assigned to the ephemeral `patrol_count` at every wire-crossing
(`field_director.gd:1845`). **Which men you get depends on which screen you opened and how many times you
walked out.** ADR-010 is one seed per operation; men who persist for a whole tour must not be drawn from a
counter that ticks per excursion. This is also the save-scum door: reload, open a different screen, get
different men.

---

## 2 · CONSTRAINTS THIS ANSWER MUST SATISFY

| Constraint | Source | What it forbids |
|---|---|---|
| Walking out at 2 of 8 is **legal** | Pillar 3 | any strength gate or "wait for replacements" block at the wire |
| No fail-state; escalation instead | Pillar 5 | a wipe that ends the run with a game-over |
| Loss must be **felt**, never read | ADR-018 §2 | a manifest / strength number on the HUD |
| Rank = missions survived | `squad_roster.gd:210-225` | replacements arrive PVT and stay PVT until they walk |
| Growth is learn-by-doing | `squad_roster.gd:143-161` `credit_use` | any XP granted for a body arriving |
| All-or-nothing commit | ADR-007, `campaign_state.gd:_defer_saves` | rolling new men mid-patrol and writing them |
| One seed per operation | ADR-010 | rolling a replacement's stats at arrival time from a live RNG |
| Doc's bag / the gunner's belts never self-refill | `squad_system.gd:7-13` | men self-refilling either |

That last row is the whole argument. **The project already ruled that a consumable does not restock
itself. A man is the most expensive consumable in the game, and he restocks himself instantly.** The two
laws sit twelve lines apart in one file and contradict each other.

---

## 3 · OPTION A — THE REPLACEMENT DRAFT (a queue on a clock)

**Rule.** Men arrive from Battalion on a cadence, at the firebase, **between excursions only**. The squad
is whatever strength the arrivals have made it. `SQUAD_SIZE` becomes a **ceiling**, never a quota.

**Cadence (concrete):** one man per **2 completed patrols** (`patrol_count` / `missions_played` is the only
clock that exists), **plus** an emergency draft of 2 delivered at the next wire-crossing when living
strength drops below 4 — the Army backfills a combat-ineffective squad first, which is both true and the
anti-spiral valve. Ceiling 8. From 2-of-8: 2 arrive at the next AAR, then 1 per two patrols. Full strength
is ~8 patrols away. **You fight the middle of the tour understrength** — which is the answer to his
question and also the most interesting state this game can be in.

**Where the state lives — minimal `CampaignState` change, 3 fields:**

```
var replacement_queue: Array = []   # pre-generated member dicts, in arrival order
var replacement_credit: int = 0     # patrols accrued since the last arrival
var arrivals_total: int = 0         # monotonic; the ONLY index used to seed a man
```

`SAVE_VERSION: int = 1` → `2` (`campaign_state.gd:6`) with a `_migrate()` branch seeding an empty queue —
an old save loses nothing.

**Generation moves out of the constructor.** `ensure_roster()` splits:

- `SquadRoster.prune_dead()` — drops KIA, runs the existing field back-fill migrations
  (`squad_roster.gd:186-200`), **never generates**. This is what `squad_system.gd:70` and `barracks.gd:50`
  call. D1 and D2 both die here.
- `SquadRoster.draw_replacement(campaign_seed, arrivals_total)` — generates ONE man from a seed derived
  from the campaign seed and the monotonic arrival index. Same index → same man, forever, on every
  machine, after any reload.
- Called only from `_bank_patrol()` (`field_director.gd:1817`), inside the all-or-nothing commit window.

**Determinism:** the arrival index, not the patrol counter, is the stream. Save-scumming a bad roll is
impossible because arrival N is arrival N. Pre-generate the queue 3 deep at campaign start and the player
can even *see* who is coming — chalked on the CP board, diegetic, not a stats screen.

**Skill/XP interaction: untouched.** `_roll_starting_skills` (`squad_roster.gd:117-135`) already gives a
replacement L1-3 in his MOS by aptitude, so he is a person, not a blank. `rank_for()` returns PVT because
`missions == 0`. The competence gap ADR-018 demands is already encoded — a new pointman's `point` skill is
1-3 against a dead veteran's 5-7, and `barracks.gd:_seasoning` reads GREEN vs SALTY off exactly that.

**At 2 of 8, walking out anyway:** fully legal, zero friction, no prompt, no block. The AAR toast at
`field_director.gd:1837` carries the only tell — *"TWO MEN ON THE STRENGTH REPORT"* — words, never a panel.

**TRADEOFF (named):** *tempo is now on a leash the player does not hold.* A wipe costs real hours, and if
his patrols run long that is a slow, unfun stretch. We buy dread and pay in pacing. The cadence number is
a knob only his playtest can validate — no probe can tell us whether 8 patrols to full is heavy or trivial.

**Failure modes.**
- *Death spiral* — real. The below-4 emergency draft is the only thing between us and it; without it a
  gutted squad gets more gutted every patrol. **The valve ships with the cadence, not after it.**
- *Rookie farming for XP* — dead on arrival: bodies pay no XP (`credit_use` fires only on *doing*, e.g.
  `squad_system.gd:447`), and the queue is pre-generated, so killing a man to reroll stats gets you the
  same next man. Nothing to farm.
- *Save-scum* — closed by the arrival-index seed plus `_defer_saves` / `commit_mission`.
- *New fossil risk* — `ensure_roster` must be **deleted**, not parked beside `prune_dead` (ADR-023). Two
  functions that both look like "make the roster right" is precisely the lie the fossil law names.

---

## 4 · OPTION B — THE GARRISON IS THE POOL (the player asks for men)

**Rule.** Replacements do not appear; **the player walks over and takes men off the wire.** The firebase
garrison is already soldiers, not scenery (standing ruling), and the ward already holds bodies
(`campaign_state.gd:60` `ward_wounded`). Between excursions the player goes to the CP and attaches one or
two garrison men for the next walk-out.

**Where the state lives:**

```
var garrison_pool: Array = []   # member dicts standing the wire; finite, 6-10
var ward_returns: Array = []    # {member, patrols_left} - a WIA coming back with his skills intact
```

Plus Option A's `arrivals_total` seeding rule, because the garrison itself must refill on a slow trickle.

**This is the strongest Pillar 4 answer.** You are IN the squad, and getting men back becomes a **verb the
player performs in the world** rather than a number a system restores. It also gives the ward a function:
the only route by which a **veteran** ever comes back — a man returns after k patrols with his
`skills` / `skill_uses` / `missions` intact, which is the one thing a fresh replacement can never give you.

**The cost is legible and it bites.** Every man pulled off the wire is a bunker nobody is in when the
siege comes (`scripts/missions/siege_director.gd`). Filling your squad *weakens the firebase*. That is a
real decision with two real sides — which Option A does not have.

**TRADEOFF (named):** *this is UI work, and it is the exact UI ADR-029 deleted.* A "pick your men" flow is
a barracks screen wearing a hat; it must be a conversation with an NCO at the CP or it is a regression.
Second cost: a deep garrison means the squad is never short and we have re-invented the vending machine
with extra steps — the pool has to be **small and visibly draining.**

**Failure modes.** *Garrison-stripping exploit* (fill to 8 every patrol, let the wire rot) — priced by the
siege, but ONLY if the siege actually reads the garrison count; that must be verified before this ships.
*Ward double-dip*: a man must leave `ward_wounded` when he enters `ward_returns` or he is counted twice.
*Determinism*: garrison men are generated at world build from the op seed, never on the fly when asked.

---

## 5 · OPTION C — NO REPLACEMENTS; THE TOUR ROTATES

**Rule.** Within a tour the dead stay dead and nobody arrives. When the squad is destroyed (or the tour's
patrol count runs out), the **tour ends**: you rotate, a new squad is drawn, and what persists is
`reputation` / `title_tier()`, `kia_total`, `bags_unlifted`, `mission_log` — the ledger of what you did to
your men.

**Where the state lives:** `var tour_index: int = 0` and `var tour_kia: int = 0`. `ensure_roster` is called
**once, at tour start**, seeded `hash(campaign_seed, tour_index)`. Two fields; by far the cheapest option.

**Why it is defensible:** zero cadence tuning, zero new UI, perfect determinism. It honors Pillar 5 the
roguelike way — the run does not end, *the men* end, and your rank walks into the next tour. That is
exactly ADR-018's arc: you get the Arc Light because **you** survived, not because they did.

**TRADEOFF (named):** *it deletes the state his question is actually about.* "Everybody but 2 guys died"
becomes a two-patrol epilogue instead of a chapter. It also reads as a fail-state even though it is not,
and Pillar 5 forbids the feeling as well as the mechanic. A wipe on patrol 2 throws away the only thing
the player was building.

---

## 6 · RECOMMENDATION TO THE ARBITER

**A as the spine, B as the verb, C rejected — but C is the honest fallback if he rejects the slow hour.**

Option A alone fixes the economy but leaves the player *waiting*, a passive answer to a question about
agency. Option B alone cannot fill a squad that outran the garrison. Together they are one system with two
doors: **Battalion sends men on a clock (A); the player can rob his own wire to go out heavy tonight (B),
and pays for it at the next siege.** Ward returns are the only path a veteran comes home.

**Build order, minimum viable:**

1. **Kill the vending machine first, alone, before any economy exists.** Split `ensure_roster` into
   `prune_dead()` (no generation); remove the generation path from `barracks.gd:50` and
   `squad_system.gd:70`. One-file change, and it makes the *current* behavior honest — dead men stay dead
   until something explicitly sends more. Ship that and let him feel it.
2. Three `CampaignState` fields + `SAVE_VERSION` 2 migration; arrivals in `_bank_patrol()` only.
3. The below-4 emergency draft — the anti-spiral valve, shipped in the same change as the cadence.
4. Option B's CP verb, once he has ruled on the ward.

**What is sacrificed, plainly:** the game gets slower after a bad patrol, and there will be an hour where
the player is short-handed and cannot fix it. **That hour is the product.** If he does not want that hour,
the honest alternative is Option C — not a faster cadence. A fast cadence is the vending machine with a
delay, and it will read as one.

**Open questions only the Summoner can rule:**

- **Cadence** — one man per two patrols, or per in-game day? (There is no calendar field in
  `CampaignState`; a day-based cadence is new state.)
- **Does the ward give men back?** Today `ward_wounded` is a pure scoreboard. Making it a source is the
  single highest-value change in this analysis, because it is the only way a **veteran** returns.
- **Can the player rob the wire?** Option B's exploit is a feature only if the siege prices it.
