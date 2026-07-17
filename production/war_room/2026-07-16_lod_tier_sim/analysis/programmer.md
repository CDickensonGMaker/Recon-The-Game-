# PROGRAMMER / GODOT — LOD-tier unification (Phase 0)

Evidence read this session: `enemy_base.gd:31-55,113-123,220,482-484,805-833,885,942-1025`;
`civilian.gd:40-55,110-149,320-370`; `world_sim.gd` (whole); `test_fossils.gd` (whole);
`fossil_baseline.json:28`. Repo-wide grep on every symbol below.

---

## 1. PHASE 0 — ONE LOD AUTHORITY

### Naming
`_set_tier(tier: AlertTier, witnessed)` at `enemy_base.gd:816` is the **ALERT** setter
(RELAXED/SUSPICIOUS/ALERT/COMBAT), called by the arena as `e._set_tier(AlertTier.COMBAT,false)`.
The ADR's proposed `set_tier(t)` **collides**. Do not use it.

**LOD setter name: `set_sim_tier(tier: int) -> void`** — public (a *different* object, the
scheduler, calls it, exactly as `set_lod_live` was public), and named for its authority
(`WorldSim` = the simulation). It reads clearly against `_set_tier` (private, alert). Reject
`set_lod_tier` — "lod" is the vocabulary we are retiring.

### Shared vocabulary — define the tiers in WorldSim, not the entity
```gdscript
# world_sim.gd — the scheduler owns the tier vocabulary.
enum { SIM_LIVE, SIM_NEAR, SIM_FAR, SIM_ABSTRACT }   # 0,1,2,3
const SIM_THINK: Array[float] = [0.15, 0.3, 0.6, 0.6]  # enemy think interval by tier
```
Putting the enum in the scheduler (and having both setters compare against `WorldSim.SIM_FAR`)
guarantees each tier name is referenced from ≥2 files → it can never itself become a freq-1
fossil. It also makes the scheduler the **single distance authority** the briefing demands.

### Identical signature on BOTH classes
```gdscript
# EnemyBase
func set_sim_tier(tier: int) -> void:
    _think_interval_current = WorldSim.SIM_THINK[tier]
    var live: bool = tier <= WorldSim.SIM_FAR
    set_physics_process(live)
    visible = live

# Civilian  — same signature; body differs (no think interval; actor holds the mesh)
func set_sim_tier(tier: int) -> void:
    var live: bool = tier <= WorldSim.SIM_FAR
    set_physics_process(live)
    if actor != null and is_instance_valid(actor):
        actor.visible = live
```
The scheduler calls `entity.set_sim_tier(t)` on enemies and civilians **uniformly** — it never
needs to know the class. Duck-typed, one call site.

### What it SUBSUMES and lets us DELETE (all in the same change)
| Delete | File:line | Subsumed by |
|---|---|---|
| `_update_think_lod(delta)` + its call | `enemy_base.gd:39-54, 482` | `set_sim_tier` sets `_think_interval_current` from `SIM_THINK[tier]` |
| `_lod_timer` (enemy) | `enemy_base.gd:36` | scheduler owns the recompute cadence + hysteresis |
| `set_lod_live` / `set_lod_abstract` (enemy) | `enemy_base.gd:115-122` | `set_sim_tier(SIM_ABSTRACT)` == old abstract; `SIM_LIVE` == old live |
| `MAX_THINK_TIME` + `last_think_time` | `enemy_base.gd:220, 33` | dead const, never wired — pure fossil, remove now |
| `lod_tier`, `_lod_timer`, `LOD_*` consts | `civilian.gd:45-55` | tier is now a transient arg, not stored state |
| `_update_lod(delta)` + its call | `civilian.gd:329-354, 122` | scheduler is sole distance authority |
| civ FAR early-return | `civilian.gd:123-127` | physics is simply OFF at SIM_ABSTRACT — `_physics_process` won't run |
| `set_lod_live` / `set_lod_abstract` (civ) | `civilian.gd:360-369` | folded into `set_sim_tier` |

**Does anything else read `civilian.lod_tier`?** Grep: `lod_tier` occurs **only inside
`civilian.gd`** (decl :53; reads :123,338,339,342,350; write :351,361). Nothing external. So the
civ's self-driving `_update_lod` can be deleted outright and the scheduler becomes sole authority
with **zero external breakage**. (Note `set_lod_live` at :361 currently reads `lod_tier` — that
read dies with the collapse, which is why both must go together.)

---

## 2. WHERE THE ENEMY THINK-INTERVAL COMES FROM

`_think_interval_current` is read at **8 live sites**: `484` (the think gate), `885`
(`_retarget_timer`), `942/946/947` (visibility timers), `952/954` (`contact_conf` ramp), `1025`
(`_contact_time`). These must keep working.

- **Declaration stays**: `var _think_interval_current: float = THINK_INTERVAL` (`:35`). Keep the
  `THINK_INTERVAL` const and this init.
- **Written by `set_sim_tier`** from `WorldSim.SIM_THINK[tier]`, replacing the deleted
  `_update_think_lod`. All 8 read sites are untouched.
- **CRITICAL — the default init is load-bearing.** `test_arena_perf.gd` spawns **no player** and
  there is no `WorldSim.update_player` driver in the arena, so `set_sim_tier` is **never called**
  there. The field therefore stays at its init `THINK_INTERVAL` (0.15). **This is a behavior
  change: today `_update_think_lod` sees `player == null` and forces 0.6 (`:44-46`); after deletion
  arena enemies think at 0.15 — ~4× the AI think work.** Since the arena IS the perf probe (`27 FPS`
  floor, `perf_probe` is KEEP-GREEN), this can regress it. **MEASURE `perf_probe` before/after.**
  If it dips, the honest fix is to run the scheduler in the arena too (with a synthetic AO centre),
  not to re-hardcode a null-player fallback.

---

## 3. FOSSIL PROBE INTERACTION

**Why the stubs escape today:** the probe (`test_fossils.gd:241`) judges by a **global frequency
count**. `set_lod_live`/`set_lod_abstract` are declared identically on BOTH classes → freq 2 →
`freq > 1` → **never flagged**, despite zero callers. They are UNFINISHED (built ahead), not
grandfathered — they are **not in the baseline**.

**Will the collapse start flagging anything? No.**
- The two `set_lod_live`/`set_lod_abstract` decls are **deleted**, not renamed → they vanish from
  `_seen` entirely. A deleted symbol is neither a new fossil nor a "buried" baseline entry (they
  were never in the baseline). No probe reaction at all.
- New `set_sim_tier` is declared on both classes (freq 2) **and now has callers** in `world_sim.gd`
  → freq ≥ 3. Never flagged.
- `_update_think_lod` (freq 2: decl+call) and civ `_update_lod` (freq 2) are called today, so
  neither is in the baseline; deleting them just drops them from `_seen`. Clean.
- Tier enum/`SIM_THINK` referenced from scheduler + both setters → freq ≥ 2. Safe.

**The one baseline hand-edit — `MAX_THINK_TIME` only.** It is the sole LOD symbol in the baseline
(`fossil_baseline.json:28`, freq 1). Deleting the const from `enemy_base.gd:220` makes that baseline
key disappear from `_seen` → the probe's `cleaned` branch (`test_fossils.gd:78-89`) prints
*"1 FOSSIL BURIED — shrink the register"*. **That is a PASS, not a failure** (`cleaned` never
increments `_failures`; only `new_fossils` does). To satisfy the "register only shrinks" law:
**hand-edit `fossil_baseline.json`** — delete line 28
(`"scripts/enemies/enemy_base.gd|const|MAX_THINK_TIME",`) and decrement `"count": 79 → 78`
(count is display-only but keep it honest). **Never `--write-baseline`.** Order matters: delete the
const AND the baseline line in the same change — if the line is removed while the const survives, it
becomes a NEW fossil and fails the build; if the const is removed while the line stays, it's a
harmless "buried" nag. This is the only baseline touch the whole phase needs. `test_fossils` count
drops — the briefing's proof-of-wiring.

---

## 4. NAMED SACRIFICE (code-clarity lens)

**We are fusing two ladders that never agreed, and the fusion hides a semantic override.**
- Enemy LOD was **think-rate only** (80/150m; FAR still ran physics + fired — an enemy you snipe at
  200m keeps fighting). Civilian LOD was **physics-cull** (80/300m, 5m hysteresis; FAR froze
  physics, stayed visible). One tier table cannot mean both. The 4-tier compromise
  (LIVE/NEAR/FAR physics-on; ABSTRACT physics-off+invisible) **regresses the enemy**: a COMBAT
  enemy pushed to SIM_ABSTRACT (>300m or off-AO) freezes and vanishes — a **Pillar 1 (gunplay)
  hit**. Mitigation the scheduler MUST carry: never demote `alert_tier == COMBAT` below SIM_FAR.
  That couples sim-tier to alert-tier — the exact two-"tier" confusion this rename was meant to
  kill. We trade one collision (`set_tier`) for a subtler coupling.
- **Hysteresis moves out of the entity into the scheduler.** Civ's 5m anti-flap band (`:52`) was
  per-entity state; the scheduler must now remember each entity's last tier and apply hysteresis,
  or units flap tier every tick at a boundary (thrashing `set_physics_process`/`visible`). Dropping
  this is a real, invisible regression — physics/visibility churn is worse than the cost LOD saves.
- **Clarity cost we accept:** two "tier" setters now sit on `EnemyBase` — `_set_tier` (alert,
  private) and `set_sim_tier` (LOD, public). Distinct names + the private/public split keep them
  legible, but a future reader must still hold both in mind. Net: **less code, one authority,** at
  the price of a scheduler that must encode two rules (COMBAT-exempt, hysteresis) the deleted
  per-entity code used to carry for free. No free lunch.
