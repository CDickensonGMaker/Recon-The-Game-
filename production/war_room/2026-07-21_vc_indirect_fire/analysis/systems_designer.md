# SYSTEMS DESIGNER — VC INDIRECT FIRE + THE CLAIM LEDGER
**2026-07-21 · War Room `2026-07-21_vc_indirect_fire` · lens: economy and system contract**

Every number below is grounded in a `file:line` I opened this session. Where I could not ground a
number I say so.

---

## 0. FINDINGS FIRST — pointers in the briefing that the code does not support

Per the briefing's own instruction ("if one is wrong, that is a finding and it goes at the top").

### F1 — **A5 IS FALSE AS WRITTEN. There is no incoming-fire wedge.**
`scripts/ui/mission_hud.gd:196` is `show_damage_direction(rel_angle)` — a red pip that fires **after
you take a hit**. Its only caller is `scripts/player/player.gd:1177-1178`, inside the damage path.
It has never been a warning; it is a *post-mortem*. A5 ("reuse the existing incoming-fire wedge") is
proposing to reuse a function that by construction cannot fire before the round lands.

**This does not kill A5, it corrects it.** The honest version keeps A5's discipline (no second
indicator) and costs one call site: fire `show_damage_direction` from the **spot round's terminal**,
with the bearing **to the tube**, not to the impact. The player is told, in the vocabulary the game
already speaks, *"that came from over there."* That single pip is simultaneously the warning, the
fairness receipt, and the treasure map to the tube. It is the cheapest good thing in this whole
design.

### F2 — **`AmbientWar` is already crying wolf, and it will break the fairness contract.**
`scripts/ai/ambient_war.gd:11` — `KINDS` contains `"mortar"`. `:32-36` rolls 1–3 events **per sim
hour** at 200–800 m from the player on a random bearing; `:52-53` plays `explosion.wav` from a
positioned 3D source. A sim hour is **60 real seconds** (`scripts/autoload/sim_clock.gd:18`,
`real_to_sim_ratio = 60.0`).

So the player currently hears a positional "mortar" thump from 200–800 m **one to three times a
minute, forever**. The moment a mortar report means *"a tube in your AO is ranging on you,"* the
ambience budget is actively lying to the player about the single most important sound in the new
system. **Delete `"mortar"` from `KINDS`.** Keep `"artillery"` — distant rolling artillery is
non-actionable atmosphere (Pillar 2) and reads as a different sound. One-word change; without it the
fairness contract is undermined by decoration.

### F3 — **The night budget is real, and I nearly mis-ruled it.** `MissionWeather.is_night`
(`scripts/world/mission_weather.gd:95`) is set from `_apply_time`, which is driven by
`SimClock.time_period_changed` (`:80-83`). `SimClock.period_at` (`scripts/autoload/sim_clock.gd:60-66`)
puts NIGHT at 19:00–05:00. At `real_to_sim_ratio = 60.0`, **NIGHT is 10 real minutes out of every 24.**
The dawn reset at `field_director.gd:958-959` therefore genuinely fires. "One per night" is
implementable with the existing latch pattern and needs no new clock. Recorded because it is the
budget's denominator and nothing in the repo states it.

### F4 — **`_maybe_launch_sappers` breaks ADR-010 today.** `field_director.gd:967` rolls bare
`randf()`. The sapper night roll is therefore not reproducible from the op seed. Do not copy the
pattern into the barrage roll (see §4). Worth its own small bead against the existing code.

### Pointers I verified as **correct**
`combat_manager.gd:245` (enemies-only) · `weapon_holder.gd:444` (path is `scripts/player/`) ·
`cas_airplane.gd:188` · `field_director.gd:590` `_fire_shell` · `:567` `_run_mortar_mission` ·
`site_planner.gd:664` `stamp_vc_camp` · `enemy_base.gd:2307` · `ally_base.gd:1143` ·
`player.gd:1250` · Fairness Law header at `field_director.gd:862`. The briefing's core claim is
**true**: `apply_suppression_in_area` has exactly two callers and neither is an indirect weapon.

---

## 1. THE RIGHT NUMBERS FOR VC INDIRECT FIRE

### 1.1 What the player's own tube does (measured, this session)

| Quantity | Player 81 mm | Source |
|---|---|---|
| rounds | 1 spot + 3 FFE (4 FFE at `fo ≥ 5`) | `field_director.gd:572, 578-584` |
| spot scatter | ±15.0 m × `sheaf_scale(fo)` | `fire_plan.gd:16`, `:40-41` |
| FFE scatter | ±8.0 m × `sheaf_scale(fo)` | `fire_plan.gd:15` |
| blast | 10.0 m, plateau 4.0 m | `fire_plan.gd:17`, `combat_manager.gd:99` |
| damage | spot 70 max / 40 min; FFE **140 max / 40 min** | `field_director.gd:668` |
| timing | spot impacts t≈4 s; FFE at t≈7, 8, 9 s | `:583` + `SHELL_FLIGHT_S = 4.0` (`:241`) |
| cooldown | `max(10, 25 − 2×fo)` s | `:406` |
| allotment | 3 per walk-out (+1 at `fo ≥ 6`) | `:822` |

Lethality reference: player HP 100, enemy HP 65–85 (`data/enemies/vc_rifleman.tres:10` = 70). The
player's own FFE round does **140 inside 4 m — it kills him outright**, and the `min_damage = 40`
floor means *anyone* within 10 m of *any* round eats ≥ 40. Three rounds inside 10 m is a corpse.

**The one thing this table proves:** the player's mortar is already a coin-flip weapon at close
range. Handing the VC the same numbers would produce exactly the "one-shot from off-screen" the
briefing forbids. The VC tube must be **weaker per round, wider in sheaf, slower in cadence, and
longer in warning.**

### 1.2 The proposed VC tube — a 60 mm, not an 81 mm

Historically the local-force VC unit that garrisons a jungle camp carries the 60 mm (Type 63 /
captured M2); the 82 mm belongs to main-force units. Our camps are local-force garrisons of 6–9 men
(`mission_generator.gd:599`). 60 mm it is — and that choice does the balancing for free.

```gdscript
## fire_plan.gd — VC indirect. The enemy's table lives beside the player's so the
## asymmetry is readable in one screen and cannot drift apart.
const VC_MORTAR_SHEAF_M: float = 12.0      ## 1.5x the player's 8.0 — no FO, no fo_fac scaling
const VC_MORTAR_SPOT_M: float = 22.0       ## 1.47x the player's 15.0 — the ranging round strays
const VC_MORTAR_BLAST_M: float = 8.0       ## 0.8x the player's 10.0 — 60mm, not 81mm
const VC_MORTAR_MAX: int = 95              ## a dead-centre hit leaves a healthy man at 5 HP
const VC_MORTAR_MIN: int = 22              ## vs the player's 40 floor — the EDGE is survivable
const VC_SPOT_INTENSITY: float = 0.35      ## 33 max. THE SPOT ROUND MAY NEVER KILL A HEALTHY MAN.
const VC_MORTAR_ROUNDS: int = 4            ## FFE rounds after the spot
const VC_ROUND_INTERVAL_S: float = 1.6     ## vs the player's 1.0 — two men hand-dropping
const VC_SPOT_TO_FFE_S: float = 12.0       ## THE FAIRNESS BUDGET. Never tune below 8.0.
const VC_MISSION_COOLDOWN_S: float = 75.0  ## re-lay, re-observe, and the crew ducks
```

**Why each number, in economy terms:**

- **`MAX 95` is the keystone.** Plateau is `8.0 × 0.4 = 3.2 m` (`combat_manager.gd:99`). A dead-centre
  round leaves a full-HP player alive at 5 HP — **once**. Every subsequent round in that salvo kills.
  This is not mercy, it is a *contract*: the VC mortar can never delete a healthy player in one
  event, and it can always kill a player who does not move. That converts a coin flip into a
  positional test, which is what an indirect weapon is supposed to be. Against enemy HP: 95 kills a
  70-HP `vc_rifleman` out to ~4.8 m, so **the VC tube kills its own men**, which matters in §2.
- **`MIN 22` versus the player's `40`.** The player's mortar has no survivable edge. The VC's does.
  A man at 8 m takes 22 and knows he was lucky. That single number is the difference between "the
  system is teaching me to move" and "the system is taxing me at random."
- **`SPOT_INTENSITY 0.35` → 33 damage** is a hard, probeable contract: `33 < 100`. Write the probe.
- **4 FFE rounds at 1.6 s** = a 6.4-second salvo. Longer than the player's 3 s and less deadly per
  round: the VC trade precision for duration, which is both historical and the right *feel* — you
  are under it for a while and you can run out from under it.
- **`SPOT_TO_FFE_S = 12.0` is the whole fairness contract in one constant.** Player sprint ≈ 6 m/s →
  72 m of travel, far outside `SHEAF 12 + BLAST 8 = 20 m`. If any future tuning pass touches this
  number, the fairness law is being amended and it needs a decree.

### 1.3 The tube as an object

```gdscript
## mortar_tube.gd
const VC_TUBE_AMMO: int = 16          ## 3 full missions (5 rounds each) + 1 spare
const VC_TUBE_RANGE_MAX: float = 800.0
const VC_TUBE_RANGE_MIN: float = 90.0 ## the dead zone — inside this it cannot engage you
const VC_TUBE_HP: int = 60            ## one M79 round, one LAW, one satchel, or a magazine
const VC_TUBE_CREW: int = 2           ## vc_rifleman; the tube fires only with a living crewman <6m
const VC_CREW_REPLACE_S: float = 90.0 ## the camp garrison sends another man
```

**Range is grounded, not guessed.** Camps are seeded 400–540 m from the wire gate, and the first
camp is capped at ≤ 480 m — *"the close-camp promise"* (`mission_generator.gd:540-541`). Villages sit
240–470 m (`:512`). Map is 1280 m. An 800 m tube at the ≤480 m camp therefore:
- **reaches the FSB** (the barrage behaviour is possible without a new "firing position" entity),
- **covers the near AO** the player actually walks,
- **does not cover the map** — there is real ground out of range, so reading the bearing and walking
  out of it is a genuine, learnable answer. A tube that covered the AO would make the whole feature a
  weather system you cannot argue with.

**`RANGE_MIN 90 m` is the best number in this document.** A mortar cannot shoot what is under it. The
last 90 m of the kill-the-tube loop is a place where the tube is inert and the fight is rifles. The
system teaches its own counter by geometry, with no UI and no tutorial.

**Crew, not tube, is the trigger — but the tube is the kill.** Kill the two crewmen and the tube goes
silent for 90 s while the camp sends another man. Destroy the tube and it is over. One loop teaches
the player that men are replaceable and steel is not, which is the correct lesson about this whole
war and costs one timer to say.

**Tubes per AO: 1 — and 2 at CRITICAL.** `_grant_fire_support` (`field_director.gd:824-828`) already
uses `CampaignState.threat_label()` to release napalm and CBU at HIGH and Spectre at CRITICAL. Making
the enemy's ordnance read the *same* label is the cleanest rule available: the escalation ladder cuts
both ways, it is already the game's language, and the player can predict it. The tube is stamped at
the `ci == 0` camp — deterministic off the op seed (ADR-010), and it is the camp he was always going
to walk to. No new site type, no new pathing, no new content.

---

## 2. THE FAIRNESS CONTRACT FOR THE FIELD WALK-ON

### 2.1 The predicate — ALL must be true at the moment the call goes out

1. **OBSERVED, BY A MAN, WITH HIS EYES.** A living `EnemyBase` with `alert_tier == COMBAT`
   (`enemy_base.gd:74`) **and** `has_line_of_sight == true` **and**
   `target_visible_duration >= 3.0` (`:69-70`). Not "heard." Not ALERT. Not
   `last_known_target_pos`. A man looked at you for three seconds. This is the same witness rule
   ADR-005 already enforces on the beacon (`noise_bus.gd:12-14`: *"Only a man who SEES you goes
   COMBAT"*), so a player who has never been made is **never** shelled — and a player who has been
   made has already been told, by the existing "YOU'VE BEEN MADE" toast (`field_director.gd:76`).
2. **THE OBSERVER SURVIVES TO REPORT.** `VC_OBS_REPORT_S = 10.0` between acquisition and the spot
   round leaving the tube. If the observer dies inside that window, no rounds. **This is the single
   most important clause in the design**: it makes the walk-on a thing the player can *prevent*, and
   it explains itself without a word of UI — kill the man who was looking at you.
3. **STATIC.** The player's position has moved < `VC_STATIC_M = 20.0` over the last
   `VC_STATIC_S = 12.0` s. Re-checked at the FFE call. This is the mechanical sentence of the whole
   feature: *an unranged tube cannot plot a moving patrol.*
4. **TUBE LIVE, LOADED, IN RANGE, OFF COOLDOWN.** Not destroyed, `ammo >= 5`, aim point between
   90 m and 800 m, `mission_cooldown <= 0`, ≥1 living crewman within 6 m.
5. **THEIR OWN FIRE DISCIPLINE.** No living VC within `VC_DANGER_M = 25.0` of the **aim point** at
   call time. (§2.2 covers how this is prevented from becoming a permanent shield.)
6. **ONE MISSION AT A TIME.** The tube is a mutex. The FSB barrage and the field walk-on can never
   be in the air together.

**And the invariant that binds them all, which should be written into the file header the way the
Fairness Law is written into `raise_crisis`:**

> **THE ROUNDS GO WHERE YOU WERE, NEVER WHERE YOU ARE.** The aim point is frozen at the spot round.
> The fire-for-effect is plotted onto the spot's point and is never re-solved onto the live player.

### 2.2 Where it degenerates

| # | Exploit / bad feel | Verdict | Bound |
|---|---|---|---|
| E1 | **The observer shield** — kill everyone who can see you, never get shelled | **Working as intended.** That IS the counter-play | Priced already: shooting costs a 150 m `GUNSHOT` noise (`noise_bus.gd:18`) and a −25 detected contact (ADR-006:40) |
| E2 | **Hug the enemy** — stand inside 25 m of a VC and the tube is muzzled | **Good, historical, keep** | The discipline check runs **once, at call time, against the aim point**. Hugging works only if you are hugging when the call goes out; break contact and the next call plots you. **Plus:** if the player has been static inside a VC's 25 m bubble for > 30 s, the discipline check is **waived** — the local commander accepts the loss. One timer kills the permanent shield and it is dramatically correct |
| E3 | **Bait and drain** — eat missions from safety until the 16 rounds are gone, then walk in | **A plan, not an exploit.** Reward it | Costs ~4 real minutes and every salvo is a real risk |
| E4 | **The wire shield** — if the walk-on excludes ground near the FSB, camp at 95 m from `fsb_center` | **The only genuinely bad one** | Do **not** write a distance exclusion. Predicate 6 (the tube mutex) already prevents double-fire. Standing near the wire then buys you nothing but the garrison's guns |
| U1 | Rounds land while you are in a tunnel or bunker | **Already solved, no new work** | `_can_damage_multipoint` traces 8 points and gives zero with no LOS (`combat_manager.gd:210-241`) |
| U2 | The spot round kills you | **Contractually impossible** | 33 max vs 100 HP. Probe it |
| U3 | No visible warning | **Real, and F1 is why** | Fire `show_damage_direction` from the spot terminal with the **bearing to the tube** |
| U4 | Shelled at 02:00 and you cannot see the bearing | **Atmosphere, not unfairness** | *Provided* the tube's report is a positional 3D source at the tube. NoiseBus + `AudioStreamPlayer3D` give this for free — see F2, and delete the ambient decoy |

### 2.3 The unfairness I could not design away, and name honestly

A player lying concealed in a treeline glassing a village for two minutes is doing **the most
core recon activity in the game**, and predicate 3 punishes staying put. The mitigation is
predicate 1 — a concealed observer is not eyes-on, so the tax only applies *after you have been
made*, which is the escalation economy that already exists. But it is a real narrowing: once you are
made, the game stops rewarding patience. **That is the cost of this feature and it should be
stated in the ADR, not discovered in a playtest.**

---

## 3. SUPPRESSION NUMBERS

### 3.1 How suppression is actually CONSUMED (read before picking any number)

| Consumer | Decay | Thresholds and effects |
|---|---|---|
| **Enemy** (`enemy_base.gd`) | 0.3 /s (`:214`) | `> 0.5` → +0.3 cover score (`:1156`) · `> 0.7` + ENGAGE goal → **SUPPRESSED state: velocity zeroed, stops firing entirely** (`:1274`, `:1492-1498`) · `> 0.8` → cannot fire (`:1468`) · move mult 1.0→0.4 across 0→0.5, 0.4→0.05 across 0.5→0.85, **0.0 above 0.85** (`:1731-1740`) |
| **Ally** (`ally_base.gd`) | 0.4 /s (`:212`) | `> 0.35` while SEEKING_COVER (else `> 0.6`) and no cover → pinned (`:625-626`) · `≥ 0.5` → **will not fire** (`:829`) · `≥ 0.6` → low posture (`:368`, `:234`) |
| **Player** (`player.gd`) | 0.55 /s standing, **1.3 /s prone/crouched** (`:123-124`) | Shader overlay · camera h/v offset ≤ 0.06 m · lowpass to 650 Hz (`:1267-1294`). **No aim penalty. No movement penalty.** |

**This table is the design's centre of gravity and it should decide the numbers, not intuition:**

- **Suppression on the player is FREE.** It costs sensation, never capability. A big number on the
  player is not unfair — it is atmosphere, and it is exactly Pillar 2. The prone/crouch decay of
  **1.3/s vs 0.55/s** even makes it a taught behaviour: get down and the world comes back.
- **Suppression on an ENEMY at 0.7+ ends the fight.** That is a number you hand out deliberately.
- **Suppression on an ALLY at 0.5+ stops your squad from shooting back.** This is the dangerous
  one and §3.3 is about it.
- **Decay maths.** At 0.3/s enemy decay, a single 0.9 hit pins for `(0.9−0.7)/0.3 = 0.67 s` of
  freeze and `(0.9−0.5)/0.3 = 1.3 s` of cover-seeking. **One round does not suppress.** Sustained
  suppression requires impacts every ~1.0–1.6 s — which is exactly `VC_ROUND_INTERVAL_S = 1.6` and
  the player's 1.0 s cadence. The numbers already agree with each other; that is a good sign.

### 3.2 The `SUPPRESS_M` table

The only shipped calibration is `BOMB_SUPPRESS_M = 40.0` at amount `1.0` against
`BOMB_BLAST_M = 16.0` (`fire_plan.gd:22-23`, `cas_airplane.gd:188`) — a **2.5× ratio at full
amount**. Anchor everything to it, and express it as a rule rather than five hand-typed floats so it
cannot drift:

```gdscript
## The pin ring is 2.5x the kill ring, everywhere. One rule, so no weapon can drift
## away from the drawn footprint (which is this file's whole reason to exist).
static func suppress_radius(kind: String) -> float:
static func suppress_amount(kind: String) -> float:
```

| kind | BLAST_M | **SUPPRESS_M** | **amount** | why |
|---|---|---|---|---|
| `mortar` (81 mm) | 10.0 | **25.0** | **0.9** | at 6 m → 0.68 (enemy seeks cover, near frozen); at 12.5 m → 0.45 (worried, not pinned). Freezes what it nearly hits |
| `arty` (105 mm) | 14.0 | **35.0** | **1.0** | 6 rounds at 0.7 s (`field_director.gd:427`) **stack** to the 1.0 cap — a battery flattens a position for its whole duration. That is what an arty slot buys |
| `bombs` | 16.0 | **40.0** | **1.0** | **SHIPPED — do not touch.** This is the calibration anchor |
| `napalm` (per drop) | 10.0 | **22.0** | **0.8** | ×5 drops down the strip. Napalm's killing is the burn; the suppression does the psychological work |
| `cbu` (per bomblet) | 5.0 | **9.0** | **0.35** | ×16 bomblets over a 22 m ellipse: individually trivial, collectively total. The correct emergent shape for a cluster weapon, needing no special case |
| `spectre` (beaten zone) | 25.0 beaten | **30.0** | **0.6** /burst | continuous for 30 s → permanent pin under the beaten zone, releasing the instant the gun walks off |
| `vc_mortar` FFE | 8.0 | **20.0** | **0.85** | see §3.3 |
| `vc_mortar` spot | 8.0 | **20.0** | **0.45** | the ranging round rattles; it does not pin |

### 3.3 A1's real cost, which the briefing does not name

Making `apply_suppression_in_area` faction-blind means **the player's own mortar now suppresses the
player's own squad.** 0.9 at centre, 25 m radius, against a `DANGER_CLOSE_M` of 45.0
(`field_director.gd:248`). Today a danger-close call costs your men 0.4× damage
(`combat_manager.gd:149-150`); after A1 it also costs them **their trigger fingers** — allies stop
firing at `≥ 0.5` (`ally_base.gd:829`), which is everything inside ~12.5 m.

I **endorse** it — a called mortar your own men lie under and keep shooting through is a lie, and
Pillar 1 says weapons kill like weapons. But the honest form mirrors the precedent that is already
law two lines away:

> **Friendly indirect applies 0.6× suppression to friendlies**, exactly as `attacker == null` already
> applies 0.4× damage to them (`combat_manager.gd:146-150`). Same seam, same philosophy, one line.

And it means the VC barrage's real cost against a patrol is not the damage — it is that **your squad
stops shooting for ~2 s per round.** A 4-round salvo mutes your fireteam for most of 7 seconds while
riflemen close. That is the most frightening thing in this proposal and it is the reason A1 matters
more than the tube does.

**Perf:** faction-blind triples the iteration (enemies + allies + player). Worst case is CBU: 16
impacts × ~40 agents = 640 distance checks inside one second. Negligible. No objection.
`AgentRegistry.props` (`agent_registry.gd:13`) must **not** be walked — a trap has no morale, and the
existing `has_method("apply_suppression")` guard (`combat_manager.gd:255`) already handles civilians.

---

## 4. THE FSB BARRAGE BUDGET

```gdscript
const VC_BARRAGE_CHANCE: Dictionary = {"LOW": 0.0, "MODERATE": 0.25, "HIGH": 0.5, "CRITICAL": 0.75}
const VC_PREP_TO_ASSAULT_S: float = 45.0
var _barrage_rolled_night: bool = false   ## mirrors _sapper_rolled_night (:730), reset at dawn
```

Compare `SAPPER_CHANCE = {0.0, 0.2, 0.45, 0.7}` (`field_director.gd:714`). The barrage sits slightly
above it because the barrage is the **cheap recurring harassment** and the sapper assault is the
**once-per-operation set piece**. `LOW = 0.0` is load-bearing and deliberately identical: **a player
who kept the AO cold is never shelled.** Stealth is an economy (Pillar 3), and this is a place where
the economy pays in the enemy's silence rather than in points.

**Cadence: one roll per night, reset at dawn** — the exact `_sapper_rolled_night` pattern at
`:958-965`. Per F3 a night is 10 real minutes out of every 24, so the natural rate is **one barrage
per ~24 minutes of play.** No new clock, no new constant.

### The elegant part: the barrage and the walk-on share ONE budget

**Do not give the barrage a per-operation cap.** `VC_TUBE_AMMO = 16` already caps it: 5 rounds per
mission ⇒ **3 missions, ever**, unless the AO resupplies the tube. And they come from the same
magazine — **shelling the firebase costs the tube the rounds it would have spent on your patrol.**
One number, two behaviours, and it is a trade the player can feel without being told.

### Interaction with the existing sapper machinery

- **`_sapper_launched` (one per operation, `:730`) is untouched.** If the sapper roll succeeds on the
  same night, the barrage becomes its **prep fire**: the barrage lands, then `launch_sapper_assault`
  is deferred `VC_PREP_TO_ASSAULT_S = 45.0`. One legible event — *"they shelled us and then they
  came"* — instead of two coin flips inside the same 10 minutes. Cost: one timer.
- **If `_sapper_launched` is already true, the barrage still rolls.** This is precisely what stops the
  back half of a long operation from going toothless once the set piece is spent.
- **`BREACH_MORTAR_LOSS` (3) and `BREACH_ARTY_LOSS` (1) are NOT touched by the barrage**
  (`:725-726`, `:943-951`). One depot, one breach, one ledger. A barrage that also docked
  `CampaignState.depot_loss` would charge the player twice for two unrelated events and turn
  `_grant_fire_support`'s arithmetic (`:832-838`) into something no player can predict. **The
  barrage's cost is men, structures and sleep — never the allotment ledger.**
- **`spare_garrison = true` on every barrage explosion**, per the same Pillar-5 decree the satchel
  already honours (`combat_manager.gd:164-167`): men who cannot react are not deleted by a scripted
  event. The **player** is fair game — he can wake and move, and that *is* the moment.
- **Determinism (ADR-010):** seed the barrage roll from `op_seed ^ sim_day`, so a given night in a
  given operation is the same night after a reload. Explicitly **do not** copy `randf()` from
  `:967` (see F4).

---

## 5. DOES "KILL THE TUBE" PAY OUT UNDER ADR-006?

**No. It must not pay score — and that is the correct answer, not a compromise.**

ADR-006:44 is unambiguous: *"Kills pay zero score."* A destruction bounty for the tube is
`kills × 10` wearing a hat, and it would re-open the exact wound audit #2 called the headline wound
(ADR-006:20-26: the XP economy *"literally trains loud play"*). Under ADR-006 the tube pays in the
two currencies that remain open:

**CONSEQUENCE (the real payment).** The AO goes quiet. `VC_BARRAGE_CHANCE` reads a *live* tube, so a
dead tube means no barrage roll and no walk-on. **The reward for the work is that the thing stops
happening to you.** It is legible without a number, it needs no UI, and it is exactly what ADR-029's
open patrol simulator wants — no objective counter, just a world that changed because you were in it.

**INTEL (the tangible payment).** The crew's plotting board is a loot interaction on the channel that
already exists: `CampaignState.intel_points += 2` with a one-shot `looted` flag, priced identically
to the tunnel cache (`player.gd:560-567`). Intel is spent 1 per walk-out on S2's read
(`field_director.gd:792-796`), so 2 points = two patrols of knowing what is out there. The tunnel
cache is the right peer for "you found the enemy's paperwork."

### Is it a farm? Bound it and no.

- **1 tube per AO** (2 at CRITICAL). Not respawned within the operation by default.
- **Exactly ONE replacement tube per operation**, and only if `threat_label()` is HIGH or CRITICAL at
  the moment the first dies. **A cold AO does not receive a new tube.** Ceiling: 2 loots (3 at
  CRITICAL) per operation.
- The replacement stamps at a **different** camp (`ci == 1`), so it is not a respawn camper's stand.
- **And the anti-farm is structural, which is the good kind.** Farming tubes requires holding the AO
  at HIGH/CRITICAL. That tier costs you −25 per detected contact under ADR-006:40 *and* buys the VC
  the second tube. **The farm taxes itself in the same currency it pays out.** No special-case
  cooldown, no anti-exploit hack — the existing economy does the work.

---

## 6. RULING ON THE GATE QUESTION

**The work is three different things and lumping them is exactly how a gate gets laundered. Split it.**

### 6.1 `kfoz` (suppression starvation) — **DEFECT FIX. EXEMPT. No gate link. Ship now.**
`apply_suppression_in_area` walks one faction (`combat_manager.gd:246`) and is reached by 2 of the
game's 9 weapons. `ally_base.apply_suppression` (`:1143`) and `player.add_suppression` (`:1250`) are
**built, live, and unreachable from any area call**. That is not a missing feature — it is a wired
system with two dead terminals, the exact profile ADR-023 classes as **UNFINISHED** and the exact
profile ADR-015:18 exempts ("bug fixes"). Also note it is the highest-leverage item here: it
improves every existing weapon before a single line of VC code exists.

### 6.2 `8xo3` (VC indirect fire) — **NEW FEATURE EPIC. GATE IT. `bd dep add 8xo3 97u3`.**
Nothing is broken; this adds an entity class, an AI behaviour, a stamped site element, a new enemy
data resource and an ordnance path. The tempting exemption is the third one — *"items explicitly
ordered by a standing decree"* — and the Summoner did order the shape this session.

**Here is the distinction that decides it: a decree exemption is for a bounded item a decree named.
It is not a laundering channel for an epic.** ADR-015 exists because a markdown law had a measured
half-life of two hours and 27 commits landed straight through it (ADR-015:5, :36). If "the Summoner
mentioned it this session" clears the gate, then the gate clears **every** session — and `97u3`
becomes what `k77e` already was for ~95 commits: *a gate that blocked nothing* (CLAUDE.md, THE
FOSSIL LAW). The gate's cost **is** its purpose (ADR-015:31), and a gate that yields to enthusiasm is
the fossil this project keeps rediscovering.

**The decree is not ignored — it is banked.** The design lands NOW: this council, the ADR, the
constants table above, the doc sweep. The code lands the moment the Summoner walks the loop and
discharges `qrg6`. R4 is a *playtest*, not a build — he can clear it tonight, and per the standing
practice the honest move is to put that in front of him as a question rather than to route around it.

### 6.3 The doc sweep (`GAME_GUIDE.md:184`, `:138`) — **EXEMPT. Do it FIRST, as ruled.**
Canon asserting an enemy capability the code does not have is a **TRUTH LAW** violation
(ADR-015:23-25) and a textbook DRIFT GENERATOR under CLAUDE.md's no-more-drift rule. It is the one
piece of this work that is strictly better done *before* the gate lifts than after — a doc that lies
about the feature will mislead whoever builds the feature.

**That split is also the correct build order, which is how you know it is not a dodge:** fix the doc,
fix the defect, and the feature is then a small delta on a system that already suppresses everyone.

### 6.4 One fossil-law addition the briefing missed
A2 (extract `IndirectFire`, delete the originals) is correct and I concur. But **exactly one
indirect-fire path** also requires deleting `"mortar"` from `AmbientWar.KINDS`
(`scripts/ai/ambient_war.gd:11`) — see **F2**. It is not a code fossil, it is a **signal** fossil: a
decoration that speaks the same word as the new system's most important warning. One word, and
without it the fairness contract is undermined by the ambience budget.

---

## 7. THE CONSTANTS TABLE (consolidated)

### `fire_plan.gd` — additions
| Constant | Value | Grounded in |
|---|---|---|
| `VC_MORTAR_SHEAF_M` | 12.0 | 1.5× `MORTAR_SHEAF_M` 8.0 — no `fo_fac` |
| `VC_MORTAR_SPOT_M` | 22.0 | 1.47× `MORTAR_SPOT_M` 15.0 |
| `VC_MORTAR_BLAST_M` | 8.0 | 0.8× `MORTAR_BLAST_M` 10.0 (60 mm vs 81 mm) |
| `VC_MORTAR_MAX` / `MIN` | 95 / 22 | player HP 100 · plateau 3.2 m · enemy HP 65–85 |
| `VC_SPOT_INTENSITY` | 0.35 | 33 damage — cannot kill a healthy man |
| `MORTAR_SUPPRESS_M` | 25.0 | 2.5 × `MORTAR_BLAST_M` (bomb anchor) |
| `ARTY_SUPPRESS_M` | 35.0 | 2.5 × `ARTY_BLAST_M` |
| `NAPALM_SUPPRESS_M` | 22.0 | 2.2 × `NAPALM_BLAST_M` (per drop, ×5) |
| `CBU_SUPPRESS_M` | 9.0 | 1.8 × bomblet blast (per bomblet, ×16) |
| `SPECTRE_SUPPRESS_M` | 30.0 | beaten zone + margin |
| `VC_MORTAR_SUPPRESS_M` | 20.0 | 2.5 × `VC_MORTAR_BLAST_M` |
| `FRIENDLY_SUPPRESS_MULT` | 0.6 | mirrors the 0.4× friendly damage rule |

Amounts: mortar 0.9 · arty 1.0 · bombs 1.0 (shipped) · napalm 0.8 · cbu 0.35 · spectre 0.6 ·
vc FFE 0.85 · vc spot 0.45.

### `indirect_fire.gd` / `mortar_tube.gd`
| Constant | Value |
|---|---|
| `VC_MORTAR_ROUNDS` | 4 FFE (+1 spot) |
| `VC_ROUND_INTERVAL_S` | 1.6 |
| `VC_SPOT_TO_FFE_S` | **12.0 — never below 8.0** |
| `VC_MISSION_COOLDOWN_S` | 75.0 |
| `VC_TUBE_AMMO` | 16 |
| `VC_TUBE_RANGE_MIN` / `MAX` | 90.0 / 800.0 |
| `VC_TUBE_HP` | 60 |
| `VC_TUBE_CREW` | 2 · `VC_CREW_REPLACE_S` 90.0 |
| `VC_OBS_REPORT_S` | 10.0 |
| `VC_STATIC_M` / `VC_STATIC_S` | 20.0 / 12.0 |
| `VC_DANGER_M` | 25.0 (waived after 30 s of player camping) |
| `VC_BARRAGE_CHANCE` | LOW 0.0 · MOD 0.25 · HIGH 0.5 · CRIT 0.75 |
| `VC_PREP_TO_ASSAULT_S` | 45.0 |
| tubes per AO | 1 (2 at CRITICAL) · 1 replacement per op, HIGH+ only |
| tube loot | `intel_points += 2` (tunnel-cache parity) |

---

## 8. PROBES REQUIRED (ADR-015 — nothing here closes on a reading)

1. `test_vc_spot_nonlethal` — spot round dead-centre on a 100 HP player leaves him alive. **Asserts
   `VC_SPOT_INTENSITY × VC_MORTAR_MAX < 100`.**
2. `test_vc_fairness_window` — from acquisition to first FFE impact is ≥ `VC_OBS_REPORT_S +
   VC_SPOT_TO_FFE_S`; kill the observer inside the window and **zero rounds fly**.
3. `test_vc_rounds_dont_track` — player sprints 60 m after the spot round; FFE impacts all land
   within `VC_MORTAR_SHEAF_M` of the **spot's** point, none within 20 m of the player.
4. `test_suppression_faction_blind` — one `apply_suppression_in_area` call raises
   `suppression_level` on an enemy **and** an ally **and** the player, with the ally taking
   `FRIENDLY_SUPPRESS_MULT` when `attacker == null`.
5. `test_tube_budget` — 16 rounds ⇒ exactly 3 missions; the 4th call is refused; a destroyed tube
   makes `VC_BARRAGE_CHANCE` unreachable.
6. `test_tube_deadzone` — a player at 80 m from the tube is never engaged; at 100 m he is.
7. `test_barrage_does_not_touch_depot` — after a barrage, `CampaignState.depot_loss` is unchanged.
8. Fossil probe delta: `"mortar"` absent from `AmbientWar.KINDS`; `_fire_shell` and
   `_run_mortar_mission` absent from `field_director.gd`.

---

## 9. WHAT IS SACRIFICED (no free lunches)

1. **The best verb in the game gets worse.** A1 means a called danger-close mortar now mutes your own
   squad (`ally_base.gd:829`, ≥0.5). The 0.6× friendly multiplier softens it; it does not remove it.
   That is deliberate, and it will be felt on the first playtest.
2. **Patience stops paying once you are made.** Predicate 3 (static > 12 s) taxes the treeline-
   observation play that is the most authentic recon activity in the game. Predicate 1 confines the
   tax to players who have already been detected — a narrowing, not an elimination.
3. **The escalation ladder now bites.** Threat-gated tubes mean a loud player is punished twice:
   once by ADR-006's score and once by incoming steel. Fail-forward (Pillar 5) survives only because
   `MAX 95` guarantees a healthy man survives the first round.
4. **Feature velocity, on purpose.** Gating `8xo3` behind `97u3` means the tube does not ship this
   session. That cost is ADR-015's *purpose*, not its side effect — but it is a real cost and the
   Summoner should be asked to discharge R4 rather than have the gate quietly routed around.
5. **An atmosphere asset dies.** Deleting `"mortar"` from `AmbientWar` costs a third of the ambient
   war's vocabulary (`KINDS` goes 5 → 4). Pillar 2 pays so Pillar 1 can have an unambiguous warning.
6. **The AO gets one more thing to remember.** Tube state, ammo, crew, cooldown and replacement all
   have to survive save/load or the barrage will resurrect a tube the player already killed — a new
   persistence surface, and persistence surfaces are where this project's fossils breed.
