# AI Systems Architect — "react like men, not bots"

**War Room 2026-08-12 · analysis only · every claim carries a `file:line` (POINTER LAW).**
**Summoner's framing (mid-session ruling):** *"i want modern ai thinking with our units with our
old school feeling game"* + *"for both enemies and allies"*. So: contemporary decision quality,
PSX presentation. Everything below is ranked by whether it reads through **silhouette, position,
timing, sound and decision-making** — the channels that survive low-poly.

**Verdict up front.** The enemy brain is genuinely modern in its *goal* layer and genuinely
bot-like in its *perception and body* layer. The ally brain is a decade behind the enemy brain on
perception, and that gap — not the enemy AI — is the loudest thing in a firefight, because the
squad is the thing the player stares at for thirty minutes (Pillar 4).

---

## 0 · What is already excellent (do not rebuild)

Naming these first so nobody "fixes" them.

| System | Pointer | Why it is already modern |
|---|---|---|
| Shared goal scorer | `scripts/ai/combat_goals.gd:68-155` | Nine-verb scored brain, FEAR doctrine (`:74`), open-ground discipline (`:129-132`), numbers-weighted retreat (`:152`), incumbent hysteresis (`:160-173`). Both factions run it. |
| Honest attention | `enemy_base.gd:1298-1307` | No player bias, `_last_attacker` x2.5, crowded-target discount, ghost decay. This is Arma-grade target selection. |
| Exposure ramp / first-shot mercy | `ai_marksmanship.gd:74-96`, `enemy_base.gd:2237` | First burst genuinely goes wide, cone *breathes* with the ramp (`:90`), warning crack 5-9° (`:54-60`). |
| Contact-confidence debounce | `enemy_base.gd:1391-1398` | Goals read `contact_conf`, never raw LOS. Correct architecture. |
| Bounding advance | `enemy_base.gd:1867-1928` | Real rush-pause-burst, throttled ray budget, two-dry-search fallback. |
| Break ladder + surrender | `enemy_base.gd:2501-2523` | Courage-powered rout, Chieu Hoi, nerve stiffened by local numbers. |
| Witness rule / evidence | `enemy_base.gd:1031-1130`, ADR-005 | Imperfect information is *designed in*, not bolted on. |
| Sentry gaze sweep | `enemy_base.gd:1680-1686` | ±140° scan, phase-desynced at `:345`. Enemies do look around. |

---

## 1 · Reaction time and target acquisition

### 1a. The enemy reaction gate is 0.3–0.375 s. That is a bot.
`enemy_base.gd:1718-1724`:
```
var required_reaction: float = BASE_REACTION_TIME * (2.0 - char_reaction)
```
`BASE_REACTION_TIME = 0.25` (`:245`), `char_reaction` rolls 0.5–0.8 across all three
personalities (`:385/391/397`). So the window is **0.25×(2.0−0.8)=0.30 s to 0.25×(2.0−0.5)=0.375 s**.
A 75 ms spread across the entire enemy population — every man on the map reacts within one
twelfth of a second of every other man. Human simple-reaction is ~0.25 s; *recognise a threat,
decide, mount, fire* is 0.6–1.5 s and varies by a factor of three between individuals.

**Triage: UNFINISHED.** The mechanism is built and wired; the constants are set to bot values.

There *is* a startle path — `_set_tier` grants an extra 0.4–0.7 s when a cold man is jumped
inside 15 m (`:1256-1261`) — but it is gated on `was_cold` **and** `distance < 15.0` **and**
only against `GameManager.player`. A man ambushed at 40 m, or ambushed by an *ally*, gets no
startle at all.

**Triage of the 15 m / player-only gate: UNFINISHED** — the good idea exists with an
artificially narrow trigger.

### 1b. `aim_speed` is documented in radians per second and is not radians per second.
`enemy_base.gd:112` declares `var aim_speed: float = 8.0  # Radians per second`, and
`:1648-1649` spends it as a **lerp weight**:
```
var aim_delta: float = aim_speed * delta
current_aim_dir = current_aim_dir.lerp(target_aim_dir, aim_delta).normalized()
```
Identical at `ally_base.gd:152` + `:1064` (`aim_speed = 7.0`).

That is exponential convergence with time constant `1/aim_speed` ≈ **0.125 s, independent of
angular error**. A man who must swing 170° behind him settles his muzzle in the same 0.3 s as a
man already looking 5° off. **This is the single most visible bot-tell in the game and it reads
purely through silhouette** — exactly the channel the Summoner said survives PSX fidelity. Real
men whip 30°/s of torso and 120°/s of eye, and the difference between "he was already covering
that lane" and "he had to turn around" is the whole texture of an ambush.

**Triage: FOSSIL comment over UNFINISHED code.** The units contract in the comment is a lie
(COMMENT DISCIPLINE / drift). The fix is a genuine slew cap, below.

### 1c. Reaction does not vary by alert tier.
`required_reaction` reads only `char_reaction`. A RELAXED cook at his pot (`camp_role`,
`:143`) and an ALERT man already sweeping his sector pay the identical 0.3 s.
`alert_tier` (`:97`) is never consulted in `_execute_combat`. **MISSING.**

### 1d. Allies have NO reaction gate at all.
`ally_base.gd` contains no `has_reacted`, no `reaction_timer`, no `BASE_REACTION_TIME`. The only
latency is `_aim_settle = randf_range(0.45, 0.9)` (`:772`), set **only when the target changes**
(`:771`). An ally who reacquires the *same* man after a foliage blink pays **zero**.
Asymmetry vs `enemy_base.gd:1718-1724`. **MISSING (ally side).**

---

## 2 · Imperfect information

### 2·0 THE HEADLINE FIND — every enemy shout in the game is a no-op.

`_on_noise_heard` returns immediately when the noise came from our own side
(`enemy_base.gd:1267-1269`):
```
if source_team == 1:  # our own side
    return
```
Every enemy VOICE event is emitted with `source_team = 1`. There are **six** of them, and they
are the game's entire spoken information layer:

| Shout | Site | Radius | Intended meaning |
|---|---|---|---|
| Witness alarm | `enemy_base.gd:1088` | 30 m | "they got Nguyen — over there!" |
| Corpse discovery | `:1123` | 30 m | "there's a body here" |
| Grenade telegraph | `:2329` | 20 m | "LUU DAN!" |
| Pain grunt (solid hit) | `:2467` | 20 m | "I'm hit" |
| Crippled cry | `:2558` | 30 m | "he's down and crawling" |
| Order | `:963` | — | squad direction |

**Not one of them has ever been heard by another enemy.** The only listeners those events reach
are `civilian.gd:329` and `mission_trigger.gd:66`; `evidence_ledger.gd:57-58` discards team≠0.
So a man can scream that he has found a body and the man ten metres away notices nothing.

**Triage: UNFINISHED.** The emitters, the radii, the VO lines and the listener are all built and
correct. One early-return line makes the whole layer inert. This is the "already built, never
fires" of this audit.

**Why it matters for the Summoner's ask:** shouting *is* the modern-AI information channel —
delayed, ranged, lossy, directional, and audible to the player. It is the one propagation
mechanism that reads perfectly at PSX fidelity because it is **sound**, not animation. It exists.
It is switched off.

### 2·0b Meanwhile, the channel that DOES work is instant, perfect and unbounded.
All real enemy→enemy propagation runs through the `EnemySquad` static dictionary.
`_squad_sync` (`enemy_base.gd:1000-1018`) pushes `target.global_position` — the **exact live
transform** — into `EnemySquad.report_contact` (`enemy_squad.gd:244-260`) every think, and
squadmates pull it with **zero delay, zero error and no range limit**. `SHARE_RANGE = 30.0`
(`enemy_squad.gd:8`) is documented as "a spotter wakes squadmates within this" and is **never
used as a propagation filter** — its only reference in the repo is `enemy_base.gd:1017`, and
there as `* 2.0` on a tier gate. **FOSSIL comment over a live unbounded share.**

Worse, `_think_cheap_combat` (`:920-925`) copies `EnemySquad.shared_last_known` verbatim with no
range check at all, so a cold fighter's `last_known_target_pos` tracks the player **live, through
walls, at unlimited range** for as long as any squadmate anywhere has eyes on. He cannot *fire*
(LOS is caller-gated) but he can walk to you and, via `:1783-1788`, lob accurate grenades at a
man he has never seen. **Triage: UNFINISHED (leak).**

Cross-squad propagation is **MISSING** entirely — every `EnemySquad` function early-returns on
`id < 0` (`enemy_squad.gd:176,186,197,206,244,264,272,279`), so a lone wolf shares and receives
nothing and two adjacent squads never exchange a fact.

**The pairing is the whole story: the lossy human channel is switched off and the telepathic one
is unbounded.** Flipping that ratio is the single largest realism lever in the codebase.

### 2·0c What is genuinely good on the information side (do not touch)
The witness heartbeat is real and fires: `_can_witness` is a four-gate check — sight cap, FOV
cone, smoke, physics ray (`enemy_base.gd:1044-1057`) — called unconditionally at the top of
`_think` (`:878-881`), un-tiered by design. `_witness_check` (`:1064-1100`) wakes **exactly one**
witness (`:1089 return`) and banks unwitnessed bodies. `_check_corpse_discovery` (`:1104-1124`)
requires 22 m *and* a full witness check, then re-anchors the squad hunt on the body
(`:1119-1121`). The `EvidenceLedger` scatters fixes deliberately — 55 m on noise, 8 m on bodies
(`evidence_ledger.gd:25-26`) — so hunters spawn onto a *wrong* position and have to search
(`field_director.gd:163-186`). The hunt net genuinely expands and slides down the breadcrumb
heading (`enemy_squad.gd:299-453`). **This is already modern-tier imperfect information.** It is
undermined by 2·0b, not absent.

Two live team-label quirks worth a one-line fix each: `marching_cell.gd:84` emits *enemy*
footsteps as team 0 (friendly cells make real enemies suspicious), and `zpu_gun.gd:248` emits
enemy AA fire as team 0 at 260 m, which writes a player-evidence fix into the ledger and can
single-handedly satisfy the detection gate at `field_director.gd:139`.

### 2a. COMBAT tier = 360° all-round awareness. Omniscience, by construction.
`enemy_base.gd:1021-1028`:
```
RELAXED -> 100.0 ;  SUSPICIOUS/ALERT -> 150.0 ;  _ -> 360.0
```
and `:1172` skips the FOV test entirely once `alert_tier == COMBAT`. So the instant a man goes
loud he can see through the back of his own skull, forever — `_set_tier` never drops below ALERT
again (`:1220` `# never back to RELAXED`). Flanking a man in contact is mechanically impossible
to do *unseen*; only the LOS ray stops him. **This is the loudest information tell.**

Even RELAXED at 100° is generous — human useful-attention is ~60°, and the ±140° gaze sweep
(`:302`) already gives coverage over time, which is the *correct* way to spend it.

**Triage: UNFINISHED** — the tier system is fully built and simply hands out an unearned value at
the top tier.

### 2b. Ally target acquisition has no FOV cone, no awareness accumulator, and no LOS.
`ally_base.gd:739-773` iterates `AgentRegistry.enemies`, filters on `is_dead`, `non_hostile`,
and `SightCap.at()` distance — **and nothing else**. No facing test, no
`CombatManager.has_line_of_sight`, no `awareness` ramp, no `alert_tier`. An ally acquires a man
standing behind a bunker wall directly at his back, instantly, at up to the open sight cap.
Firing is LOS-gated afterwards (`:1001`, `:1338`), so he does not shoot through the wall — but he
*turns to face it*, and `contact_conf` (`:791`) starts filling the moment geometry clears.

Compare the enemy path, which is a full perception model: sight cap by terrain (`:1159`), player
stance modifiers (`:1163-1168`), FOV cone (`:1171-1175`), close-sense bubble (`:1178`), smoke
occlusion (`:1180`), geometry ray + terrain ray (`:1184-1189`), graded awareness gain
(`:1192-1201`).

**This is the largest single asymmetry in the codebase and it is on the faction the player
watches.** **Triage: MISSING (ally side); the enemy implementation is the template.**

### 2c. Ally targeting is "nearest living enemy", full stop.
`ally_base.gd:754` `if dist >= closest_dist: continue`. No `_target_score` equivalent, no
"he is shooting me" weighting, no crowding discount — all of which the enemy has at
`enemy_base.gd:1298-1307`. Six allies in a line will all lock the same nearest man and ignore
the one killing them. **MISSING (ally side).**

### 2d. Awareness accrues on the wrong clock.
`enemy_base.gd:1204/1208` advance `awareness` by `THINK_INTERVAL` (the 0.15 constant) while the
think loop actually runs at `_think_interval_current` (`:784`), which the LOD sets to 0.3 or 0.6
beyond 80 m / 150 m (`:46-52`). Detection therefore runs **2–4× slow at range** and the decay
runs slow too. Mixed-clock bug class; `_update_line_of_sight` got this right (`:1371`,
`:1384-1396`) and `_update_perception` did not. **Triage: UNFINISHED (defect).**

---

## 3 · First-shot accuracy and weapon handling

### 3a. Enemies are right. Allies bypass the entire fairness model.
`ally_base.gd:1674`:
```
final_aim = AIMarksmanship.aim_with_spread(final_aim, pre_cap, _target_is_player(), 1.0, false)
```
`exposure_t` is hardcoded **1.0** and `force_first_miss` is hardcoded **false**. Read against
`ai_marksmanship.gd:74-96`, that means an ally is *permanently converged*: no ramp, no warning
crack, no opening volley that goes wide. The enemy passes real values (`enemy_base.gd:2237`,
`:2242`). The comment at `ai_marksmanship.gd:3-6` claims "ONE spread path … so a mirror match
trends 1:1" — it is one *cone* path, but the two callers feed it opposite fairness terms, so the
mirror does **not** trend 1:1. **Drift in a live comment.**

Note the exposure ramp for AI-vs-AI is dead anyway: `aim_with_spread` only applies
`exposure_spread_mult` on the `is_player_target` branch (`:83-90`). Ally-vs-enemy fights have no
ramp on *either* side. So squad-vs-VC firefights — the thing the player spends the patrol
watching — have **no first-burst looseness at all on either side**. Everyone is zeroed from round
one. **Triage: UNFINISHED** (the mechanism exists; the AI-vs-AI branch was never given it).

### 3b. Neither faction tracks ammunition.
`enemy_base.gd` has no magazine, no reload, no `_reload_timer`; `can_fire`/`fire_timer`/
`burst_count`/`MAX_BURST` (`:285`) are the only cadence model, and the burst rest is
`randf_range(0.4, 1.2)` (`:1777`). Allies the same. Men never run dry, never reload behind cover,
never call for ammo. A reload is a **silhouette + sound + timing** event — the highest-value class
of behaviour under the Summoner's filter — and it is the single most recognisable "this is a
person" beat in any tactical shooter. **Triage: MISSING (both factions).**

### 3c. Suppression degrades enemy *movement* well and enemy *aim* almost not at all.
`_suppression_move_mult` (`enemy_base.gd:1997-2006`) is a proper three-band curve down to 0.05×.
But the aim side is `enemy_base.gd:1744`:
```
accuracy_modifier = base_accuracy_modifier * (1.0 - (1.0 - suppression_level) * 0.2)
```
Read it carefully: at `suppression_level = 0` the multiplier is **0.8** (tighter), at
`suppression_level = 1` it is **1.0**. A fully suppressed man shoots 25% *worse than a calm one*
— that is the whole effect, and it fires only in the mid-range band of `_execute_combat`. A
pinned man's rounds should be going nowhere near you. **Triage: UNFINISHED (inverted/undersized
constant).**

Allies have no `_suppression_move_mult` equivalent at all (covered by the parallel cover/
suppression audit — flagged here only to note it is the same shape of gap).

---

## 4 · Reaction to events other than the player

### 4a. THE BIG ONE — nothing in either AI reacts to a squadmate dying.
`died` is emitted at `enemy_base.gd:2694` / `:2744` and `ally_base.gd:1788`. Repo-wide, every
consumer is **bookkeeping**:

| Consumer | Pointer | What it does |
|---|---|---|
| `field_director.gd:52` → `:96` | mission tally | scoring |
| `squad_system.gd:97` → `_on_member_died` | roster | UI / VO |
| `ai_stress_arena.gd:1857,1882` | probe counters | test harness |
| `gun_range.gd:177,439`, `zombie_wave_director.gd:172` | level scripts | spawning |

**Zero AI subscribers on either side.** The man beside you takes a head hit, gibs
(`GibSystem.dismember_head_burst`, `enemy_base.gd:2487`), and his neighbour's suppression,
morale, goal, posture and gaze are all completely unchanged. He does not flinch, does not look,
does not drop, does not bark.

The witness rule (`_witness_check`, `:1064`) *does* fire on death — but it is an **information**
mechanism (who learns the AO is compromised), not a **behavioural** one. Nobody's nerve moves.

This is the highest-value find in the audit. It is cheap (one signal handler), it costs almost
nothing in CPU (event-driven, not polled), and it reads through every PSX-safe channel at once:
posture drop (silhouette), a scream (sound), a rush to cover (position), a pause in fire
(timing). **Triage: UNFINISHED — the signal exists, wired to everything except the brains.**

### 4b. Grenades are thrown but never feared.
`enemy_base.gd:2324-2353` throws a real `Grenade` with a 1 s windup, a "LUU DAN!" shout, a
`NoiseBus.VOICE` event (`:2329`) and VO (`:2330`). Nothing on the receiving end listens for a
*grenade* — `_on_noise_heard` (`:1267-1280`) treats a VOICE event as generic awareness +0.35 and
walks the man **toward** the noise (`:1274` sets `last_known_target_pos`). So the correct
response to a live frag is currently *investigate it*. Allies have no grenade logic in either
direction — no throw, no dive. **Triage: MISSING (grenade-danger reaction, both sides).**

### 4c. Getting hit: enemies flinch, allies do not.
Enemy `take_damage` is rich — `goal_timer = 99.0` class-A interrupt (`:2413`), trigger stall
(`:2452-2453`), `sprite_actor.flinch()` (`:2456`), pain-quota `apply_stagger` + `_stumble_until_ms`
+ pain grunt over NoiseBus (`:2461-2467`), crippling (`:2425-2430`), rout ladder (`:2501-2523`).
Ally `take_damage` (`ally_base.gd:1751-1762`) records `last_hit_dir` and adds a flat
`suppression_level + 0.3`. **No flinch, no stagger, no stumble, no pain VO, no goal interrupt,
no rout.** An ally soaks rounds like furniture. **MISSING (ally side); enemy is the template.**

### 4d. Flank awareness exists as data and is never spent.
`last_hit_dir` is computed on both sides (`enemy_base.gd:2418`, `ally_base.gd:1751`) and is used
**only to pick a death-fall animation** (`:303` comment; `ally_base.gd:1795-1812`). Nobody asks
"that came from a direction I am not covering". `_last_attacker` (`:1288`) does re-target, which
is most of the value — but the *posture/cover* side never learns its cover is now useless.
**Triage: UNFINISHED (the datum is captured; no behavioural consumer).**

### 4e. Fire.
`scripts/combat/burning.gd` — no AI reads it. A burning man keeps his goal. **MISSING**, low
priority.

---

## 5 · Individual variation — how much behaviour is actually personality-shaped?

Better than the brief feared, and the honest answer is **the goal layer is well-shaped, the body
layer is not shaped at all.**

**Enemies.** `_apply_personality` (`:378-399`) rolls five traits, then `_ready` (`:335-336`) lerps
two of them 60% toward the archetype's `EnemyData`. Live read sites:

| Trait | Read at | Effect |
|---|---|---|
| `char_aggression` | `:1487` → `combat_goals.gd:111,122,129` | ADVANCE/FLANK/ENGAGE weights — **strong, visible** |
| `char_self_preservation` | `:1488` → `combat_goals.gd:90,153` | SEEK_COVER / RETREAT — **strong, visible** |
| `char_accuracy` | `:2239` | cone width — visible only statistically |
| `char_reaction` | `:1721` | 75 ms of total spread — **effectively inert** |
| `aim_speed` | `:1648` | 5–9 as a lerp weight = 0.11–0.20 s settle — **effectively inert** |
| `enemy_data.courage` | `:2503` | break ladder — **strong** |
| `enemy_data.determination` | `:1227-1230` → `:1457`, `:1696` | how long he hunts you — **strong** |

So four of seven genuinely shape behaviour. The two that would make each man *look* different in
the first two seconds of contact — reaction and slew — are exactly the two whose ranges are too
narrow to perceive. Fixing the constants in §1a and §1b converts existing, already-wired
personality into visible character at zero architectural cost.

**Allies.** `courage = randf()` (`ally_base.gd:353`), `effective_courage()` (`:111-112`, steadied
by the player standing close — a nice touch), read at `:833`, `:880-885`, `:1214-1223`,
`:1330`, `:1449`. Roughly the same coverage on the goal side. But allies have **no per-man
accuracy roll, no reaction roll, no aim_speed roll** — `aim_speed` is a flat `7.0` for the whole
squad (`:152`), so every man in the fireteam swings his muzzle in perfect unison. That is a
literal bot-tell, visible in silhouette, in every contact.

---

## 6 · Idle and non-combat

- **Enemy gaze sweep: WIRED and good.** `:1680-1686`, ±140° at 0.7 rad/s, phase-desynced (`:345`).
- **Enemy camp life: WIRED.** `camp_role` / `work_clip` / `work_pos` (`:143-151`), walked to at
  `:1674-1677` and gated on `alert_tier <= SUSPICIOUS`.
- **Ally gaze sweep: MISSING.** `ally_base.gd` has `_micro_idle` positional drift
  (`:1172-1185`) but no gaze sweep at all. Allies stare dead ahead. Since allies also have no FOV
  gate (§2b), the missing sweep costs nothing *functionally* — which is exactly why nobody noticed.
  Wire both together or neither.
- **Weather / night: MISSING** on both sides beyond `SightCap`.
- **Ambient VO: MISSING.** `VOManager` (`scripts/autoload/vo_manager.gd:61-74`) has
  `play_squad`/`play_enemy` and a cooldown gate (`:98`). Enemies bark 9 lines — pain (`:765`,
  `:2715`), retreat (`:977`, `:2523`), contact (`:1087`, `:1122`), grenade (`:2330`), order
  (`:2625`), surrender (`:2858`). Allies bark **only through `squad_system.gd`** (`:243`, `:348`,
  `:491`, `:529`, `:655`, `:678`) — so a garrison ally or a `friendly_patrol_group` man is
  permanently mute. And **neither side has a single idle/ambient line**: no chatter on the march,
  no ammo call, no "moving!" on a bound. Sound is a PSX-proof channel and it is half-empty.

---

## 7 · Perf accounting (ADR-026 is the top systemic risk)

Existing per-think O(n) sweeps that any new work must not multiply:
- `_local_force_ratio` (`:1512-1528`) — walks *all* enemies + *all* allies, every think, every
  man. At 45 men that is ~13 k distance tests/s at full LOD.
- The rout ladder re-walks all enemies inside `take_damage` (`:2510-2514`) — per hit.
- Allies have **no think LOD at all** (`ally_base.gd:659-662` uses the bare `THINK_INTERVAL`),
  unlike `enemy_base.gd:37-52`. A garrison of allies in a 45-man siege thinks at full rate
  regardless of distance. Cheap win available here, unrelated to realism.

---

## 8 · RECOMMENDATIONS — ranked by visible impact per unit of work

Every one of these is **wiring or constants**, not new architecture, except R4.

### R1. Casualty reaction — connect `died` to the brains. *(highest impact, near-zero CPU)*
Event-driven; **no per-frame cost**. In `enemy_squad.gd` (or a small static broker) fan a death
out to men within ~20 m: `apply_suppression(0.25)`, force `goal_timer = 99.0` (the existing
class-A interrupt, `enemy_base.gd:2413`), reset `has_reacted = false`, point `facing_dir` at the
death, and fire `VOManager.play_enemy("pain"/"contact")` on one nearby man only (the cooldown gate
at `vo_manager.gd:98` already prevents a chorus). Mirror into `ally_base.gd` off
`squad_system.gd:97`, which already has the handler.
**Reads as:** the whole line ducks when a man drops. Silhouette + sound + timing.
**Sacrifices:** enemies become slightly harder to whittle down one at a time; a suppression bump
on death makes chained kills easier, so cap the fan-out at one bump per man per ~2 s.

### R2. Make `aim_speed` an angular rate. *(one line each side, zero CPU)*
`enemy_base.gd:1648-1649` and `ally_base.gd:1064`. Replace the lerp weight with a real slew cap —
rotate `current_aim_dir` toward `target_aim_dir` by at most `aim_speed * delta` **radians**
(`Vector3.rotate_toward`, or `slerp` with `minf(1.0, (aim_speed*delta)/angle)`). At `aim_speed 5–9`
a 170° swing then costs 0.33–0.6 s while a 10° correction costs 20 ms. Roll allies' flat 7.0 into
`randf_range(5.0, 8.0)` at `ally_base.gd:152` so the fireteam stops moving in unison.
**Reads as:** men caught facing the wrong way have to *turn*, and you can see it and shoot them
first. This is the single cheapest change that converts a bot into a man, and it is pure
silhouette — perfect for PSX.
**Sacrifices:** enemies get meaningfully easier when flanked. That is the point (Pillar 1), but it
will show up in lethality tuning; `test_ai_fairness` should be re-run.

### R3. Widen and tier the reaction window. *(constants only, zero CPU)*
`enemy_base.gd:245` `BASE_REACTION_TIME 0.25 → 0.45`, and make the tier a factor at `:1721`:
RELAXED ×2.2, SUSPICIOUS ×1.5, ALERT ×1.0, COMBAT ×0.7. Widen `char_reaction` rolls at
`:385/391/397` to something like 0.25–0.95 so men differ by ~3×. Lift the startle gate at
`:1258-1261` off `GameManager.player` and off the 15 m radius — any cold man jumped by anything.
Add the ally counterpart: reuse `_aim_settle` but set it on *reacquisition*, not only on target
change (`ally_base.gd:771`).
**Reads as:** ambushes work; garrison men who were already alert snap back fast, the cook does not.
**Sacrifices:** the AO is easier to stealth through; that is ADR-005's intent, so it is aligned,
but the demo's siege will feel slightly softer at the wire.

### R4. Give the ally a perception model. *(largest build; highest payoff on Pillar 4)*
`ally_base.gd:739-773` is currently a distance filter. Port the enemy shape: an FOV cone
(reuse `_fov_deg`'s ladder), a `CombatManager.has_line_of_sight` + `SightCap.has_terrain_los`
gate before acquisition (not only before firing), an `awareness` accumulator, and the
`_target_score` weighting from `enemy_base.gd:1298-1307` so allies stop all locking the nearest
man. Add the gaze sweep (`enemy_base.gd:1680-1686`) so the cone is not a blindfold.
**Perf:** one extra perception ray per ally per think. At ~8 squad members and 6.7 Hz that is
~54 rays/s — negligible against the enemy budget (`CombatManager.rays_perception`, `:1183`).
Pair it with an ally think-LOD (`ally_base.gd:659`) and it is net-neutral.
**Reads as:** the squad reports contacts it can actually see, spreads its fire, and can be
surprised. It also makes the player's *call-outs* matter (Pillar 4) — an omniscient squad has
nothing to be told.
**Sacrifices:** allies get worse at fighting, which will read as "my squad is dumb now" unless R1
and R6 land with it. Do not ship R4 alone.

### R5. Cap COMBAT-tier awareness. *(one constant)*
`enemy_base.gd:1027-1028` `360.0 → ~240.0`, keeping the `CLOSE_SENSE_RANGE` bubble (`:1178`) so
point-blank still works. Flanking a man in contact becomes possible again.
**Cost:** zero. **Sacrifices:** enemies are exploitable by circling; the 240° + close-sense
combination keeps that from being free.

### R6. Ally parity on hit reaction. *(port an existing block)*
`ally_base.gd:1751-1762` — bring across the enemy's flinch (`enemy_base.gd:2454-2457`), the
trigger stall (`:2452-2453`), the pain-quota `apply_stagger` + `_stumble_until_ms` (`:2461-2466`)
and a pain VO. `ModelActor.flinch` already exists.
**Cost:** zero per-frame. **Reads as:** allies visibly take rounds.

### R7. Suppression must actually spoil aim. *(one line)*
`enemy_base.gd:1744` — the term is inverted in effect (0.8× calm, 1.0× pinned). Make it
`base_accuracy_modifier * (1.0 + suppression_level * 1.5)` and apply it in every branch of
`_execute_combat`, not just the mid band.
**Cost:** zero. **Sacrifices:** suppressive fire becomes a real player verb, which makes the M60
strictly stronger — a balance question for `balance-reviewer`, not a realism one.

### R8. Ammunition and reloads. *(smallest new system, big sensory payoff)*
A `mag_size` on `WeaponData`, a counter in both bases, and a 2–3.5 s reload that forces a duck if
cover is near. Bark it (`VOManager` "reloading"/"cover me"). This is the classic *modern* AI beat
and it is entirely silhouette+sound+timing.
**Cost:** trivial CPU. **Sacrifices:** real content work (VO lines, a reload clip per weapon per
faction) and a genuine lethality drop as enemies go quiet periodically.

### R9. Grenade danger. *(small)*
Have `Grenade` register itself on a static danger list; both bases test it in `_think` (a
distance check against a list that is almost always empty) and, if inside ~8 m with fuse left,
force `SEEK_COVER` away from it plus a bark. Also stop `_on_noise_heard` walking men *toward* a
VOICE event that was a grenade warning (`enemy_base.gd:1267-1280`).
**Cost:** one distance loop over a near-empty array per think.

### R10. Fix the awareness clock and the drifted comments. *(hygiene, do it in passing)*
`enemy_base.gd:1204/1208` → `_think_interval_current`. Correct the `# Radians per second` lie at
`enemy_base.gd:112` / `ally_base.gd:152` when R2 lands. Correct
`ai_marksmanship.gd:3-6`'s "trends 1:1" claim, which `ally_base.gd:1674` falsifies.

---

## 9 · Triage summary

| Finding | Pointer | Triage |
|---|---|---|
| No AI consumer of `died` | `enemy_base.gd:2694`, `ally_base.gd:1788` | **UNFINISHED** |
| `aim_speed` is a lerp weight, not a rate | `enemy_base.gd:1648`, `ally_base.gd:1064` | **UNFINISHED** (+ FOSSIL comment) |
| Reaction window 0.30–0.375 s, tier-blind | `enemy_base.gd:245,1721` | **UNFINISHED** |
| Ally has no reaction gate | `ally_base.gd` (absent) | **MISSING** |
| Ally acquisition: no FOV, no LOS, no awareness | `ally_base.gd:739-773` | **MISSING** |
| Ally targeting is nearest-only | `ally_base.gd:754` | **MISSING** |
| Ally passes `exposure_t=1.0, force_first_miss=false` | `ally_base.gd:1674` | **UNFINISHED** |
| Exposure ramp never applies AI-vs-AI | `ai_marksmanship.gd:83-92` | **UNFINISHED** |
| COMBAT tier = 360° FOV | `enemy_base.gd:1027` | **UNFINISHED** |
| Awareness on the wrong clock | `enemy_base.gd:1204,1208` | **UNFINISHED** (defect) |
| Suppression barely touches aim (inverted) | `enemy_base.gd:1744` | **UNFINISHED** |
| Ally: no flinch/stagger/pain/rout | `ally_base.gd:1751-1762` | **MISSING** |
| `last_hit_dir` has no tactical consumer | `enemy_base.gd:2418`, `ally_base.gd:1751` | **UNFINISHED** |
| No grenade-danger reaction | both bases | **MISSING** |
| No ammo/reload model | both bases | **MISSING** |
| No ambient/idle VO; non-squad allies mute | `vo_manager.gd:61-74` | **MISSING** |
| Ally has no gaze sweep | `ally_base.gd` (absent) | **MISSING** |
| Ally has no think LOD | `ally_base.gd:659` vs `enemy_base.gd:37-52` | **UNFINISHED** |
| Burning has no AI consumer | `scripts/combat/burning.gd` | **MISSING** |

**Recommended order:** R2 → R1 → R3 → R5 → R7 (all constants/wiring, one session, no new
systems, and together they cover reaction, casualty response, flanking and suppression) — then
R6 + R4 + R10 as the ally-parity pass, then R8/R9 as content work.

*Nothing here proposes degrading AI sophistication to match the art. Every recommendation reads
through silhouette, position, timing or sound.*
