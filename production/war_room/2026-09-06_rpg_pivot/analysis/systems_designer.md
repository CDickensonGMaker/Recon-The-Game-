# SYSTEMS DESIGNER — the RPG pivot of 2026-09-06

**Council:** RECONgame War Room, 2026-09-06 · **Lens:** systems design
**Brief:** specify the factions-as-readout coupling, name the replacement reputation faucet,
judge contraband as currency, and report the truth about the player's down state and the
Fairness Law's first-shot near-miss.
**Standing:** ANALYSIS. Nothing here is a build. Everything except §4's item (a) is
post-launch record-as-canon under GAME_GUIDE §8's EA target (`GAME_GUIDE.md:352-372`).

---

## 0 · The one-line reading of the decree

The Summoner has found the missing half of ADR-019, and it is a genuinely good piece of
systems design: **ADR-019 built a system with no output channel, and the four firebase
factions are that channel.** ADR-019 named the wound itself — *"if the player cannot feel it
through the world within one playtest, the presentation has failed — and the fix is more
world, never a meter"* (`ADR-019-hearts-and-minds.md:120-122`). Four opinionated men in the
firebase are *more world*. They cost no HUD, no screen, no number, and they discharge the
r4bk exception ADR-019 took on credit.

My job is to say what that costs, and it costs three things: **a legibility ceiling**
(§1.6), **a progression faucet that does not exist once ADR-006 is gone** (§2), and **a
positive feedback loop on loud play if contraband is looted off bodies** (§3.4).

---

## 1 · THE COUPLING — factions as the readout, specified as a system

### 1.1 The architectural call: two readouts off ONE log, never off each other

The tempting shape is: conduct → allegiance number → world behaviour AND faction barks. That
shape is wrong, and it is wrong for a reason that only shows up later.

If the factions read the allegiance scalar, then **all four factions are the same instrument
with four skins.** They can only ever disagree in intensity, never in direction. But the whole
point of the decree — *"one player action gets four different readings"* — is that HQ is
*pleased* by the thing the true believer is *sickened* by. That requires the four to read the
**conduct**, not the summary of it.

So:

```
CONDUCT LOG  (typed events, append-only, bounded)
   |
   +--> district_sentiment : float   -> WORLD behaviour (traps, ambush, informers, VC regen)
   |                                    ADR-019 §2. Never rendered. Never spoken.
   |
   +--> faction lenses (x4)          -> WORDS at the firebase.
                                        Each lens is a weight vector over conduct KINDS.
```

Two consumers, one source, **no edge between them.** That single decision is what makes the
decree's promise mechanically true rather than cosmetic, and it is the thing I would defend
hardest in the Weaving.

### 1.2 Minimum data model

Three pieces of state. That is the whole system.

**(a) The conduct log** — lives in `ProvinceState` (ADR-017 §9, `ADR-017:71-73`; the class does
not exist yet, `ADR-017:81-86`).

```
conduct_log : Array   # bounded ring, ~64 entries
  { kind: String, district: int, patrol_no: int, witnessed: bool }
```

`kind` is a small closed vocabulary. Six of the nine already have a live hook in code today:

| kind | existing hook (file:line) |
|---|---|
| `NONCOMBATANT_KILLED` | `scripts/world/civilian.gd:867` → `director.record_noncombatant_death()`; tallied at `scripts/missions/mission_state.gd:22` |
| `ATROCITY_WITNESSED` (ears) | `scripts/player/player.gd:243-258` → `civilian.on_atrocity_witnessed`, `scripts/world/civilian.gd:889-899` |
| `CONTACT_DETECTED` / `CONTACT_AVOIDED` | `scripts/missions/mission_state.gd:105-110` — the ADR-006 ledger. **The inputs survive even though the score does not** (§2.4) |
| `PATROL_COMMITTED` | `scripts/missions/field_director.gd:2035` `_bank_patrol()` at the wire |
| `SQUAD_KIA` | `field_director.gd:2064` `_read_the_dead(...)`; `CampaignState.kia_total` `campaign_state.gd:56` |
| `TUNNEL_COLLAPSED` | `CampaignState.collapsed_tunnels` `campaign_state.gd:36` |
| `CACHE_TAKEN` | `CampaignState.add_intel` `campaign_state.gd:91-95` |
| `ARSON` / `MEDCAP` / `TAX_COLLECTOR_KILLED` | **do not exist** — ADR-019 §2's own table, unbuilt |

**No new instrumentation is needed for most of the vocabulary.** That is the cheapest part of
this whole decree and it should be said out loud.

**(b) The sentiment scalar** — `ProvinceState.district_sentiment : Dictionary[int, float]`.
Internal. Never returned by any function a Control node can reach. In the demo slice there is
exactly one village (`mission_generator.gd:716`, per `GAME_GUIDE.md:361-366`), so this
collapses to a single float and costs effectively nothing.

**(c) The speaking scheduler** — `FirebaseOpinion` (a new autoload, or a child of FieldDirector):

```
_pressure   : Dictionary[faction_id, float]   # unspoken accumulated opinion
_last_spoke : Dictionary[faction_id, int]     # ms
LENSES      : const, faction_id -> { conduct_kind: weight }
```

`_pressure` is the only per-faction number and it is a **scheduling** number, not a standing.
It is consumed to zero the moment the faction speaks. It must never be read for anything but
"who talks next."

### 1.3 Where a change ENTERS — the one faucet

Exactly one entry point, following the precedent `bank_reputation` already sets
(`campaign_state.gd:177-181`, "the ONE bank point for AAR score") and `add_intel`
(`campaign_state.gd:90-95`, *"the ONE way intel is earned. Routing every source through here
is what keeps the spendable pool and the silent accumulator from drifting apart"*):

```
ProvinceState.record_conduct(kind: String, at: Vector3, witnessed: bool) -> void
```

It appends to the log, nudges the district scalar, and adds `abs(lens[kind])` to every
faction's `_pressure`. **No system writes `district_sentiment` directly. Ever.** This project
has already been bitten by two accumulators drifting apart (`campaign_state.gd:76-78`) and by
a bank point that missed a key (`field_director.gd:217-220`). One faucet.

### 1.4 How one change becomes four readings

The lens is a fixed const table. Sketch, for illustration only — the weights are the
Summoner's to set:

| conduct kind | HQ | the gang | the true believers | the burnouts |
|---|---|---|---|---|
| enemy KIA | **+2** | 0 | +1 | −1 (*more of them coming now*) |
| noncombatant killed | 0 (*it counts as a body*) | 0 | **−3** | −1 |
| ears taken | −1 (*paperwork*) | **+1** (*it sells*) | **−3** | +1 (*he's one of us*) |
| patrol walked, no contact | −1 (*nothing to report again*) | 0 | +1 | **+2** |
| squad KIA | −1 | 0 | −1 | **−3** |
| bought from the gang | **−2** | **+3** | −2 | +1 |

Read the *noncombatant* row: HQ shrugs, the gang shrugs, the believer is disgusted, the
burnout is uneasy. **One action, four readings, disagreeing in sign.** That is the decree, and
this table is the entire mechanism that delivers it. It is a `const` dict.

Each faction's spoken line is chosen from a coarse bucket of its own running lens total —
**three buckets** (`SOUR / NEUTRAL / WARM`) with hysteresis, never a continuum. Three is not a
starvation of expression; it is the guard in §1.6.

### 1.5 Who speaks, and when

The demo already owns every wire needed to *carry* a line: the toast bus
(`field_director.gd:7` `signal toast`) and three VO channels (`vo_manager.gd:50 play_radio`,
`:67 play_squad`, `:80 play_enemy`). What is missing is the **decision of whose turn it is**,
and that is the actual system:

1. **Trigger moments** (never ambient chatter — a bark you hear every 40 seconds is
   wallpaper): the patrol AAR at the wire (`field_director.gd:2035-2070`, already the commit
   point under ADR-029 Amendment 006); walking into that faction's *place* in the firebase for
   the first time that day; the morning.
2. **The bid.** At a trigger, every faction whose `_pressure` clears a floor bids. The winner
   is the highest pressure with `now - _last_spoke > FACTION_COOLDOWN` (a day, or a patrol).
   Ties break toward the faction whose bucket most recently *changed*.
3. **One line. One faction. Per moment.** Four barks at once is a stats screen read aloud. One
   action earns four readings across four returns to the wire, not four in one breath. This
   pacing property is what makes the readout feel like men rather than UI.
4. **Silence is a reading.** A faction with nothing to say says nothing, and the player notices
   when the man who always talks to him stops. Free, and the most atmospheric output the system
   has.

### 1.6 The state that MUST NOT exist — and the ceiling nobody has named yet

Forbidden outright, per ADR-019 §4 (`ADR-019:79-88`) and the precedents this codebase already
holds itself to — `field_marks` *"never a count, never a tally by kind"*
(`campaign_state.gd:34-38`), `ears_taken` *"a COUNT, never a score"*
(`campaign_state.gd:79-82`), `collapsed_tunnels` *"never surfaced as a count, a panel or a
marker"* (`campaign_state.gd:33-36`):

- No numeric getter for sentiment or faction standing reachable from `scripts/ui/`.
- No faction standing rendered as a bar, pip, colour, icon, or ordered list.
- No per-kind tally shown anywhere — that is a meter with extra steps and a fig leaf.
- **No screen that lists the factions together. Seeing them side by side IS the meter.**
  Comparison is what turns four opinions into one scoreboard.
- No threshold the player can be told he is approaching.

**And now the thing the decree has not priced, which is my job to say:**

> **A bark with a legible mapping IS a meter with four ticks.** If HQ has three lines and the
> player learns that line 3 means "you are near the promotion gate," the number is back — and
> it is worse than a number, because it is slower to read.

The decree's stated purpose is to solve ADR-019's *"delayed consequence is hard to learn from
and easy to experience as unfairness"* (`ADR-019:123-127`). But legibility is exactly what
makes it a meter. **These two goals are in direct tension and cannot both be maximised.**

The resolution I propose, and the line I would put in the ADR:

> **A faction line may name the SUBJECT. It may never name the QUANTITY or the DIRECTION.**
> *"That ville down the road's gone quiet on us"* — legal; it points at the cause.
> *"THE DISTRICT IS HOSTILE. EXPECT CONTACT."* — legal at the HQ board; ADR-019 §4 explicitly
> sanctions plain-language briefing sentiment (`ADR-019:85-88`).
> *"Three more like that and they'll wire every trail out here"* — **forbidden**. That is a
> meter spoken aloud.

That rule buys most of the anti-unfairness and pays for it with the last 20% of legibility. It
is the correct trade, and it is not a free one.

### 1.7 Cost, honestly

One class (`ProvinceState`, ~150 lines), one const lens table, one scheduler (~100 lines), and
**line authoring — 4 factions × 3 buckets × 4-6 lines ≈ 60 written lines, plus VO if they
speak rather than toast.** The code is a week. **The writing and the voice are the real bill**,
and they are the half that historically gets deferred and strands the system — ADR-018 §2's
silent squad XP is the standing example: *"the easiest system in the game to build and have
nobody notice"* (`ADR-018:88-92`).

---

## 2 · RETIRING ADR-006 — what feeds reputation instead

### 2.1 Measured truth about the faucet being retired

- `compute_score()` — `scripts/ui/screens/debrief.gd:32-42`. Terms: contacts avoided ×+25,
  contacts detected ×−25, −damage_taken, +50 fast success, +75 ghost bonus
  (`debrief.gd:16-23`), −100 POW.
- **Callers — there are three, not two:**
  - `scripts/missions/field_director.gd:2058` — the patrol AAR at the wire. **This is the live
    one** under ADR-029 (`ADR-029-amendments-008-006.md`, the ADR-006 amendment).
  - `scripts/main/game_flow.gd:469` — the legacy mission-end debrief path.
  - `scripts/ui/screens/debrief.gd:126` — renders `"SCORE: %d"`. **A raw number on screen.**
    The ADR-029 screen is deleted so this is dead in the demo path, but it is a live
    contradiction of ADR-032's *never rendered as a number* law and should die with the score.
  - (`tools/probe_config.gd:34` — instrument only.)
- `CampaignState.bank_reputation()` — `campaign_state.gd:177-181`:
  `reputation += maxi(0, points)`, returns true on a tier rise.

### 2.2 What actually stands on that faucet — the brief undercounts it by one

The brief names rank and the armory rack. There is a **third consumer**, and it is the one
ADR-018 cares most about:

| consumer | file:line |
|---|---|
| the rank word (the only tell) | `field_director.gd:2059`, `game_flow.gd:470`, `barracks.gd:47`, `service_record.gd:32`, `debrief.gd:66` |
| the armory rack | `armorers_bench.gd:152` → `rack_for_tier()` `:46-53` |
| **the fire-support allotment** | **`field_director.gd:1512-1518`** — `var rank := CampaignState.title_tier()`; PVT loses bombs and napalm, PVT/PFC lose CBU and Spectre |

That third one is **ADR-018's whole thesis in code** — *"rank gates AUTHORITY, never ABILITY"*
(`ADR-018:44-56`). Retiring the score without a replacement faucet does not merely stall the
armory: **it freezes the player at PVT forever and permanently denies him fast movers.** A
decree that retires ADR-006 and leaves this unnamed ships a game where fire support never
opens. Naming it is the most load-bearing sentence in this analysis.

### 2.3 The replacement faucet — HQ IS the faucet

The synthesis runs in both directions. If the factions are the readout, then **the faction
that owns promotion is the one that pays it.** Rank stops being a score and becomes what it
actually is in an army: *your commander's opinion of you.*

```
FieldDirector._bank_patrol()          # field_director.gd:2035 — unchanged shape
  -> HQOpinion.assess(result) -> int  # replaces DebriefScreen.compute_score
  -> CampaignState.bank_reputation()  # campaign_state.gd:177 — UNCHANGED
```

`HQOpinion.assess()` pays:

| term | value | rationale |
|---|---|---|
| the excursion was committed at the wire | **the base grant** | ADR-029's own ratified Q1 default: *"rank clock = completed patrols"* (`ADR-029:51`). **This is already canon** — I am not inventing a faucet, I am promoting an existing one |
| ground covered (25m sectors) | small | already accumulated `mission_state.gd:30-46`, already reported `debrief.gd:82`; ADR-029 Amendment C's "reported, not yet priced" finally prices |
| route marks walked | small | `mission_state.gd:37`, already banked |
| you brought your men back | modest | `result.squad_kia` empty. Pillar 4, and it is HQ's honest concern |
| POW lost | large negative | already a term, `debrief.gd:40` |
| **enemy KIA** | **ZERO** | see §2.5 |

A **~30-line function** replacing a ~10-line one, at the same two call sites, in the same
shape. Code only. **Zero art-days** — the split that drives all planning
(`GAME_GUIDE.md:378-380`). Touched by the change: `tests/test_reputation.gd`,
`tools/probe_config.gd:34`, `debrief.gd:126`.

### 2.4 What happens to the ±25 contact grammar

**Its inputs live; its scalar dies.** `contacts_detected` / `_detected_groups`
(`mission_state.gd:105-110`) keep running exactly as built — they become two conduct kinds
feeding §1's lenses. What is deleted is their conversion into a single banked number the player
can feel himself optimising. ADR-006's *moral* — *"loud stays viable; it stops being the
optimal XP strategy"* (`ADR-006:47-49`) — is preserved by relocation, exactly as the decree
claims.

> **ADR-006 is not being repealed. It is being RE-HOSTED.** That distinction belongs in the
> record, because "retired" reads to a future agent as "delete the ledger" — and the ledger is
> the sensor everything in §1 depends on.

### 2.5 The failure mode I must name, and the line where it stops

The decree says *"body count becomes HQ's OPINION rather than a law of the universe."* Read
carelessly that says: HQ's opinion pays rank, HQ likes bodies, therefore **rank pays kills** —
and `kills × 10` walks back through the door ADR-006 was written to shut. Rank buys the armory
*and* the fast movers, so a kill-paying rank clock makes loud play the optimal progression
strategy outright. That breaches ADR-006, Pillar 3, and the standing law named in the brief, in
one move.

> **THE LINE: body count may move HQ's WORDS. It may never move HQ's GRANT.**

HQ can be delighted with you, say so, and still promote you on patrols walked. That is not a
fudge — it is the actual texture of the thing: the brass loves the number and promotes on time
in grade. The rank clock is `PATROL_COMMITTED`; the body count is dialogue. Same faction, two
channels, and only one of them is a faucet.

### 2.6 The ratchet question

`bank_reputation` floors each grant at 0 (`campaign_state.gd:179`), so rank has never been
losable, and `tests/test_reputation.gd` asserts tier monotonicity. If HQ's displeasure is to
mean anything, the tempting move is demotion — **do not take it.** Demotion strands the player
below his armory tier (`armorers_bench.gd:152` re-racks on tier) and below his fire support
(`field_director.gd:1512`); it takes away a gun he is carrying. Instead: **a sour HQ pays ZERO
for that patrol.** The ratchet stays, the probe stays green, no save migration, and displeasure
still costs real time.

---

## 3 · CONTRABAND AS CURRENCY

### 3.1 State of the code

`grep` for contraband / black market across `scripts/` and `production/`: **zero hits.**
Nothing exists. The nearest live things are `CampaignState.intel_points`, spent at
`field_director.gd:1449-1450` for one bearing toast, and `rack_condition`
(`campaign_state.gd:112-115`).

### 3.2 Can it replace points without becoming a second economy? — Conditionally yes

ADR-032's three lanes are learn-by-doing (allies), rank (player authority), armory (player
kit). Contraband is legal **if and only if it does not buy what any of those three buy.**

**Contraband must never buy a weapon.** The moment it does, the M72 LAW that ADR-032 made the
crown of a 30-level ladder (`ADR-032:73`) becomes purchasable and the authority ladder
collapses into a shop — which GAME_GUIDE §6 has *already frozen by name* ("RPG shop",
`GAME_GUIDE.md:319`). That is the bright line.

### 3.3 What it CAN buy that the armory cannot: CONSUMABLES AND SUSTAIN

The armory is permanent, gated, and player-facing. Contraband should be temporary, ungated, and
**squad-facing** — which puts it squarely on Pillar 4:

- Doc's bandages beyond the issue (`squad_system.medic_bandages`, `squad_system.gd:439`)
- a belt for the pigman (`mg_belts`, `squad_system.gd:430`)
- **buying back the depot the sappers blew** (`CampaignState.depot_loss`,
  `campaign_state.gd:120`, consumed on the next walk-out) — the best single hook in the game
  for this, because it turns a loss you suffered into a decision you make
- a rack clean without the work (`rack_condition`, `campaign_state.gd:112-115`)
- comfort and cosmetics: booze, tape, film, a fan, a poncho liner — ADR-018's cosmetic slot
  (`ADR-018:56`), seen in the firebase and on your own corpse
- a replacement man arriving sooner (`_call_replacements`, `field_director.gd:2063`)

None of these touch a bullet. **ADR-016's one damage grammar is untouched by construction** —
contraband never reaches `hitzone.gd`, never adds a multiplier, never opens a second damage
path. State that as a binding clause when this is recorded.

### 3.4 THE FAILURE MODE — and it is worse than kills×10

> **If contraband is looted off bodies, bodies are income, and the cheapest way to make bodies
> is to be loud.**

Loud → more corpses → more contraband → **more bandages and more belts** → loud play becomes
*more survivable* → more loud. That is not merely a re-run of the `kills × 10` loop ADR-006
convicted (`ADR-006:23-28`); it is strictly worse, because it compounds through a channel the
old score never had. `kills × 10` bought you a level. Looted contraband buys you **the ability
to keep being loud.** A positive feedback loop on lethality tolerance is the one economy shape
this game must never grow.

There is a second, sharper edge. `player.gd:240-243` records a Summoner ruling in so many
words: taking ears is *"deliberately NOT a reward: no intel, no score, no stat… a trophy system
that only ever pays out reads as the game approving."* **Making ears sellable to the gang
reverses that ruling directly and makes atrocity profitable.** This is the single most dangerous
coupling latent in the decree. If ears are ever priced, it must be by explicit re-ruling — never
by a system quietly noticing they are loot.

### 3.5 The three guards

1. **Contraband comes from CACHES AND SITES, never from corpses.** The loot is where the VC
   keep it. Getting to it is a *patrol* problem — reconnaissance, route, risk — not a firefight
   problem. This inverts the loop: the way to get rich is to walk far and quiet, which is
   ADR-006's moral expressed as a currency instead of a score. `add_intel`
   (`campaign_state.gd:90-95`) and `stash_is_due` (`:104-108`) are already exactly this shape
   and already run.
2. **Everything it buys is consumable.** Nothing permanent, nothing that stacks, nothing that
   raises a ceiling. A consumable economy cannot compound.
3. **Buying from the gang costs you with HQ** (§1.4's lens: HQ −2). The black market becomes a
   genuine tradeoff against the rank clock rather than free money. **This is what makes the
   four factions load-bearing instead of decorative** — the gang is only interesting if trading
   with it is a real decision, and it is only a real decision if some other faction pays you.

With those three, contraband is a legal fourth lane. Without guard 1 it is a trap.

---

## 4 · THE DOWN STATE

### 4.1 What the player's death path ACTUALLY is today

Traced end to end. Every line verified against source.

**1 · The hit.** `HealthSystem.take_damage()` — `scripts/player/health_system.gd:210`.
- **A headshot bypasses everything:** `health_system.gd:217-224` —
  `Hitzone.zone_name_is_fatal(zone)` → `force_death()` directly, *"never `_die`, or a headshot
  would merely put the player in bleed-out"* (ADR-016 Amendment D). **A headshot can never be a
  down.**
- **A body hit on an already-downed player does NOT kill:** `health_system.gd:226-234` — it
  routes to `revive_handler.pressure_revive(6.0)` and returns 0 damage. Only a headshot ends a
  downed man.
- Otherwise HP falls (`:236-243`); `<= 0` → `_die()` (`:245-247`); survived → the bleed clock
  arms at 25-30s (`:248-259`).

**2 · The down.** `HealthSystem._die()` — `health_system.gd:271-279`.
- Consults `revive_handler.can_revive()` = `SquadSystem.can_revive()`
  (`scripts/squad/squad_system.gd:330-336`): a living MEDIC exists **and** `medic_bandages > 0`
  **or** Doc can restock from a medical box within 6m (`:340-345`).
- If yes: `is_downed = true`, `downed_started.emit(DOWNED_BLEED_SECONDS)` where
  `DOWNED_BLEED_SECONDS = 30.0` (`health_system.gd:268`), then `begin_revive()`
  (`squad_system.gd:434-448` — burns a bandage, toasts *"MAN DOWN - DOC IS MOVING TO YOU"*,
  drops the medical box on the ground, fires `man_down` + `doc_moving` VO).
- If no: straight to `force_death()`.

**3 · The 30 seconds.** `SquadSystem._process_revive()` — `squad_system.gd:455-490`.
Doc is ordered `RESCUE` to the player's position; at ≤2.8m he plays `medic_treat_give` and
channels `max(2.5, REVIVE_CHANNEL_SECONDS − medic_skill × 0.4)` — **veterancy shortens it**
(ADR-018 §2's learn-by-doing, `credit_use` at `:481`). Success → `HealthSystem.revive()`
(`health_system.gd:302-309`) → **full health**, per his 2026-07-18 decree. Clock out or medic
dead → *"DOC DIDN'T MAKE IT TO YOU"* → `force_death()`.

**4 · The end.** `HealthSystem.force_death()` — `health_system.gd:290-297`.
- `swap_handler.try_swap()` → `BodySwapSystem` (`scripts/player/body_swap_system.gd:38-53`):
  the player wakes in the eyes of a named garrison man. `POOL_SIZE = 3` swaps = **4 men total**
  (`:13`, his 2026-08-24 ruling), pool picked once from `garrison_promoted` (`:56-69`),
  `BLACK_SECONDS = 3.5` (`:14`). Installed **demo-only** at
  `scripts/levels/demo_game.gd:552-568`.
- Pool spent → `died.emit()` + `GameManager.on_player_death()` → `field_director.gd:224-225`
  `fail_mission("KIA")`, or `demo_game.gd:571` end card.

**5 · WHAT THE PLAYER IS DOING FOR THOSE 30 SECONDS — this is the finding.**
`Player._collapse_camera()` — `scripts/player/player.gd:1922-1945`, fired from
`downed_started` at `player.gd:1320-1321`:

```
set_physics_process(false)
set_process_input(false)
set_process_unhandled_input(false)
vm.visible = false                        # the viewmodel is hidden
head.position.y -> 0.25   (0.7 s tween)   # the head falls to the ground
camera.rotation_degrees.z -> 75 * side    # and rolls toward the shot
```

**All three input paths are off.** The player has no look, no move, no weapon, no verb. The
comment names the ruling behind it (`player.gd:1917-1921`, his 2026-08-24): *"it should drop
down and lay in place"*, and *"lies STILL through the medic window."*
And `player.gd:1971-1972`: `is_dead()` returns **true while downed** — *"the AI breaks off
during the medic window."* **The downed player is not a target.**
Every other player verb is separately gated off downed: ladders (`:1408`), the MG mount
(`:1538`), photo mode (`:1628`); and the save layer refuses to write (`save_manager.gd:334`).

### 4.2 So "extend the down state" does not mean what it sounds like

**The down state already exists, and on paper it is already the tense, survivable, medic-
under-fire state the counter-proposal describes.** Thirty seconds. A medic sprinting. Rounds
that cut the clock instead of killing you. A veteran Doc who is measurably faster than a rookie
Doc — Pillar 4 with teeth, already shipped.

What it is **not** is *played*. It is a **30-second cutscene with zero verbs.** The Overseer's
counter-proposal is right on the pillars and slightly wrong on the diagnosis: the work is not
"make the down state longer," it is **"give the down state verbs and stakes."**

Four candidate extensions, each with its price:

**(a) LOOK — restore camera look while downed.** `player.gd:1926-1928` kills all three input
paths; re-enable `set_process_input` with a downed branch accepting mouse look only, clamped to
the collapsed head orientation. **Cost: hours. Risk: near zero.** Buys: you *watch Doc come*,
and you watch him not make it. It converts a black-out into a scene. **The highest
value-per-line change in the entire decree**, and the only item here whose price I would even
quote against the EA window — it is not on §8.1's ship order, so it is the Summoner's to insert
or not.

**(b) CRAWL.** A heavily damped physics branch. **Cost: real.** The frozen-head tween
(`player.gd:1940-1944`) fights any movement; three verb gates key off `is_downed` to *refuse*
rather than to *adapt* (`:1408`, `:1538`, `:1628`); and the medic's `RESCUE` order targets a
position that would now move (`squad_system.gd:468`). **And it is a reversal of a Summoner
ruling, not an extension of one** — "drop down and lay in place" is recorded verbatim at
`player.gd:1917-1919`. It must be re-ruled explicitly, never assumed. Design cost: crawling to
cover makes Doc's job *easier*, which shortens the tension the state exists to create.

**(c) THE SIDEARM.** The best version of the fantasy, and the most expensive. The blocker is
not the pistol; it is that `player.gd:1972` reports the downed player as **dead**, so the AI
de-targets him. A downed man who can shoot but cannot be shot is an invulnerable turret. Fixing
that means downed men are targeted again — and the whole `pressure_revive(6.0)` design
(`health_system.gd:228-234`) assumes hits while downed are *stray*. Deliberate fire at a downed
player burns the 30 seconds in five hits. **The rebalance is the work, not the pistol.**

**(d) LENGTH.** `DOWNED_BLEED_SECONDS: 30.0 → n` is one constant (`health_system.gd:268`) and
nearly free. **But it costs tension rather than buying it:** a longer wait with no verbs is a
longer cutscene. Do (a) before (d), always.

### 4.3 The Pillar 4 reading — and a warning

The counter-proposal's claim is that extending the down state strengthens Pillar 4. **It does —
but only for (a) and (d).** If the player can save himself with (c)'s pistol, the squad stops
being the answer to the worst moment in the game, and Pillar 4 is *weakened*, not strengthened.
The Pillar-4-maximal version is:

> **LOOK + VOICE.** You can look, and you can call — a shout that actually re-points Doc
> (`medic.set_order(RESCUE, ...)` at `squad_system.gd:468` already exists to be re-pointed).
> You are helpless, you can see, and your only verb is *your squad*.

That is simultaneously the cheapest option and the one that serves the pillar hardest. I
recommend it.

### 4.4 One structural fact the decree should record

`BodySwapSystem` — the 4-man life economy — is installed **only in the demo**
(`demo_game.gd:552-568`), and its pool is drawn from `garrison_promoted`
(`body_swap_system.gd:61`), a group that exists at the firebase during stand-to
(`garrison_defender.gd:100`). **On a patrol in the open RPG world there is no such pool**, so
`_nearest_living()` returns null and `try_swap()` refuses (`body_swap_system.gd:44-46`) —
which means out there, **the down state IS the entire safety net.** Extending it is load-
bearing for the RPG world in a way it simply is not for the demo. That asymmetry is the
strongest argument in favour of the counter-proposal and it is not currently written down
anywhere.

### 4.5 THE FAIRNESS LAW PROBE — first shot at an unaware player

**VERDICT: FIRING. Implemented, wired on both shooter paths, and probe-covered.**

**The implementation:**
- `scripts/combat/ai_marksmanship.gd:53-60` — `_first_shot_nudge()`: *"The warning crack: a
  deliberate 5-9 deg miss, biased high/wide."* `randf_range(5.0, 9.0)` degrees, random azimuth,
  forced upward bias (`a.y += absf(sin(dir)) * miss * 0.5 + 0.02`).
- `ai_marksmanship.gd:94-96` — applied inside `aim_with_spread()`, gated
  `if force_first_miss and is_player_target`. `:63-66` records the invariant: the AI-vs-AI cone
  dial and the first-shot mercy sit on **opposite branches** of `is_player_target`, so the
  firefight dial can never reach a shot aimed at the player.

**Enemy wiring (the live path):**
- `scripts/enemies/enemy_base.gd:2417-2420` — `aim_with_spread(..., _target_is_player(),
  exposure_t, not _first_shot_fired)`, then `_first_shot_fired = true` and the `open_fire` VO.
- **Re-arm:** `enemy_base.gd:1313` — `_first_shot_fired = false  # new fight, new warning
  shot`, inside `_set_tier()`'s COMBAT branch (`:1302-1313`) and *after* the same-tier dedup at
  `:1305`. It re-arms once per fresh transition into COMBAT.
- Declared at `enemy_base.gd:277`.

**Ally wiring (same shared path):** `scripts/allies/ally_base.gd:2039-2041`, flag at `:405`.

**The law's other half — "AI accuracy ramps with player exposure" — is also live:**
- `ai_marksmanship.gd:68-77` `exposure_spread_mult()`: ×2.4 fresh → ×1.0 converged, monotone.
- Fed at `enemy_base.gd:2411`: `target_visible_duration / d_exposure_ramp`, per-archetype
  (`:172`, from `EnemyData` at `:381`). The clock resets on a new victim (`:1423`, `:1430`) and
  decays at 3× when sight is lost (`:1451`).
- `ai_marksmanship.gd:85-92` records a real past defect and its fix: **the cap must breathe
  with the ramp**, or a weapon whose natural cone already exceeds the cap (AK 2.2°) fires the
  capped cone both fresh and converged and *"the opening volley was as lethal as the converged
  one."* Fixed — the cap is multiplied by the same ramp at `:90`.

**Probe coverage:**
- `tests/test_firefight_len.gd:62` exercises the `force_first_miss = true` branch and `:80-82`
  asserts `max_firstshot_dev >= 5.0` — *"First shot at the player is a deliberate telegraphed
  miss."* The same probe asserts at `:76-78` that the AI-vs-AI dial never widens the player cone.
- `tests/test_ai_fairness.gd:52-62` asserts the exposure ramp's endpoints and monotonicity, and
  `:39-52` that per-archetype ramp data is actually plumbed (an NVA regular converges faster
  than a farmer with a rifle).

**Three divergences from the written law, reported honestly:**

1. **The trigger is not awareness — it is the shooter entering COMBAT.** The law says *"first
   shot at an **unaware** player."* The code re-arms on the transition into COMBAT
   (`enemy_base.gd:1313`), whether or not the player knows the shooter is there. That is
   **broader** than the law — every fresh engagement opens with a warning crack — and is
   probably the better rule. But it is not the written rule, and it has a hole: **a shooter
   already in COMBAT (one already fighting your squad) spends no warning shot when he swings
   onto you**, even though you may be completely unaware of him. That is precisely the case the
   law was written to cover, and it is the one case the code does not cover.
2. **The flag is per-man, not per-engagement.** A six-man ambush opens with six independent
   near-misses. Generous, atmospheric, almost certainly desirable — but nobody ruled it, and it
   means ambush opening lethality scales *inversely* with ambush size.
3. **Verification standing.** I proved by reading that the code implements the rule and that
   probes assert it. I did **not** run the suite, and `GAME_GUIDE.md:381-386` records the last
   baseline as 2026-07-27 (101 pass / 18 fail / 14 error) and *"unverified since."* Per ADR-015
   the honest claim is: **IMPLEMENTED and PROBE-COVERED; last suite run unverified.** Not
   "green today."

---

## 5 · EVERY TRADEOFF, NAMED

**On the coupling (§1):**
- **Legibility vs. the meter.** The decree's purpose is to make consequence legible; legibility
  is what turns barks into a meter. They cannot both be maximised. §1.6's subject-not-quantity
  rule spends the last 20% of legibility to keep the system honest.
- **The writing bill is the real bill.** ~60 authored lines plus VO. Code is a week; the words
  are the half that historically strands (ADR-018 §2, `ADR-018:88-92`).
- **Silence is ambiguous.** A faction that says nothing because nothing moved is
  indistinguishable from a faction with no lines authored yet. Only a playtest separates those,
  and the fresh-player testing law applies.
- **Four factions is a content multiplier on every future conduct kind.** Every new verb the
  game grows needs four opinions or it is silent — a permanent tax on all future design.

**On retiring ADR-006 (§2):**
- **Rank slows and flattens.** A per-patrol grant is far less variable than a ±25 ledger. The
  quadratic curve (`campaign_state.gd:149-152`) was tuned against ~150/patrol
  (`ADR-032:47-53`); a flat grant needs `rep_for_level`'s two constants retuned — data, not law.
- **Skilled play stops paying rank.** Ghosting a whole AO now pays in *world state* (the
  district) and *words* (the factions), not in the ladder. That is the intent, and some players
  will read it as their skill going unrewarded. A real loss; I will not dress it up.
- **The ratchet means a sour HQ is only ever a delay, never a fall.** Safe, migration-free, and
  slightly toothless.
- **The retirement is a re-host, not a repeal.** If the record says "retired," a future agent
  deletes `mission_state`'s contact ledger — the sensor §1 depends on. The word must be
  *re-host*.

**On contraband (§3):**
- **A fourth lane is a fourth thing to balance**, and ADR-032's three-lane separation was
  hard-won.
- **The gang competes with HQ for the player's time** — the point, and also a pacing risk: two
  faucets means two grinds.
- **Guard 1 (caches, not corpses) will feel arbitrary** to a player who just cleared a camp and
  cannot take anything off the men in it. That friction is the price of not making bodies into
  income, and it will read as a missing feature before it reads as a design.
- **Consumables-only means the money never accumulates into anything.** A currency with no
  permanent sink is less satisfying. Accepted, deliberately.

**On the down state (§4):**
- **(a) LOOK costs the mercy of the black-out.** Watching Doc fail to reach you is worse than
  fading out — which is exactly why it is right.
- **(b) CRAWL reverses a recorded Summoner ruling** and shortens the tension it means to extend.
- **(c) SIDEARM weakens Pillar 4** by making the player his own rescue, and forces a rebalance
  of `pressure_revive` that could make the down state *shorter* in practice, not longer.
- **(d) LONGER, alone, is a longer cutscene.**
- **All four raise the floor on player survivability**, which is directionally toward the thing
  Pillar 1 forbids. The defence is that none of them add HP and none touch `hitzone.gd` — the
  one damage grammar (ADR-016) is untouched. **Death still comes from situation. It just takes
  thirty seconds and has your squad in it.** That argument holds only as long as nobody
  proposes more `max_hp` — `player.gd:1330`: *"ADR-018: every grunt has the same body. No
  progression touches health or stamina."*

---

## 6 · SCOPE

Nothing above is a build. Under GAME_GUIDE §8.1 the EA product is the demo's shape and §8.1's
eight items own the remaining days. §1, §2, §3 and §4(b)(c)(d) are **RECORD-AS-CANON,
post-launch**. §4(a) — restoring look while downed — is the only item whose price I would even
quote (hours, code-only, zero art-days), and it is not on the ship order, so it is the
Summoner's to insert or not.
