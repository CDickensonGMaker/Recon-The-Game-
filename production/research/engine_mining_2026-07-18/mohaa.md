# OpenMoHAA AI Mining Report — for RECONgame
*(agent mining report, 2026-07-18. Source: openmoh/openmohaa — open reimplementation of MoHAA on the id Tech 3 / ioquake3 base. Paths relative to `code\fgame\` unless noted. MoHAA units: ~39.4/m — 2048u ≈ 52 m. Server tick: 20 Hz / 50 ms (`gamecvars.cpp:389`, `server/sv_init.c:1097`) — every actor "thinks" each 50 ms tick, but all expensive work inside is time-gated far below that.)*

## 1. Think architecture

**Two-axis state machine.** `eThinkState` (WHAT: IDLE/PAIN/KILLED/ATTACK/CURIOUS/DISGUISE/BADPLACE/GRENADE/NOCLIP, `actor.h:328`) × `eThinkNum` (HOW: TURRET/COVER/PATROL/RUNNER/ALARM/etc., `actor.h:342`). A per-actor `m_ThinkMap[state]→think` (`actor.h:621`) lets level scripts swap the implementation of ATTACK per actor (`type_attack cover|turret|balcony|runandshoot`, `actor.cpp:7982`). Defaults: ATTACK→THINK_TURRET (`actor.cpp:8126-8151`). Each think is a static vtable struct `GlobalFuncs_t {ThinkState, BeginState, EndState, SuspendState, ResumeState, PassesTransitionConditions, ReceiveAIEvent, ...}` (`actor.h:587-615`) — zero allocation, one indirect call per tick (`actor.cpp:7582-7586`).

**Priority think levels** (`actor.h:383`): IDLE < PAIN < KILLED < NOCLIP. Pain/death preempt via Suspend/Resume — an interrupted cover run resumes cleanly (`actor.cpp:8295`). Transition polling is one function-pointer chain in fixed priority order: grenade > badplace > attack > disguise > curious > idle (`actor.cpp:8516-8539`).

**The dormancy gate — the single biggest trick.** `Actor::Think` early-outs on `g_ai`, `m_bDoAI` (script `ai_on/ai_off`, `simpleactor.cpp:1209-1217`), then every `Think_X` starts with `RequireThink()`:

```cpp
// actor.cpp:6607
return (level.inttime < edict->r.lastNetTime + 60000);
```

`lastNetTime` is stamped by the **server snapshot system** when the entity is actually sent to a client (`server/sv_snapshot.c:542`) — i.e. PVS-relevant recently. An actor no client has "seen" for 60 s stops evaluating perception, transitions, pathing, animation, and movement entirely. **Idle far actor cost/frame ≈ the `Actor::Think` preamble** (origin-history slot at 8 Hz, `FixAIParameters` clamps, one bool compare; `actor.cpp:7543-7586`) — no traces, no path, no anim (`m_bAnimating=false` skips PreAnimate, `g_main.cpp:546-551`; MOVETYPE_WALK does nothing in `G_RunEntity`, `g_phys.cpp:1408`). Waking is event-driven: AI sound events and damage go through `ReceiveAIEvent`/Pain regardless.

**Godot translation.** Don't tick 40 AI in `_physics_process`. One `AIDirector` autoload owns an array of agents; each agent stores `relevant_until_msec`, refreshed when inside camera frustum+fog range or within N m of any human-relevant actor. Dormant agents: zero per-frame cost (**remove from the tick list — not "return early", don't call them**), reachable only via the sound-event bus and damage signals. 60 s grace matches MoHAA.

## 2. Perception — vision

**Cheap-first ordering, one trace max** (`entity.cpp:2872-2898`): dist² → `AreasConnected` (BSP area-portal reachability — free room-level rejection *before* any ray) → 2-D FOV dot (`actor.cpp:3935-3952`) → single ray (`MASK_CANSEE`, `bg_public.h:669`).

**Fog caps sight.** Vision distance = `min(m_fSight, farplane_distance)` (`actor.cpp:3917-3926`); enemy-visible checks use `farplane * 0.828` (`actor.cpp:4071`). Defaults: sight = world AIVisionDistance 2048u ≈ 52 m (`actor.cpp:2821`, `worldspawn.cpp:601`), FOV 90° (`actor.cpp:2785`).

**Dirty-time caching — callers declare freshness.** `CanSeeEnemy(iMaxDirtyTime)` / `CanShootEnemy(...)` / `EnemyInFOV(...)` / `UpdateEnemy(...)` recompute only if the cached timestamp is stale (`actor.cpp:4048-4091`, `6656-6661`). Real intervals used: **attack transition 0 ms, curious 100, attack-states 200–500, idle 500, disguise 1500–2000** (`actor.cpp:8619,8711,8740`; `actor_cover.cpp:333,367`; `actor_turret.cpp:194,565`; `actor_disguise_salute.cpp:80`).

**Round-robin enemy set: ≤1 sight trace per actor per perception update.** `ActorEnemySet::CheckEnemies` (`actorenemy.cpp:341-451`) walks candidates with a persistent cursor `m_iCheckCount` and **stops at the first enemy in FOV+range**; only that one gets the LOS trace (inside `UpdateLMRF`, `actorenemy.cpp:75`). Candidate list = opposing team's intrusive linked list `level.m_HeadSentient[1 - m_Team]` (`actor.cpp:6630`) — no global entity scans.

**Noticing is an integral, not a boolean.** `m_fVisibility += frametime / LMRF`, decays −0.25/s when unseen (`actorenemy.cpp:102-126`). LMRF (notice-time factor, `actorenemy.cpp:30-100`) multiplies: range curve, FOV-edge penalty, target's `stealthMovementScale` (crouch/slow = harder), actor `m_fNoticeTimeScale` and cvar `g_ai_noticescale`. Enemy "confirmed" only at visibility ≥ 0.999 — distant/peripheral glimpses cost nothing extra and produce gradual, humanlike detection. Alertness: sound events *lower* notice time (fire −0.2, explosion −0.4, voice −0.25, footstep −0.05, capped at 2/3 current; `actor.cpp:9585-9643`), recovering at +0.1/s (`actor.cpp:6640`).

**Player-look reciprocity:** the player's aim accumulates `m_fPlayerSightLevel` on watched actors, added into their visibility of *you* (`player.cpp:4437-4455`, `actorenemy.cpp:120`) — scoping a guy makes him notice you sooner. Free drama.

**Smoke:** actors sample **one random** smoke sprite per check, not all (`actor.cpp:6676`); LOS gets an obfuscation alpha (`G_VisualObfuscation`, `g_utils.cpp:507`) vs a 0.5 threshold (`actor.cpp:3878-3885`).

**Godot:** identical layering with `intersect_ray` as the *last* step; cache `{can_see, checked_msec}` per agent with a per-state max-dirty table; round-robin one ray/agent/think; make AI sight = fog draw distance (PS2 fog becomes a perception *budget*). Foliage is NOT in the sight-ray mask — concealment is modeled by notice-time multipliers and cover flags, so rays only test solid geometry — vastly cheaper than per-leaf occlusion, and matches the impostor-card foliage decree.

## 3. Perception — hearing (event-driven wakeup)

`G_BroadcastAIEvent(originator, origin, type, radius)` (`g_utils.cpp:1786-1855`): iterate sentient list, dist² + area-connected cull, then `act->ReceiveAIEvent(...)`. **No polling anywhere.** Radii (`g_utils.cpp:1771`): weapon_fire 2048 (52 m), impact 384, explosion 4096 (104 m), voice 1024, urgent-voice 1536, footstep 512 (13 m), grenade 384. Emitters: weapon fire (`weapon.cpp:3083`; loud guns clamp(world_radius/2, 1500, 8000) `weapon.cpp:1614`), impacts (`weaputils.cpp:1237`), explosions (`explosion.cpp:133`), footsteps (`sentient.cpp:2941`).

Receiver (`actor.cpp:9095-9150`): hearing gate (`m_fHearing` 2048 default), then per-type: `CuriousSound` rolls `soundAwareness * rangeFactor` vs random (`actor.cpp:9243-9253`), applies **priority ladder** (grenade 8 > weapon_fire 7 > explosion 6 > impact 5 > urgent 4 > voice 3 > footstep 2 > misc 1, `actor.cpp:9159`) so a footstep never overrides investigating gunfire (`m_iCuriousLevel`, `actor.cpp:9259`), sets `m_vLastEnemyPos` to the sound origin and flips to CURIOUS. Footsteps/voices only "count" when the source is *not* visible (`actor.cpp:9679-9699`). **Friendly events auto-merge squads**: any event from a same-team non-squadmate merges the intrusive squad ring (`actor.cpp:9103-9106`).

**Cost scaling:** O(events × actors) with two float compares per actor — fine at hundreds; broadcast rate, not think rate, is the driver.

**Godot:** an autoload `AIEventBus.emit(pos, type, origin_actor)` with the radius table above; agents register on spawn. This IS the wakeup path for dormant agents (a firefight 40 m away re-arms `relevant_until`). Keep the priority ladder and the "only unseen sources trigger curiosity" rule; add the awareness dice-roll so a whole treeline doesn't pivot in lockstep.

## 4. Navigation

**Designer-placed node graph, all expensive facts precomputed offline.** ≤4096 `PathNode`s (`navigate.h:224`), each ≤48 links stored as `pathway_t{dist, dir, pos1, pos2, fallheight, badPlaceTeam, numBlockers}` (`navigate.h:87-96`) — connectivity, widths (`maxheight[]` per 8-unit width step, `navigate.h:76`), and fall heights baked at map compile/load (`CreatePaths`). Spatial lookup: 256-unit grid cells holding node ids (`navigate.h:219-224`).

**A\*** (`navigate.cpp:304-486`) with three throttles *inside* the search: leash pruning per edge (skip nodes beyond leash-home radius, `navigate.cpp:397-402`), hard `maxPath` abort (`navigate.cpp:433`), fallheight/bad-place team filters per edge (`navigate.cpp:438-440`). `findFrame` int stamps avoid clearing 4096 nodes per search (`navigate.cpp:353`).

**Repath discipline** (`simpleactor.cpp:171-227`): re-search only if (path missing) OR (dirty-time expired AND path complete) OR goal actually changed — combat states call `SetPathWithLeash(lastEnemyPos, NULL, 0)` every think but it no-ops while the goal is stable (`actor_turret.cpp:203`). Path buffer reused, grown in chunks of 10 (`actorpath.cpp:137-143`). Following uses a pure-local 4096u lookahead cutting corners geometrically (`actorpath.cpp:60-115`) — no per-frame re-query. Global budget `MAX_PATHCHECKSPERFRAME 4` (`navigate.h:60`, reset `g_main.cpp:561`) for validity probes.

**Godot:** NavigationServer replaces the graph, but keep every throttle: (1) clamp goal into leash circle *before* asking for a path (leash = `m_vHome` set on spawn/enemy-acquire, default 512u ≈ 13 m — what kept MoHAA fights local and cheap); (2) repath only on goal-moved > threshold / path-complete / dirty-time; (3) an AIDirector token bucket: ≤N `NavigationAgent3D.target_position` writes per frame (that's when Godot recomputes); (4) tactical annotations (cover, sniper spots, grenade-safe lanes) as **hand/tool-placed Marker3D nodes layered on top of the navmesh** — annotation-on-nodes, not navmesh smarts, is where combat quality lives.

## 5. Squad & mass-combat control (how 30-man fights stayed playable)

- **Squads are intrusive circular linked lists** (`sentient.h:183`), formed dynamically by proximity/events (`MergeWithSquad`). No squad manager object at all.
- **Enemy sharing with delay:** 0.75 s after acquiring an enemy, post `ShareEnemy` to squadmates, who confirm only if they can see the sharer or the enemy (`actor.cpp:6719`; `actorenemy.cpp:501-536`) — information propagates at human speed, one guy traces, the squad inherits.
- **Threat-score target selection with crowding discount** (`actorenemy.cpp:128-266`): base 10000/10500(visible) + weapon-class × range-zone matrix (5 zones: 256/768/1280/2048u) + closeness bonus, then **minus attacker-count (capped 4)** (`actorenemy.cpp:245-257`), +5 if he shot me, +5 if player is aiming at me (player adds 3 to his target's count, `player.cpp:4459`), +250 favorite enemy. Fire distributes across targets instead of dog-piling — emergent crossfire discipline with zero coordination messages.
- **Duty-cycled shooting = natural limit on simultaneous attackers.** Cover think alternates SHOOT → HIDE with `Cover_HideTime`: **Americans 2–4 s, Germans 4–15 s** (`actor_cover.cpp:28-33`). In a 12-man German line, only ~a third are firing at any instant — the Normandy feel AND the perf/lethality governor.
- **Cover node claiming:** `Claim/Relinquish/IsClaimedByOther` + 4 s cooldown after release, 5 s temp-bad on failure (`navigate.cpp:3170-3207`) — no two actors pick the same rock; candidate search filters flags/leash/min-max band, sorts by distance, keeps ≤16 (`navigate.cpp:2382-2437`, `MAX_COVER_NODES` `actor.h:296`), validates lazily one per attempt (`actor_cover.cpp:121-161`).
- **Suppression fire:** default 50% chance (`actor.cpp:2956`) to shoot at last-known position for up to 15 s after losing sight, gated by a >50% clear trace (`actor_turret.cpp:329-377`) — sustains fire volume without LOS.
- **Global one-shot tokens:** one "surprise/identify" entry animation per 3 s level-wide (`level.m_iAttackEntryAnimTime`, `actor.cpp:8471`), one curious voice line per window (`actor_curious.cpp:57`) — the "AI theater" never stacks.
- **Movement spacing without avoidance solver:** `MoveOnPathWithSquad` (`actor.cpp:6072-6147`) — if a squadmate is within interval (128u ≈ 3.3 m) ahead of my path direction and we'd converge, **stand for 500 ms** (`m_iSquadStandTime`), ties broken by entnum. Plus `ShortenPathToAvoidSquadMates`. Dumb, robust, O(squad).
- **Corpse ring buffer:** max 5 bodies, oldest deleted (`actor.h:297`, `Actor::AddToBodyQue`).

**Godot:** all directly portable. Threat scoring is a 20-line function; `attacker_count` is an int on the target; hide-time duty cycle is one timer; claims are a `claimed_by/available_at_msec` pair on cover markers; the "stand 0.5 s instead of avoid" rule will outperform NavigationAgent3D avoidance for squads (turn RVO off) — matching the existing 2:1 fire discipline work.

## 6. Combat gunnery (dangerous-but-fair at scale)

AI never rolls to-hit; it **aims at target + error vector** (`GunTarget`, `actor.cpp:10615-10744`): error = `(1 - accuracy·visibilityFactor) * 2 * scatterMult` scaled by cvars (`g_aiScatterWide 16`, `g_aiScatterHeight 45`, cover factor ×0.80 when player concealed, min accuracy 0.33 through smoke, suppress scatter ×2.0, range bands 500/700/1000/2200u per weapon `mAIRange`). Misses are real ray shots that crack past the player's head — threat theater with deterministic DPS knobs. Base game skipped friendly-line-of-fire checks entirely (`actor.cpp:4106-4108` — pre-2.0 returns false; OPM/2.0+ added the squadmate-projection check `actor.cpp:4104-4150`). Grenades: closed-form throw/roll velocity (`CalcThrowVelocity`), designer-placed `GrenadeHint` markers for window/over-wall tosses (`grenadehint.h:31`), grenade-response states (flee via `FindPathAway`, kick-back, martyr) triggered by the grenade *event*, not scanning.

## 7. Script system split (morpheus)

Engine owns: think states, perception, pathing, combat micro. Scripts own: everything level-specific — spawn waves, patrol chains (waypoint `SimpleEntity` targets, `actor_patrol.cpp:52-95` just walks `m_patrolCurrentNode` and fires `movedone`), `ai_off/ai_on`, all ~150 tunables per actor (sight/hearing/accuracy/leash/mindist/maxdist/interval/type_attack..., event table `actor.cpp:2400-2700`). Scripts are cooperative threads on a timer list, executed only when their wait expires (`ScriptMaster::ExecuteRunning`, `scriptmaster.cpp:771-823`), with runaway guard `MAX_EXECUTION_TIME 3000` (`scriptmaster.h:33`); actors notify via `Unregister(STRING_MOVEDONE / HASENEMY / VISIBLE)` (`actor.cpp:7604-7620`) — pure event handshake, zero polling. **What stayed simple because of this:** the engine has NO mission logic, no objective system, no wave manager, no dialogue trees — the AI brain is a reusable soldier and the level `.scr` is the director.

**Godot:** your GDScript scene scripts *are* morpheus. Keep the brain generic + parameter-driven (export vars matching the MoHAA tunable vocabulary: sight, hearing, fov, accuracy, leash, mindist, maxdist, interval, soundAwareness, suppressChance); level scenes wire patrol `Path3D`s and await `move_done`/`has_enemy` signals. FieldDirector = the .scr layer.

## 8. Effects pipeline at scale

Bullet impacts/tracers are **not entities**: compressed client-game-messages (coord + packed normal dir + 1–2 bits caliber) broadcast **only to clients that can see the point** (`gi.SetBroadcastVisible` + `CGM_BULLET_6/7/8`, `weaputils.cpp:2368-2406`); the client spawns decals/particles/sounds locally. Penetration handled server-side by surface flags (`SURF_FOLIAGE`/glass/wood pass-through with damage decay, `weaputils.cpp:2410-2430`). **Godot single-player analog:** one `ImpactSystem` autoload with pooled MultiMesh decals + a few reused GPUParticles3D "one-shot" emitters, fed `(pos, normal, surface_type)`; frustum+distance gate before spawning anything; foliage cards = penetrable surface type (fits the impostor-card destructibility architecture).

## 9. OpenMoHAA modernization notes

- OPM had to *fix* `RequireThink` to let actors think in multiplayer (`actor.cpp:6609-6611`) — confirming the original literally froze AI outside client relevance.
- OPM added a **Recast/Detour navmesh** generated from BSP (`navigation_recast_*.cpp`, `IPather` abstraction `navigation_path.h:41`) because hand-placed nodes don't exist on MP maps for bots — the 2002 system's cost model *depended on designers pre-baking the graph*; runtime navmesh is the modern replacement (Godot has this for free).
- OPM comments flag original oddities kept for parity: unconditional `PathIsValid()==true` (`simpleactor.cpp:322`), no friendly-LOF check in base game, `m_bSilent` never initialized — the original cut corners aggressively and shipped legendary AI anyway.

---

# TOP 10 GOLD (ranked by payoff for large-combat Godot FPS)

1. **Relevance-gated dormancy** (`actor.cpp:6607` + `sv_snapshot.c:542`): AI not player-relevant for 60 s costs ~zero; woken only by sound events/damage. Implement as tick-list membership, not early returns. THE AI-count scaler for a 1 km AO.
2. **Dirty-time cached perception with per-state freshness** (`actor.cpp:4048-4091`; 0/100/200/500/1500 ms table): callers declare how stale is acceptable. O(frames) traces → O(state-changes).
3. **≤1 LOS ray per agent per perception update via round-robin cursor** (`actorenemy.cpp:371-379`) + cheap-first rejection (dist→area→FOV→ray). Add a global AIDirector ray budget (`MAX_PATHCHECKSPERFRAME 4` pattern).
4. **Duty-cycled shooting (hide 4–15 s / shoot bursts)** + **threat score with attacker-count discount capped at 4**: emergent fire discipline that governs difficulty, spreads targets, and caps per-frame combat work. Cheapest "big battle feel" in the codebase.
5. **Event-bus hearing with radius table + priority ladder + awareness roll**: weapons broadcast, AI never polls; doubles as the dormancy wakeup. Radii: shot 52 m, explosion 104 m, footstep 13 m.
6. **Visibility as time-integral (LMRF)**: notice time scales with range/FOV-edge/target-stealth/alertness; decays 0.25/s. PS2-cheap stealth-in-jungle (grass = stealthMovementScale, not raycast-vs-leaves); eliminates LOS-flicker bugs.
7. **Leash/tether everywhere** (13 m default; pruned inside pathfinding; clamps curious/attack goals): fights stay local, paths short, no map-wide pathfinding storms.
8. **Claimable annotated cover markers** (claim/4s-cooldown/5s-tempbad, ≤16 candidates, lazily validated): tactical quality lives in placed data, not runtime geometry analysis. Bake into the firebase chunk kit + village prefabs.
9. **Aim-error gunnery instead of to-hit rolls** (scatter 16 wide/45 high × visibility × range band, suppress ×2): misses are real near-miss shots — feels lethal, tunes deterministically, drives suppression for free. Pair with 50%-chance/15 s suppression at last-known-pos.
10. **Delayed squad knowledge propagation** (0.75 s ShareEnemy, confirm-only-if-plausible, event-driven squad merge, "stand 500 ms" anti-bunch): one perceiver arms a whole fireteam at human speed; squads need no manager object, just a linked ring.

Bonus: global one-shot theater tokens (one entry-anim/3 s, one curious bark per window); corpse ring buffer of 5; sample-one-random-smoke-sprite stochastic checks; AI sight capped at fog distance — with PS2 fog, draw distance IS the perception budget.
