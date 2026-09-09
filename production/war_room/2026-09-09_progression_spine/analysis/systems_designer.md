# SYSTEMS DESIGNER — THE PROGRESSION SPINE
**War Room 2026-09-09 · post-demo · the economy, the state, the rules**
All code claims verified this session against the files cited (pointer law).

---

## 0 · THE FINDING THAT REFRAMES THE WHOLE QUERY

**Two of the rungs he is asking for are already in the code, and one clause of ADR-011 is already a fossil.**

- **"Borrow any RTO you meet" is his own ruling from 2026-08-05 and it SHIPPED.** `nearest_radioman()`
  (`field_director.gd:795-811`) takes the nearest living member of group `"radioman"` *wherever he came
  from*, and the header says so explicitly: *"This is the ONE authority for 'whose radio am I on' — do
  not re-derive it from a squad roster."* The player-side half shipped too: `_rebind_nearest_handset()`
  (`player.gd:493-518`) and the interact verb **`[F] TAKE HANDSET`** on an aimed radioman
  (`player.gd:624`). Rung 2 is not a new mechanic. It is a **supply problem**.
- **The supply is zero.** `FriendlyPatrolGroup._spawn_men()` builds from
  `["POINTMAN","RIFLEMAN","RIFLEMAN","MG"]` — **no RTO** (`friendly_patrol_group.gd:36`). And
  `GarrisonDefender` states in its own header *"The firebase radioman is background — never the player's
  RTO"* (`garrison_defender.gd:14`). **There is nobody in the world to borrow from.** The verb exists and
  points at an empty population.
- **ADR-011's "budgets are rolled at briefing, per mission type" is DEAD PROSE.** The code allots
  **once per simulated day**, latched on `_sim_day()`, at the wire crossing:
  `_grant_fire_support()` (`field_director.gd:1488-1494`, comment *"ONE ALLOTMENT PER DAY"*), scaled by
  threat tier, cut by `title_tier()` (`:1514-1522`), docked by `CampaignState.depot_loss` (`:1536-1543`).
  ADR-029 deleted the briefing. **Question 5 is already answered by the code; the ADR just hasn't been
  told.** Correct it on contact (CLAUDE.md no-drift law).

---

## 1 · ADR-011: AMENDED, NOT SUPERSEDED. THE HANDHELD IS NOT A BYPASS.

ADR-011's law has two clauses and they are not equally load-bearing:

| Clause | Status | Why |
|---|---|---|
| *"One leash function (`_radio_check()`) gates every entry point… **No bypass paths**"* | **INVIOLATE** | An architecture law, and the reason the fire net is the best-guarded input surface in the game. Every path — menu, arm, dispatch, [Y] shortcut, supply drop — routes through it (`field_director.gd:256, 386, 523, 1050, 1301, 1656, 1685`). |
| *"The radio is a man… a LIVING RTO within `RTO_RADIO_RANGE` (10.0m)"* | **AMENDABLE** | This is a **predicate inside** the gate (`_radio_check()`, `field_director.gd:814-822`), not the gate itself. |

> **THE AMENDMENT, precisely: a bypass is a call path that does not call `_radio_check()`. Adding a new
> SOURCE that `_radio_check()` accepts is not a bypass. What `_radio_check()` accepts may be amended;
> that everything calls it may never be.**

That one sentence saves ADR-011 whole and still lets the handheld exist. The man stops being the only
net and becomes **the best net** — the code stays one gate.

### What the handheld CAN and CANNOT do

| | Man on the net (RTO within 10m) | Your own handheld |
|---|---|---|
| Tubes (mortar, illum, WP) | yes | **yes** |
| Battery (arty 105s) | yes | **yes, but no adjustment / no walk-in** |
| Fast movers / napalm / CBU / Spectre | yes (rank-gated, `:1514-1522`) | **NEVER.** Battalion talks to RTOs. |
| Resupply drop | yes | **no** |
| Sheaf quality | `fo_fac` 1.0→0.45, veteran 4th round (`:1499`, ADR-011) | **fixed at `fo_fac` 0** — the widest scatter in the game |
| Net cooldown | `25 − 2×fo` s, floor 10 (`field_director.gd:555-557`) | **flat 25 s, no floor relief** |
| Danger-close confirm | his voice, 5 s window | same protocol, **no VO** — alone with the decision |
| Your hands | free — **you keep shooting while he talks** | **rifle stowed for the whole transmission** |
| Your ruck | his 25 lb | **yours** — the handheld eats the LAW/satchel/ration slot |
| Your signature | his whip antenna | **yours** |

### Why the top rung does not cannibalise the middle

The handheld is **strictly worse in five dimensions** and better in exactly one: **leash**. He buys
freedom of position and pays in tier ceiling, sheaf quality, latency, hands and weight. An RTO remains
the only way to get fast movers onto a target *while you are still firing your rifle* — and the fast
movers are the most spectacular system in the game.

Three teeth stop the handheld ending the ladder:
1. **HANDS.** Transmitting stows the rifle and pins you (ADR-004's rifle-down/handset-up grammar). An
   RTO exists so that *somebody else's* hands are full.
2. **SIGNATURE.** A transmitting handheld is a detection event under the witness rule (ADR-005) and a
   magnet for counter-battery and snipers. The RTO has always been the man who dies first; carry his
   radio and you inherit his death.
3. **BREAKAGE.** The handset is already a physical object with state (`RadioHandset`, `RadioCord`,
   `player.gd:_bound_handset`). It can be shot off you, drowned, and left on your corpse.

---

## 2 · THE LADDER AS AN ECONOMY

Every rung strictly better in ONE axis and strictly worse in another, or it is just "more power."

| Rung | Latency | Tier ceiling | Reliability | Leash | Risk | Whose budget | **WHAT IT GIVES UP** |
|---|---|---|---|---|---|---|---|
| **0 · Solo, no net** | instant (organic only) | grenades, LAW, WP, smoke | your aim | **none** | none | yours (carried) | **all steel that falls from the sky** |
| **1 · Mission-supplied RTO** | fast | full, rank-gated | best (`fo_fac` grows) | **10 m** | a stranger; he leaves at the wire | battalion, daily | **he goes home.** Nothing persists |
| **2 · Borrowed RTO** | slow — you must *reach* him | tubes + arty; air only if his element rates it | his `fo_fac`, not yours | 10 m **of a man walking his own route** | his element's contact state can deny you | **HIS**, small, one call | **timing.** You call when you can reach him, not when you need it |
| **3 · RTO companion** | fast | full, rank-gated | best, and **it grows with you** | 10 m | **permadeath**; a poor rifleman | battalion, daily | a body you must feed, protect and lose |
| **4 · Own handheld** | slowest (stow, transmit, no adjust) | **tubes + unadjusted arty ONLY** | worst sheaf in the game | **∞** | signature, weight, breakage | **your own personal allotment — smallest pot** | hands, ruck, quiet |
| **5 · Up to 8 men** | fast | full | best | 10 m | 8 casualties are yours | battalion, daily | **the stealth economy.** Eight men are eight detection sources against the contact ledger (`mission_state.gd:105-110`) |

**ADR-018's LADDER LAW survives, restated.** ADR-018 says *"rank gates how BIG, never WHETHER."* Rung 0
appears to breach it. It does not: **being off the net is a POSITION, not a rank gate.**

> **A player may always REACH a net within a bounded walk.** Rank decides how big. Position decides
> whether. Nothing in this ladder may make *"no fire support at all, at this rank"* true.

---

## 3 · BORROWED RTO — THE RULES (state, not a prompt)

The briefing asks it to hang off "existing conversation systems." **There are none** — a repo-wide search
for a conversation/dialogue/topic system returns nothing, and the interact verb is a hardcoded if-ladder
with load-bearing priority ordering (`player.gd:606-660`; the two-quests plan says so at
`DEMO_TWO_QUESTS_PLAN_2026-09-06.md:166`). So it hangs off **the interact verb plus per-element state** —
which is the correct place anyway, and which is where `[F] TAKE HANDSET` already lives.

Each borrowable element carries a net record:

| Gate | Source | Rule |
|---|---|---|
| `net_state` | derived | `OPEN` / `BUSY` / `SPENT` / `SOUR` / `DEAD` |
| **availability** | the world | An element has a radioman or it does not. ~1 in 3 ambient elements, plus the firebase TOC. Rarity IS the gate. |
| **permission** | `CampaignState.title_tier()` (ADR-032) | A PVT gets the handset for tubes. A SGT gets the element's air if it has any. Refusal is a line, never a lock. |
| **his own state** | **already shipped** — `_last_contact_ms`, `_reported`, `pinned_holder` (`friendly_patrol_group.gd:16-29`) | An element in contact is `BUSY`; his net is his own lifeline first. **Reuse this state; do not invent a second one.** |
| **budget** | **HIS** — never merged into `FieldDirector.fire_support` | 1–2 tubes, never air, per element per day |
| **consequence** | per-element standing in the ledger | Spending his stock sets `SPENT` for the day. Shelling his men danger-close sets `SOUR` **for the tour**. |

**What stops the vending machine — three teeth, none of them a cooldown:**
1. **He walks away.** The element loops a route (`friendly_patrol_group.gd:_advance_route`). The radio you
   used yesterday is four klicks north today.
2. **He has one call, not a menu.** His pot is a patrol's pot, not a battalion's.
3. **The ask costs standing.** And what the player actually wants is not *more* calls — it is **calls at
   the moment of contact**. A borrowed net can never give him that, because contact is exactly when he
   cannot walk to the man and exactly when that man's net is BUSY. **That is the structural reason to
   want your own radio** — no number tuning required.

---

## 4 · STATE AND PERSISTENCE

`CampaignState` is a flat cfg, `SAVE_VERSION = 1` (`campaign_state.gd:6`), and ADR-032 already set the
precedent for **superset reads with no version bump** (`reputation` falling back to `team_xp`,
`campaign_state.gd:250, 297`). Follow it exactly.

| New field | Type | Default on an old save |
|---|---|---|
| `spine_rung` | `int` | 0 |
| `companion_id` | `String` (roster key) | `""` |
| `has_handset` / `handset_condition` | `bool` / `float` | false / 1.0 — mirror the `rack_condition` shape (`campaign_state.gd:116`) |
| `element_standing` | `Dictionary` element_key → `{asked_day, spent, sour}` | `{}` |

**ADR-010 bites hard here.** `pinned_holder` is an **instance id**, explicitly cleared by
`MissionScope.reset()` (`friendly_patrol_group.gd:19-29`) — precisely the shape that must never be
persisted. **Element identity in the ledger must be SEED-DERIVED** (operation seed + element index),
never an instance id, or a load re-keys every relationship the player built. Any new static the ladder
introduces registers in `MissionScope.reset()` or it is a defect (ADR-010).

**When the companion RTO dies: permadeath, and the rung DOES NOT FALL.** ADR-006 Amendment B §5 already
ruled this economy a ratchet that never demotes, for a concrete reason — a demotion strands the player
below his own armory tier. Same logic: you lose **the man**, not **the trust**. You may request another
after a wait measured in campaign days, and **he arrives green** (`fo_fac` 0 — widest sheaf, longest
cooldown, no veteran 4th round). That is ADR-018 §2's silent veterancy finally having teeth, priced in
the one currency the player can actually feel: the shape of the sheaf on the ground.
**Handheld loss is different** — it is an object, so losing it *does* drop you a rung until replaced.

---

## 5 · FIRE SUPPORT BUDGETS — THREE POTS, NEVER MERGED

| Pot | Owner | Refill | Consumed by |
|---|---|---|---|
| **Battalion daily** | `FieldDirector.fire_support`, latched by `_sim_day()` (`:1488-1494`) | once per day at the wire | rungs 1, 3, 5 |
| **Element** | the borrowed man's element record | once per day, 1–2 tubes | rung 2 |
| **Personal** | the handheld's own small allotment | once per day, smallest | rung 4 |

Merging any two of these deletes the ladder. If a borrowed call decrements the battalion pot, borrowing
is free and rung 3 has no buyer. Keep `fire_support` the shape it is; add a **net-identity accessor** at
the day-latch so the dispatch path asks *"whose pot"* in one place, not at every call site.

---

## 6 · THE COMMAND VERBS AS STATE MACHINES — and the defect to design out

> **THE FAILURE MODE HAS A NAME: THE ARRIVED-AND-IDLE MAN.** It is in the shipping code today.
> `OrderMode.MOVE_TO` (`ally_base.gd:1487-1491`) tests distance every frame and, on arrival, falls into
> `_settle(delta)` — **the order mode never changes.** The man is permanently "MOVE_TO, arrived": not
> following, not holding a post, no facing, no sector, and **no system can ask him what he is doing**,
> because his state still says he is walking. His *"move here, which then creates a hold and defend
> command"* is a request for the missing transition, by name.

**The rule that designs it out: arrival is a TRANSITION, not a distance test — and a man may never exist
in a state with no instruction.** Enforce it at the setter: `set_order()` (`ally_base.gd:329`) takes
`(mode, pos, facing, intent)` and refuses an order missing any of them.

| Verb | From → To | On arrival | Dwell | Breaks the state | Player 300 m away |
|---|---|---|---|---|---|
| **MOVE HERE** | FOLLOW/HOLDING → **MOVING** | **auto-transition to HOLD AND DEFEND**: snap to best cover within 8 m, face away from the squad centroid (or toward last contact) | — | path failure or 45 s of no progress → HOLD where he stands, with a bark | — |
| **HOLD AND DEFEND** | ← MOVING | — | **indefinite** — a held post is held | REGROUP · post untenable (half the element down, or flanked) · medic call · **player beyond `RECALL_M`** | **auto-RALLY on the player**, with a bark |
| **REGROUP** | any → **RALLYING** | → FOLLOW at the slot | — | a new order | rallies |
| **ATTACK** | any → **ASSAULTING** (target = entity + anchor position) | target dead/lost 10 s → **HOLD AND DEFEND at the point of last contact** — never FOLLOW, which is the same bug in another suit | — | suppression break (FEAR doctrine) → BROKEN → recovers to HOLD | rallies |

**The 300 m ruling, and its cost.** Men holding beyond `RECALL_M` (~150 m) auto-rally to the player.
**Tradeoff named:** this deletes the "leave a support-by-fire element 300 m out" tactic. Deleted on
purpose — it is invisible to the player, it is exactly the case the AI cannot hold, and Pillar 4 says you
are *in* the squad, not a cursor above it. A man you cannot see doing a job you cannot verify is a
simulation cost that buys nothing.

---

## 7 · THE AGGRESSIVE ATTACK — one scalar, emergent cost

Aim + pull trigger is the same ATTACK order with `aggression = 1.0` instead of `0.35`. That one scalar
drives five dials:

| Dial | Deliberate | Aggressive |
|---|---|---|
| Burst length / RoF | controlled bursts | sustained |
| Cover dwell | peek → shoot → return | short exposure, stays up |
| Advance willingness | bounds only when the target is suppressed | advances regardless |
| Exposure tolerance (the FEAR self-preservation threshold) | goes to ground early | keeps moving under fire |
| Suppression output | aimed at the man | volume at the area |

**The cost must be EMERGENT, never a roll.** Do not add a casualty chance — Pillar 1 forbids death from
hit-point math. Aggression multiplies **time out of cover** and **advance distance per bound**, and
divides **the suppression level at which he goes to ground**. The enemy's already-lethal, already-accurate
fire then does the killing. The casualties are real, they are legible, and no die was rolled.
Second cost, already priced by canon: an aggressive assault near a ville is fire discipline spent, and
fire discipline near a ville **is** allegiance (ADR-006 Amendment B) — read through the contact ledger
that Amendment B §1 forbids anyone from deleting.

---

## 8 · FOSSIL LAW (ADR-023)

**Must be deleted when this ships:**
- **ADR-011's *"budgets are rolled at briefing, per mission type"* clause** and its
  `mission_generator.gd:103/132/153/236/248` citations. There is no briefing (ADR-029) and the code
  allots per day. **This is a live fossil in canon prose today** — correct it on contact.
- **`OrderMode.MOVE_TO` as a terminal state** (`ally_base.gd:1487-1491`). Replaced by the arrival
  transition; the `else: _settle(delta)` branch must go, not linger as a fallback.
- **GAME_GUIDE §4.4's FOLLOW / HOLD / MOVE-TO / FIRE-TOGGLE vocabulary**, if the verb set reduces to four.
  Two order vocabularies in one game is precisely the disease ADR-023 names.
- **`_drop_ammo_box()` bolted to the HOLD key** (`squad_system.gd:283-284`). If HOLD becomes an *arrival*
  state, this drops an ammo box every time any man arrives anywhere. Name it now or it ships as a bug.

**Must NOT be deleted — GATED, not replaced:** `SquadSystem` and the 5-man roster · formations and slot
logic · `member_by_mos` · the `fo_fac` quality path (`field_director.gd:1499, 555-557`) · the
`RadioHandset` / `RadioCord` physical net · `_radio_check()` itself · `_grant_fire_support()` · the
contact ledger (`mission_state.gd:105-110`, protected by ADR-006-B §1).
**This pivot deletes no squad code.** It moves the squad from hour 0 to hour N. Anyone reading it as
"we don't need the squad systems" has misread it, and that sentence belongs in the decree.

---

## 9 · DOORS TO KEEP OPEN — decisions being made NOW that get expensive later

1. **Seed a radioman MOS into ambient friendly elements — or at minimum reserve the slot.**
   `friendly_patrol_group.gd:36`'s pool is one line of code, but the **art** is a PRC-25 backpack variant,
   the `"radioman"` group join and a `RadioHandset` child. If the character/event census is being frozen
   now, **radiomen must be counted as a first-class population**, or rung 2 has no supply and the
   already-shipped `[F] TAKE HANDSET` verb keeps pointing at nothing.
2. **The firebase stamped kit must carry a `radio_post` ANCHOR, not only buildings.** `site_planner`
   already knows the post (`site_planner.gd:1130, 1173` map `"radio"`/`"plot"` → `"radioman"`). Bake that
   anchor in **while the kit is being authored** — retrofitting anchors into a frozen modular kit is
   per-building work; adding one named marker now is free.
3. **Change `AllyBase.set_order()`'s signature TODAY** (`ally_base.gd:329`) to require facing + intent,
   even if every current caller passes a default. There are a handful of call sites right now. After a
   squad-AI wave lands it is a refactor across the whole AI — and until then, every new order re-creates
   the arrived-and-idle man.
4. **Stop `AllyBase` defaulting to FOLLOW.** It defaults to FOLLOW, and `friendly_patrol_group.gd:50-57`
   has to *undo* it for every ambient man. In a solo world most men are not the player's, so the default
   is wrong for the majority case. Make each spawner state it explicitly now — a silent default every new
   spawner must remember to override is a defect generator.
5. **The event/VFX census must record the SOURCE of every fire-support event, not just the kind.**
   `_mark_dispatch(kind, target, run_dir)` (`field_director.gd:459`) has no owner field. One string
   argument now; a schema migration through every consumer later.
6. **Rule NOW that world-element identity is SEED-DERIVED, not instance-id** — before the census hands out
   ids. `pinned_holder` (`friendly_patrol_group.gd:19-29`) shows the alternative: an identity
   `MissionScope` must wipe every mission, that can never be persisted or related to (ADR-010).
7. **Do not merge the fire-support pot into anything.** Keep `fire_support` a dict owned by the director
   and introduce the net-identity getter at the day-latch (`field_director.gd:1488`) while there is still
   only one pot. A second pot is then one function; without it, it is every call site.
8. **Do not touch the demo's supplied-RTO framing.** The demo already ships rung 1. It is the ladder's
   floor, already built and already playtested. Leave it where it is.

---

## TRADEOFFS, NAMED (Council Law 2)

- **The handheld costs the RTO his uniqueness.** He stops being the only net and becomes the *best* net —
  a real demotion of ADR-011's poetry, bought deliberately in exchange for a ladder.
- **The 150 m auto-rally deletes the detached support-by-fire element.** Accepted: invisible, and the AI
  cannot hold it.
- **Three pots is three ledgers to debug**, inside an economy the player never sees (ADR-032's standing
  cost — a hidden economy is hard to reason about, and the probe carries that weight).
- **Rung 2 needs a population that does not exist**, which means art-days before it can be tested at all.
- **A green replacement companion is a punishment the player did not choose.** It is the price of Pillar 4
  having teeth, and it is the same bet ADR-018 already made.
