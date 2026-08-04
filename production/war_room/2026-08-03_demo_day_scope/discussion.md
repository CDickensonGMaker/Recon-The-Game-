# THE DEBATE — 2026-08-03 — Demo Day Rescope

Phase 3. Six architects wrote independently with no cross-talk. What follows is where they
AGREE (weight: independent convergence on the same pointer is the strongest evidence this
council produces), where they CONFLICT, and where the Arbiter was WRONG.

---

## 1. UNANIMOUS, INDEPENDENTLY DISCOVERED: THE SUN DOES NOT MOVE

Three architects who never spoke to each other found the same wall.

- **Devil's Advocate:** `mission_weather.gd:20-25` is a 4-state table; `_apply_time` fires only on
  a period crossing (`:77-83`), easing 6s (`:41`). DAY runs 7.0–17.0 (`sim_clock.gd:55-59`).
  A 0700→1900 arc gets **two lighting events**. "By the r4bk Law the day arc does not exist."
- **Game Designer:** sun angle is a per-PERIOD constant (`mission_weather.gd:88-120`). "Ratio is
  felt as event density, never as time."
- **Technical Director:** DAY is a fixed −50° block. "A 23-minute day renders with a nailed sun
  for ~19 of them." And the fix has a price: the sun may move but **must never cast** —
  −10.5 FPS at any shadow cap (`PERF_LEDGER.md:727-734`).

**This is the single most important finding of the council.** Every clock-ratio question in the
briefing (question A) was downstream of an assumption nobody had checked. The Arbiter asked "what
ratio?" when the real question was "what does the engine render?"

**Corollary, found twice independently:** *0700 does not exist in code.*
`mission_weather.gd:40` `TIME_ID_START_HOUR` = {5.5, 10.0, 17.5, 21.0} and it WINS over
`mission_generator.gd:248-255` (`game_flow.gd:677-679`). There is no 7.0. The demo's 17:30 is
DUSK's table constant, not an authored time.

---

## 2. UNANIMOUS: QUESTION D WAS FALSIFIED. THE ARBITER READ IT BACKWARDS.

Three architects, same correction, same pointer.

`field_mult` multiplies the **wait between waves** (`field_director.gd:148`), not the wave count.
A lower multiplier means waves arrive **sooner**. Decay makes the late game HARDER, exactly as its
own comment at `:129` says. The Arbiter's premise — "the second half is softer" — is wrong.

And it is worse than wrong, it is **moot**: `mins` reads `state.elapsed_seconds()` (`:132`), and
`state` is rebuilt on every inbound wire crossing (`:1584-1587`). In the Arbiter's own 3-excursion
shape, no leg reaches 15 minutes. The decay is dead code in this arc.

**RESOLVED: do not invert it. Do not flatten it. The real softening is elsewhere — see §3.**

---

## 3. CONVERGENT: THE SECOND HALF GOES SOFT BECAUSE THE POOL RUNS DRY

- **Systems Designer:** 12 men (`field_director.gd:106`), 2–4 per wave (`:149`) ≈ 4 waves;
  70–110s then 100–160s (`:118`, `:148`) = **~7.7 minutes of contact and the AO is empty forever.**
- **Game Designer:** independently, "the soft second half is `_hunter_pool = 12` (`:106`) running
  dry after 3–6 waves."

In a 7-minute demo this never surfaced. In a 30-minute one it is the arc's spine snapping at the
one-quarter mark. Systems proposes topping the pool up on each OUTBOUND gate crossing, at the same
seam as the fire-support grant (`:1221`).

**Sacrifice named (Systems):** this breaks ADR-035's per-operation finite-pool promise — "you can
bleed the AO dry" stops being true. The Arbiter weighs this in §5 of the synthesis.

---

## 4. THE ARBITER'S QUESTION F WAS ASKED ABOUT THE WRONG THING — AND THE ANSWER IS WORSE

**Technical Director, measured:** `LIVE_CAP` is read in exactly two places
(`siege_director.gd:421-430`, `:435-446`) and **both walk only `SiegeDirector.cells`.**
The garrison does not count (`field_director.gd:1364-1378`). Hunters do not count (`:155-162`).
Allies do not count. `spawn_tracked_enemy` has no cap at all (`:41-57`).

**The three populations never meet in any counter.** The "collision" the briefing feared cannot
happen, because there is no global headcount — and ADR-026 forbids adding one.

**Systems Designer, arriving from the opposite direction, found the consequence:** hunters are
**never reaped** (`siege_director.gd:712-716` walks only siege cells). A quiet day ends with
~12 hunters + ~40 garrison + 45 assault ≈ **97 bodies alive under a cap that only sees 45.**
The Devil's Advocate counted ~118 including squad. Different totals, identical finding.

**THE REAL DEFECT (Technical Director, and nobody else saw it):** `_enforce_live_cap` calls
`set_physics_process(false)` (`:444`), and **`set_physics_process(true)` exists nowhere** in
`marching_cell.gd` or `siege_director.gd`. It is a **one-way latch**. A frozen cell never marches
again, still reports full paper strength (`marching_cell.gd:56-57`), so `live/peak` never falls and
**the assault can never break** — it runs to `MAX_DURATION_S` past the end card.

That is the 2026-07-28 trickle failure, still loaded. `SIEGE_STRENGTH = 45` is what disarms it
(`demo_game.gd:44-48`).

**THEREFORE THE ARBITER'S PROPOSED 55 ARMS A KNOWN SOFTLOCK BY CONSTRUCTION — on the branch that
fires when the player has the WORST day.** The Devil's Advocate reached the same conclusion by a
different route: "the Arbiter's 55 sits above the cap that caused the 7/28 trickle."

**RESOLVED, and it is the hardest ruling of this council: the day may move SIEGE_STRENGTH DOWN
from 45 and NEVER up.**

---

## 5. CONFLICT: DOES THE DAY FEED THE NIGHT AT ALL? (question E)

| Architect | Position |
|---|---|
| **Systems** | YES — fold, don't subtract. `night = 45 − hunters_killed − 8(mouth blown) + 10(informer)`, clamp 28–45. **Trap: never price it off `state.kills` — the midday bank wipes it** (`:1584`). |
| **Game Designer** | YES, conditionally — "speak it twice or don't build it." Carriers already exist: RTO radio VO at the gate (`field_director.gd:667-673`) and the end card (`demo_game.gd:331-359`). |
| **Devil's Advocate** | **NO, as a body count.** Night sight is 56m, the assault crosses 190–235m, illum strobes 55s on / 15s off. **A player cannot tell 35 men from 55 men at night.** Build the consequence as a **BREACH** — the siren is already wired — not as a number. |

**The Devil's Advocate wins the perception argument and loses the design argument.** He is right
that the body count is imperceptible *as a body count*. He is wrong that this kills the link: the
Game Designer's two speech acts and the DA's own breach both make it perceptible without the
player ever counting anyone. These are complementary, not competing. Synthesised in the decree.

---

## 6. CONVERGENT: THE ARBITER'S BEAT SHEET DOES NOT SURVIVE

**The walk is not 2.5 minutes — it is ~25 seconds.** (Devil's Advocate, measured.) Village at
185m from centre (`mission_generator.gd:709`), parapet at 96m, `WALK_SPEED 5.0` (`player.gd:5`).
The Arbiter budgeted 2.5 minutes of walking for 25 seconds of ground. **"Padding presented as
pacing."** Upheld without dissent.

**And nothing can happen on that walk anyway.** Double-gated, found by three architects:
`_check_detection` requires a COMBAT contact (`field_director.gd:113-119`) AND `_process_escalation`
returns early on an empty evidence ledger (`:143-145`), which is fed only by player gunfire
(`:35-38`), then waits 70–110s (`:118`). **Ruling 9 — "a hunter patrol must be able to hit the
player any time outside the wire" — is structurally impossible in the shipped code.**

**Unanimous on the remedy (question G): SHIP THE AMBIENT CELL.** Game Designer wants it *crossing
his front* at ~2:45 — let-pass-or-shoot, which teaches the stealth economy with zero tutorial.
Systems names three hard constraints: the road must stay **>90m from `fsb_center`** or
`_poll_firebase_threat` (`:1328`, `FSB_THREAT_MEN` 2) stands the whole 40-man garrison to at 07:05;
`last_combat_contact_ms` is a **global static** (`enemy_base.gd:272`) so any enemy going loud
anywhere fires a false "YOU'VE BEEN MADE" with nothing behind it; and it must be tagged `"hunters"`
so the night arithmetic folds it in.

**And the 200m landmark is two disabled lines** (Level/World): the patrol planner already places
first-signs at 150–300m (`:496`, consumed `:765-769`); `mission_generator.gd:723-724` ships zero.

---

## 7. THE MIDDAY RETURN: THE ARBITER PROPOSED IT, TWO ARCHITECTS CONDEMNED IT, ONE SAVED IT

- **Game Designer:** DEAD TIME AND DAMAGING. Zero code reads the chow-hall markers (no repo hits
  for `WB_chowhall`/`work_eat`/`food_stop`/`work_serve`); the return fires the AAR the demo
  EXCLUDES (`field_director.gd:1564-1578` vs `demo_game.gd:20`); and `_bank_patrol` resets
  `state.start_time_ms` (`:1584-1587`) — **it makes the afternoon easier.** Move the chow hall
  to 21:30, before stand-to.
- **Devil's Advocate:** independently found the same AAR collision — debrief toasts and a possible
  FIELD PROMOTION in a demo that excludes the debrief.
- **Level/World:** YES — **but only with the chow hall exported.** 198 markers, 40 men, alternating
  sentry shifts, seeded aid station, ledger-conditional litter team
  (`site_planner.gd:964-990`). "It must be worth taking and safe to skip" (ADR-020 §3) — never the
  only source of satchels or bandages. **Without the export it is the same lap he walked at 0700.**

The three do not actually disagree. All three say *the return is worth nothing without the chow
hall, and the AAR fires regardless.* The Game Designer's 21:30 placement resolves it.

---

## 8. THE EXPORT IS THE REAL BLOCKER — AND IT IS OLDER THAN ANYONE THOUGHT

**Level/World, MEASURED:** `fsb_main_v3.glb` is dated **Jul 26**. Zero `WB_chowhall`, zero
`work_eat`, and **zero `WB_medical`** — **the medical complex has never been in the running game
either.** The Arbiter's `:912` finding is confirmed correct; `:1104` is confirmed still stale.

**THE HIGHEST-VALUE MEASUREMENT NOBODY HAS TAKEN (Level/World):** GLB work markers carry Blender's
**dot** suffix (`work_rest.001`), but `site_planner.gd:905-909` strips only `_<int>`. If Godot's
importer preserves the dot, **~185 of 198 markers silently degrade to `off_duty`** — meaning the
aid-station seed (`:969-978`, needs ≥2 `medic`) and the litter team have **never fired in the
history of this project.** Run `test_firebase_garrison.tscn` and print the occupation histogram
**before** re-exporting anything.

**And a trap:** exporting the chow hall as-is silently steals garrison men — +40 unknown `work_*`
types enter the fixed 23-man round-robin (`site_planner.gd:936`, `:992-1008`) as `off_duty` statues
on the mess benches.

---

## 9. MULTI-PAD: BUILT IN CODE, ABSENT IN THE WORLD — TWO INDEPENDENT MEASUREMENTS AGREE

- **Game Designer:** `_free_pad` already walks all pads, capacity 1 each (`air_traffic.gd:467-515`);
  only the *scheduling* is single. But **no code starts a heli on a pad** — every `lz_cycle` begins
  airborne ~280m out (`:536-540`). His "birds lifting off as he turns the corner" needs a
  launch-from-pad path that does not exist.
- **Level/World, measured:** the shipped GLB has **ONE pad placement** (`gen_firebase_v3.py:1070`).
- **Technical Director, measured:** all three pad-prefix nodes sit at the **identical position**
  (22.18, 4.01, −41.29). `air_traffic.gd:54`'s "three PSP pads" comment is **drift**.
  `_free_pad()` would land three birds on one square metre.

**Price (Technical Director):** Huey = **27 draw calls**; Chinook = **84 calls / 12,028 tris**;
baseline ~1,350 calls where 1,000 calls ≈ 6 FPS (`PERF_LEDGER.md:686,700`). **Real bug found:**
`_dispatch` checks the ceiling once before the lead (`:328`) then adds 8 wingmen unchecked
(`:343-349`) — up to 22 airframes, +44% calls.

**And the rescope's true frame cost is daylight, not men:** `air_traffic.gd:93-108` books hours
6–23, so a day demo fires **~39 transit bookings + all 4 LZ cycles vs today's ~18/1** — 2.2× the
air, landing exactly where the combat-load gate is clear.

---

## 10. ALLY AI (question H): THE ARBITER'S FIVE POINTERS HOLD — AND THE GAP IS NOT WHERE HE LOOKED

The AI Architect re-confirmed all five of the Arbiter's verified pointers, then answered the three
open questions:

1. **NO MEDIC — and worse, there is no wounded ally.** `ally_base.gd:1485-1487` goes straight from
   HP≤0 to `_die()`; no downed state (its own docstring, `:41-42`). The medic's only revive path is
   the PLAYER (`squad_system.gd:99-102`, `:313-348`). **Meanwhile the ENEMY has `is_downed`, a
   `downed_pool`, and medics who drag men out (`enemy_base.gd:2489-2570`).**
   **The VC recover their wounded; your squad cannot be wounded.** For a Summoner who just elevated
   squad survivability to pillar level, this is the finding.
2. **MOS is read NOWHERE in the AI.** One hit across `scripts/allies` + `scripts/ai`, and it is a
   comment (`ally_base.gd:166`). Courage is a flat `randf()` (`:296`) — so the RTO rolls go-getter
   ~25% of the time and skips cover (`:109`).
3. **COVER ONLY, NEVER CONCEALMENT.** `_find_cover_point` accepts a spot only if a physics ray is
   BLOCKED (`ally_base.gd:1298-1303`). Grass/fern/bush/rice have **no collider by contract**
   (`tree_cover_layer.gd:17-19`). **Yet the sim already rewards the grass** — vegetation cuts sight
   (`sight_cap.gd:32-39`) and heavy jungle blocks LOS 30%/cell (`gameplay_grid.gd:406-411`).
   **The AI simply cannot see a reward the simulation is already paying.** One O(1) grid read is
   the entire gap.
   *Bonus defect:* trunk colliders exist only within 70m of the **player**
   (`tree_cover_layer.gd:34-43`) — allies further out have zero cover at all.

**THE VIETCONG INSIGHT, answered:** verbs owned today — trap-spot (POINT), call-for-fire (RTO),
player-revive + bandages (MEDIC), sustained fire (MG), cluster thumper (GRENADIER). **Four of the
five are AUTOMATIC.** Only the radio is spendable, so only its loss is felt. MARKSMAN has a weapon
and a body but is absent from `MOS_ORDER` (`squad_roster.gd:64`) — **it never spawns.**

**New defect nobody was looking for:** allies never pass `squad_broken`/`force_ratio` to the shared
scorer (`ally_base.gd:782-801`); the enemy does (`enemy_base.gd:1408-1409`). The squad-break toast
is a cheque the AI does not cash. **~2 lines.**

**Scope correction: the squad is 8, not 5** (`squad_system.gd:19`). The briefing was wrong.

---

## 11. CONVERGENT, FROM TWO DIRECTIONS: THE RTO QUESTION IS ALREADY ANSWERED BY THE CODE

Caleb's stated-open extension — *"if the RTO MAN goes down, do the calls stop?"* — is not open.

- **AI Architect:** `_radio_check` needs a living RTO within 10m (`field_director.gd:654-663`,
  `:323`) and kicks the player off the net that frame (`:257-268`).
- **Systems Designer, independently:** `member_by_mos` skips dead men (`squad_system.gd:168`) →
  `_radio_check` (`:657-660`) gates arm/request/supply. And **allies have no downed state**, so
  "goes down" and "dies" are the same event.

**The calls already stop, totally and permanently.** What Caleb must actually rule is different,
and the Systems Designer framed it correctly: with 3 calls, no save, and no replacement, RTO death
is **deletion, not degradation** — which is Pillar 5's problem, not a feature. His proposal: allow
the handset to be picked up off the corpse (`ally_base.gd:1547-1549`) with the forward-observer
accuracy factor dropped to 0, so the punishment is a **wide, sloppy sheaf** instead of silence.
**Sacrifice named:** this costs ADR-011's "the radio is a man" — the RTO becomes a quality
multiplier rather than a hard gate.

---

## 12. THE PLAYER'S FAIL-FORWARD EXISTS — AND CONTRADICTS ITSELF

**Devil's Advocate:** the downed-player path is real and complete (`squad_system.gd:224-345`,
`health_system.gd:248-286`, 6 bandages `:10`). Two contradictions instead:

1. **`revive()` restores FULL HP** (`health_system.gd:276-278`) — his own 7/18 decree — versus his
   8/3 ruling that you "come back degraded." **His tie to break.**
2. **The headshot bypasses the revive window entirely** (`:203-208`). One round at minute 22 costs
   22 minutes, and the only button is `reload_current_scene()` (`:362`). **In a no-save 30-minute
   demo that is the sadism simulator Pillar 5 forbids.** Recommended: a one-per-run helmet save.

This second item is the Arbiter's chief concern in the whole rescope. Ruling 6 (no save) and ruling
7 (fail forward) are individually sound and collide at exactly one code path.

---

## 13. THE THINGS THAT TURN OUT TO BE FREE

Reported so the council does not spend a day building what is already built (the Arbiter's standing
warning: the backlog has claimed shipped items were open).

- **The destructible tunnel mouth is ALREADY SHIPPED. Zero engineering cost.** HOLD-interact
  satchel, grenadier-skill hold time, blast, nav re-bake, cross-patrol permanence:
  `player.gd:838-891`, `campaign_state.gd:478-490`, consumed `site_planner.gd:195-202`. **Both
  stampers already place one** (`:258`, `:1632`). Only non-code costs remain: confirm the demo
  loadout carries a satchel (`player.gd:843`), and discoverability.
- **Civilians and "being seen" EXIST.** `civilian.gd` is 38 KB with behaviour trees, SimClock
  schedules and households. The informer path is real
  (`civilian.gd:582-594` → `field_director.gd:627-641`). **The only gap is that it is a coin flip**
  — `mission_generator.gd:979` gives the demo village a ~50% chance of an informer at all.
- **The enemy camp stamper is built** (`site_planner.gd:1629`, dispatch `:761`); the demo just
  disables camps (`mission_generator.gd:740-741`). **A plan edit, not new content.**
- **Multi-pad allocation is built** (`air_traffic.gd:467-515`) — the pads are not.
- **The backlog is HONEST: 0 false claims in 5 spot-checks** (Devil's Advocate) — but it **stops at
  7/31**, so every estimate drawn from it **under**-counts.

---

## 14. THE ONE PROPOSAL THE ARBITER MUST RULE ON: THE DEVIL'S COUNTER-OFFER

The Devil's Advocate priced the rescope at **~8–9 agent-days + 3 Blender sessions** and called it
**a new game mode wearing the demo's name**, with the night siege at ~15% of it — against a date
Caleb set while looking at a different object.

**His counter-proposal: ship the DUSK PATROL, ~18 minutes.** One sortie, one village, the one
lighting transition the engine actually renders, stand-to, attack. Sacrificed: the chow hall's
demo debut, the enemy camp, the full day, and 12 minutes of runtime.

**Caleb ruled 30 minutes and a full day. Law 3: the Summoner holds final authority.** The Arbiter
does not overturn it — but the Devil has earned the right to have it put to him in plain words,
because the reason he ruled 30 minutes (his first game averaged 30 and players came back) is a
statement about *runtime*, and the Devil's objection is about *lighting*. Those can both be
satisfied. See the synthesis §2.
