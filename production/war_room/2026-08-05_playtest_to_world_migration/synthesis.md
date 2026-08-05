# THE DECREE — 2026-08-05 — THE MIGRATION: PLAYTEST ZONES → DEMO & GAME WORLD

**Convened:** the Overseer/Director as Arbiter, at the Summoner's direction.
**Council:** systems-designer · technical-director · level/world-architect · game-designer ·
devil's-advocate. Independent sight, code only.
**Every claim below was verified by reading the code. Where the Arbiter's own briefing was wrong,
the correction is in `discussion.md §1` — eight items.**

---

## 0. THE ONE-PARAGRAPH DECREE

**Two of the three things you named are already in the game, and you should stop paying attention to
them.** Shooting through materials works everywhere — huts, temple, VC camps, the firebase — and four
different bits of shipped code read those tags. Your RTO strikes with every value you tuned on the
range are already the demo's and the patrol's strikes, because the range never had its own copy: it
picks up the same radio. **The third thing is real and it is bigger than you framed it.** "Destructible
trees and buildings" is two separate jobs. The firebase can already be blown apart — parapet, bunkers,
towers, sandbag stacks, all with HP, and the hole becomes walkable. **The world you patrol into
cannot.** And the jungle is worse than merely missing: today a blast *deletes* cover and hands back a
decoration that evaporates — so bombarding the jungle currently makes it **safer** to cross. The
migration is therefore: give the world the same destruction laws the firebase already has, and make a
fallen tree a real piece of cover. Before either, fix one number — the per-mission crater budget — or
your next 30-minute playtest will lie to you about the tuning you already got right.

---

## PART ONE — WHAT ALREADY TRANSFERS (stop spending attention here)

These are shipped in **both** the demo and the patrol world. No migration exists to do.

### 1.1 Shooting through materials — LIVE EVERYWHERE
**What it does:** a thatch hut wall lets a rifle round through at 80 % damage instead of stopping it
dead. Sandbags and stone do not. Shotgun pellets punch through up to two soft layers. Explosions
partly defeat soft cover and defeat hard cover on a chance roll (your ~50 % ruling).
**Where it lives:** every structure the world planner places is tagged as it is placed
(`site_planner.gd:189`), and the firebase model's own colliders are tagged when it is stamped
(`:1373`). Read by `bullet_system.gd:206`, `weapon_holder.gd:647`, `combat_manager.gd:290-292`.
**Three small holes worth one hour, not a project:** the fallen-log collider carries no material tag
(`fellable_tree.gd:129`), and neither do tunnel rooms (`tunnel_room.gd:29`) or the resupply crate
(`field_director.gd:1027`).

### 1.2 RTO fire support with your tuned values — LIVE EVERYWHERE
**What it does:** the radio call, the wait, the sheaf, the danger-close double-press, the 40 m
no-overfly rule, the telegraph, the ×5 explosion spectacle.
**Where it lives:** `field_director.gd` — the *shipped* director. The range does not own a copy; it
wires itself to the same object (`support_fire_range.gd:91`) and calls it.
**Every number you turned is already in the world:** arty 8–12 rounds in an 18 m sheaf · arty shell
260 max / 90 min · napalm 5 canisters · CBU 16 bomblets over 22 m · WP 3 rounds · Spectre 4 m
dispersion · danger-close 45 m with a 5 s confirm · enemy accuracy at you −15 %.
**What must NOT come across:** the bench's unlimited ammunition (9 of everything) and its zeroed
air-cooldown. Those are the lab's clamps. Shipping them deletes the reason a fire mission is a
decision.

### 1.3 Ordnance promotes trees so shells can hit them — LIVE
**What it does:** anything explosive in flight temporarily gives the batched trees along its path
real colliders, so a shell can burst in the canopy instead of sailing through it. Your
"detonate on first real contact" ruling.
**Where it lives:** `tree_cover_layer.gd:86-95`, called from `combat_manager.gd:380` (every explosive
projectile), `grenade.gd:94`, `sapper_charge.gd:49`, `field_director.gd:463-465`,
`siege_director.gd:667`. Off-screen blasts still break the world — gaze-based promotion stayed
rejected.

### 1.4 The firebase blows apart — LIVE, and MORE than was believed
**What it does:** 80 parapet segments at **140 HP** each; fighting bunkers, MG bunkers and sleeping
bunkers at 260; towers at 180; sandbag stacks at 90. When one dies it hides its mesh, disables its
collider, scatters shared rubble, craters the ground, and **rebakes the navmesh so the hole is
walkable** — destruction that is not decoration.
**Where it lives:** `site_planner.gd:1542-1615`, `destructible.gd`, `nav_baker.gd:193`.
**Correction to the record:** the parapet is 140 HP × 80 segments, not "80 HP". And SiegeDirector
does **not** read a destroyed segment as a breach — it reads the group for positions only. The hole
becomes passable through the generic nav rebake, not through the siege logic.

### 1.5 The jungle already tears at the right size
Contrary to the suspicion carried into this council: a blast clears vegetation over **8 m for a
grenade, 12 m for arty/mortar, 20 m for a bomb, 60 m for napalm** in the shipped world — as much or
more than the arena does. The radius is not the problem. See §3.1 for what is.

---

## PART TWO — THE MECHANICAL LIFTS (no decision needed, just do them)

Ordered. Each is small, each is guarded by existing machinery.

### M-1 · THE CRATER BUDGET — do this first, it costs one line
**What it is:** the ground can only be dug **40 times per mission**
(`damage_system.gd:81`), and **every ground-burst artillery round spends one**
(`field_director.gd:842`). One artillery mission is 8–12 rounds. **Three to five fire missions and
the ground silently stops cratering** — while scars and vegetation-clearing keep working, so it reads
as "artillery got weaker," not as a cap.
**Why it matters now:** the demo is a single continuous 30-minute patrol with a scripted napalm
strike, siege air beats and a night assault. You will hit this cap and then mistrust tuning you
already got right.
**Cost:** raising the cap raises the ceiling on main-thread chunk rebuilds — but they are already
drained one per frame (`world_config.gd:46`), so the cap bounds total work, not spike height. The
honest fix is to make it a **rolling window** (recent digs) rather than a lifetime count.
**Straight lift? No — a small fix. Do it anyway. Nothing else on this list is worth measuring until
this is gone.**

### M-2 · GIVE THE PATROL WORLD'S STRUCTURES HP
**What it does in the game:** the village huts, the village centre, the cache, the tunnel mouth, the
VC camp structures, the temple and its statues stop being indestructible. A satchel, a rocket, an
artillery sheaf or a napalm run levels them. The rubble is one shared draw call, the ground craters,
and the navmesh reopens so men can walk where the wall was.
**Where it lives now:** nowhere for these; the identical machine already runs on the firebase
(`_wire_structure_destructibles` / `_adopt_structure`, `site_planner.gd:1561-1615`), matching meshes
**by name prefix** so it needs **no Blender re-export**.
**Where it must live:** called from `place_structure` (`site_planner.gd:162`) — which puts it in the
demo and the patrol world at the same instant, because `demo_game.gd` is a driver over the same
builder (`game_flow.gd:582, :606`).
**Straight lift.** The only new content is an HP-per-kind table, and see M-3.
**Cost, honestly:** ~60–120 more objects on the explosion bus — a linear distance check per blast,
orders of magnitude below the 2.4 ms you could even detect. Levelling is already throttled to 2 per
frame. **The real cost is not frames, it is permanence:** ADR-031 makes destruction permanent and
there is no far-field recycler in code. Free for a 30-minute demo, a slow leak on a long patrol.
**What is sacrificed:** this buys atmosphere and consistency, **not a new verb** — ADR-031 said so
first. Nothing in the game reacts to a flattened village: no allegiance hit, no ROE entry, no VC
response. Do not let it be called done when the hut falls over.

### M-3 · ONE HP TABLE, NOT FOUR
Three tables exist today and were hand-synchronised: `fire_support_bench.gd:48-55` (sandbag wall 140,
stack 90, bunker 260, tower 180, wire 60), `site_planner.gd:1552-1558` (its own copy), and
`support_fire_range.gd:988` (fort HP **110** — already drifted). Adding a fourth for huts
institutionalises the drift the fossil law forbids. **One file, everyone reads it.**

### M-4 · TAG THE FALLEN LOG AND THE TWO STRAGGLERS
One group name each on `fellable_tree.gd:129`, `tunnel_room.gd:29`, `field_director.gd:1027`. The
felled log is the one object in the game explicitly built to be prone cover and it is the one object
whose material the ballistics code has to guess.

### M-5 · STOP THE ARENA WRITING ON THE GAME
Not a migration — the opposite. The arena sets three pieces of shared static state and restores none:
- `EnemySquad.tiering_enabled = false` (`ai_stress_arena.gd:304`) — **for the rest of that process,
  activity-tiered AI is OFF.** That is the single largest CPU lever in the project, disabled by a
  test scene.
- `GibSystem.gib_lifetime_s = 25.0` (`:305`) against a game default of 12.0.
- `GameSettings.ai_vs_ai_cone_mult` (`:308`) — real mechanism, **zero effect at defaults**, and there
  is no in-game path from the arena to the demo. Hygiene, not alarm. The briefing overstated this and
  it is corrected here.
`demo_game.gd:117` already models the discipline — it clears its own flag *"never leak demo state
into a normal boot."* The arena should match it.

### M-6 · REMOVE THE ARENA HOOK FROM SHIPPED BULLET CODE
`bullet_system.gd:172-176` reaches into the current scene and calls `get_player_damage_mult()` if it
exists. The only provider is the arena. A test hook inside the bullet path in shipping code — the
exact shape ADR-023 forbids.

### M-7 · THE DRIFT PASS (NO-DRIFT law, same change)
`site_planner.gd:1479-1484` is a pre-fix problem statement standing above its own fix — it says the
destructibles manifest is "READ BY NOTHING" (it is read 20 lines below at `:1497`), that "nothing in
the shipped world ever called `Destructible.new()`" (the next function does, at `:1513`), and that the
firebase "was incapable of taking a mark" (parapet, bunkers, towers and stacks are all on the bus).
Also correct: `site_planner.gd:1491-1492` and `:1536-1537` (SiegeDirector does not read a breach),
`ai_stress_arena.gd:1954-1955` (perception exempts only the player's squad, not all allies), the
`DEMO_SHIP_BACKLOG` "group-based, applies to main world" line, and the dead
`site_planner.gd:140 _is_soft_cover()`.

---

## PART THREE — WHAT NEEDS YOUR RULING

### 3.1 · THE FALLEN TREE — the big one
**What happens today, exactly:** a blast removes the standing trees inside its radius — and removing
them **removes their trunk colliders**, so the cover is genuinely gone. Up to **5** of them get a
falling animation; a bare mesh hinges over and lies there with **no collider, no registry entry**
(the file says so itself, `vegetation_manager.gd:440-446`). Past **24** lying trees, the oldest are
deleted outright.

**So bombarding the jungle deletes cover, hands back a prop, and then deletes the prop.** The ground
gets *tidier* under fire. That is backwards for a Vietnam firefight, and the game already does it
right on both benches: `FellableTree` lays a real 0.45 m × 5 m capsule along the fall direction
(`fellable_tree.gd:129-140`) that you can lie behind.

**Why it is affordable — the argument, stated plainly:** since ADR-033 there are **no resident tree
colliders**. There is a pool of 1,280 bodies serving a 70 m ring around you; measured worst demand is
919, so ~40 % headroom. A fallen log **replaces a standing trunk one-for-one**, so making logs solid
is **net zero new physics bodies**.

**What it costs, honestly — and this is why it is not a straight lift:**
- The pool shares one cylinder shape per radius. A lying log needs a **rotated capsule** — a second
  shape family and a per-log orientation carried through chunk rebuilds.
- The mechanism that deletes the standing tree (the "hole" that scatter skips) is the same mechanism
  that would delete the log. `TreeCoverLayer` has **no concept of a candidate that survives a hole**.
  Somebody has to own that exception.
- The 24-log FIFO must become distance-keyed or logs must be exempt, or **a log a man is lying behind
  can be freed by a blast 200 m away** — a direct violation of ADR-031's "permanence is sacred inside
  the firefight radius."
- Nothing rebakes the navmesh when a tree falls, so AI will walk through a downed trunk. `Destructible`
  already solves the inverse case (opening a hole); closing one is new.

**Classification: a SMALL REWRITE of the tree-candidate model with a small runtime cost.** Roughly a
day, not an hour, and it must not be called a lift.

**The game-designer's position, on the record:** if exactly one thing on this whole list ships, it is
this. Every other item changes what a firefight *looks like*. This changes what a firefight *is* —
and the value is not that you gain cover, it is that **the enemy** gains cover and the ground
rearranges itself mid-fight.

### 3.2 · HOW FAR DOES DESTRUCTION REACH?
M-2 as written gives every structure in the AO HP. The alternative is to scope it — the firebase plus
villages only, leaving the temple and statuary indestructible as scenery. Cheaper on permanence,
inconsistent as a law.

### 3.3 · SEGMENTED TREES — still held for your verdict
Your 8/4 ruling (split tree models at joints so a canopy hit breaks the tree at height instead of
felling it from the roots) is logged and **not dispatched**, waiting on your chamber verdict. The
council's advice: **this is a fidelity upgrade on a system that does not yet matter.** Do not send the
Blender job until a fallen tree is cover, or you will have segmented a decoration.

### 3.4 · DEFENSIVE ZONES INTO THE FULL GAME
The mechanism is shared code (`AllyBase.defense_zone`) but only the arena ever assigns a zone. Full
integration — firebase garrison stations *being* zones, the two-state DEFEND⇄PATROL life switched at
the wire gate, enemy camp defenders using the same doctrine — was already flagged as council work and
carries a dependency: main-game garrison men are Civilian-class until the post-demo soldier migration.
**Not folded into this decree; named so it is not lost.**

---

## PART FOUR — WHAT IS REFUSED, AND WHY

| Refused | Reason |
|---|---|
| The arena's spotting constants (`SPOT_RANGE 72`, `SPOT_CONE_DOT −0.17`, `SPOT_GAIN 0.85`) | A **second perception authority** (ADR-023). The shipped `EnemyBase` has a full one — awareness accumulator, 140 m open / 45 m jungle sight caps, FOV cone, smoke and terrain LOS. The arena's block exists only to route around the buddy rule its own spawn choice triggers. |
| The bench's unlimited fire-support stock (9 of everything) and `_cas_cooldown = 0` | Deletes the fire-support economy — the only thing that makes a fire mission a decision (ADR-011). |
| The arena's 30-man survival-wave `SIEGE_STRENGTH` | A stress figure, not a design figure. The demo's 45 is ruled, and 55 arms a known softlock (2026-08-03 council). |
| `mirror_mode`, `MIRROR_HP 80`, `player_damage_multiplier`, `ai_hp_multiplier`, `rng_seed`, `force_gib`, `hot_start`, `debug_readouts` | Instruments. ADR-029 Q5: lab scenes stay as instruments. |
| Any retune of ADR-016 damage values as part of this migration | ADR-016 is law and is guarded by `tests/test_flat_damage`. |

---

## PART FIVE — ORDER, DEPENDENCIES, AND THE PERF ANSWER

**Order:**
1. **M-1** crater budget (protects every judgement you make afterwards)
2. **PROBE A — THE WALK** (below), before anything is built
3. **M-5, M-6, M-7** (leaks, hook, drift — cheap, and they make later measurements trustworthy)
4. **M-3** one HP table → **M-2** structures get HP → **M-4** tags
5. **PROBE B — THE BARRAGE SPIKE** (this is the ADR-031 gate, open since 2026-07-25)
6. **3.1** the fallen tree becomes cover (with **PROBE C**)
7. **3.3** segmented trees — only after 6, only on your word

**Dependencies:** M-3 blocks M-2 (or the fourth HP table gets written). 3.1 blocks 3.3. Probe B
formally discharges the ADR-031 gate that has been holding building destruction since July.

**THE PERF ANSWER, HONESTLY:**

- **HP on world structures: the budget is KNOWN and it is cheap.** Not measured — *derived*, from
  structure: a `Destructible` has no per-instance process, adopts the collider that already exists,
  adds no mesh, shares one rubble draw call, and is throttled to 2 levellings per frame. The blast bus
  is O(N) per explosion over ~60–120 objects. **ADR-031's gate is about terrain heightmap holes, not
  state-swap structures; structures were gated by association and the association is wrong.**
- **Colliders on felled trees: the body budget is KNOWN and it is zero net.** The log replaces the
  trunk inside the same 1,280-body ring.
- **What is genuinely UNKNOWN, and I will not pretend otherwise:** the nav-rebake churn under a
  sustained barrage, and — far more importantly — **this project has never measured a single jungle
  sightline.** Every FPS row in `PERF_LEDGER.md` is a stationary camera inside a cleared firebase
  (`PERF_LEDGER.md:972-975`), the CPU-vs-GPU split has never been taken at `fsb_main` at all
  (`:968-971`), and the detectability floor is **~3 FPS**. **Rule #1 is about walking, and nobody has
  ever measured the walk.**

**THE PROBES:**
- **PROBE A — THE WALK.** Boot the demo, walk out the wire into the jungle. `[PERF] FPS=` already
  prints every 2 s (`game_world.gd:481`). **Zero code, ~4 minutes.** This is the missing baseline and
  it precedes everything.
- **PROBE B — THE BARRAGE SPIKE.** Stand in a village, call artillery (8–12 rounds, each a crater + a
  vegetation clear + fells + structure levellings), catch the worst single frame. Ship config, Intel
  UHD floor. **This is the ADR-031 gate number.**
- **PROBE C — THE LOG RING.** Extend `tests/test_trunk_ring.gd` with a case that fells 40 trees inside
  the ring and asserts net-zero body growth. Headless, guarded, permanent.

**No FPS delta is accepted unless the draw-call/primitive delta has the right sign and a plausible
magnitude** — the binding rule from 2026-07-26, after the instrument lied for three runs.

---

## PART SIX — WHAT IS SACRIFICED (no free lunches)

- **Permanence becomes a real tax.** ~100 levelled structures plus persistent logs, hidden meshes,
  disabled colliders, and a rubble transform array that only grows. ADR-031 promised a far-field
  recycler; **it does not exist in code.** Invisible in a 30-minute demo, unbounded on a long patrol.
- **Structure destruction buys atmosphere, not tactics.** No allegiance hit, no ROE entry, no VC
  reaction to a flattened village. We are shipping destruction with no consequence layer, in a game
  whose fifth pillar is *fail forward*.
- **A day of engineering goes to the tree**, and it is a day that is not spent on the felt-danger
  work the FEAR doctrine still owes.
- **Raising the crater budget raises total main-thread rebuild work** across a session, even though
  the per-frame drain already bounds spike height.
- **The three refused categories mean the labs and the game will keep diverging.** That is correct —
  a lab that matches the game is not a lab — but it means every future tuning session needs this same
  question asked again: *is this number a system, or is it a clamp?*

---

## DECISIONS ONLY YOU CAN MAKE

1. **Do fallen trees become real cover you can lie behind, or stay decoration?** (Council recommends
   yes — it is the only item that changes how a firefight plays. Costs about a day and makes felled
   logs permanent.)
2. **Do we raise the per-mission crater limit so artillery keeps digging for a full 30-minute demo?**
   (Right now it stops after roughly four fire missions and nothing tells you.)
3. **Does every building in the world get destroyable — villages, VC camps, and the temple — or just
   villages and camps, leaving the temple as scenery?**
4. **Should a levelled village cost you anything with the locals, or is it purely spectacle for now?**
   (Today nothing in the game notices.)
5. **Do we send the Blender job to split tree models into segments now, or wait until fallen trees are
   real cover first?** (Council recommends wait.)
6. **When you blow up a fallen log's neighbourhood, may an old log be deleted to save memory — or is
   every log you can hide behind permanent for the rest of the patrol?**
7. **Do you want the firebase garrison holding assigned ground the way the arena's men now do, before
   the demo — or after?** (It rides the post-demo soldier-class migration if after.)
