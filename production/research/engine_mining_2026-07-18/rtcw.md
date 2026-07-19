# RTCW-SP AI Cast Mining Report — for RECONgame
*(agent mining report, 2026-07-18. Source: id-Software/RTCW-SP GPL, paths relative to `src\`)*

RTCW SP ran ~20–30 simultaneous soldier AI on a 2001 PIII by treating **AI decision-think, AI physics/movement, and AI perception as three separately throttled pipelines**. Q3 engine baseline: server at 20Hz (50ms frames), entities outside player PVS never sent to client (render/anim cost for unseen AI = zero, for free).

## 1. Think scheduling — the three-tier frame architecture

**Tier A — decision think (`AICast_Think`)**: `game\ai_cast_think.c:795` `AICast_StartFrame`, called from the *player's* ClientThink (`game\g_active.c:1432`), so AI decisions are paced by player command arrival.
- Cvars: `aicast_thinktime` default **50ms**, `aicast_maxthink` default **4** (`game\ai_cast.c:490,493`). Design comment at `ai_cast.c:484-488`: "(aicast_thinktime / sv_fps) * aicast_maxthink = number of casts to think between each aicast frame".
- **Hard cap: at most 4 *live* AI run full decision-think per server frame** — loop condition `count < aicast_maxthink` at `ai_cast_think.c:874`; dead AI don't count against the budget (`:916-919`). Round-robin resume pointer `lastthink` (`:870-882`) so starvation rotates instead of repeating.
- Priority gate at `:898-907`: think this frame if (moving `!VectorCompare(velocity,0)`) OR (`enemyNum >= 0`) OR (`aiState >= AISTATE_COMBAT`) OR (saw the player in the last **4000ms**) OR (buttons held) OR (`elapsed >= aicast_thinktime`); scripted-anim casts think every frame.
- Jitter: `cs->lastThink = time + rand() % 20` (`:914`) — deliberately de-synchronizes think phases so all AI never think on the same frame.
- Inside one think, the aifunc state loop runs **exactly one iteration** in release (`:74` — `aicast_debug.integer ? MAX_AIFUNCS : 1`), so a state transition costs one extra frame instead of risking a same-frame cascade. `MAX_AIFUNCS 15` (`game\ai_cast.h:45`) is a debug infinite-loop guard.

**Tier B — movement/physics (`AICast_StartServerFrame`)**: `ai_cast_think.c:945`, called from `G_RunFrame` (`game\g_main.c:2547`). Converts stored `cs->lastucmd` into a usercmd and runs the cast's Pmove via `trap_BotUserCommand` (`:1062-1063`).

**Tier C — perception (`AICast_SightUpdate`)**: a single global budget call `AICast_SightUpdate((int)(SIGHT_PER_SEC * elapsed/1000))` (`ai_cast_think.c:854`), `SIGHT_PER_SEC 50` (`ai_cast.h:47`) = **50 pair visibility checks per second for the entire level**, with elapsed clamped to 100ms (`:851-852`) so a hitch can't cause a sight-check flood.

## 2. THE KEY QUESTION: what RTCW stops doing for AI the player can't see

`AICast_StartServerFrame`, `ai_cast_think.c:1044-1074`. An AI's **entire movement update (usercmd → Pmove → animation timers) is skipped** unless at least one of (checked cheapest-first, PVS deliberately last, `:1049-1056`):
- high priority (alive, or died < 5s ago) AND >300ms since last move-think — a ~3Hz heartbeat so unseen AI still crawl along their paths;
- player is in a scripted camera;
- this AI can currently see the player, or the player can currently see it (timestamp equality tests — **no raycast**, just reads the vislist);
- it has nonzero velocity (mid-air/falling never freezes);
- its last usercmd has any movement/buttons (it's *trying* to move);
- `trap_InPVS(cs->bs->origin, player origin)` — "do pvs check last, since it's the most expensive to call" (`:1055-1056` comment: always allow when in PVS "otherwise bosses won't gib, and dead guys might not push away from clipped walls").

So: an idle, unseen, out-of-PVS AI costs **one timestamp compare per server frame + one decision-think every ~50-100ms (capped at 4/frame globally)** and zero physics, zero animation, zero rendering. It is *not* fully dormant — it can still hear, be informed by friends, and decide — which is why RTCW guards "wake up while offscreen" behavior for free.

Additional dormancy: trigger-spawned AI have `aiInactive = qtrue` and are **unlinked from the world entirely** (`ai_cast.c:669-672`, `ai_cast_think.c:1076-1077` unlinks inactive ents; skipped by think `:893`, by sight `ai_cast_sight.c:603,683,713`, by save `g_save.c:840`). Activation re-links after a bbox-clear check (`ai_cast.c:582-633`). Spawns are also **staggered** `FRAMETIME * ((numSpawningCast+1)/3)` to avoid command-buffer spikes (`ai_cast.c:677`).

Dead-body cost cap: after 5s dead, head-hit checking disabled (`FL_NO_HEADCHECK`, `ai_cast_think.c:587-589`); sinking corpses free the whole client slot (`trap_DropClient`, `:578-584`).

**Godot translation (RECONgame):** split each AI into `think()` (goal/perception/target selection, your existing 6-7Hz) and `move_tick()` (NavigationAgent3D update + velocity + AnimationTree). Gate `move_tick()` exactly like RTCW: run it only if `is_on_screen` (VisibleOnScreenNotifier3D on the AI root = your PVS), `velocity.length_squared() > 0`, `wants_to_move`, in-combat, or a 300ms heartbeat elapsed. When gated off, also set `AnimationTree.active = false`. Central `ThinkScheduler` autoload: ring array of agents, budget `MAX_THINKS_PER_FRAME = 3-4`, per-agent `last_think_ms`, promote to every-tick when the gate conditions hold, `+ randi() % 20` jitter on rescheduling. The single biggest lever for "frame cost scales with AI count".

## 3. Perception

**Vision = 2 cheap filters, then budgeted raycasts.** `AICast_CheckVisibility` (`game\ai_cast_sight.c:225-331`):
1. Range: `dist > attributes[ALERTNESS]` reject (`:318`) — alertness *is* view distance (soldier: 16000u ≈ unlimited; tune per rank).
2. FOV cone (`AICast_InFieldOfVision` `:69-100`), FOV widened by state: `aiStateFovScales = {1.0 relaxed, 1.5 query, 1.5 alert, 2.0 combat}` (`:53-59`); FOV forced to **270°** if they've ever fought (`:267-271`), **360°** if target was visible last check while alert+ (`:273-276`) — "aware" targets can't be circled. Eye = actual head-tag position/orientation, cached one per frame per client (`:282-305`).
3. `AICast_VisibleFromPos` (`:107-218`): up to **5 traces** — chest, feet, head, right, left — with `trap_InPVS` early-out on the first 3 and skip left/right entirely if none was in PVS (`:154-167`). Mask `MASK_AISIGHT` — "we can see anything a bullet can pass through" (`:169`). Returns on first clear trace, so common case is 1 trace.

**Amortization** (`AICast_SightUpdate` `:566-790`):
- AI→player pairs checked every frame **only until first sighting**: skip if seen last check (`:651`), skip if checked within 40+rand40 ms (`:656`) — acquisition latency bounded by reaction-time only, not by budget.
- All other pairs: global budget (50/s), resumable round-robin cursors `lastsrc/lastdest` (`:566, 673-789`), per-pair floor `SIGHT_MIN_DELAY 200`ms (`:575,725`).
- Friendly pairs re-checked only every **2000+rand1000 ms** (relaxed) or 500+rand500 (combat) (`:741-752`). Corpses checked only until sighted once (`:729-734`).

**Result caching is the perception**: everything writes into `cs->vislist[ent]` (`cast_visibility_t`, `ai_cast.h:226-241`) — `visible_timestamp`, `visible_pos`, `visible_vel`, `notvisible_timestamp`, 3 breadcrumb `chase_marker`s dropped at 1000ms intervals after losing sight (`ai_cast_sight.c:552-558`, `ai_cast.h:221-222`). Decision code (e.g. `AICast_ScanForEnemies`, `game\ai_cast_fight.c:159-330`) does **zero raycasts** — it reads timestamps via `AICast_EntityVisible` (`:337-394`).

**Reaction time is free** — timestamp math in `AICast_EntityVisible`: `reactionTime = 1000 * attributes[REACTION_TIME]`, halved if already fought this target, scaled ×0.5..1.0 inside 384u (`:359-373`). Target must have been continuously visible for `reactionTime` before it "counts". Conversely, **5000ms memory**: after losing direct sight, target treated visible 5 more seconds (`:384-390`).

**Hearing = ranges, not audio** (`AICast_AudibleEvent`, `ai_cast_fight.c:2303-2371`): each weapon has a hand-tuned sound range table (`AICast_GetWeaponSoundRange` `:1838-1891` — knife/silenced 64, pistols 700, SMGs 1000, sniper 2000, dynamite 3000), scaled by `HEARING_SCALE`, then **×`HEARING_SCALE_NOT_PVS` (0.9) if listener is outside the sound's PVS** (occluded hearing, one PVS lookup, no pathfinding). `DistanceSquared` early-out before the PVS test (`:2350-2354`). Heard events get a **random reaction delay 200+rand300 ms** (`:2367`) and just set `audibleEventTime/Org`. Near-miss bullets: `AICast_ProcessBullet` (`:2230-2296`) — impact within `INNER_DETECTION_RADIUS` (512) + PVS, or path within half that radius; ignored entirely if already in combat (`:2259`); reaction delay 100+rand200.

**Instant-combat bubble**: enemy sighted inside `INNER_DETECTION_RADIUS` 512u → immediately hostile regardless of state (`ai_cast_sight.c:402-413`).

**Info sharing**: friendlies within `AIVIS_SHARE_RANGE 384` (`ai_cast.h:219`) copy each other's whole vislist entries — including triggering the sight script/voice line once (`ai_cast_sight.c:444-527`). Dead friendlies found → `AIVIS_INSPECT` flag → investigate (`:425-435`). This is the entire "squad communication" system: no messages, just copying structs when near.

**Godot translation:** a `PerceptionServer` autoload owning `vislist[a][b]` dictionaries of timestamps. Per physics frame, spend a fixed raycast budget (start at 50/s like RTCW — it's shockingly low and it worked): AI→player pairs at high rate until first-sighted, AI↔AI at 200ms+ floors, allies at 2s. Distance + cone first, `intersect_ray` last. Reaction/memory purely from timestamps. Hearing: `emit_sound(pos, range)` → distance² test, then one `intersect_ray` to the listener as the "PVS" occlusion proxy (×0.9 range if blocked). Share vislists between squadmates within ~15m. Chase breadcrumbs (3 × 1s) give "hunt where he went" with zero pathfind queries.

## 4. Combat behaviors

**Data vs code:** all soldier personality is a 21-float table per character (`castAttributes_t`, `ai_cast.h:129-155`; `aiDefaults[]` `game\ai_cast_characters.c:50-101`). Soldier: run 220 / walk 90, FOV 90, yaw 200°/s, aim_skill .5, aim_accuracy .5, attack_skill .75, reaction .5s, attack_crouch .4, aggression .5, tactical .8, camper 0, alertness 16000, hearing 1.0 / 0.9 non-PVS, IDR 512, health 100. Elite Guard differs only in numbers. Behavior *code* is shared; character = data + optional 3 special-attack function pointers + sound-script names + AI flags. Scripts can override per-entity (`attrib` action).

**Aggression is one scalar function** (`AICast_Aggression`, `ai_cast_fight.c:1214-1282`) blending: low health (−), hit recently (−, fear decays linearly), reloading (−), distance from enemy (+), all × `attributes[AGGRESSION]`. Chase if > 0.6 (`:1300`); take cover if `aggr * situational_scale < 0.4` (`:1354`), scale ×3 when following the player (`:1333-1335` — squadmates fight, don't cower), ×0.6 when enemy's aim dot > 0.97 at me (`:1338-1348`). One number drives chase/cover/retreat.

**Cover** — two-stage, cheap-first:
1. **Crouch-in-place** (`AICast_GetTakeCoverPos`, `ai_cast_fight.c:1744-1768`): if I can hit him standing but *not* crouching (2 cached attack checks), trace with crouch-height bbox; if enemy can't see crouched-me, cover = "duck right here" (`crouchHideFlag`). No movement, no search.
2. **Hide-area BFS** (`AAS_NearestHideArea`, `botlib\be_aas_route.c:2186-2399`): Dijkstra over navmesh areas by travel time, nearest area **not visible from the enemy's area**. Cost controls: global **once per frame** (`:2204-2207`), abort at `MAX_HIDEAREA_LOOPS 3000` (`:2196`), candidate rejected by **precomputed area→area visibility table** first (`AAS_AreaVisible`, `:2347,2357`), confirming raycast only for survivors, cached per search (`visCache`, `:2358-2365`). Heuristics: never path through/toward the enemy (`:2304-2328`), +1000 penalty if another AI already occupies the area (`:2340-2344`), if currently unseen never move into his view (`:2346-2350`). Result stored in `cs->takeCoverPos`, consumed over seconds (`takeCoverTime = level.time + 2000 + rand()%4000`). Attack-position search same trick capped at **200 loops** (`AAS_FindAttackSpotWithinRange`, `:2407-2426`).

**Grenade throwing** (`AIFunc_GrenadeFlush`, `game\ai_cast_funcs.c:3690-3995`): triggered from Battle when enemy hidden 100–2000u away. **Global** cooldown `lastGrenadeFlush` — one AI in the whole level per 7s (`:4810, 4003`). Aiming = fire a *dummy* grenade entity, run `G_PredictMissile`, free it (`:3936-3942`), score the landing via `AICast_SafeMissileFire` (`ai_cast_fight.c:2044-2092`: hurts enemy? too close to me ×1.5 radius? any friendly in radius? overshot?), then **iterate pitch** across thinks (`:3967-3992`). Friendly-fire solved *before* the throw.

**Grenade avoidance/return**: live missiles broadcast danger every missile frame (`g_missile.c:570` → `AICast_CheckDangerousEntity`, `ai_cast_fight.c:2102-2201`) with gates (TACTICAL ≥ 0.1, FOV if relaxed, must know the thrower). Sets `dangerEntity/Pos/ValidTime` → every state's first check bails to `AIFunc_AvoidDanger`. Grenade near with >1.5s fuse + `AIFL_CATCH_GRENADE` + team check + **global 3s limit `level.lastGrenadeKick`** → kick-it-back (`:3143-3184`). Player aim/flamethrower also registers as danger per client frame (`g_active.c:1640-1671`).

**Aim error model** — two independent pieces:
- *Angular/positional error at think time* (`AICast_AimAtEnemy`, `ai_cast_fight.c:1481-1580`): aim at **last visible position** if occluded (`:1521-1527`); lead by `aim_skill * 0.2 * velocity` (`:1571-1573`); moving targets >256u get a sinusoidal miss term scaled by `(1-accuracy)` with **per-entity phase `(entityNum+3)%4`** (`:1566-1568`) — everyone's wobble is desynced; grenades aimed at feet <180u, lofted +12+dist/50 beyond 400u.
- *Ballistic spread at fire time* (`Bullet_Endpos`, `game\g_weapon.c:878-907`): `miss = (1 − accuracy) * AICAST_AIM_SPREAD(2048)` at 8192 trace length (`ai_cast_global.h:40`). And `accuracy` is **time-under-observation ramped** (`AICast_GetAccuracy`, `ai_cast_fight.c:1969-1996`): base `AIM_ACCURACY` ± 0.2, ramping up over `500 + 3500*(1−skillscale)` ms of continuous target visibility — the player breaking LOS *resets the AI's aim-in*. The entire skill loop of RTCW firefights, for one timestamp subtraction.
- Trigger discipline: won't fire until within 20° of ideal yaw (`ai_cast_think.c:199-208`); SMGs randomly release trigger for 100-200ms bursts (`ai_cast_fight.c:1711-1716, 1606-1626`); bolt/scoped weapons can't move-and-fire (`:1587-1599`, `:1663-1681` freezes `speedScale=0` after firing).

**Attack-line checks are cached**: `AICast_CheckAttack` memoizes per (frame, enemy, weapon, allowHitWorld) in `checkAttackCache` (`ai_cast_fight.c:817-835`); underlying `_real` (`:558-771`) does up to 7 "fuzzy" traces with an `InPVS` abort before any trace (`:720-724`).

**Pain/flinch**: `AICast_Pain` (`game\ai_cast_events.c:103-151`): escalate to ALERT minimum, record attacker as seen (getting shot reveals the shooter), neutral→enemy, fire `pain` script event with health-range matching. `pauseTime` freezes the AI while big state-change anims play (`ai_cast_fight.c:118-121`). Damage feeds fear via `lastPain` in the aggression formula.

**Squad-ish coordination** (all emergent, no squad manager): vislist sharing (§3); `leaderNum` follow with `MAX_LEADER_DIST 256` (`ai_cast.h:59`); polite avoidance — blocked AI *asks the blocker* to compute a sidestep via `AICast_GetAvoid` + `obstructingTime` (`ai_cast_think.c:1363-1526, 1535-1622`); anti-clump via the +1000 occupied-area penalty; global grenade/kick cooldowns as implicit "one guy does the special thing" tokens.

## 5. State machine shape

`char *(*aifunc)(cast_state_t *cs)` (`ai_cast.h:382`) — **one function per state, returns NULL to stay, or calls `AIFunc_XxxStart(cs)` which sets `cs->aifunc` and returns the state's name string**. ~20 states total (`ai_cast_funcs.c`: Idle 464, InspectFriendly 673, InspectBulletImpact 986, InspectAudibleEvent 1137, ChaseGoal 1576, DoorMarker 1827, BattleRoll 1918, BattleHunt 2106, BattleAmbush 2320, BattleChase 2630, AvoidDanger 3112, BattleTakeCover 3324, GrenadeFlush 3690, BattleMG42 4023, InspectBody 4195, GrenadeKick 4349, Battle 4712). Every state's preamble re-checks the same 3 interrupts in priority order — danger, door, leader too far — then its own logic. Transitions are explicit call-sites; **returned name strings feed a per-cast ring buffer** (`AICast_DBG_AddAIFunc`, `ai_cast_think.c:81`, dump last 10 on runaway `:87-89`) — the debug story is "print the last 10 state names". Separately a tiny 4-value *alertness* enum (RELAXED/QUERY/ALERT/COMBAT) orthogonal to behavior state, driving FOV, anim sets, walk-vs-run; QUERY escalates on repeat sightings: 1st query 1000ms lock-on, 2nd 500ms, 3rd instant combat (`ai_cast_fight.c:125-143`), with dedicated `AICast_QueryThink` bypassing the aifunc system (`ai_cast_think.c:1645-1702`).

**Godot translation:** `var state: Callable` + `func to_battle() -> void: state = battle; state_log.push("battle")`. Skip the graph framework; flat function-per-state + explicit `return start_x()` transitions + a 10-entry `state_log: PackedStringArray` shown in the debug overlay is *more* debuggable than a BT because the transition site is a grep-able line of code. Keep RECON's alertness tier separate from behavior state like RTCW does.

## 6. Scripting (designer control without code)

`game\ai_cast_script.c`: per-map text file `maps/<mapname>.ai` (`:353-386`). Grammar: per-character blocks of `event [param] { action args... }`. **25 events** (`scriptEvents[]` `:234-263`): spawn, playerstart, enemysight, sight, enemydead, trigger, pain (health-range match `:284-302`), death, activate, friendlysightcorpse, avoiddanger, blocked, statechange, bulletimpact, inspectbodystart/end, attacksound, painenemy… **~80 actions** (`scriptActions[]` `:137-227`): gotomarker/walktomarker/crouchtomarker, gotocast, followcast, wait, playanim, playsound, trigger, noattack/attack, selectweapon/giveweapon, alertentity, setmovetype, **accum** (8 per-cast counter buffers with test/inc branching — their entire logic system, `ai_cast.h:52`), abort_if_loadgame, savegame, attrib (override any attribute at runtime), deny, backupscript/restorescript, explicit_routing (`AIFL_EXPLICIT_ROUTING`), mount, statetype, mu_* music.
Load-bearing idea: **dynamic AI runs always; scripts are event-triggered action stacks layered on top**, with `deny`/`scriptNoAttackTime`/`scriptNoMoveTime`/`scriptNoSightTime` (`cast_script_status_t`, `ai_cast.h:286-305`) as the *only* coupling — the script suppresses or redirects the dynamic AI; `AICast_ScriptRun` executes the stack after the aifunc each think (`ai_cast_think.c:742-744`). Unclaimed events fall through to hard-coded defaults.
**Godot translation:** TOML per encounter: `[[on.enemysight]] actions = ["goto marker_12", "say contact", "accum 0 inc 1"]`. Event → array of `{action, args}` executed by a ~30-line interpreter over the existing goal system, with `deny`-style suppression timers on the agent.

## 7. Movement & animation decoupling

- Think (Tier A) only writes *intent*: elementary actions → `AICast_UpdateInput` converts to a `usercmd_t` stored in `cs->lastucmd` (`ai_cast_think.c:339-426`) with view-angle slewing capped by `YAW_SPEED` attribute ×2 in combat (`:98-158` — turn *rate* is a stat; aim error partially emerges from slow turns).
- Tier B replays `lastucmd` through the **same Pmove as the player** each (non-gated) server frame — AI think at 3-10Hz, movement integrates at 20Hz, between thinks the AI "keeps holding the same keys". **Never interpolate the brain, interpolate the *input*.**
- Movement speeds read **from animation data**: `anim->moveSpeed` of the current WALK/WALKCR/RUN anims copied into attributes every think (`ai_cast_think.c:637-655`) — no foot-slide because the anim is authoritative.
- Approach without overshoot: `AICast_SpeedScaleForDistance` (`ai_cast_funcs.c:311-349`) — a 0.2s predictive brake, no PID.
- Short-horizon prediction uses the real Pmove offline: `AICast_PredictMovement` (`ai_cast_think.c:1101-1233`) runs N dummy Pmove frames (5×0.4s in `GetAvoid`, 4×0.2s dodge-roll safety, 5×2.0s grenade rush check). Sidestep search = 5-10 yaw offsets × predict × score — rate-limited per-AI (500ms + rand) *and* one-per-level-frame (`:1259-1267`).
- New legs anim longer than current → auto `scriptNoMoveTime` freeze until it finishes (`:1068-1072`): animations gate movement, not vice versa.
- Client: cast entities excluded from extrapolation smoothing (`g_active.c:1292-1295`); PVS-culled from snapshots — client never animates unseen AI.

## 8. Distance/visibility LOD elsewhere

- Hearing degraded (not cut) out of PVS: `HEARING_SCALE_NOT_PVS 0.9`.
- Sight-check frequency LOD by relationship: hostile-unseen 40ms · pair floor 200ms · friendlies 2-3s · corpses once.
- All expensive spatial queries have global once-per-frame + loop caps: hide search (3000), attack-spot (200), avoid (1/frame), grenade flush (1 per 7s level-wide), kick (1 per 3s).
- `AICast_CheckAttack_real` aborts on `!trap_InPVS` before tracing.
- Corpse sink + client-slot free; `FL_NO_HEADCHECK` after 5s.
- Elapsed-time clamps everywhere (100ms) so hitches degrade simulation rate, never spike per-frame cost.

---

# TOP 10 GOLD (ranked by payoff for a large-combat Godot FPS)

1. **The PVS movement gate** (`ai_cast_think.c:1044-1074`): skip physics/nav/animation for any AI unseen AND still AND not trying to move, with a ~3Hz heartbeat and recently-died grace. Brain on, body off. ~30 lines in Godot.
2. **Global think budget with round-robin + jitter** (`aicast_maxthink 4`, `:874,914`): 20 AI ≠ 20× cost — constant cost, slightly staler decisions.
3. **Global perception budget + vislist timestamps** (`SIGHT_PER_SEC 50`, `ai_cast_sight.c:566-790`): all raycasts in one budgeted server; consumers read cached timestamps; reaction/memory/aim-in become timestamp arithmetic.
4. **Accuracy ramps with continuous visibility; breaking LOS resets it** (`ai_cast_fight.c:1969-1996`, `g_weapon.c:887-891`): the whole feel of fair large-volume incoming fire. Pairs with suppression.
5. **Two-stage cover: crouch-in-place first, then budgeted BFS to not-visible-from-enemy area with cached vis tests** (`:1744-1768`; `be_aas_route.c:2186-2399`): one search per frame level-wide, occupied-area penalty prevents clumping.
6. **One-function-per-state FSM returning state-name strings + last-10 ring buffer** (`ai_cast.h:382`): the debuggability pattern. Plus the separate 4-value alertness tier scaling FOV.
7. **Personality as a flat float table** (`aiDefaults`, 21 floats): VC militia vs NVA regular vs sapper = data rows, zero new code; one `Aggression()` scalar drives chase/cover/retreat.
8. **Dummy-projectile grenade simulation with iterative pitch correction + level-wide one-grenade token** (7s flush / 3s kick): pre-verified friendly-fire, convergent aiming, and the cooldown is both a perf cap and a drama pacer.
9. **Sound as ranges + occlusion-degraded hearing + random reaction delays** (weapon sound-range table, ×0.9 non-PVS, 200-500ms delays): silenced-vs-loud stealth and staggered human-looking reactions from a distance check + one ray. Near-miss awareness only for non-combat AI.
10. **Interpolate input, not intelligence** (`lastucmd` replay + anim-authoritative move speeds): think writes intent; a dumb per-tick consumer holds the keys; turn rate is a stat. The contract that makes #1 and #2 safe to apply aggressively.

Bonus: vislist *sharing* within 384u as the entire squad-comms system; 3-breadcrumb chase markers; per-frame memoized attack-line checks; trigger-spawned AI fully unlinked until activated; staggered spawning; event+action-stack designer scripting with `deny` suppression.
