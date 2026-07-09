# WIRING STATUS — what's wired, stubbed, missing (2026-07-09)

Answers "how many things still need wiring before we scale." Built from a full codebase audit.
Status: ✅ wired end-to-end · 🟡 partial / placeholder · ⛔ missing.

## The spine is solid ✅
The core is genuinely connected and persistent — this is the strong foundation to scale on:
- **Mission loop**: menu → mission-select (seeded, deterministic) → briefing → world load → MissionDirector +
  MissionGenerator plan/build → objectives/sensors → mission-end → XP bank → CampaignState persistence → debrief. (`game_flow.gd`)
- **Campaign persistence**: roster, XP pool, threat level saved to `user://` (`campaign_state.gd`).
- **Squad**: 5-man roster spawn, orders (follow/hold/move/fire-toggle), MOS verbs (medic revive, point warning,
  grenadier M79, pigman, RTO fire-support), permadeath → roster refill. (`squad_system.gd`, `ally_base.gd`)
- **Fire support**: RTO-gated menu (bombs/napalm/arty/mortar/Spooky), budgets, CAS dive-bomb + **now F-4 flyby + CBU**. (`mission_director.gd`, `cas_airplane.gd`)
- **Terrain destruction**: persistent heightmap craters + vegetation clear on any explosion. (`damage_system.gd`)
- **Detection/AI**: alert tiers, NoiseBus, suppression, cover, EnemySquad coordination, goal-driven combat. (`enemy_base.gd`, `enemy_squad.gd`)
- **Skills**: 6/7 skills + 3 attributes drive real player effects (jam, spread, reload, revive, FO cooldown).
- **Gunplay**: hitzones, falloff (player/enemy/ally), hitmarker, flesh blood (**now all factions**), pain stagger (**now wired**).

## Things defined-but-not-wired 🟡 (dead code to connect — cheap wins)
| Item | State | Fix |
|---|---|---|
| `detect_ambush` skill | buyable, **zero effect** — point radius uses the `al` attribute instead | wire skill → point scan radius (task #46) |
| player `al` attribute | saved, **never read for the player** (only squad members) | a "being-noticed" HUD pip (DESIGN §4.10, task #46) |
| squad members' own `st`/`ag`/`small_arms`/`sniping` | stored, **ally combat ignores them** — only the player's stats matter | ally_base reads member stats (task #47) |
| `punji_trap.glb` | ~~model-only, no damage~~ → **WIRED tonight** (PunjiTrap actor + village placement) | ✅ done |
| `apply_stagger()` | ~~uncalled~~ → **WIRED tonight** (pain-quota on solid hits) | ✅ done |

## Placeholder visuals 🟡 (art-gated, logic works)
- Explosion FX: damage+crater+audio work, **no fireball/flash/smoke** (`grenade.gd:88` TODO).
- Fire: `FireHazard` = one emissive cylinder; a real `terrain_vfx NAPALM_FIRE` exists in terrain code but is **unwired** (task #26).
- Placeholder meshes: claymore (green box), Spooky gunship (box), smoke (purple sphere), MG nest, POW cage.
- Flesh-hit sound = placeholder (`gun_fx.gd:197`).
- No blood decals/pools yet (particles only) — plan in `research/gore_fx.md` (tasks #20/22).

## Missing systems ⛔ (real new work)
- **Ragdoll** — death = canned clip; plan ready in `research/ragdoll.md` (task #24, one shared physical-skeleton .tscn).
- **Audio/VO layer** — barks exist as on-screen TEXT only; no voice audio (tasks #41/43, `research/barks.md` TBD).
- **Rubble/collapse** — destroyed structures just vanish (task #29).
- **Coop/multiplayer** — zero networking; viable DLC (~6-10wk) per `research/coop_feasibility.md`, NOT a rewrite (task #49).
- **Province/war-map campaign** — DESIGN §2 wants a province map; current campaign is a flat threat model (M8).
- **Bible chapters** — only 05, 08(roads), 09 written; 00/01/02/03/04/06/07/10/11 still stubs.

## Verdict — how much before scaling
The **simulation spine is wired and persistent** — you can scale content on it now. Before scaling *hard*, the
highest-leverage gaps are: (1) **audio/VO** (biggest felt absence — barks are silent), (2) **character art off
placeholder capsules**, (3) the **dead skills/stats** (cheap, done/in-progress tonight), (4) **province campaign**
if the XCOM-loop vision is the target. Coop and ragdoll are self-contained additions, not blockers. Nothing in the
core loop is broken or half-connected — the risk is breadth of content + the audio layer, not structural rewiring.
