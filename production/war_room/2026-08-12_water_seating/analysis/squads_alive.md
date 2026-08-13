# COMBAT FEEL ARCHITECT — "Squads that read as alive, not as bullet fodder"

**War Room session:** 2026-08-12 · **Charge:** design of aliveness, NOT wiring.
**Constraint:** modern decision quality, PSX presentation. Only **sound, silhouette, position, timing** read.
**Weighting:** allies heavier than enemies — the player's eight men are on screen every second of the game.

All claims below carry `file:line` (POINTER LAW). Read against code, not docs.

---

## 0. THE HEADLINE FINDING

**RECONgame's enemies have more personhood machinery than the player's own squad.**

An NVA regular gets: a rolled personality archetype with five varying traits
(`enemy_base.gd:378-398`), a down-not-dead state (`enemy_base.gd:2699`), a
squadmate who breaks off to drag him out of the fight (`enemy_base.gd:2656-2694`), a
morale break ladder that can rout him or make him throw his rifle down
(`enemy_base.gd:2522-2544`), limb wounds that degrade him (`enemy_base.gd:2582-2591`),
and a witness system so his death propagates to the men who saw it (`enemy_base.gd:1064`).

An American in the player's squad gets: two scalars (`ally_base.gd:104-105`), and
death at zero HP with no intermediate state (`ally_base.gd:1846-1848`).

That inversion is the whole problem. The men the player is *supposed to bond with* are
the thinnest actors in the game. Everything below is that finding, decomposed.

---

## 1. SELF-PRESERVATION — "does he act like he wants to live?"

### What exists (enemy side — genuinely good)

| Behaviour | Pointer | Reachable in a normal firefight? |
|---|---|---|
| Rout (drop fight, run rear, VO) | `enemy_base.gd:2540-2544` | YES — fires on any non-fatal hit once `pressure > 0.7 + courage*0.6 + nerve`, 25% roll |
| Chieu Hoi / surrender | `enemy_base.gd:2536-2538` | RARE — needs `living_nearby == 0` **and** hp < 1/3 **and** a further 40% roll. Compound ≈ single-digit % of contacts |
| Down-not-dead | `enemy_base.gd:2494-2503` | YES — 35% at zero-margin lethal hits, fading to 0 at 40 overkill |
| Crippled (2 leg wounds → crawl) | `enemy_base.gd:2569-2591` | Occasional |
| Squad break / withdrawal | `enemy_squad.gd:119-141`, `marching_cell.gd:135` | Siege-only in practice; `withdraw_to` has one caller class |

The **numbers term** is the good part: `enemy_base.gd:2529` stiffens a man's spine by
force ratio, and `combat_goals.gd:149-153` breaks the badly outnumbered. That is modern
thinking and it reads correctly — men with friends up hold, lone men run.

### What is shallow

The rout is a **coin flip on a damage event**, not a decision. A man does not decide the
treeline is not worth crossing; he decides only after a bullet has already found him.
There is no *anticipatory* self-preservation anywhere — nothing in `combat_goals.gd` asks
"how exposed is the ground between me and where I am being sent". `under_unanswered_fire`
(`combat_goals.gd:74`) is the closest thing and it is reactive to suppression, not
predictive of terrain.

**A man who only flinches after being hit reads as a machine with a damage handler.**

### What is absent (allies)

- **No rout.** No ally ever runs.
- **No surrender.** Correct for the fantasy; not a gap.
- **No down state.** `ally_base.gd:1846` → `_die()`. A squadmate is upright or he is meat.
  `campaign_state.gd:266-274` says so in its own comment and even names the fix:
  *"DELETE THIS DERIVATION the day allies gain a real wounded state."* The ward's WIA count
  is currently **derived at 3× KIA** because no per-man wounded state exists to read.
- **No wounds.** `apply_wound` exists on `EnemyBase` only. An ally's legs never fail.
- **No refusal, no hesitation.** `set_order` (`ally_base.gd:245`) is a two-line setter with
  no gate of any kind. Every order is obeyed instantly by every man regardless of his state.
  **This is the single largest "he is not a person" tell in the game**, and the player
  triggers it himself, on purpose, several times a minute.

**Verdict §1: the enemy's self-preservation is real but reactive. The ally's is absent.**

---

## 2. INDIVIDUATION — the big one

### The audit: what actually varies between two men in the same squad

Every squad member is built at `squad_system.gd:67-100`. What is per-man:

| Property | Per-man? | Pointer |
|---|---|---|
| `courage` | YES — `randf_range` inside an MOS band | `squad_system.gd:85`, bands at `:133-141` |
| `skill` (spread) | YES — `randf()` | `ally_base.gd:371` |
| `fire_rate_mult` | MG only (1.6) | `squad_system.gd:89` |
| `face`, `helmet` | YES, cosmetic | `squad_roster.gd:108-109` |
| `st/ag/al`, skills | YES — but read by **five** call sites total | `squad_roster.gd:99-100` |
| `preferred_range` | **NO — 14.0 for all eight** | `ally_base.gd:10` |
| `move_speed` | **NO — 5.6 for all eight** | `ally_base.gd:9` |
| `max_hp` | **NO — 80 for all eight** | `ally_base.gd:7` |
| `MAX_BURST` | **NO — const 6** | `ally_base.gd:258` |
| `aim_speed` | **NO — 7.0** | `ally_base.gd:189` |
| reaction time | **NO** — `_aim_settle = randf_range(0.45,0.9)` is re-rolled **per contact**, not per man | `ally_base.gd:790` |
| voice | 2 voices for 8 men, by name hash | `vo_manager.gd:15,70-72` |

Compare `enemy_base.gd:378-398`, where a single enemy rolls `char_aggression`,
`char_accuracy`, `char_reaction`, `char_self_preservation` **and** `aim_speed` per man.
**The enemy has a five-trait personality vector. The ally has one and a half.**

### Now quantify: how much observable behaviour does `courage` actually buy?

`courage` reaches behaviour through exactly five gates. Take two riflemen from the same
band (`squad_system.gd:140`, `[0.25, 0.9]`): **A = 0.30 (timid), B = 0.85 (bold)**.

**First, the rally trap.** `effective_courage()` (`ally_base.gd:111-117`) adds **+0.25**
when the player is within **6.0m**. The follow slot is rolled at **2.5–4.5m**
(`ally_base.gd:367`). *A squad in FOLLOW is essentially always inside the rally radius.*
So in play, A reads **0.55** and B reads **1.0** (clamped from 1.10).

Now walk the five gates:

1. **`wants_cover_first`** (`:136-142`) — the 0.75 bar. A takes the cover trip, B skips it.
   But the term is `_contact_time < 5.0`. **Divergence duration: five seconds, once per contact.**
2. **`may_close_distance`** (`:147-148`) — requires `nerve < 0.35`. With the rally bonus the
   **lowest possible effective courage of any rifleman is 0.50**. Medic floor: 0.40. RTO
   floor: 0.35 — *not less than* 0.35. **This branch is mathematically dead for the entire
   player squad whenever the player is nearby, i.e. always.** The "coward anchors on his
   rock" behaviour, written and commented at `:1259-1261`, has never once run in the
   player's squad.
3. **`advance_band`** (`:1263`) — 0.9 vs 1.2 at the 0.7 bar. A holds at 16.8m, B at 12.6m.
   **A 4.2m standoff difference**, inside jungle draw distance, between two men who are
   both moving. Sub-perceptual.
4. **CombatGoals `aggression`/`self_preservation`** (`:920-921`) — the one genuinely
   continuous channel. It shifts SEEK_COVER by ~0.13, damps ADVANCE ×0.45 below 0.7, and
   scales RETREAT — but `incumbent_mult` 1.5 (`combat_goals.gd:51,166`) means the goal
   only changes when the margin is large, and with the rally bonus most of the squad is
   bunched in the 0.5–1.0 range where these terms are close together.
5. **The cover-arrival dive-roll** (`:1504-1510`) — reads **raw** `courage < 0.3`, so it
   almost never fires for a rifleman, and when it does it is gated by a per-man cooldown
   AND a squad-wide window. Cosmetic, one animation.

**QUANTIFIED VERDICT:** two riflemen at opposite ends of the courage band behave
differently for **approximately the first five seconds of a contact**, and thereafter
differ by **one ~4m standoff band** and small continuous nudges inside a hysteresis
that suppresses them. Everything else — how fast he reacts, how far he stands off, how
long his bursts are, how quickly he swings his rifle, how much damage he absorbs, what
he sounds like, whether he says anything at all — **is identical across all eight men.**

**Personality in the player's squad is decorative.** The bands at `squad_system.gd:133-141`
buy role flavour (a timid RTO), not individual character.

### What SHOULD vary, and reads at PSX fidelity

Ordered by how visible each is through jungle at 30m with no face:

| Trait | Channel it reads on | Why it works at PSX |
|---|---|---|
| **Reaction time** (first shot after contact) | **timing** | One man is always first to fire. The player learns his name from the audio alone. |
| **Preferred range** | **position** | The pig hangs back and hoses; the pointman is always ten metres too far forward. Reads as silhouette spacing. |
| **Willingness to leave cover** | **position + timing** | A man who is still behind the log when everyone else moved is legible instantly. |
| **Rate/length of fire** | **sound** | Long ripping bursts vs. two-round taps is the most PSX-legible personality signal there is. |
| **Talkativeness** | **sound** | Who calls things out and who never says a word. |
| **Cover dwell** | **timing** | How long between peeks. |
| **Movement gait/speed** | **silhouette** | The slow man, the man who always jogs. |

All seven are **numbers on the roster dict**. None needs new art, none needs new AI.

---

## 3. CONTINUITY — a past and a future

### What exists (and it is more than expected)

`SquadRoster` is a real persistence layer, and a good one:
- 250×250 name tables drawn from the men the draft actually took (`squad_roster.gd:8-61`).
- Rolled attributes and starting skills — "no blank recruits" (`squad_roster.gd:117-135`).
- **Learn-by-doing** that persists: `credit_use` (`squad_roster.gd:143-161`), credited from
  a real kill (`enemy_base.gd:2560-2573`), from the point man spotting (`squad_system.gd:500`),
  from the medic working (`squad_system.gd:392`).
- **Earned rank** by missions survived (`squad_roster.gd:210-225`).
- **Earned nicknames** at 3 tours, with a one-shot christening toast — *"THE MEN HAVE
  STARTED CALLING %s..."* (`squad_system.gd:760-762`). This is the best single line of
  aliveness content in the project.
- A Barracks roster screen showing name / kills / missions (`barracks.gd:66-69`).
- A look-at nameplate at 5m with rank, role and nick (`squad_nameplate.gd`).

### What is shallow

- **The Barracks is behind the pause menu** (`game_flow.gd:340-349`). The place where the
  player's men become people is a submenu he may never open.
- **The nameplate is 5.0m / 12°** (`squad_nameplate.gd:10-12`). Reading a man's name
  requires walking up and staring at his chest. In a 30-minute demo most players will
  never learn a single name.
- Nicks need **3 tours** (`squad_roster.gd:75`) and only 4 MOS can earn one
  (`squad_roster.gd:72-74`). **In the EA demo — one firebase, one day — no nickname will
  ever be earned.** The best content in the system is unreachable in the shipping product.

### What is absent

- **THE DEAD ARE FORGOTTEN BY NAME.** `squad_system.gd:697` names every man lost into
  `state.flags["squad_kia"]`. `campaign_state.gd:264-267` then reads only `.size()` and
  increments two counters. **`ensure_roster` deletes the bodies** (`squad_roster.gd:170-173`,
  comment: *"they stay in memory only via the log"* — the log stores type/success/kills/seed,
  `campaign_state.gd:280-286`, **not names**). The butcher's bill is a number.
  There is no memorial, no KIA list, no way to ever see JOHNNY KOWALSKI's name again.
- **A man carries nothing forward from a bad contact.** No wound history, no "he was there
  when the LZ got hit", no changed behaviour after surviving something. `missions`, `kills`,
  `xp` and skills are the entire record of a life.
- **The player has no reason to know a name before he loses it.** The KIA toast
  (`squad_system.gd:699`) is the *first time* many players will read that man's name.

**§3 is the cheapest route from fodder to person and it is almost entirely a data/UI
question.** The persistence spine is already built and tested; what is missing is
*surfacing* and *remembering*.

---

## 4. ARC WITHIN A FIGHT — does a man change as it develops?

**Searched exhaustively. Almost nothing evolves.**

| Candidate | Verdict |
|---|---|
| `courage` | **Constant from spawn to death.** Rolled once (`squad_system.gd:85`), never written again. |
| `effective_courage()` | Varies only with **player proximity** (`ally_base.gd:111-117`). Not with the fight. |
| `_contact_time` | Accumulates (`ally_base.gd:847`) but is read at exactly **one** place — the 5s cover-first window (`:142`) — and one more in the scorer (`combat_goals.gd:85,95`). After 6 seconds it stops mattering forever. |
| `suppression_level` | Decays in ~3.3s (`ally_base.gd:663`). An **instant**, explicitly noted as such at `:267`. |
| `incoming_pressure` | Slower-decaying companion, but still a rolling window, not a trajectory. |
| `squad_broken` | A **binary**, flipped by headcount ratio (`squad_system.gd:458-464`). The only thing in the game that changes an ally's temperament mid-fight — and it is squad-wide, all-or-nothing, and needs roughly half the squad dead to fire. |
| Ammunition | **Nothing.** No ally tracks rounds. `squad_ammo_low.wav` exists in all three voice folders and has **no caller** anywhere. Nobody ever runs low. |
| Fatigue | **Does not exist for AI.** `stamina` is the player's alone (`player.gd:68`). Eight men jog a 500m patrol and are as fresh at the end as the start. |
| Anger / grief | **Does not exist.** See §5. |
| Enemy side | `enemy_base` is the same: `char_aggression` is set in `_ready()` and never rewritten. `alert_tier` changes, but that is knowledge, not temperament. |

**VERDICT §4: a RECONgame soldier's temperament is a constant. He starts a firefight and
ends it the same man.** The only mid-fight state changes are a 3-second suppression
instant and one squad-wide binary. This is the second-largest fodder tell: *a fight
does not do anything to anyone.*

---

## 5. RELATIONSHIPS — do men acknowledge each other?

### Enemy side — good, and the blueprint

- `_medic_think` scans a global `downed_pool` for a wounded comrade (`enemy_base.gd:2626-2647`).
- `_execute_aid` walks to him, sets `work_clip = "carry_wounded"`, plays `"being_carried"`
  on the casualty, and **drags him away from where the threat is believed to be**
  (`enemy_base.gd:2656-2694`). The rear is derived from `last_known_target_pos`, never
  from the player's true position — this is careful, honest AI.
- `_witness_check` (`enemy_base.gd:1064-1080`) propagates a death to men who could see or
  hear it. Comrades react to a specific loss.
- Contact adoption: *"A buddy sees the enemy; I don't. Adopt the squad's contact and wake up"*
  (`enemy_base.gd:1012`).
- `MarchingCell` (`marching_cell.gd`) is a *cell*, not a bag of men — it materialises
  together, withdraws together on the axis it came in on (`:135-166`).

### Ally side — almost nothing

- **The medic serves the PLAYER only.** The entire revive chain (`squad_system.gd:346-401`)
  is bound to `HealthSystem.revive_handler` on `world.player` (`:122-125`). Doc will cross
  open ground to bandage the player and will **never** so much as glance at a squadmate,
  because a squadmate has no downed state to notice.
- **Nobody reacts to a squadmate's death.** `died` has exactly one listener,
  `_on_member_died` (`squad_system.gd:693`), which writes a toast and reassigns the radio.
  **No neighbour barks. No morale changes. Nobody looks.** A man the player has walked
  200m beside falls over and the other seven keep shooting with identical parameters.
- **No shared positions, no buddy pairs, no bounding.** The formation is eight independent
  rolled offsets around the player (`ally_base.gd:367`) — a ring, not a fireteam. Men do
  not pair, do not cover each other's movement, do not follow one another.
- **`has_covering_fire` is declared `false` and never set** (`ally_base.gd:122-127`, with an
  honest comment saying so). The ally scorer therefore never knows a friend is supporting
  him — so `ADVANCE` (`combat_goals.gd:127`) never gets its covering-fire bonus on the
  friendly side. *Allies cannot cooperate because they cannot perceive cooperation.*
- The one genuine relationship in the code is **the radio handoff** (`squad_system.gd:717-753`)
  — the nearest rifleman picks up the fallen RTO's set and becomes the RTO. That is a real
  moment between men and it is the only one.

---

## 6. THE PLAYER'S SQUAD SPECIFICALLY (Pillar 4)

> *"the squad is the RPG — and you are IN it, not above it."*

The architecture honours the pillar: the player suggests (`_order_all`, F1-F4) and the men
hold their own intent. **But the men have no interiority for that intent to come from.**

### The eight-man silence problem

The squad's voice library holds **24 recorded lines per actor** (`assets/audio/vo/john/`).
Called anywhere in the codebase: `movement_ahead`, `man_down`, `weapons_free`,
`weapons_tight`, `thumper_out`, `taking_fire`, `on_your_feet`, `grenade`, `fall_back`,
`doc_moving`, `clear`, plus `contact_front`/`enemy_left`/`enemy_right` from
`_call_contact` (`ally_base.gd:795-811`).

**Never called by anything:** `squad_contact`, `squad_ammo_low`, `squad_fire_in_hole`,
`squad_frag_out`, `squad_moving`, `squad_on_me`, `squad_push_up`, `squad_reloading`,
`squad_reloading_cov`, `squad_sniper`, `squad_treeline`. **Eleven recorded lines, paid for,
sitting silent.** (Wiring is another architect's charge — the *design* point is that even
if all 24 were wired, **every one of them is a combat callout.** There is not a single
ambient, personal, or conversational line in the library.)

Consequence: **the squad is completely silent from boot until the first bullet.** The demo
(`demo_game.gd:26-69`) opens with the player on a bunk, the squad moving out at T+10s, and
then a long stretch of daylight patrol. For the first several minutes of the shipping
product, eight men walk beside the player without making a sound.

`VOManager` also gates hard: `MAX_CONCURRENT_FIELD = 2` and `SPEAKER_COOLDOWN_S = 3.0`
(`vo_manager.gd:24-26`). Correct for anti-chorus; it also means a firefight yields very
few lines. And `SQUAD_DIRS` is **two voices** (`vo_manager.gd:15`) split by name hash —
**four men share one voice.** Sound is one of only four channels that read at PSX
fidelity, and it is running at 2-voice resolution.

### What would make him feel he is IN a squad

1. **Men addressing HIM.** Not one line in the library is directed at the player. No
   acknowledgement of an order, no question, no complaint, no "where we going, Sarge".
   An order given into silence is an order given to a script.
2. **Men addressing EACH OTHER by name.** `SquadRoster.call_name()` (`:255-263`) is built
   and used only in toasts. The men never say each other's names out loud.
3. **Unprompted behaviour.** The only unprompted acts in the squad are the point man's
   scan (`squad_system.gd:489`), the grenadier's cluster shot (`:518`), and the medic's
   crate drop (`:679`) — all three specialist-only, and all three fire on a timer or a
   geometry test, not on a man's judgement. **The five riflemen never do anything the
   player did not cause.**
4. **Opinions.** Nothing in the game has a man disagree, hesitate, or prefer.
5. **Visible fear or steadiness.** `CombatPosture` (`combat_posture.gd`) is shared and
   works — but it is driven by suppression alone (`:35-56`), so all eight men crouch at
   exactly the same threshold at exactly the same time. **A squad that crouches in unison
   reads as one entity, not eight.**

---

## 7. RECOMMENDATIONS — ranked by perceived-aliveness per unit of work

### TIER A — DATA / CONTENT (cheap, large, low risk)

**A1. The per-man behaviour vector.** *(Highest ratio in the document.)*
Roll six numbers per man at generation, store them on the roster dict so they persist and
so the same seed gives the same men (ADR-010), and apply them at `squad_system.gd:85`
alongside the existing courage line:

| Field | Suggested spread | Reads as |
|---|---|---|
| `reaction` | ×0.6–1.6 on `_aim_settle` (`ally_base.gd:790`) | who shoots first, every time |
| `range_bias` | ×0.7–1.4 on `preferred_range` (`ally_base.gd:10`) | squad spacing, silhouette depth |
| `burst_bias` | 3–9 replacing `MAX_BURST` const (`:258`) | sound signature per man |
| `gait` | ×0.9–1.1 on `move_speed` (`:9`) | who lags, who pushes |
| `cover_dwell` | ×0.7–1.5 on peek cadence | timing |
| `talk` | 0–1, gates chatter | who calls things out |

**Cost:** a table plus ~30 lines, no new AI, no new art.
**Sacrificed:** balance determinism — the MG's 1.6 `fire_rate_mult` and the support-fire
lab's pinned courages (`support_fire_range.gd:49-56`) are calibrated against uniform men,
so those benches will need re-pinning. Also a small perf-neutral widening of the spread
band means some men will miss more; that is the point, but it must be tuned against
ADR-016 lethality.

**A2. Fix the rally trap.** `RALLY_BONUS = 0.25` at `RALLY_RADIUS = 6.0`
(`ally_base.gd:106-107`) versus a follow slot rolled at 2.5–4.5m (`:367`) means the bonus
is **permanently on** for a squad in FOLLOW, which deletes the bottom of every courage band
and kills `may_close_distance`'s coward branch outright. Either drop it to ~0.10, or gate
it on the player being *forward* of the man (which is what "lead from the front" actually
means), or scale it by how many men are inside the radius.
**Cost:** one function. **Sacrificed:** the squad will look less bold when the player pushes
— which is the honest outcome.

**A3. Name the dead and keep them.** Store `squad_kia` **names** into a persistent
`fallen: Array` in `CampaignState` (currently `:264-267` reads only `.size()`), and add a
memorial column to the Barracks (`barracks.gd`). Print the roll at the end card.
**Cost:** ~40 lines, one UI list. **Sacrificed:** save size (trivial); some players find a
memorial maudlin.

**A4. Third and fourth squad voice.** `SQUAD_DIRS` is two (`vo_manager.gd:15`). Add a
`voice` key to the roster dict at generation (so a man keeps his voice for his whole
career, exactly as `face`/`helmet` already do at `squad_roster.gd:108-109`) and cast four.
**Cost:** VO recording — the expensive item on this list, but the only one that buys
individuation on the strongest PSX channel. **Sacrificed:** budget and studio time.

**A5. Ambient chatter content.** Record ~15 non-combat lines: moving out, a long march, a
water crossing, nightfall, after a fight, an acknowledgement of an order, one complaint,
one question to the player. Schedule them off `talk` (A1) and situation.
**Cost:** VO + a small scheduler. **Sacrificed:** repetition risk — 15 lines across a
30-minute demo will be heard more than once; that is survivable, silence is not.

**A6. Make a nickname reachable in the demo.** `NICK_MISSIONS = 3` (`squad_roster.gd:75`)
in a one-day product means no player ever sees the christening toast. Either lower it, or
seed the starting roster with one or two men who **already** carry a nick and a mission
count — instant "these men have a past".
**Cost:** two constants. **Sacrificed:** the earned-ness of the nick, slightly. Worth it.

---

### TIER B — BEHAVIOUR (moderate, high payoff)

**B1. Ally down-not-dead, and squad aid.** *(The strongest single behaviour on this list,
and largely a PORT rather than a build.)* `EnemyBase` already holds the complete machine:
`_become_downed` (`:2699`), `downed_pool` (`:2616`), `_medic_think` (`:2626`), `_execute_aid`
with the drag (`:2656`), and the `carry_wounded` / `being_carried` clips are already
authored and playing. Mirror it onto `AllyBase` at the `_die()` gate (`ally_base.gd:1846`),
and widen the squad medic from player-only (`squad_system.gd:122-125`) to any downed man.
`campaign_state.gd:268-274` explicitly asks for this and names its own removal.
**What it buys:** a man screams instead of vanishing; Doc breaks off and runs to him; two
men drag him out. That is three separate "these are people" reads from one port.
**Cost:** the port plus a real WIA path through the AAR. **Sacrificed:** the demo's
lethality softens — a downed ally is a saved ally, and the casualty ledger will read
lighter unless the bleed clock is tight. Also risks Doc being pulled off the player at the
worst moment; that is drama, but it must be tuned.

**B2. A nerve that moves.** Replace the static `courage` in `effective_courage()` with a
`nerve_current` that starts at the rolled value and drifts:
- **down** when a squadmate falls within ~15m, under sustained suppression, when badly
  outnumbered, as `_contact_time` runs long;
- **up** on his own kill, when the enemy breaks, when the player is genuinely leading,
  on a lull.
Feed *that* to `CombatGoals.Context.aggression`/`self_preservation` (`ally_base.gd:920-921`).
**What it buys:** §4 in one stroke — the man who started bold is cautious ten minutes in,
and the squad's whole posture curves over a long fight.
**Cost:** ~40 lines and real tuning. **Sacrificed:** predictability. A squad that degrades
can spiral; needs a floor and a recovery rate, or a bad contact becomes unwinnable and
Pillar 5 (fail forward) is breached.

**B3. Ally death witness.** Mirror `_witness_check` (`enemy_base.gd:1064`) on the friendly
side: on `died`, the nearest living man calls the fallen man's name out loud
(`SquadRoster.call_name` already exists at `:255`), everyone within radius takes a nerve
hit (B2), and suppression jumps.
**What it buys:** a specific loss instead of a headcount. Reads on sound — the strongest
PSX channel — and costs almost nothing on top of B2.
**Cost:** ~20 lines + one VO line per voice. **Sacrificed:** VO budget; risk of the line
colliding with the death cry (`vo_manager.gd` gating handles it).

**B4. Refusal and hesitation.** `set_order` (`ally_base.gd:245`) obeys instantly and
unconditionally. Gate it: a man below a nerve floor takes 1–3s before complying, or
refuses to leave hard cover under unanswered fire — **and says so.**
**What it buys:** the clearest possible signal that a man has self-interest.
**Cost:** small. **Sacrificed:** player agency, deliberately — and this is the one item on
the list that reads as a **bug** if the bark is missing or the delay is unbounded. Ship it
only with the line, and only with a hard ceiling on the delay.

**B5. Buddy pairs.** Pair the eight men into four teams at spawn (`squad_system.gd:67`).
A pair shares a rough position, moves alternately, and each man reacts specifically to his
buddy going down. This is also the cheapest honest way to finally set `has_covering_fire`
(`ally_base.gd:122-127`) — my buddy is firing, therefore I may move.
**What it buys:** the ring formation becomes a fireteam; ADVANCE finally gets its covering-
fire bonus on the friendly side (`combat_goals.gd:127`).
**Cost:** moderate — pairing plus alternating-movement logic. **Sacrificed:** formation
tidiness and some nav churn; a pair that gets separated needs a rejoin rule or it looks broken.

---

### TIER C — PRESENTATION THAT SURVIVES PSX

**C1. Break posture unison.** `CombatPosture.decide` (`combat_posture.gd:35-56`) uses shared
thresholds, so eight men crouch on the same frame. Add a small per-man offset to
`CROUCH_SUPPRESS` / `PRONE_SUPPRESS_ENTER` from the A1 vector.
**Cost:** two lines. **Sacrificed:** the clean doctrinal contract of the 2026-07-23 faction
merge — the offsets must be small enough not to reopen it.

**C2. Idle posture and clip variety when halted.** One `_idle_drift` (`ally_base.gd:1221-1233`)
across the whole squad. Vary the halted clip and dwell by roster index — one man kneels,
one watches the rear, one lights up.
**Cost:** clip selection only, using clips that likely already exist in the library.
**Sacrificed:** nothing meaningful.

**C3. Extend the nameplate, carefully.** 5.0m / 12° (`squad_nameplate.gd:10-12`) is too
tight for the player to ever learn a name. Widen the look range to ~15m, or add a faint
chevron at squad distance with the call name only.
**Cost:** trivial. **Sacrificed:** Pillar 4 pressure — anything approaching a god-view of
your men violates *"you are IN it, not above it."* Keep it look-gated and keep it faint;
this is the one presentation item that can go wrong on principle rather than on execution.

---

## 8. NOTED FOR THE ARBITER (not my charge, flagged in passing)

`squad_system.gd:233,240` call `_order_all(mode, pos, toast, vo_id)` with **four**
arguments against a **three**-parameter signature at `:255`. This belongs to the wiring
architect, but it sits on the F1/F3 order path, which is the most-used input in the game.

---

## 9. THE VERDICT IN ONE LINE

RECONgame's men are not fodder because the AI is bad — the shared goal scorer
(`combat_goals.gd`) is genuinely modern. They are fodder because **eight men share one
body, one temperament, one silence and one memory**, and because the fight does not change
any of them. Give each man a number vector, a voice, a wound, and a name that survives him.
