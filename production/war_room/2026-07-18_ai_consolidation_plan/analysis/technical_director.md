# TECHNICAL DIRECTOR — AI Consolidation Plan (2026-07-18)
Lens: measured-payoff sequencing · Godot 4.7 mechanism reality · the scoreboard.
Inputs: briefing.md · SYNTHESIS.md · recon_survey.md · quake3.md · godot_4.7_features.md · godot_standards.md · PERF_LEDGER numbers of record.

---

## 0. Godot mechanism reality checks (the facts the ordering rests on)

**VisibleOnScreenNotifier3D.** It is a renderer-side AABB-vs-frustum test driven by the
RenderingServer. Three properties matter here:
1. **Headless: dead.** Under `--headless` the dummy rendering server performs no culling;
   notifiers never fire `screen_entered` and `is_on_screen()` stays false. If A2's body gate
   keyed on it, every headless probe would gate EVERY body — witness/locomotion/hitzone
   probes either break or pass vacuously. Our probe suite is headless by law; this alone
   disqualifies the notifier as the gate authority. (W0 carries a 10-line micro-probe that
   records this fact so it is measured, not asserted — never-guess law.)
2. **Frustum-only, occlusion-blind.** It does not consult occlusion culling (and this
   project configures none beyond frustum + fog — survey §3). A soldier behind a hill,
   inside fog, is "on screen" to the notifier. Safe direction (gates less than possible)
   but leaves the biggest jungle win — the ~90 m fog wall — on the table.
3. **Latency.** Enter/exit signals arrive on render cadence, fine for a 300 ms heartbeat,
   but nondeterministic frame-to-frame — bad for reproducible benches.

**Ruling → A2 gate mechanism: sim-side perceivability check, not the notifier.**
One pure function (lives in PerceptionServer):
`perceivable(pos) = dist ≤ fog_sight_cap AND (dist ≤ near_bubble ~20m OR camera_fwd·dir ≥ cos(half_fov+margin))`
plus the RTCW conditions (moving / trying to move / in combat / 300 ms heartbeat).
This is exactly what the engines did (Q3 PVS is a data check, RTCW's body gate is a
seen-by-any-client check — neither asks the renderer). It is headless-valid, deterministic,
probe-drivable (probes place the camera), *more* aggressive than frustum because the fog
cap applies, and it becomes the single perceivability oracle reused by C1's FXBus gate and
B's aggregation — one authority, fossil-law clean. The notifier is not used at all.

**Autoload ordering.** Autoloads sit under root before the main scene in declaration order;
`_physics_process` runs in tree order, so autoloads tick before all scene agents. Therefore
PerceptionServer (and later GameFrame) advance budgets/cursors at frame start before any
agent reads timestamps — no ordering hack needed. W0 probe asserts this order once rather
than trusting it. Corollary risk: we are ADDING autoloads (PerceptionServer, FXBus,
GameFrame) to a project whose diagnosis includes "14 autoloads" — the scoreboard tracks an
autoload census and the plan nets DOWN by D's end (each new autoload must bury at least one
old system: WorldSim/SimClock/NoiseBus-absorbed).

**Signal costs.** Per-emit Variant marshalling + per-connection dispatch. Fine for events
(deaths, decree moments); wrong for per-frame or per-shot fan-out to 60 connected agents.
Design consequence: the vislist is a **polled timestamp store** (agents read in `_think`,
zero signals); B2's wake bus is **spatial-bucket direct dispatch** (query grid cells in
radius, call `wake()` on those agents only), not a broadcast signal every dormant agent
filters. Matches godot_standards.md signal protocol ("not frame-by-frame").

**PhysicsServer ray costs.** `intersect_ray` per-cast native cost is small; the O(N) cost
today is GDScript call overhead + query-object churn per agent per think. Centralizing in
PerceptionServer with one reused `PhysicsRayQueryParameters3D` and a hard budget converts a
scaling cost into a fixed one. Context: BulletSystem already legally spends up to 128
rays/frame — perception rays (~240–420/s at 36–60 live units) are only PART of the 25–192 ms
`ai/agents` wall. The scoreboard MUST bucket rays, think-body time, and hitzone sync
separately so we learn which cut actually paid (see §2).

**Godot 4.7 side notes.** Shader Baker (4.5) belongs in the release preset regardless of
C2 — C2's runtime pre-warm kills dev-run first-contact hitches, the baker kills them in
export. The 4.7 typed-return-override rule will bite the D2 function-per-state split
(every state func must return explicitly) — noted for the programmer, costs nothing now.

---

## 1. Wave ordering — stress-test and final order

### A1 vs B1: do they entangle?
Shallowly, yes; blockingly, no. A1's budget classes are **relationship-based**
(hostile-unseen 40 ms → seen pairs 200 ms → friendlies 2 s → corpses once) — none of that
needs a sim-tier. What A1 DOES need is a roster: who is in the perception rotation, with a
priority class per agent. If A1 grows its own roster, B1 later builds the tier authority on
a *different* one and we have manufactured registry #3 (liability #10 is already "dual
registries"). **Resolution: Wave 0 lands THE AgentRegistry** — one flat roster (enemies,
allies, civilians), subsuming `CombatManager.active_*` (burial in the same wave), with a
`tier` field that defaults LIVE. A1 consumes the roster; B1 later becomes the sole *writer*
of the tier field. A1 ships with zero tier logic. Entanglement dissolved at the cost of one
small enabler task. Verdict: **A1 buildable before B1.**

### Can C1 land early and independently?
Yes — FXBus touches no AI decision path, and its perceivability gate is the same pure
function A2 introduces (not the vislist, not tiers). Two reasons it must land BEFORE B:
(1) B2's wake events are emitted BY FXBus ("emitters: FXBus events, not bullet objects" —
synthesis); building B2 first means inventing emitters twice. (2) C1 kills the
instantiate-churn spikes that contaminate every before/after bench we take afterward.
C2 (pre-warm) moves even earlier, into Wave 0, because first-use pipeline compiles are
measurement noise TODAY and the fix is trivial.

### Why B moves behind C
B1 is the only wave that (a) requires a council/pillar decree (WorldSim vs AIDirector —
ADR-025/ADR-005 touching), (b) changes what the AI does when the player is absent
(dormancy vs the witness rule), and (c) merges five LOD notions plus LazyGroup. It is the
highest-regression wave (§3) and its payoff shows on the PATROL bench (long-session cost
accumulation — enemies never despawn), not the night arena. It also gets cheaper after A:
once corpse-discovery is a PerceptionServer class (A1), gating it per-tier is one code
path, not a scattered edit. Sequencing it after two mechanically-derisked waves is the
correct risk ordering AND the correct earliest-FPS ordering — A owns the measured 25–192 ms
wall; B owns a slower bleed.

### FINAL ORDER

| Wave | Content | Primary exit (counters are the GATE; fps is confirmation) | Bench number (shipped config 0.75/mode5 unless noted) |
|------|---------|-----------------------------------------------------------|--------------------------------------------------------|
| **W0** | Scoreboard counters · AgentRegistry (buries `active_*` dual registry) · C2 pre-warm (+ Shader Baker in release preset) · preservation-probe audit (write missing witness/2:1/fairness probes FIRST) · notifier + autoload-order micro-probes | Baseline table complete (6 metrics × night arena + patrol); registry probe green; no first-contact pipeline spike >25 ms in spike catcher | No fps gate — enabler wave. Baseline rows recorded: night arena 22.3 shipped / 18.8 native; patrol spawn 28.8 native |
| **WA** (A1+A2+A3+A4) | PerceptionServer (vislist, 50/s budget, funnel flags→dist²→FOV→ray, staged burial of in-agent perception) · sim-side body gate (move_tick + HitzoneBuilder.sync + AnimationTree) · stagger `offset=interval*i/count` + ≤4 full thinks/frame · fairness exposure-ramp MIGRATED onto timestamps (A4 is a migration, not a new feature — one ramp authority) | Perception rays ≤60/s level-wide, starvation counter 0 sustained; full thinks ≤4/frame; hitzone syncs/frame ≤ perceivable count; witness + fairness + 2:1 probes green | **`ai/agents` median ≤10 ms in night-arena firefight (from 25–192); night arena ≥28 fps avg shipped (from 22.3); worst frame ≤45 ms.** (Honesty note: native night arena is GPU-bound at 51.9 ms — 30 fps native is NOT promised by any CPU wave) |
| **WC** (C1+C3) | FXBus `(event,pos,parm)` + steal-oldest pools (impacts/decals/audio; tracers already pooled) + gun_fx burial same wave · closed-form grenades + one-grenade token (FUN lever — game-designer sign-off on the token) | **Combat `instantiate()` count = 0** (headless probe assert); >25 ms spike count during sustained fire −50% vs WA row | Night-arena worst frame ≤40 ms shipped; avg no regression (±1 fps) |
| **WB** (B1+B2) | Council decree: tier authority (my recommendation §3: AIDirector tick-list on the W0 registry; bury WorldSim tiers — dormant = NOT TICKED, MoHAA shape, true zero cost per ioq3 "gate systems off, don't early-return") · collapse all 5 LOD notions + LazyGroup becomes a tier assignment · NoiseBus→AIEventBus (radius table, priority ladder, dice-roll, FXBus emitters) · AGGREGATE fireteam-as-dot optional last | Tier census live in overlay; full-sim agents ≤16 + perceivable; ADR-005 dormant-corpse probe green (silent kill near dormant group → discovered on wake-in-range); patrol fps decay after 2-location walk ≤10% of spawn row | **Patrol long-walk bench: `ai/agents` ≤8 ms sustained after visiting 2 locations; ≥30 fps native at spawn pose held post-visits (from 28.8 fresh). Night arena: no regression** |
| **WD** (D1–D3 + arena wrapper) | GameFrame single authority (tick-order census FIRST, replicate order exactly, reorder later) · god-class split remainder (function-per-state + state_log, personality→EnemyData rows, squad comms via vislist sharing, ally/enemy body merge) · burials: apply_bullet_damage, SimClock decision, world_config ladder decision · ADR-028 Phase 3 arena thin wrapper + structural probe | `_physics_process` scripts 30 → ≤12; enemy_base 2469 → ≤1000 lines; autoload census ≤14 net with named burials done; fossil baseline strictly smaller; arena-wrapper probe green | **No-regression wave: both benches within 1 fps of WB rows.** Structure is the payoff, fps is the constraint |

WA.3 (stagger) could technically land in W0 but changes think timing = behavior-adjacent;
it stays in WA where the probes are watching.

---

## 2. Scoreboard design

**The contamination lesson rules the design.** The survey proved identical arena rows swing
±10% fps ("the arena is a live firefight that escalates while you measure it"). Therefore:
**deterministic counters are the primary per-wave exit gates; fps numbers are confirmation,
taken as median-of-3 on fixed seeds/poses.** A wave that hits its counters but misses fps
by <1 fps is a judgment call for the Arbiter; a wave that misses counters is not done.

| # | Metric | Where it lives | Headless-valid? |
|---|--------|----------------|-----------------|
| 1 | `ai/agents` ms bucket (median + p99) | Exists in `arena_perf_overlay` per-system buckets; W0 attaches the same bucket harness to patrol world; ps2_perf_probe SUMMARY gains the field | Yes for relative regression (no render contention → numbers differ; windowed for numbers of record) |
| 2 | Perception raycasts/frame + /sec, and **starvation counter** (pairs overdue past their class floor) | Pre-A1: counter shim at `CombatManager.has_line_of_sight` + `_update_line_of_sight` + cover-search call sites (W0). Post-A1: **PerceptionServer self-reports** — it owns every sight ray, the counter is free | **Yes** |
| 3 | Thinks/frame, split full vs cheap | Increment at `_think` entry; reported via overlay + probe SUMMARY | **Yes** |
| 4 | Instantiate-count-in-firefight | gun_fx call-site counter + `Performance` object/node-count delta across the probe's scripted fire window; post-C1 the headless probe ASSERTS 0 | **Yes** (instancing happens headless even though nothing renders) |
| 5 | Hitzone syncs/frame + gated-body count + tier census | Body gate / AgentRegistry self-report (W A/B) | **Yes** |
| 6 | Night-arena fps avg/median + worst-frame ms + spike count (>25 ms) | `night_jungle_bench.bat` + ps2_perf_probe SUMMARY (add p99 frame-ms field, W0); overlay spike catcher live | **No — windowed.** FLAG: Summoner-run or explicitly announced batch; never spam windowed Godot (standing law). One batched windowed session per wave close |
| 7 | Patrol long-walk bench (seed 47225, scripted 2-location visit, then hold spawn pose) | New probe script riding ps2_perf_probe harness (W0 defines it, WB gates on it) | Counters yes; fps windowed |

Protocol per wave: headless counter run in the test suite (every commit) + ONE windowed
bench batch at wave close → row appended to `PERF_LEDGER.md` with commit hash. Before/after
rows always same seed, same pose, same shipped config.

---

## 3. Risk register — refactor on live AI

Surface: 2469-line god class, 30 `_physics_process` scripts, 14 autoloads, and every
shipped behavior on the briefing's preserve list reads the systems being rewired.

| Risk | Wave | Guardrail |
|------|------|-----------|
| **Perception rewiring silently changes witness/2:1/fairness behavior** (every decision reads the vislist after A1) — the widest surface | WA | Probe-first law: W0 writes/verifies the preservation probes BEFORE the cut; per-agent `state_log` ring buffer (RTCW pattern, ~32 entries: state, cause, timestamp) lands WITH A1 so any regression is postmortem-readable; counters as deterministic gates |
| **Dormancy vs ADR-005** (a dormant soldier cannot witness) — the deepest pillar touch | WB | Semantics hold because sight caps are 45–140 m and DORMANT requires range >> sight cap — a dormant soldier could never have seen the corpse anyway. Probe: silent kill near dormant group → no escalation; group wakes in range → discovery escalates. This probe is written in W0, green before AND after WB |
| **Replacing keep-old-path-behind-flag (FORBIDDEN by fossil law)** | all | **Staged burial, one wave, one commit train:** land replacement → full probe suite green → delete predecessor → suite green again → bench. A/B comparison is done **by commit, not by runtime flag** — bench the pre-wave commit vs post-wave commit; git revert of the wave's commit train is the rollback. The probe suite + fixed benches ARE the safety net |
| Ray-budget starvation → detection-latency regression (50/s may be thin for 60 agents' pair floors) | WA | Starvation counter in scoreboard (exit gate = 0 sustained); budget is a tunable, raised BEFORE wave close if starving — RTCW's 50/s served ~20 AI, we may land at 80–100/s; fairness probes catch felt latency |
| A2 pose-pop on wake (gated AnimationTree resumes stale) | WA | 300 ms heartbeat caps drift; 1-frame pre-roll on perceivable-enter; arena eyes-test (rule #1 — Caleb's eyes judge, not counters) |
| **Two dormancy authorities** (LazyGroup activation vs tier DORMANT) — a new fossil pair | WB | LazyGroup is MERGED into the tier authority in the same wave (activation = tier promotion), named burial in WB's exit list |
| GameFrame migration breaks implicit tick-order dependencies (30 scripts tick in tree order today) | WD | WD.1a is a census task: instrument and RECORD current order, replicate exactly in GameFrame, reorder only as a later deliberate change |
| Autoload creep (+3 new) against a 14-autoload diagnosis | WA–WD | Autoload census in scoreboard; each new autoload names its burial (PerceptionServer buries in-agent perception; FXBus buries gun_fx churn; GameFrame buries per-node `_physics_process`); net ≤14 at WD close |
| Event-bus fan-out cost (60 connected agents × per-shot signals) | WB | Design rule: spatial-bucket direct dispatch, no broadcast signals (§0) |
| Bench noise laundering a regression | all | Counters primary, fps confirmatory; median-of-3; fixed seeds; ledger rows carry commit hashes |

**Highest-regression wave: WB** (pillar-touching dormancy + 5-way LOD merge + LazyGroup
merge + council decree dependency). WA is the widest but most probe-able. The plan
deliberately spends W0 building the net before either.

---

## 4. Bead-graph skeleton (each task ≤ 1 session)

**Epic `AICON` — AI Consolidation (gated on Summoner blessing)**

- **W0 Scoreboard + seams** (epic-blocks: WA)
  - W0.1 Counters: ray/think/instantiate shims + overlay & ps2_probe SUMMARY fields (incl. p99)
  - W0.2 AgentRegistry: one roster + tier field; subsume `CombatManager.active_*` (burial + probe)
  - W0.3 C2 pre-warm + Shader Baker preset + patrol long-walk bench script + baseline ledger rows (windowed batch — Summoner flag)
  - W0.4 Preservation-probe audit: witness / 2:1 / fairness / dormant-corpse probes written & green on current code
  - W0.5 Micro-probes: notifier-headless fact, autoload tick order
- **WA Perception wall** (needs W0; blocks WC)
  - WA.1a PerceptionServer core: vislist, budget+cursors, funnel, perceivability fn; enemies read timestamps
  - WA.1b Allies + corpse class migrated; in-agent perception paths DELETED (staged burial); state_log ring buffer
  - WA.2 Body gate: move_tick + HitzoneBuilder.sync + AnimationTree, heartbeat + pre-roll
  - WA.3 Think stagger + global ≤4 full thinks/frame
  - WA.4 Fairness ramp migration onto timestamps (one ramp authority)
  - WA.5 Exit gate: probes + counters + windowed bench row (Summoner flag)
- **WC Effects** (needs WA; blocks WB.3)
  - WC.1 FXBus + steal-oldest pools + gun_fx burial
  - WC.2 Zero-instantiate probe + spike/worst-frame bench row
  - WC.3 Closed-form grenades + grenade token (game-designer sign-off bead)
- **WB Sleep/wake** (needs WA; WB.3 needs WC.1)
  - WB.0 **Council decree: tier authority** — WorldSim-wire vs AIDirector (TD recommendation: AIDirector tick-list on W0 registry; bury WorldSim tiers). The ONE open decision for the council
  - WB.1 Tier authority (HOT/LIVE/DORMANT[/AGGREGATE]) + collapse `_update_think_lod` / civilian `lod_tier` / hot-set wiring / `set_lod_*` stubs / WorldSim per decree (burials named)
  - WB.2 LazyGroup → tier promotion merge + ADR-005 dormant-corpse probe
  - WB.3 NoiseBus → AIEventBus: radius table, priority ladder, awareness dice, FXBus emitters, bucket dispatch
  - WB.4 AGGREGATE fireteam-dot at 1 Hz (optional — may defer without blocking WD)
  - WB.5 Exit gate: patrol long-walk bench + night-arena no-regression row (Summoner flag)
- **WD Structure** (needs WB)
  - WD.1a Tick-order census + GameFrame core
  - WD.1b Migrate `_physics_process` holders in batches (30 → ≤12)
  - WD.2a State machine: function-per-state + state_log formalized
  - WD.2b Personality → EnemyData rows; squad comms via vislist sharing; ally/enemy body merge
  - WD.3 Burials: apply_bullet_damage · SimClock decision · world_config ladder decision
  - WD.4 Arena thin wrapper (ADR-028 Phase 3) + structural probe
  - WD.5 Final bench sweep + fossil-baseline shrink + ledger close-out

Dependency spine: W0 → WA → WC → WB → WD (WB.3 additionally on WC.1; WA.3 independent but
held in WA; WD.2a seeded by WA.1's extraction).

---

## 5. What is sacrificed (Law 2)

Staler decisions under load (budgeted thinks/rays — bounded by class floors and the
starvation gate); effect fidelity degrades under saturation (steal-oldest — by design);
dormant AI reacts only to what the event bus broadcasts (event coverage must be honest —
WB.3's radius table is a contract, not a suggestion); W0 spends one wave of Summoner
patience producing zero fps (it buys trustworthy numbers for four waves); WD delivers
almost no fps at all (it delivers the codebase the next year of features lands on); and
native-night-arena 30 fps is NOT promised by any CPU wave — that scene is GPU-bound at
51.9 ms native and the shipped config is the config of record.

## 6. Open questions for the Summoner (kept to the genuine minimum)

1. WB.0 tier authority decree (council decides; TD recommends AIDirector + bury WorldSim).
2. Windowed bench cadence: one announced batch per wave close acceptable? (Never-spam law.)
