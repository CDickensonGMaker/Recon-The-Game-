# RECONgame — ROADMAP (working sequence)

Extends `DESIGN.md §6` (approved M0–M8). This is the *living* order-of-build, folding in the
2026-07-08 campaign-vision + asset notes. Canon detail lives in `production/bible/`. Task truth lives in beads (`bd ready`).

**Where we are:** M0–M2 done (loop proven). **M3 (detection/AI) + M5 (gunplay) in active hardening** —
this morning landed mission-seed determinism, `MissionScope` cross-mission teardown, and range-based damage
falloff (player/enemy/ally). KEYSTONE beads open: detection alarm+ambience (`r6qe`), EnemySquad coordinator
(`gpvb`), gunplay feedback pass (`wbtd`), smart-enemy AI (`0623`). Audio synth bank pending (`ew4u/9qp6`).

---

## Two tracks run in parallel (never block systems on art)

- **CODE track** — no asset dependency. Can run tonight / any headless session.
- **ART track** — Blender/Godot asset work. Needs the Blender MCP connected.

---

## CODE track — near-term (asset-free, do these when Blender is down)

1. **Finish M3 detection/AI keystones** — alarm carriers + positional ambience (`r6qe`), EnemySquad
   coordinator (`gpvb`), smart patrol/search/teamwork (`0623`). *The stealth-vs-loud economy.*
2. **M5 gunplay feel** — feedback pass: blood/tracer/decals/hitmarker (`wbtd`); stoppage rolls; recoil/handling.
   Falloff ✅ done. Ballistics via pool deferred to when projectile weapons go live (`warm_pool()` is ready).
3. **Campaign DATA layer (pure code, unlocks the vision)** — `CampaignState` roster schema (Bible 05),
   persistence save/load, XP pool spend, war-state model. **100 bios** authored as a data file (no assets — batchable).
4. **Playtest bug sweep** — `e6qc` combat-lab bugs, softlocks; keep beads lean (close on fix).
5. **hi9c firebase variety** — make `stamp_firebase()` actually use its `rng` (P2, cosmetic).

## ⚠️ GATE — War Room before the campaign build

**Operation Style front door (SF / Regular Army / Marines)** changes the loop structure AND commits us to
≥3 faction model sets. Do NOT build it until a War Room signs off (Arbiter + game-designer + systems-designer
+ devils_advocate). Decide: is style a full front-door fork, or a lighter modifier on one loop? This gates M8.

## CODE track — M6/M7/M8 systems (post-gate)

6. **M6 mission generator proper** — taxonomy, 2–4 objectives, site pass, **contact deck + scripted events**
   (convoy car-bomb, suicide bomber, roaming villagers — `RECONgame-3? events bead`), intensity curve, rolls.
   Ties to BATTLE DIRECTOR epic (`ccqv`).
7. **M7 live insertion + vehicles** — Huey ride/door-gun/AA/hot-LZ; **driveable vehicles** + **manned turret
   emplacements** (vehicles bead; ties RIDE OR WALK epic `8oki`). **Barbwire hazard** = damage-on-contact obstacle.
8. **M8 campaign layer** — province map, war state, HQ tent hub UI, roster management, mission offers by region,
   Operation Style selection wired to loadout/offers. Epic `4i60` + RPG-loop epic `m177` + CAPTURE epic `iyuh`.

---

## ART track (Blender — when MCP is up)

**Characters (Bible 09):**
- **A. Fix the "chonky" base mesh** — slimmer proportions + better low-poly topology. Do this FIRST; the whole
  roster reuses the base. (bead, `4i60` child)
- **B. Modular soldier kit** — helmet / torso / arm / face swap slots keyed to roster `portrait_keys`.
- **C. Faction model sets** — SF, Regular Army, Marines (helmet/torso swaps on the slim base). Gated by the War Room.
- **D. Civilians + event actors** — roaming villagers, suicide-bomber-as-civilian for scripted events.
- **E. FP viewmodels remaining** (epic `36pk`) — rifles done (M14/Mosin/AK/M16). Left: M60/RPD (LMG hold),
  PPSh (SMG), RPG-2 (over-shoulder), shotgun+sniper (reuse semi-auto pose). Then Godot procedural feel controller.

**World/props:**
- Barbwire + turret-emplacement + driveable-vehicle models/scenes (feed CODE items 7).
- Firebase realism pass (`rudg`), more/varied bushes (`360a`).

**Sprites (parallel, DESIGN §4.9):** finish render matrix (`9xd`), consumer code, `_q` dedupe, muzzle-data wiring.

---

## Bible fill order (docs to finish)

`00_PILLARS` → `01_GAME_LOOP` → `02_GUNPLAY` → `03_AI_DETECTION` → `04_SQUAD` → `06_MISSION_GEN` →
`07_INSERT_EXFIL` → `08_WORLD_TERRAIN` → `10_UI_AUDIO` → `11_SUPPORT_FIRE`.
(`05_CAMPAIGN_ROSTER` ✅ and `09_CHARACTERS_ART` ✅ written 2026-07-08.)
