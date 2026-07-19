# Engine Mining Synthesis — id Tech 3 Family vs RECONgame
**2026-07-18 · Sources: Quake III Arena GPL + ioquake3, RTCW-SP GPL, OpenMoHAA · plus a full survey of RECONgame's live code**

Full reports in this folder: `recon_survey.md`, `quake3.md`, `rtcw.md`, `mohaa.md` (every claim below carries file:line citations there).

---

## The diagnosis (measured, not guessed)

RECONgame's frame is **CPU-bound on AI, not GPU-bound on jungle** (`ai/agents` bucket 25–192 ms vs jungle GPU ~12 ms; PERF_LEDGER). The specific floor:

1. Every live enemy runs `_update_perception` (with an LOS raycast) + corpse-discovery **every think, untiered** — the hot-set cap of 12 does not reduce this.
2. `HitzoneBuilder.sync` runs **every physics frame for every live body**.
3. Enemies **never sleep** — once a LazyGroup spawns, its soldiers simulate at full cost forever. The machinery to fix this (`WorldSim` T2/T3 tiers, `set_lod_live/abstract`) is **built but has zero callers**.
4. Five overlapping LOD authorities coexist; nobody can tell which is load-bearing (ADR-025 Phase 0 never done).
5. `enemy_base.gd` is a 2,469-line god class, ~40% duplicated into `ally_base.gd`.

## The convergence (the strongest signal three independent codebases can give)

All three engines, written by different teams across 1999–2002, solve large combat with the **same five moves**. None of them is about rendering — all are about *what you refuse to compute*.

| # | The move | Q3 | RTCW | MoHAA | RECONgame today |
|---|----------|----|------|-------|-----------------|
| 1 | **Perceivability gates simulation** (not distance) | PVS bit test decides what exists per client | Body gate: unseen+still AI = no physics/anim/movement, brain stays on | `RequireThink`: dormant 60s after last player-relevance; event-woken | Built (`WorldSim` tiers) but **unwired** |
| 2 | **Global budgets, not per-agent costs** | Bot stagger formula; snapshot caps | `aicast_maxthink 4` full thinks/frame; **50 sight rays/sec for the whole level** | ≤1 ray/actor round-robin; 4 path checks/frame | None — every agent pays every think |
| 3 | **Perception is a cached timestamp store; behavior reads, never raycasts** | botlib world mirror at bot Hz | `vislist[]` timestamps; reaction/memory/aim-in = timestamp math | dirty-time `CanSeeEnemy(max_staleness)` per state | Perception inline in each agent's think |
| 4 | **Effects are data + fixed steal-oldest pools; zero allocation in combat** | `EV_*` events, 2 ints + vec3, 300ms; pooled client effects | same engine | visible-only client messages; surface-flag penetration | `gun_fx` cap-and-FIFO **instantiates** under fire |
| 5 | **One clock, one loop, one authority** | `G_RunFrame` walks one flat array; `nextthink` or nothing | three tiers from two call sites | one `Think` vtable dispatch | 14 autoloads, 30 `_physics_process` scripts, 2 world-build paths |

Supporting convergences: personality as flat data (RTCW: 21 floats per character; MoHAA: ~150 script tunables), fire discipline doubling as the perf governor (MoHAA duty-cycle + attacker-count cap ≈ our 2:1 rule, independently invented), fights kept local by leashes (MoHAA 13m default), grenades as closed-form math not physics bodies.

---

## The mapped fixes (engine mechanism → our liability)

### WAVE A — the CPU wall (highest payoff, targets the measured 25–192 ms)

**A1. PerceptionServer** *(kills liability #1)*
One autoload owns all sight checks with RTCW's shape: global ray budget (start at RTCW's shipped **50/sec** — it served a whole level), round-robin cursors, per-pair floors (hostile-unseen 40ms → pairs 200ms → friendlies 2s → corpses once), funnel ordering **flags → dist² → FOV dot → only then raycast**. All results written as timestamps into a vislist; `enemy_base` reads cached timestamps and does **zero raycasts of its own**. Free byproducts once timestamps exist: RTCW's reaction time, 5s target memory, and the accuracy-ramp (A4).

**A2. The body gate** *(kills liability #1's hitzone half + is the RTCW form of #2)*
Gate `move_tick` + `HitzoneBuilder.sync` + `AnimationTree` per soldier exactly like RTCW `ai_cast_think.c:1044`: run only if on-screen (VisibleOnScreenNotifier3D), moving, trying to move, in combat, or a 300ms heartbeat fires. Unseen idle soldier = one timestamp compare. Brain (think, hearing, vislist sharing) stays on — that's why it's safe: RTCW shipped stealth + flanking with this gate on.

**A3. Global think budget + stagger** *(liability #10, and the missing layer over our 6-7Hz think)*
RTCW: max **4 full thinks per frame level-wide**, round-robin resume so nobody starves, `+rand()%20ms` jitter so brains de-phase. Q3's spawn-time formula `offset = interval * i / count`. A LazyGroup spawning 7 men no longer aligns 7 think spikes.

**A4. Accuracy ramps with continuous visibility; breaking LOS resets it** *(free once A1 exists — and it's a FUN lever, pillar 1)*
RTCW `AICast_GetAccuracy`: aim-in over 0.5–4s of continuous sight. MoHAA's visibility-integral does the same for *detection*. Surviving heavy fire by breaking LOS becomes real gameplay; pairs with our suppression.

### WAVE B — sleep and waking (the AI-count scaler for a 1km AO)

**B1. One relevance authority — wire it or bury it** *(liabilities #2 + #6, ADR-025 Phase 0)*
Decision for the council: either finally wire `WorldSim`'s T2/T3 tiers or delete them and build a single `AIDirector` tick-list (MoHAA shape: dormant = **not in the tick list at all**, not early-returning). Fossil law forbids keeping both. All five current LOD notions (`_update_think_lod`, civilian `lod_tier`, hot-set, `set_lod_*` stubs, WorldSim) collapse into ONE authority with tiers: HOT (full) / LIVE (gated body) / DORMANT (event-wake only) / AGGREGATE (distant fireteam = one dot advanced at 1Hz on its patrol route — how we exceed id-era combat sizes on PS2 discipline).

**B2. Event-bus wakeup — extend NoiseBus into MoHAA's AIEventBus**
Radius table (shot 52m, explosion 104m, footstep 13m), priority ladder (grenade > shot > explosion > … > footstep) so a footstep never overrides investigating gunfire, awareness dice-roll so a treeline doesn't pivot in lockstep. This IS how dormant soldiers wake. Emitters: FXBus events, not bullet objects (Q3 bots don't perceive missiles — only results).

### WAVE C — effects and allocation (flat frame time under fire)

**C1. FXBus + steal-oldest pools** *(liability #9)*
Q3's contract: combat code emits `(event, pos, parm)`; one consumer file dispatches into preallocated pools (tracer MultiMesh, impact particles, decal ring ~256, audio players ~32) that **steal the oldest slot and never fail**. Perceivability-gate before any work (an unseen far muzzle flash costs zero). `instantiate()` count during a firefight: **zero** — probe-able.

**C2. Preload registry + pipeline pre-warm**
Q3 precaches everything at load and refers to assets as ints. Godot corollary: warm each effect/shader once at load — first-use pipeline compile is our hitch.

**C3. Closed-form grenades/mortars**
`trajectory_t` thinking: parabola computed at throw, evaluated per tick, one segment ray. No RigidBody3D per grenade. RTCW's dummy-sim aiming (iterative pitch correction across thinks) gives careful-looking throws; MoHAA's global one-grenade-token (7s) is both a perf cap and a drama pacer.

### WAVE D — structure (the simplification half of the mandate)

**D1. Finish ADR-028 for real: one frame authority**
Q3's `G_RunFrame` is the model: one autoload walks one flat registry with `next_think_ms`; individual nodes lose their own `_process`. The arena becomes a thin wrapper (Phase 3) — same world path, different config. This is the structural cure, not another parallel system.

**D2. Split the god class along the engines' seams**
The seams all three engines agree on: perception (→ PerceptionServer), personality (→ data: RTCW's 21-float table shape; we already have `EnemyData` — extend, VC militia vs NVA regular vs sapper become rows), state machine (→ RTCW's one-function-per-state with `state_log` ring buffer — more debuggable than any framework), squad comms (→ vislist sharing within 15m; no manager object). Ally/enemy shared body code merges (Q3: bots and players run the same Pmove).

**D3. Fossil burials this research settles**
`CombatManager.apply_bullet_damage` (routed around) — delete. `SimClock.advance()` (zero callers) — wire or delete, council picks. `world_config` FPS ladder — either build ioq3-style attention throttling (unfocused window → lower budgets) or delete the dead dial. Dual entity registries (groups + `active_*`) — one survives.

### Also validated (keep, don't re-litigate)
- 66ms timestep cap, 6-7Hz think/execute split, goal-driven AI, multi-point explosion visibility — correct Q3 borrowings, confirmed against source.
- BulletSystem's no-node-per-bullet segment raycast — already the id pattern.
- ProjectilePool — already correct; extend the pattern to FX (C1).
- 2:1 fire discipline + hot-set — independently matches MoHAA's duty-cycle + attacker-cap; extend with threat-score target spreading (attacker count discount, cap 4).
- Fog as sight cap (MoHAA: AI vision = fog distance) — PS2 fog literally becomes the perception budget; foliage stays OUT of sight-ray masks (concealment = notice-time multiplier, not per-leaf occlusion) — fits the impostor-card decree.

---

## Recommended order (for the War Room to bead)

1. **A1+A2+A3** — one wave, directly attacks the measured wall; probes: raycasts/frame counter, thinks/frame counter, night-arena bench before/after.
2. **B1** — the tier authority decision (wire WorldSim vs AIDirector) is pillar-touching → council decree required; then B2.
3. **C1–C3** — mechanical, low-risk, big worst-case-frame win.
4. **D1–D3** — the simplification payoff; D2 rides along whenever A1 lands (perception extraction IS the first god-class cut).

**What is sacrificed (law 2):** staler decisions under load (budgeted thinks), effects degrade under saturation (steal-oldest), dormant AI can't react to things no system broadcast (event coverage must be honest), and two build-waves of refactor risk on live AI — mitigated by the probes above and the arena bench as the fixed benchmark.
