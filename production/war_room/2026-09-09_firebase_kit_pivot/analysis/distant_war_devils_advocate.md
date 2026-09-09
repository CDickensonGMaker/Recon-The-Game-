# DEVIL'S ADVOCATE — MAY THE WAR AT RANGE BE RESOLVED ABSTRACTLY?

**Matter II, council of 2026-09-09.** Every claim below carries `file:line` or a number. Where I could
not measure, I say so in those words.

**My verdict in one line:** the design question deserves a YES-with-conditions, but it must not be
built now, because **the shipped demo contains 3–4 distant full-fidelity bodies** and **the stutter he
reported has a measured cause that has nothing to do with distant simulation.**

---

## OBJECTION 1 (RANKED FIRST) — THE PERF PRIZE IS ~3 MEN. MEASURED.

The enthusiasm assumes there is a crowd out there paying full price. There is not.

**`LazyGroup` already IS the abstraction, and it is more aggressive than anything proposed here** — it
does not resolve a distant group cheaply, it declines to create it at all.

- `scripts/missions/lazy_group.gd:8` — `@export var activation_range: float = 120.0`
- `scripts/missions/lazy_group.gd:59` — `if player.global_position.distance_to(global_position) > activation_range: return`
- `scripts/missions/mission_generator.gd:945` — `lg_p.activation_range = 140.0` (enemy groups)
- `scripts/missions/mission_generator.gd:1023` — `fp.activation_range = 140.0` (friendly patrols)
- `scripts/world/ambient_encounters.gd:289` / `:363` — 120.0 / 140.0

**No lazy body exists beyond 140 m of the player. Ever.**

Now the demo's actual roster, `plan_demo_world`, `scripts/missions/mission_generator.gd:812-841`:

| Group | Count | `lazy` | Sited |
|---|---|---|---|
| `village_defenders_0` | `rng.randi_range(3, 4)` | **false** | village, `:741-746` — `fsb_center + v_dir * 185.0`, band ±60 m |
| `treeline_watchers` | `rng.randi_range(3, 5)` | **true** | `fsb_center + … * 190.0` |
| `camp_mortar_crew` | `3` | **true** | `fsb_center + t_dir * 300.0` |
| `zpu_crew` | `2` | **true** | same camp |
| friendly patrols | `2 × 4` (`:1002-1003`) | **true** (140 m) | AO |

**THE COUNT: the demo's entire persistent distant-body population is `village_defenders_0` — 3 to 4
men.** Every other group in the AO is lazy and does not exist until the player is inside 140 m, at
which point it is not distant any more.

And the demo's own line of code says why, verbatim (`:811`):

> `# Light daytime presence only - the siege brings the real enemy at night.`

**Then the second half of the prize is already banked too.** Distant AI think is ALREADY
distance-throttled — `scripts/enemies/enemy_base.gd:41-56`:

```
d > 150.0  -> _think_interval_current = 0.6     # 4x throttle
d >  80.0  -> _think_interval_current = 0.3     # 2x
else       -> 0.15
```

So the arithmetic on the enthusiasm's own numbers (`marching_cell.gd:1-8`: AI think ~1.2 ms of a
38–40 ms wall):

- Think is ~3% of the wall to begin with.
- Beyond 150 m it is already running at **one quarter rate**.
- The population it runs on beyond 140 m is **3–4 men**.

**Abstract resolution of the distant war, applied to the product that ships on 2026-09-06's shape,
saves a quantity indistinguishable from zero.** The 45-man siege is the only crowd this game has, it
is not distant, and it is already handled by `MarchingCell`.

### An independent confirmation, arrived at from the other direction

I did not need to trust my own reading. The 2026-09-07 demo audit counted the same population from the
player's side, and landed on the identical number (`recon-demo-audit-2026-09-07.md:28-30`):

> *"pre-siege is **one fixed 3-4 man group at 165-185 m** plus 2-3 lazy patrols."*

**Two routes — my code walk of `plan_demo_world`, and a playthrough audit — converge on 3-4 men.** Per
the project's own War Room doctrine, convergence from different doors is the strongest signal this
process produces. **The count is not in doubt.**

**This is the finding that should decide the phasing.** The matter is real as *design*. As *perf* it is
post-demo, and building it now spends the hours on the one part of the frame that was already cheap.

---

## OBJECTION 2 — HIS STUTTER HAS A KNOWN CAUSE, AND IT IS NOT DISTANT AI

The council is at risk of answering a question he did not ask. Here is what he actually hit.

### The "ambient" napalm is not ambient. It is scripted, and it is the FIRST ordnance of the run.

`scripts/levels/demo_game.gd:299-343`:

```
const NAPALM_EARLY_S: float = 35.0
const NAPALM_RANGE_M: float = 210.0
...
if not _napalm_early_done and _clock >= NAPALM_EARLY_S:
    _napalm_early_done = true
    _strike_at(d, d.fsb_center, PI * 0.5, "SOMEBODY ELSE'S WAR - NAPALM ON THE TREELINE")
```

**T+35 seconds**, 210 m out, while the player is barely off the bunk (the squad moves out at T+10 s).
It is the first explosive event of a session — the single worst place in the arc to put a cold path.

Note also: `AmbientWar.KINDS` is `["artillery", "mortar", "tracers", "burning", "gunship_attack"]`
(`scripts/ai/ambient_war.gd:12`). **`AmbientWar` never drops napalm.** What he heard was this scripted
beat, or a `SIEGE_AIR_BEATS` pass (`demo_game.gd:324-331`, four of the seven carry napalm or CBU).

### The mechanism, traced end to end

`scripts/gameplay/fire_plan.gd:31` — `const NAPALM_DROPS: int = 9`
`scripts/vehicles/cas_airplane.gd:26` — `const NAPALM_STAGGER: float = 0.1`
→ **9 explosions inside 0.9 s.**

Each one lands in `CombatManager.apply_explosion_damage`, which calls, with **no player-distance gate
whatsoever** (`scripts/autoload/combat_manager.gd:201`):

```
TreeBreakSystem.apply_blast(center, radius)
```

→ `scripts/world/tree_break_system.gd:474` / `:676` → `vm.add_fell_entries(entries)`
→ `terrain/vegetation/vegetation_manager.gd:599-600` → `_scatter_epoch += 1`

And the vegetation manager's own header says what that used to cost
(`terrain/vegetation/vegetation_manager.gd:421-422`):

> *"…invalidate the scatter of every chunk on the map, and an assault fells trees continuously —
> measured 2026-09-09: `veg.build_scatter` back at **80.1 ms** inside the 45-man fight."*

**A napalm run 210 m away paid a MAP-WIDE vegetation rebuild, nine times in 0.9 seconds.** The cost is
100% distance-independent by construction — `apply_blast` never asks where the player is.

### The verdict, against the brief's four options

**(b), with a residue of (a) that is closed, and one honest unknown.**

- **(a) — the first-strike cache warm is FIXED and I verified the fix is live.** `PERF_LEDGER.md:1283`
  (`2026-08-31 - THE RAID, MEASURED ALONE FOR THE FIRST TIME`) measured `first burn patch (cold)`
  57.1/60.7 ms and `first explosion (cold)` 60.9/64.3 ms — **~121 ms in one frame on the first bomb of
  a mission**, cause `GunFX`/`FireHazard` lazy sheet caches. Fixed by `GunFX.warm()` + `FireHazard.warm()`.
  I confirmed both calls exist in shipping code: `scripts/levels/game_world.gd:56-57` (and mirrored at
  `scripts/levels/ai_stress_arena.gd:325-326`). This should no longer be what he feels.
- **(b) — the crater / vegetation chunk rebuild is the live one**, measured at 80.1 ms as recently as
  **today**, and halved to 21.4 ms by tonight's per-chunk invalidation. A napalm beat is exactly the
  trigger. **This is his stutter.**
- **(c) something new** — not indicated; every symptom is accounted for.
- **(d) unknown** — one part genuinely is: whether the build in his hands tonight contained tonight's
  per-chunk fix, and what the residual is on his machine. **No post-fix player-side row exists.** I will
  not invent one.

### A precision the council must not fumble

`PERF_LEDGER.md:1418` voids the measurement window 2026-08-07..2026-09-08. **It does not void the
2026-08-31 raid numbers.** The void is specifically about rows *stating a render scale*
(`PsxLook` wrote 1.0 while the rows claimed 0.75). The raid figures come from
`tools/probe_raid_cost.tscn` — headless CPU microseconds, no render scale in the measurement. They
stand. I flag this because the temptation to wave the void flag at an inconvenient number is real, and
it would be wrong here.

### HE JUST RAN THE EXACT TEST THE LEDGER ASKED FOR

This is the part the council must not miss. The 2026-08-31 raid fix was **never closed**, and the
document says precisely what would close it — `production/PLAYTEST_FINDINGS_2026-08-28.md:282-284`,
verbatim:

> *"**What is NOT proven: this is headless CPU truth. Call a napalm run and a CBU run in the demo and
> tell me whether the first strike still hitches — that is the only thing that closes this.**"*

**Tonight he called a napalm run in the demo and reported that the first strike hitches.**

His stutter is not a new mystery and it is not evidence about distant AI. **It is the answer to a
standing open question that has been sitting in the findings doc for nine days, and the answer is
"still hitches."** The correct response is to close R1 — with the vegetation-invalidation mechanism
named as the residual cause the headless probe could not see — not to open a new system.

### Why this is the most important thing this council can tell him

**His instinct is correct and his evidence points at the wrong system.** He said *"we're not optimizing
some of these events as well"* — and he is **right**: `apply_blast` fires map-wide work for an event
210 m away with no distance gate. That is precisely "not optimized for distance."

But the un-optimized thing is **terrain and vegetation**, not AI. If the council answers "yes, abstract
the distant war," it will build a system that does not touch `TreeBreakSystem`, `apply_blast`, or
`build_scatter` — **and his stutter will still be there.** He will have paid for a feature and kept the
bug. That is the worst outcome available from this session.

---

## OBJECTION 3 — THE TRANSITION CASE. THE 80 m RING RESTS ON A BROKEN INSTRUMENT.

`marching_cell.gd:12-15` states its derivation:

> *"Must clear the night sight cap (56 m open, from `EnemyBase.SIGHT_CAP_OPEN` x the 0.4 NIGHT darkness
> multiplier) or the player watches bodies appear out of nothing."*

I checked the arithmetic. It is right, and the instrument is wrong.

### The numbers

- `scripts/enemies/enemy_base.gd:108` — `const SIGHT_CAP_OPEN: float = 140.0`
- `scripts/ai/sight_cap.gd:12` — `const DARKNESS_BY_PERIOD: Array[float] = [1.0, 1.0, 0.75, 0.4]`
  (DAWN, DAY, DUSK, NIGHT)

| Period | Multiplier | Open cap | Cleared by `MATERIALIZE_M = 80.0`? |
|---|---|---|---|
| DAWN | 1.0 | **140 m** | **NO — short by 60 m** |
| DAY | 1.0 | **140 m** | **NO — short by 60 m** |
| DUSK | 0.75 | **105 m** | **NO — short by 25 m** |
| NIGHT | 0.4 | 56 m | yes |
| any, under illum | 0.9 floor (`sight_cap.gd:34`) | **126 m** | **NO — short by 46 m** |

**Answering the brief's direct question: the day sight cap is 140 m and 80 m does not clear it.**

**But I will not call this a shipped defect in the siege, because it is not one.** The demo's assault is
a night action: `demo_game.gd:174` `NIGHT_HOUR = 19.0`, NIGHT reached at ~1184 s (`:46`), probe at
1395 s (`:58`), siege at 1440 s (`:59`). At night the cap is 56 m and 80 m is correct. **The number is
right for the only case that ships.** Law 2 cuts both ways; I am not manufacturing a defect.

**What IS a shipped defect is narrower, and real:** the illum flare's *visual* light reaches further
than its *materialize* trigger.

- `scripts/combat/illum_flare.gd:11` — `const LIGHT_RADIUS: float = 30.0`
- `scripts/combat/illum_flare.gd:51-53` — `is_lit()` tests `< f.light_radius`, i.e. **30 m**
- `scripts/combat/illum_flare.gd:93` — `_omni.omni_range = light_radius * 1.5`, i.e. **45 m**

**Between 30 m and 45 m from a flare, ground is visibly lit and a dormant cell standing on it does not
materialize.** A 15 m annulus where the player can see illuminated ground that men will later pop into.
Modest, but measured, and it belongs in the ledger.

### The instrument defect, which is the part that matters for generalising

**`SightCap` describes what an NPC's AI is permitted to acquire. It has nothing to do with what the
player's camera renders.** `sight_cap.gd:2-3` says so itself — *"One implementation for BOTH sides: a
man's eyes obey the world, whichever army he is in."* Both sides means both AI factions. The player is
not an `EnemyBase`; nothing in his perception path consults `SightCap`.

What the player actually has:

- **Binoculars.** `scripts/player/player.gd:213-218` — `target_fov: float = 18.0 if _binocs_active else 75.0`.
  Magnification = `tan(37.5°)/tan(9°)` = **4.84×**. A man popping in at 80 m subtends what a man at
  **16.5 m** does to the naked eye.
- **The M70 scope.** `data/weapons/m70.tres:24` — `ads_fov = 12.0`. Magnification = `tan(37.5°)/tan(6°)`
  = **7.30×**. A pop at 80 m looks like a pop at **11 m**.
- **Fog does not save it.** `scripts/levels/game_world.gd:89` — `env.fog_density = 0.0065`. At 80 m,
  transmittance `exp(-0.0065 × 80)` = **0.59**. The body is ~59% unfogged. It is not hidden.

**The 80 m ring was derived from a number that measures the wrong eye, and the player is carrying a
4.84× optic that the derivation never considered.** It survives in the siege because night, muzzle
flash, and a player under assault hide a multitude of sins. **It will not survive being generalised to
a daylight ambient firefight the player is deliberately walking toward with binoculars up** — which is
the exact scenario in the brief's question 2.

### Why an ambient firefight is STRICTLY harder than a siege march

A `MarchingCell` is allowed to be ugly in five ways an in-contact firefight is not:

1. **No enemy is engaged.** The cell walks toward a known objective. Every man materialises standing,
   walking, unwounded, facing the objective — the state is a single vector. A firefight in progress has
   men prone, in cover, suppressed, mid-reload, facing a *second* party.
2. **No accumulated dead.** `_spawn_one` (`:183-201`) places men on a ring, `randf_range(1.5, 5.0)`
   from the cell origin. There are no bodies to place, because nobody has died yet. An abstract
   firefight that has been resolving for four minutes must **materialise a graveyard**: bodies in
   positions consistent with an exchange that never happened, with wounds from weapons that were never
   fired, facing directions nobody chose. `MarchingCell` answers none of this and was never asked to.
3. **One party, one objective.** Two parties 40 m apart (`ambient_war.gd:16` `PARTY_SPREAD_M = 40.0`)
   must materialise into a coherent *mutual* geometry — mutually in cover, mutually in LOS, neither
   standing in the open. Nothing in the codebase does this.
4. **The player is a spectator, not a participant.** In the siege he is being assaulted; he is looking
   at the wire, at night, being shot at. Walking toward a distant firefight, he is *studying* it,
   through glass, at leisure, choosing his own approach vector.
5. **The pop is covered by a budget tuned for the siege.** `SPAWN_PER_FRAME = 2` (`:147`) with the
   measured warning at `:141-146` that 1/frame made *every phase worse*. A firefight materialising two
   parties plus their dead is a bigger burst than the class this budget was measured against, and
   `:126-131` records what that class cost before the budget existed: **267–288 ms**, `+2,300..+2,900`
   nodes in one frame, *"the game's recurring worst-frame class."*

**What he hears at 81 m versus sees at 79 m.** At 81 m: `AmbientWar`'s distant firefight model —
positional audio, 900 Hz cutoff (`ambient_war.gd:31`), two parties on burst clocks. At 79 m: two
squads of men appearing on a ring at 2 per frame, plus corpses that must be conjured with plausible
wounds. **The audio model is excellent and the visual transition is unbuilt.** That gap is the honest
answer to question 2, and the council should not paper over it.

---

## OBJECTION 4 — "OUTCOMES MAY NOT CHANGE" WILL BREAK SILENTLY. HERE IS EVERY LEAK.

The constraint is right and it is much harder than it sounds, because in this codebase **outcomes are
not a number — they are the side effects of bullets.** Remove the bullets and the following stop
happening, none of them loudly.

### LEAK 1 — the evidence ledger and the entire hunt net

`EvidenceLedger` is fed by **exactly one source**, `NoiseBus`:

- `scripts/missions/field_director.gd:26-28` — `evidence = EvidenceLedger.new(...)`;
  `NoiseBus.noise_emitted.connect(_on_noise_evidence)`
- `scripts/missions/field_director.gd:35-38` — `evidence.on_noise(type, pos, source_team, …)`
- `scripts/enemies/evidence_ledger.gd:56-63` — GUNSHOT → `record(WEIGHT_GUNSHOT 1.0)`,
  EXPLOSION → `record(WEIGHT_EXPLOSION 1.4)`

**An abstract fight fires no shots, so it emits no `NoiseBus` event, so it writes no evidence row, so
`best_fix()` returns empty, so nobody is dispatched.** The FieldDirector's own comment states the
consequence (`field_director.gd:169`):

> *"With no evidence there is no lead and nobody is sent"*

**A war that runs without you but leaves no tracks is not the same world.**

### LEAK 2 — emitting the noise is ALSO an outcome change

The obvious patch — have the abstract fight emit `NoiseBus` events — is not free either.
`scripts/autoload/noise_bus.gd:23` — `NoiseType.GUNSHOT: 150.0`. Every living AI subscribes
(`enemy_base.gd:404` `NoiseBus.noise_emitted.connect(_on_noise_heard)`).

An abstract firefight sited at `AmbientWar`'s own band (200–800 m, `ambient_war.gd:3`) that emits real
gunshots wakes **every AI within 150 m of itself**, including, at the near end of that band,
groups near the player. **Both choices change outcomes.** Silence changes the hunt net; noise changes
who is alerted. There is no neutral option, and the council must pick one deliberately rather than
discover it.

### LEAK 3 — suppression and morale are emergent from bullets, and cannot be scored

Suppression is applied per-round by things in flight, and casualty shock is applied by *witnessing*:

- `scripts/enemies/enemy_base.gd:114` — `const CASUALTY_SHOCK: float = 0.35`
- `scripts/enemies/enemy_base.gd:1150` — `w.apply_suppression(CASUALTY_SHOCK)` on a witnessed casualty
- `scripts/allies/ally_base.gd:125` — `const NERVE_LOSS_PER_CASUALTY: float = 0.12`
- `scripts/allies/ally_base.gd:128` / `:2400` — `CASUALTY_SHOCK_M = 25.0`, applied to mates inside 25 m

**Who broke, and when, is not derivable from a casualty count.** Two men lost to a burst that also
pinned the other four is a different world-state from two men lost cleanly. An abstract resolver can
reproduce the *dead*; it cannot reproduce the *pinned*, and Pillar 1 (believable firefights) lives in
the second number. This is the deepest of the leaks and the least likely to be noticed, because the
casualty count will look correct.

### LEAK 4 — the butcher's bill is a physical object, not a counter

`scripts/autoload/campaign_state.gd:50-73` — his decree of 2026-07-30:

> *"the aid station fills from REAL casualties, and the dead stack up as body bags beside it — a
> cumulative scoreboard of the player's own failure with NO UI"*

`kia_total` (never decrements) · `ward_wounded` · `bags_unlifted` ("what is STACKED and visible") ·
`WIA_PER_KIA = 3` · `WARD_BEDS_MAX = 12`. An abstract resolution must increment all of these **and
produce the stretcher-bearers, the ward occupancy, and the physical bags**, or the scoreboard silently
under-reports. A number that goes up while the tent stays empty is not the ledger he decreed.

### LEAK 5 — bodies as intel

His decree of 2026-07-30: bodies give intel only, searched for points toward a stash of 3 marks,
exactly 1 real. Answering the brief's question 3 plainly: **an abstractly-resolved battle CAN produce
bodies worth reading — but only if the resolver records, per dead man, which weapon he carried, which
faction, and where he fell.** That is not a casualty count; it is a full per-man record. At which point
you are storing most of a body's state to avoid simulating a body, and the saving shrinks again.
`_spawn_one` (`marching_cell.gd:183-201`) stores nothing of the kind — it rolls a position from an RNG
at materialise time. **The precedent does not carry this, and building it is most of the work.**

### LEAK 6 — determinism is shakier than the brief assumed, but not for the stated reason

**I must refute the brief's own hypothesis here.** It suspected `SimClock.advance()` still has zero
callers. **That is false.**

- `scripts/autoload/sim_clock.gd:27-34` — `_ready()` calls `set_process(true)`; `_process(delta)` calls
  `advance(delta)`. **The clock is wound every frame.**
- `scripts/main/game_flow.gd:108` — `SimClock.advance(...)` on the time-skip path.

The clock is fine. **The real determinism problem is one line lower.** `advance(delta)` takes the
**real frame delta** (`sim_clock.gd:45` — `sim_hour += delta * real_to_sim_ratio / 3600.0`). `sim_hour`
is therefore a function of **frame timing**. Integer-hour crossings still fire deterministically
(`:49-50`), so `AmbientWar`'s hourly roll is safe — but **any abstract resolution that integrates over
continuous `sim_hour`, or that ticks on `delta`, will resolve differently at 30 fps than at 60 fps.**
Under ADR-010 (one seed per operation) that is a violation, and it is invisible: the seed will be
identical and the outcome will not. **If the council rules yes, the resolver must tick on a fixed
accumulator, never on `delta`.**

---

## OBJECTION 5 — THE PRECEDENT. THIS PROJECT HAS ALREADY BUILT THIS ONCE AND IT COST REAL WORK.

ADR-025 was a full LOD-tier design with `materialize_near` / `dematerialize_far`. It is **SUPERSEDED,
instruction VOID**, and `world_sim.gd` is now 34 lines — a flat registry. Its own header records what
it did on the way out: it *"stayed DRAFT-but-live for four days and actively misdirected work: on
2026-07-20 it routed an agent into building the condemned consumer."*

**That is the shape of the risk, and this council is standing in exactly the same doorway.** A blessed
tier name (`AGGREGATE`), a real perf story, a plausible design — and four days later an agent building
against a document that had already been killed. The failure mode is not "the idea is wrong." It is
**"the idea is right, the vehicle is condemned, and nobody who reads the doc can tell."**

The mitigation is cheap and I will name it: **if this council rules yes, the decree must state its own
expiry and its own consumer.** Not "abstract the distant war" — but "this specific system, consumed by
this specific caller, measured by this specific probe, and if the probe does not exist the decree is
not in force." ADR-015 already demands the probe. ADR-025 died because it was a design without one.

### THE TRACK RECORD, COUNTED — and it is worse than one bad ADR

I had the whole `production/adr/` folder swept for this question. **This project has never shipped a
world-simulation abstraction layer. Not once.** Every design in that family is dead, frozen, or
forbidden:

| ADR | The abstraction | Where it ended |
|---|---|---|
| **025** | LOD tiers, `materialize_near`/`dematerialize_far`, off-screen resolution | **SUPERSEDED, instruction VOID.** The only fully-killed ADR in the folder. |
| **013** | chunk streaming | **Killed by policy, not tuning** — *"the exact synchronous-world-streaming bug class that killed the Catacombs project"* |
| **039** | Zones, not streaming | **ACCEPTED as canon; POST-DEMO — BUILD NOTHING** |
| **041 / 040 / 007-A** | authored places · down state · save anywhere | all **ACCEPTED as canon; POST-DEMO, BUILD NOTHING** |
| **001** | far-LOD sprite A/B for vegetation | cancelled (`ADR-001:30-33`) |

**And the decisive one is three days old.** `production/adr/ADR-039-zones-not-streaming.md:1-3`:

> **Date:** 2026-09-06 · **Status:** ACCEPTED as canon; **POST-DEMO — BUILD NOTHING** (Summoner decree,
> THE RPG PIVOT, under his own scope wall *"but the demo scope is still the overall goal"*)

**The Summoner has already ruled on world abstraction, on 2026-09-06, and his ruling was: canon, and
build nothing until after the demo.** ADR-039 sits directly on top of ADR-013 (≤2 km never streams) and
carries his scope wall in its own status line.

**A council decree that says "build abstract distant resolution now" contradicts a ratified ADR that is
three days old, under a scope wall he wrote himself.** That is not a tradeoff to weigh — under
ADR-014's canon hierarchy it is out of this council's authority. The Arbiter should say so plainly:
**the design answer is already ratified and already frozen; what is in front of us is a request to
un-freeze it, and only the Summoner can do that.**

**The geometry re-check the briefing asked for:** ADR-025's stated kill-shot was that `CELL_SIZE` /
`AO_RADIUS` could never produce DORMANT on a 1280 m map, and the demo map is 512 m
(`GameFlow.DEMO_MAP_SIZE`, `demo_game.gd:167`). **That argument does indeed no longer bind at 512 m.**
I concede the point and it does not help, because Objection 1 kills the same proposal by a shorter
route: on a 512 m map with a 140 m lazy-activation radius, **the DORMANT band contains 3–4 men.** The
geometry got better and the population got smaller. Those cancel.

---

## OBJECTION 6 — WHAT THE HOURS BUY INSTEAD

Against the standing demo blockers, the ranking is not close. `PLAYTEST_FINDINGS_2026-08-28.md:124-125`
counts **14 open, all 14 `[ART]`/`[SCENE-LAYOUT]`**, and adds at `:130`: *"not one has been verified by
your eye, and the art half has not been started."* The 2026-09-07 audit names five that block a
stranger (`recon-demo-audit-2026-09-07.md:21-40`):

1. **No onboarding at all** — `grep PLAYER_MANUAL` = 0 hits. *"The stranger cannot act."* 4–8 h.
2. **The siege forms up OFF the 512 m map** — `RING_MIN 300`/`RING_MAX 500` (`siege_director.gd:19-20`),
   `MORTAR_TUBE_STANDOFF 700` (`:50`) on a 512 m map. **1,057 `floor_y` no-collider misses in one
   siege; attackers walk ~200 m on nothing.** 2–6 h, gate 1,057 → 0.
3. **Payoff at minute 23–24** — needs his ruling, not a build.
4. **White untextured surfaces on the walked path** — `medic_brassard_white`, `SurgeonMask2`, both
   inside the wire, plus 10 stray props ~900 m out.
5. **`__bolt`/`__mg`/`__launcher` clip families do not exist** (`model_actor.gd:997`) — every MG,
   bolt-action and RPG man in the 45-man assault holds his weapon like a rifle, **in the one fight the
   demo is built on.**

Plus: **there is no artefact to hand anyone** — `build/RECON_Demo.exe` is dated 2026-07-31, and the EA
target date (2026-09-06) has already passed with the entry gate undischarged.

**Note item 2 especially, because it is the same disease this council is being asked to treat and it is
already diagnosed with a number.** The siege spawns men outside the map and they traverse 200 m of
nothing. That is a real distant-simulation defect, it is measured, it has a gate, and it is 2–6 hours.
**If the council wants to spend hours on the war at range, that is the work — and it is a bug fix, not
an architecture.**

Every one of the five is a defect a first-time player hits in the first thirty seconds or the last ten
minutes. **None of them is abstract resolution.** An abstract-resolution system is invisible to a player
who never walks 200 m from the wire — and the demo's arc, by its own clock (`demo_game.gd:58-59`),
seats him at the firebase and brings the war to him at T+24 minutes.

**Spending this session's hours on the distant war is spending them on the one part of the demo the
demo does not use.**

---

## LAW 2 — WHAT IS SACRIFICED, SAID PLAINLY

If the council rules **yes and builds now**: it spends its hours on ~3 men of load, ships a transition
that a 4.84× optic defeats in daylight, and leaves his actual stutter — a map-wide vegetation rebuild
fired by a blast 210 m away — in the build. He will replay it, feel the same hitch, and correctly
conclude the council did not listen.

If the council rules **no**: it loses nothing today, because nothing today is paying for the distant
war. It costs something later — when the open-patrol world (ADR-029, PLAYTEST R4, deferred) puts real
populations at real distances, this work becomes necessary, and doing it under launch pressure is worse
than doing it now.

**And the honest heart of it:** *"the war runs without you"* does not survive being resolved by dice, if
the dice only produce a number. It survives if the resolution produces **tracks** — evidence rows,
noise, bodies with weapons and bearings, a ward that fills. Every one of those is a thing the current
`MarchingCell` precedent does not carry, and building them is most of the cost. **The cheap version of
this feature is the version that breaks the promise.**

---

## THE ONE ARGUMENT FOR ABSTRACT RESOLUTION I CANNOT REFUTE

**`LazyGroup` already changes outcomes, silently, today — and abstraction is the only thing that fixes it.**

`scripts/missions/lazy_group.gd:50-61`: a group beyond 140 m is not simulated cheaply. **It does not
exist.** It cannot fight, cannot die, cannot be heard, cannot leave a body, cannot write an evidence
row. Its men are `_spawned = false` and nothing else.

So the standing constraint — *"the same men die and the same ledger rows are written whether or not the
player watches"* — **is already false in the shipped build**, and it is false in the worst direction:
not degraded, but absent. The `treeline_watchers`, the `camp_mortar_crew`, the `zpu_crew` and both
friendly patrols are in a state of suspended non-existence until the player walks to them. Two friendly
patrols and three enemy groups can never, at present, meet each other — because at any moment at most
one of them is real.

**A distant firefight between two lazy groups is currently impossible, and that is a design failure, not
a perf saving.** The only mechanism that could make it possible is exactly the one under debate:
something cheap enough to run on groups that are not near the player, and faithful enough to write the
rows.

**So the answer to question 1 is YES — abstract resolution is not merely permissible, it is the only
route to the world he was promised.** My objection is entirely to the *when* and the *why*. Built as a
perf optimisation, now, against the demo, it is measurably worthless (Objection 1) and it will be
mistaken for a fix to a stutter it does not touch (Objection 2). Built as a **world-fidelity feature**,
after the demo ships, against the open-patrol world it was always for — it is right, and I would argue
for it.

**The prize is not frames. The prize is that the war can happen at all when he is not looking.** The
council should say that in those words, and should not let the perf number — which I have measured at
approximately nothing — be the reason it gets built.
