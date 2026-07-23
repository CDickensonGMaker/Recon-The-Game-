# RECONgame - Claude Development Guidelines

**RECONgame** is a hardcore Vietnam War open patrol simulator (Godot 4.7 stable, GDScript): one operation seed → a populated AO stamped around the firebase (villages, camps, ambient ecology) that you walk out into and come back from. No briefing UI, no objective counter, no exfil step — `"PATROL"` is the only mission type the generator produces (ADR-029; `scripts/missions/mission_generator.gd`). Arma/OFP sandbox bones, SOCOM/Vietcong flavor, RECON RPG (1982) numbers backbone, HLL lethality, AI fireteam, PSX low-poly 3D characters (ADR-001 — the sprite renderer is dead; 3D models for everything).

**CANON (ADR-014):** `production/GAME_GUIDE.md` + `production/adr/` outrank this file. If this file
contradicts an ADR, the ADR wins and this file gets corrected.

**Read these before designing anything:**
- `DESIGN.md` — pitch, setting, core fantasy, tone, player loop, pillars, AI stress-test arena, tech stack, development priority (APPROVED). No M0–M8 roadmap lives here.
- `STATE_OF_PROJECT.md` — origins (merged from HellOfDuty + TerrainEngine copies), decisions log.
  **READ FOR ORIGINS ONLY — its state-of-the-code is frozen at 2026-07-07 and is now WRONG.** Its
  MISSING/"build new" table (`:164-177`) lists the mission generator, AI alert states, stealth, saves,
  audio and VFX as unbuilt; all shipped (`scripts/missions/mission_generator.gd`,
  `scripts/enemies/enemy_base.gd:64` `enum AlertTier`, `scripts/autoload/save_manager.gd`). It also says
  Godot 4.5 (we are 4.7) and "all NPCs are colored capsules" (ADR-001: 3D models for everything).
- `MISSION_DESIGN_RESEARCH.md` — RTCW/MoHAA-derived mission/AI architecture
- `RECON_ADAPTATION.md` — tabletop rules → real-time mappings (detection, XP scoring). **Its damage section is DEAD — it still describes a dice grammar (`rifle hit = 4d10`) that ADR-016 retired. Damage is flat and deterministic; take damage from ADR-016 and the Damage System section below, never from this file.**

**Pillars (test every decision; merged and ruled 2026-07-19, text of record `production/bible/BIBLE.md:62-90`):**
1. **Believable firefights** — AI that fights like soldiers AND weapons that kill like weapons, neither subordinate · 2. **Atmosphere** · 3. **Freedom** (no rails, stealth is an economy not a gate; the seeded world generates the stories) · 4. **The squad is the RPG — and you are IN it, not above it** (you suggest and call; the squad holds its own AI intent — a design that has you positioning individual men violates this) · 5. **Fail forward** (escalation not fail-states; death matters, but this is not a sadism simulator).
`DESIGN.md:67-94` holds the superseded pre-merge text — do not cite it, and never cite `DESIGN.md §N`: that file has no numbered sections.

**Origins:** `scripts/`, `scenes/`, `assets/`, `data/` = Hell of Duty FPS core (copied; HellOfDuty project untouched). `terrain/` = TerrainEngine copy (res:// paths remapped to res://terrain/; original project untouched). RTS assets (structures, weapon data, unit data) get copied in from `C:\Users\caleb\RealVietnamRTS` as needed — never edit that project from here.

## Architecture Patterns (Quake 3/Spearmint Inspired)

### Core Principles
- **Tactical, deadly combat** - 1-2 shots to kill, player must be strategic
- **No armor pickups** - Fast and lethal, not arcade-style
- **Goal-driven AI** - Enemies make tactical decisions, not just react

### Key Patterns Implemented

#### 1. Timestep Capping (Framerate Independence)
```gdscript
# In _physics_process:
var capped_delta: float = minf(delta, 0.066)  # Max 66ms like Quake 3
```

#### 2. Separate Think/Execute (AI)
```gdscript
# Think on schedule (6-7 Hz), execute every frame
const THINK_INTERVAL: float = 0.15
think_timer += delta
if think_timer >= THINK_INTERVAL:
    think_timer = 0.0
    _think()  # Goal evaluation, target finding
_execute(delta)  # Smooth movement and aiming
```

#### 3. Goal-Driven AI
Goals (high-level): `ENGAGE_TARGET`, `SEEK_COVER`, `FLANK_TARGET`, `ADVANCE`, `RETREAT`
States (low-level): `COMBAT`, `SEEKING_COVER`, `FLANKING`, `ADVANCING`

#### 4. Smooth Aim Interpolation
```gdscript
current_aim_dir = current_aim_dir.lerp(target_aim_dir, aim_speed * delta).normalized()
```

#### 5. Multi-Point Visibility (Explosions)
Check 8 points around target - if ANY point visible, explosion damages target.

#### 6. Suppression System
- Enemies have `suppression_level` (0-1)
- Sustained fire increases suppression
- High suppression forces cover-seeking behavior

## GDScript Strict Typing Rules

Godot 4.7 (Forward+) with strict typing enabled. This project opens in **4.7 ONLY** — an older editor rewrites `project.godot`. Follow these rules to avoid type inference errors:

### 1. Float Interpolation
```gdscript
# GOOD
var mult: float = lerpf(1.0, 0.5, t)

# BAD - lerp() returns Variant
var mult := lerp(1.0, 0.5, t)
```

### 2. Float Min/Max
```gdscript
# GOOD
var val: float = minf(x, 1.0)
var val: float = maxf(0.0, x)

# BAD - min()/max() return Variant
var val := min(x, 1.0)
```

### 3. Integer Min/Max
```gdscript
# GOOD
var damage: int = maxi(1, calculated)
var clamped: int = mini(value, 100)

# BAD
var damage := max(1, calculated)
```

### 4. Method Returns That Could Be Variant
```gdscript
# GOOD - explicit types
var aim_dir: Vector3 = controller.get_aim_direction()
var target: Node = area.get_parent()
var hit_collider: Object = result.collider
var enemies: Array[Node] = get_nodes_in_group("enemies")

# BAD - can't infer type
var aim_dir := controller.get_aim_direction()
var target := area.get_parent()
var hit_collider := result.collider
```

### 5. Raycast Results
```gdscript
# GOOD
var result: Dictionary = space_state.intersect_ray(query)
if result:
    var hit_collider: Object = result.collider
    if hit_collider is Node and (hit_collider as Node).is_in_group("enemies"):
        var enemy: Node = hit_collider as Node

# BAD
var result := space_state.intersect_ray(query)
if result:
    var target := result.collider
    if target.is_in_group("enemies"):  # Error: Object has no is_in_group
```

### 6. Node Method Calls on Object Types
```gdscript
# GOOD - check type then cast
if hit is Node and (hit as Node).is_in_group("enemies"):
    damage_target = hit as Node

if hit is Node and (hit as Node).get_parent():
    var parent: Node = (hit as Node).get_parent()

# BAD - Object doesn't have Node methods
if hit.is_in_group("enemies"):
if hit.get_parent():
```

### 7. Vector Operations
```gdscript
# GOOD - explicit Vector3 for computed values
var direction: Vector3 = (target_pos - global_position).normalized()
var right: Vector3 = aim_dir.cross(Vector3.UP).normalized()
var origin: Vector3 = global_position + Vector3.UP * 1.5

# BAD when method returns could be ambiguous
var direction := some_method_returning_vector()
```

### 8. Function Parameter Types
```gdscript
# GOOD - use base types that work for multiple implementations
func setup(ctrl: CharacterBody3D, equip: EquipmentManager) -> void:

# BAD - overly specific types that may not match
func setup(ctrl: FPSController, equip: EquipmentManager) -> void:
```

## Project Architecture

### Physics Layers
| Layer | Name | Usage |
|-------|------|-------|
| 1 | world | Static geometry |
| 2 | player | Player body |
| 3 | enemies | Enemy bodies |
| 4 | player_hitbox | Player attack areas |
| 5 | enemy_hitbox | Enemy attack areas |
| 6 | player_hurtbox | Player damage receivers |
| 7 | enemy_hurtbox | Enemy damage receivers |
| 9 | projectiles | Bullets, grenades |

### Damage System (ADR-016 — flat base × zone, deterministic)
- `WeaponData.base_damage` is a flat `int` per hit. NO dice, NO rolls, NO flat-modifier arrays.
  `get_damage()` is pure; all variance comes from range falloff, hitzones, and the situation sim.
- Values of record (ADR-016 Amendment H — the great flattening, 2026-07-16, fun>realism, rounds even):
  **Base = 27 for EVERY rifle/SMG/pistol** (M16 · M14 · AK · PPSh · M1911 · Mosin, and any future
  base gun) · **MG class = 42** (M60 AND RPD) · **Sniper = 87** (M70 only; the Mosin stays 27 as the
  VC line rifle) · **Shotgun 35/pellet** (buckshot, unchanged, out of scope). Weapon identity now lives
  in accuracy/fire-rate/handling/recoil — NOT damage.
- **EXPLOSIVES — the Summoner's lethality decree (ADR-016 line 178). THESE ARE THE VALUES OF RECORD.
  The old table (M79 44 · M26 55 · LAW 72 · RPG-2 62 · RPG-7 73) is SUPERSEDED — do not "fix" a
  weapon back to it:**
  **M26 frag 190 · M79 HE 150 · M72 LAW 250 · RPG-2 250 · RPG-7 290.** A rocket is more lethal than
  a grenade, and shrapnel is the point.
  *(This line was stale for weeks, and because CLAUDE.md is injected into EVERY session, it made two
  War Room architects independently "verify" a canon violation that did not exist. A stale CLAUDE.md
  is not a wrong note — it is a DRIFT GENERATOR.)*
- Zone multipliers (Amendment D): HEAD = fatal (bypass) · TORSO ×2.5 · GUT ×2.25 + bleed · LIMB ×1.0
- Player HP: 100 · Enemy HP: 65–85
- Guarded by `tests/test_flat_damage.tscn` — retuning a value without amending ADR-016 turns the suite red.

### Key Classes
- `Hitzone` - Body part damage detection (extends Area3D) — **the ONLY damage receiver class. There is no `Hurtbox` and no `Hitbox` class; wire receivers as `Hitzone` (`scripts/combat/hitzone.gd`), built by `HitzoneBuilder`, tuned by `HitzoneTuning`.**
- `WeaponData` - Weapon stats resource
- `EnemyData` - Enemy configuration resource

## Weapon Viewmodel System

### CRITICAL: Camera/Viewmodel Setup (DO NOT CHANGE)
The viewmodel editor and in-game camera must stay perfectly synchronized:

**Player Scene (`scenes/player/player.tscn`):**
- Head node at Y=1.7
- Camera3D as child of Head (no transform offset)
- WeaponHolder as child of Camera3D with **NO transform offset** (identity transform)

**Viewmodel Editor (`scenes/weapons/viewmodel_editor.tscn`):**
- Camera3D at Y=1.7, FOV=75
- WeaponHolder as child of Camera3D with **NO transform offset**

**Rules:**
1. WeaponHolder must have identity transform (no offset) in both scenes
2. Base/hip FOV is 75.0; ADS uses per-weapon `ads_fov` from the .tres (ADR-004 — e.g. M16 60, AK 62, M14 58). Binoculars are NOT a weapon resource — there is no binocular .tres; the 18.0 zoom FOV is hardcoded in `scripts/player/player.gd`
3. Weapon positions set in WeaponData .tres files, not in scene transforms
4. Scale baked into viewmodel .tscn root node, not applied at runtime

### Viewmodel Scene Structure
```
WeaponViewmodel (Node3D) <- Scale goes here (e.g., 0.03 for Thompson)
├── Model (GLTF instance) <- Rotation offset to orient barrel to -Z
└── MuzzlePoint (Marker3D) <- Tracer spawn position
```

### Adding New Weapons
1. Create `scenes/weapons/{weapon}_arms_viewmodel.tscn` (the `_arms_` convention is what the guns use — `m16a1_arms_viewmodel.tscn`, `ak47_arms_viewmodel.tscn`, `m60_arms_viewmodel.tscn`; only non-gun items like `m26_grenade_viewmodel.tscn` and `medkit_viewmodel.tscn` drop it)
2. Set root node scale (start with 0.03, adjust as needed)
3. Set Model rotation to orient barrel toward -Z
4. Add MuzzlePoint at barrel tip
5. Create `data/weapons/{weapon}.tres` with positions
6. Use viewmodel editor to fine-tune hip/ads positions
7. Keep hip_rotation and ads_rotation values numerically close (within 90°) to prevent spinning during ADS transition


## NO MORE DRIFT — correct it on contact (Summoner's standing law, 2026-07-19)

**Summoner:** *"no more drift."*

COMMENT DISCIPLINE, the FOSSIL LAW and the POINTER LAW are three faces of ONE disease. A fossil is dead
code that reads as live. An unpointered doc is a claim that reads as verified. A stale charter is retired
law that reads as binding. Every time, something in this repo asserts a state of the world that is no
longer true — and the next reader, human or agent, acts on it.

**THE RULE: when you touch a file and find a claim in it that is no longer true, you correct it or note
it IN THE SAME CHANGE. You never read past it.** Drift survives because everyone who noticed it was busy
with something else.

Measured 2026-07-19, each verified against code: the damage table below (`:180-187`) that made two War
Room architects independently "verify" a canon violation that did not exist · four beads sending agents
to hunt a `WorldBuilder` class with **zero hits repo-wide** · a `.gitignore` comment justifying an
untracked 133 MB truth source as regenerable from `us_grunt_v2.blend`, **a file that does not exist** ·
and `.claude/agents/recon-overseer.md:58` — *the head agent's own standing instructions* — enforcing the
RECON dice that ADR-016 retired (`production/adr/ADR-003-one-damage-grammar.md:2`).

---

## COMMENT DISCIPLINE — stop narrating (Summoner's law, 2026-07-13)

**Summoner:** *"not put so many notes into the code as we are writing it — i think itll cut down on
our project time in half."*

Measured when he said it: **20% of this codebase is comments** (6,508 / 32,141 lines). Worst files run
37–54%. **285 are tombstone comments** — prose narrating the project's past *inside the source*:
`## this file used to hardcode 130` · `## GUNSHOT was 55m` · `# was a hardcoded ALERT_RANGE*2`.

**None of that documents the code. It documents the pull request** — the agent explaining to a reviewer
why its change was right. That belongs in the commit message and the ADR. Both already exist here.

**And it is not merely noise — it camouflages fossils.** `# was a hardcoded ALERT_RANGE*2` is the exact
comment that hid the dead `ALERT_RANGE` const from the fossil probe. **A tombstone comment hides the
corpse it marks.** Comment discipline and the FOSSIL LAW are the same law.

**THE RULE.** Write a comment ONLY to state a constraint the code cannot show — a units contract, a
non-obvious invariant, "do not reorder these two lines, and here is the physical reason."
**NEVER** to say what the next line does · where the code came from · what it used to be · why the
change is correct · which bead it came from. No `## WHY:` essays. No changelogs in file headers.
When tempted to explain history: **put it in the commit message or the ADR.**

---

## THE FOSSIL LAW — delete the old system when you replace it (ADR-023)

**Summoner's standing law, 2026-07-13:** *"when we improve or fix a system we always need to clean up
the old system so we don't have multiple things that could accidentally be interpreted by you as the
same thing when coding."*

**A system's replacement is not shipped until its predecessor is DELETED.** Fix the thing, then bury
the corpse — in the same change, not "later".

**This law exists because of YOU, the agent reading this.** A **fossil** — a const nobody reads, a
signal nobody connects, a function nobody calls — is not a bug. The game runs fine with it. It is
worse than a bug: **it is a lie in the map.** It reads as load-bearing and it survives every grep,
and you cannot tell it from live code. You will use the wrong one. That has already happened here.

Found on 2026-07-13, five systems, one session — **and the game worked the whole time:**
- `ALERT_RANGE` / `AGGRO_RANGE` — superseded by `enemy_data.alert_range`. *The replacement's own
  comment says so.* Never deleted.
- `MAX_THINK_TIME` — a Quake-3 pattern never wired. `last_think_time` never even assigned.
- `CombatManager.apply_bullet_damage` — **a whole damage router the bullets route around.**
- `.gitignore` rules naming `art_source/` — a tree that was deleted. The rule didn't fail, **it
  stopped matching**, and swallowed 1.66 GB.
- the GATE bead — `k77e` was never `bd dep`-linked. **A gate that blocked nothing**, for ~95 commits.

**Nothing was broken. Everything was a lie about what the code means.** This project's problem is not
fractures — it is fossils.

**THE MACHINE (because a law in Markdown is just the next fossil):** `tests/test_fossils.tscn`, in the
suite. The existing fossils are grandfathered in `tests/fossil_baseline.json` (`:2-3` — `ceiling` 27,
`count` 27, as of 2026-07-19), under a `ceiling` that only ratchets down. **A NEW fossil FAILS THE BUILD.** The register **only shrinks.**

`--write-baseline` writes the intersection of register and reality and is incapable of growth. New
entries enter ONLY via `--grandfather --reason="<text>"`, which appends dated provenance to
`grandfather_log`. `count` and `ceiling` are audited before the register is consulted, so a hand-edit
cannot pass quietly. Regenerating the baseline to silence a failure remains **the one forbidden move**
— it is a debt register, not a snooze button.

Two rules the probe had to learn, and they are the law in miniature:
1. **A comment is a tombstone, not a caller.** `# was a hardcoded ALERT_RANGE*2` was counted as a
   reference — *the sentence recording the const's death was keeping it off the death list.*
2. **The death register is not a caller.** The baseline names every grandfathered symbol; tallying it resurrected them
   all. **The fossil detector was defeated by its own record.**

Dead ≠ delete. Triage first: **FOSSIL** (superseded → delete) · **UNFINISHED** (built ahead of its
wiring → wire or cut) · **MISSING FEATURE** (documented, never built → build it, e.g. `world_config`'s
FPS-fallback ladder is read by *nothing* while perf is the top systemic risk). Deleting on a
zero-reference count alone is how you lose the game: **913 of 1,291 assets have zero grep hits**, and
`ModelActor` resolves the entire cast from bare `unit_id` strings.

---

## THE POINTER LAW — an assertion with no pointer is an opinion (ratified 2026-07-19)

**Any document that asserts the state of code must cite `file:line` or name the probe that proves it.
An assertion with no pointer is a dated opinion and must carry a date banner.**

This is the FOSSIL LAW pointed at prose. A fossil is a lie in the map; an unpointered doc is a lie
about the map. You cannot tell either from truth by reading it, and you will act on it.

Five incidents cost this project real work, and one rule catches all five: the damage table · the
fossil counts · the `terrain/` blind-spot claim · the four beads that sent agents hunting a
`WorldBuilder` class that has zero hits repo-wide · the `.gitignore` comment justifying an untracked
133 MB truth source as regenerable from `us_grunt_v2.blend`, **a file that does not exist**. Every one
read as current fact. Not one carried a pointer.

Cite the pointer, or date the line and mark it as of-its-time. The healthy docs already do it —
`ADR-016`, `PERF_LEDGER.md`, `bible/04_AI_LOCOMOTION.md`, `research/engine_mining_2026-07-18/`.
Copy them. **When you cannot find a pointer, that is the finding** — note it in the tracking docs, do
not soften the claim and move on.

**THE MACHINE:** `tools/probe_doc_pointers.py` — flags any doc asserting code state with neither a
`file:line` nor a date banner. Weak by design: it catches the shape, not the truth.

---

## THE WAR ROOM IS THE DEFAULT PROCESS — for ANY change, not just big ones

**Summoner's standing law, 2026-07-12:** *"make that the key workflow when we do any big run of
anything OR ANY SMALL FIX AT ALL."*

Convene the council **before building**, even for a small fix. It is not ceremony — on 2026-07-12 it
caught, in a single session:
- a standing **P0 GATE bead** that mechanically forbade the feature about to be built (ADR-015),
- a **live shipping bug** nobody had noticed (one grenade converted 256m of authored jungle into
  procedural palms — `vegetation_manager.clear_area()`),
- a **landmine in the plan's own "highest-value fix"** that would have set the entire map to a 45m
  sight cap (`ClearingSystem`'s map is `fill(1.0)` — a clearing MASK, not a density),
- and two **wrong council claims** the Arbiter had to overrule. The process cuts both ways.

**How:**
1. Summon 3–4 architects **in parallel, with no cross-talk.** That independence IS the value — when
   they converge from different doors, it is the strongest signal this process produces.
2. Each **reads the code, never the plan.** Three times in one day the codebase beat the document.
3. They write full analyses to `production/war_room/analysis/` and return **only a short verdict**,
   so the Arbiter's context survives.
4. Arbiter weaves a synthesis, **names what is sacrificed** (no free lunches — the law binds the
   Arbiter too), and records the outcome in the project's tracking docs.

**Load into every architect brief:** `~/.claude/architect_knowledge/GodotPrompter/skills/<topic>/`
(51 domain skills, Godot 4.3–4.7), `godot_4.7_features.md`, and `godot_standards.md`. The Summoner
added these deliberately and asked that they be used.

---

## Task Tracking

Beads (`bd`) is **RETIRED** (2026-07-22). It accumulated false "done" claims — beads closed as complete
while the art logs still listed the same work unfinished — so it now costs more than it tracked. Track
outstanding work and open questions in the project's source-of-truth docs and in Claude memory instead:
- `production/CALEB_TODO_7_22_updated.md` — the owner's live task list (sources of truth)
- `production/ART_Track_Log.md` — art/weapons/animation/structures master list
- Claude memory (`~/.claude/projects/.../memory/`) — durable cross-session facts and rulings

Do NOT resurrect `.beads/` and do NOT run `bd`. Do not trust any surviving bead export as current truth;
the two docs above and code pointers win.

### THE SESSION ENTRY GATE

**PLAYTEST R4 is the standing session entry gate — resolve it FIRST, before anything else.** It checks
the ADR-029 open-patrol loop: boot seated at `fsb_main` → out the wire gate on one diegetic pointer →
find a site unguided → fair contact → squad behaves → AAR banks at the gate
(`scripts/missions/field_director.gd:602-614`). It is discharged only by a **verified playtest by the
Summoner** (ADR-015) — never by a probe, never by an agent's reading. Until he has verified it, gated
feature work stays parked.

### THE DECISION QUEUE — open every session by asking him, not by building

**Summoner's standing practice, 2026-07-20:** *"we should be starting every session with me answering
questions that can move the needle forward."*

Open each session by surfacing the decisions only he can make — every hour a needle-moving question
sits unanswered is an hour of work aimed by guesswork. On 2026-07-20 he cleared 25 in one sitting and it
redirected the entire session: two systems retired, two ADRs deleted, three "blocked" items already
shipped.

**Put every question to him GLOSSED, in plain words he can rule on without opening any file or tracker**
(Summoner's rule, 2026-07-19: *"the beads are really cryptic to me and hard to answer in the moment"*).
Name the subsystem, then state the defect or goal plainly. A wave code or bare acronym is a handle, not
a question.
- Bad: `PIVOT W4 [AWAITS RATIFICATION]` · `AI-CONSOLIDATION WA`
- Good: `Convoys spawn with an empty vehicle array, so none has ever moved`

Record his rulings verbatim in the tracking docs (and Claude memory when durable) so they stay findable.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **Record remaining work** - Note follow-ups in the project's todo/tracking docs and Claude memory
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update the todo docs** - Mark finished work done, update in-progress items in the tracking docs
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
