# GAME DESIGNER — Sapper charges at the wire

**Session:** 2026-07-20 · **Lens:** FUN and PACING · **Read the code, not the plan.**

All claims below carry `file:line` per the POINTER LAW. Everything cited was read this session.

---

## 0. What the code actually is (verified, not assumed)

| Claim | Pointer | Status |
|---|---|---|
| `SapperCharge` is a 37-line `Node` with `setup(objective_center, director)`; it hijacks `enemy.last_known_target_pos` every physics frame and detonates inside 9m | `scripts/enemies/sapper_charge.gd:6,13,24,29` | VERIFIED |
| Detonation = `apply_explosion_damage(pos, 180, 60, 10.0)` + `MEDIUM_EXPLOSION` terrain deform + heavy explosion FX + `NoiseBus` EXPLOSION + the sapper suicides (`take_damage(9999)`) | `sapper_charge.gd:31-35` | VERIFIED |
| It emits its OWN toast directly (`director.toast.emit`), bypassing the RTO net gate | `sapper_charge.gd:28` vs `field_director.gd:612` | **VERIFIED — this is a Fairness Law problem, see §7** |
| `vc_sapper.tres` is 1 of 9 entries in the uniform-sampled `ENEMY_DATA` pool → ~11% of every spawned man is already a "sapper" | `mission_generator.gd:24-37,857` | VERIFIED |
| Firebase garrison = 17 `Civilian`s, `is_garrison = true`, and `_on_noise` returns immediately for them — they do not flee, do not cower, do not shoot | `mission_generator.gd:744-772`, `scripts/world/civilian.gd:56,171-172` | VERIFIED |
| `_poll_firebase_threat()` fires at 2+ living enemies within 90m of `fsb_center`, only while `patrol_out` | `field_director.gd:494-495,626-641` | VERIFIED |
| `raise_crisis()` is gated on `_radio_check()` — off the net, no word reaches him | `field_director.gd:605-621` | VERIFIED |
| **SimClock exists and is real.** `Period {DAWN,DAY,DUSK,NIGHT}`, `period_at()` NIGHT = hour ≥19 or <5, `time_period_changed` signal, and a working `schedule_event(day, hour, kind, payload)` already used in production by the convoy | `scripts/autoload/sim_clock.gd:9,60-67,70,11-14`; consumer `mission_generator.gd:348` | **VERIFIED — a day/night system EXISTS and is schedulable** |
| **A sim day is 24 REAL minutes.** `real_to_sim_ratio = 60.0`, `sim_hour += delta * 60 / 3600` → 60 real seconds = 1 sim hour | `sim_clock.gd:18,47` | VERIFIED |
| A PATROL is designed to run 20–30 real minutes | `production/GAME_GUIDE.md:194` | VERIFIED |
| The firebase holds a real, loseable asset: the armorer's bench + weapon rack, persisted via `CampaignState.rack_condition` | `mission_generator.gd:664-669`, `scripts/levels/armorers_bench.gd:16`, `scripts/autoload/campaign_state.gd:37,260-264` | VERIFIED |
| Next patrol's steel is granted at the wire and scales off `CampaignState.threat_label()` | `field_director.gd:567-584` | VERIFIED |
| `add_threat_modifier(delta, missions, reason)` is a live, decaying escalation lever | `campaign_state.gd:84` | VERIFIED |

**The single most important number in this whole analysis:** a full day/night cycle is **24 real minutes**, and a patrol is **20–30 real minutes**. Night is not scarce here — it is roughly 10 minutes of every 24, ~42% of wall-clock. **Anyone proposing "gate it on night" as a rarity control is wrong.** Night-gating is a *flavour and legibility* control, not a frequency control. The frequency control has to come from somewhere else.

---

## 1. HOW OFTEN? — Name the number

### The failure mode, stated plainly
"Every patrol becomes a base defence" is not the only failure. There are three, and they sit on a knife edge:

- **Failure A — the treadmill.** Sapper hits every walk-out. The open patrol stops being "leave the camp and go find problems" (ADR-029:16) and becomes "leave the camp, get yanked home." This is what the previous agent's two-crisis cap was defending against, and it was right.
- **Failure B — the ghost.** Gate it so hard it fires once in twenty hours of play. We shipped a behaviour nobody sees, which is how `sapper_charge.gd` got orphaned in the first place. A feature that never fires is a fossil with a heartbeat.
- **Failure C — the shrug.** It fires at a decent rate but ignoring it costs nothing legible, so the player learns in two patrols to never turn around. Worse than A or B, because it burns the *idea* — the second time you offer him a firebase crisis he already knows it's noise.

### THE NUMBER

> **At most ONE sapper attempt per sim-night, probability-gated on the AO threat tier, never before the player's THIRD walk-out, and never two nights running.**
>
> | `CampaignState.threat_label()` | P(sapper attempt that night) |
> |---|---|
> | LOW | **0.00** |
> | MODERATE | **0.20** |
> | HIGH | **0.45** |
> | CRITICAL | **0.70** |
>
> Scheduled through `SimClock.schedule_event(day, hour≈randi_range(1,4), &"sapper_probe", …)` — the mechanism the convoy already uses (`mission_generator.gd:348`), rolled once per `day_advanced` (`sim_clock.gd:12`).

### Defence of the number

**Why per-NIGHT and not per-patrol.** Per-patrol frequency is the treadmill by construction: it ties the event to the player's action rather than to the world's clock, which is exactly the rails shape ADR-029 forbids. Per-night ties it to the world. A player who does one long 30-minute patrol crosses ~1.25 nights and gets ~1 roll; a player who does three short 10-minute walk-outs crosses the same ground and gets the same ~1 roll. **The world's tempo, not the player's, sets the rate.** That is the ADR-029 north star in scheduling form.

**Why threat-gated and not flat.** `_grant_fire_support()` already reads `threat_label()` and hands the loud player napalm and Spooky (`field_director.gd:576-580`). The AO already answers noise with escalation on one axis. The sapper is the *other side of the same coin*: burn villages and battalion gives you steel, **and the VC come for your ammo dump.** That symmetry is worth more than any tuning value in this document — it means one number the player is already implicitly managing controls both his reward and his exposure. Pillar 5 (fail forward: "detection escalates, failure mutates") is literally this.

**Why LOW = 0.00 and not 0.05.** Sub-10% probabilities on a rare-ish event are indistinguishable from bugs. A player who has never gone loud must be able to say truthfully "this has never happened to me," and a player at CRITICAL must be able to say "it happens most nights." If both are 8%, the system communicates nothing and reads as random cruelty — which is precisely the "sadism simulator" Pillar 5 disclaims (`bible/BIBLE.md:91`).

**Why not before the third walk-out.** You cannot break a loop the player has not learned. Patrols 1–2 teach the wire gate, the bearing bark, the AAR. Introducing "the place you come home to can be attacked" before he trusts that the place *is* home destroys the meaning of the event. Cheap to implement: `patrol_count >= 3` (`field_director.gd:514`).

**Why never two nights running.** Three loud rescues in a row is a pacing failure — the previous agent's finding, and I concur and extend it. A one-night cooldown, plus the CRITICAL 0.70 cap, bounds the worst case at ~1 sapper attempt per 2 nights ≈ per ~48 real minutes ≈ per ~2 patrols, and only for a player who has earned CRITICAL. That is the *ceiling*, and it is survivable. The expected case for a normal player sitting at MODERATE is one sapper attempt roughly every 5 nights — memorable, not routine.

**Expected-rate sanity check.** Quiet player (LOW/MODERATE): sees his first sapper somewhere in hours 2–4 of play. Loud player (HIGH/CRITICAL): sees one every other night. **Both of those are correct outcomes.**

### The existing crisis cap
The previous agent's two-`firebase_attack`-per-operation cap should stay, as a **hard backstop on the CRISIS TOAST**, not on the sapper spawn. They are different objects: the sapper is a world event; the toast is a communication. Rate-limit the communication harder than the event. See §7.

---

## 2. TIME OF DAY — yes, and the system exists

**Answer: YES, gate it on NIGHT, and the system is `scripts/autoload/sim_clock.gd`.**

- Periods: `sim_clock.gd:9` (`enum Period { DAWN, DAY, DUSK, NIGHT }`)
- The classifier: `sim_clock.gd:60-67` — NIGHT is `hour >= 19.0 or hour < 5.0`
- The signal to hook: `sim_clock.gd:13` `time_period_changed(period: int)`, and `sim_clock.gd:12` `day_advanced(sim_day: int)` for the once-per-night roll
- The scheduler to use: `sim_clock.gd:70` `schedule_event(day, hour, kind, payload)` → fires `sim_event` at `sim_clock.gd:99`. **Already load-bearing in production** at `mission_generator.gd:348` (the convoy). This is not new machinery; it is machinery with one consumer that deserves a second.
- Weather/light already track period: `scripts/world/mission_weather.gd:53,80`

**The historical case is real** — đặc công sapper doctrine was overwhelmingly a night discipline, and the project's own reference material describes them stripped near-naked precisely for night infiltration (`assets/reference/references/reference_vc_nva.md:100-125`). Pillar 2 (Atmosphere) is paid directly: a satchel going off in the dark, at a firebase you can see burning from 400m out in the jungle, is the single most Vietnam-film image this feature can produce.

**But be honest about what night-gating buys.** Because a day is 24 real minutes (`sim_clock.gd:18,47`), night is ~42% of playtime. Night-gating cuts the eligible window by a bit over half. **It is a flavour gate and a legibility gate, not a rarity gate.** Anyone who tunes the probability assuming "night is rare" will ship Failure A. The probability table in §1 is calibrated on a per-night roll *already assuming* night comes around roughly once per patrol.

**Secondary benefit worth naming:** night-gating makes the event *predictable in kind but not in instance*. The player learns "they come at night" — which is a real tactical literacy he can act on (be home at dusk, or accept the risk and push deeper). That is the difference between a system and a random event, and it is what makes ignoring it a *decision* rather than a coin flip.

---

## 3. WHAT HE LOSES — the consequence, and why it is not a fail-state

**The Arbiter is right that a lost firebase is wrong.** Pillar 5 (`bible/BIBLE.md:91`) is "escalation, not fail-states," and the firebase is the player's only anchor — it holds the bench, the rack, the spawn, and the AAR commit point. Destroying it is a lose screen wearing a diegetic hat.

**But "nothing happened" is worse,** because it teaches the player the system is theatre. Once he learns to ignore one crisis, he ignores all of them, and every future world-event we build is discounted on arrival.

### The right consequence: **he loses MATERIEL and TEMPO, never the base and never the campaign.**

The satchel should be aimed at a **structure**, not at `fsb_center`. The firebase GLB carries authored markers (ADR-029:22 — `GUN_POINT`, `FOOTPRINT`, `APPROACH`). Target the ammo/gun point. What that buys, all of it using levers that already exist:

**1. His gun. (`CampaignState.rack_condition`, `campaign_state.gd:37,260-264`)**
The rack is in the blast. Every stored weapon's condition drops hard. He comes back, goes to the bench (`armorers_bench.gd:148` `_tick_clean`), and finds he has to spend 20 seconds per weapon (`armorers_bench.gd:10`) cleaning fouled steel before he can walk out again — or walk out with a gun that will fail him. **This is the best consequence available in this codebase** because it is felt *in his hands, in the next firefight*, not read in a menu.

**2. His steel. (`_grant_fire_support`, `field_director.gd:567-584`)**
The mortar pit went up. Next walk-out's `fire_support["mortar"]` is cut (3→1, or 0). One patrol only. He is not crippled, he is *lighter* — and he will feel it the first time he cannot break contact with a fire mission.

**3. The AO smells blood. (`add_threat_modifier`, `campaign_state.gd:84`)**
A successful sapper hit adds a positive threat delta for 2 missions. Note the deliciously ugly second-order effect this creates, and **keep it**: raised threat *also* raises his fire-support allotment (`field_director.gd:576-580`). Getting hit makes the AO more dangerous AND arms him better. That is not a bug. That is a war.

**4. Empty posts.** Dead garrison men leave their posts unmanned (`mission_generator.gd:750-769` builds them from `fsb_garrison_plan` posts). The firebase is *visibly* thinner when he walks back in. No number, no counter — Pillar 4's "silent and behavioural" doctrine (`GAME_GUIDE.md`, §4.4) applied to the base.

**5. The AAR says it back.** `_bank_patrol()`'s toast (`field_director.gd:697`) is the natural place: *"BACK INSIDE THE WIRE — THEY HIT THE AMMO DUMP WHILE WE WERE OUT."* One line. No screen.

### The moral guardrail — and I am flagging this hard

**The 17 garrison men CANNOT DEFEND THEMSELVES.** `civilian.gd:171-172` returns out of `_on_noise` for `is_garrison`, before the flee/cower roll. They do not react to gunfire. They do not react to explosions. They will stand at their posts and be killed.

A 180-damage, 10m-radius explosion (`sapper_charge.gd:31`) landing among men who cannot flee, cower, or fire back, on a repeating schedule, is **a massacre simulator, and Pillar 5 explicitly says this is not a sadism simulator** (`bible/BIBLE.md:91`).

**Therefore, binding on the implementation:**
- **Aim the charge at a STRUCTURE marker, not at `fsb_center`.** Materiel is the target; men are splash. Kill 0–3, not 17.
- If the council will not accept that, then the garrison needs at minimum a flee reaction to `NoiseBus` EXPLOSION — which means touching `civilian.gd:171`, which the Summoner has NOT ruled on and which the brief puts out of scope. **So take the structure-targeting option.** It is cheaper, it is out of scope's way, and it is better design regardless: blowing the ammo dump is a more interesting loss than a body count.

---

## 4. "WHILE HE IS AWAY" vs. "SOMETHING HE CAN WITNESS" — I argue for BOTH, with the witnessable version primary

**The Arbiter's brief leans "while he is away." I think that framing, taken alone, produces the weakest possible version of this feature.**

An event that resolves entirely off-screen and reaches the player as a toast + a map circle is **a spreadsheet event**. It has no image, no sound, no moment. Compare it to the thing this feature *could* be: you are 400m out in the dark, and the horizon behind you goes orange.

### The design: the sapper team is a THING THAT CROSSES HIS GROUND

Spawn the sapper team (2–3 men, one carrying the charge) at **300–500m from `fsb_center`, on a random bearing**, and have them *walk in*. Give the run-in a real duration — call it 90–150 seconds of travel. That window is everything:

- **He may bump them.** The ambient patrols already walk the ground between the wire and the villages (`mission_generator.gd:644-660`); a sapper team moving to the wire crosses the same ground. If he is returning from a patrol, or set in an ambush, or just walking a bearing, **he can cut them in the jungle and never know what he prevented** — or know exactly, once he learns the silhouette. `reference_vc_nva.md:125` says the sapper reads at 3–5m as "nearly naked, skin tone dominates, satchel bags. Cannot be confused." **The art already supports a recognisable enemy.** Pillar 1's "death from situation" cuts both ways: recognition is a skill the player earns.
- **He may see it.** From outside the wire, at night, a firebase is the only lit thing on the map. A satchel going off there is visible and audible from a very long way. `NoiseBus.emit_noise(EXPLOSION, pos, 1)` already fires (`sapper_charge.gd:34`).
- **He may hear about it and choose.** The `raise_crisis` path (`field_director.gd:605`) still runs, still RTO-gated. That is the *fallback* channel, not the event.
- **He may miss it entirely.** He is 600m away in heavy rain with a dead RTO. He comes back to a burnt ammo dump and a fouled rack, and pieces it together from the crater. **This is the best outcome the system can produce** and it is only possible if the event is a real thing in the world rather than a notification.

### The line I would draw
> **The toast is the FAILURE mode of the event, not the event.** Build the sapper team as a physical thing running physical ground. If the player intercepts it, the system worked. If the player hears about it and turns around, the system worked. If the player never learns it happened until the AAR, **the system still worked** — and that is the version that makes the world feel like it exists without him, which is the whole promise of "open simulator."

"While he is away" and "he can witness it" are not alternatives. **"While he is away" is the frame; "witnessable" is the implementation of that frame that has any teeth.** The pure-notification version is the frame with the teeth pulled.

---

## 5. DOES IT FIGHT ADR-029? — No, and here is exactly where the line is

ADR-029's binding constraints (`ADR-029-open-patrol-simulator.md:29-34`): no player-facing mission tracking ever; the pointer is diegetic only (grease circle, compass, point-man bark, one gate toast); floating objective markers forbidden; the gate "points the patrol at a living location," it does not command.

**A sapper attack does not violate any of those,** provided:

### The line, stated as a testable rule
> **A crisis may CHANGE WHAT IS WORTH DOING. It may never REQUIRE what is done.**

On the safe side of the line — all of it already built:
- `raise_crisis` does `patrol_locations.push_front(loc)` and retargets the *soft pointer* (`field_director.gd:609,614`). It is a suggestion in the same diegetic vocabulary as everything else.
- It is RTO-gated (`field_director.gd:612`). Off the net, the world event still happens, he just isn't told. **This is a genuinely excellent piece of design already in the codebase** and it is the strongest anti-rails guarantee here: the crisis cannot yank a man who isn't listening.
- Ignoring it is a *playable, priceable choice* with a bounded cost (§3).

On the wrong side of the line — none of these may be built:
- A countdown timer, on screen or in a toast. ("RETURN IN 4:00.")
- `mission_failed` / any fail-state on the firebase (`field_director.gd:119`).
- A persistent objective marker on the firebase.
- A consequence severe enough that no reasonable player would ever ignore it. **This is the subtle one.** If losing the base means losing the campaign, ADR-029's "no rails" survives on paper and dies in practice — a soft pointer backed by an unacceptable penalty is a rail with better manners. **The §3 consequence set is calibrated to be genuinely ignorable:** one patrol of fouled guns and thin steel is a real cost that a player can rationally decide to eat in exchange for finishing the sweep he's on. That ignorability is not a weakness of the design. **It is the design.**

### The one thing that DOES fight ADR-029, today, in the code
`sapper_charge.gd:28` calls `director.toast.emit("SAPPER IN THE WIRE!")` **directly**, at 40m, bypassing `raise_crisis()` and therefore bypassing `_radio_check()` (`field_director.gd:612`). That is a marker appearing from nothing for a player with no radio — the exact thing `raise_crisis`'s comment (`field_director.gd:603-604`) says must never happen, and a Fairness Law violation.

**Binding on implementation: route the warning through `raise_crisis`, or gate it on `_radio_check()` / on the player having line-of-sight. Do not ship line 28 as written.** (See §7.)

---

## 6. WHAT IS SACRIFICED

No free lunches. Naming them:

1. **Most players will rarely see it.** At LOW/MODERATE threat this fires maybe once every 5 nights. We are building a behaviour, an explosion, a spawn path and a consequence chain for content that is, by deliberate design, uncommon. **This is the direct price of not shipping Failure A**, and I pay it willingly, but it is real engineering spent on rare content.

2. **The inversion: the best content goes to the worst players.** Threat-gating means the careful, quiet player — the one `ADR-006`'s +25/contact-avoided economy actively rewards (`GAME_GUIDE.md:140`) — is the one who sees this system least. The reckless player gets the memorable nights. I accept it because it is Pillar 5's escalation logic working correctly, but it is a genuine tension with the scoring economy and someone will eventually notice that playing "right" makes the world quieter.

3. **Structure-targeting sacrifices the horror.** Real sapper attacks were bloody, close, and personal. Aiming at the ammo dump to avoid massacring 17 defenceless noncombatants trades away the most viscerally Vietnam thing this feature could do. The alternative costs a ruling on `civilian.gd:171` that is explicitly out of scope. **This sacrifice is forced by scope, not chosen** — and it should be revisited the moment the garrison-combatant question is ruled on.

4. **Night-gating carries less weight than it reads.** At 24 real minutes per day, "they come at night" gates out ~58% of playtime, not 90%. The flavour is worth it; anyone who tunes on the assumption that night is scarce will be wrong by roughly 4×.

5. **New persistence surface.** Rack-condition damage and a one-patrol fire-support penalty mean new campaign state to save, migrate and probe (`campaign_state.gd:140-207`, `SAVE_VERSION` at `:6`). Every consequence I proposed uses an *existing* lever specifically to hold this cost down, but the coupling is new and the save schema will feel it.

6. **The probability table is unplayed.** 0.20 / 0.45 / 0.70 are reasoned from the 24-minute day and the 20–30 minute patrol (`GAME_GUIDE.md:194`), not measured. They are a starting position for the Summoner to feel and re-rule, and they should be data, not constants in a `.gd`.

7. **A second consumer for `SimClock.schedule_event` deepens a dependency** that today has exactly one production caller (`mission_generator.gd:348`). If that scheduler has bugs, this feature will find them.

---

## 7. Implementation constraints I would bind (design-side, for the programmer's lens)

Not my lane to specify the code, but these are design requirements, not implementation preferences:

1. **`sapper_charge.gd:28` must not emit a toast directly.** Route through `raise_crisis()` or gate on `_radio_check()`. As written it violates the Fairness Law and ADR-029's diegetic-pointer rule (§5).
2. **Target a structure marker, not `fsb_center`.** Materiel is the target; garrison deaths are splash, capped low (§3).
3. **The sapper team spawns at 300–500m and walks in.** The travel window is the feature (§4). A sapper that materialises at the wire is a notification with a particle effect.
4. **The probability table lives in data, not in a constant.** The Summoner will re-rule these after one session of play, and he should not need a code change to do it.
5. **The existing 2-crisis-per-operation cap stays, applied to the TOAST, not to the spawn.** The world may do more than it tells him about. That asymmetry is the open-simulator promise.
6. **Do not build a `sapper_charge` consumer that also converts the garrison to combatants.** Out of scope per the brief, and §3's structure-targeting is specifically designed so that ruling is not needed.

---

## Verdict in one line

**One roll per sim-night, night-gated via the SimClock that already exists, probability scaled by the threat tier the player earns with his own noise, never before patrol 3, never two nights running — and build it as a sapper team that runs 400m of real ground so he can cut them in the dark, with the toast as the failure mode rather than the event. He loses his rack's condition and one patrol's steel, never the base.**
