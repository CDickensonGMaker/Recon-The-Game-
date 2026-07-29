# DEVIL'S ADVOCATE — the v2 firebase siege

**Written 2026-07-28. Every claim below was read out of the code, not the plan.**
The decree stands. Nothing here argues the siege should be smaller. Everything here is a thing that
will BREAK, a thing that is SACRIFICED, or a thing the other architects will skip because it is boring.

---

## 0. THE ARITHMETIC OF THE DECREE CONTRADICTS ITSELF

The decree says **"a d50 roll of enemies. With 2d6 of them being sappers."** Read literally:

| roll | attackers | sappers | result |
|---|---:|---:|---|
| d50=1, 2d6=7 | 1 | 7 | **seven sappers of one man** |
| d50=3, 2d6=12 | 3 | 12 | four times more sappers than attackers |
| d50=1, 2d6=2 | 1 | 2 | a "siege" that is one man |
| d50=50, 2d6=2 | 50 | 2 | 48 riflemen, 2 satchels — the sappers are a rounding error |

**`2d6` is not a subset of `d50` for 30 of the 50 possible attacker rolls** (any d50 ≤ 11 can be
exceeded by 2d6). The council MUST rule the clamp — `sappers = mini(2d6, count)` or
`sappers = mini(2d6, count/2)` — or the first ship build spawns a negative rifle element
(`for j in range(ASSAULT_ELEMENT)` with a negative count is a silent no-op in GDScript, so it will
not even error: it will just quietly produce a sapper-only siege nobody ordered).

**And the low tail is not a siege at all.** d50 is uniform: **22% of nights roll ≤ 11 attackers**,
which is the *existing* 3+4 raid the decree replaces. 1-in-50 nights the "death-or-life siege" is one
man walking at the wire. The decree demands "it must feel like death-or-life" (briefing:26) and
simultaneously demands a flat d50 (briefing:22). Those two lines fight. A flat d50 is the wrong
distribution for the feeling the decree asks for; the arbiter must either accept that 1 night in 5
is a non-event, or name a floor. **I do not propose a smaller siege — I name that the decree's own
distribution defeats the decree's own feel-goal one night in five.**

---

## 1. THE 40–50% BREAK HAS NO LEDGER TO COUNT WITH. NONE. THE CODE HAS NO PLAYER-KILL COUNTER.

The decree: *"holding off long enough that over 40 to 50 percent of the attack is killed **by them**."*
**There is no data structure in this repository that can answer "did the player kill this man."**

- `field_director.gd:63-68` — `_on_enemy_died` calls `state.record_kill()` and erases the body.
  It takes `_group_tag` and **discards the killer entirely.** The signal itself
  (`enemy_base.gd:5` `signal died(enemy: EnemyBase)`) **carries no killer argument.**
- `mission_state.gd:6,14` — `var kills: int` / `record_kill()`. One integer. It counts a man who
  bled out from a gut wound the same as one the player shot in the face.
- `enemy_base.gd:2271-2280` `_credit_killer` — the only attribution path in the game — credits
  **only nodes carrying a `member` dict**, i.e. allies, per ADR-032. Its own header says
  *"the player has no skills"*. **The player is structurally excluded from the one kill-credit
  function that exists.**

So every one of the Summoner's hypotheticals resolves to the same defect:

**a) The player hides in a bunker and fires nothing.** The garrison kills 25 of 50. `state.kills`
reads 25. A naive threshold sees 50% and breaks the siege. **The player wins by hiding.**

**b) The player's own mortars do it.** `_run_mortar_mission` → `_fire_shell` → `_mortar_impact`
(`field_director.gd:721-730`) calls
`CombatManager.apply_explosion_damage(ground, 140*intensity, 40, MORTAR_BLAST_M, **null**)`.
**`attacker` is `null`.** `enemy_base.gd:2152-2157` only records `_last_attacker` when the attacker
is a Node in group `player` or `allies`. A mortar kill therefore has **`_last_attacker == null`**,
`_credit_killer(null)` returns at `:2272`, and `_witness_check(null)` is called with no killer
(`:2386-2390`). **The player calls a fire mission, wipes fifteen attackers, and by every ledger in
the codebase he killed nobody.** Same for arty (`_arty_impact:579`, attacker `null`), WP
(`_wp_impact:622`, `null`), and his own claymores (`claymore.gd:58`, `null`).

**c) Punji traps: a red herring, and the council will waste time on it.** `punji_trap.gd:5` —
*"The VC laid these, so enemies never trigger them"*; `_physics_process:59-67` scans **only**
`GameManager.player` and group `allies`. **A punji trap can never kill an attacker.** Rule it out
and move on.

**d) Friendly fire and the satchel.** `sapper_charge.gd:59-60` detonates with
`spare_garrison = false` and `attacker = enemy` (the sapper). 250 damage / 14 m. Any *attacker*
inside that radius dies with `_last_attacker` = a VC sapper. If the break counter is naive, **the VC
blowing up its own assault element counts toward the player "holding them off."**

**e) The threshold is never reached and the siege runs forever.** This is the real one.
`_execute_assault` (`enemy_base.gd:1370-1371`) is `_move_toward(assault_objective, ...)` with **no
arrival test and no timeout**. `_poll_firebase_threat` (`:1026`) has **no siege clock**. The current
system has no end state at all — it ends because the four chargers die. At 50 men, if the survivors
stall at 300 m (a defect the briefing itself names at :52), the fight neither breaks nor ends, and
`_fsb_threat_active` latches on forever because 2+ men sit inside the 90 m ring.
**The siege needs a WALL-CLOCK timeout as well as a casualty threshold, or "dawn" as a hard break.**

### What this actually costs to build
A killer-attributed kill ledger is **not** a small change. It touches: the `died` signal signature,
every `apply_explosion_damage` call site that currently passes `null` (7+ sites), and the
`attacker == null` branch at `combat_manager.gd:149-150` that gives indirect fire its 0.4× friendly
softening — **that branch reads `attacker == null` as "indirect fire", so you cannot simply start
passing the player as the attacker of his own mortar mission without making his own steel four times
more lethal to his own squad.** That is a live gameplay regression hiding inside the "just track who
killed him" fix. Name it out loud before anyone estimates this.

**My recommendation, stated as a cost not a design:** the cheapest honest threshold is
**"attackers killed by ANY defending force" (garrison + squad + player + his called steel)** —
i.e. `state.kills` delta scoped to the siege group tags. It is *not* what the decree says
("killed by them"), it can be built on the existing counter, and it makes "hiding in a bunker while
your garrison dies for you" a legal win. **Somebody has to tell the Summoner that.** The alternative
is the full attribution rebuild above.

---

## 2. SURVIVORS "WITHDRAW" INTO NOTHING. THE SUMMONER'S NAMED FAILURE IS ALREADY REAL IN THE CODE.

Trace it end to end.

- `enemy_base.gd:1207-1221` — RETREAT is a per-man goal score. There is no formation break.
- `enemy_base.gd:1644-1676` `_execute_retreating` — a routed man sets `_retreat_bearing` **away from
  the threat**, slides along walls (`:1663-1671`), and runs at `move_speed * 1.25` (`:1674`).
  **There is no destination. There is no rally point. There is no distance at which he stops.**
- **There is no despawn.** `_live_enemies` is erased **only** in `_on_enemy_died`
  (`field_director.gd:65`). Repo-wide, `enemy_base.gd` calls `queue_free` on itself at **`:2411` and
  `:2456` — both are 45-second CORPSE cleanup timers after death.** A LIVING enemy is never freed by
  anything, ever.
- **There is no map clamp.** Grep for `map_size` / position clamping in `enemy_base.gd`: **zero
  hits.** The hunter spawner clamps its *spawn* point (`field_director.gd:105-106`) — nothing clamps
  a moving body. A routed man runs at the 1280 m map edge and stays there.
- **He never calms down.** `enemy_base.gd:898-902`: from COMBAT, after 8 s with no target,
  `_set_tier(AlertTier.ALERT)` — with the comment **`# never back to RELAXED`**.
- **Therefore his body never sleeps.** `_body_gate_open()` (`enemy_base.gd:534-536`) returns true if
  `alert_tier > AlertTier.RELAXED`. **A withdrawn survivor is permanently ALERT, so the WA-A2 body
  gate — the project's one measured AI-cost mitigation — is permanently OPEN on every single one of
  them, forever, for the rest of the operation.**

**The arithmetic of three nights.** 3 × d50, mean 25.5 = **~76 attackers spawned per operation**.
Break at 45% killed = ~34 dead. **~42 men withdraw and become permanent, full-cost, never-sleeping,
never-despawning bodies loitering at the map edge**, on top of the resident camp population and the
`_hunter_pool` of 12. They also permanently inflate `live_enemy_count()` (`:117-124`), and any
future consumer of it. This is precisely the failure the Summoner named in his own decree
(briefing:10-11) — and it is not a risk, **it is the current behaviour of `_execute_retreating`.**

**The withdraw verb must be built, and it must include a despawn.** The only honest options:
(a) run to a bearing off-axis and `queue_free` past N metres from `fsb_center` with the player not
looking (needs `CombatManager.perceivable`, already used by the body gate), or (b) reuse
`_check_tunnel_retreat` (`enemy_base.gd:584`) as the fiction — they go to ground and vanish.
Either way, **a "withdrawal" that does not free the node is not a withdrawal, it is a leak.**

### The sappers cannot withdraw AT ALL — structurally
`enemy_base.gd:1317-1319`: `if assault_objective != Vector3.ZERO: _execute_assault(delta); return`.
**The goal FSM never touches a driven man's legs.** A sapper with a live `SapperCharge` is exempt
from RETREAT by construction. The decree says "survivors withdraw"; **2–12 men per night are
mechanically incapable of it.** They will reach the bench or die. Whatever break rule you write,
you must ALSO write `charge.abort()` → `assault_objective = Vector3.ZERO` → hand him back to the FSM,
or your break condition fires and the sappers keep walking in.

---

## 3. SAPPER BREACH: NIGHTS 2 AND 3 ARE FREE FOR THE ENEMY AND SILENT FOR THE PLAYER

`on_firebase_breach` (`field_director.gd:1085-1093`) is latched by `_firebase_breached`, once per
operation, with the comment *"One depot, one breach - a second sapper cannot destroy what is already
gone."* That comment is correct for one raid of 3 sappers. Across three nights it produces:

- Night 1, sapper #1 reaches the bench: mortars→0, arty−1, `depot_loss` persisted, **one toast**.
- Night 1, sappers #2–#12: each still detonates a **250-damage / 14 m** blast (`sapper_charge.gd:15-18`)
  that `spare_garrison=false` (`:59-60`) means **kills promoted garrison defenders outright** — and
  produces **no message, no cost, no signal of any kind.**
- Nights 2 and 3: **every sapper is now a pure garrison-deleter with zero player-facing consequence.**
  Up to 24 more satchels going off inside the wire and the game says nothing.

The Fossil-Law replacement is not just deleting the latch. **The breach needs a target list** — the
dump (once), then the MG emplacements (`mg_emplacements` group, `garrison_defender.gd:97`), the
bunkers, the radio, the aid station. Otherwise nights 2–3 have nothing to breach and the escalation
the decree promises runs *backwards*: night 1 is the expensive night, nights 2–3 are cheaper.
`_sapper_aim` is a **single** `Vector3` set once from `built.bench` (`setup_patrol:910-912`) — one
point, for up to 36 sappers across three nights.

---

## 4. THE GARRISON IS A ONE-SHOT RESOURCE, AND NIGHT 3 IS DEFENDED BY NOBODY

`_garrison_stand_to` (`:1066-1078`) is latched by `_garrison_stood_to`. But **removing the latch is
not enough, because promotion is destructive and irreversible:**

`garrison_defender.gd:42-48` — promote() calls `civ.remove_from_group("firebase_garrison")`,
`remove_from_group("civilians")`, `AgentRegistry.unregister`, `queue_free()`. **The Civilian is
destroyed.** After night 1 the `firebase_garrison` group is **empty**. Un-latching
`_garrison_stood_to` gives you a loop over an empty array on nights 2 and 3.

The garrison ceiling is **24 men** (`site_planner.gd:726` `FSB_GARRISON_MAX_MEN`). Against a
mean-25.5-man assault with 2–12 satchels going off inside the wire, night 1 casualties will be
heavy. **There is no stand-down, no re-promotion, no replacement, and no reinforcement path.**
Night 3's "siege" is 25 men attacking a base defended by the player, his squad, and whatever
fraction of 24 survived nights 1 and 2 — with a d50 that does not care.

**This is the decree's real difficulty curve, and it is inverted by accident:** the assault size is
i.i.d. across nights while the defence monotonically decreases. Night 3 is *statistically harder* than
night 1 by a large margin, and nothing in the decree asked for that.

**SACRIFICED, and nobody will say it out loud:** the moment the garrison stands to, **24 Civilians
with work-post schedules, idle chains and occupations are permanently deleted from the firebase.**
The living firebase — the men at the mess, the gun crew, the radioman, the thing that makes fsb_main
feel inhabited (Pillar 2) — **is spent by the first siege and never comes back for the rest of the
operation.** After night 1 the player's home is a fort full of static HOLD-order soldiers on 8 m
leashes (`ally_base.gd:855`). That is a real atmosphere cost of this decree and it is invisible in
every design doc.

---

## 5. THREE NIGHTS: WHAT "THREE NIGHTS" ACTUALLY IS IN THIS ENGINE

**Measure it.** `sim_clock.gd:17` `real_to_sim_ratio = 60.0`. One real second = one sim minute.
`period_at` (`:57-64`): NIGHT is 19:00–05:00 = **10 sim hours = 10 REAL MINUTES.** A full day is
**24 real minutes**.

**"Three nights in a row" is therefore ~72 minutes of unbroken real-time play**, with two 14-minute
days between them, and the player may not quit, may not die, and (see below) may not save.

- **He leaves on patrol during a siege.** `_poll_wire_gate` (`:920-944`) flips `patrol_out` at 120 m
  and calls `_bank_patrol` on return. Nothing in the siege path cares. **The player can simply walk
  out of the gate mid-assault**, and 50 attackers will grind the garrison down behind him while
  `_poll_firebase_threat` — which only runs when `patrol_out` — now dutifully fires the crisis it
  refused to fire while he was standing in it. **The gate that the briefing correctly calls fatal
  (:48-50) is fatal in BOTH directions: silent at home, and it rewards abandoning the base.**
- **He never returns.** Nothing ends the siege. See §1(e).
- **He saves.** `save_data.gd:15-17`:
  `## MissionSection reserved for Phase E (full save-anywhere): objective mask, live enemies, craters,
  heat. Schema slot exists so migration is a no-op later.` `var mission: Dictionary = {}` — **empty.**
  **Live enemies are not serialized. At all.** A save during a 50-man night assault stores the
  player's position/ammo (`PlayerSection`), the campaign dict, and `operation_seed`. On load the
  world regenerates from the seed and **the siege is gone** — 50 attackers, the garrison's promotion
  state, `_firebase_breached`, `_garrison_stood_to`, the night counter, all of it. The **only** thing
  that survives is `CampaignState.depot_loss` (`:1091-1092`, proven by
  `test_firebase_defense.gd:299-304`).
  **Save-scumming a siege is not an exploit the player has to discover — it is the default behaviour
  of the save system.** And nothing in the decree's three-night run can survive a save.
- **He dies.** `_on_player_died` → `fail_mission("KIA")` (`:141-142`). The night counter, wherever
  it lives, must survive that or nights 2–3 are lost — and if it lives in `CampaignState` it must
  also survive the seed-regenerated world.

**Where does the night counter LIVE?** It cannot live on `FieldDirector` (rebuilt per world build).
`CampaignState` is the only durable store proven to round-trip
(`test_firebase_defense.gd:300-304`). That is the answer, and it needs a `consecutive_siege_nights`
field plus a **reset rule** — the decree says night 4 cannot fire, so something must zero the counter
on the first quiet night, and `_maybe_launch_sappers`' existing dawn reset (`:1100-1102`) is
per-*day*, not per-quiet-night.

---

## 6. PERFORMANCE: BOTH OF THIS PROJECT'S AI MITIGATIONS ARE INERT DURING A SIEGE, BY CONSTRUCTION

The briefing's question 4 offers the council two mitigations. **Read them.**

**(a) ADR-025 LOD tiers — the ADR is VOID.** `production/adr/ADR-025-lod-tier-simulation.md:3-10`:
*"**Status: SUPERSEDED 2026-07-20** — never ratified... **Do not extend `WorldSim`, and do not wire
`materialize_near`/`dematerialize_far`.**"* **There is no node-culling LOD in this game.** The only
live LOD is `_update_think_lod` (`enemy_base.gd:37-41`), a *think-rate* LOD on a 2-second cadence.
It sheds think frequency; it does not shed a body, a hitzone, a `move_and_slide`, or a draw call.
**Any architect who answers question 4 with "ADR-025 LOD tiers" is quoting a retracted document —
which is exactly the drift the POINTER LAW exists to stop, and it is in the briefing itself.**

**(b) The EnemySquad hot-set caps the fight at 12 men — which is a GAMEPLAY defect, not a
mitigation.** `enemy_squad.gd:37` `HOT_CAP: int = 12`. `enemy_base.gd:596-601`: a COMBAT unit that
cannot claim a hot slot runs `_think_cheap_combat()` — **no per-think targeting, no LOS raycast.**
With 50 attackers, **38 of them are cold.** They keep physics and perception
(`enemy_squad.gd:35-36`) but they do not run the combat brain. And the hot slots are a **global**
static dictionary shared with the garrison's own attackers, camp defenders, and hunters.

**The consequence the perf architect will call a win and the game-designer must call a disaster:
the 50-man siege is a 12-man firefight with 38 spectators.** It will not feel like death-or-life —
it will feel like a crowd standing in the dark while a dozen men fight. Raising `HOT_CAP` for the
siege is the obvious move and it is exactly what the measured numbers forbid.

**(c) The WA-A2 body gate closes on nobody in a siege.** `_body_gate_open()`
(`enemy_base.gd:534-536`) returns true for `current_state == COMBAT` **or** `alert_tier > RELAXED`.
Every attacker is spawned ALERT (`field_director.gd:1144`) and goes COMBAT on contact.
**Gate open, 100%, for all 50.** PERF_LEDGER's own A2 rows say this out loud:
*"in THIS bench the gate never closes — hot_start puts every unit in COMBAT tier (gate open by
contract)... 0% gated is the CORRECT census for a firefight."*

**The measured numbers, and they are not comfortable:**
- PERF_LEDGER W0 row: **65–67 live units → AI physics wall ~38–40 ms per tick.** Attribution:
  hitzone sync ~10 ms, `move_and_slide` ~9 ms, anim/execute remainder ~18 ms. **Perception rays and
  think are ~6% of it** — the wall is the BODY, and the body is exactly what a siege cannot gate.
- Night-arena 18v18 (`ai_stress_arena`, dense jungle, flares, fires): **18.8 fps native Forward+ /
  22.3 at the shipped 0.75.** *"NOTHING CLEARS THE 30 FPS GATE IN THE NIGHT ARENA."*
- Shipped patrol world at the fsb_main spawn, ship parity: **~34 fps**, canopy the only lever above
  noise (+6.3).

**A 50-attacker siege is 50 + up to 24 garrison + 6 squad + player ≈ 81 bodies — larger than the W0
65-unit bench that measured a ~38–40 ms AI wall — at NIGHT, inside the firebase (the densest mesh
site in the game: 678 meshes / 1,116 bodies), with mortar impacts running
`DamageSystem.apply_damage` terrain deformation (`field_director.gd:728`) and
`GunFX.play_explosion_3d` per round.** On the owner's Intel UHD this is not a 23-fps problem, it is
plausibly a single-digit one. **No architect should hand the Summoner a siege plan without saying
that the honest mitigation set is empty:** LOD is a void ADR, the body gate is contractually open,
and the hot-set "mitigation" works by turning 38 attackers into scenery.

**One thing that IS cheap and nobody will propose it because it is boring:** ADR-031 destruction and
crater deformation on every enemy mortar round is the discretionary cost here. `_mortar_impact:727-728`
only deforms at `intensity >= 1.0` — the enemy's walking barrage should deform on a strict *cap*
(the friendly path already caps craters at 2 of 6 rounds, `:580`), or the terrain rebuild budget
will eat the siege's frame time for visual gravy.

---

## 7. THE ENEMY MORTAR — THE BRIEFING'S OWN FINDING, ANSWERED

There is genuinely no enemy indirect fire. `_run_mortar_mission` / `_fire_shell` / `_mortar_impact`
(`:586-660, :721-730`) are the friendly path and they are **not neutral**:

- `_fire_shell:656-659` computes the shell's azimuth as `ground - fsb_center` and spawns the round
  **on the bearing FROM THE FIREBASE**. An enemy mortar reusing this path fires **outward from the
  base at its own target inside the base** — visually backwards.
- `_run_mortar_mission:587` emits the player's toast and `_radio_vo("mortar_mission")`.
- `_mortar_impact` passes `attacker = null`, which `combat_manager.gd:149-150` reads as **"indirect
  fire — do only 0.4× to your own men."** **An ENEMY mortar walking onto the firebase would be
  softened to 40% against the player's squad and the garrison by a branch written to protect the
  player from his own steel.** Reusing this path without splitting that branch makes the enemy
  barrage a light show.

The ranging-then-tightening walk is genuinely cheap to build on `Ballistics.fire_arc` +
`_fire_shell`'s shell path — but it needs **its own impact terminal** with a real attacker and its
own firing origin. Say it plainly: **this is a new system, not a reuse.** Also note the mortar is the
one part of the siege that hurts the player **inside the bunker he is hiding in**, which is the only
mechanic in the whole decree that answers §1(a). That makes it load-bearing, not flavour.

---

## 8. ONE AXIS: WHAT IT COSTS

The decree's axis rule is the right call for findability and I will not re-litigate it. Three costs:

1. **The current bearing is DETERMINISTIC and identical every night.** `launch_sapper_assault:1120-1122`
   seeds `rng` from `hash(Vector2i(fsb_center.x, fsb_center.z)) ^ 0x5A9927` — **a constant for a given
   operation.** Three nights of siege would come from **exactly the same compass bearing every time.**
   The player learns it on night 1 and pre-sights night 2 and 3. The seed must take the night index.
2. **A single axis + the MG emplacement covering it = a shooting gallery**, and the garrison's MG is
   AI-manned (`garrison_defender.gd:63-71`). If the axis lands on a manned Pig (42 dmg,
   `data/weapons/m60.tres`), the AI wins the siege without the player. If it lands away from the
   guns, the garrison is irrelevant. **The axis choice silently decides whether the player matters.**
   It should be chosen *relative to the emplacements*, not by a bare bearing hash.
3. **`SAPPER_RING_MIN/MAX` is 300–500 m with `±0.35 rad` spread** (`:785-786, :1124-1126`). At 500 m
   that arc is ~350 m wide — 50 men in it are **not** one axis, they are a broad front. The angular
   spread must shrink as the count grows, or "one overall axis" is not what gets built.

---

## 9. WHAT IS SACRIFICED — NAMED, NO FREE LUNCHES

1. **The living firebase, permanently.** 24 scheduled Civilians deleted on the first stand-to
   (`garrison_defender.gd:42-48`), never restored. Pillar 2 pays for this decree, once per operation.
2. **The frame budget, with no mitigation left in the bank.** ADR-025 is void; the body gate is open
   by contract in a firefight; the hot-set only "helps" by silencing 38 of 50 attackers. Every future
   perf request will now be measured against a scene that this decree made unwinnable.
3. **Save/load integrity, or a big new system.** Either sieges are save-scummable (today's
   behaviour — `save_data.gd:15-17` serializes zero live enemies) or Phase E full mission
   serialization gets built, which is a project of its own.
4. **The "player kills them" fantasy**, unless a killer-attributed ledger is built through
   `enemy_base.gd:5` `died`, every `apply_explosion_damage(… null)` call site, **and** the
   `attacker == null` friendly-softening branch at `combat_manager.gd:149-150`.
5. **Freedom, quietly (Pillar 3).** A three-night siege that cannot be saved through is a ~72-minute
   forced-attendance window. The player who wants to walk out on patrol is either abandoning his base
   or scumming it. **This decree, for its duration, is the most rail-like thing in an
   explicitly no-rails game.** That is the tradeoff to name to the Summoner: the siege buys
   death-or-life stakes with the player's freedom to leave, and there is no version of it that does
   not.
6. **Whatever was next.** The mannable MG emplacement, the FP viewmodel pipeline (which the owner
   ruled TOP PRIORITY on 2026-07-25), and PLAYTEST R4 — the standing session entry gate, still
   undischarged. **This decree is not free in calendar time and the arbiter should say so.**

---

## 10. THE SHORT LIST OF THINGS THAT WILL BREAK ON DAY ONE OF IMPLEMENTATION

| # | defect | pointer |
|---|---|---|
| 1 | `2d6` sappers can exceed a `d50` count | decree arithmetic, briefing:22-23 |
| 2 | no killer attribution exists anywhere | `field_director.gd:63`, `enemy_base.gd:5`, `:2271` |
| 3 | mortars/arty/claymores pass `attacker=null` | `:726`, `:579`, `claymore.gd:58` |
| 4 | fixing (3) breaks friendly-fire softening | `combat_manager.gd:149-150` |
| 5 | retreat has no destination, no despawn, no map clamp | `enemy_base.gd:1644-1676`; `field_director.gd:65` |
| 6 | survivors never leave ALERT → body gate never closes | `enemy_base.gd:902`, `:534-536` |
| 7 | sappers are FSM-exempt and cannot withdraw | `enemy_base.gd:1317-1319` |
| 8 | `firebase_garrison` group is EMPTY after night 1 | `garrison_defender.gd:42-48` |
| 9 | one breach target, one `_sapper_aim` Vector3 | `field_director.gd:801`, `:910-912`, `:1085-1088` |
| 10 | live enemies are not serialized — a save deletes the siege | `save_data.gd:15-17` |
| 11 | assault bearing is constant per operation | `field_director.gd:1120-1122` |
| 12 | hot-set caps the fight at 12; 38 attackers are scenery | `enemy_squad.gd:37`; `enemy_base.gd:596-601` |
| 13 | briefing cites ADR-025 as a mitigation; ADR-025 is void | `ADR-025…md:3-10` |
| 14 | enemy mortar reusing `_fire_shell` fires outward from the base | `field_director.gd:656-659` |
| 15 | no siege timeout — the threshold may never be reached | `enemy_base.gd:1370-1371`; `field_director.gd:1026` |
| 16 | 3 flares vs up to 36 stealth sappers over three nights | `save_data.gd:118`; `field_director.gd:664-672`; `test_firebase_defense.gd:223-233` |

**On #16, since nobody else will check the player's pockets:** the *only* proven counter to a
sapper's night stealth is an illumination flare — `test_firebase_defense.gd:223-233` measures a sapper
as invisible at 45 m at night (cap 56 × 0.6 = 33.6 m) and **visible again under a flare**. The player
carries **`flare_count: int = 3`** (`save_data.gd:118`) and the resupply drop is latched
`supply_used` — **once per operation** (`field_director.gd:664, 672-674`). Three flares and one crate,
against 3 nights × 2–12 sappers, in ten-minute nights. **The decree is unwinnable on its own stealth
terms unless flares are replenished or the siege lights itself** (the enemy's own mortar flashes, a
burning hootch, an ADR-031 fire). That is the cheapest fix in this document and it is the one most
likely to be missed.
