# GAME DESIGNER — THE SIEGE (v2), independent analysis

**Date:** 2026-07-28 · **Lens:** the feel and the player's minute-by-minute experience of a night
siege from inside his own wire. Every claim below cites `file:line`, measured against the code today.

---

## 0. THE NUMBERS THAT ALREADY EXIST (read before designing anything)

These are not proposals. They are the constants the siege will actually be played in.

| Fact | Pointer | What it means for feel |
|---|---|---|
| 1 real second = 60 sim seconds | `scripts/autoload/sim_clock.gd:17` `real_to_sim_ratio = 60.0` | **A whole night is 10 real minutes.** NIGHT = 19:00–05:00 (`sim_clock.gd:57-64`). |
| Night sight cap = 140 × 0.4 = **56 m** in the open | `scripts/ai/sight_cap.gd:12` `DARKNESS_BY_PERIOD[NIGHT]=0.4` × `enemy_base.gd:80` `SIGHT_CAP_OPEN=140.0` | Both sides. Confirmed by `tests/test_night_sight.gd:58`. |
| Night sight in jungle = 45 × 0.4 = **18 m** | `enemy_base.gd:81`, `sight_cap.gd:39` | The treeline outside the wire is functionally black. |
| A flare lifts the cap to 140 × 0.9 = **126 m**, radius 30 m, 25 s | `illum_flare.gd:8-9`, `sight_cap.gd:34`, probe `test_night_sight.gd:81` | **75 seconds of total vision per patrol** — the player carries 3 (`player.gd:94` `flare_count = 3`). |
| Attackers spawn at 300–500 m | `field_director.gd:785-786` | i.e. **5–9× beyond the night sight cap.** They walk in unseen for a long time. |
| Garrison = 24 men max, ~17 curated posts around the full ring | `site_planner.gd:687-701`, `:726` `FSB_GARRISON_MAX_MEN = 24` | A real body of defenders — see §4. |
| A garrison defender is leashed to his post at **8 m** | `garrison_defender.gd:60` `post_leash = 8.0`, enforced `ally_base.gd:855-856` | On a one-axis attack, ~3/4 of the garrison never fires a shot. |
| Only **12 enemies world-wide** run full combat AI | `enemy_squad.gd:37` `HOT_CAP = 12` (a GLOBAL static `_hot`, `:35`) | A d50 siege is 12 fighters and 38 walkers. See §5. |
| Squad break already exists at **ratio < 0.45** | `enemy_squad.gd:103` `BREAK_RATIO = 0.45`, `is_broken():147-151`, consumed `enemy_base.gd:1217-1218` | **The decree's 40–50% break condition is already built.** |

**CORRECTION TO THE BRIEFING.** The briefing states at `:38-39`: *"There is no formation-level
morale/break."* That is false as of today. `EnemySquad.is_broken(squad_id)` (`enemy_squad.gd:147`)
computes living/peak strength against a courage-modulated threshold (`:111`) centred on
`BREAK_RATIO = 0.45`, and `enemy_base.gd:1217-1218` adds `+0.7` to every man's RETREAT score when
his squad is broken. Every man spawned through `FieldDirector.spawn_tracked_enemy` gets
`squad_id = hash(group_tag)` (`field_director.gd:39`), so `"sapper_assault"` and `"firebase_assault"`
are already two coherent formations with a break threshold of **45% losses**. The Summoner's decree
("40 to 50 percent") landed on a number this codebase independently arrived at. **Do not build a
second break authority.** The work is not inventing the break — it is (a) making the attack ONE
squad_id so the ratio is over the whole assault and not per-element, and (b) making "broken" mean
*walk off the map on a known bearing* instead of *score RETREAT higher*.

---

## 1. THE BEAT SHEET — a d50 siege in seconds

Written against `real_to_sim_ratio = 60.0` (`sim_clock.gd:17`), so all timings below are REAL
seconds the player sits through. A 10-real-minute night is the entire canvas; the siege must fit
inside it with quiet on both ends, or "night" becomes "siege" and the dread evaporates.

**Target shape: ~6:30 of siege inside a 10:00 night.**

### T−90s to T−0 · THE HAIR STANDS UP (the tell)
The world goes wrong before anything is visible. `GameWorld.set_wildlife_ducked` already exists as
the verb (`mission_weather.gd:145`, called on rain) — reuse it: the ambient jungle track drops out.
No toast, no marker. If the player is asleep/at the mess he learns from the sentries: a garrison
sentry bark, then the wire's first shot. **This is the only warning that should exist.** See §7.

### T+0 to T+45s · FIRST CONTACT ON THE WIRE (the sentries, not the player)
The lead element walks into the 56 m night cap and the sentries on the threatened arc open up.
The player's *first* information is muzzle flash and tracer — and tracers already read brighter at
night (`bullet_system.gd:218`, `bullet_tracer.gd:37` `4.5 if MissionWeather.is_night`). The garrison
promotion fires here (`field_director.gd:1066` `_garrison_stand_to`) with its one toast,
`"STAND TO - THE WIRE'S IN CONTACT"` (`:1078`).

**This is the correct opening and it must not be replaced by a radio call.** The player runs to a
sound. That is a Vietnam firebase.

### T+45s to T+2:30 · RANGING ROUNDS (the decree's mortars)
First round lands LONG and wide — the player hears the tube (a distant *thoomp*), then a hang, then
a crump in the wire behind him. Second round short. Third bracketing. The cadence should be one
round every 12–18 real seconds, walking a bracket **inward toward the compound centre**, so the
player learns the geometry of the walk and *moves* because of it.

The shell verb already exists whole and is side-agnostic: `_fire_shell` (`field_director.gd:648`)
spawns a real round on a bearing and arcs it via `Ballistics.fire_arc`, and `_mortar_impact`
(`:721`) applies `140 × intensity` damage at `FirePlan.MORTAR_BLAST_M = 10.0`
(`fire_plan.gd:17`) plus terrain deformation. **The enemy mortar is not a new system — it is
`_fire_shell` with an enemy azimuth and a walking aim point.** The one thing it must NOT reuse is
`_run_mortar_mission` (`:586`), whose `MORTAR_SPOT_M = 15.0` ranging shot (`fire_plan.gd:16`) is
tuned for the *player's* call. The enemy's error must start much wider (60–80 m) and tighten to
~10 m over the siege — that tightening IS the clock the player is racing.

**Feel note, and it is the whole reason the mortar earns its cost:** it takes the player's cover
away from him over time. At T+45 the bunker is safe. At T+5:00 it is registered. The siege has a
direction of travel even when nobody is shooting.

### T+2:00 to T+4:30 · THE ASSAULT (the loud element closes)
Behind the ranging rounds the main body closes from 300 m to the wire. At night-cap 56 m they are
invisible for ~240 m of that walk. The player's ONLY counter is illumination — and he has 75 seconds
of it (§0). **This is the tension engine of the whole encounter and it is already built.** He is
spending a scarce resource to buy back sight, and every flare lights *him* too
(`illum_flare.gd:1-2` — "Works both ways - you're lit too").

### T+3:00 to T+5:30 · THE SAPPERS (the different problem)
The 2d6 sappers are a **separate verb from the assault** and must read that way. `SapperCharge`
(`sapper_charge.gd`) drives a man to a fixed point and detonates at 5 m for 250 damage in a 14 m
radius (`:15-18`), sparing nobody (`:59-60`, `spare_garrison=false`). They are per-unit harder to
see at night (asserted in `tests/test_firebase_defense.gd:9-11`).

The assault is *noise on the perimeter*. The sappers are *a man already inside your wire*. The beat
the player must feel: he is shooting at the loud thing on the north wire when a satchel goes off
behind him.

### T+5:30 to T+6:30 · THE BREAK
Losses cross ~45% and `EnemySquad.is_broken` flips (`enemy_squad.gd:147`). Survivors must **leave on
a legible bearing**, not mill. See §2.

### T+6:30 to dawn · THE MORNING AFTER
Currently: **nothing happens.** There is no AAR, no butcher's bill, no closure — because
`_bank_patrol` (`field_director.gd:1213`) fires only on crossing the wire INWARD
(`:941-943`), and a man who never left never crosses it. See §6.

---

## 2. "A REAL FIGHT FOR DEATH OR LIFE" — what the current build actively prevents

Five things, ranked by how much each one costs the fantasy.

### 2.1 THE SIEGE CANNOT HAPPEN WHILE HE IS HOME (fatal, already named)
`_poll_firebase_threat:1027` returns on `not patrol_out`, and `_maybe_launch_sappers:1105` requires
`patrol_count >= 1`. The briefing names the first. I confirm both and add: `_garrison_stand_to` is
called from inside that gated function (`:1039`), so **the garrison cannot stand to while the player
is inside his own wire.** The 24 men keep walking to the mess line while sappers cross the wire.

### 2.2 HE CAN SHELL HIS OWN WIRE, AND THAT IS NOT THE PROBLEM PEOPLE THINK
The fire menu (`field_director.gd:179-207`) is live wherever he stands, and `_grant_fire_support`
(`:957`) hands him 3–4 mortars + 1 arty + 1 snake-eye per walk-out, with napalm/CBU/Spectre at
HIGH/CRITICAL (`:966-970`). Arty is 6 rounds of 200 damage at 14 m blast (`:439-445`,
`fire_plan.gd:19`).

**RULING: calling steel onto your own wire IS the fantasy. Do not nerf it. Price it.** Three things
already price it correctly and one does not:
- `_danger_close_to_squad` (`:559`) includes the PLAYER (`:561-563`) and extends by the footprint
  reach (`:558`). At `DANGER_CLOSE_M = 45.0` (`:265`) *every* call inside a firebase is danger-close.
  The double-press ritual therefore fires on every single call of the siege. **That is correct and it
  is the best moment in the encounter** — the ADR-011 language for it ("you look at your own men and
  mean it", ADR-011:58) is exactly the siege's peak.
- `_radio_check` (`:523`) requires a LIVING RTO within 10 m (`:266`). In a siege that means the
  player is dragging one specific man around a perimeter under mortar fire. **Kill the RTO and the
  sky closes.** This is the single best pillar-4 pressure in the game and the siege is where it pays.
- The budget is scarce: 3–4 mortar missions total. He cannot spam it.
- **What does NOT price it:** `_mortar_impact` (`:721`) and `_arty_impact` (`:574`) call
  `CombatManager.apply_explosion_damage(..., null)` with no attacker attribution and — critically —
  **nothing stops those rounds from killing the promoted garrison.** Good. But there is no
  consequence beyond death: no toast, no reputation cost, no line in any ledger for the men he
  killed. `civilian_deaths` (`mission_state.gd:22-28`) counts noncombatants only, and the garrison
  stops being a Civilian the moment it is promoted (`garrison_defender.gd:42-43`). **A player who
  wins the siege by dropping arty on his own bunkers should read that on the morning-after list.**

### 2.3 THE PLAYER IS BLIND AND HAS NO WAY TO BUY SIGHT AFTER 75 SECONDS
Three flares × 25 s (`illum_flare.gd:8`, `player.gd:94`) is the entire illumination economy, and it
is refilled only by a supply crate (`player.gd:669`). A 6-minute siege has 75 seconds of light in it.
After that he is fighting at 56 m in the open and 18 m in the vegetation, against men who see him
exactly as well (the symmetry is probe-locked, `test_night_sight.gd:87-111`).

**There is an unreachable answer already sitting in the code.** `request_fire_support` has a `"wp"`
branch (`field_director.gd:456-457` → `_run_wp_mission:610`) that fires a white-phosphorus round.
It is reachable from **nothing**: `"wp"` is not a key in the `fire_support` dict (`:255`), not in
`_grant_fire_support` (`:962-965`), and not bound to any menu key (`:180-195`). Per the FOSSIL LAW
triage in `CLAUDE.md:322` this is **UNFINISHED, not FOSSIL** — built ahead of its wiring. The siege
is its wiring. An **ILLUM mission** on the same shell path (`_fire_shell:648`) — a round that pops a
long-burning flare over a placed point — is the player's one strategic answer to the dark, it costs a
tube he might have wanted for HE, and it lights him too. Build it as the WP mission's sibling or as
WP's actual purpose.

### 2.4 THE GARRISON IS COMPETENT BUT PINNED, AND 3/4 OF IT IS SPECTATING
See §4.

### 2.5 THE ATTACKERS WILL NEVER BREAK ON THEIR OWN, AND THEN THEY WILL BREAK ALL AT ONCE
`_local_force_ratio` (`enemy_base.gd:1238-1249`) counts friends within 25 m against player + allies,
and `numbers_mult = clampf(1.6 - ratio*0.45, 0.25, 1.4)` (`:1220`) **quarters** the retreat urge for
a man in a crowd. Fifty men on one axis is a permanent 3:1 local ratio: they will press with
`+0.15 ADVANCE` (`:1203-1204`) and effectively never withdraw individually. That is *good* — it is
what makes the first half feel like a tide. But it also means the ONLY exit is the formation break,
which makes §2.5's tuning load-bearing: get `BREAK_RATIO` wrong and the siege either never ends or
ends in one frame.

---

## 3. THE ONE-AXIS RULING — the version of it that is still frightening

**Does one axis make it a shooting gallery? As currently coded, yes.** `launch_sapper_assault`
(`:1115-1144`) rolls ONE `bearing` (`:1122`) and jitters sappers ±0.35 rad (`:1124`) and the assault
element ±0.5 rad (`:1137`). At 300–500 m that is a ±20°/±29° cone — a *line* of men walking at a
*line* of guns. The player picks one firing position, faces one direction, and the encounter has one
input.

**The ruling stands. Here is the version that keeps the fear, and none of it violates it.**

1. **The axis is a SECTOR, not a bearing — and it is chosen by terrain, not by `randf`.** One
   quadrant of the ring (~90°), picked where the vegetation and approach lanes actually favour an
   attacker. `SightCap.at` already reads `grid.get_vegetation` (`sight_cap.gd:38`), so the AI's own
   sight model already knows which arc is dark. Ninety degrees still means *"they are coming from
   the north"* — one direction to run to, no man lost in 500 m of jungle — but the player cannot
   solve it from one sandbag. He has to move along an arc, and moving is when the mortars get him.
2. **The sappers get a different vector INSIDE the same sector.** The decree says one overall axis;
   it does not say one line. Sappers should approach the *flank of the sector* — the seam the loud
   element is pulling eyes away from. The code already declares this intent in the comment at
   `:789-792` ("they fire, telegraph with tracers and voices, and pull the garrison's eyes while the
   sappers slip in quiet") and then **defeats it by drawing both from the same bearing.** Widen the
   sappers' offset to the sector edge and the intent becomes real for the cost of one number.
3. **A feint is legal and costs nothing.** Two or three men on the *opposite* side who fire and do
   not close. They are inside the "no lost NPCs" rule because they are few, they are loud, and they
   withdraw with the break. What they buy is the player's *doubt* — the moment he wonders whether
   he has committed to the wrong wall. That doubt is the difference between a siege and a range day.
4. **The axis must be legible within 30 seconds.** Sentries' tracers, the direction of the first
   crump, the bark. A player who spends two minutes finding the fight is bored, not tense.
5. **Say the axis out loud, once.** When the garrison stands to (`:1078`), the toast should name the
   arc — *"STAND TO — THEY'RE ON THE NORTH WIRE"*. Not a marker. A direction. ADR-029 §4 forbids
   objective markers; it does not forbid a man shouting a compass bearing.

**What is sacrificed (named, per council law):** flanking the attackers is no longer a real player
option — you cannot get behind a 90° sector without leaving the wire in the dark. The siege is a
defensive encounter with defensive verbs, and the player who wants to manoeuvre will feel walled in.
Accepted: this is the ONE encounter in an open patrol sim where the walls are the point.

---

## 4. PILLAR 4 — does he command the garrison, or hold one sector? **RULING: he holds a sector.**

The player commands his SQUAD and only his squad. The order verbs already exist and are already
squad-only: `squad_system.gd:152-167` binds `squad_follow` / `squad_hold` / `squad_move` and
`_order_all` (`:177`) iterates `members`. Garrison defenders are deliberately excluded — they are
promoted with `squad_member = false` (`garrison_defender.gd:52`) and `OrderMode.HOLD` on a
`post_anchor` (`:58-60`), exactly like `friendly_patrol_group.gd`.

**Do not add a garrison order verb.** Pillar 4's own text (`CLAUDE.md:21`) says *"a design that has
you positioning individual men violates this."* Twenty-four men on a perimeter is the purest
possible temptation to violate it, and the encounter is better without it: the fantasy of a firebase
under attack is *you are one rifle and the wire holds or it doesn't.* You trust the men on the other
arcs because you cannot see them and cannot help them.

**But the current pinning is too absolute, and it makes 18 of 24 men irrelevant.**
`ally_base.gd:855-856` hard-drags a defender back the instant he exceeds `post_leash = 8.0 m`. On a
90° sector attack, the ~6 men whose posts face that arc fight; the other ~18 stand in the dark
looking at nothing for six minutes, and the player can do nothing about it. That is not tension,
it is a staffing error the player is forced to watch.

**The fix that respects the pillar:** the garrison re-weights **as a body, by itself**, without a
player order. When the threat sector is known, off-arc posts shift a fraction of their men toward
the contact — a single "reinforce the threatened arc" behaviour owned by `GarrisonDefender`, not by
the player, and not per-man. He never positions a soldier. He watches men run past him toward the
sound, which is the correct emotional read and costs him nothing to author.

**What is sacrificed:** the player who *wants* to run the defence will resent that he cannot. That
is the pillar, working as designed.

---

## 5. THE FRAME BUDGET, FROM A DESIGN SEAT (the honest read on d50)

I defer the numbers to the technical architect, but one design consequence must be said here because
it changes what the encounter IS: **`HOT_CAP = 12` is global** (`enemy_squad.gd:37`, static `_hot`
at `:35`). Of fifty attackers, twelve run full combat AI and thirty-eight run cold. `request_hot`
(`:65-81`) hands slots out first-come and `release_hot` (`:84`) frees them on death, so the hot set
is *whoever thought first*, not *whoever is fighting the player*.

Design reading: that is nearly the right encounter by accident. A siege SHOULD be twelve men in
contact and thirty-eight moving up in the dark. But the hot set must be biased to **proximity to the
player's arc**, or the player will spend the siege shooting at cold walkers while twelve smart men
fight a garrison sentry he cannot see, on the far side of the compound.

If the frame cannot pay for 50 bodies, **cut the count, never the sappers.** A d30 siege with 2d6
sappers is still the decree's encounter; a d50 siege where the sappers were trimmed is not.

---

## 6. FAIL FORWARD — what it means to LOSE a firebase

Today the entire cost of a successful assault is `on_firebase_breach` (`:1085-1093`): 3 mortars and
1 arty docked now, the same docked from the next allotment via `CampaignState.depot_loss`
(`:1091`, consumed `:974-980`), one toast. It is once per operation (`:1086`). **That is the price of
a bad afternoon, not the price of losing a firebase.**

Worse, there is no closure event at all. `_bank_patrol` (`:1213`) — the AAR, the reputation bank
(`:1218`), the squad's end-of-mission tick (`:1222`) — fires ONLY on crossing the wire inward
(`:941-943`). A night spent fighting for the base's life inside the wire produces **no AAR, no
butcher's bill, no rank movement, nothing.** The siege ends and the game says nothing.

And there is an active *inversion*: `spawn_tracked_enemy` registers every spawned group in the
ADR-006 contact ledger (`:42-44` → `mission_state.register_group`), regardless of `patrol_out`. The
siege's two or three groups are detected by definition. At −25 per detected contact (ADR-006:51-52)
**surviving a siege silently debits the player's next patrol score by 50–75 points.** He is punished
for being attacked in his sleep. That must be fixed whatever else is built — either the siege's
groups never enter the ledger, or the siege banks its own AAR.

### What losing should mean (Pillar 5: escalation, not a fail-state)
1. **A morning-after AAR at first light**, not at the wire. The night's own accounting: attackers
   killed, garrison dead by name (the promoted men carry real `SquadRoster` names,
   `garrison_defender.gd:56`), what was destroyed, whether any of them died to his own steel (§2.2).
   This is the encounter's payoff and it currently does not exist.
2. **The garrison does not respawn.** Men lost are gone for the rest of the operation. Night 2 of a
   three-night run is thinner than night 1 — that is the three-night structure's entire dramatic
   engine, and without it the run is one night played three times. It also gives the player a real
   reason to care about a stranger dying on the far wire.
3. **A lost firebase is a DEGRADED firebase, never a game over.** Escalate what breaks: the depot
   (already), then the MG emplacements (`MGEmplacement`, placed at `mission_generator:783-790`),
   then the TOC/radio — and losing the radio is the most interesting loss in the game, because
   `_radio_check` (`:523`) already makes the sky conditional on a man and a machine.
4. **The AO answers.** A firebase that was nearly overrun should make the next day's world louder,
   through the existing threat tier (`CampaignState.threat_label`, read at `:961`) — which the
   player already sees in the barracks and which already buys him napalm and Spectre (`:966-970`).
   The loop closes on itself: a bad night buys harder ordnance for the next one.

---

## 7. WHERE HE LEARNS IT IS COMING — telegraph it, but never announce it

**Ruling: telegraph in the WORLD, never in the UI, and never with certainty.**

ADR-029 §4 forbids player-facing mission tracking, and a "TONIGHT: SIEGE" toast would be exactly
that. But a siege with zero warning is a cheap ambush, and — worse — it is unplayable, because the
player's preparation verbs (positioning, manning the MG at `player._nearby_mg_emplacement`, standing
near the RTO, husbanding flares) all take real minutes he will not be given.

The tells, in order of when he gets them, all of them diegetic and all of them *ambiguous*:

1. **The day before, in the field.** He walked past a camp and it was empty. He took fire from a
   direction with no camp in it. The threat tier moved. These already exist as world state; nothing
   new is needed except that the AO be allowed to *look* different before a siege night.
2. **At dusk.** The garrison's own behaviour. `SitePlanner` already alternates two sentry shifts
   specifically so "the wire is not empty after dark" (`site_planner.gd:819-822`). On a siege night,
   more men on the wire, fewer at the mess. He can read it if he looks. He gets no toast for it.
3. **Minutes out.** The jungle goes quiet — `set_wildlife_ducked` (`mission_weather.gd:145`,
   implemented `game_world.gd:313`) is already the verb for exactly this and is currently used only
   by rain. This is the strongest, cheapest tell in the whole design and it is already built.
4. **Never a certainty.** Some quiet nights must have all the tells and nothing happens. A tell that
   is always right is a UI element wearing a costume.

**One thing he SHOULD be told, once, when it starts:** the arc. See §3.5. Everything before that
moment is atmosphere; that one line is the difference between a fight and a scavenger hunt.

---

## 8. THE DIVERGENT-SYSTEMS ANSWER (which authority owns the siege)

`FieldDirector` owns it, alone. It already holds the threat poll (`:1026`), the garrison stand-to
(`:1066`), the breach cost (`:1085`), the crisis channel (`:1005`), the spawn+ledger seam (`:31`),
and the only shell-in-the-air verb in the repo (`_fire_shell:648`). The v2 siege is `SAPPER_*` /
`_sapper_launched` / `launch_sapper_assault` **deleted and replaced in place** (FOSSIL LAW,
ADR-023). The enemy mortar is `_fire_shell` with an enemy azimuth — **not** a second indirect-fire
system, and **not** `_run_mortar_mission`, whose sheaf constants belong to the player's call. The
formation break is `EnemySquad.is_broken` (`enemy_squad.gd:147`) — **not** a new morale system.

---

## 9. RANKED BUILD ORDER (design priority, not effort)

1. Un-gate the siege from `patrol_out` / `patrol_count` (`:1027`, `:1105`) — without it nothing else
   matters.
2. Garrison stand-to must be repeatable and casualty-persistent (`_garrison_stood_to:1067` latch).
3. Enemy ranging mortar on `_fire_shell`, wide→tight. This is the siege's clock.
4. Break = `EnemySquad.is_broken` on ONE assault squad_id + a real withdrawal on a known bearing.
5. Sector (not line) axis, sappers on the sector flank, one arc named in the stand-to toast.
6. The morning-after AAR + garrison dead by name + the ADR-006 ledger inversion fixed (`:42-44`).
7. Wire the ILLUM/WP mission (`:456`, `:610`) into the menu and the allotment.
8. Garrison re-weights toward the threatened arc as a body (never a player order).
