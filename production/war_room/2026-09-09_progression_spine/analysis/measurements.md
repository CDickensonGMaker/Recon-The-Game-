# MEASUREMENTS — what the code actually says
## War Room 2026-09-09, THE PROGRESSION SPINE · static audit, no game launched (Caleb was playing, pid 13196)

**Method:** static read of `scripts/` and `project.godot`. Nothing here was verified by playtest.
Per ADR-015 that means these are **located facts, not proven behaviours** — every claim below is a
code reading, and any claim about how it FEELS remains unverified.

---

## 1 · THE HEADLINE: THE SOLO PIVOT IS CHEAP, AND ALMOST NOTHING IS THROWN AWAY

The Summoner's first pressure point was *"nothing gets thrown away — verify that."* Verified.

**The squad code already survives having zero men.** Every consumer null-checks:

| Consumer | File:line | Behaviour with an empty squad |
|---|---|---|
| `member_by_mos()` | `scripts/squad/squad_system.gd:350`, `:602-604`, `:634` | returns `null`; every caller null-checks |
| `_first_living()` | `squad_system.gd:309-311`, `:577-583` | returns `null`; `_update_break()` comments the empty case as *"Reachable for real during teardown"* |
| `_radio_check()` | `scripts/missions/field_director.gd:814-821` | returns the string `"NO RADIO - YOUR RADIO MAN IS DOWN"`, no crash |
| `receive_replacements()` | `squad_system.gd:153` | guards its only division with `maxi(1, fresh.size())` |

**No `members.size()` division and no squad-count assumption was found that would crash.** The squad
systems degrade to toasts and no-ops. *(Static reading only — not playtested.)*

### The ONE real blocker

`SquadRoster.ensure_roster()` (`scripts/squad/squad_roster.gd:169-197`) **manufactures a fresh full
8-man roster whenever the living roster is empty** (`:178-179`). The game cannot currently begin an
operation solo, not because anything breaks, but because the roster **self-heals to eight**.

> **The solo pivot's code cost is not "rewrite the squad." It is "stop the roster from refilling itself,
> and let squad size be a campaign variable."** Everything downstream already copes.

### Squad size is a hand-synced constant in TWO files — a standing fossil-law hazard

- `const SQUAD_SIZE: int = 8` — `scripts/squad/squad_system.gd:23`
- `const SQUAD_SIZE: int = 8` — `scripts/squad/squad_roster.gd:67`, commented *"Kept in lock-step with
  SquadSystem.SQUAD_SIZE"*

Not data-driven, not a `.tres`, not one source of truth. **A ladder whose whole point is that squad size
grows over time cannot be built on a hand-synced pair of constants.** This is door #1 to keep open.

Composition: `MOS_ORDER = ["POINTMAN","RTO","MEDIC","MG","GRENADIER"]` (`squad_roster.gd:64`) + 3
riflemen to fill (`FILL_MOS`, `:68`). `setup()` spawns `mini(SQUAD_SIZE, roster.size())`
(`squad_system.gd:71`) — **it already spawns fewer men than eight if the roster is short.** The
variable-size squad is half-built by accident.

---

## 2 · THE COMMAND GRAMMAR IS ~70% ALREADY SHIPPED — AND IT HAS NO CURSOR

His proposed verbs against what exists (`scripts/allies/ally_base.gd:279` —
`enum OrderMode { FOLLOW, HOLD, MOVE_TO, RESCUE }`; issued at `squad_system.gd:277-291`;
bound `project.godot:221-244`):

| His verb | As-built | Gap |
|---|---|---|
| **MOVE HERE** | `MOVE_TO`, key **X**, **already an aimed ground point** | none — the input exists |
| **…becomes HOLD AND DEFEND** | `HOLD`, key **H** (also drops an ammo box) | **HOLD and MOVE_TO are separate orders. There is no arrival transition.** This is the real work |
| **REGROUP** | `FOLLOW`, key **C** | naming; behaviourally present |
| **ATTACK** | — | **does not exist.** Nearest is the weapons-free toggle, key **N** |
| **Aimed-and-trigger-pulled ATTACK** | — | does not exist |

**The period-HUD collision is smaller than the brief assumed.** There is **no command cursor, no wheel,
no order menu, and no order icons** anywhere in the codebase. Orders are keypress-only; feedback is a
toast (`squad_system.gd:244-247`) plus a `VOManager.play_squad` bark. `MOVE_TO` already designates by
**aiming at the ground** — which is exactly the *"the weapon IS the interface"* answer, already shipped.

> **Brothers in Arms' cursor is not a thing this project would be removing. It is a thing this project
> never built.** The scheme he described is closer to as-built than to BiA.

Supporting: `scripts/ui/squad_nameplate.gd` gives a look-at nameplate (name/rank/role) at ≤5 m —
read-only identification, already the beginning of a "who heard me" affordance.

---

## 3 · BORROWING A STRANGER'S RADIO IS NEARLY FREE — THE ARCHITECTURE IS ALREADY GROUP-BASED

This is the most consequential finding for his best idea.

- The RTO is not a special entity. He is a squad MOS slot who is **added to the group `"radioman"`**
  (`squad_system.gd:235-239`, `_wire_rto_radio()`), then given a `RadioHandset` via
  `RadioHandset.attach_to(rto)` (`scripts/gameplay/radio_handset.gd:101-134`).
- The gate reads the **group, not the squad**: `_radio_check()` (`field_director.gd:814-821`) calls
  `nearest_radioman()`, which searches the `"radioman"` group for a living man within
  `RTO_RADIO_RANGE = 10.0` (`field_director.gd:364`).
- The player **already walks up to a radioman and takes the handset**: `_aimed_radioman()`
  (`scripts/player/player.gd:438-451`) raycasts for a man in group `"radioman"`; `[F]` calls
  `set_on_net()` (`player.gd:1055-1058`, `:469-488`).

> **A friendly NPC RTO who is added to the `"radioman"` group is, mechanically, already borrowable.**
> The verbs, the leash, the handset, the grab and the gate all read the group. What does *not* exist is
> the **permission, the price and the fiction** — who he is, whether he'll let you, and what it costs.
>
> **That is the correct division of labour and it is the argument for building this rung first:
> the plumbing is done; only the design is missing.**

Also live: `_hand_off_radio()` (`squad_system.gd:829-865`) reassigns the radio to the nearest living
non-medic rifleman when the RTO dies, and toasts *"THE RADIO IS GONE - NOBODY LEFT TO CARRY IT"* when
nobody is left. The net force-closes the same frame the RTO dies (`field_director.gd:298-303`).

### A fossil, found in passing (NO MORE DRIFT)

`project.godot:250-254` defines an input action **`radio`, bound to key G, with zero references in any
script.** It is a declared-and-never-read symbol — an ADR-023 fossil. It is also, conveniently, the
obvious bind for a player-carried handheld. **Either wire it or delete it; do not leave it standing.**

---

## 4 · THERE IS NO DIALOGUE SYSTEM. AT ALL.

A grep of `scripts/` for `dialogue|Dialogue|conversation|Conversation|talk_to|DialogueTree` returned
**zero files**.

> **This refutes a premise in the session brief.** The brief asked that borrowing an RTO *"connect to
> the existing conversation/dialogue systems rather than being a new prompt."* **There are no existing
> conversation systems to connect to.** The only friendly-NPC interaction in the game is the `[F]`
> handset grab, which is a prop grab, not a conversation.
>
> Corrected on contact, per NO MORE DRIFT. The design must either (a) build the first conversation
> system, or (b) deliberately make borrowing a radio a **wordless, physical** act — which is cheaper,
> more period-honest, and consistent with the diegetic-first UI doctrine.

---

## 5 · THERE IS NO MISSION NUMBER TO COUNT TO

`mission_generator.gd:881` sets `director.state.mission_type = "PATROL"` — the only type the generator
emits (ADR-029). **No campaign order, no mission list, no mission numbering exists.**

> **"The 4th or 5th mission" has nothing to count today.** Either a campaign mission counter is new
> work, or — better — the rung is triggered by something the player DOES rather than by an ordinal.
> The machinery for that already exists: `CampaignState.reputation` → `level()` (1-40, hidden) →
> `title_tier()`/`title()` (`scripts/autoload/campaign_state.gd:24-180`), banked by
> `bank_reputation()` (`:177-180`), which already reports whether a promotion threshold was crossed.

Ally rank is separately derived from missions survived: `SquadRoster.rank_for()`
(`squad_roster.gd:246-261`), PVT→SFC, gating leadership rank only for POINTMAN/RTO — the comment at
`:203` states *"rank gates authority, never ability"* (ADR-018, honoured in code).

---

## 6 · WHAT THE DEMO GIVES THE PLAYER TODAY

`scripts/levels/demo_game.gd:143-151` sets `GameFlow.demo_mode = true` and calls
`_flow._begin_operation(...)` — the **same** path as normal play (ADR-028 honoured, not a parallel
copy). That path builds the squad at `scripts/main/game_flow.gd:699-703` and spawns the player seated
on a bunk (`:658-665`).

**The demo therefore starts the player with eight men and a radio, and that does not change this
session** (his ruling: post-demo-launch work).

---

## 7 · FIRE SUPPORT AS BUILT (ADR-011 surface the ladder must not break)

`field_director.gd:558-600` — eight call types wired: `bombs` · `napalm` · `arty` (multi-round spiral,
`:567-587`) · `mortar` · `spectre` · `cbu` · `wp` · `illum`. Budgets are a per-mission dictionary
(`:345-346`, e.g. `mortar: 2, illum: 2`), allotment scales with the RTO's `fo_fac` skill (`:1503`),
danger-close confirm at `:539-548`.

**Every path funnels through `_radio_check()`.** There is currently **no bypass** — which is exactly
what ADR-011 requires, and exactly what a player-carried handheld would break.

---

## 8 · CONFIDENCE AND LIMITS

- Everything above is **static reading**. No probe was run and no playtest was performed.
- The claim *"the squad code does not crash with zero members"* is the strongest claim here and it is
  still **unproven** — it is a reading of every guard, not an execution. **Before any solo work begins,
  the cheap proof is a headless probe that stands up a `SquadSystem` with an empty roster and ticks it.**
  That probe does not exist.
- The enemy-side RTO (`data/enemies/nva_rto.tres`, `assets/nva_vc/characters/nva_rto.glb`) exists as
  data and art with no gameplay consumer found — consistent with the standing canon note that
  *"DATA ONLY - no AI gives an enemy a radio"*.

---

## 9 · ADDENDUM (Arbiter's own verification) — HE ALREADY RULED THE BORROWED RADIO, AND THE ARCHITECTURE IS BUILT BUT NEVER POPULATED

Found while verifying §3. This is the largest single finding of the session and it changes what the
"borrow a stranger's RTO" rung actually costs.

### 9.1 · The ruling exists, in the code, in his own words — 2026-08-05

`scripts/missions/field_director.gd:789-794`, the header comment on `nearest_radioman()`:

> **ANY RADIOMAN IS THE NET** (his ruling 2026-08-05: *"make it so all radiomen are valid call options
> and the menu is universal"* — *"that does feul that feeling of a larger war too"*).
> The net used to be ONE man on ONE roster: your squad's RTO and nobody else, so standing next to a
> firebase radioman with a live PRC-25 on his back got you nothing. **Nearest living man in "radioman"
> wins, wherever he came from.** This is the ONE authority for "whose radio am I on" — do not re-derive
> it from a squad roster.

`nearest_radioman()` (`:795-812`) does exactly that: it iterates `get_nodes_in_group("radioman")`, skips
the dead, and returns the closest. **It never consults the squad roster.**

> **He proposed the borrowed-radio mechanic today as a new idea. He decreed it five weeks ago and the
> architecture was built to his decree.** The council should tell him so plainly — it is a much better
> position to start from than a blank page.

### 9.2 · And it is populated by exactly one man

Every non-bench registration into the group, project-wide:

```
scripts/squad/squad_system.gd:236    rto.add_to_group("radioman")     <- the player's own squad RTO
```

That is the complete list. The other three hits are dev benches (`ai_stress_arena.gd:1347`,
`support_fire_range.gd:269`, `test_range.gd:127`), unreachable from the title screen.

The firebase radioman the comment names as the motivating case **is never added to the group.**
He exists as a work-marker role — `site_planner.gd:1130` (`["FOOTPRINT_003", "radioman", 1]`),
`:1173`, `:1218` — staffed by a garrison defender, and `scripts/allies/garrison_defender.gd:14` says so
outright: ***"(The firebase radioman is background - never the player's RTO.)"***

> **DRIFT, recorded per NO MORE DRIFT and the truth law (ADR-015).** The comment at
> `field_director.gd:791-793` asserts the firebase-radioman case works — *"standing next to a firebase
> radioman with a live PRC-25 on his back got you nothing"*, framed as the defect the change fixed. **It
> still gets you nothing**, because nothing but `squad_system.gd:236` ever joins the group. The capability
> is real; the population is empty. A comment claims behaviour no probe proved.
>
> **ADR-011 is also stale on this point.** It still reads *"the radio is a MAN … a LIVING RTO"* keyed to
> the squad; his 2026-08-05 ruling made it *any* radioman and the ADR was never amended. Whatever this
> council decides, ADR-011 owes an amendment for a ruling already thirty-five days old.

### 9.3 · The living world of other people's squads is PARTLY BUILT — and it has no radioman

`scripts/missions/friendly_patrol_group.gd` — `class_name FriendlyPatrolGroup extends LazyGroup`. Its own
header:

> *"an ambient US element walking the AO … They are US-side and armed, but they are **NOT the player's
> squad**: `squad_member` is false, they never enter `SquadSystem.members`, and **they take no orders**.
> When one is shot to pieces it calls for help on the net — the ONE producer for
> `&"friendly_patrol_pinned"`."*

It walks a looping waypoint route (`route`, `WAYPOINT_REACHED_M 6.0`), spawns real `AllyBase` men
(`:41`), drives them with the **same order verbs the player uses** (`set_order(HOLD)` `:54`,
`set_order(MOVE_TO, route[_wp])` `:56`, `:83`), holds a static one-at-a-time net-attention token
(`pinned_holder`), and dresses its men so the squad nameplate can identify them at 5 m — the comment
names the reason: *"without it an ambient friendly is an unnamed silhouette in US green — the blue-on-blue
the r4bk affordance exists to prevent."*

**Its MOS pool is `["POINTMAN", "RIFLEMAN", "RIFLEMAN", "MG"]` (`:36`). There is no RTO in it.**

### 9.4 · What this collapses the rung-2 build down to

| Piece | State |
|---|---|
| "Any radioman is the net" gate | **shipped** (`field_director.gd:795-822`) |
| Player walks up and takes a handset | **shipped** (`player.gd:438-451`, `:1055-1058`) |
| Error copy already written for strangers | **shipped** — `"TOO FAR FROM THE RADIO - GET TO A RADIO MAN (%dM)"` (`:820`) |
| Ambient US elements walking the AO | **shipped** (`friendly_patrol_group.gd`) |
| Nameplate so you can tell who a friendly is | **shipped** (`squad_nameplate.gd`) |
| **An RTO in any element that is not yours** | **MISSING** — one MOS in one pool, one `add_to_group` |
| **The social price: permission, budget, refusal under fire** | **MISSING — and this is the actual design work** |

> **Rung 2 is not a system to build. It is a man to add and a price to design.** That is the strongest
> argument in the session for building this rung first, and for building it small.

### 9.5 · Two more constants the ladder will need

- `RTO_RADIO_RANGE = 10.0` (`field_director.gd:364`) — the leash, unchanged since ADR-011.
- `RADIO_LEASH_M = 4.5` (`ally_base.gd:247`) with `radio_leash` (`:246`) — the RTO's follow tether, and
  **`net_planted` (`:298`)**, a mode in which the RTO stays put and the player ranges to `8.0 m`
  (`:1423-1428`). **A "plant the net here and go" verb already exists in the ally AI.** It is the natural
  home of the rung-3 companion's one verb.

### 9.6 · A line number corrected in passing

`_bank_patrol()` is at **`scripts/missions/field_director.gd:2053`**, with `bank_reputation` at `:2072`
and the promotion toast `"FIELD PROMOTION: %s"` at `:2073` — not `:1797`, which was cited in an analysis
this session and is stale.

---

## 10 · ADDENDUM 2 — "SQUADS AND WORLD HAPPENINGS ALL OVER THEM" IS ALREADY BUILT, AND IT IS ALSO HIS DECREE

His proposal's premise — *"the player is the solo person in this world and theres squads and world
happenings all over them"* — describes a world that largely exists.

### 10.1 · Ambient US elements walk the AO today

`scripts/missions/mission_generator.gd:1005-1029`, `_spawn_friendly_patrols()`:

```
const FRIENDLY_PATROLS: int = 2
const FRIENDLY_PATROL_MEN: int = 4
```

Two four-man US elements, seeded (`int(p.seed) + 97 * (pi + 1)`), routed on a real patrol circuit
between the gate and the villages, `activation_range 140.0`. Its comment names the care already taken:
they are *"deliberately NOT routed through `spawn_tracked_enemy` — that would file them in
`_live_enemies` and register them as contact groups in the ADR-006 ledger."*

### 10.2 · And other people's FIGHTS are a shipped pacing engine — his decree, 2026-08-07

`scripts/world/ambient_encounters.gd:1-30`:

> *"**The walking dice (his decree 2026-08-07): distance travelled outside the wire is the pacing
> engine** — every `ROLL_EVERY_M` walked, one roll may stage ONE ambient encounter. Three kinds: VC
> leaning on the ville, **a friendly element passing through**, **a friendly element stuck in a real
> firefight.** Never two at once, never during the siege, never at night, never inside the first ten
> minutes."*

Knobs: `ROLL_EVERY_M 65.0` · `EVENT_CHANCE 0.35` · `HOLD_S 600.0` · `COOLDOWN_S 240.0` ·
`DAY_CAPS {"harass": 1, "patrol": 2, "contact": 1}` · `WIRE_M 110.0`. It carries RTB orders, a
lead-home check and element teardown (`:461-494`).

### 10.3 · THE CONVERGENCE — the proposal is the capstone of three of his own prior decrees

| Date | His decree | As-built |
|---|---|---|
| **2026-07-12** | ADR-020's first-patrol guarantee includes *"**A firefight you HEAR and never reach** → the war is bigger than you, and you cannot fix it"* (`ADR-020:56`) | canon |
| **2026-08-05** | *"make it so all radiomen are valid call options and the menu is universal"* — *"that does feul that feeling of a larger war too"* | `nearest_radioman()` shipped; **group has one member** |
| **2026-08-07** | the walking dice — VC harassment, a friendly element passing, **a friendly element in a real firefight** | `ambient_encounters.gd` shipped |
| **2026-09-09** | *"the player is the solo person in this world and theres squads and world happenings all over them… come up to a radio man can also just use it to call stuff in"* | **this session** |

> **THE ARBITER'S HEADLINE FINDING: this is not a new direction. It is the capstone of three decrees he
> already made, and it converts ADR-020's saddest line into a verb.**
>
> ADR-020 promised the player a firefight he can hear and *never reach* — *"the war is bigger than you,
> and you cannot fix it."* The walking dice built that firefight. The universal net built the means.
> **Put one radioman in that element and the beat becomes: the war is bigger than you — but you can
> reach a man with a radio, and do something about it.** That is the whole proposal, and two thirds of
> it shipped weeks ago.

**What is genuinely missing is three things, and only three:**
1. **A radioman in any element that is not the player's** (one MOS in `friendly_patrol_group.gd:36`,
   one `add_to_group`, one PRC-25 dress variant).
2. **The player being alone** (stop `SquadRoster.ensure_roster()` self-healing to eight,
   `squad_roster.gd:178-179`; make squad size a campaign variable, not two hand-synced constants).
3. **The social price** — permission, budget, refusal under fire. **This is the only part that is
   actual design work, and it is small.**

---

## 11 · ADDENDUM 3 — THE COMPANION RUNG ALSO EXISTS ALREADY, IN A DIFFERENT COSTUME

`scripts/world/pilot_recovery.gd` — *"the downed-pilot chain (S28, his 8/7 ruling)"* — is a shipped,
non-squad ally companion with a full lifecycle:

- He **waits in the world** beside his wreck, with a lazy VC picket nearby.
- He **wakes for the man who came for him**: `WAKE_M = 12.0` — *"He stands up for the man who came for
  him, not for a passer-by at 40m."*
- He **follows the player**: `enum Phase { IDLE, WAIT, ESCORT, DONE }`, driving
  `set_order(FOLLOW)` / `set_order(MOVE_TO, _ward_pos())` / `set_order(HOLD)` (`:176, :222, :240`).
- He **banks at the wire**: `HOME_M = 30.0`.
- He is **exclusive with the walking dice** and carries unconditional timeouts on every phase
  (`WAIT_TIMEOUT_S` / `ESCORT_TIMEOUT_S`, both 420 s).

> **Rung 3 — the RTO companion — is architecturally the pilot chain with a radio instead of a .45.**
> Attach point, wake distance, escort phase, bank-at-the-wire and the exclusivity guard are all shipped.

### And its header contains the warning this council most needs

> *"THE UNCONDITIONAL CLOCK. Neither phase had one, and `encounter_active()` suppresses every ambient
> encounter while this chain is live — so a pilot the player never walked out to **silently killed the
> walking dice for the whole rest of the run**, and the symptom read as *"the encounters are boring"*,
> not *"a system is stuck"*."*

**A companion is a state machine that can wedge the living world, and the wedge presents as boredom.**
Any RTO-companion or borrowed-RTO state must carry an unconditional timeout from its first commit, and
must be registered in `MissionScope.reset()`.

### Its UX pattern is the one the ladder should copy

> *"Period HUD decree: NO marker, NO objective text — **the smoke column IS the waypoint**; toasts are
> the radio."*

The same doctrine the UX lens reached independently this session (*"the man is the marker"*).

---

## 12 · ADDENDUM 4 — DOORS, VERIFIED BY THE ARBITER

| Door | Verified state | Cost now → later |
|---|---|---|
| `AllyBase.set_order()` signature (`ally_base.gd:329`) | **28 call sites across 15 files** (`garrison_defender` ×2, `ai_stress_arena` ×4, `demo_game` ×2, `friendly_patrol_group` ×3, `scripted_sequence` ×2, `squad_system` ×4, `seat_system`, `ambient_encounters`, `pilot_recovery` ×3, benches ×4, `player.gd:551`, `gore_lab`) | 28 now; grows with every AI wave. *(An analysis this session called it "a handful" — it is 28. Corrected.)* |
| `AllyBase` order default | `var order_mode: OrderMode = OrderMode.FOLLOW` (`ally_base.gd:295`) — `friendly_patrol_group.gd:50-57` has to **undo** it for every ambient man | free now; a defect generator per new spawner |
| Roster strip layout | `_squad_panel.position = Vector2(12, -310)` with *"Two lines per man"* (`mission_hud.gd:258-259`) — **hard-anchored for a fixed count** | one expression now; a layout pass later |
| Fire-support dispatch owner | `_mark_dispatch(kind: String, target: Vector3, run_dir: Vector3)` (`field_director.gd:459`) — **no source/owner field** | one argument now; a schema migration through every consumer later |
| Tour / rotation clock | **DOES NOT EXIST.** No `days_left`, `tour_days`, `rotate_home`, `DEROS`, `days_in_country` anywhere in `scripts/`. Only `_sim_day()` (`field_director.gd:67`) | **Pillar 4 promises men who "rotate home" and nothing in code counts a tour.** A standing debt, not new work created by this decree |
