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

## VERIFY THESE FIRST (one boot, then read the console)

| Print | What it answers |
|---|---|
| `[Siege] reinforced +34 - the assault is now 45 men (peak 45)` | the 720 s beat finally fires |
| `[Siege] perimeter measured from N parapet segment(s) over 36 bearings` | the overrun can judge "inside" at all |
| `[Siege] press wave N: X of Y men crossing` | the assault is pressing, not sitting |
| `[Siege] OVERRUN - N attacker(s) inside the wire` | the gate lane works |
| `[AmbientWar] ... held silent - 2 firefights already sounding` | the cap is reporting itself |
| a lit circle 140 m out, going dark ~15 s between rounds | the garrison is lighting its own wire |
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
