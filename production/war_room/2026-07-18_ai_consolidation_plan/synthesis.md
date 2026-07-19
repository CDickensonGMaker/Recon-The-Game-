# DECREE — AI consolidation plan (PLAN ONLY, awaiting the Summoner's blessing)
2026-07-18 late · Arbiter: recon-overseer · Council: systems-designer, technical-director,
game-designer, devils-advocate (analyses in ./analysis/; all four read live code; the DA
re-verified every "dead" claim and the measurement chain)

## Arbiter rulings on council conflicts
- **SimClock: LIVE ORGAN, not a fossil.** The DA proved it (sim_clock.gd:33-36 self-ticks
  every frame; hour_advanced feeds CampDirector/AmbientWar/AirTraffic/WeatherDirector/
  ConvoySpawner/civilians). The game-designer's "never ticks" claim is OVERRULED on code
  evidence read by the Arbiter directly. The survey's "zero callers" sentence is the only
  fossil. Wire-or-delete is STRUCK; SimClock is untouchable in this plan.
- **B1: AIDirector tick-list wins; WorldSim tiers die.** Systems-designer and TD converged
  independently, and the kill-shot is factual: WorldSim's CELL_SIZE/AO_RADIUS geometry can
  never produce DORMANT on a 1280m map — "wiring it" was a rewrite wearing a fossil's name.
  Registry deletion is a small migration (mission_generator:188-193, world_sim._process,
  test_world_alive) — three named touch points, not a free rm.
- **A2 gate mechanism: sim-side oracle** (fog-cap distance + camera-forward dot + 20m near
  bubble + RTCW conditions: moving/combat/300ms heartbeat + ungate for cover_exit-window and
  downed units). NOT VisibleOnScreenNotifier3D (dead headless = vacuous probes;
  occlusion-blind; render-latent). The same oracle serves C1's FX gate.
- **The 25-192ms number is retired.** It came from a run ADR-026 itself voids (Blender
  open), in a TIME_PROCESS remainder bucket that EXCLUDES _physics_process — where the AI
  actually lives. The wall is real (clean CPU ~44ms night-arena); its attribution is
  unknown. W0 measures before Wave A is believed: 7-13 perception rays/frame ≈ <1ms says
  A2 (body gate) likely carries the milliseconds and A1 is architecture + the A4 fun lever.

## THE WAVES (order: W0 → A → C → B → D; arena wrapper LAST)
**W0 — scoreboard + hardening (no fps gate; everything else is gated on it):**
ray counters (has_line_of_sight/_update_perception/_can_witness/cover/bullet segments) ·
physics-side CPU buckets via the existing report_cpu_bucket plumbing (think/move/
hitzone-sync/anim split, first time) · one clean night bench, Blender closed → the number
of record · **AgentRegistry**: ONE roster, buries the dual registry (groups +
CombatManager.active_* + 5s sync timer); A1 reads it, B1 later adds its tier field ·
C2 pipeline pre-warm · delete set_lod_live/abstract stubs NOW (wrong-shaped — they kill the
brain; deleting first prevents anyone "wiring the existing hook") · **write ALL preservation
probes** (list below) before any wave lands.

**WA — the body gate + perception platform:** A2 body gate first (the ms per W0's own
numbers), then A1 PerceptionServer (budget classes: hostile-unseen 40ms floor → pairs →
friendlies → CORPSES AS A RE-CHECKING CLASS — "once" is vetoed, late discovery is ADR-005;
death-witness check synchronous + staleness-exempt; position queries (_can_witness of
last_known) get a named home in the server), A3 think budget + stagger (WITH: push-based
hot-slot refill on death, ENGAGE_TTL census guard vs stretched thinks, wall-clock disengage),
A4 exposure-ramp re-platform (preservation-class: it IS the live Fairness Law).
Exit: ai physics-bucket median ≤10ms on the W0 baseline bench · rays ≤60/s · ≤4 full
thinks/frame · night arena ≥28 fps shipped config · every preservation probe green.

**WC — allocation flatness:** FXBus + steal-oldest pools (tracer MultiMesh, impacts, decal
ring, audio) behind the A2 oracle; closed-form grenades/mortars (parabola + segment ray).
Exit: instantiate() count in a firefight = 0 (probe) · worst frame ≤40ms shipped · spike
count −50% vs W0 baseline.

**WB — sleep and waking:** B1 AIDirector (HOT=EnemySquad hot-set broker, unchanged /
LIVE=body-gated / DORMANT=off the tick list, event-wake beacons incl. spider-hole triggers
and corpse beacons / AGGREGATE=LazyGroup dot at 1Hz on its patrol route). **Dormancy
catch-up contract:** gut-bleed, downed bleed-out, suppression decay simulate elapsed time on
wake — a dormant dying man still dies (probe). WorldSim deleted (tiers + registry migration).
B2 event-bus wake extending NoiseBus — ADR-005's 150m GUNSHOT stays law (MoHAA radii are
shape, not values); heard ≠ witnessed: bus events NEVER stamp the witness beacon. AGGREGATE
emission contract: deterministic schedule + far-field war signatures + night illum (the
20-hour ambience law keeps its inputs).
Exit: patrol long-walk ai bucket ≤8ms sustained · ≥30 native held after camp visits ·
dormant-corpse + dormancy-clock probes green.

**WD — structure:** D1 one frame authority (flat registry, next_think_ms; nodes lose private
_process where migrated) · D2 god-class split on the engines' seams — SHARE THE BODY
(locomotion/unstick/cover broker/fire path/gore; fixes ally per-frame corpse sync), NEVER
the brain (witness ledger, hold-fire _may_engage, OrderMode, allies pinned HOT) · D3
remaining fossils (apply_bullet_damage; world_config ladder: build attention-throttle or
delete the dial — TD picks in-wave with a probe).
Exit: ±1 fps vs WB · enemy_base ≤1000 lines · ≤12 _physics_process scripts · fossil
baseline shrinks.

**ARENA (ADR-028 Phase 3) — LAST, capability-gated.** The arena is the project's INSTRUMENT
and the rule-#1 benchmark; it stays FROZEN until every wave's before/after is banked. The
wrapper lands only against this checklist: hot_start · awareness-injection seam (migrates
INTO PerceptionServer as its test port, then the arena copy dies) · telemetry +
report_cpu_bucket feeds · the hand-stamped benchmark map preserved as seeded data ·
set_characters_active/set_debug_vis_active seams. Found leak rides along: mirror mode sets
tiering_enabled=false and never restores it.

## THE FUN-LEVER GATE (the DA's rule, now law for this plan)
Anything that changes WHO is shot at, HOW FAR pursuit goes, WHAT gets investigated first,
HOW FAR the enemy sees, or HOW LONG he remembers is a FEATURE — it enters through the
Summoner's eyes or not at all:
- **Duty-cycle rhythm fire** (lull-punctuated incoming, VC/NVA hide-time identity) — the
  game-designer recommends YES; **this is the ONE Summoner question in the plan.**
- Threat-spread merged INTO the 2:1 rule (attacker-count discount, cap) — proposed, WA/WB.
- Leash: naive 13m REJECTED (collides with the shipped 130m hunt net — the most praised
  behavior); if ever, as a movable-home hunt-interaction question. Not in these waves.
- Hearing priority ladder + awareness dice — B2 feature line (conflicts test_los_determinism;
  needs its own bless + probe amendment).
- Fog-as-sight-cap: REJECTED as a silent 140→90m stealth change. Caps stay 140/45.
- RTCW 5s memory: REJECTED. Live 8.0s TARGET_MEMORY stays.
- Grenade token 7s vs live 5s/12s spacing: pacing retune, WB bless line.

## KEEP / KILL / MIGRATE (every named duplicate)
KILL (verified dead): set_lod_live/abstract stubs (W0) · CombatManager.apply_bullet_damage
(WD) · WorldSim tiers (WB) · MAX_THINK_TIME fossil (already baselined; dies with WD).
MIGRATE: WorldSim registry → AgentRegistry (WB; 3 touch points) · CombatManager.active_* →
AgentRegistry (W0) · arena awareness-injection → PerceptionServer test port (arena phase) ·
arena world-build + ArenaGrid → shared world path (arena phase) · 5 LOD notions →
AIDirector tiers (WB; civilian lod_tier last).
KEEP: SimClock + its whole subscriber net (LIVE) · EnemySquad hot-set (HOT broker inside
AIDirector) · LazyGroup (becomes the AGGREGATE tier's body) · arena harness/telemetry/
hot_start/benchmark map (frozen instrument) · think/execute split, 66ms cap, BulletSystem,
ProjectilePool, 2:1 + hot-set (extended only through the fun gate).

## PRESERVATION PROBES (written in W0, all behavioral, no text-greps)
1. test_witness_rule — silent kill unseen ⇒ camp RELAXED; witnessed ⇒ escalation; corpse
   walked past 20s later ⇒ discovery (replaces the source-grep guard A1 would delete).
2. test_dormancy_clocks — active bleed → dormant → wake ⇒ dead/caught-up; suppressed →
   dormant → wake ⇒ decayed.
3. test_think_budget — staggered spawn ⇒ no aligned spikes; hot-slot refill <500ms after
   death; count_engaging census error bounded under budget.
4. test_body_gate — off-screen gated unit still accumulates think ticks + hears; downed and
   cover_exit-window units never gated.
5. test_spider_tunnel — buried spider-hole pops at trigger range at any tier (NEW, unguarded
   today).
6. Existing guards re-run per wave: veg_cover, probe_concealment, detection, low_posture,
   ally_cover_roll, mirror_match, flat_damage, arena_patrol, activity_tiering (rewritten
   behavioral), firefight_len, fairness 4000-sample.

## Named sacrifices (Law 2)
Staler decisions under think budgets · effects degrade steal-oldest under saturation ·
AGGREGATE quantizes positions (doubling back reforms contact differently — wake-fidelity
contract in WB) · dormant AI reacts only to broadcast events (event coverage must be honest)
· two waves of refactor risk on live AI, capped by probe-first + staged burial (replace →
probes green → delete → green, one commit train; no parallel flag paths — fossil law) ·
W0 costs ~2 days before any payoff lands.

## OPEN QUESTIONS FOR THE SUMMONER (only these)
1. Bless duty-cycle rhythm-based incoming fire as the under-fire feel? (council: yes)
2. Bless the plan + wave order as written (one gate; waves then run without mid-phase
   questions per the standing decree).
