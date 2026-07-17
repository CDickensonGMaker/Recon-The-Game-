# Devil's Advocate — Arena US Model Spawner Reversal (2026-07-15)

**Query:** Reverse the 2026-07-15 decree (synthesis #8) that forbade `us_grunt_v3` for role
MOS in the arena. Summoner says: role exports are BROKEN, v3 is good, use the random
spawner `SquadSystem.pick_body_for_mos`.

Read: code + beads only. No plan doc.

---

## 1. Why did the Council originally reject v3? Is there a real v3 bug we'd reintroduce?

**There is no v3-specific bug in the record.** Bead 0623.3's note and synthesis #8 give two
motives, neither a defect:
- **Determinism** — `WEAPON_BODY_POOLS` selection is a random pool draw; the decree wanted a
  fixed MOS→body map so the same seed shows the same men.
- **Per-role silhouette identity** — pointman/rto/rifleman/grenadier/mg as distinct bodies so a
  human watching can read the fireteam.

Reversing does NOT reintroduce a v3 bug. It trades away (a) silhouette variety and (b), IF routed
through a shared RNG, determinism. That's it.

**And the Summoner is factually right that v3 is the LESS-broken body.** Measured in the art-debt
beads:
- `us_grunt_v3` is an **OLD** model (a662): it HAS `head_frag_*` meshes → **head gibs work**. It
  does NOT carry the `Base_Human` second body (eq6n scopes that to "all six NEW GLBs" only).
  Its one defect is double gear (x1bs), and x1bs.1 states `model_actor.gd` **already hides that at
  runtime**. So v3 renders essentially clean in-engine.
- The role bodies the decree mandated — pointman/rifleman/mg/grenadier/rto — are the **six new
  GLBs**: each ships a `Base_Human` 402-tri ghost body (eq6n, still OPEN), **ZERO head gibs**
  (a662, P0), plus the same double gear.

**So the current decree'd arena spawns the MOST-broken bodies available** — ghost second bodies and
dead head gibs on every US soldier the Summoner is about to watch. His reversal is directionally
correct.

## 2. Does the debug-vis / telemetry depend on distinct role models? NO.

Read `_update_debug_vis()` (ai_stress_arena.gd 1098-1150) and `_dbg_label_for` (1081-1095). The
labels render `current_state` / `current_goal` / `order_mode` / `suppression_level` / `has_cover`
and modulate by `alert_tier`. **Nothing reads the body model.** The label doesn't even print MOS.
LOS lines read `has_line_of_sight`, not silhouette. MG is distinguished by `fire_rate_mult = 1.6`
(line 667), not by its mesh.

**Conclusion:** going all-v3 breaks NO telemetry and NO debug label. The only loss is a human's
eyeball read of "which one's the MG" — and since v3-vs-broken-role is currently *broken silhouette*
vs *clean uniform*, that read is already poisoned. The silhouette sacrifice is real but minor.

## 3. THE CORE INCOHERENCE — "use V3 AND the random spawner" cannot both be true.

`pick_body_for_mos` (squad_system.gd 86-93) does the OPPOSITE of "spawn v3":
- `DETERMINISTIC_MOS_BODY` is checked FIRST → **RTO always returns `us_grunt_rto`** (the broken new
  body), no v3 possible, ever.
- `m60 → [us_grunt_mg]`, `m79 → [us_grunt_grenadier]`, `m70 → [us_grunt_marksman]` — these pools
  contain **ONLY the broken role body and no v3**. For MG/grenadier/marksman the "random" spawner
  returns the broken model 100% of the time.
- Only `m16a1 → [us_grunt_v3, us_grunt_pointman, us_grunt_rifleman]` even contains v3, and there
  it's a 1-in-3 random mix WITH the two broken bodies.

**Routing the arena through `pick_body_for_mos` as-is makes the arena WORSE, not better** — it
guarantees broken MG, grenadier, marksman and RTO, and randomly-broken riflemen. The Summoner's
stated MECHANISM defeats his stated GOAL. His goal ("show the good v3, not the broken role exports")
is sound; "use the random spawner" is the wrong lever.

To actually force v3 through the random spawner you must gut `WEAPON_BODY_POOLS` to `["us_grunt_v3"]`
for every weapon AND gut `DETERMINISTIC_MOS_BODY`. That is a **SquadSystem edit**, which:
- **Violates decree decision #7** ("arena tuning must not leak into `SquadSystem`").
- **Changes the shipped campaign** — `SquadSystem.setup` → `_pick_unit_for_mos` → `pick_body_for_mos`
  dresses every campaign fireteam. Every campaign squad becomes uniform v3 until x1bs.1 re-export.

**The sacrifice named:** to fix a probe scene you would degrade the shipped game's squad variety and
punch a hole in the arena/campaign firewall the same Council erected six decisions earlier. (Caveat:
campaign currently spawns the SAME broken role bodies, so all-v3 is arguably a *net visual upgrade*
for the campaign too — but it's a scope decision that belongs to the campaign, not smuggled in as an
arena band-aid.)

## 4. Determinism landmine.

- `pick_body_for_mos(rng)` takes an explicit RNG; the arena already builds a fresh **seeded local**
  `rng` in `_spawn_us_squad` (654-655) and campaign uses a dedicated `_roster_rng` (seed
  director+67890). Neither touches the global stream. So body selection is NOT the `randf()`
  poison of RECONgame-atov, and does NOT threaten the 5i8a GATE (province rebuild) — the arena isn't
  the province and the RNGs are dedicated. Low risk on this axis.
- **BUT there IS a live determinism fossil right here:** ai_stress_arena.gd **line 124**:
  `RandomNumberGenerator.new().seed = 20260714  # global seed for reproducible arena runs`. This
  constructs an anonymous RNG, seeds it, and **throws it away** — no reference kept. It is a NO-OP
  that reads as load-bearing ("global seed for reproducible runs"). That is exactly the atov-class
  lie the project hunts. **Not captured in any bead.** Flag it regardless of this reversal.

## 5. Fossil Law & bead hygiene.

- **Do NOT half-reverse.** If the fix switches away from `ARENA_MOS_BODY`, the const must be
  **fully deleted** in the same change. Leaving `ARENA_MOS_BODY` in place but unused creates a NEW
  fossil → `tests/test_fossils.tscn` fails the build (register only shrinks). Deleting a genuinely-
  dead const is the *correct* move and is safe. The trap is the middle state.
- **Don't silently reopen-and-rewrite 0623.3.** Its close note ("deterministic ARENA_MOS_BODY map
  wired") is TRUE for what it did. Rewriting it to say the opposite makes the graph lie. Clean
  hygiene: **file a NEW bead** — "Arena spawns least-broken body until x1bs.1 re-export; supersedes
  ARENA_MOS_BODY role map" — mark 0623.3 **superseded**, and **link the new bead to x1bs.1** (the
  real fix) so the reversal and its reason are visible.

## 6. Bead-coverage gaps.

- **Line-124 no-op** (dead RNG seed) — NOT beaded. New bead.
- **The campaign is shipping the SAME broken role bodies** (eq6n/a662 ghost body + dead gibs via
  `pick_body_for_mos` in `SquadSystem.setup`), and **no bead flags the interim exposure**. x1bs/
  x1bs.1 track the *art re-export*; nothing tracks "until re-export, the shipped campaign renders
  broken men — decide the interim body." If the arena warrants a band-aid, the campaign has the
  identical disease unmanaged. Gap.
- Open arena beads the Summoner wants saved are intact: **0623.1** (NAV warning) and **0623.2**
  (verify 3-5min run) are OPEN and captured — good.

---

## VERDICT

**Genuinely sacrificed:** per-MOS silhouette variety in the arena (minor — no code reads the model,
the debug label never showed MOS, MG is fire-rate-flagged not mesh-flagged). If done via pool-purge:
ALSO campaign squad variety and the arena/campaign firewall (decision #7).

**Single biggest risk:** the Summoner's stated MECHANISM is self-defeating. `pick_body_for_mos`'s
`m60`/`m79`/`m70` pools and `DETERMINISTIC_MOS_BODY` contain ONLY the broken role bodies with **no
v3 to draw** — routing through the random spawner guarantees broken MG, grenadier, marksman, and
RTO. Implemented literally it makes the arena worse. Runner-up: a half-reversal that leaves
`ARENA_MOS_BODY` unused = a fresh fossil = red build.

**Greenlight — but reshape it.** The GOAL (stop showing the broken role exports; show the clean-at-
runtime v3) is legitimate and worth doing now for the 0623.2 playtest. But:
1. **Overrule the mechanism.** Do NOT route through `pick_body_for_mos`. Make it arena-local:
   repoint the arena to spawn `us_grunt_v3` for the broken roles. **Fully delete `ARENA_MOS_BODY`**
   if it goes unused (no half-reversal), or trivially it becomes an all-v3 constant — but a const
   that maps six keys to one value is a smell; prefer a plain `us_grunt_v3` literal in
   `_spawn_us_squad`.
2. **Do NOT touch `SquadSystem` / `WEAPON_BODY_POOLS` / `DETERMINISTIC_MOS_BODY`.** Respect decision
   #7. The campaign body question is a separate, deliberate decision, not an arena side-effect.
3. **Measure before committing** (project law, never-guess-in-Blender/verify-in-engine): confirm
   `us_grunt_v3` renders clean at runtime after `model_actor.gd` cleanup and that `Base_Human` is
   absent — don't assume the beads are still current.
4. **Fix or bead line-124** (dead RNG-seed no-op).
5. **Bead hygiene:** new superseding bead linked to x1bs.1; mark 0623.3 superseded, don't rewrite it.

The band-aid earns its keep for THIS session's playtest. The true fix stays gated on **x1bs.1**
(Blender re-export to worn-only gear). Keep the arena patch minimal and arena-local so it's a clean
one-line delete the day x1bs.1 lands — a band-aid that peels off, not another fossil to hunt.
