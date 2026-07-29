# LEAD PROGRAMMER — THE SIEGE (v2), architecture / ownership / frame budget

**Date banner:** every claim below was read against the live tree on 2026-07-28. Pointers are
`file:line` as of that read. Nothing here is quoted from a plan.

---

## 0. THE HEADLINE, FOUR LINES

1. **There is already exactly ONE enemy-spawn authority** — `FieldDirector.spawn_tracked_enemy`
   (`scripts/missions/field_director.gd:31-45`). The siege must not become a second one. A
   `SiegeDirector` is correct as a **state owner**, forbidden as a **spawner**.
2. **The 4-man element does NOT stall.** It closes — and then walks up to **130 m past the firebase**
   and fans out over an **~88 m** arc. VERDICT below, with lines.
3. **The frame cost of 50 bodies is the BODY, not the brain.** The hot-set (`HOT_CAP = 12`) caps the
   one bucket that is already only ~3% of the AI wall. `EnemySquad` tiering buys the siege almost
   nothing, and the WA-A2 body gate buys it **exactly zero** by construction.
4. **ADR-025 is not a mitigation** — it is SUPERSEDED at its own line 3
   (`production/adr/ADR-025-lod-tier-simulation.md:3-19`). Budget nothing against it.

---

## 1. OWNERSHIP — who owns the siege

### 1.1 The spawn authority already exists and is already singular

Repo-wide grep for spawners:

| caller | file:line | verdict |
|---|---|---|
| `FieldDirector.spawn_tracked_enemy` | `field_director.gd:31` | **THE authority** |
| `LazyGroup._spawn_men` | `lazy_group.gd:88` | routes THROUGH it |
| `MissionGenerator._spawn_enemy_groups` | `mission_generator.gd:877` | routes THROUGH it |
| `_process_escalation` (hunters) | `field_director.gd:109` | routes THROUGH it |
| informer response | `field_director.gd:512` | routes THROUGH it |
| sappers / assault element | `field_director.gd:1127, :1140` | routes THROUGH it |
| `ai_stress_arena.gd:1392, :1500`, `gore_lab.gd:397` | bench scenes | deliberate bypass, not shipped |

`mission_generator.gd:714-717` states the contract in the negative and is worth quoting because it
proves the seam is *understood*, not accidental: friendlies are deliberately **not** routed through
`spawn_tracked_enemy` because that would file them in `_live_enemies` and register them as ADR-006
contact groups. **That is the one legitimate reason to bypass, and the siege has no such reason.**

`CampDirector` (`scripts/enemies/camp_director.gd`) is **not** a spawner — it only re-roles bodies
someone else made (`camp_director.gd:63-83` `attach`, `:108-129` `_apply_schedule_for_hour`). It is the
existing precedent for "a brain that owns behaviour but not population", and it is the right shape.

### 1.2 THE RULING

> **`FieldDirector` remains the sole spawn authority, the sole kill ledger and the sole crisis
> emitter. The siege gets a `SiegeDirector` node that owns SIEGE STATE AND CADENCE ONLY, holds a
> reference to the director, and creates every body by calling `director.spawn_tracked_enemy(...)`.**

Concretely:

- `class_name SiegeDirector extends Node`, added as a child of the `FieldDirector` at
  `setup_patrol` time (the same place `_sapper_aim` is captured, `field_director.gd:906-918`).
- It owns: the night latch (`sim_day`-keyed, §5), the d50/2d6 rolls, the axis bearing, the ranging
  ladder, the assault-strength ledger, the break check, the withdraw order.
- It owns **no** `EnemyBase.spawn_enemy` call, **no** second `_live_enemies` array, **no** second
  `state.register_group`. Bodies come back from `spawn_tracked_enemy` and it holds weak references.
- `FieldDirector` keeps `_poll_firebase_threat`, `_garrison_stand_to`, `on_firebase_breach`,
  `raise_crisis` — the siege *calls* them, it does not reimplement them.

**How the other brains stay out, named individually:**

| system | why it cannot collide | enforcement |
|---|---|---|
| `_process_escalation` hunters (`:88-114`) | spawns relative to `world.player`, 180–230 m ring | **must be suppressed while a siege is live** — otherwise hunters spawn *inside* the compound when the player is home. One `if _siege.is_active(): return` at `:90`. |
| `LazyGroup` (`lazy_group.gd:49-61`) | 120 m proximity latch off the *player* | a player sitting at `fsb_main` already woke everything in 120 m on patrol 1; no new interaction, but the siege must NOT create LazyGroups (it would double-latch). |
| `CampDirector` | re-roles only bodies handed to it (`:63-66`, needs ≥2 members) | do not `attach` siege men. They have an objective, not a schedule. |
| `MissionGenerator` | one-shot world build (`:857-878`) | untouched. |
| `DynamicMissionFactory` | dedup by entity id (`dynamic_mission_factory.gd:10, :39-41`) | see §4. |

**The failure mode being avoided, said plainly:** the divergent-systems blindspot is not "two files
spawn enemies" — it is "two files each believe they know how many enemies exist". `_live_enemies`
(`field_director.gd:12`) + `MissionState.register_group` (`:44`) + `EnemySquad._strength` peak tracking
(`enemy_squad.gd:129-133`) are three ledgers that already have to agree. A siege that spawns its own
men makes it four, and the break threshold (§7) reads one of them.

### 1.3 On the 1247 lines

`field_director.gd` is 1247 lines and already carries: mission state, spawning, escalation, fire
support (7 kinds), the fire menu / input handling, the wire gate, the route, crises, the firebase
attack, and the AAR. Splitting the siege out is **correct for the file**, and it is also the only
split that is currently safe, because the siege block (`:766-1146`) has exactly four inbound edges:
`_process` (`:161-162`), `SapperCharge._detonate` → `on_firebase_breach`
(`sapper_charge.gd:66-68`), `GarrisonDefender.promote` (`:1075`), and the two tests. Everything else
in that file is untouched by the extraction.

---

## 2. THE FRAME BUDGET — measured, extrapolated honestly, and the mitigations that exist

### 2.1 What is actually measured (nothing else may be quoted)

| row | population | figure | pointer |
|---|---|---|---|
| headless AI wall, W0 tree | 65–67 live | **~38–40 ms / physics tick** | `PERF_LEDGER.md:290-299` |
| headless AI wall, HEAD | 62–71 live | **14–15 ms / physics tick; 0.214–0.231 ms per unit** | `PERF_LEDGER.md:334-339` |
| bucket split | 65+ live | think **1.2 ms (≈3%)**; move_and_slide 9 ms; hitzone sync 10 ms; execute remainder 18 ms | `PERF_LEDGER.md:295-304` |
| windowed night firefight, Forward+ | 18v18 (~36 bodies) | **18.8 fps native / 22.3 at shipped 0.75** | `PERF_LEDGER.md:156-157` |
| windowed patrol world, day, stationary | ~13 live | **~34 fps** ship-parity | `PERF_LEDGER.md:683-702` |

**Two caveats that bind:** the headless rows measure CPU only (no renderer), and the only night-
firefight GPU row in the ledger is the **arena at ~36 bodies**, not the patrol world at ~85. There is
no measured number for what the decree asks for. Anyone who gives you one is guessing.

### 2.2 The honest per-frame estimate for the siege

Population at siege peak:

```
50 attackers (d50 max)
+  8–15 promoted garrison AllyBase   (garrison_defender.gd:26 promotes 1:1 per post)
+   4–6 player squad
+ ~13 resident ambient (PERF_LEDGER.md:364)
= ~75–85 live full-AI bodies
```

At the HEAD-measured **0.22 ms/unit/physics-tick** (`PERF_LEDGER.md:338-339`), that is
**≈ 17–19 ms of AI per physics tick, CPU, headless.** `physics_ticks_per_second` is 60
(`PERF_LEDGER.md:1052-1054`). At a rendered 30 fps that is **two physics ticks per frame ≈ 34–38 ms
of AI in a 33 ms frame budget.** The AI wall alone eats the frame before a single pixel is drawn.

I am stating that as an extrapolation of a measured per-unit cost, not as a measurement. It should be
treated as the *optimistic* bound, because:

- **the per-unit figure was measured with the body gate contributing 0%** (`PERF_LEDGER.md:341-347`),
  and a siege is the same case: `_body_gate_open()` returns true for anyone with
  `alert_tier > RELAXED` or `current_state == COMBAT` (`enemy_base.gd:535-536`). **Every one of the 50
  attackers is gate-open by contract. WA-A2 banks exactly zero during a siege.**
- **the hitzone bucket is understated.** `ai_usec_hitzone` is physics-side only, and
  `hitzone_builder.gd:164-166` connects an **ungated** closure to `skeleton_updated`, so the render-
  frame sync is counted nowhere (`PERF_LEDGER.md:1022-1024, :1055-1057`).

### 2.3 What the existing tiering does and does not buy

**`EnemySquad` hot-set (`enemy_squad.gd:37-41`, `HOT_CAP = 12` / `HOT_CEILING = 16`)** gates
`_think_full_combat` only, and only for `alert_tier == COMBAT` (`enemy_base.gd:596-601`). Think is
**1.2 ms of a 38 ms wall**. Capping it caps 3%. Worse for the siege: men at ALERT tier — which is
every attacker until the garrison opens up — **skip the tiering branch entirely** and run the full
`_update_perception` + `_update_line_of_sight` + `_evaluate_goals` + `_squad_sync` path at
`enemy_base.gd:603-609`. **The hot-set does not cover the approach phase at all.**

**`_update_think_lod` (`enemy_base.gd:37-52`)** is distance-from-player: 0.6 s beyond 150 m, 0.3 s
beyond 80 m, 0.15 s inside. During a siege the player is at the centre of the fight, so **every
attacker inside 80 m runs at the full 6.7 Hz.** This is the one dial that *is* live and *is*
siege-relevant, and it is currently player-distance only.

**`LazyGroup`** is irrelevant: the siege spawns hot.

**ADR-025 tiers are dead** (`ADR-025:3-19`, confirmed at `PERF_LEDGER.md:1047-1050`:
`world_sim.gd` is now a 34-line flat registry). Do not budget against them.

### 2.4 The mitigations that exist WITHIN Forward+ (ADR-001 / ADR-026 hold; no renderer swap)

Ranked by measured or statically-counted evidence, cheapest first:

1. **Fix the canteen regex — `model_actor.gd:407`.** The pattern anchors on a dot-digit suffix and
   matches retired `us_grunt_v3` naming; the shipping grunts use `canteen_l_002…_006` with
   underscores, so **every grunt renders 5 stacked canteens** (`PERF_LEDGER.md:1019-1021`, measured
   statically). ~4 extra draw calls per body. At 50 attackers + 15 defenders that is **~260 calls on a
   411–464-call non-canopy budget** (`PERF_LEDGER.md:896-903`). **This is the single largest GPU-side
   siege lever in the repo and it is a one-line regex fix.**
2. **Close the hitzone-sync leak — `hitzone_builder.gd:164-166`**, and collapse the 11
   `affine_inverse()` per man at `hitzone_builder.gd:225` to 1 (`PERF_LEDGER.md:1022-1026`). Hitzone
   sync is ~10 ms of the 38 ms wall at 65 units; it scales linearly with the siege.
3. **Extend `_update_think_lod` to be siege-aware.** Today it reads player distance only
   (`enemy_base.gd:46`). During a siege, an attacker 200 m out on the far arc still matters to the
   fiction but not to the frame. Adding "and not perceivable" (the `CombatManager.perceivable` test
   the body gate already uses, `enemy_base.gd:541`) pushes the far half of the assault to 0.6 s think.
   **Do NOT weaken the witness heartbeat** — ADR-005 guard-rail, `enemy_base.gd:587-590`.
4. **`alphaMode:"BLEND"` → alpha-scissor on the firebase.** `fsb_main.glb` carries **20 alpha-BLEND
   materials, 19 identical `Sandbags*` on a 64×64 texture, in the transparent pass, filling the screen
   at the exact measured pose** (`PERF_LEDGER.md:1039-1042`). A night siege is fought looking *at* that
   geometry from inside it. This violates ADR-026:30 already; the siege makes it expensive.
5. **Cap the mortar impact rate, not the mortar count.** `_mortar_impact` →
   `CombatManager.apply_explosion_damage` walks four `AgentRegistry` snapshots
   (`combat_manager.gd:138, :161, :178, :188`) and runs `_can_damage_multipoint` — **8 raycasts per
   candidate in radius** (`combat_manager.gd:210-219`). With ~85 bodies packed on ONE axis
   (the decree's own §7) inside a 10 m `MORTAR_BLAST_M` (`fire_plan.gd:17`), a single shell can fire
   ~8×N rays in one frame. Rounds must be spaced, never salvoed on the same tick.
6. **Destruction is already throttled** (`destructible.gd:9, :41` drains
   `WorldConfig.STRUCTURE_LEVELS_PER_FRAME` per frame; ADR-031 §3). No new work; do not bypass it by
   calling `Destructible` swaps directly from the impact handler.

**What I will not propose:** a renderer swap. ADR-026 Amendment A ratifies `forward_plus`, the
`project.godot` key is *absent* and Forward+ holds by desktop default (`PERF_LEDGER.md:21-27`), and the
measured Mobile gain (`:158-159`) is a decision the Summoner already declined. The levers above are
all inside Forward+.

**The tradeoff I am naming, because no decision is free:** at ~85 bodies the honest engineering
answer is that the siege will not hold 30 fps on the measured Intel UHD target even with all six
levers. The levers buy maybe a third of the deficit. **If the decree's 50 is non-negotiable — and it
is — then the frame cost is the price, and it must be paid by the Summoner's eyes at playtest
(`PERF_LEDGER.md:6-13` — no numeric gate; his eyes decide), not by an agent quietly shrinking d50.**

---

## 3. THE 4-MAN ELEMENT — VERDICT

**Question asked:** do the troopers spawned at `field_director.gd:1136-1144` (ALERT +
`last_known_target_pos = fsb_center`, no `assault_objective`) actually close on the wire, or stall
at 300 m?

### VERDICT: **NOT CONFIRMED — they do NOT stall. They close.** But the element is defective in a
### different and worse way: **it overshoots the firebase by up to 130 m and disperses across an
### ~88 m arc.** CONFIRMED, with the trace below.

**The trace, step by step:**

1. Spawn: `field_director.gd:1140-1144` — `spawn_tracked_enemy(..., "firebase_assault")` gives
   `squad_id = hash("firebase_assault")` (`:39`, ≥ 0), then sets `last_known_target_pos = fsb_center`,
   `target_last_seen_time = 0.0`, `_set_tier(AlertTier.ALERT)`. Ring radius
   `SAPPER_RING_MIN+40 .. SAPPER_RING_MAX+60` = **340–560 m** (`:1138`).

2. `_think()` at `enemy_base.gd:596` — tier is ALERT, not COMBAT, so the hot-set branch is skipped
   and the full non-combat path runs (`:603-609`). `target` is force-nulled at `:604`.

3. `_update_line_of_sight()` at `:1041` — **`target` is null, so it returns at `:1042-1045` without
   touching `target_last_seen_time`.** The counter only increments at `:1061`, which is unreachable
   when there is no target. **`target_last_seen_time` therefore stays pinned at 0.0 forever.**

4. `_evaluate_goals()` at `:1101` — no target, so the `:1117-1138` branch runs.
   `begin_hunt(squad_id, fsb_center, heading, now)` fires at `:1129`. `trail_heading` returns ZERO
   (fresh squad, no crumbs — `enemy_squad.gd:316-317`), so `heading = last_known_target_pos -
   global_position` (`:1128`) = **the inbound bearing toward the firebase**. Then `:1131`:
   `last_known_target_pos != ZERO and (hunting or target_last_seen_time < 5.0)` — the second clause is
   **permanently true** because of step 3. **`best_goal = INVESTIGATE`, forever.** `end_hunt` at
   `:1135` is unreachable.

5. `_update_state_for_goal()` `:1296-1297` → `AIState.ALERT`. `_execute()` `:1317` — no
   `assault_objective`, so the FSM runs → `_execute_alert(delta)` at `:1393`.

6. `_execute_alert` `:1397-1406` — `squad_id >= 0`, so the goal is `EnemySquad.hunt_point(...)`, and
   `hunt_point` only bails when `hunt_start <= 0.0` (`enemy_squad.gd:401`), which never happens
   because `end_hunt` was never called. So the men walk to `hunt_point`, every think, forever.

7. **Where `hunt_point` sends them** (`enemy_squad.gd:397-427`):
   - anchor = `hunt_anchor_now` = `fsb_center + heading * advance`, with
     `advance = min(HUNT_ADVANCE_MAX, HUNT_ADVANCE * elapsed * (0.4+det))` (`:332-341`).
     `HUNT_ADVANCE = 1.1 m/s`, `HUNT_ADVANCE_MAX = **130 m**` (`:303-304`).
   - radius = `min(HUNT_R_MAX*(0.65+0.6*det), HUNT_R0 + HUNT_GROWTH*elapsed*(0.6+det))`
     (`:431-442`) → **up to ~88 m** for an NVA regular.
   - wedge = `±HUNT_ARC_DEG (80°)` in `HUNT_STEP_DEG (32°)` slots (`:305-306, :411-421`).

   Walking 340–560 m at ALERT speed takes well over 100 s, by which time `advance` has already
   saturated at its 130 m cap. **The four men arrive at a point ~130 m PAST `fsb_center` along the
   inbound bearing, spread over an ~88 m arc, ~80° wide.** With `FSB_THREAT_M = 90`
   (`field_director.gd:775`), that puts the far men **outside the compound on the wrong side.**

**Consequences, said plainly:**

- They *do* trip `_poll_firebase_threat` in transit (they cross the 90 m ring), so the crisis and
  `_garrison_stand_to` fire. The current system is not inert.
- But the element has **no doctrine**: it does not stop at the wire, does not hold an axis, and its
  terminal state is "four men loitering on the far side of the base". **This is the decree's §7
  "lost enemy NPCs the player cannot find" — already shipping, already reproducible.**
- And it only presses at all because of the accident in step 3. `target_last_seen_time` not
  incrementing while `target == null` is a real defect (`enemy_base.gd:1042-1045`): it silently makes
  the `< 5.0` clause at `:1131` a constant `true` for every targetless ALERT man in the game. **Do not
  "fix" that line without knowing this element leans on it** — fix it and the current assault dies at
  the hunt's expiry (`HUNT_BASE_S 25 + HUNT_DET_S 65×det`, `enemy_squad.gd:307-308, :385-392`), i.e.
  roughly 77 s in, still 100–300 m out. **That is when it would truly stall at 300 m.**

**What the v2 siege must do instead:** give the assault an explicit objective. `assault_objective`
already exists and already works — `enemy_base.gd:1317-1319` routes to `_execute_assault` at `:1371`
(`_move_toward(assault_objective, delta, 1.15)`), which is the sapper's push-through-contact drive
and is probed at `tests/test_sapper_assault.gd:55-74`. It is currently reserved for
`silent_infiltrator` men, but the two flags are **explicitly independent** (`enemy_base.gd:63-66`:
silence is an invariant "independent of the assault-move override"). A LOUD trooper with an
`assault_objective` set to a **wire-segment point on the chosen axis** (not `fsb_center`) will drive
to the wire and fight from there, and the 130 m overshoot disappears because the hunt net is never
consulted. **No new movement system is required.**

---

## 4. THE `patrol_out` GATE — every consequence of removing it

`field_director.gd:1027`: `if fsb_center == Vector3.ZERO or not patrol_out: return`.

The decree is right that this is fatal — a siege that happens *to him at home* is silent under this
line. Removing `not patrol_out` has **six** consequences. Four are wanted; two are bugs that must be
fixed in the same change.

**Wanted:**

1. `_garrison_stand_to()` (`:1039`) fires while the player is home. Required — otherwise the garrison
   are passive Civilians during a home siege and the player defends alone.
2. `_fsb_threat_active` / `_fsb_wave` (`:1044-1045`) advance, so the wave key is real.
3. `emit_location(&"friendly_firebase_under_attack", ...)` fires (`:1049-1050`).
4. The `FSB_CLEAR_POLLS` re-arm (`:1054-1058`) becomes meaningful across a multi-wave night.

**BUGS CREATED — must be fixed in the same change:**

5. **The player will be tasked to sweep his own firebase.** `raise_crisis` (`:1005`) does
   `patrol_locations.push_front(loc)` at `:1009` **BEFORE** the `not patrol_out` guard at `:1010`.
   So even today the location is banked while he is home; it is only the toast that is suppressed.
   Then `_pick_patrol_location` (`:1149`) takes any entry with a `trigger_state` key **first, ahead of
   the route and the bearing scan** (`:1152-1159`), and `DynamicMissionFactory.location_for` always
   stamps `trigger_state` (`dynamic_mission_factory.gd:32`). **On the next walk-out, "SIX WANTS US
   SWEEPING …" points at `fsb_center`, 0 m away** (`rebark_patrol`, `:988-993`). Today one stale entry
   accumulates per operation; with the gate removed and three nights of waves it is one per wave.
   **Fix: `raise_crisis` must reject a `firebase_attack` whose `pos` is within the wire, or
   `_pick_patrol_location` must skip crisis entries of kind `firebase_attack`.** Prefer the former —
   a firebase attack is not a place to walk to when you are standing in it.

6. **`_garrison_stood_to` is a once-per-operation latch** (`:804`, checked `:1067-1069`). Three nights
   needs stand-to → stand-down → stand-to, **with the casualties from night 1 still missing on night
   2**. `GarrisonDefender.promote` destroys the `Civilian` (`garrison_defender.gd:42-48`) and cannot be
   reversed, so "stand down" cannot mean demotion. It must mean: the promoted `AllyBase` returns to
   `OrderMode.HOLD` at `post_anchor` (already the default, `garrison_defender.gd:58-60`) and the latch
   is replaced by a **per-man idempotency check** — promote anyone still in `firebase_garrison`,
   which is naturally idempotent because `promote` removes the man from that group at
   `garrison_defender.gd:42`. **Delete the `_garrison_stood_to` bool; the group membership IS the
   latch.** Casualties then persist for free: a defender killed on night 1 is simply absent.

**NOT a problem, verified:**

- **`DynamicMissionFactory` dedup is already correct.** `_seen` is keyed by `entity_id`
  (`dynamic_mission_factory.gd:10, :39-41`), and `field_director.gd:1048-1050` already XORs the wave
  counter into the key (`base_key ^ (_fsb_wave * 0x9E3779B1)`). Each new wave is a new key. The only
  residue is that `_seen` grows one entry per wave for the operation's life — bounded by wave count,
  not a leak worth code.
- **Marker spam is already handled** by `_fsb_threat_active` + `FSB_CLEAR_POLLS = 20`
  (`:813, :1040, :1054-1058`) — 20 × 0.5 s poll = **10 s of sustained clear** before a re-announce.
  Probed at `tests/test_firebase_defense.gd:328-362`.

**AND: a test inverts.** `tests/test_sapper_assault.gd:198-199` asserts *"sappers raised a crisis
while the player was inside the wire (should be silent)"* — i.e. **the suite currently guards the
exact gate the decree deletes.** That assertion must be rewritten to its opposite, not deleted, and
its negative control must move to something still true (e.g. a lone wanderer still does not raise a
crisis — `FSB_THREAT_MEN = 2`, `:776`).

---

## 5. ENEMY INDIRECT FIRE — reuse the SHELL, build a new IMPACT and a new MISSION

**RULING: reuse `_fire_shell` / `Ballistics.fire_arc` (the shell in the air). Do NOT reuse
`_run_mortar_mission` and do NOT reuse `_mortar_impact`. Three named coupling risks, all real.**

### Reuse — the shell path

`_fire_shell` (`field_director.gd:648-660`) is already generic: it takes a shell path, an impact
point and a terminal `Callable`, and hands off to `Ballistics.fire_arc`
(`scripts/combat/ballistics.gd:26-46`). `data/projectiles/mortar_81mm.tres` exists. Nothing about it
is friendly-specific except one line (below). This is the correct seam — building a second ballistic
path would be the textbook divergent system.

### Do NOT reuse `_run_mortar_mission` (`:586-603`)

It is welded to the player's economy, not to physics:
`toast.emit("FIRE MISSION … (%d left)" % fire_support["mortar"])` (`:587`), `_radio_vo` (`:588`),
`FirePlan.sheaf_scale(fo)` from the RTO's `fo_fac` (`:590`, `fire_plan.gd:40-41`), and the veteran's
4th round (`:591`). An enemy fire mission shares **none** of that. It needs its own function — and
that is where the decree's ranging ladder lives: the friendly path fires ONE wide spot round
(`MORTAR_SPOT_M = 15 m`, `fire_plan.gd:16`) then a tight sheaf; **the enemy path wants the opposite —
a long walk from wide to tight over minutes.**

### COUPLING RISK 1 — the azimuth is hardcoded to the firebase (a wrong-bearing tell)

`field_director.gd:656`: `var azimuth: Vector3 = ground - fsb_center`. For an ENEMY shell the impact
point **is** the firebase, so `azimuth ≈ Vector3.ZERO`. `Ballistics.firing_point` then falls back to
`Vector3.FORWARD` (`ballistics.gd:52-55`). **Every enemy shell would visibly arrive from due north**,
regardless of where the attack is coming from — and the decree's whole §7 is "one overall axis". The
enemy mortar must pass its own gun bearing explicitly. This is a real bug the reuse would inherit
silently: no crash, no error, just a permanent tell.

### COUPLING RISK 2 — the friendly danger-close discount (this one is severe)

`_mortar_impact` (`:721-730`) calls
`CombatManager.apply_explosion_damage(ground, int(140*intensity), 40, MORTAR_BLAST_M, **null**)`.
The `null` attacker is load-bearing: `combat_manager.gd:146-150` reads
`if attacker == null: damage = maxi(1, int(damage * 0.4))` **for allies**, so friendly indirect fire
does 40% to your own men on purpose. **An enemy mortar reusing `_mortar_impact` inherits that
discount and lands at 40% lethality against the player's squad and the promoted garrison — the exact
men it exists to threaten.** The enemy impact must pass a non-null source (the assault's mortar node
or the siege director) so the full damage lands. One argument, and it silently guts the decree's
"death or life" if missed.

### COUPLING RISK 3 — enemy shells kill the assault, and the assault's deaths count as the player's

`apply_explosion_damage` damages **enemies too** (`combat_manager.gd:187-205`), which is correct and
believable. But `FieldDirector._on_enemy_died` (`:63-68`) calls `state.record_kill()` for **every**
enemy death with **no attributor** — a man killed by his own side's mortar, by his own satchel
(`sapper_charge.gd:70` `take_damage(9999, ..., enemy)`), or by a friendly arty mission the player
called is counted identically. **The decree's break condition is "40 to 50 percent of the attack is
killed BY THEM"** — by the player. If the break reads `state.kills`, the enemy's own ranging rounds
walking across their own assault line will break their own siege. **The siege needs its own
player-attributed casualty counter**, or `_on_enemy_died` needs the killer passed through. `died` is
already the signal (`:40`); whether it carries a killer is the thing to check when building.

**Where the enemy mortar should live:** `SiegeDirector`. It is siege cadence, not fire support. It
must NOT be added to `fire_support` (`:962-965`) — that dictionary is the player's allotment and is
consumed by the fire menu.

---

## 6. FOSSIL LAW — the exact death list

When the v2 siege ships, these DIE in the same change (ADR-023; `tests/test_fossils.tscn` ratchets):

**`scripts/missions/field_director.gd`**

| symbol | line | note |
|---|---|---|
| `SAPPER_DATA` | `:783` | **CAUTION: referenced by `ai_stress_arena.gd:1392`** — the bench must be repointed or it breaks the arena build. |
| `SAPPER_COUNT` | `:784` | referenced by `tests/test_firebase_defense.gd:246, :249-250` |
| `SAPPER_RING_MIN` / `SAPPER_RING_MAX` | `:785-786` | superseded by the axis geometry |
| `SAPPER_CHANCE` | `:787` | superseded by the any-night / 3-night rule (decree §1–2) |
| `ASSAULT_DATA` | `:793` | |
| `ASSAULT_ELEMENT` | `:794` | referenced by `tests/test_firebase_defense.gd:251-252` |
| `_sapper_launched` | `:802` | the once-per-op latch the decree kills |
| `_sapper_rolled_night` | `:803` | replaced by a `SimClock.sim_day`-keyed latch |
| `_garrison_stood_to` | `:804` | replaced by `firebase_garrison` group membership (§4.6) |
| `_maybe_launch_sappers()` | `:1099-1110` | moves to `SiegeDirector` |
| `launch_sapper_assault()` | `:1115-1146` | moves to `SiegeDirector` |
| the `_process` call site | `:162` | |

**Tests that guard them and must be rewritten, not deleted:**

| test | lines | what changes |
|---|---|---|
| `tests/test_sapper_assault.gd` | `:159-189` `_check_launch_wiring` | calls `launch_sapper_assault(3)` and asserts the one-per-op cap at `:183-185` — **the cap is exactly what the decree kills** |
| `tests/test_sapper_assault.gd` | `:195-224` `_check_notification_path` | **assertion `:198-199` INVERTS** (§4) |
| `tests/test_sapper_assault.gd` | `:228-282` `_check_gating` | rebuilt around any-night + 3-night, `_sapper_launched` / `_sapper_rolled_night` references at `:239, :241, :251, :263, :274` all die |
| `tests/test_firebase_defense.gd` | `:243-263` `_check_assault_is_coordinated` | reads `FieldDirector.SAPPER_COUNT` / `ASSAULT_ELEMENT` |

**KEEP — these are NOT fossils and must survive the extraction:** `SapperCharge` whole
(`scripts/enemies/sapper_charge.gd` — the 2d6 sappers are the same behaviour, and its origin guard
`:27-28` is load-bearing), `GarrisonDefender` whole, `on_firebase_breach` (`:1085`),
`BREACH_MORTAR_LOSS` / `BREACH_ARTY_LOSS` (`:798-799`), `_sapper_aim` (`:801`, set from the bench
marker at `:910-912`), `FSB_THREAT_M` / `FSB_THREAT_MEN` (`:775-776`), `_fsb_threat_active` /
`_fsb_wave` / `_fsb_clear_polls` / `FSB_CLEAR_POLLS` (`:810-813`), `_poll_firebase_threat` (`:1026`),
`_garrison_stand_to` (`:1066`), `CRISIS_CALL["firebase_attack"]` (`:818`).

**Name the variable rename, or the probe eats it:** if `_sapper_aim` keeps its name while the system
is no longer called "sapper", that is a lie in the map. Rename to `_breach_aim` in the same change.

---

## 7. PROBES — every rig must have one that EXERCISES it

The standing lesson is that a rig without a probe that *drives* it is a rig nobody has run. One probe
per mechanism, each with the negative control named, following the pattern already established at
`tests/test_firebase_defense.gd:1-16`.

| # | mechanism | probe drives | negative control | pointer to the seam |
|---|---|---|---|---|
| 1 | **d50 / 2d6 rolls** | `SiegeDirector.roll_assault(rng)` as a **pure static** returning `{count, sappers}` | 10k draws: count ∈ [1,50], sappers ∈ [2,12], sappers ≤ count | keep the roll pure so it is testable without a world — the pattern at `SapperCharge.is_valid_objective` (`sapper_charge.gd:27`) |
| 2 | **any-night + 3-night cap** | drive `SimClock.sim_day` across 5 nights | night 4 in a row does NOT launch; a skipped night RESETS the run | `sim_clock.gd:41-46` (`sim_day` increments on 24 h wrap); `MissionWeather.is_night` is live — `_apply_time` is re-driven by `time_period_changed` (`mission_weather.gd:53, :80-83, :95`), verified |
| 3 | **the single axis** | launch, read every spawned man's bearing from `fsb_center` | all 50 within the axis arc; **negative:** a launch with the arc widened puts men outside it | `field_director.gd:1122-1126` is the existing bearing math to replace |
| 4 | **men CLOSE and STOP at the wire** | spawn on the ring, step `_execute` N times, assert distance-to-`fsb_center` **decreases AND converges to the wire radius, never < it and never > it** | **the control that catches the §3 bug:** the same men WITHOUT `assault_objective` overshoot past `fsb_center` — assert the new path does not | `enemy_base.gd:1317-1319`, `:1371`; the overshoot is `enemy_squad.gd:303-304` |
| 5 | **ranging → accuracy** | fire N enemy missions, record impact distance from aim | the sequence is **monotonically tightening**; **negative:** shell 1 lands outside the radius shell N lands inside | `field_director.gd:648-660` |
| 6 | **enemy shells hurt at FULL rate** | apply the enemy impact with an ally in radius; compare against the same blast with `attacker = null` | **the null-attacker version does 0.4×** — this probe is the guard on Coupling Risk 2 | `combat_manager.gd:146-150` |
| 7 | **the break threshold counts PLAYER kills** | kill 45% of the assault with the player as killer → withdraw; kill 45% with an enemy mortar / a satchel → **NO withdraw** | this is the whole of Coupling Risk 3 | `field_director.gd:63-68`, `sapper_charge.gd:70` |
| 8 | **withdraw leaves no man in the jungle** | after break, step the sim; assert every survivor is either despawned at the AO edge or converging on ONE withdrawal point | **negative:** without the order they scatter — the current `hunt_point` fan (`enemy_squad.gd:411-421`) | decree §7 |
| 9 | **garrison stands to across 3 nights, with casualties** | promote, kill 2 defenders, run to dawn, re-run the poll on night 2 | night 2 promotes **only** the men still in `firebase_garrison`; the dead do not come back | `garrison_defender.gd:26-48`; the group IS the latch (§4.6) |
| 10 | **crisis fires while the player is HOME** | `patrol_out = false`, 2 men on the wire, poll | the crisis fires **and** `_pick_patrol_location` does NOT subsequently task him to sweep `fsb_center` | `field_director.gd:1009-1010`, `:1152-1159` — this is the §4.5 bug, and probe 10 is the only thing that will catch it |
| 11 | **no second spawn authority** | source scan: `EnemyBase.spawn_enemy` callers outside `field_director.gd` + the two bench scenes | **fails the build if the siege adds one** — the same shape as `tests/test_fake_lights.gd`'s spawner census (`PERF_LEDGER.md:472-477`) | §1 |
| 12 | **fossils** | `tests/test_fossils.tscn`, already in the suite | the ceiling only ratchets down (`fossil_baseline.json:3-4`) | §6 |

**Probe 11 is the one I would fight for.** It is the only mechanism in this list that defends the
architecture rather than a behaviour, and the divergent-systems blindspot is the failure this project
is most prone to. It costs ~20 lines.

---

## 8. WHAT I AM SACRIFICING (no free lunches)

- **The frame.** ~85 full-AI bodies at the measured 0.22 ms/unit is ~34–38 ms of AI per rendered
  frame at 30 fps. The six levers in §2.4 recover perhaps a third. **The siege will be the heaviest
  thing in this game, and the honest position is that it is paid for, not optimised away.**
- **The `target_last_seen_time` accident** (`enemy_base.gd:1042-1045`) is a genuine defect that the
  current assault leans on. Fixing it and shipping the siege are the same change; fixing it alone
  would kill the existing raid, and shipping the siege alone would leave a live landmine for the next
  agent who touches ALERT-tier behaviour.
- **A `SiegeDirector` is a new class**, and every new class is a fossil candidate. It earns its
  existence only because it *removes* ~90 lines from `field_director.gd` in the same change (§6). If
  the siege ships as a `SiegeDirector` **beside** a surviving `launch_sapper_assault`, this analysis
  has been implemented wrong.
