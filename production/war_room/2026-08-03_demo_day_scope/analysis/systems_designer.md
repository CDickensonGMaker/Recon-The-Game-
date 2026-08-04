# SYSTEMS DESIGNER — the arithmetic that connects day to night

**War Room:** 2026-08-03 demo day rescope · **Lens:** the economy · **Law 2 binds:** every
recommendation names what it sacrifices.

Everything below was read out of code today. Where I could not measure, I say so and specify the
measurement.

---

## 0. THE HEADLINE — the briefing's premise on (D) is inverted, and the real defect is elsewhere

Three findings, in order of how much they change the plan:

1. **`field_mult` does not soften the second half. It hardens it.** It multiplies the hunter *period*,
   not the hunter *count* (`field_director.gd:148`). A lower multiplier means a SHORTER wait means MORE
   hunters. The briefing read it backwards.
2. **In the proposed shape, `field_mult` never executes at all.** Its clock is
   `state.elapsed_seconds()` (`:132`), and `state` is thrown away and rebuilt with a fresh
   `start_time_ms` on every inbound wire crossing (`:1584`, `:1587`). A day arc with a midday return
   through the chow hall resets it. Neither half reaches 15 minutes. The branch is dead code in demo
   scope.
3. **The thing that actually empties the second half is the POOL, and no multiplier can touch it.**
   12 men (`:106`), 2–4 spent per wave (`:149`), so ~4 waves. First at 70–110 s after contact
   (`:118`), then 100–160 s (`:148`). **Total ≈ 70 + 3×130 ≈ 460 s ≈ 7.7 minutes of contact time
   before the AO is out of hunters forever.** In a 23-minute day, the morning eats the whole net and
   the afternoon sortie walks through an empty jungle. That is the backwards arc — not the decay.

---

## (D) THE `field_mult` DECAY — LEAVE IT. Fix the pool instead.

### What the code actually does

```
field_director.gd:130-133   field_mult = clampf(1.0 - (mins - 15.0) * 0.02, 0.6, 1.0)
field_director.gd:148       _hunter_timer = randf_range(100.0, 160.0) * field_mult
```

`field_mult` is a coefficient on the **respawn interval**. At 1.0 the next wave is 100–160 s out. At
the 0.6 floor it is **60–96 s** out. **Lower multiplier = faster waves = more pressure.** The comment
at `:129` ("the longer you are in the field, the harder the AO leans on you") is correct and the
briefing's reading of it is not. Nothing needs inverting.

### Why it is unreachable anyway

`mins` comes from `state.elapsed_seconds()` (`mission_state.gd:132-133`), measured from
`state.start_time_ms`. `_bank_patrol` replaces the whole object:

```
field_director.gd:1584   state = MissionState.new()
field_director.gd:1587   state.start_time_ms = Time.get_ticks_msec()
```

`_bank_patrol` fires on every inbound crossing of `WIRE_RETURN_M` (95 m, `:1223-1225`). The Arbiter's
beat sheet has the player return through the wire at midday for the chow hall. **That return zeroes
the escalation clock.** Morning excursion ≈ 10 min, afternoon ≈ 10 min: `mins` never exceeds 15 in
either, `field_mult` is pinned at 1.0, and the `-2%/min` line never runs.

Note what survives the bank and what does not, because the asymmetry is load-bearing:

| Survives `_bank_patrol` | Reset by `_bank_patrol` |
|---|---|
| `_hunter_pool` (`:106`) | `state.kills` (`:6` in mission_state) |
| `_escalation_active` (`:104`) | `state.elapsed_seconds()` (`:1587`) |
| `_hunter_timer` (`:105`) | `contacts_detected` / `contacts_avoided` |
| `evidence` ledger (`:109`) | `waypoints_reached`, `ground_covered` |

**This table is the single most important thing in this analysis for anyone designing the day→night
link.** Any arithmetic that reads `state.kills` to price the night is silently wiped by the chow-hall
return.

### RULING

**LEAVE `field_mult` alone.** Do not invert it (it is already pointed the right way), do not flatten
it (flattening a branch that never runs is churn), and do not delete it this session (it is a
genuinely live feature for the full game's multi-hour patrols — it is only unreachable in the
30-minute demo shape). Log it in the fossil register as *unreachable-in-demo, live-in-campaign*
rather than deleting it.

**Fix the pool instead. Minimal change: top the pool up on the outbound wire crossing, not once at
boot.** `_grant_fire_support` already demonstrates the exact seam — `_poll_wire_gate` calls it on the
outbound crossing at `:1221`. Add a pool grant on the same line:

- morning walk-out: pool = 6
- afternoon walk-out: pool = 6 (top-up, not add — a morning the player spent quietly does not stack)

Same 12-body total budget as today (`:106`), same "you can bleed the AO dry" promise within an
excursion, but the afternoon is no longer pre-emptied by the morning.

**SACRIFICED:** the promise at `:103` — *"Finite pool - you can bleed the AO dry"* — becomes finite
*per excursion* rather than finite *per operation*. A player who wipes the morning net and walks back
in has not permanently quieted the AO, and that is a real reduction in the weight of a hard morning.
ADR-035's finite-pool statement (`ADR-035-the-route-the-pencil-and-the-hunters.md:83`) needs an
amendment line saying the pool is per-excursion, or the doc drifts the moment this ships.

**Also sacrificed if you do nothing:** the afternoon sortie to the enemy camp — the second half of
his 23-minute day — is an unopposed walk. That is the cost of leaving the pool at a single 12.

### One live bug found in this function

```
field_director.gd:139-145
    if evidence == null: return
    evidence.prune(now_s)
    var fix := evidence.best_fix(now_s)
    if fix.is_empty(): return        # <- returns WITHOUT resetting _hunter_timer
```

`_hunter_timer` is already ≤ 0 at this point. So when the trail is cold, this re-polls **every frame**
until evidence appears, and then spawns a wave **instantly** — the 100–160 s cadence is skipped
entirely for the first wave after a dry spell. Cheap in CPU (a prune over a short array), but it means
the first shot the player fires after a quiet stretch can put hunters on the map with no delay at all.
Not a demo blocker; worth one line.

---

## (E) DOES THE DAY FEED THE NIGHT — YES. And it should be ONE body budget, not two.

### What exists today

`SIEGE_STRENGTH` is a bare const (`demo_game.gd:48`), consumed once at `:273` →
`_open_siege(SIEGE_STRENGTH, ...)` → `reinforce(strength - run_strength)` at `:306`. Making it dynamic
is a one-line change from `const` to a computed var. The plumbing is already correct: `reinforce`
grows `run_strength` and `run_peak` together (`siege_director.gd:246-247`), which is what makes the
break ratio and `killed_count` mean anything.

### The measurement nobody has taken, and it is worse than the briefing states

`LIVE_CAP` (50, `siege_director.gd:36`) is enforced at `:435-446` and `:421-430` by iterating
**`cells`** — the siege's own MarchingCells. It counts **nothing else**. It does not count the
garrison, and it does not count hunters.

And **hunters are never reaped.** `_process_reap` (`siege_director.gd:712-736`) only walks `_reaping`,
which is populated exclusively from `_break_siege`'s cell teardown (`:696-698`). A hunter spawned by
`field_director.spawn_tracked_enemy` at `:157` enters `_live_enemies` (`:53`) and stays there for the
rest of the operation unless the player kills him.

**Therefore, in the proposed day arc, the worst case at 19:00 is:**

```
12 hunters (all sent, none killed — the QUIET player's reward)
+ ~40 garrison promoted to AllyBase defenders (_garrison_stand_to, :1364-1380)
+ 45 assault
= ~97 simultaneous bodies, governed by a cap that only sees 45 of them
```

**The branch that gives the player the hardest night is also the branch that gives him the worst
frame rate.** That is the collision, and it is sharper than question F states: the quiet, skilful,
"clean day" player is the one who arrives at the night attack with 12 uncleared bodies still standing
in the AO.

### THE ARITHMETIC — fold, do not add

The Arbiter's instinct ("one arithmetic instead of two scenes") is right, but subtraction alone leaves
the bodies on the map. The correct rule is a **fold**:

> **The men you did not kill today are the men in the wire tonight.**

At the dusk stand-to, before `_open_siege`:

```
hunters_sent   = 12 - _hunter_pool                    (field_director.gd:106, :150 — survives the bank)
hunters_alive  = live_enemy_count("hunters")          (field_director.gd:165-172)
hunters_killed = hunters_sent - hunters_alive

night_strength = 45
               - hunters_killed                        (0..12)
               - 8   if the tunnel mouth was destroyed
               + 10  if an informer got clear          (_informer_answered, field_director.gd:330)
night_strength = clampi(night_strength, 28, 45)
```

Then, at stand-to, **despawn every surviving hunter** through `despawn_tracked_enemy`
(`field_director.gd:72-76`) — which is explicitly documented as a withdrawal, not a casualty, and
never fires `died`, so nothing miscounts it as a kill (ADR-035 §4). They are not deleted from the
fiction; they are the men who walked to the assembly area. The assault they walk into is
`night_strength`, and the body count on screen is bounded by the one cap that already exists.

**Why these terms:**

- `_hunter_pool` and `_live_enemies` both survive `_bank_patrol`. `state.kills` does not
  (`:1584`). **Any design that prices the night off `state.kills` is broken by the chow-hall return
  and will silently read near-zero.** This is the trap in this question.
- The clamp ceiling is **45, not 55.** The briefing sketched "seen-and-camp-intact 55", but 55 is
  above the number `demo_game.gd:44-47` documents as the largest where every man the roll describes
  actually reaches the wire (the 2026-07-28 trickle failure). The `+10` informer term is there so a
  seen day cannot be *reduced* below a clean one, not so it can exceed the authored ceiling.
- Reproduce his sketch: killed 6 + blew the mouth = 45−6−8 = **31** (his "clean day 35" band).
  Touched nothing = **45**. Seen, informer clear, camp intact = 45+10 clamped = **45** (his "55"
  intent, delivered as the ceiling rather than above it).

### LEGIBILITY — r4bk, two surfaces, both already built

An invisible consequence is no consequence, and neither surface needs new HUD (ADR-030 deferral
respected — both are the existing `toast` signal, `field_director.gd:7`, and the existing end card):

1. **At the last inbound gate crossing (dusk).** Hook `_bank_patrol` (`:1564`), which already emits a
   patrol summary at `:1578`. One RTO line, plain: `S2: THAT'S ELEVEN LESS OF THEM THAN THIS MORNING`
   or `S2: THEY'RE STILL OUT THERE IN STRENGTH — SIX WANTS EVERYONE ON THE WIRE`. This is the *only*
   moment the link can be stated before it is spent.
2. **On the end card.** `_show_end_card` (`demo_game.gd:331`) already carries the named men. Add one
   line: `THEY CAME WITH 31. YOU'D PUT 14 IN THE GROUND BEFORE DARK.` Two numbers, no acronyms.

**If you cannot ship both lines, do not build the link.** A silent difficulty modifier in a 30-minute
demo with no save reads as inconsistent balance, not as consequence.

**SACRIFICED:**

- **Pillar 3 takes a real hit for the demo's duration.** Once a player learns the link, the daylight
  becomes farmable and the loud strategy dominates: kill hunters → easier night. "Stealth is an
  economy, never a gate" survives in letter, but the economy now has a dominant loud branch. The
  partial counter is structural — the pool only sends hunters when there is *evidence*
  (`:139-145`, `evidence_ledger.gd`), and evidence is what the player left by being loud, so farming
  requires exposure. But the trade is real and should be named to him, not smoothed over.
- **The "clean day" player is punished by the fold in a way he cannot see.** Under the fold, 12
  unkilled hunters become 12 of the 45. Under pure subtraction he would face 45 *plus* 12. The fold is
  strictly kinder and strictly cheaper on frames — but it means a genuinely stealthy day produces the
  *maximum* night, and there is no daylight route to an easy night except violence. That is a
  defensible design (it is the Vietcong bar) but it is a design *decision*, not a neutral fix.
- **Determinism.** `SIEGE_STRENGTH` stops being a const, so the demo's night is no longer identical
  between boots. `demo_game.gd:7-10` already declares that ambient positioners roll their own RNG, so
  this is inside the existing honesty statement — but the *arc* was seed-fixed and now is not. Update
  that header comment in the same change or it becomes drift (this file's own law).

---

## (G) THE PROACTIVE GAP — YES to one ambient cell, with three hard constraints

### The gap is real and it is exactly where the 5-minute rule bites

`_check_detection` (`:113-119`) arms on `EnemyBase.last_combat_contact_ms > _detect_baseline_ms`.
`_process_escalation` returns immediately while `_escalation_active` is false (`:124`). Nothing in
`FieldDirector` can put a man near the player before the first combat contact. The 4-minute walk to
the village is guaranteed empty of threat.

### Does the evidence/lead system work before first contact? — PARTLY, and the answer matters

**Noise recording is live from boot.** `NoiseBus.noise_emitted` is connected in `setup` (`:27-28`),
and `_on_noise_evidence` (`:35-37`) records every player-team GUNSHOT/EXPLOSION with **no
`_escalation_active` guard**. So by the time contact arms, a ledger already exists — the net does not
start cold.

**But with no player noise there is no lead and nobody is sent** (`:143-145`, and
`evidence_ledger.gd:58-59` discards all non-team-0 noise). ADR-035 states this deliberately
(`:81` — "No evidence, no lead, nobody sent"). So on a silent walk-out the hunt net is *structurally
incapable* of producing a threat, no matter what you do to the multiplier or the pool.

**Conclusion: the ambient cell is not an optimisation of the hunt net. It is the only mechanism that
can threaten a quiet player in the first five minutes.** It must find him by its own perception
(ADR-005 witness rule), and that is exactly right — the beacon stays earned.

### RULING: ship it. One cell, 4 men, on a road. Three constraints, all hard.

**1. The road must never pass within 90 m of `fsb_center`.** `_poll_firebase_threat` (`:1318-1331`)
counts *any* entry in `_live_enemies` inside `FSB_THREAT_M` (90 m, `:956`) and stands the garrison to
at `FSB_THREAT_MEN` = 2 (`:957`, `:1328`). A 4-man cell drifting inside 90 m at 07:05 promotes ~40
Civilians to AllyBase defenders (`_garrison_stand_to`, `:1364-1380`), which destroys the day's arc,
burns the stand-to beat that the night attack needs, and doubles the daytime body cost. **This is not
a tuning preference — it is a hard geometric constraint on the road, and it must be measured against
the actual `fsb_center`, not eyeballed on the Blender layout.**

**2. `last_combat_contact_ms` is a GLOBAL static, not a player-detection flag.**
`enemy_base.gd:272`, stamped in `_stamp_contact` at `:1152`, which fires from `_set_tier(COMBAT,
witnessed=true)` at `:1162-1164` and from corpse discovery at `:1032`. It means *"some enemy somewhere
went loud"* — not *"an enemy saw the player."* If the ambient cell trades shots with an ally patrol, a
convoy, or a friendly element, `_check_detection` arms and toasts **"YOU'VE BEEN MADE - THEY'RE MOVING
TO CONTACT"** while the player is a kilometre away and has been seen by nobody. The net then finds no
lead (no player noise → `:143-145` returns) and **nothing happens**. A dramatic lie followed by
silence. Today nothing else on the map goes loud before the player does, which is why this has never
been seen; the ambient cell is precisely the thing that exposes it. **Cheapest fix: gate the toast on
`evidence.total_strength(now) > 0.0` (`evidence_ledger.gd:102-106`).**

**3. Fold it into the night by (E)'s rule.** Tag it `"hunters"` so
`live_enemy_count("hunters")` (`:165-172`) sees it, and it is despawned/credited at stand-to like any
other survivor. Otherwise 4 more permanent unreaped bodies ride into the assault frame budget.

### What it costs

- **Frame cost: negligible in daylight, and that is the whole point of the timing.** 4 men on a 512 m
  map at 07:00, when neither the garrison stand-to nor the assault is up. The measured 48 FPS
  (PERF_LEDGER, W7 A/B) is a *mid-siege* number; the daylight budget is not the constrained one.
  Constraint 3 keeps it from becoming a night cost.
- **AAR cost, small and worth naming.** `spawn_tracked_enemy` calls `state.register_group` (`:56`)
  unconditionally. A cell the player never sees scores as a **contact avoided** (ADR-006's +25) purely
  for having existed. Free points for a group that was never a threat. Acceptable in a demo with the
  debrief excluded (`demo_game.gd:20`), but it is a real distortion the moment the AAR returns.

**SACRIFICED:** the AO's opening is no longer purely reactive, and a genuinely careful player can now
be found in the first five minutes through no error of his own — the cell walks a road and looks where
it looks. That is a deliberate reduction in the "quiet is always safe" contract, and it is the price
of the 5-minute rule. It is also a **determinism** cost: the cell's route/perception rolls are the
kind of ambient RNG `demo_game.gd:7-10` already declares, so it stays inside the existing honesty
statement, but the *first five minutes* stop being reproducible boot to boot.

---

## THE 3 RTO FIRE MISSIONS — verified in code. The number matches nothing that ships today.

### The two budgets that actually exist

**A. The class default** — `field_director.gd:304-305`:

```gdscript
var fire_support: Dictionary = {"bombs": 0, "napalm": 0, "arty": 0, "mortar": 2,
    "spectre": 0, "cbu": 0, "illum": 2}
```

**This is what today's shipped demo runs on**, because `_grant_fire_support` fires only from
`_poll_wire_gate` on the outbound crossing (`:1207-1221`) and the current demo never sends the player
out the gate — `demo_game.gd` contains no reference to `fire_support`, `_grant_fire_support`,
`patrol_out` or `setup_patrol` (grepped; zero hits). **Today the player has 2 mortar missions and 2
illum, and nothing else.**

**B. The live grant** — `_grant_fire_support`, `field_director.gd:1251-1255`:

```gdscript
fire_support = {
    "bombs": 1, "napalm": 0, "arty": 1,
    "mortar": 3 + (1 if fo >= 6 else 0), "spectre": 0, "cbu": 0,
    "illum": 2 + (1 if fo >= 4 else 0),
}
if tier in ["HIGH", "CRITICAL"]: napalm = 1; cbu = 1
if tier == "CRITICAL":           spectre = 1
```

At LOW/MODERATE that is **5 offensive calls** (1 bombs + 1 arty + 3 mortar) plus 2–3 illum. At HIGH,
**7**. At CRITICAL, **8**.

**So "3 RTO fire missions" is neither the shipped default (2) nor the granted allotment (5–8).** It is
a new number and it needs to be authored somewhere. To hit exactly three, my recommendation is
**three different verbs, not three of one**:

```
{"bombs": 1, "arty": 1, "mortar": 1, "illum": 2}
```

His stated intent — *"first one you gotta assume most players will just do it to do it... then they
will use the other two wisely"* — only produces a real decision if spending the wrong one *hurts*.
Three mortar missions are interchangeable; a bomb, a battery and a tube are not, and burning the
bombs on nothing at 07:30 is a decision the player feels at 19:30.

Illum stays at 2 and stays **outside** the count of three: it does no damage
(`_run_illum_mission`, `:754-757`), and `siege_director.gd:79-86` states plainly that the lit ground is
the scoreboard of the night attack. Charging it against the three would make the demo's climax dark.

### Three defects in this area, all live, all cheap

**1. Illum has no row in the fire menu.** `mission_hud.gd:97-104` lists rows for bombs/napalm/arty/
mortar/spectre/cbu. **There is no illum row.** Key 7 is bound (`field_director.gd:243-244`), the
allotment is granted (`:1254`), and nothing on screen ever tells the player it exists. In a demo whose
climax is a night assault crossing 300–500 m against 56 m night sight, **the single most important
strategic verb is invisible.** Straight r4bk violation. One row.

**2. The one-allotment-per-day latch becomes reachable in the new arc.** `_granted_day` (`:1243-1245`)
is keyed to `SimClock.sim_day`. The current demo runs 17:30 → ~06:20 and crosses midnight, but the
player never crosses the wire gate, so it never matters. **A 0700 → post-midnight arc crosses the day
boundary with a player who has been through the gate twice.** The gate band is 120 m out / 95 m in
(`:953-954`) and the comment at `:1240-1242` says explicitly that the wire fight happens inside that
band. **A player who steps 120 m outside the wire after midnight re-arms a full fresh allotment
mid-siege.** The three-call economy is void the moment he does. Latch it on the demo host, or key the
grant to the excursion rather than the sim day.

**3. `p["fire_support"]` in the plan dict is a fossil.** `mission_generator.gd:509` and `:675` both
set `"fire_support": {"mortar": 1}`. **Nothing reads it** — a repo-wide grep for `fire_support`
outside `field_director.gd` and `mission_generator.gd` finds only `field_director`'s own member,
bench/test writes, and `mission_hud.gd:96`. ADR-011's evidence section cites
`mission_generator.gd:103, 132, 153, 236, 248, 261-263` and `mission_director.gd:219/263-264/279/
379-380` — **a file that no longer exists and line numbers that have all moved.** Under the pointer
law, ADR-011 needs a correction pass and these two dict entries need triage (FOSSIL, delete) before
someone "fixes" the budget by editing a line that has never been read.

---

## THE OPEN EXTENSION — "if the RTO man goes down, do the calls stop?"

**They already do. This is not an open question; it is shipped behaviour, and it is total.**

- `squad_system.gd:166-170` — `member_by_mos` skips any member where `a.is_dead()`. A dead RTO returns
  `null`.
- `field_director.gd:657-660` — `_radio_check` returns `"NO RADIO - YOUR RADIO MAN IS DOWN"` on null.
- Every path runs it, in the same order, with no bypass: `arm_fire_mission` (`:345`),
  `request_fire_support` (`:447` — which the `[Y]` mortar and `[O]` shortcuts route through),
  `request_supply_drop` (`:849`).
- `field_director.gd:261-266` kicks him off an open net **the same frame** the RTO dies, with its own
  toast: `"THE RADIO'S DEAD - YOU'VE LOST THE NET"`.
- `_radio_vo` (`:668-673`) goes silent too — the VO is positional off the RTO's back.

**And it is permanent.** Allies have no downed state — `ally_base.gd:41` says so outright ("Allies have
no alert tier or downed state"), and `is_dead()` (`:1552-1553`) tests `AIState.DEAD` with nothing in
between. The medic revive chain (`squad_system.gd:292-320`) drives the **player's** `HealthSystem`, not
an ally's. There is no route by which a dead RTO comes back.

### RULING for the demo, and the amendment I recommend

**Answer him: yes, the calls stop, and they already stopped — you do not need to decide anything to
get that behaviour.** What he actually needs to rule on is whether that outcome is *survivable in a
30-minute no-save demo*, and my read is that as it stands it is not:

- 3 calls total, no save (briefing §0.6), no replacement RTO, and a 10 m leash
  (`RTO_RADIO_RANGE = 10.0`, `:323`) that requires the player to keep one specific man alive and
  *adjacent* through a village fight, an afternoon sortie, and a 45-man night assault.
- Losing him at 08:00 deletes a headline feature for 22 of the demo's 30 minutes, with the demo's
  entire fire-support pillar (ADR-011) never seen by that player.
- ADR-011's own cost section (`:62`, `:92`) already names losing the RTO as a Pillar-5 *degradation*.
  In this demo it is not a degradation, it is a deletion — and Pillar 5 says escalation, not
  fail-states.

**Recommended ADR-011 amendment: the RADIO is an object as well as a man.** Let the player take the
PRC-25 off a dead RTO's back — the kit-on-the-ground window already exists (`ally_base.gd:1547-1549`,
`ally_corpses` group, 45 s). Carrying it himself:

- restores the calls, so the demo's fire-support pillar survives one bad minute;
- costs him a slot and the 10 m leash's *social* meaning;
- and drops `fo_fac` to 0 — which already has teeth everywhere:
  `_cas_cooldown = max(10, 25 - 2×fo)` (`:480`), `FirePlan.sheaf_scale(fo)` widens the sheaf (`:495`,
  `:724`), the veteran's 4th mortar round is lost (`:725`), and the extra tube/illum at `fo>=6`/`fo>=4`
  are gone (`:1253-1254`). **The scatter alone is the punishment** — a green radioman's barrage walks
  wide, and he will see it.

**SACRIFICED, and this one is a Pillar-4 cost the Arbiter must weigh:** the 10 m leash is the mechanic
that makes the radio *a man you protect* rather than a menu. Letting the player pick up the handset
turns the RTO from a **gate** into a **quality multiplier**. ADR-011's core statement — *"the radio is
a man"* (`:30`) — is weakened, and the briefing's own Vietcong insight (each squad member is a
CAPABILITY, losing one costs you a VERB) is exactly what this softens. The honest alternative is to
leave it hard and accept that some demo players lose fire support at minute eight.

**My recommendation is the pickup, because "no save + 30 minutes + the feature is gone" is a
punishment, not a retry** — which is the same reasoning the briefing already used to rule death during
the day fail-forward (§0.7). But it is his call, and it should be put to him in exactly those terms.

---

## SUMMARY OF SACRIFICES (Law 2, collected)

| Recommendation | What is sacrificed |
|---|---|
| Leave `field_mult`, split the pool per excursion | ADR-035's finite-pool promise weakens to per-excursion; a hard morning no longer permanently quiets the AO. ADR-035 needs an amendment line. |
| Fold hunters into `SIEGE_STRENGTH` | Pillar 3: daylight becomes farmable, the loud branch dominates for 30 minutes. The clean/stealthy day yields the *hardest* night with no non-violent route to an easier one. The arc stops being seed-reproducible. |
| One ambient cell at boot | "Quiet is always safe" is reduced by design; the first five minutes stop being deterministic; an unseen cell scores free AAR points via `register_group` (`:56`). |
| 3 calls as 3 different verbs | Power fantasy: no spamming one tube. A player who wastes the bombs early has 22 minutes of regret and no way to earn it back. |
| RTO handset pickup | ADR-011's "the radio is a man" and Pillar 4's capability-not-gun statement both soften; the RTO becomes a quality multiplier rather than a hard gate. |
| Doing none of the above | The afternoon sortie is an unopposed walk, the night is a fixed 45 regardless of the day, and the day/night link the whole rescope is built on does not exist. |

---

## MEASUREMENTS I COULD NOT TAKE — specified, not guessed

**M1 — the real simultaneous body count at dusk.** Nobody has run live hunters + garrison + assault
together, and `LIVE_CAP` provably does not govern the first two (`siege_director.gd:435-446` iterates
`cells` only). Specify:

```
godot --path . res://scenes/levels/demo_game.tscn --print-fps
```
with the day arc wired, and read three counters at the stand-to frame:
1. `director.live_enemy_count("hunters")` (`field_director.gd:165-172`)
2. `get_tree().get_nodes_in_group("garrison_promoted").size()` (populated by
   `GarrisonDefender.promote`, `:1373`)
3. `siege.live_strength()` and the `[Siege] cell of %d held at the ring` line (`:445-446`) — if that
   line never prints while total bodies exceed 50, the cap is not doing what its name implies.

Run twice: once with the hunter fold from (E) applied, once without. **The delta between those two
runs is the frame-rate price of the day→night link**, and it is the number that decides whether the
fold is mandatory or merely tidy. My read of the code says it is mandatory, but that is an inference
from `_process_reap`'s scope (`:712-716`), not a measurement.

**M2 — the day-boundary re-arm.** Boot the day arc, let `SimClock` cross midnight, walk 120 m outside
the wire, and check whether `fire_support` refills. `_granted_day` (`:1243`) says it will. One minute
to falsify, and it voids the entire three-call economy if true.
