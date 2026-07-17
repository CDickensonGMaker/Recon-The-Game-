# AI STRESS ARENA — Handoff Guide for the Next AI

**Goal:** get the AI Stress Test arena into the shape the Summoner wants — 3–5 minute firefights
that feel like thinking soldiers, not bullet sponges. This guide is written to be executed by a
LESS capable model, so it is mechanical on purpose. Follow it literally. When unsure, STOP and ask
the Summoner rather than guessing.

Files that are canon (read before touching anything):
- `production/war_room/2026-07-15_arena_handoff_review/synthesis.md` (the decree)
- `production/war_room/2026-07-15_arena_handoff_review/UPDATE_FROM_SUMMONER.md` (what he actually wants)
- `scripts/levels/ai_stress_arena.gd` (the arena)
- Run `~/bin/bd.exe prime` then `~/bin/bd.exe ready` — TASK TRUTH LIVES IN BEADS, not markdown.

---

## THE 10 KEY THINGS

### 1. The validation loop is sacred — and the Godot path is a TRAP.
The real binary is NESTED inside a folder that is itself named `...exe`:
```
GODOT="/c/Users/caleb/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path . res://tests/test_ai_stress_arena.tscn
```
Exit code `0` = PASS. Anything else = FAIL. Also grep the output for `SCRIPT ERROR` — if you see it,
the fix is broken no matter what else prints. **NEVER say a change works until this returns exit 0
with no SCRIPT ERROR.** A model that claims success without running this is lying to the Summoner.

### 2. The grunt MODEL problem is already SOLVED — do not undo it.
Every arena US grunt spawns as `us_grunt_v3` via `ARENA_US_BODIES` in `ai_stress_arena.gd`. The
Summoner wants V3 ONLY — do NOT add `us_grunt_v2` (he does not want it in the game at all) and do NOT
add the role exports (`us_grunt_pointman/rto/mg/grenadier/rifleman/marksman`) — they each ship a
hidden `Base_Human` SECOND skinned body (bead `eq6n`) and render two overlapping men. Per-role body
variety returns only when those role exports are re-exported clean (bead `x1bs.1`); until then, V3.

### 3. The four things the Summoner is actually tuning for (this IS "working shape"):
1. **Fights last 3–5 minutes** — from tactics/survival, NOT from giant HP pools.
2. **AI accuracy = "Star Wars trooper" dial** — AI misses a lot, especially at range / first contact.
   Volume of fire and exposure kill, never pinpoint aim. Lever: `@export var ai_accuracy_mult`.
3. **Survival-first AI** — both sides break contact, withdraw when outnumbered/suppressed, value
   cover over kills. Levers: `ai_retreat_hp`, plus enemy `d_retreats_when_hurt` / morale.
4. **Terrain proves line-of-sight** — entrenched men facing the wrong way must NOT magically see a
   flanker. Cover/vegetation is a validation tool, not decoration.
All of these are `@export` vars near the top of `ai_stress_arena.gd` (the "TUNING LEVERS" block).

### 4. Tune by MEASUREMENT, not vibes (ADR-015 verification law).
The arena prints a telemetry line every 30 sim-seconds: US/VC alive, kills, rounds fired, retreats,
seconds-suppressed, avg distance to target. Procedure: change ONE lever → run headless → read the
line → compare. If you cannot measure a change, you cannot claim it. "Probably better" closes nothing.

### 5. Keep arena levers INSIDE the arena (decree #7 — scope law).
`ai_accuracy_mult`, `ai_hp_multiplier`, `player_damage_multiplier`, `reserve_rate_multiplier`,
`ai_retreat_hp` live on `AIStressArena` only. **Do NOT** push them into `SquadSystem`, `EnemyBase`,
`AllyBase`, or any campaign file. The campaign has the SAME broken-model bug (eq6n) but fixing that
is a separate Summoner decision — do not smuggle a campaign change into arena work.

### 6. Do not poison the RNG (bead `atov`, a P0).
Never add `randf()` / `randi()` to a per-frame or perception hot path — it desyncs the deterministic
seed. Use the already-seeded local `rng` in `_spawn_us_squad`. Never add a dead
`RandomNumberGenerator.new().seed = ...` line (that pattern was just deleted as a no-op fossil).

### 7. FOSSIL LAW — delete the old system in the SAME change (ADR-023).
When you replace something, delete its predecessor immediately. Dead consts/functions/dicts are not
harmless — they read as live and the next model uses the wrong one. `tests/test_fossils.tscn` FAILS
THE BUILD on a new fossil. Do NOT regenerate `tests/fossil_baseline.json` to silence it — that is the
one forbidden move. Run the full suite before declaring done.

### 8. COMMENT DISCIPLINE — stop narrating (Summoner's law).
Write a comment ONLY to state a constraint the code cannot show (a units rule, an invariant). NEVER
write comments that say what the next line does, what the code used to be, why the change is correct,
or which bead it came from. That history goes in the commit message, not the source. A weak model's
instinct is to over-comment — resist it.

### 9. Bead hygiene — the graph is the memory between sessions.
- `~/bin/bd.exe show <id>` before you touch related work.
- Close with PROOF: `~/bin/bd.exe update <id> --status done` only after the headless probe passes.
- Do NOT rewrite a closed bead's honest note. If you reverse a past decision, file a NEW bead that
  references the old one (that is how `0623.3` was reversed).
- Still OPEN and relevant: `0623.1` (NAV warning — one VC spawns off-navmesh, ~67m, no path),
  `0623.2` (verify the 3–5 min fight — closes on the Summoner's PLAYTEST, not a headless run),
  `eq6n` (the Base_Human double body — root cause of all "broken grunt" reports),
  `x1bs.1` (Blender re-export of role bodies to clean gear — the REAL fix that restores per-role
  variety; until then the arena stays on v3/v2), `a662` (head gibs — likely STALE, role exports now
  have head_frag_01..07; re-verify before acting).

### 10. The final gate is a HUMAN playtest, and you must PUSH.
`0623.2` cannot be closed by a headless probe — the Summoner watches a 3–5 minute run and judges
whether it FEELS like survival/suppression rather than sponginess. Your job is to get it ready and
hand him a build with the telemetry showing the right shape. End every session with:
```
git pull --rebase && git push && git status   # must show "up to date with origin"
```
Work is NOT done until `git push` succeeds. Never stop before pushing.

---

## Quick tuning starting points (change ONE at a time, then measure)
- Fights too SHORT / sponge feel wrong → adjust `ai_hp_multiplier` (currently 1.5), but prefer
  raising survival behavior over HP.
- AI too deadly / zeroes the player → LOWER effective accuracy: raise the miss (the `ai_accuracy_mult`
  currently multiplies enemy accuracy UP at 2.5 for volume-of-fire; if it feels aimbot-y, that dial
  or the underlying spread is the place, not HP).
- Nobody breaks contact → raise `ai_retreat_hp` (currently 0.35) and confirm enemy morale/retreat
  flags are being applied in `_finish_agent_setup()`.
- Fix `0623.1` first if the log spams `[NAV] ... no path` — clamp the spawn/target to the navmesh
  closest point (see `enemy_base.gd` around line 1544 where it was downgraded to a warning).

## EXPORTING THE UPDATED US GRUNTS (the real fix — supersedes the v3 code stopgap)

The Summoner built a corrected US grunt set in Blender (`assets/us/characters/us_base_v3.blend`,
7 rigs: base `PSXRig` + rifleman/grenadier/mg/rto/marksman/pointman). Guns aligned in the
`idle_aiming_fixed` pose and bone-parented to `mixamorig:RightHand`. Backup of every gun's
hand-relative transform: `production/blender/us_grunt_gun_holds_idle_aim.json`.

**Locked decisions (Summoner, this session):**
- Gear ships **baked-in-but-hidden**; the spawner shows/hides by name (existing worn-gear system).
  Radio `prc25_*` ships in-mesh (hidden) for rifleman/pointman/rto; dropped for marksman/mg/grenadier.
- Export **overwrites** `us_grunt_{rifleman,grenadier,mg,rto,marksman,pointman}.glb`; base `PSXRig`
  becomes the standard `us_grunt_v3.glb`.
- `Base_Human` is the **secondary gib body — IT STAYS.** It ships in every GLB (the exporter un-hides
  everything on purpose: "the GAME hides the gib donors at runtime, not us"). The in-game double-body
  (`eq6n`) is therefore a **CODE fix**, not an art deletion — see below.

**Done this session:**
- Poses locked, guns backed up, `us_base_v3.blend` saved.
- `tools/export_us_squad.py` LINEUP repointed from the 2-day-stale `us_v3_soldier_lineup.blend` to the
  truth file `us_base_v3.blend` (this was bead `bgfq` live — the exporter was about to ship old art and
  discard the day's work).

**Blockers still open (finish these in order):**
1. **Canteen name guard.** `export_us_squad.py` aborts because the belt canteens are named
   `canteen_l.002` … `.006` and the exporter rejects any `.` in a mesh name (its guard against Blender
   `.001` collision suffixes, since GibSystem matches by exact name). Godot converts `.`→`_` on import
   anyway (`canteen_l.002` → `canteen_l_002`), and model_actor already references the underscore names.
   **Fix:** in the export rename step, convert `.`→`_` for these legitimate numbered meshes instead of
   aborting — OR confirm with the Summoner whether the 5 canteens are intentional (a belt has several)
   vs accidental duplicates to delete. Do NOT just delete the guard; it prevents silently-broken gibs.
2. **Run the 6-role export headless** (won't touch an open Blender session):
   `"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b -P tools/export_us_squad.py`
   Expect `us_grunt_<role>.glb` overwritten, each printing `head frags: N` and a size. Any ABORT = stop.
3. **Base → standard.** `export_us_squad.py` only does the 6 tagged roles. The base `PSXRig` (untagged
   meshes: `us_grunt_joined`, `Base_Human`, `m16_world`, empty back) still needs an export path to
   `us_grunt_v3.glb`. Adapt the same script (no tag-strip; names already canonical).
4. **`eq6n` CODE fix — hide `Base_Human` on the live body.** `model_actor.gd`'s gib contract
   (`_apply_gib_rig_contract`, ~line 388) classifies `Base_Human` as the live body and never hides it,
   so it double-renders. It must treat `Base_Human` as a hidden gib layer (like `grunt_*`/`cap_*`) on
   the intact body and reveal it only during gibbing. Until this lands, the exported grunts will show
   two overlapping bodies in-game. This closes/absorbs `eq6n`.
5. **Verify** in-game (headless probe exit 0 + a real look): single clean body, gear toggles per role,
   gibbing still fires, then `git push`.

**Bead when done:** supersede the v3-arena stopgap; fold `eq6n` into the model_actor fix; note `bgfq`
partially addressed (exporter now reads truth file); `x1bs.1` satisfied by this export.

## What a weak model should NOT attempt alone
- Rebalancing the shared damage table (ADR-016) — those are canon values of record.
- Any change to `SquadSystem`/`EnemyBase`/`AllyBase` that leaks arena tuning into the campaign.
- The Blender re-export (`x1bs.1`, `eq6n` root fix) — that is hand-authored art work the Summoner does.
- Convening/overruling a War Room decree — escalate to the Summoner or the `recon-overseer` agent.
