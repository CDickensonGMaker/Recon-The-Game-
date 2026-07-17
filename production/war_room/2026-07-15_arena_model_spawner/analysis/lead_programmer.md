# Lead Programmer — Arena Model Spawner (2026-07-15)

Query: make the AI Stress Arena spawn US grunts via the "random grunt spawner"
(`SquadSystem.pick_body_for_mos`) + us_grunt_v3, retiring the hardcoded
`ARENA_MOS_BODY` dict added by RECONgame-0623.3.

I read the code, not the plan. Findings below.

---

## 1. What the code actually does today

### The spawn path
`ai_stress_arena.gd:652-669 _spawn_us_squad()`:

```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = _rng.seed + _us_squads.size() * 97   # 654-655
for i in range(men_per_squad):
    var mos: String = US_SQUAD_MOS[i % US_SQUAD_MOS.size()]
    ...
    var body: String = str(ARENA_MOS_BODY.get(mos, "us_grunt_rifleman"))  # 663
    ally.set_sprite(body, SquadSystem.weapon_for_mos(mos), "US")          # 664
```

`ARENA_MOS_BODY` (lines 35-42) is a deterministic MOS→role-body map:
POINTMAN→pointman, RTO→rto, MEDIC/RIFLEMAN→rifleman, GRENADIER→grenadier, MG→mg.
Never touches us_grunt_v3. That was the entire point of 0623.3.

### TWO EXISTING FOSSILS found in this function (report to Arbiter)
1. **Line 654-655 local `rng` is DEAD.** It is created and seeded, then never drawn
   from — `ARENA_MOS_BODY.get()` is deterministic, so nothing in the loop consumes
   `rng`. It was plainly created *for body selection* and orphaned when 0623.3
   hardcoded the dict. My recommended change revives it for its original purpose.
2. **Line 124 `RandomNumberGenerator.new().seed = 20260714` is a NO-OP.** It builds a
   throwaway RNG, seeds it, and discards it on the same line. The comment
   `# global seed for reproducible arena runs` is FALSE — it seeds nothing global
   (Godot's global stream is set via the `seed()` builtin, not
   `RandomNumberGenerator.new().seed`). This is a fossil AND a comment-discipline
   violation (a comment asserting behavior the code does not have). Recommend delete
   the line outright while we are in this file.

### Determinism (bead RECONgame-atov: "randf poisons the RNG stream")
- Arena master `_rng` is seeded `20260714` at `_ready():122`. It drives ALL
  environment placement and spawn jitter, including reinforcement jitter at 804-805 /
  815 which fire *later* in the run.
- `_rng.seed` is a stored property; reading it always returns `20260714` (drawing
  advances `state`, not `seed`). So the per-squad local rng seed
  `_rng.seed + squad_index*97` is stable and deterministic per squad index.
- **Key point:** drawing body picks from the *local* `rng` never advances `_rng`, so
  environment and reinforcement streams are untouched — full determinism preserved,
  and we never call `randf()`, so the atov trap does not apply. Using `_rng` directly
  for bodies, or `randf()`, would both be wrong: the former shifts every later jitter
  draw, the latter poisons the un-seeded global stream.

## 2. `squad_system.gd:82-97` — the "random spawner" chokepoint

```gdscript
static func weapon_for_mos(mos) -> String            # MOS_WEAPON, default m16a1
static func pick_body_for_mos(mos, rng) -> String:
    if DETERMINISTIC_MOS_BODY.has(mos): return it     # RTO → us_grunt_rto
    pool = WEAPON_BODY_POOLS[weapon_for_mos(mos)]      # else weapon-keyed pool
    return pool[rng.randi_range(...)]                  # random draw
```

Pools:
- `m16a1` → `[us_grunt_v3, us_grunt_pointman, us_grunt_rifleman]`
- `m60` → `[us_grunt_mg]`, `m79` → `[us_grunt_grenadier]`, `m70` → `[us_grunt_marksman]`
- `DETERMINISTIC_MOS_BODY`: RTO → us_grunt_rto

So calling `pick_body_for_mos` in the arena yields: POINTMAN/MEDIC/RIFLEMAN = random
m16 body (v3 in the mix), GRENADIER = grenadier, MG = mg, RTO = rto. us_grunt_v3 IS in
rotation for the three rifle roles. This is the *same code the campaign squad uses*
(`SquadSystem.setup → _pick_unit_for_mos → pick_body_for_mos`), so the arena would then
match campaign look — which is the Summoner's stated intent.

`test_squad_body_pool.gd` locks this contract: specialists return their role body
across 20 rolls; the m16 pool must produce ≥2 distinct bodies across 60 rolls. **Any
edit to the pools breaks this test** (that is Option A's cost, below).

## 3. On the "broken exports" premise — I cannot confirm it from code

The brief states the role exports are broken ("2 of 3 broken", specialists "all broken").
**From the codebase I find the opposite signal and must flag it honestly:**
- Bead **n76b** (2026-07-13, "MOS RENAMED TO THE ART", Summoner: *art is truth*)
  established the six role GLBs (pointman/rto/rifleman/mg/grenadier/marksman) as the
  **current** art and DELETED the old m60/m79/us_rto references.
- Bead **x1bs.1** (open) marks **us_grunt_v3 itself** — plus old m14/m60/m79/v2 carriers
  — as the one shipping duplicate donor gear needing re-export. The role bodies are not
  named there.
- All seven GLBs exist with `.import` files; `model_actor.gd` treats
  pointman/rifleman/mg/grenadier/marksman/rto as **live** (`CARRIES_RADIO`,
  `RADIO_FORBIDDEN` lists). Runtime donor-gear cleanup applies to all of them equally.

So the code shows no "broken role body" marker. If the technical-artist confirms a real
visual regression the Summoner saw, it lives at the GLB/pool level, not in arena logic.
My recommendation is robust either way (see §4).

## 4. `AllyBase.set_sprite` / arg-count note
- `ally_base.gd:211 set_sprite(unit, weapon, faction="US Army and Co")`.
- Arena calls it with 3 args, `faction="US"`; SquadSystem calls it with 2 (default
  faction). The arena has shipped with `"US"` and it flows into
  `SpriteStateMap.clip_for(...)`. **Keep the arena's existing 3-arg call unchanged** —
  only the `body` source changes. No signature work needed.
- `AllyBase.spawn_ally(parent, pos)` is static, returns AllyBase; unchanged.

## 5. Options evaluated

**(A) Purge role bodies from `WEAPON_BODY_POOLS` globally (every MOS → v3-family).**
Sacrifices: hits the **campaign squad** too (scope creep beyond the arena ask), and
**breaks `test_squad_body_pool.gd`** (specialists would no longer return their role
body; m16 pool would shrink). Also premised on the "broken" claim I can't verify.
Rejected — wrong blast radius, and it re-decides campaign art on an arena ticket.

**(B) Arena-local good-body pool that still randomizes.** Keeps campaign untouched, but
**does not use the random spawner the Summoner named** — it re-forks the logic the
arena is supposed to converge onto, i.e. it rebuilds a private ARENA dict. That is the
exact shape of the fossil 0623.3 created. Rejected unless the artist confirms the role
bodies are genuinely broken, in which case B becomes the honest stopgap (map arena
bodies to `us_grunt_v3` only) while x1bs.1 fixes the art.

**(C) Point specialist roles at good bodies inside `pick_body_for_mos`.** Same
campaign blast radius and test breakage as A, plus it hides the change inside a shared
static — worse discoverability. Rejected.

**RECOMMENDED — call the spawner, delete the fossil, touch nothing else.** Route the
arena through `pick_body_for_mos` using the already-present local `rng`, delete
`ARENA_MOS_BODY`. This literally "uses us_grunt_v3 + the random grunt spawner", keeps
the campaign and the pools and the test untouched, revives one dead variable, and
buries the 0623.3 hardcode per FOSSIL LAW. If the role bodies later prove broken, the
fix is ONE edit at the pool chokepoint that repairs arena AND campaign at once — versus
re-hardcoding the arena a second time. Sacrifice named: this surfaces whatever the
role-body pool currently yields in the arena; if the artist confirms brokenness, we
accept a temporary visual regression there until x1bs.1 lands (track as a blocker), and
we do NOT paper over it with a new arena dict.

## 6. Exact edits

`scripts/levels/ai_stress_arena.gd`:
- **Delete lines 33-42** — the `ARENA_MOS_BODY` const and its doc comment (FOSSIL LAW).
- **Line 663**, replace:
  ```gdscript
  var body: String = str(ARENA_MOS_BODY.get(mos, "us_grunt_rifleman"))
  ```
  with:
  ```gdscript
  var body: String = SquadSystem.pick_body_for_mos(mos, rng)
  ```
  (line 664 `ally.set_sprite(body, SquadSystem.weapon_for_mos(mos), "US")` unchanged;
  the local `rng` at 654-655 is now live and used for its intended purpose.)
- **Delete line 124** `RandomNumberGenerator.new().seed = 20260714` — no-op fossil +
  false comment. (`_rng.seed = 20260714` at 122 is the real, sufficient seed.)

No changes to `squad_system.gd`, `ally_base.gd`, or `WEAPON_BODY_POOLS`.

## 7. Tests
- `test_squad_body_pool.gd`: **untouched → stays green** (pools unchanged). This is the
  proof that my blast radius is arena-only.
- `test_ai_stress_arena.gd`: headless probe, no body assertions today — will not break,
  and will now *exercise* `pick_body_for_mos` in the arena load path (free coverage that
  every drawn body GLB loads). Optional hardening: add a light assert that each spawned
  US ally's `sprite_unit` ∈ {us_grunt_v3, pointman, rifleman, mg, grenadier, rto} to lock
  intent. Recommended but not required.
- `test_fossils.tscn`: `ARENA_MOS_BODY` is not in `fossil_baseline.json` (it is live at
  663). Deleting both the const and its only use is clean — the register only shrinks.

## Verdict
Delete `ARENA_MOS_BODY` + the line-124 no-op; call `SquadSystem.pick_body_for_mos(mos,
rng)` through the already-seeded local `rng`. Three-line arena-only change, campaign and
pools untouched, `test_squad_body_pool` stays green, determinism fully preserved (never
touches `_rng`, never calls `randf()`). Flag to the council: the "broken role exports"
premise is not visible in code — if real, fix it once at the pool chokepoint, never with
a second arena hardcode.
