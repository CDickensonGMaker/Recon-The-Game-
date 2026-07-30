# DEMO — SESSION HANDOFF, 2026-07-30

**Read first:** `production/DEMO_SHIP_BACKLOG.md` (the master tracker) and
`production/war_room/2026-07-30_demo_backlog/synthesis.md` (the decree, with the four council
claims the Arbiter REFUTED and the two Arbiter designs the council KILLED).

**Nothing below has been playtested by the Summoner.** A log line is a claim; the eyes are the
authority. Supersedes `DEMO_SESSION_HANDOFF_2026-07-29.md` for everything it covers.

---

## THE FOUR THINGS THAT WERE SILENTLY BROKEN

Each was found by reading code, and each had been shipping as if it worked.

1. **The demo's night assault had never happened.** `SIEGE_STRENGTH 40` was declared and never
   applied: `_open_siege` hit the `if d.siege.active` guard (`demo_game.gd:197-203`) and
   toasted. The 600 s probe's `MAX_DURATION_S 480` expires at exactly `DAWN_AT_S 1080`, so that
   branch was taken EVERY time. **Every demo night ever played was 11 men, announced twice.**
2. **The CAS gun run one-shots you and your whole garrison**, and its comment claimed the
   opposite. Layer 32 is the player hurtbox, not "enemy bodies". 87 × 2.5 = 217 vs 100 HP.
3. **`ACTION_WORK` never walked a man to his post**, so the whole 7/29 night shift never manned
   anything — it only looked right because spawn teleports everyone.
4. **A viewmodel whose clips are not named `rifle_idle` / `charge_handle` plays NOTHING.**
   `weapon_holder.gd:929,937` ask for those literal strings, so a prefixed export silently sits
   in its rest pose. A code contract worth knowing for every gun. *(The specific gun this was
   found on is the Summoner's live work — hands off, see below.)*

---

## WHAT LANDED 7/30

**The overrun (C3).** `Context.assault_press` + `CombatGoals.PRESS_ADVANCE 0.75`;
`EnemyBase.siege_press`; `SiegeDirector._rotate_press` (`PRESS_CYCLE_S 8.0`,
`PRESS_FRACTION 0.35`, never a satchel man, never a probe, cleared on break).
`inside_count()` + `siege_overrun` -> "THEY'RE INSIDE THE WIRE" + siren.
**The lane is the GATE on purpose** — nothing reads a breach, so nothing is art-blocked.

**The escalation.** `SiegeDirector.reinforce(extra)`; `SIEGE_STRENGTH` 40 -> **45 total**.

**Friendly air.** Mask unchanged and lethal; `authored_strike(..., danger_close)` +
`GUN_STANDOFF_M 120` + 12-bearing rotation; `[G]` is danger-close; ambient Spectre keeps out
of the player.

**Spooky's vulcan is real.** 90 rounds/s on the physics tick, port muzzle, dispersion by
re-aim. `bullet_tracer.gd` DELETED. `BulletSystem.fire(..., mark_surface)` added.

**A4.** `_bt_work` walks to its marker and holds; `off_duty` 20.5–22.0 SIT -> WORK.

**D3.** Two answering parties, burst clocks, 900 Hz low-pass, ragged tail, `FIRE_CAP 2`, and
the 7/27 per-weapon distant reports finally adopted.

**F2.** LEFT = pencil, RIGHT = eraser (new `MissionState.erase_pencil_mark_near`).

**The garrison lights its own wire (C6).** `FieldDirector.garrison_illum` +
`SiegeDirector._walk_illum`: 140 m out on the attack bearing, first at 12 s, then every 70 s,
burning 55 s so there is real darkness between rounds. Never bills his illum stock. **Without
this the whole overrun happened in the dark** — 56 m night sight against a 190–235 m approach.

**Convoys (D1, partial).** The column used to be born INSIDE the compound — strung 30 m straight
back off `route[0]`, which at the gate is inside the wire. It now seats along its own route by
arc length. And nothing ever set rotation, so the column crabbed sideways through every bend;
`_face_along` now turns each vehicle onto its direction of travel.

---

## LATE 7/30 — THE COUNCIL'S CODE-ONLY FIXES (no Blender time, no playtest needed to be safe)

**Six more byte-identical BT freezes killed.** `_bt_rest/_bt_cook/_bt_sleep/_bt_fish/_bt_sit/
_bt_talk` were the same freeze copy-pasted six times beside `_bt_work`. All SEVEN now route
through ONE `_bt_settle(action, bb, speed)` (ADR-023 — one implementation, not seven), which
walks to whatever the schedule resolved and then holds, with the same name-derived offset so two
men never share a skin. **The cook now cooks AT the field range; the sleeper no longer sleeps on
his feet in the open.** New `IDLE_SPEED 0.8` — a man crossing camp to sit down does not march.

**Interior props are culled past 40 m** — `site_planner._cull_interior_props`. MEASURED out of
`fsb_main_v3.glb`: **826 visible surfaces, of which 368 (44.6%) are the 178 `fb_int_` props,
carrying 11,936 of 318,056 triangles (3.75%).** Nearly half the compound's draw calls buy 4% of
its geometry, and nothing had ever set a range on them. A cot is occluded by its own hootch long
before 40 m, so the fade is unobservable. **This is the cheap half; the MultiMesh pass (368 → ~11)
is the rest and must delete the `fb_int_` bake in the same change or every prop doubles.**

**THE BUTCHER'S BILL EXISTS.** `CampaignState.kia_total` (never decrements) · `ward_wounded` ·
`bags_unlifted`, on all three serialisation paths (.cfg, `to_dict`, `from_dict`) and defaulting to
0 on older saves — nobody was counting, so a pre-7/30 tour honestly starts at zero rather than
inventing a past. `on_mission_end` now BANKS the dead: `squad_system.gd:443` has always named
every man lost into `state.flags["squad_kia"]`, `build_result` copies every flag into the result,
and this function **threw the list away** before `SquadRoster.ensure_roster` deleted the bodies —
so nothing in the campaign remembered that anyone died.
`WARD_SEED_ON_NEW_TOUR = 2` on a wipe (his ruling; a fixed number, not an unseeded roll).
**The wounded are DERIVED and deliberately so:** `ally_base.gd:41` states that allies have no
downed state, so a squad member is alive or dead and there is no per-man WIA to read. The ward
fills from the FIGHT at `WIA_PER_KIA = 3`, saturating at `WARD_BEDS_MAX = 12`. An explicit
`result["friendly_wia"]` always wins, so a future real wounded state needs no change here.
**Delete the derivation the day allies gain one.**

**`Destructible.is_destroyed()` is now THE answer, not a fossil.** It shipped this morning with
zero callers. `siren_tower.gd` was inferring death from a *MeshInstance3D's `.visible`* — which is
wrong the moment anything else hides a mesh, and as of tonight a visibility range does exactly
that at 40 m. It now walks up for the Destructible and asks. `_do_destroy` never frees the node,
so `is_instance_valid` passes forever on a structure that is gone; that is the trap this closes.

---

## HUEY TROOP DELIVERY / EXTRACTION (late 7/30, unverified)

`Helicopter` has emitted `landed`/`took_off` and `SeatSystem` has offered
seat/unseat/unseat_all/board_squad since both were written, with **zero production callers** —
so a Huey landed on the pad, idled out its ground seconds and left EMPTY, and the ship-gate
clause "Huey landings with troops disembarking" was scenery. `HeliLift`
(`scripts/vehicles/heli_lift.gd`) is the consumer, attached in `air_traffic._dispatch_lz_cycle`.

**Mission is decided at DISPATCH**, not touchdown, because a delivery must arrive with men
already aboard. The concealment rule is satisfied by the DOORS: shut the whole way in, opening
only once the wheels are down. `Door_Left`/`Door_Right` are driven off their AUTHORED shut pose,
never an assumed zero.

**Need drives it, not a coin** (a deliberate change from the brief's "roll", flagged to him):
under `ESTABLISHMENT 28` the ship brings replacements; at strength it takes men out. That makes
the pad logistics and makes the butcher's bill mechanical — men die, the garrison drops, the next
ship brings their replacements.

**His two rulings:** delivered troops arrive as garrison **Civilians** reusing the existing
promote path (an AllyBase would be a second path against ADR-023, is full-cost always where a
Civilian is LOD-aware, and has no schedule or work marker so it would stand where it landed);
and they **persist against the cap** — replacements fill vacancies and never stack.

`garrison_strength()` counts `firebase_garrison` AND `garrison_promoted`, because `promote()`
moves a man between them and counting one reports half a garrison mid-siege. A ship landing INTO
a fight promotes its men immediately rather than leaving them walking to work posts.

**Clips:** all six `disembark_heli` / `_b`–`_f` are present (`anim_library.glb` re-exported
2026-07-30 23:05, 112 clips). `BOARD_CLIPS` is **empty on purpose** — boarding is still being
mocapped and the library holds zero `board` clips, so no names were invented. Filling that one
const is the only change needed when they land; the call site is already there.

**NEEDS AN EDITOR REIMPORT before it can be judged.** `HeliLift` is a new `class_name` with zero
entries in `.godot/global_script_class_cache.cfg`, so `--check-only` reports
"Identifier not found: HeliLift" until the editor rescans. Every `class_name` in this project has
needed that step.

**Unresolved without his eyes:** `huey.tscn` ships no `SeatSystem` node, so one is attached at
runtime and falls back to the measured UH-1 layout. If the airframe exports real seat sockets
those win; if the fallback is in use, seated men may sit slightly off the bench.

---

## VERIFY THESE FIRST (one boot, then read the console)

| Print | What it answers |
|---|---|
| `[Siege] reinforced +34 - the assault is now 45 men (peak 45)` | the 720 s beat finally fires |
| `[Siege] perimeter measured from N parapet segment(s) over 36 bearings` | the overrun can judge "inside" at all |
| `[Siege] press wave N: X of Y men crossing` | the assault is pressing, not sitting |
| `[Siege] OVERRUN - N attacker(s) inside the wire` | the gate lane works |
| `[AmbientWar] ... held silent - 2 firefights already sounding` | the cap is reporting itself |
| a lit circle 140 m out, going dark ~15 s between rounds | the garrison is lighting its own wire |
| `[FSB] N interior prop(s) culled past 40m` | expect **178** — the draw-call fix is live |
| `[LIFT] inbound with N replacement(s)` / `[LIFT] delivered N` | the Huey is really carrying men |
| `[LIFT] extracting N man/men from the pad` | the extract branch found eligible men |
| `[CAS] no clear gun axis 120m off the player - napalm only` | the aiming discipline is live |
| `[NAV] ally ... no path` count | was 8; still the A1/A2 question |

**Then look with your eyes at:** do the VC funnel through the GATE and get inside · do the
sentries WALK to the wire at dusk instead of appearing on it · does a distant firefight sound
like two sides arguing rather than one pop · does Spooky's gun draw a rope of tracer · are your
bullet holes still there after a gunship pass.

---

## OWED, AND HONESTLY OWED

- **THE FULL PARSE GATE.** His Godot editor was open all session, and two editors writing
  `.godot/` can corrupt the import cache, so `--headless --editor --quit` was NOT run.
  `--check-only --script` over all 17 changed files gave **zero `Parse Error`s** (the syntax
  pass) and 13 `Compile Error: Identifier not found`, every one naming one of the 14 autoloads
  at `project.godot:32-44` — the documented blind spot. **That proves no syntax errors and
  cannot prove no type errors.** Run the full scan the moment the editor is closed.
- **THE MOSIN IS HIS AND IS OFF LIMITS.** His instruction, 2026-07-30: *"skip anything with the
  mosin, im live working on that."* Nothing in this session wrote to a Mosin asset — the GLB was
  parsed read-only, no Blender tool was run, and no Godot-side workaround was shipped. It was
  swept into the safety commit by `git add -A` and is excluded from every commit after that.
  **Do not open, re-export, validate or "fix" the Mosin, and do not act on any earlier note
  about it — his live version is the only truth.** One durable fact worth keeping, because it
  is a CODE contract and not his art: `weapon_holder.gd:929,937` ask for the literal clip names
  `rifle_idle` and `charge_handle`, so bare names are what the game can see.
- **`CREDITS.txt` credits generated gun audio to "Snake's Authentic Gun Sounds".** A licensing
  question, not a code fix. The alarm that the synth had just overwritten real recordings was
  REFUTED — `fire_m16a1_1` and `fire_car15_1` were already byte-identical at HEAD.
- **`us_artillery_m101_RECOVERED.blend` (25 MB) was deliberately NOT committed** — a backup
  .blend, against the standing storage rule. Still on disk.
- **D1 convoys deferred**, and the old brief's premise was wrong: routing exists, but the gate
  is the road hub so there is no map-edge road, and the visible bug is
  `convoy_spawner.gd:86` dropping vehicles 2–6 up to 30 m inside the wire.
- **Other dirty guns:** `m60` markers severed at ruler coords + non-uniform scale on the charge
  handle; `rpd`/`ithaca`/`rpg2` are stale 2026-07-11 exports with only `rifle_idle`.
- **`LIVE_CAP` is 50 in code, 18 in ADR-035:253.** The ADR is canon; one of them is wrong.

## STANDING CONSTRAINTS

- **Do not launch the game.** He drives testing.
- ADR-023: replace a system, delete its predecessor in the same change.
- COMMENT DISCIPLINE, POINTER LAW, FOSSIL LAW. The project is CALL-BOUND.
- Open the session with his decision queue, not with building.
