# DEVIL'S ADVOCATE — 2026-07-30 demo backlog

**Read:** briefing.md · `CLAUDE.md` (FOSSIL LAW ADR-023, COMMENT DISCIPLINE, POINTER LAW, NO MORE
DRIFT) · `production/DEMO_SESSION_HANDOFF_2026-07-29.md`. Every claim below carries a `file:line`
or names the command that produced it. Where the briefing and the code disagree I say so.

**Posture:** I am not against any of these six items. I am against building them THIS session, on
THIS working tree, in THIS order. The tree is the finding.

---

## 0. THE WORKING TREE — read this before designing anything

Command: `git status --porcelain` (279 entries), `git log -3 --format='%h %ad %s' --date=iso`.

### 0.1 The whole 7/29 session after 15:40 is UNCOMMITTED, and much of it is UNTRACKED

Last commit is `c38647d3 2026-07-29 15:40:04 "Physics tick 60->30"`. Everything the handoff
describes as landed sits in the working tree only:

```
git ls-files --error-unmatch data/weapons/aircraft_20mm.tres scenes/world/firebase_main.tscn
  -> error: pathspec ... did not match any file(s) known to git
```

Both of the handoff's headline artefacts are **untracked**. So are 4 new files in `scripts/world/`,
3 in `tools/`, 3 in `tests/`, 3 in `scripts/levels/`, plus 60 modified tracked scripts. There is no
stash (`git stash list` empty).

`CLAUDE.md:425-446` — *Session Completion*, "MANDATORY", "Work is NOT complete until `git push`
succeeds", "NEVER stop before pushing — that leaves work stranded locally". **The 7/29 session
violated its own mandatory workflow.** Memory `recongame-single-disk-risk` says the standing risk is
untracked work on one drive. That risk is now realised across ~280 paths.

**Concrete failure:** a routine `git checkout -- scripts/` or `git reset --hard` — the exact move an
agent reaches for when a parse error appears mid-session — destroys two sessions of work with no
recovery path. There is no branch, no stash, no remote copy. Adding six more items multiplies the
blast radius of one careless command.

### 0.2 THE GUN AUDIO WAS OVERWRITTEN WITH SYNTH — AGAIN — AND IT IS SITTING UNCOMMITTED

Memory `recon-audio-pipeline-map`: *"bare gen_weapon_audio.py overwrote real guns."* It happened
again and was never reverted.

```
git diff --stat -- assets/audio/sfx/weapons/
  bolt_mosin.wav 110328 -> 120078 ... fire_ak47_1 79458 -> 86478
  fire_car15_1 79458 -> 86478 ... fire_m16a1_1 79458 -> 86478
  fire_mosin_1 176478 -> 192078 ... fire_rpd_1 79458 -> 86478
  mech_{ak47,car15,m16a1} ... reload_{ak47,car15,m16a1}   [12 files]
```

`assets/audio/CREDITS.txt:64-72` declares exactly these ids —
`fire_{m16a1,car15,ak47,rpd,mosin,m70,m14,m60,ppsh41}_*` — as **licensed third-party recordings**
from "Snake's Authentic Gun Sounds". The files on disk are no longer those recordings. The ledger
written in the same session is already **false about the tree it documents** — a POINTER LAW
violation of the exact kind `CLAUDE.md:330-350` names.

Worse, the synth output is *broken*:

```
md5sum assets/audio/sfx/weapons/fire_car15_1.wav  -> bb52cd4bc55e4db73f6ab292b9576964
md5sum assets/audio/sfx/weapons/fire_m16a1_1.wav  -> bb52cd4bc55e4db73f6ab292b9576964
```

**Byte-identical.** `tools/weapon_voices.py:64-82` gives the two guns deliberately different
`f_low` (190 vs 165), `bark_hz` (1550 vs 1350), `drive` (1.3 vs 1.6) and `blast_tau`. At HEAD the
two files differed. So the `over=` overrides are **not reaching the near-fire render path**, and the
M16 and the CAR-15 are now literally the same sound. In HEAD they were two different recordings.

The guard now exists — `tools/gen_weapon_audio.py:635-646` refuses a bare run — but it was installed
**after** the damage and the damage was never undone. That guard's own comment (`:635-639`) is an
8-line tombstone narrating the incident inside the source, which `CLAUDE.md:256-276` forbids.

**Recovery, one line, while the tree is still dirty:**
`git checkout -- assets/audio/sfx/weapons/` restores the licensed pack from `c38647d3`.
**If anyone commits this tree wholesale first, the downgrade is baked in** and only recoverable by
digging history. This is the single most time-critical item in the whole council.

### 0.3 Two other tree hazards

- Four explosion wavs **deleted** (`explosion_{40mm,grenade,heavy,rocket}.wav`) and replaced by
  `_1/_2/_3/_dist` variants. `scripts/autoload/audio_manager.gd:372-376` and
  `scripts/combat/gun_fx.gd:112-115` still key on the bare kind names. If the variant lookup is not
  wired, every explosion in the game is silent. **Unverified by anyone.** This is a one-boot check
  and it should happen before a single new line is written.
- `assets/player/viewmodels/mosin_fp.glb` is modified and uncommitted (2.44 MB -> 3.56 MB). The
  floating round in item 7 is a defect in an **uncommitted export** — see §C.

---

## A. THE OVERRUN PUSH — the proposed `press_assault` bound

### A.1 A driven man CANNOT SHOOT. This is arithmetic, not opinion.

`_fire_at_target()` has exactly one caller: `enemy_base.gd:1478`, inside `_execute_combat`. The
assault override returns at `:1307` (driven) and `:1311` (undriven, marching) **before** the `match
current_state` dispatch at `:1322-1338`. Therefore:

> **For every second `assault_driven` is true, that man is mute.** Not "less effective" — he fires
> zero rounds.

`_update_aim` at `:1296` still runs, so he tracks a target with his eyes and never pulls the
trigger. That is precisely the shape of the 7/29 report: *"the VC started running at the base and no
one fought besides me"* — the tombstone at `enemy_base.gd:66-72` records it.

**The proposal's own numbers.** ~40% subset, ~9 s cycle, ~4 s drive. Peak mute fraction = **40% of
the materialized assault**, average = 0.40 × 4/9 = **17.8%**. `LIVE_CAP` is 50
(`siege_director.gd:36`), so at peak **20 men are sprinting and silent at once**. That is not a
subtle degradation — 20 mute runners is the visual the Summoner rejected.

**Where it becomes the old bug exactly:** the mute fraction is `subset × min(1, drive_s / interval)`.
It reaches 1.0 — the 7/29 bug verbatim — at `subset = 1.0` **or** at `drive_s >= interval` with a
full subset. It is already *visibly* the old bug at the individual level: any one man you happen to
be watching is indistinguishable from a 7/29 man for 4 seconds at a stretch. **Rotation does not fix
the bug; it hides it behind a duty cycle.** The very first thing a tuner does when the press "isn't
pushing hard enough" is raise the subset and lengthen the drive. The knob's failure direction *is*
the regression.

### A.2 The dilemma with no middle setting

Ask the one question the design must answer: **does the press fire on men already in `COMBAT`?**

- **YES** → you yank 40% of the men *out of an active firefight* every 9 s. They stop shooting, turn
  their backs and run. That is the 7/29 bug, throttled.
- **NO** → after the assault reaches the wire, essentially every materialized man IS in COMBAT
  (`enemy_base.gd:1309-1313`: contact clears the objective and hands his legs back). The eligible
  set is empty. **The feature is a no-op precisely at the moment it is supposed to fire.**

There is no third option in the current FSM. Any press that works is a press that mutes men in
contact. **The honest fix is a `_execute_advance_under_fire` that moves AND shoots** — i.e. touching
`_execute_combat`'s movement branch (`:1436-1483`) — not a fourth flavour of leg-theft override.
That is a real piece of AI work, not a session-tail add-on.

### A.3 The press cancels the withdrawal, and the reap can never fire

`_break_siege` (`siege_director.gd:340-362`) calls `withdraw_to(rally)`, which sets
`assault_objective = rally` and `assault_driven = true` (`marching_cell.gd:155-156`). If a
`press_assault` countdown is still live on that man, it expires ~4 s later and clears the drive it
did not set. Two writers, one pair of fields, no ownership token.

**Concrete:** siege breaks at t=100.0 while man M is 2.0 s into a press bound. At t=102.0 the
countdown expires and clears `assault_driven` (or, worse, `assault_objective`). Now look at
`siege_director.gd:382-384`:

```
var at_rally: bool = m.assault_objective != Vector3.ZERO
    and m.global_position.distance_to(m.assault_objective) <= 20.0
```

With `assault_objective` cleared, `at_rally` is **false forever**. `from_base` for a man standing
inside the compound is ~0, so `>= REAP_RADIUS_M` (600 m) is false forever. He only leaves on
`REAP_TIMEOUT_S` = **90 seconds** (`:44`). Result: after the siege visibly breaks and the survivors
run, some number of men stand inside the wire fighting for a minute and a half, then vanish into
thin air in front of the player. Both halves of that are worse than not having the feature.

`_break_siege` also `queue_free()`s the cell at `:355` and clears `cells` at `:356`. Any per-man
press bookkeeping held on the SiegeDirector keyed by cell is now dangling; if the countdown lives on
the cell it dies with it and the drive **never** expires — the man runs at a rally point with
`assault_driven` stuck true, forever, until the 90 s reap. That is the 7/29 "ran at a point they
were already standing on, forever" failure resurrected on the withdrawal path.

### A.4 The press on a medic drops the wounded man mid-drag

Ordering, `enemy_base.gd:1305` (assault) **above** `:1318` (medic). The medic override is
unreachable while `assault_objective` is set.

Enemy medics drag wounded out — Summoner ruling 2026-07-29, memory `recon-enemy-medic-ruling`, code
at `enemy_base.gd:2286-2363`. `_execute_aid` is the **only** thing that moves the casualty:
`:2363` does `_aid_target.global_position = _aid_target.global_position.lerp(trail, ...)`.

**Concrete:** medic M has `_drag_started = true` and is towing casualty C. Press fires on M at
t=0. `_execute` now returns at `:1307`, so `_execute_aid` never runs. M sprints 4 s × ~4 m/s ≈ 16 m
toward the objective. **C does not move — he sits where he was dropped**, still `is_downed`, still
not `set_meta("dragged_out")`, so no other medic will re-claim him
(`:2309` only skips men already flagged). At t=4 the drive expires, `_execute_aid` resumes, and
`:2360-2363` lerps C's position toward `trail` — C **snaps ~16 m across the ground** at
`8.0 * delta` toward a medic who is no longer beside him. Visible teleporting corpse. And the
press's whole purpose is defeated anyway: the medic was the one man in the assault whose legs were
already spoken for.

**Minimum guard:** never press a man with `_aid_target != null`, and never press a `SapperCharge`
carrier. Neither is in the proposal.

### A.5 A man already at the objective, and a man behind an intact wall

- **At the objective:** `ASSAULT_ARRIVE_M` is 8.0 (`:79`) but that gate is on the *undriven* branch
  (`:1310`) only. A DRIVEN man has no arrival test at all — `_execute_assault` (`:1371-1372`) just
  calls `_move_toward(assault_objective, ...)` forever. Press a man standing 1 m from his bound and
  `_router.step` returns a sub-0.1 m direction, `_move_toward` lerps velocity to ~0, and he stands
  still with a run animation intent and no gun for 4 s. He is not pushing; he is a statue.
- **Behind the wall — this is the one that kills the design:**

### A.6 THE NAVMESH HAS NO HOLE. Destroying a parapet does not open a path.

`destructible.gd:74-75` disables the segment's `CollisionShape3D`, so a body can *physically* pass.
But `nav_baker.gd:16` states the contract outright: *"sites != chunks -> a crater never triggers a
re-bake."* Grep for a rebake caller: `NavBaker.clear()` at `mission_scope.gd:31` and
`nav_baker.gd:89` only. **Nothing re-bakes navigation when a Destructible dies.**

`nav_router.gd:53-59`: nav applies only when `box >= 0 and NavBaker.box_contains(box, to)`. So:

- **Both endpoints inside the firebase nav box** → NavigationAgent paths on the **stale** mesh,
  which still shows a closed 80-segment ring. The agent routes to the **gate**, or the path fails
  and `nav_router.gd:93+` falls back to a straight line into the wall. **Either way the men ignore
  the breach they just paid lives to make.**
- **Endpoints in different boxes** → straight-line steering, i.e. men walking into whatever is in
  front of them. The design "works" only by *bypassing navigation entirely* — which is the exact
  defect ADR-023 cites in `nav_router.gd:2-3` (*"allies steered straight into walls for want of
  this"*). We would be re-introducing, on purpose, the bug the router was written to kill.

**This is not a tuning problem. There is no mechanism by which a blown parapet becomes traversable
ground for the AI.** Ship the press as proposed and the honest outcome is: sappers blow a hole,
40 men stream past it into an intact wall segment 20 m away, and pile up. That reads worse on screen
than trading shots at the wire, which at least looks deliberate.

### A.7 The wire is indestructible, so there is nothing behind the hole but wire

Handoff open item 3 (`DEMO_SESSION_HANDOFF_2026-07-29.md:93-95`): the barbwire is **one merged
`bwire_card_ring` mesh**, so there is nothing to adopt as a Destructible. Memory
`recongame-impostor-foliage`: `barbwire_card` is the ONLY wire. So after the parapet segment dies,
the wire ring in front of it is still standing and still colliding.

**Concrete:** sapper detonates, segment at bearing θ goes to `_dead`. Press aims 20 men at a depth
inside the compound through that bearing. They reach the wire ring, `move_and_slide` stops them
dead, `_move_toward` keeps commanding velocity into it, and twenty men grind against an invisible
card for 4 s, are released, then get pressed into it again 5 s later. **Twenty men vibrating against
a wire card is the demo's climax.**

**Therefore: the overrun gate clause is BLOCKED ON A BLENDER RE-EXPORT that nobody has done**
(`tools/gen_firebase_v3.py` change, per the handoff). Writing `press_assault` today does not advance
the gate; it produces code that cannot be verified until the wire is split and the nav story is
answered. That is the definition of negative value.

### A.8 The breach poll is a fossil on every map that is not the firebase

`FSB_PARAPET_GROUP` (`&"fsb_parapet"`) is defined and added in **exactly one place**:
`site_planner.gd:1266`. The other Destructible builders do not add it:

- `sapper_room.gd:161-162` `_adopt()` — lifts real parapet segments out of the GLB, no group.
- `ai_stress_arena.gd:1290, 1318, 1344` — hand-built forts, no group. And `ai_stress_arena.gd:1507`
  runs `open_siege(SIEGE_STRENGTH)` — **the arena is the one chamber built to exercise the siege.**

So: `get_nodes_in_group("fsb_parapet")` returns `[]` in the arena and the sapper room, forever. The
press falls back to "the sector-bearing perimeter point at the ring radius" — but 49.3–96.1 m
(mean 75.5) is a *firebase* number, and the arena is a small chamber that already overrides
`ring_min`/`ring_max`/`cell_materialize_m` (`siege_director.gd:72-76`) and defends an **L-shaped**
parapet (`ai_stress_arena.gd:1003`), not a ring. A ring-radius fallback aims the bound at open
ground.

**The overrun would be unverifiable in the only place we can iterate on it without a full world
boot.** Whatever the fix (group in `Destructible._ready`, or a shared adopt helper), ADR-023 forbids
leaving two ways to mark a parapet — pick one, and delete the other in the same change.

And already live in the tree: `destructible.gd:50-52` asserts *"SiegeDirector polls this on the
`fsb_parapet` group to find its breach axis."* Grep: `siege_director.gd` contains **zero**
occurrences of `fsb_parapet` or `is_destroyed`. **A comment describing a caller that does not
exist** — POINTER LAW violation, written this session, and it is exactly the shape
`CLAUDE.md:288-292` warns about: it reads as load-bearing, it survives grep, and the next agent will
assume the wiring is done.

---

## B. SPOOKY'S REAL ROUNDS

### B.1 It will kill the garrison, the squad and the player, and nothing in the proposal says so

`cas_airplane.gd:66` — `const STRAFE_MASK: int = 1 | 32 | 64 | 512`.
Hitzone layers, measured:

| Body | Hitzone layer | Pointer |
|---|---|---|
| Player | **32** | `player.gd:902` — `_build_static(self, 32, 16, ...)` |
| Allies / garrison | **32** | `ally_base.gd:442` — `build(self, ma, 32, 16, ...)` |
| Enemies | **64** | `enemy_base.gd:462` — `build(self, ma, 64, 8, ...)` |

`STRAFE_MASK` includes **32**. Copying `_fire_strafe_burst` into `_fire_vulcan` gives the AC-47 a
gun that hits US bodies and the player with no faction test whatsoever.

Now the damage. `data/weapons/aircraft_20mm.tres`: `base_damage = 87`, `min_damage_mult = 0.85`.
ADR-016 zones (`CLAUDE.md:196`): TORSO ×2.5 → **217**. HEAD → fatal, bypass. Player HP **100**.
Enemy HP 65–85.

> **One 20mm round anywhere on the player's torso is instant death. One round is instant death for
> any ally. There is no falloff at 160 m that changes this.**

Rate: `VULCAN_INTERVAL 0.35` × `VULCAN_ROUNDS_PER_BURST 3` = **8.57 rounds/s**, for
`DURATION 30.0` s = **~257 rounds per call-in** (`spectre_gunship.gd:21-24`). Beaten zone is
centred on `target`, and the siege objective is `FieldDirector.siege_aim` — **the bench inside the
wire** (briefing; `field_director.gd:881-884`). `FirePlan.SPECTRE_BEATEN_M = 25.0`
(`fire_plan.gd:34`).

**Concrete:** player calls Spooky during the siege (`field_director.gd:505-506`) at the wire, as any
player will, because that is where the enemy is. 257 one-shot-kill rounds land in a 25 m disc that
contains the garrison, his own fireteam and himself. The current fake version at least routes
through `CombatManager.apply_explosion_damage(..., 4 m kill radius, 0.2)` with an explosion falloff
and a 4 m radius (`:163`). The real version replaces a 4 m squishy blast with 257 instant-lethal
line-of-fire kills over the whole 25 m disc. **This does not make the gunship more believable. It
makes it a Summoner-killer and a squad-wipe button.** Pillar 5 (*fail forward, not a sadism
simulator*) and Pillar 4 (*the squad is the RPG*) both take the hit.

If the intent IS friendly fire — which is defensible and arguably period-correct — then it needs a
**minimum safe distance** and a refusal-to-fire arc, and that is a design decision for the Summoner,
not an implementation detail of "make the rounds real." **Nobody has asked him.**

### B.2 The real gun MISSES, because saturation and precision are opposite settings

The fake Vulcan picks a **new uniformly-distributed point over the whole 25 m disc every 0.35 s**
(`_zone_point(1.0)`, `spectre_gunship.gd:147-153`) and applies a 4 m kill radius there. That is why
it reads as saturation: the beaten zone is genuinely covered.

A real round is dispersed by `base_spread = 1.4` (degrees) from one aim vector. Slant range from
`ORBIT_ALT 130` / `ORBIT_RADIUS 160` is ~206 m. 1.4° at 206 m ≈ **5.0 m** cone radius. Copy
`_fire_strafe_burst` literally and you also inherit `STRAFE_SPREAD_M = 4.0` box scatter — still
~±4 m. So real rounds land in a **~5 m** patch, not a **25 m** disc: the beaten zone shrinks by a
factor of **25 in area** (π·25² → π·5²).

Two outcomes, both bad:
- Keep one aim point per burst → a 5 m pencil. The Vulcan hits whatever is at one spot and nothing
  else. From 130 m up, against men who are moving and prone behind a berm, it will frequently hit
  the berm. Reads as **a gun that misses**.
- Re-randomise per round across 25 m → a 20°-wide fan of tracer from a single airframe, which does
  not read as a minigun; it reads as a shotgun in the sky.

The honest answer is neither: it is **re-aim per burst across the disc AND keep the rounds real**,
which is what the current code already does for the *impact* and does not do for the *flight*. That
is a genuine redesign of the fire solution, not a copy of `_fire_strafe_burst`.

### B.3 Budget — MAX_BULLETS is not the constraint; the tick and the tracer cap are

- Spooky alone: 8.57 rounds/s at 1030 m/s over ~206 m = 0.20 s flight → **~1.7 rounds in flight**.
  Nothing. `MAX_BULLETS = 500` (`bullet_system.gd:32`) is not threatened by the gunship.
- The real budget pressure comes from the *combination* the handoff already flags: a 50-man siege
  (`LIVE_CAP` 50) + a CAS gun at `STRAFE_INTERVAL 0.08` × 3 = **37.5 rounds/s** + Spooky. The
  comment at `:26-30` estimates ~100/s from an aircraft gun. That still leaves headroom, but
  **nobody has measured it** — `_peak_bullets` is instrumented (`:41-42`, `:63`) and has never been
  read from a real boot.
- **Physics tick is 30 Hz** (commit `c38647d3`). At 1030 m/s each round advances **34.3 m per
  tick**. The segment raycast prevents tunnelling, but the *loop cost* is one raycast per round per
  tick and the tick is now half as frequent, which halves temporal resolution of every hit event.
  A round crossing a man's 0.4 m-deep torso resolves from a 34 m segment — fine for a hit test,
  but the reported impact point and therefore the FX position quantise coarsely.
- `MAX_TRACERS = 48` (`:33`). Spooky wants 8.57 tracers/s with a ~0.2 s life = ~2 live. Fine alone;
  combined with a 50-man siege the tracer pool starves and the visual budget, not the sim, is what
  the player sees. **The FAKE version's tracers were unconditional** — `BulletTracer.spawn_tracer`
  at `:161`, outside the pool. Going real puts Spooky's tracers into a **contended 48-slot pool**,
  so the more the siege fires, the LESS visible Spooky's gun becomes. That is the thing the fake
  version gave us that the real one takes away, and it is the one thing Spooky exists for.

### B.4 What the fake version gave us

Guaranteed coverage of the beaten zone · guaranteed visible tracer · zero friendly-fire surface ·
zero bullet-budget contribution · a man behind the berm spared by a cheap visibility guess rather
than by geometry. **We are trading a working spectacle for a physically honest gun that is less
visible, less accurate, and lethal to the wrong people.** The briefing states the airframe holds
"two different ideas of what a round is" — true, and consistency is a real value. It is not worth
the demo.

---

## C. THE FLOATING ROUND (Mosin) — a runtime hide is a fossil the day the export lands

The Summoner's report is a **viewmodel** bug and it is the FP pipeline, which memory
`recongame-blender-godot-pipeline-priority` calls the MAIN PRIORITY. It must be fixed. But not in
Godot.

### C.1 The root cause is two disagreeing parts manifests — an ADR-023 divergence

| Source | Mosin `parts` | Pointer |
|---|---|---|
| `tools/viewmodel_manifest.json` | `["Mosin", "Mosin_boltknob"]` | verified by reading the file |
| `tools/fp_pose.py` | `('stripper_clip_Mosin', 'Mosin_boltknob', 'Mosin')` | `fp_pose.py:35-36` |

**Two lists of what the Mosin is made of, and they disagree about the exact node that is floating.**
That is the FOSSIL LAW's disease verbatim: two things an agent could read as the same thing. The
stripper is a declared part in the pose tool and an undeclared stowaway in the export manifest —
which is why it exports as a ROOT and why the `--strict` export gate never objected. **The export
gate validates length against `real_length_m`; it does not validate that no undeclared root
escaped.**

The manifest's `clips` list is also drifted: it names 6 (`rifle_idle, reload, reload_empty,
charge_handle, fire, jam`) while the briefing measured **8** in the GLB including `mosin_round_load`
and `mosin_idle`. And `tools/gen_weapon_audio.py`'s sibling problem aside, memory
`recon-fire-is-procedural-in-godot` says a `fire` clip should not be authored in Blender at all —
yet `fire` is in the manifest's clip list. More drift in the same file.

### C.2 If we hide it at runtime anyway, here is the exact deletion condition

Godot has **zero** references to the node today — grep over `scripts/ scenes/ data/ tools/` for
`stripper|clip_round|Mosin_clip` returns hits only in `tools/fp_pose.py:28,35,36` and
`tools/retarget_ref_anim.py:248,417`. So a runtime hide would be **new** code with no precedent to
follow, existing solely to paper over an export defect.

**It is a fossil the instant the export is fixed,** and it is the *worst* kind, because it will keep
working: a `find_child("stripper_clip_Mosin")` guarded by a null check silently does nothing after
the re-export, so no test goes red and nobody ever learns it is dead.

If the Summoner rules for it as a stopgap, it MUST ship with:
1. **Deletion condition, written in the ADR and the tracking doc, not in a comment** (COMMENT
   DISCIPLINE): *delete the runtime hide when `tools/viewmodel_manifest.json` lists
   `stripper_clip_Mosin` under `parts` for `mosin` AND `mosin_fp.glb` exports it parented under
   `Mosin` rather than at root.*
2. A **test that fails when the export is fixed** — e.g. `tests/` asserts the GLB has a root-level
   `stripper_clip_Mosin`; the day the export lands, that test goes red and points at the hide. A
   stopgap with no ratchet is just a fossil with an apology.

**My recommendation: do not write the hide.** The correct fix is one manifest entry plus one
re-export, it is in his Blender queue territory, and there is already an uncommitted new
`mosin_fp.glb` in the tree (2.44 → 3.56 MB) — meaning **the defect is in a brand-new export that
nobody has validated.** Fix the exporter and the manifest, re-export once, delete nothing later.

---

## D. SCOPE — shipping more unverified code is negative value

### D.1 The arithmetic of unverified work

State of the ledger, from the handoff itself: *"Nothing below has been playtested by the Summoner"*
(`:6-8`). The gate table (`:20-26`) has **three of four clauses at "built, unverified"** and one
OPEN. Add six items and a bug, and the unverified pile roughly doubles.

Unverified code is not zero-value; it is **negative**, and the mechanism is specific:

1. **Diagnosis cost is superlinear.** When he boots and something is wrong, the suspect set is every
   unverified change. One bug across 12 unverified systems costs 12 bisections. The same bug across
   3 costs 3. Two of the four bugs I found above (§0.2 audio, §0.3 explosion keys) are *already*
   invisible inside the 7/29 pile.
2. **It generates drift faster than it generates features.** In this session's own untested output I
   found: a false CREDITS ledger (§0.2), a comment naming a nonexistent SiegeDirector caller
   (`destructible.gd:50-52`), two comments naming a deleted class (`ai_stress_arena.gd:56,277` —
   `DestructibleFortification` has **zero** `class_name` definitions repo-wide, and
   `test_support_fire_bench.gd:98-100` already forbids it in the *other* file), and ~30 lines of
   fresh tombstone prose (`bullet_system.gd:22-30, 52-65`; `enemy_base.gd:66-72`;
   `gen_weapon_audio.py:635-639`). `CLAUDE.md:234-252` — "no more drift", "correct it on contact."
   **The last session's untested output is where this session's drift came from.**
3. **It masks the ship gate.** Three clauses read "built" and none is confirmed. If the Huey
   disembark does not actually work (handoff `:23` — "disembark behaviour NOT confirmed"), then the
   gate clause *he cares most about* is broken and we are spending the session on the fourth clause.

### D.2 The verification budget for one sitting

He boots once and looks. Realistically that is **one boot, maybe two**, and a bounded eye-check
list. The handoff already defines that list (`:65-80`): six console prints plus four eye checks.
**That list is already longer than one sitting and it is from the LAST session.** There is no room
in this session's verification budget for six new items. Anything we add is guaranteed to arrive
unverified, by arithmetic.

### D.3 CUT LIST

**DO NOW — restore and verify, zero new features (call it 30 minutes):**
- **`git checkout -- assets/audio/sfx/weapons/`** — undo the synth overwrite of the licensed pack
  (§0.2). Then re-run the near-render with the `over=` overrides actually applied, or leave the
  recordings alone. This is time-critical: it dies the moment anyone commits.
- **Commit and push the 7/29 tree, including the ~180 untracked paths** (§0.1). `CLAUDE.md:425-446`
  already makes this mandatory and it was skipped. Do this BEFORE writing any new code, so that
  today's work is separable from yesterday's when he bisects.
- **Wire or verify the explosion-variant lookup** (§0.3). Four wavs were deleted; `audio_manager`
  and `gun_fx` still key the bare names. Silent explosions would read as "the whole demo is broken."
- **Correct four drifted claims on contact** (POINTER LAW, `CLAUDE.md:234-252`):
  `destructible.gd:50-52` (names a SiegeDirector poll that does not exist),
  `ai_stress_arena.gd:56` and `:277` (`DestructibleFortification`, zero definitions),
  `CREDITS.txt:64-72` (describes files the tree no longer contains).

**DEFER — blocked on a Blender re-export, not on code:**
- **C3 overrun push (item 1).** Blocked on the wire (§A.7) and on navigation having no hole
  (§A.6). Writing `press_assault` today produces unverifiable code that re-creates the bug he
  reported (§A.1, §A.2) and breaks the withdrawal (§A.3). The correct sequencing is: split
  `bwire_card_ring` into destructible segments in `tools/gen_firebase_v3.py`, decide the nav story
  (a pre-baked breach corridor per segment, or a link toggled on destroy), THEN write the doctrine —
  and write it as **advance-while-firing** inside `_execute_combat`, not as a fourth leg-theft
  override. If he wants motion at the wire *this* demo, the cheap honest version is to move the
  siege *objective* forward when a segment dies (one line in `siege_director._run_siege`, reusing
  the existing undriven-march path at `enemy_base.gd:1309-1311`, which already advances men who are
  NOT in contact and lets men who ARE in contact fight). Same spectacle, zero new override, zero
  mute men.
- **Spooky's real rounds (item 2).** Needs a Summoner ruling on friendly fire and a minimum safe
  distance before a line is written (§B.1), and a real fire-solution redesign to keep the beaten
  zone (§B.2). Do not copy `_fire_strafe_burst`.
- **F2 map verbs (item 6).** He explicitly asked that F3 wait; F2 without F3 is guessing at the
  interaction model twice.

**CUT ENTIRELY:**
- **The Mosin runtime hide (item 7 as a Godot fix).** Fossil-by-construction (§C.2). Fix the
  manifest + re-export instead; the divergence with `fp_pose.py:35-36` is the actual bug and it will
  bite the next gun too.
- **D1 convoy routing (item 5).** A whole road-network integration is not a demo-session item, and
  "convoys drive through buildings" is invisible in a 512 m firebase-holdout slice
  (memory `recon-demo-game`) where nothing is driving.

**KEEP — if and only if the DO-NOW list is clean and there is time left:**
- **A4 off-duty work markers (item 4).** 191 markers already ship in the GLB; the read is "the base
  is alive"; the failure mode is cosmetic and the verification is one glance. **Caveat and it is not
  small:** the garrison schedules were rewritten 7/29 (A3) and are themselves unverified, so
  building A4 on top means a schedule bug and a work-marker bug are indistinguishable. **Verify A3
  first, in the same boot, or A4 becomes the thirteenth unverified system.**
- **D3 ambient war audio cadence (item 3).** His note is a *tuning* note — "faster or a less
  occurring event." One constant in `ambient_war.gd`, one eye-check, no new system, no new coupling.
  This is the only item on the list that is genuinely a one-sitting change. Do it last, in five
  minutes.

### D.4 What this costs — the law binds me too

Cutting C3 means the demo ships **without** the largest gate clause. He asked for the VC to attempt
to overrun the firebase and we would be handing back "not this session." That is a real loss and I
am not pretending otherwise. My argument is that the alternative on offer is **not** the overrun —
it is 20 mute men grinding against an indestructible wire card, which spends the clause's credibility
rather than delivering it. Cutting Spooky means the airframe keeps two ideas of a round for another
week; that is an inconsistency nobody looking at the screen can see. Cutting D1 and F2 means two
known defects stay known. Restoring the audio and pushing the tree produces **zero new
spectacle** — the entire DO-NOW list is invisible to the player. That is the trade: one session of
nothing visible, in exchange for a tree where the next bug he reports can be found in one bisection
instead of twelve, and for the licensed gun recordings still existing.
