# Quake 3 Code-Mine: Simplification + Throttling Patterns for RECONgame
*(agent mining report, 2026-07-18. Sources: id-Software/Quake-III-Arena GPL (`q3:`), ioquake/ioq3 (`ioq3:`))*

## 1. The frame model: one authority, fixed chunks, residual accumulator

**Mechanism.** The whole game sim runs from ONE call site. `SV_Frame` (`q3:code/server/sv_main.c:751-852`): `frameMsec = 1000 / sv_fps->integer` (sv_fps default **"20"** → 50ms, `q3:code/server/sv_init.c:596`), accumulate `sv.timeResidual += msec` (line 777), then `while (sv.timeResidual >= frameMsec) { svs.time += frameMsec; VM_Call(gvm, GAME_RUN_FRAME, svs.time); }` (lines 832-838). The game never sees wall clock — it sees `levelTime` in exact 50ms steps. Renderer/client framerate is completely decoupled; the client interpolates between 20Hz snapshots.

`G_RunFrame` (`q3:code/game/g_main.c:1713-1832`) is a single flat loop over one fixed array `g_entities[MAX_GENTITIES]` (**1024** slots, `GENTITYNUM_BITS 10`, `q3:code/game/q_shared.h:1095-1096`), dispatching by `eType`: missiles → `G_RunMissile`, items/physics → `G_RunItem`, movers → `G_RunMover`, clients → `G_RunClient`, everything else → `G_RunThink` (lines 1773-1793).

**nextthink scheduling** (`G_RunThink`, `q3:code/game/g_main.c:1688-1704`): an entity does ZERO work unless `nextthink > 0 && nextthink <= level.time`; then `nextthink` is cleared and `ent->think(ent)` runs once. Entities re-arm themselves. Default game logic granularity is `FRAMETIME 100` msec (`q3:code/game/g_local.h:38`) — item respawns, corpse sink, etc. all think at 10Hz or slower, on the 20Hz spine. Nothing polls. Per-second work is explicit: `ClientTimerActions` — "Actions that happen once a second" (`q3:code/game/g_active.c:398-403`).

**Hz table (dedicated Q3, 1999):** sim spine 20Hz · misc entity thinks ≤10Hz (nextthink) · client regen/timers 1Hz · bot decision AI 10Hz staggered (`bot_thinktime` 100ms) · bot input pump every server frame · snapshots per-client 20Hz max, rate-choked down.

**Why cheap.** One loop, one clock, one array; the "scheduler" is one integer compare per entity per tick. Cost scales with *armed* entities, not existing ones.

**Godot translation.** You already have the 66ms cap and 6-7Hz AI. What's worth copying is the *shape*: ONE `_physics_process` owner (a `GameFrame` autoload) that owns `level_time_ms` (int, +=tick, never float), and walks a flat array of registered sim objects with `if obj.next_think_ms > 0 and obj.next_think_ms <= level_time_ms: obj.next_think_ms = 0; obj.think()`. Individual nodes should NOT have their own `_process`/`_physics_process` — every enabled `_process` in Godot is a per-frame native→script call even if the method body early-outs. This is your anti-"14 parallel live systems" hammer: WorldBuilder-style, one deterministic frame authority, systems become functions called from it in a fixed order, not nodes that each tick themselves.

## 2. Snapshot/PVS: "don't transmit (or simulate) what can't be perceived"

**Mechanism.** Every snapshot is rebuilt from scratch per client, per send: `SV_BuildClientSnapshot` (`q3:code/server/sv_snapshot.c:436-515`) → `SV_AddEntitiesVisibleFromPoint` (lines 283-421). The filter chain, in cost order:
1. `!ent->r.linked` → skip (line 317) — unlinked = doesn't exist to anyone.
2. Flag gates: `SVF_NOCLIENT`, `SVF_SINGLECLIENT`, `SVF_CLIENTMASK` (lines 327-349) — per-recipient existence.
3. `SVF_BROADCAST` → always sent (line 359).
4. Area connectivity: `CM_AreasConnected(clientarea, svEnt->areanum)` (line 366) — closed doors sever whole regions.
5. Cluster PVS bit test: precomputed at *link time* — the entity caches which visibility clusters it touches; the test is `bitvector[l>>3] & (1<<(l&7))` (lines 381-386). **No raycast ever.**

Snapshot capped at `MAX_SNAPSHOT_ENTITIES 1024` (line 228). Per-client send *rate* is also individually throttled: `client->nextSnapshotTime = svs.time + rateMsec` (`q3:code/server/sv_snapshot.c:588`), `snapshotMsec = 50` default (`q3:code/server/sv_client.c:1159-1161`) — clients naturally stagger; a choked client just gets snapshots less often (`rateDelayed`, lines 583-586), and the sim doesn't care.

Bonus in the same file family: origins are integer-snapped before transmit (`SnapVector` in `G_TempEntity`, `q3:code/game/g_utils.c:497-498`) — quantize everything you replicate/store.

**Why cheap.** All the expensive spatial reasoning (PVS) was precomputed offline by q3map; runtime is a bit test. Perception gating happened at the *data* layer, so effects/sounds/entities behind a hill cost zero bytes and zero client work.

**Godot translation (the big one for AI-count + vegetation frame cost).** Build a **PerceptionBus**: precompute a coarse AO grid (e.g. 32m cells over the 1km AO) with a baked cell-to-cell "can possibly see" table (offline raycast fan from cell centers, terrain + canopy only — your impostor-card jungle is perfect for a "dense canopy blocks long sight lines" bake). Then:
- **Effects/audio gating**: a VC muzzle flash 600m away in unconnected cells spawns *nothing* — no particle node, no AudioStreamPlayer3D, no decal. Distance-only culling is wrong in jungle; PVS-style culling is much more aggressive.
- **AI LOD by perceivability**: fireteams in cells not connected to the player's cell (and not in recent contact) drop to "aggregate mode" — position advanced along patrol route at 1Hz, no per-soldier animation, no physics body, no individual LOS checks. Q3's lesson: perceivability is a *server-side data property*, checked with a table lookup, not a physics query.
- Godot mechanics: `VisibleOnScreenNotifier3D` handles the renderer side already; the PVS table is for *sim/audio/AI*, which the renderer can't cull for you.

## 3. The event system: effects as data, not objects (the node-per-tracer killer)

**Mechanism.** Two flavors, one contract — `entityState_t.event/eventParm` (`q3:code/game/q_shared.h:1317-1318`):
- **Piggyback events**: `G_AddEvent(ent, event, parm)` (`q3:code/game/g_utils.c:574-596`) stuffs the event into the entity's existing state. Top 2 bits are a sequence counter so the same event twice in a row is still detected: `EV_EVENT_BIT1 0x100 / EV_EVENT_BITS` (`q3:code/game/bg_public.h:341-343`, consumption dedupe at `q3:code/cgame/cg_event.c:1190-1196`). A muzzle flash costs **zero extra entities** — it rides on the shooter.
- **Temp entities**: `G_TempEntity(origin, event)` (`q3:code/game/g_utils.c:486-505`) for effects at a point with no owner entity (bullet impacts, explosions). It's a bare entity whose `eType = ET_EVENTS + event`, flagged `freeAfterEvent = qtrue`.

**Lifecycle** (`q3:code/game/g_main.c:1742-1767`): events auto-clear after `EVENT_VALID_MSEC 300` (`q3:code/game/bg_public.h:345`); temp entities are then freed wholesale. Temp entities never think (line 1765-1766). Server does **not** simulate the effect at all — even a played sound is just `G_Sound` → temp entity with a soundindex parm (`q3:code/game/g_utils.c:604-609`).

**Client consumption**: `CG_CheckEvents` (`q3:code/cgame/cg_event.c:1174-1204`) fires each event exactly once into one giant switch (`CG_EntityEvent`). Visual results go into **fixed pools that steal the oldest**: `MAX_LOCAL_ENTITIES 512` (`q3:code/cgame/cg_localents.c:29`), `CG_AllocLocalEntity` "Will allways succeed, even if it requires freeing an old active entity" (lines 77-87); decals: `MAX_MARK_POLYS 256` + `CG_AllocMark` same policy (`q3:code/cgame/cg_local.h:65`, `q3:code/cgame/cg_marks.c:83-87`). The ~40 `EV_*` codes (`q3:code/game/bg_public.h:347-452`) cover the entire audiovisual vocabulary of the game.

**Why cheap.** An impact is 2 ints + a snapped vec3, alive for 300ms. The client turns it into pooled sprites/sounds with a hard memory ceiling and graceful degradation (oldest effect dies first) — a firefight can never allocate unboundedly.

**Godot translation.** One autoload `FXBus` with `func emit(ev: int, pos: Vector3, parm: int)`. Combat code (server-side logic) NEVER instantiates effect scenes. `FXBus` first asks PerceptionBus "can the player perceive this cell?" — if no, return before any work. If yes, dispatch into preallocated pools: one `MultiMeshInstance3D` for tracers, one for impact sparks/dust (or a fixed array of reusable `GPUParticles3D` you `restart()`), a ring buffer of ~256 decals, a pool of ~32 `AudioStreamPlayer3D` (steal-oldest, exactly `CG_AllocLocalEntity`). One `match ev:` switch in one file = your `cg_event.c`. This converts N AI shooters × M shots from node churn into array writes, and gives you a single throttle point (shrink pool sizes on a slow frame).

## 4. Botlib: why 16+ bots fit on a Pentium II

**Architecture split**: deliberation in `q3:code/game/ai_*.c` (mod side), navigation/perception substrate in `q3:code/botlib/` (engine side). Key mechanisms:

- **AAS instead of raycasting the world.** The map is precompiled *offline* (bspc tool, `q3:code/bspc/`) into convex reachability areas + precomputed reachability links with travel times (`aas_area_t`, `aas_reachability_t`, `aas_cluster_t`, `q3:code/botlib/aasfile.h:133-218`). At runtime, "where can I go / how long to get there" is graph lookup, never collision query. Routing uses a **lazily-built, LRU-capped cache**: `AAS_GetAreaRoutingCache` builds a travel-time table per (cluster, goal-area, travelflags) on first request (`q3:code/botlib/be_aas_route.c:1399-1438`), capped at `max_routingcache` **4096KB** (line 1241), evicting via `AAS_FreeOldestCache` (lines 621-727).
- **Think Hz + staggering.** `bot_thinktime` default **"100"** ms, hard-capped at 200 (`q3:code/game/ai_main.c:1645, 1435-1437`). The stagger formula — `botstates[i]->botthink_residual = bot_thinktime * botnum / numbots` (`q3:code/game/ai_main.c:1067`) — phase-offsets every bot so with 10 bots at 10Hz, each 50ms server frame runs ~5 bot brains, never all 10. Each bot then accumulates its own residual and thinks when due (lines 1535-1544). Meanwhile the cheap part — `BotUpdateInput` + `trap_BotUserCommand` (pushing the *last computed* movement command into the shared player-movement code) — runs every server frame (lines 1549-1560). **Decide slow, act smooth.**
- **World mirror updated at bot Hz, not sim Hz.** Entity state is copied into botlib (`trap_BotLibUpdateEntity`) only inside the botlib-residual block (lines 1453-1525), and explicitly skips missiles and event-only entities (lines 1476-1484) — bots don't perceive bullets, only results. Item-goal recomputation is amortized to every **0.3s** (`BotAIRegularUpdate`, `q3:code/game/ai_main.c:928-933`).
- **Perception is filtered before it's paid for.** `BotFindEnemy` (`q3:code/game/ai_dmq3.c:2929-3047`): per candidate — team/dead/invisible flag checks, then squared-distance gate `squaredist > Square(900 + alertness*4000) → skip` (line 3012), then FOV cone test `InFieldOfVision` (line 2840, mathematical, free), and only THEN up to 3 traces (mid/bottom/top of bbox) in `BotEntityVisible` (lines 2825-2921), early-outing at `bestvis >= 0.95` (line 2915). FOV itself narrows with distance (line 3019). Traces are the *last* filter, never the first.
- **Goal stack + flat FSM.** Long-term/nearby goals live on a small stack (`goalstack[MAX_GOALSTACK]`/`BotPushGoal`/`BotPopGoal`, `q3:code/botlib/be_ai_goal.c:172-173, 1202-1229`). Behavior is ~12 explicit nodes — `AINode_Seek_LTG`, `AINode_Battle_Fight`, `AINode_Battle_Retreat`, etc. (`q3:code/game/ai_dmnet.h:35-57`) — with goal timeouts (`nbg_time = FloatTime() + 4 + range*0.01`, `q3:code/game/ai_dmnet.c:1899`) so bots can't wedge; a `MAX_NODESWITCHES 50` guard catches oscillation (`q3:code/game/ai_dmnet.h:33`).

**Godot translation.** (a) Your 6-7Hz think matches `bot_thinktime`; make sure you also copied the **stagger formula** — `agent.think_offset = think_interval * index / count` — and the **think/act split** (steering continues every physics tick from cached decisions). (b) Replace runtime NavMesh + raycast-heavy queries with a baked tactical graph over the AO: waypoint/cell graph with precomputed cover flags, canopy-occlusion, and travel times; cache route tables per objective node lazily with an LRU cap (Q3 literally ships the eviction policy). (c) Enforce the perception funnel order in AI code: flags → distance² → FOV dot-product → PerceptionBus cell test → *only then* `intersect_ray`, with a global per-frame trace budget. (d) Skip perceiving projectiles entirely; react to fire via suppression events (you already have suppression — feed it from FXBus events, not from bullets).

## 5. Memory discipline: preallocate, pool, never allocate mid-combat

**Mechanism.**
- Engine: hunk (level-lifetime, `com_hunkMegs` default **56/64MB**, `q3:code/qcommon/common.c:45-49, 1504`) + small zone; everything level-scoped is freed by resetting a pointer.
- Game VM: `g_entities[1024]` static; `G_Alloc` is a bump allocator over a static **256KB** pool with NO free (`POOLSIZE (256*1024)`, `q3:code/game/g_mem.c:31-53`). Entity "allocation" is slot reuse with a 1s cool-down to protect network delta coherence (`G_Spawn`, `q3:code/game/g_utils.c:395-434`).
- Client effects: fixed pools, steal-oldest (§3).
- Assets: everything is precached during load. Server registers names into configstrings (`G_ModelIndex`/`G_SoundIndex`, `q3:code/game/g_utils.c:116-121`); client loads ALL of it in `CG_RegisterSounds`/`CG_RegisterGraphics` during `CA_LOADING` (`q3:code/cgame/cg_main.c:1923-1927`). After load, gameplay refers to assets as **small integers**. Mid-frame the game allocates *nothing*.

**Why cheap.** Zero malloc/GC jitter; every frame's memory behavior identical to the last.

**Godot translation.** (a) `preload()`/load-screen-load every combat asset (scenes, materials, audio streams) into an autoload registry; gameplay passes registry indices, not paths — never `load()` in combat. (b) Pools for every combat-spawned thing: soldiers, grenades, tracers, decals, audio players — `instantiate()` count during a firefight should be **zero** (matches your fresh-player law: probe it — count instantiations per frame in a test). (c) Godot-specific: also pre-warm shaders/particles once at load (spawn each effect offscreen for a frame) — Q3's equivalent was registering all shaders at load; in Godot 4.7 the first-use pipeline compile is your hitch. (d) Steal-oldest, never fail: effect quality degrades under load instead of frame time.

## 6. Simplicity discipline worth stealing

- **Flat data contract.** `entityState_t` (`q3:code/game/q_shared.h:1285-1327`) is 4 systems' shared language (game, server, client, bots): ints + vec3s + a `trajectory_t`. No pointers, no inheritance, no callbacks in data. RECONgame equivalent: a plain `SoldierState` (Dictionary-free, typed fields, or PackedFloat32Array columns) that AI, animation, FX, and save code all read — instead of each system holding node references into each other.
- **Closed-form trajectories.** `trajectory_t` + `BG_EvaluateTrajectory` (`q3:code/game/q_shared.h:1261-1276`, `q3:code/game/bg_misc.c:1203-1272`): projectiles/movers don't integrate per frame — position is `f(trBase, trDelta, trTime)`; `G_RunMissile` evaluates + one trace from old to new pos (`q3:code/game/g_missile.c:447-453`). Grenades in RECONgame: compute the parabola once at throw, evaluate per tick, one segment intersect — no RigidBody3D per grenade, and it's deterministic.
- **Single owner per system, one file:** damage = `g_combat.c`, projectiles = `g_missile.c`, ALL effect spawning = `cg_event.c`, movement = `bg_pmove.c` ("both games player movement code", `q3:code/game/bg_pmove.c:23-24` — same code predicts on client and executes on server; bots inject `usercmd_t` through the same path, `q3:code/game/ai_main.c:1559`: AI and player are the same body). Visibility+transmit = `sv_snapshot.c`.
- **Hard interface seams.** The entire game logic touches the engine through one enum of syscalls (`q3:code/game/g_public.h:106+`) and exports exactly **8 entry points** (`gameExport_t`, `q3:code/game/g_public.h:397-428`). You can't grow a hidden side-channel. Godot: give each system one script with an explicit public API, wired only through the GameFrame authority and buses; no cross-node `get_node("../..")`.
- **Spatial queries via a dumb fixed structure**: 4-deep/64-node world sector tree for entity-in-box queries (`AREA_DEPTH 4 / AREA_NODES 64`, `q3:code/server/sv_world.c:71-74`). A 1km AO needs nothing smarter than a fixed grid of entity buckets updated on move.
- **Self-defense clocks**: time-wrap restart at `0x70000000` (`q3:code/server/sv_main.c:788-796`) — ints for time, and known rollover behavior.

## 7. ioq3 additions relevant to throttling/simplification

- **Context-aware frame throttling**: `com_maxfpsUnfocused` / `com_maxfpsMinimized` (`ioq3:code/qcommon/common.c:2779-2781`, applied 3120-3127) — different tick budgets per attention state. RECONgame: window unfocused → drop render scale/FPS cap and AI to patrol-tier.
- **Sleep, don't spin**: `com_busyWait` default **0** with precise `NET_Sleep(timeVal - 1)` until next due frame (`ioq3:code/qcommon/common.c:3143-3161`), `SV_FrameMsec` computing exact ms until next sim step (`ioq3:code/server/sv_main.c:1030-1045`), and `Sys_Sleep(-1)` full block when a dedicated server has no map (`ioq3:code/server/sv_main.c:1069-1072`) — fixed the 100% idle-CPU bug (`ioq3:ChangeLog:52`). Pattern: an idle subsystem should cost literally nothing — gate whole systems off, don't early-return per member per frame.
- **Framerate stabilizer**: the `bias` accumulator subtracts last frame's overshoot from the next frame's budget so the *average* rate holds (`ioq3:code/qcommon/common.c:3129-3137`) — a 5-line pattern for keeping a fixed-Hz AI scheduler honest when a spike delays it.
- **Simplification precedent**: ioq3 deleted Q3's per-client `nextSnapshotTime` scheduler and just iterates all clients each server frame, skipping only if rate-choked (`ioq3:code/server/sv_snapshot.c:643-685`), clamping client `snaps` to `sv_fps` (`ioq3:code/server/sv_client.c:1449-1461`). When the anytime-scheduler and the fixed tick fight, keep the tick and delete the scheduler.
- `frameMsec` scaled by `com_timescale` with a 1ms floor (`ioq3:code/server/sv_main.c:1087-1091`) — clean slow-mo/fast-forward through one variable, useful for RECON replay/debug.

---

# TOP 10 GOLD (ranked by expected payoff for large-combat RECONgame)

1. **FXBus event system + steal-oldest pools** (§3, `g_utils.c:574`, `cg_localents.c:80-93`). Kills node-per-tracer/decal/sound dead; caps worst-case effect cost at pool size regardless of how big the firefight gets.
2. **Perceivability gating (PVS-style baked cell table)** (§2, `sv_snapshot.c:283-421`). Effects, audio, and AI detail for anything the player can't possibly perceive cost ~zero. In dense jungle this culls far more than distance ever will.
3. **Perception funnel with trace-last ordering + global trace budget** (§4, `ai_dmq3.c:3012-3021`). Flags → dist² → FOV dot → cell table → raycast.
4. **Single game-frame authority walking one flat list with `next_think_ms`** (§1, `g_main.c:1688-1793`). One clock, one loop, zero per-node `_process`. The structural cure for the overlapping-systems disease.
5. **Staggered AI think: `offset = interval * i / count`, decide at 6-7Hz, act every tick from cache** (§4, `ai_main.c:1067,1535-1560`).
6. **Zero allocation in combat: preload registry + pooled everything + pipeline pre-warm** (§5, `g_mem.c:31`, `cg_main.c:1923-1927`).
7. **Closed-form trajectories for grenades/mortars/thrown FX** (§6, `q_shared.h:1270-1276`, `g_missile.c:447`).
8. **Baked tactical graph + LRU route cache instead of live nav queries** (§4, `be_aas_route.c:1399-1438`, 4MB cap).
9. **Aggregate-mode AI for unperceivable fireteams** (§2+§4, botlib's skip-missiles/skip-events precedent, `ai_main.c:1476-1484`). Off-cell squads advance as a single dot at 1Hz.
10. **ioq3 attention throttling + sleep-when-idle + bias stabilizer** (§7, `common.c:3113-3161`).

Anti-pattern confirmed by the source: Q3 has **no** per-entity update manager, no observer webs, no effect objects with lifecycles — effects are data, AI is a table-driven funnel, and exactly one function advances the world. Everything above is that one idea applied five ways.
