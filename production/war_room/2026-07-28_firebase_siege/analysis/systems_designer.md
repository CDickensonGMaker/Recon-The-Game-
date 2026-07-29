# SYSTEMS DESIGNER — THE SIEGE (v2)

**Written 2026-07-28. Every claim below carries a `file:line`. Where I could not find a pointer,
I say so — that is the finding.**

My lens is the numbers and the shape of the system. I take all eight decree items as settled and
price them.

---

## 0. THE ENVELOPE NOBODY HAS COSTED — A NIGHT IS TEN REAL MINUTES

`SimClock.real_to_sim_ratio = 60.0` (`scripts/autoload/sim_clock.gd:18`) — one real second is one
sim minute. `period_at()` (`sim_clock.gd:56-63`) makes NIGHT `hour >= 19.0 or hour < 5.0` = **10 sim
hours = 10 real minutes**. `MissionWeather.is_night` (`scripts/world/mission_weather.gd:95`) is set
from that period crossing, and `_maybe_launch_sappers` gates on it
(`scripts/missions/field_director.gd:1100`).

**Everything below is budgeted inside 600 real seconds.** A siege that runs past dawn is a siege the
clock cancels mid-fight — `is_night` flips false, `_sapper_rolled_night` resets
(`field_director.gd:1101`), and nothing tells the 30 live attackers the night is over. The hard
timeout in §3 is not polish; it is the only thing keeping the assault inside its own night.

---

## 1. THE d50 AND THE 2d6 — WHAT THE DICE ACTUALLY PRODUCE

### 1.1 A flat d50 is a uniform draw, and it deletes the only escalation currency in the game

`CampaignState.threat_label()` (`scripts/autoload/campaign_state.gd:141-149`) is the game's one
escalation string. It gates the current sapper roll (`field_director.gd:787`,
`SAPPER_CHANCE = {LOW:0.0, MODERATE:0.2, HIGH:0.45, CRITICAL:0.7}`) and it gates the player's own
steel (`_grant_fire_support`, `field_director.gd:957-985` — napalm/CBU at HIGH, Spectre at CRITICAL).
It is fed by the player's own noise (`campaign_state.gd:170-180`).

A **uniform 1–50 rolled per assault** means a LOW-threat player who has been immaculate for six
patrols draws 47 attackers exactly as often as a CRITICAL player does. The tier stops meaning
anything about *the fight*, and it keeps meaning something about *his ordnance* — so being quiet
makes the siege identically deadly and leaves him with fewer tools for it. That is backwards.

**The reconciliation that does not touch the decree.** The decree fixes the *size* of the roll. It
says nothing about **how often the roll happens** or **who the 50 men are**. Both are live levers:

- **Frequency stays tier-owned.** Keep the existing `SAPPER_CHANCE` shape verbatim, renamed to the
  siege. At LOW a 50-man night is rare because *any* night is rare. This mechanism already exists
  and already reads the label (`field_director.gd:1108`). No new authority.
- **Composition is tier-owned; count is not.** Fifty `vc_farmer` is not fifty `nva_regular`
  (`data/enemies/nva_regular.tres`: `max_hp 85`, `determination 0.9`, `flanks true`, vs the farmer).
  Roll a literal d50, then draw each body from a tier mix:

  | tier | nva_regular | vc_rifleman | vc_farmer |
  |---|---|---|---|
  | LOW | 0.00 | 0.55 | 0.45 |
  | MODERATE | 0.20 | 0.60 | 0.20 |
  | HIGH | 0.50 | 0.50 | 0.00 |
  | CRITICAL | 0.80 | 0.20 | 0.00 |

  Sappers always come from `vc_sapper.tres` regardless of tier — the 2d6 is a *role*, not a quality.

This delivers d50 as written and still makes the AO's temperature felt.

### 1.2 The 2d6 subset is the best number in the decree, and nobody has noticed why

`sappers = mini(roll_2d6(), count)`. Run the distribution:

| d50 roll | 2d6 mean 7 | sapper fraction | what the night IS |
|---|---|---|---|
| 3 | clamped to 3 (2d6 > 3 ~92% of the time) | **100%** | three silent men, no muzzle flashes, satchels |
| 8 | 7 | 88% | an infiltration with a thin screen |
| 20 | 7 | 35% | a probe with a real base of fire |
| 50 | 7 | 14% | a battalion assault with a demolition element |

`vc_sapper.tres` has `aggression 0.2`, `silent_infiltrator = true`, and `SapperCharge` men **never
fire** — the satchel is the weapon (`scripts/enemies/sapper_charge.gd:1-9`,
`enemy_base.gd:63-64`). So a **3-man night is a stealth-defence horror piece with nothing to shoot
at**, and a **50-man night is a stand-up firefight**. The two dice, taken together, are a *ratio
generator*. The small night and the big night are not the same game at two volumes; they are two
different games. That is the strongest thing in the decree and the design should lean on it, not
smooth it.

**Consequence, and it is a problem — see §7.** A single percentage break rule cannot score both.

### 1.3 The dice do not interact with ADR-016 at all, and that is the finding

ADR-016 flattened everything to `base_damage 27` per rifle, MG 42 (`CLAUDE.md:180-198`). There is no
dice grammar left to collide with — `get_damage()` is pure. So the siege's lethality is exactly
linear in body count: 43 riflemen × 27 base × TORSO ×2.5 = **two torso hits kill a 100 HP player.**
On one axis, standing in the open, he dies in well under a second.

**Therefore the single axis is a survival mechanic, not an NPC-recovery convenience.** The decree
justifies item 7 by "no lost enemy NPCs" — that is its *smaller* reason. The real reason is that one
axis gives the player a facing, and a facing is the only thing that makes 50 men at 27 damage
survivable. The Arbiter should read item 7 as load-bearing for fairness, not for tidiness.

---

## 2. THE SHAPE IN SECONDS

All times real-seconds from the assault gate passing. Roll the gate once per night at a sim-hour in
`[20.5, 02.0]` so the siege never opens at 04:55.

| T+ | phase | what happens |
|---|---|---|
| 0 | **COMMIT** | d50 + 2d6 rolled, axis rolled, wave 1 (12 men) spawns at 400–500 m on the axis. No toast. |
| 0–48 | **RANGING** | 4 rounds, 1 per 12 s, CEP 55 → 21 m, aim point on the wire at the axis. The *only* warning he gets. |
| 45–150 | **THE APPROACH** | waves 2–4 commit at 20 s spacing. Sappers cross 300 m. First contact trips `_poll_firebase_threat` → STAND TO + the radio crisis. |
| 150–330 | **FIRE FOR EFFECT** | 3-round volleys every 25 s, CEP 9 m, aim point walking from the wire toward `fsb_center`. Break check live throughout. |
| break | **WITHDRAW** | 45 s to clear the axis, then despawn (§3). |
| 420 | **TUBES DISPLACE** | mortars stop unconditionally — they have a basic load, and they must be off the ground before light. |
| 480 | **HARD WITHDRAW** | unbroken or not, the assault breaks off. **The night owns the siege; the siege does not own the night.** |

Eight minutes, inside a ten-minute night, with two minutes of slack. This is the whole envelope and
it is tight — which is correct for a siege.

---

## 3. THE BREAK — WHERE IT LIVES, WHO COUNTS, AND HOW NOBODY IS LOST

### 3.1 The per-man ladder cannot produce this break. Proof, not opinion.

`enemy_base.gd:1219-1221`:

```gdscript
var numbers_mult: float = clampf(1.6 - _last_force_ratio * 0.45, 0.25, 1.4)
scores[Enums.AIGoal.RETREAT] = retreat_score * char_self_preservation * numbers_mult
```

`_local_force_ratio()` (`enemy_base.gd:1238-1254`) counts friends within 25 m against player + allies
within 25 m. **Fifty men on one axis puts every attacker at ratio ≥ 5**, which pins `numbers_mult` at
its `0.25` floor. The retreat score is quartered for the entire assault, at every casualty level,
for as long as the mass is intact. Simultaneously `advance_score += 0.15` fires (`:1203-1204`).

The individual courage ladder is therefore *structurally incapable* of breaking a 50-man formation.
It was built to model a man in a fireteam and it does that well. **The formation break must be a new
authority.** This is not a preference; it is arithmetic on line 1220.

### 3.2 `EnemySquad.is_broken` is the wrong authority too

`spawn_tracked_enemy` sets `squad_id = hash(group_tag)` (`field_director.gd:39`), so one tag = one
squad. `break_state` (`enemy_squad.gd:109-112`) breaks below `ratio < 0.45` shifted by courage —
that is **55% killed**, above the decree's 40–50% band, and NVA courage 0.65 pushes the threshold
*lower* still (harder). Worse, `peak` is `maxi(peak, live)` recomputed on a 1 s TTL
(`enemy_squad.gd:129`) — a **staggered** wave arrival (which §6 requires for perf) would latch peak
at wave 1's 12 men and break the whole siege after 6 kills. Riding the decree on `is_broken` and
staggering the spawn are mutually exclusive.

### 3.3 The break, concretely

Three ints on FieldDirector, one increment in a hook that already exists:

```
_siege_committed : int    # the d50, set ONCE at commit. Never recomputed. Never re-derived from live count.
_siege_killed    : int    # incremented in _on_enemy_died when group_tag begins "siege_"
_siege_break_frac: float  # randf_range(0.40, 0.50), rolled once per assault
```

`_on_enemy_died(enemy, group_tag)` at `field_director.gd:63` **already carries the group tag** and is
already connected at spawn (`:40`). The counter costs one branch per death.

Fire when `_siege_killed >= int(ceil(_siege_committed * _siege_break_frac))`.

Rolling the fraction inside the band (rather than fixing 0.45) means the player cannot learn to count
to a number. He learns a *feel*: "about half."

**Do not filter by killer.** Garrison kills, MG kills, mortar kills and sapper-blast fratricide all
count. A filter the player cannot see is a rule that does not exist. Pillar 4 also forbids it — he
does not position individual men, so he cannot be asked to earn kills personally.

Boundary checks: `count=3, frac 0.45 → ceil(1.35) = 2` (two of three sappers die, the third leaves).
`count=1 → 1`. `count=50, frac 0.50 → 25`. All sane.

### 3.4 "Withdraw" — the decree's stated fear is a REAL, LIVE defect

`_execute_retreating` (`enemy_base.gd:1644-1676`) flees on a bearing away from the last threat, slides
along walls, and **has no destination, no timeout and no terminal state.** And `EnemyBase` has **no
despawn path anywhere in the file** — the only `queue_free()` in it is `:360`, a ModelActor teardown.
A routed man runs into the jungle at `move_speed * 1.25` **forever**, as a live, tracked
`_live_enemies` entry.

So if the break is implemented as "raise everyone's RETREAT score," the decree's own worst case is
*guaranteed*: 27 survivors permanently loose in 500 m of jungle. `_break_siege()` must therefore do
three things in order:

1. **Clear the drive.** `assault_objective = Vector3.ZERO` on every live siege man
   (`enemy_base.gd:1317` is the override that reads it).
2. **Give them a rally, reusing the drive.** Set `assault_objective = fsb_center + axis * 420.0`.
   `_execute_assault` (`enemy_base.gd:1370`) already pushes legs through contact at 1.15× — which is
   exactly what a withdrawal under fire looks like. **No new movement code, and the men leave along
   the one axis the player is already facing.** He sees them go.
3. **Reap them.** A `_poll_siege_exfil` on the existing 0.5 s tick (`field_director.gd:157-163`):
   remove any siege man beyond 500 m of `fsb_center` **and** beyond 180 m of the player **and** not
   `CombatManager.perceivable` (the predicate at `enemy_base.gd:541`). Hard sweep 90 s after the
   break for any survivor meeting the last two conditions regardless of distance.

**"No man lost in the jungle" can only honestly mean they leave the WORLD, not the map.** There is no
existing despawn to reuse; this is new code and the Arbiter should book it as such.

### 3.5 The bug the reuse in (2) creates, written down before it ships

`SapperCharge._physics_process` (`sapper_charge.gd:42-51`) tests distance to its own `target_pos`,
**not** to `assault_objective`. A withdrawing sapper whose rally bearing carries him back across his
original aim point **detonates on the way out**. `_break_siege()` must `queue_free()` every
`SapperCharge` child before setting the rally. One line; omit it and the withdrawal blows the depot.

---

## 4. THE MORTARS — CONCRETE NUMBERS, AND THE ONE HONEST REUSE DEFECT

### 4.1 The reuse is honest except for one line

`_fire_shell` (`field_director.gd:648-660`) is almost faction-agnostic — it loads a
`ProjectileData`, seats the impact on terrain, and arcs it in. But `:656`:

```gdscript
var azimuth: Vector3 = ground - fsb_center
```

The shell is spawned on the bearing **from the firebase outward**. For a *friendly* tube firing out
into the AO that is right. For an **enemy** tube it is exactly inverted — the round arrives from the
compound. `_fire_shell` needs a `from: Vector3` parameter (defaulting to `fsb_center`, so every
friendly caller is untouched). That is the whole change. `_mortar_impact`
(`field_director.gd:721-730`) is already pure and reusable as-is.

`FirePlan` (`scripts/gameplay/fire_plan.gd`) must **not** grow enemy constants. Its own header
(`:9-10`) says the dependency runs one way, consumers → table, and it is the *player's* footprint
table — the preview ring the player places is computed from it (`:49`). Enemy dispersion is not a
footprint the player places. Siege constants live on FieldDirector beside the siege.

### 4.2 The schedule

```
SIEGE_MORTAR_TUBES      = 2
SIEGE_RANGE_ROUNDS      = 4        # night 1; 2 on night 2; 0 on night 3
SIEGE_RANGE_INTERVAL_S  = 12.0     # fire, listen, correct
SIEGE_DISP_START_M      = 55.0     # first round CEP - no observer yet
SIEGE_DISP_END_M        =  9.0     # FFE CEP, just inside MORTAR_BLAST_M (fire_plan.gd:17 = 10.0)
SIEGE_DISP_BRACKET      =  0.62    # geometric - a correction halves the error, it does not subtract
SIEGE_FFE_VOLLEY        =  3
SIEGE_FFE_INTERVAL_S    = 25.0
SIEGE_ROUNDS_MAX        = 34       # the tubes' basic load. The barrage ENDS, on its own, always.
SIEGE_DEFORM_EVERY      =  2       # crater cap - see 4.4
```

`disp(n) = maxf(SIEGE_DISP_END_M, SIEGE_DISP_START_M * pow(SIEGE_DISP_BRACKET, n))`
→ **55.0, 34.1, 21.1, 13.1, 9.0** and clamped thereafter. `n` increments once per ranging round *and*
once per FFE volley, so the walk-on is felt across roughly five impacts (~60 s). It is never one
round. A geometric bracket is right because that is how a real crew corrects — they halve the error,
they do not step it down by metres.

### 4.3 The aim point walks INWARD, and it hunts the guns

Do not aim at `fsb_center`. Aim at the wire on the assault axis, and lerp inward as the assault
closes:

```
aim(n) = wire_point.lerp(fsb_center, clampf(float(n) / 5.0, 0.0, 0.8))
```

One lerp, and the player watches the barrage come to him. That is the death-or-life feel the decree
asks for, and it costs nothing.

**Then the tactical version, which answers Q3's shooting-gallery worry.** During FFE, if a manned
`MGEmplacement` sits within 60 m of the assault axis, bias the aim point onto it. The group is
already there and already queried — `_nearest_free_emplacement` scans `mg_emplacements`
(`scripts/allies/garrison_defender.gd:97`) and `man_by_ai` marks occupancy (`:68`).

Fifty men walking into two fixed MGs on one axis **is** a shooting gallery. The counter is not to
weaken the guns or to widen the axis (which breaks item 7). It is that **the enemy mortars are trying
to kill the guns**, and the player's counter-move is to keep the guns firing, or to move the crew, or
to accept the gap. That turns the mortar from weather into an actor, and it is the answer to Q3.

### 4.4 Do not deform on every round

`_mortar_impact` (`field_director.gd:727-728`) calls `DamageSystem.apply_damage(SMALL_EXPLOSION)`
whenever `intensity >= 1.0`. The friendly artillery path deliberately caps this — `_arty_impact`
(`:580`) carries `# crater cap: 2 of 6 rounds deform`. **34 unguarded deform calls inside a built
firebase is a terrain-rebuild storm at the exact worst frame**, and per ADR-031 it will also chew the
destructibles. Deform on even `n` only: 17 craters maximum. The firebase should look shelled, not
tilled.

---

## 5. THREE NIGHTS — NOTHING PERSISTS THIS TODAY

### 5.1 The state that does not exist

`SimClock.sim_day` (`sim_clock.gd:16`) is an autoload var. It is **not** written by `save_campaign()`
(`campaign_state.gd:208-229`), **not** in `to_dict()` (`:281-295`), and **not** in `from_dict()`
(`:298-312`). It resets to 1 on every boot. There is no consecutive-night counter anywhere in the
repo. So today, **F5/F9 mid-siege silently resets the run to night 1** — that is the direct answer to
Q5, and it is a hole in the floor, not a polish item.

Four new fields on `CampaignState`, each needing a line in all four of `save_campaign`,
`load_campaign`, `to_dict`, `from_dict` (miss one and the two stores disagree, which the file's own
comment at `:279-280` explicitly forbids):

```
var siege_nights_run : int   = 0    # consecutive nights the FSB has been hit, 0..3
var siege_last_night : int   = -1   # SimClock.sim_day of the last assault
var siege_sim_day    : int   = 1    # the sim day itself, so a reload does not rewind the campaign
var garrison_dead    : Array = []   # post positions of defenders killed (see §5.3)
```

`SAVE_VERSION` (`campaign_state.gd:6`) goes **1 → 2** with a branch in `_migrate` (`:275`). The
defaults are all safe, so the migration is a no-op — but the version guard at `:246-249` exists
precisely so a shape change is *declared*. Bumping it is not optional.

### 5.2 The run rule is two lines

```
if SimClock.sim_day > siege_last_night + 1: siege_nights_run = 0   # a quiet night breaks the run
if siege_nights_run >= 3: return                                    # night 4 in a row cannot fire
```

### 5.3 What makes night 2 and night 3 different

The count is a d50 every night — the decree forbids scaling the fight by adding men. So the
escalation axis has to be **precision and attrition**, not mass:

| | night 1 | night 2 | night 3 |
|---|---|---|---|
| count | d50 | d50 | d50 |
| composition | tier mix (§1.1) | mix shifted **one** tier up | shifted **two** tiers up |
| axis | rolled uniform | **must differ ≥ 90° from night 1** | the remaining untried sector |
| ranging rounds | 4 | 2 | **0 — fire for effect from round one** |
| opening CEP | 55 m | 34 m | 21 m |
| sapper aim | the bench (`_sapper_aim`, `field_director.gd:801`, `:912`) | bench **+** the manned MG post | bench + MG + the CP |
| garrison | full | minus night 1's dead | minus nights 1–2's dead |
| break band | 0.40–0.50 | 0.40–0.50 | 0.40–0.50 |

The felt story is: *they now know the range, and there are fewer of us.* The axis rule is what stops
night 3 from being night 1 replayed — he cannot pre-build one strongpoint and win three times, which
is exactly the trap a fixed-axis decree would otherwise set.

---

## 6. GARRISON ATTRITION — DEAD DEFENDERS DO NOT STAY DEAD TODAY

### 6.1 Measured

`_build_firebase_garrison` (`scripts/missions/mission_generator.gd:748-760`) spawns the garrison
deterministically from `SitePlanner.fsb_garrison_plan(center)` — same seed, same men, every world
build. `GarrisonDefender.promote` (`scripts/allies/garrison_defender.gd:26-80`) tears the Civilian
down and stands an `AllyBase` in his place, snapshotting `post` at `:36`. **When that AllyBase dies,
nothing anywhere records it.** Next build, every post is manned again.

Compounding it: `_garrison_stood_to` (`field_director.gd:804`) is a once-per-operation bool, checked
at `_garrison_stand_to` (`:1066-1069`). Night 2 never promotes anyone who was still a Civilian.

### 6.2 The fix, reusing a shape that already exists

The project already has exactly this pattern for world memory —
`CampaignState.remember_collapsed_tunnel` (`campaign_state.gd:347-351`) rounds a `Vector3` to the
metre, and `tunnel_is_collapsed` (`:356-360`) matches within 3.0 m so a regenerated world still
lines up. **Reuse that shape exactly; do not invent a second key format.**

- On a `garrison_promoted` ally's death, append `round(post)` to `CampaignState.garrison_dead`.
- `_build_firebase_garrison` skips any post within 3.0 m of a `garrison_dead` entry.
- `_garrison_stood_to: bool` becomes `_garrison_stood_to_day: int` (the `sim_day` it last stood to),
  so night 2 stands to again.

**Cap it.** `GARRISON_LOSS_MAX_FRAC = 0.5` — the plan always mans at least half its posts. Without
this, night 3 can arrive at an undefended firebase and the "fair siege" becomes a scripted loss,
which Pillar 5 forbids.

### 6.3 The sacrifice, named

There is no stand-*down*. Reverting promoted `AllyBase` men back to `Civilian` would be a second
transform authority pointed the other way, and the FOSSIL LAW says do not build one to make a
cosmetic problem go away. So after night 1 the firebase is permanently manned by soldiers holding
posts instead of a working base with men cooking and hauling. **Pillar 2 (atmosphere) pays for this,
and it is the cheapest honest answer.** Say it out loud rather than discovering it in a playtest.

---

## 7. WHERE THE DECREE'S OWN RULE PRODUCES TWO DIFFERENT GAMES

This is my disagreement, and it is narrow on purpose.

The 40–50% threshold is a *percentage of the roll*. Cross it with §1.2's sapper ratio:

- **Count 50.** 23 kills needed. Forty-three of the fifty are riflemen who fire, expose themselves,
  and die. Targets are everywhere. Time-per-kill is low. 23 is loud, fast work.
- **Count 5.** 2–3 kills needed. All five are sappers. `vc_sapper.tres` has `aggression 0.2` and
  `silent_infiltrator = true`; `SapperCharge` men **never fire** (`sapper_charge.gd:1-9`). There are
  no muzzle flashes, no tracers, no noise to cue on — at night, in fog, inside a compound. Finding
  three men who do not shoot back can take **longer and frighten more** than killing twenty-three who
  do.

The single percentage rule scores both as "get to ~45%." It is measuring bodies when the small night's
actual win condition is *satchels defeated*. A 5-man night that the player wins by killing two
sappers while the third blows the depot is a **win on the counter and a loss on the ground** — the
`on_firebase_breach` cost lands (`field_director.gd:1085-1093`) and the siege is scored as broken.

**My proposal, which does not re-litigate the threshold:** for `count <= 8`, the break condition is
"every committed sapper is dead or has detonated" — a state `SapperCharge` already resolves for us at
`:47-48` and `:54-71`. Above 8, the percentage rules. One branch, and it makes the small night the
horror piece the dice are already trying to make it.

---

## 8. PERF — THE HONEST PRICE (Q4)

### 8.1 The body gate is defeated by construction

`_body_gate_open` (`enemy_base.gd:534-536`) returns `true` for anyone with
`alert_tier > AlertTier.RELAXED`. The current assault element spawns straight into ALERT
(`field_director.gd:1144`) and the siege must too. So **all 50 run the full body path every frame**:
gravity, `move_and_slide`, navmesh queries, and `HitzoneBuilder.sync` on the skeleton
(`enemy_base.gd:463-470`). The project's main per-body saver is off for the entire siege, by design.

`EnemySquad.HOT_CAP = 12` / `HOT_CEILING = 16` (`enemy_squad.gd:37-38`) still bounds the *expensive*
think — targeting, LOS raycasts, precise aim. That part is safe and needs no change. What is unbounded
is the body path × 50, plus corpses.

### 8.2 Mitigations, in value order, all inside Forward+

1. **Stagger the commit into waves of 12 at 20 s spacing.** Peak concurrent live attackers ≈ 24 (one
   wave engaged, one closing) instead of 50. Wave 1's dead are corpses by wave 3. **The player never
   sees fewer men on the axis — he sees a fight that keeps feeding, which is what a siege is.** This
   is the single best mitigation and it costs nothing but a timer. It is also why the ranging phase
   exists: the walk-on mortar is the cover story for the stagger.
   *Note the coupling in §3.2 — staggering is precisely why the break cannot ride on
   `EnemySquad.is_broken`'s recomputed `peak`.*
2. **Keep the outer spawn ring at 500 m.** `_update_think_lod` (`enemy_base.gd:47-48`) drops think to
   0.6 s beyond 150 m, so uncommitted waves are cheap where they stand. The existing
   `SAPPER_RING_MIN/MAX = 300/500` (`field_director.gd:785-786`) is already correct — keep the
   numbers when the constants are renamed.
3. **A corpse reaper, which does not exist today.** 50 corpses keep re-syncing hitzones at 6 Hz
   (`enemy_base.gd:466`). `SIEGE_CORPSE_MAX = 20`, oldest freed first, only when not
   `CombatManager.perceivable`.
4. **The crater cap from §4.4.**

### 8.3 The price, stated plainly

`production/PERF_LEDGER.md:161-162` records that **nothing clears 30 fps in the night arena** — best
case 29.9 on Mobile at 0.75 scale, and **25.5 at native on the best renderer**. Forward+ is decreed
(project memory, Forward+ decree). A night siege is the night arena, plus ~24 live bodies, plus
mortar explosions, plus terrain deform.

**This will be the worst-performing ninety seconds in the game, and no mitigation inside Forward+
changes that verdict — the stagger only decides whether it is bad or unplayable.** Pretending
otherwise would be the lie the Arbiter should refuse. My recommendation is to ship it and measure it
with the Summoner's eyes (`PERF_LEDGER.md:6` — there is no numeric gate), because the alternative is
building a smaller siege, which the decree forbids.

---

## 9. WHO OWNS THE SIEGE — ONE ANSWER, PER THE BLINDSPOT LAW

**`FieldDirector`, and nothing else.** It already owns every piece:

- `spawn_tracked_enemy` (`field_director.gd:31-45`) — the one tracked-spawn authority
- `_live_enemies` (`:12`) and the death hook `_on_enemy_died` (`:63`), which already carries the tag
- the 0.5 s poll (`:157-163`)
- `fsb_center`, `_sapper_aim` (`:827`, `:801`, seeded at `:906-912`)
- the shell path `_fire_shell` / `_mortar_impact` (`:648`, `:721`)
- the breach cost `on_firebase_breach` (`:1085`)

`CampDirector` (`scripts/enemies/camp_director.gd`, 153 lines) is a village/camp ambience brain and
owns no spawn of this shape. **A `SiegeDirector` node would be the fifteenth parallel world-build
authority in a project that already has ~14.** The siege is a method set *on* FieldDirector that
replaces `SAPPER_DATA`/`SAPPER_COUNT`/`SAPPER_RING_*`/`SAPPER_CHANCE`/`ASSAULT_DATA`/`ASSAULT_ELEMENT`
(`:783-794`), `_sapper_launched` (`:802`), and `launch_sapper_assault` (`:1115-1146`) — **deleted in
the same change**, per ADR-023.

`tests/test_sapper_assault.gd` (317 lines) and `tests/test_firebase_defense.gd` (403 lines) go red
the moment those constants die. They must be **rewritten in the same change**, not deleted and not
left red — `test_sapper_assault.gd:3-9` documents that this feature was once an orphan whose sprint
never moved a man, and that probe is the only reason we know it works now.

---

## 10. THE DEFECT THE DECREE CANNOT SURVIVE

`field_director.gd:1027`:

```gdscript
if fsb_center == Vector3.ZERO or not patrol_out:
    return
```

`_poll_firebase_threat` returns early whenever the player is **inside his own wire**. The siege
happens *to him at home*. As written, the crisis never raises and — because `_garrison_stand_to()` is
called from inside this function at `:1039` — **the garrison never stands to while he is home.**

The fix is one line and it is already correct downstream: drop `patrol_out` from the outer guard.
`raise_crisis` re-checks `patrol_out` itself at `:1010` before retasking the sweep, so removing the
outer gate changes nothing about the retasking path. The gate is redundant *and* fatal.

---

## 11. THE CONSTANT BLOCK, ASSEMBLED

```gdscript
## THE SIEGE (war-room decree 2026-07-28). Replaces the SAPPER_* raid.
const SIEGE_CHANCE: Dictionary = {"LOW": 0.0, "MODERATE": 0.2, "HIGH": 0.45, "CRITICAL": 0.7}
const SIEGE_MAX_NIGHTS: int = 3
const SIEGE_HOUR_MIN: float = 20.5
const SIEGE_HOUR_MAX: float = 2.0

const SIEGE_RING_MIN: float = 300.0
const SIEGE_RING_MAX: float = 500.0
const SIEGE_ARC_RAD: float = 0.35          ## the single axis, half-angle
const SIEGE_AXIS_MIN_SEPARATION: float = PI * 0.5   ## night 2/3 must differ by this

const SIEGE_WAVE_SIZE: int = 12
const SIEGE_WAVE_INTERVAL_S: float = 20.0

const SIEGE_BREAK_FRAC_MIN: float = 0.40
const SIEGE_BREAK_FRAC_MAX: float = 0.50
const SIEGE_SMALL_NIGHT_MAX: int = 8       ## at or below: sappers-defeated is the break (§7)
const SIEGE_WITHDRAW_M: float = 420.0
const SIEGE_DESPAWN_M: float = 500.0
const SIEGE_DESPAWN_PLAYER_M: float = 180.0
const SIEGE_EXFIL_TIMEOUT_S: float = 90.0

const SIEGE_MORTAR_TUBES: int = 2
const SIEGE_RANGE_ROUNDS: Array[int] = [4, 2, 0]   ## by night index
const SIEGE_RANGE_INTERVAL_S: float = 12.0
const SIEGE_DISP_START_M: Array[float] = [55.0, 34.0, 21.0]
const SIEGE_DISP_END_M: float = 9.0
const SIEGE_DISP_BRACKET: float = 0.62
const SIEGE_FFE_VOLLEY: int = 3
const SIEGE_FFE_INTERVAL_S: float = 25.0
const SIEGE_ROUNDS_MAX: int = 34
const SIEGE_DEFORM_EVERY: int = 2
const SIEGE_TUBES_DISPLACE_S: float = 420.0
const SIEGE_HARD_BREAK_S: float = 480.0
const SIEGE_MG_HUNT_M: float = 60.0

const SIEGE_CORPSE_MAX: int = 20
const GARRISON_LOSS_MAX_FRAC: float = 0.5
```

---

## 12. WHAT I COULD NOT PROVE

- **Nobody has verified the assault element closes.** The briefing states it; I confirm the mechanism
  is missing, not merely unverified: `firebase_assault` troopers get `last_known_target_pos =
  fsb_center` + `AlertTier.ALERT` and **no `assault_objective`** (`field_director.gd:1140-1144`).
  `_execute_alert` (`enemy_base.gd:1393-1413`) therefore routes them through
  `EnemySquad.hunt_point`, whose ring **grows outward from the anchor** at `HUNT_GROWTH 1.4 m/s`
  capped at `HUNT_R_MAX 70.0 m` (`enemy_squad.gd:296-300`). They will sweep a 70 m ring *around* the
  compound, not close on it. And `hunt_active` expires after `HUNT_BASE_S 25.0 +
  HUNT_DET_S 65.0 × determination` (`:307-308`, `:385-392`) — for NVA at 0.9 that is ~84 s, after
  which they hold. **They stall.** The siege's assault element needs the same objective drive the
  sappers have; that is the mechanism, and it already exists at `enemy_base.gd:1317`.
- I did not measure the frame cost of 24 concurrent ALERT bodies. §8.3 is reasoning from
  `PERF_LEDGER.md:161-162`, not a measurement. **The stagger's wave size (12) is a guess that needs a
  probe** — and per the observation-instrument lesson, that probe must *exercise* the siege, not read
  a log.
