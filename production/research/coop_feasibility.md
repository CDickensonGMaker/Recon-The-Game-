# CO-OP Multiplayer Feasibility — RECONgame (Godot 4.6)

**Date:** 2026-07-09
**Scope:** 2–4 player CO-OP (not competitive). Host simulates the world, enemies, and mission; clients are additional grunts in the same squad. LAN / friend-invite / listen-server model — NOT a dedicated-server MMO.
**Verdict up front:** Reasonable as a **large post-launch / DLC-scale feature**, NOT a rewrite — *conditional* on the refactors in §3 being done first. Budget it at roughly **6–10 focused weeks** for a playable 2–4 co-op vertical slice, with the risk concentrated in one place: the game currently assumes exactly one player, expressed through autoloads and static vars.

---

## 0. Current state (verified in this codebase)

- **Zero networking.** No `@rpc`, no `MultiplayerSynchronizer`, no `MultiplayerSpawner`, no peers. Fully single-player.
- **Shooting is hitscan** (`weapon_holder.gd:315-323`, `intersect_ray` on layers world|enemies|enemy_hurtbox), with client-side cosmetic effects (tracer, muzzle flash, blood/impact) and **damage deferred by bullet-travel time** (`_resolve_hit`, favor-the-shooter). This is the *ideal* shape for netcode — see §2.
- **Mission generation is seed-deterministic** (`game_flow.gd:103` seeds global RNG per op; `MissionGenerator.plan/build` takes an explicit seed; squad roster derives from `seed_value + 12345`). This is the single biggest asset for co-op: **host and clients can generate byte-identical worlds from one shared seed**, so the network only has to carry *divergences* (who moved, who shot, who died), not the whole world.
- **The whole game is a single-process, single-screen loop** (`GameFlow` swaps one `current_screen`/`world` child at a time). There is no concept of "remote player" anywhere.
- **State lives in autoloads and static vars that survive between missions** — see `mission_scope.gd`, which exists precisely to scrub leaked singleton/static state between ops. That same design is the main obstacle to co-op.

---

## 1. Recommended architecture — Host-Authoritative Listen Server

Godot 4.6 high-level multiplayer gives us: `ENetMultiplayerPeer` (one peer hosts, others join), `MultiplayerSpawner` (host spawns a node → it replicates to clients), `MultiplayerSynchronizer` (streams a whitelisted property set from an authority to everyone), and `@rpc` annotations (one-off events; default is authority-only, i.e. server-only, which is what we want).

**Adopt a strict host-authoritative model:**

- **The host runs the entire simulation** — enemy AI, squad AI allies, fire support, mission director, damage resolution, campaign state. Clients are essentially "smart puppets": they render, they read local input, they predict their own movement, and they send intents to the host.
- **Clients own ONLY their own player body's transform + input** (client-authority on the local player via `set_multiplayer_authority(peer_id)` + `is_multiplayer_authority()` input gating). Everything else is host-authoritative.
- **Why host-authoritative and not peer-to-peer-per-entity:** RECON's whole feel is coordinated AI, suppression, detection tiers, noise propagation (`NoiseBus`), and shared mission state. One source of truth removes an entire class of desync bugs (two clients disagreeing about whether an NVA squad has spotted you). Godot's docs explicitly recommend keeping the server authoritative. The cost — input latency on the host's authority for shared events — is acceptable for a PvE co-op game where nobody is being cheated.

**Honest limitation:** Godot has **no built-in client-side prediction or lag compensation** (unlike Unity NGO / Fish-Net). For your *own* CharacterBody3D you predict locally and let the synchronizer stream your transform out (client-authority on your body hides your own latency). For host-authoritative things (enemy positions, other players), clients **interpolate** received transforms and accept that remote actors are ~1 RTT behind. For a jungle-paced tactical shooter (not a 128-tick arena), interpolation-only is fine. Favor-the-shooter hitscan (§2) papers over the rest.

**Networking topology:** listen server (host is also a player) over ENet. Add relay/Steam sockets later if you want NAT punch-through; not needed for a first slice.

---

## 2. What to sync, and how

| Data | Direction | Mechanism | Notes |
|---|---|---|---|
| **Local player transform** (pos, yaw, pitch/aim, stance: crouch/prone/lean) | client → all | `MultiplayerSynchronizer`, client authority, ~15–30 Hz + interpolation | Each player scene carries its own synchronizer. Whitelist a *small* property set. Aim/pitch needed so others see where you point. |
| **Player animation/visual state** (firing, reloading, sprint, wounded_legs/arms, downed) | client → all | synchronizer booleans OR `@rpc` for one-shots | Drives the 8-dir billboard + viewmodel of *other* players. |
| **Shooting** | client → host `@rpc` (reliable-ish); host → all `@rpc` for cosmetics | Client raycasts locally (favor-the-shooter), sends `{origin, dir, weapon_id, hit_target_id}` to host. **Host validates + applies damage** via `CombatManager.apply_bullet_damage`. Host broadcasts tracer/flash/impact so everyone sees it. | The existing `_resolve_hit` split (deferred by travel time) is perfect: client shows its own tracer instantly, host authoritatively resolves damage. |
| **Enemy state** | host → all | `MultiplayerSpawner` (host spawns enemy → replicates) + per-enemy `MultiplayerSynchronizer` for transform + a compact `state` enum (IDLE/COMBAT/etc.) + `current_hp`/alert_tier | Clients run **no** enemy brain — the `_think()`/`_execute()` loop runs host-only. Clients interpolate transform and pick animation from the synced state enum. This keeps `enemy_base.gd`'s heavy think-LOD, cover-claims, and goal FSM entirely on the host. |
| **AI squad allies** (the 5-man roster spawns) | host → all | Same as enemies (spawner + synchronizer) | See §3 — the roster/spawn logic is host-only; allies become shared NPCs everyone sees. |
| **Damage / death / hitzone results** | host → all | host `@rpc` | `take_damage` and `HealthSystem` run host-side; broadcast the resulting HP + death so clients update HUD, ragdoll/corpse, KIA. |
| **Mission events** (objective progress, sensor trips, informer, exfil bird status, insertion crash, escalation tier, toasts) | host → all | host `@rpc` on `MissionDirector` | `MissionDirector` already emits signals + `toast`; wrap the emissions in RPCs. Objectives evaluate host-only. |
| **Fire support** (mortar Y, CAS T, Spooky, smoke, claymore, flares, supply drop) | client intent → host → all | client `@rpc` "request strike at point" → host spawns the strike node + resolves `apply_explosion_damage` → broadcasts VFX | These are host-simulated nodes today; just gate the *trigger* through the host. |
| **Noise** (`NoiseBus.emit_noise`) | host-authoritative | Run noise on host; it feeds enemy perception which is host-only anyway | Client gunfire → host RPC → host emits noise. Do NOT run `NoiseBus` independently on clients or perception desyncs. |
| **Campaign/roster/XP/debrief** | host owns | host computes, `@rpc` the debrief result to clients for display | Only host writes `CampaignState`. Design decision needed: whose campaign persists? (Recommend: host's campaign is canonical; clients are "guests" this op, or each keeps their own merc in a shared roster — a design call, see §5.) |

**What NOT to sync:** the terrain/heightmap, vegetation, world layout, weather, time-of-day — all **regenerated deterministically from the shared seed** on every peer. Sync only the seed + the mission plan parameters at match start. This is the deterministic-generation payoff.

---

## 3. The biggest refactors required in THIS codebase

These are the load-bearing problems. Named by file/system, worst first.

1. **`GameManager.player` — the single-player assumption, everywhere.** (`scripts/autoload/game_manager.gd`) A single `player: Node`. Referenced ~20 times across 11 files. **Critically, enemy AI targets it directly:** `enemy_base.gd:50` (`_update_think_lod` reads `GameManager.player` for LOD distance) and 6 more uses in that file; `exfil_zone.gd`, `spooky_gunship.gd`, `lazy_group.gd`, `objective_sensor.gd`, `civilian.gd` all assume one player.
   → **Refactor:** introduce a `players: Array` (host-maintained). Every "distance to player / target the player / is player in range" must become "nearest of N players / any player." This is the single most invasive change and touches the core AI target-acquisition path. `GameManager` is also `PROCESS_MODE_ALWAYS` and owns pause — pause must become host-broadcast (you cannot pause a co-op session locally).

2. **`CombatManager` (autoload) holds the world's combat truth.** (`scripts/autoload/combat_manager.gd`) Single `player`, `active_enemies`, `active_allies`, one `ProjectilePool`, and `apply_explosion_damage` loops over "the player" + allies + enemies. In co-op this must be **host-only** for resolution, and "the player" becomes "all players." Explosion/knockback/suppression already iterate lists — extend the player case to a loop. `on_enemy_killed()` → `GameManager` kill counter must aggregate across clients.

3. **Static-var / autoload state that survives between missions — `mission_scope.gd` is the map of landmines.** The reset list names them: `MissionDirector.any_fire_menu_open`, `EnemyBase._cover_claims` (static Dictionary of world cells), `GunFX` session statics + decals, `SpriteLibrary` (shared sheet), `NavBaker`, `EnemySquad` static AABBs, `DamageSystem`/`ClearingSystem` (terrain autoloads holding craters/clearings). In co-op these must be **host-authoritative and host-reset**, and terrain-modifying ones (`DamageSystem` scars, `ClearingSystem` zones) need to **replicate to clients** or the deterministic world diverges the moment someone blows a crater. `EnemyBase._cover_claims` being a static shared broker is fine *on the host* but meaningless on clients (who run no AI).

4. **`SquadSystem` + `SquadRoster` — the AI-ally spawner is single-player-shaped.** (`scripts/squad/squad_system.gd`) `setup()` spawns 5 `AllyBase` from the roster, wires the **medic revive chain to `world.player`'s `HealthSystem`** (`_health.revive_handler = self`), reads squad orders from **local `_unhandled_input`** (F1–F4), and the medic moves to `world.player.global_position`. For co-op:
   - Orders (F1–F4) come from local input on each client → must RPC to host, and design must decide *who commands the AI* (host only? whoever is squad leader? everyone?).
   - Revive chain must target *any downed player*, not `world.player`.
   - The 5-man roster now shares slots with 2–4 humans — **design question:** do humans replace roster slots (2 humans + 3 AI) or ride alongside? Affects `SquadRoster.ensure_roster` and casualty persistence (`_on_member_died` writes to `CampaignState`).
   - Grenadier/point/bark ticks run host-only.

5. **`GameFlow` — single-screen, single-process lifecycle.** (`scripts/main/game_flow.gd`) The whole menu→select→briefing→world→debrief loop assumes one machine. Needs a lobby layer: host picks the op + seed, clients join and receive `{seed, mission_type, world_seed}`, everyone loads the same world, host spawns players at insertion. `spawn_player_at`, `_run_mission`, the loading screen, and `_on_mission_ended`/debrief all become host-orchestrated with client sync. `_teardown_world` + `MissionScope.reset()` must run coordinated (host tears down, tells clients).

6. **`MissionDirector` + objectives — host-authoritative evaluation.** Objectives (`kill_count`, `reach_zone`, `photo_objective`, `rescue`, `plant_charge`, `exfil_zone`) evaluate conditions locally today; several read `GameManager.player`. All objective evaluation must be host-only, with progress/completion RPC'd. `exfil_zone.gd`'s "bird shot down" roll and `insertion_ride`'s crash roll must be host-rolled and broadcast (they already derive from the seed, which helps).

**What does NOT need heavy refactoring (the good news):**
- Deterministic generation (`MissionGenerator`, terrain, weather, roster seed) — sync the seed, done.
- Hitscan + deferred `_resolve_hit` — already the right shape for favor-the-shooter netcode.
- The damage/dice/hitzone system — it's already function-call-based (`take_damage`), so it runs host-side unchanged; you just gate *who calls it*.
- Player scene structure — add a `MultiplayerSynchronizer` child and an authority check in the input path; the Head/Camera/WeaponHolder rig (locked per CLAUDE.md) is untouched.

---

## 4. Phased path (each phase is independently demoable)

**Phase 0 — Lobby + transport spike (1 week).** `ENetMultiplayerPeer` host/join, a minimal lobby that shares `{seed, mission_type}`, load the same `game_world.tscn` on all peers from the seed. Success = two machines standing in the *same* deterministically-generated AO with no players synced yet. Proves the deterministic-world premise.

**Phase 1 — Movement sync spike (1–1.5 weeks).** `MultiplayerSpawner` spawns one player body per peer; `MultiplayerSynchronizer` streams transform + aim + stance with client authority; `is_multiplayer_authority()` gates input so each client drives only its own body. Add interpolation on remote bodies. Success = 2–4 players walk around the same jungle and see each other's billboards aim/crouch/lean correctly. **This is the go/no-go gate** — if this feels bad, everything downstream does.

**Phase 2 — Shooting + damage (1–1.5 weeks).** Client raycasts locally (instant tracer/flash), RPCs `{origin,dir,weapon,hit_id}` to host; host validates + applies `CombatManager.apply_bullet_damage` and broadcasts cosmetics + resulting HP/death. Sync `HealthSystem`. Success = players shoot *each other's targets* (a shooting range with dummy targets) and everyone sees consistent hits/blood/kills. No enemies yet.

**Phase 3 — Enemies host-authoritative (1.5–2.5 weeks).** Enemy brain runs host-only. `MultiplayerSpawner` replicates spawned enemies; per-enemy synchronizer streams transform + `current_state` + `current_hp` + `alert_tier`. Clients interpolate + pick billboard animation from synced state; run no `_think()`. Route `NoiseBus` through host. **This is the hardest phase** — the `GameManager.player` → `players[]` retarget (§3.1) lands here, plus `_cover_claims`/`EnemySquad`/nav on host. Success = a firefight where all 4 players fight the same NVA and agree on who's dead.

**Phase 4 — Squad AI allies + fire support (1–1.5 weeks).** `SquadSystem` runs host-only, allies replicate like enemies. Orders (F1–F4) and fire-support triggers (mortar/CAS/Spooky/smoke/claymore) become client→host RPCs. Revive chain retargets to any downed player. Decide command authority (§3.4). Success = the AI fireteam + a mortar strike work with everyone watching.

**Phase 5 — Mission events + campaign + polish (1–2 weeks).** `MissionDirector`/objectives host-authoritative with RPC'd progress + toasts; insertion/exfil rolls host-side; debrief broadcast; decide campaign/roster persistence model; reconnection/host-migration policy (recommend: none for v1 — host leaves = mission ends). Success = a full op start-to-debrief in co-op.

---

## 5. Effort / risk verdict

**Verdict: Reasonable post-launch / DLC-scale feature. NOT a rewrite — but NOT small.** ~**6–10 focused weeks** to a shippable 2–4 co-op slice, front-loaded with the `GameManager.player` → `players[]` retarget and the singleton/static-state audit that `mission_scope.gd` already inventories for you.

**Why it's feasible (not a rewrite):**
- Deterministic seeded generation means the network carries *diffs*, not the world. Huge.
- Hitscan + deferred damage resolution is already the correct netcode shape.
- Combat/damage is already function-call-based (`take_damage`), trivially host-gateable.
- Godot 4.6's spawner/synchronizer/@rpc stack covers exactly this host-authoritative PvE pattern; there are real co-op-FPS tutorials and a shipped production case study (Dome Keeper retrofit co-op onto tens-of-thousands of lines of existing GDScript, presented at GodotCon 2025).

**Why it's real work (the risks / what breaks):**
- **The single-player assumption is embedded in autoloads and statics**, not localized. `GameManager.player`, `CombatManager`, and the `mission_scope.gd` static list are touched by the AI target-acquisition path, damage, terrain deformation, and mission logic. This is the multiplier on the estimate.
- **No built-in prediction/lag-comp in Godot.** You get interpolation + favor-the-shooter and live with remote actors being ~1 RTT behind. Fine for jungle-pace PvE; would be inadequate for competitive.
- **Terrain deformation** (`DamageSystem` craters, `ClearingSystem` clearings) must replicate or the deterministic world silently diverges mid-mission — easy to forget, ugly when it bites.
- **Design questions that are not code:** who commands the AI squad, do humans consume roster slots, whose campaign/XP persists, KIA/permadeath semantics across players (RECON is hardcore/Iron-Man-capable — what does a co-op KIA mean?). These need answers before Phase 4/5.
- **Pillar tension (name the sacrifice):** "The squad is the RPG" (Pillar 4) assumes *your* roster of AI grunts. Co-op turns 3 of those into humans. That either dilutes the RPG-fireteam identity or requires a design that lets human players *inhabit* roster mercs (carry their XP/wounds). Worth a War Room before committing.

**Recommendation:** Ship single-player first. Treat co-op as a **named post-launch update**, and pay down the debt early by doing refactor §3.1 (players array) and §3.2 (CombatManager) *even in single-player* (as an `Array` of one) so the eventual netcode isn't fighting the architecture. Gate the whole thing behind the Phase 1 movement-spike go/no-go before committing the full budget.

---

*Sources consulted:* Godot official docs — [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html), [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html), [Scene Replication blog](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/), [RPC syntax/channels](https://godotengine.org/article/multiplayer-changes-godot-4-0-report-2/); [StraySpark — authoritative server](https://www.strayspark.studio/blog/godot-4-multiplayer-networking-authoritative-server); [Ziva — best practices & benchmarks](https://ziva.sh/blogs/godot-multiplayer); [Generalist Programmer — 2026 co-op tutorial](https://generalistprogrammer.com/tutorials/godot-4-multiplayer-tutorial). Dome Keeper co-op retrofit case study (GodotCon 2025).
