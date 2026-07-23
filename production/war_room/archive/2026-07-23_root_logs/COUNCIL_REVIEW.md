# Council Review — AAA FPS craft vs RTCW/MoHAA

2026-07-08. Three architects (Gunplay, AI/Tactics, Mission/Immersion) read the actual
code against the open-source RTCW and MoHAA lessons the project already references.

## The Arbiter's finding — one pattern across all three domains

**The foundations are real; every gap is an unbuilt LAYER, not a broken system.**
And each domain has a single keystone that, once built, lights up most of its list
because the plumbing underneath already exists and is sitting unused.

| Domain | What's already real | The keystone | What falls out of it |
|---|---|---|---|
| **Gunplay** | recoil (first-shot/climb/recovery), cadence, dice damage, falloff, 3D positional audio, enemy projectiles, sway/breath | **A one-afternoon feedback pass** (5 Small items) | prototype → MoHAA-adjacent feel |
| **Enemy AI** | utility goal-scorer, 4-tier perception, NoiseBus hearing, cover-claim broker, per-archetype tuning, navmesh pathing | **An `EnemySquad` coordinator node** | search, teamwork, fire cohesion, morale — the director's three named pillars |
| **Missions** | generate→objectives→gated exfil, LazyGroup dormant pops, SurviveWaves scripted beat, fail-forward ladder | **Detection-driven alarm + a MissionTrigger/event bus** | stealth economy, QRF, authored beats |

The recurring phrase in all three reports: *"the hooks already exist and are simply
unwired."* This is a project that built infrastructure ahead of the systems that use it.

---

## GUNPLAY — feedback is the gap, and it's cheap

Lead with the 5 Small wins; together they move feel from "prototype" to "MoHAA-adjacent" in one pass:

1. **Blood + flesh-impact FX (S)** — `weapon_holder.gd:339-342` spawns an impact puff ONLY on non-flesh hits. Flesh gets nothing in world-space. Add `GunFX.blood()` in the `if flesh:` branch. Biggest single punch win.
2. **Fire the gunshot tail (S)** — `audio_manager.gd:41,62,93` build a `WeaponsTail` bus + player and NEVER `.play()` it. Two lines gives every gun weight.
3. **Bullet-hole decals (M)** — `gun_fx.impact()` has no decal; RTCW's signature "my shots matter" touch. Pooled Decal, route through MissionScope cleanup.
4. **Hitmarker + headshot/kill differentiation (S)** — currently a text "x"; headshot is a `print()` (`weapon_holder.gd:419`). Pass `zone_name`/`killed` through `target_hit`, distinct ticks.
5. **Tracer gating (S)** — every round tracers (`weapon_holder.gd:330`). Gate to ~1-in-4 for autos; makes night tracers mean something.

Then the gameplay-identity fix:
6. **M79 as a real arc (M)** — the projectile path works for enemies (`enemy_base.gd:1263`); the player never uses it (`_fire_shot` always hitscans). Branch on `projectile_data_path`, author `m79_grenade.tres`. Rifles stay hitscan (the fake travel-time at `:349` is the right call).

Also: movement/sustained-fire spread bloom (S/M), per-weapon ADS speed (S), enemy flinch (art-bound M), first-person arms (art-bound L), surface-specific impacts (M).
**Stale-audit note:** AUDIT-05 (damage falloff) is RESOLVED — `damage_multiplier_at()` is read at `weapon_holder.gd:408`. Lethality is correctly tuned for 1-2-shot kills.

---

## ENEMY AI — the individual brain is good; there is NO squad layer

The director's bar: "patrols, tough searching, teamwork, fire cohesion — NVA determination and tactics." Grep of `scripts/enemies` for `focus_fire|overwatch|bounding|coordinat|regroup` → **zero hits.** `AIGoal.REGROUP` defined, never scored.

**The linchpin: one `EnemySquad` coordinator** (group membership already exists via `group_tag`). It assigns roles to the existing per-soldier brain — no new movement/fire code:

1. **Breadcrumb trail (S)** — do this first, standalone. `last_known_target_pos` is a single Vector3; the design doc specs a 3-crumb trail so they search *where you went, not where you are*.
2. **`EnemySquad`: shared target designation + vis/alert sharing (M)** — the keystone. One squad target → instant focus-fire.
3. **Fire cohesion (S, on #2)** — focus-fire + hold-until-contact + opening volley. Very NVA.
4. **Coordinated area sweep (L)** — assigned search sectors, expanding ring, determination gradient (NVA methodical/long, VC checks obvious spots and falls back). *This is "the tough searching mechanism."*
5. **Suppress-while-flank (M, on #2)** — goals exist (`:751-765`), never coordinated.
6. **Home-facing at spawn (S)** — enemies spawn facing world -Z; the sentry sweep aims at the wrong axis. Orient defenders toward their trail/gate. (The combat lab patches this by hand today — proof the shipped path doesn't.)
7. **Squad morale (M, on #2)** — NVA-sticky / VC-brittle, casualty cascade. `retreats_when_hurt` is real per-man; morale is still random personality.
8. **Patrol routes for all standing groups (S-M)** — `make_patrol_route` exists, used by only the 2-3 ambient patrols.
9. **Situation interrupt (S-M)** — no "grenade nearby → scatter"; wire or cut `REGROUP`.
10. **Bounding overwatch (L, on #2)** — the R62 stub, ship last.

**Verdict on the FSM:** keep it. It's already a utility scorer with hysteresis — the right bones. Don't rewrite to a behavior tree; build the two layers *around* it (squad coordinator above, thin situation-interrupt stack inside). Every item 2-10 is cheap once the coordinator exists because it *assigns* goals the soldier already executes. **The combat lab validates all of it** — spawn 3, break contact, watch the TARGET column collapse to one name and GOAL split into SUPPRESS+FLANK.

---

## MISSIONS & IMMERSION — the spine is real; it doesn't feel authored yet

**Tier 1 (four of five are Small):**
1. **Positional ambience (S→M)** — the director's actual bird complaint. `game_world.gd:184` uses TWO non-positional 2D synth loops; `jungle_loop` IS the constant chirp. The NEW `audio_manager.gd` is positional *gunfire*, not ambience — it did not touch this. Scatter `AudioStreamPlayer3D` emitters (birds in canopy, frogs near water, distant firefight), day/night sets, cut under rain.
2. **Alarm on DETECTION, not first kill (S)** — `mission_director.gd:39` flips escalation on `_on_enemy_died`, so a *silent* kill still summons the AO. Gate it on reaching `AlertTier.COMBAT` or the informer. This makes stealth an economy (RTCW §5.5).
3. **Enemy-to-enemy alert propagation (S→M)** — enemies share only via NoiseBus; a silently-dropped body or a visibly-alert buddy 5m away produces nothing. On death emit a "body sighted" stimulus; raise tier near an ALERT ally. Cheapest "world reacts to me" win.
4. **Reuse SurviveWaves as a hot-LZ exfil finale (S→M)** — the one genuinely scripted beat, hardwired to FIREBASE_DEFENSE. Instantiate a 2-wave hold on the exfil call, weighted by heat.
5. **Objective consequences (S)** — completions barely change the world; wire through `state.flags` (blow the cache → the enemy mortar team goes silent).

**Tier 2:** door-gun the insertion + contested LZ (M); **the MissionTrigger + `director.notify`/`wait_till` event bus + generator beat-stamping (L)** — the research doc's identified highest-ceiling win, none of it exists; diegetic HUD middle tier (S).

**Tier 3 missing verbs, cheap on the existing sensor framework:** stealth-until-detected (S, a bonus bit), sniper-overwatch/assassinate (S, clone PhotoObjective's range+LOS), timed-demo-with-getaway (S→M), defend-and-fall-back (M). **Escort is correctly banned** by the research — Rescue (POW joins the squad) is the built substitute.

---

## Recommended sequence (Arbiter's decree)

1. **Gunplay feedback pass** (blood, tail, decals, hitmarker, tracer) — one afternoon, transforms every second of play. Do it first; it's the cheapest joy.
2. **`EnemySquad` coordinator** (breadcrumbs first, then the node) — the director's make-or-break pillar. Highest strategic value.
3. **Detection-driven alarm + positional ambience** — fixes the stealth economy and the bird complaint together.
4. Then the MissionTrigger layer, when there's appetite for the L-effort strategic investment.

Everything above is grounded in code that already exists. This is not "rebuild"; it's "wire up and layer on."
