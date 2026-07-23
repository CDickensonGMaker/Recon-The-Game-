# RECON

**A hardcore Vietnam War open patrol simulator.** You are a line grunt, not an operator. You boot
seated at a firebase, walk out the wire gate into a procedurally seeded province, and try to come
back with your squad.

![Engine](https://img.shields.io/badge/engine-Godot%204.7%20stable-478cbf)
![Language](https://img.shields.io/badge/language-GDScript%20(strict%20typed)-355570)
![Renderer](https://img.shields.io/badge/renderer-Forward%2B-4a5)
![Mode](https://img.shields.io/badge/mode-single--player-777)
![Status](https://img.shields.io/badge/status-pre--alpha-orange)
![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red)

---

## What it is

One operation seed produces a populated area of operations stamped around the firebase — villages,
enemy camps, trails, paddies, ambient ecology — and you patrol it. There is no briefing screen, no
objective counter, and no exfil step: `"PATROL"` is the only mission type the generator produces
(`scripts/missions/mission_generator.gd`).

Arma/OFP sandbox bones. SOCOM, Vietcong and Men of Valor flavor. Hell Let Loose lethality. The
RECON tabletop RPG (1982) as the numbers backbone. PSX-era low-poly 3D throughout — the look of a
lost 2002 tactical shooter, not photorealism.

The goal is not to win Vietnam. It is to survive a patrol, bring people home, and feel it when you
don't.

**What it is not:** not an XP-and-unlock shooter, not crafting or base-building, not a linear
scripted campaign, not multiplayer, not a cutscene game.

## Design pillars

Every decision is tested against these five. They are canon
(`production/bible/BIBLE.md:62-90`).

1. **Believable firefights** — AI that fights like soldiers *and* weapons that kill like weapons,
   neither subordinate to the other. Death comes from the situation — ambush asymmetry, exposure,
   volume of fire — never from bullet sponges.
2. **Atmosphere** — dense jungle, weather, night, audio. A war is happening around you whether or
   not you are in it.
3. **Freedom** — open AO, any route, any order, loud or quiet. Stealth is an economy, never a gate.
   Nothing is on rails.
4. **The squad is the RPG, and you are in it, not above it** — named persistent teammates with MOS
   roles who improve, get wounded, rotate home, and die for real. You suggest and call; the squad
   holds its own intent.
5. **Fail forward** — detection escalates, failure mutates, a dead mission generates the next
   story. Never reload-and-memorize.

## What is built

*As of 2026-07-23.*

- **Squad AI** — goal-driven fireteam (`ENGAGE_TARGET`, `SEEK_COVER`, `FLANK_TARGET`, `ADVANCE`,
  `RETREAT`), separated think/execute at ~6.7 Hz, shared combat posture, suppression, cover
  arrival stagger, squad break at ~45% strength.
- **Deterministic damage** — flat base damage × hitzone multiplier, no dice, no rolls
  (ADR-016). Head is fatal, torso ×2.5, gut ×2.25 plus bleed, limb ×1.0. Guarded by
  `tests/test_flat_damage.tscn`.
- **The living world** — a simulation clock drives civilian schedules, village households, road
  traffic and convoys, a US garrison inside the wire, ambient friendly patrols, air traffic, and
  dynamic world events that can reach the player.
- **Fire support** — the RTO carries the net. CAS and mortar fire missions with real warheads and
  a footprint you place first; lose him and you lose the net.
- **Destructible terrain** — grenades, mortars, bombs and satchels crater the ground for real, and
  the change propagates to the nav grid, the water map and the AI's concealment model.
- **Vegetation and concealment** — jungle is concealment, not cover; rounds pass through leaves.
  One terrain classifier feeds both what you see and what the AI believes it can see.
- **Persistence** — soldiers are named, improve silently through experience, and are gone for good
  when killed. Weapon condition and fouling carry between patrols.

## Running it

**Godot 4.7 stable only.** An older editor silently rewrites `project.godot` and can corrupt the
import cache. This is not a preference.

```bash
git lfs install          # assets/us/characters/us_base_v3.blend rides in LFS
git clone https://github.com/CDickensonGMaker/Recon-The-Game-.git
cd Recon-The-Game-
```

Open the folder in Godot 4.7 and run. Main scene is `scenes/main/main.tscn`.

### Development benches

Standalone scenes for tuning work that no automated test can do. Each `.bat` at the repo root
launches one directly — edit the Godot path inside if yours differs.

| Bench | What it is for |
|---|---|
| `night_jungle_bench.bat` | Dense night jungle firefight with the live profiling overlay — CPU/GPU split, draw calls, per-system buckets, spike catcher |
| `gun_range.bat` | Every gun in the armory against docile targets at 25–500m; hitzone and bullet-drop views |
| `patrol_lab.bat` | God's-eye view of VC patrols running the real `EnemyBase` / `EnemySquad` code, not a fake sim |
| `sight_lab.bat` | Calibration bench — stand a man at exactly the distance the AI is *told* it can see from. If you can see him, the art is lying |
| `viewmodel_editor.bat` | Tune first-person weapon and arm positions, saving straight into `data/weapons/*.tres` |
| `hitzone_editor.bat` | Bone-synced hitboxes overlaid on any character through any animation; saves per-unit overrides |
| `grunt_viewer.bat` | Spin a fully rigged grunt, pick an animation, lock a role, randomize appearance |

## Testing

```powershell
.\run_all_tests.ps1
```

Headless Godot probe suite. Two of the probes enforce project law rather than behavior:

- **`tests/test_fossils.tscn`** — dead code that still reads as live is treated as a build
  failure. Existing fossils are grandfathered in `tests/fossil_baseline.json` under a ceiling that
  can only ratchet down. A new fossil fails the build (ADR-023).
- **`tools/probe_doc_pointers.py`** — flags any document asserting the state of the code without
  citing a `file:line` or carrying a date banner.

## Layout

```
RECONgame/
├── scripts/        GDScript — player, enemies, AI, missions, combat, autoloads
├── scenes/         Godot scenes — levels, characters, weapons, UI, tools
├── assets/         Models, textures, audio, animations (faction-partitioned)
├── data/           Resource definitions — weapons, enemies, units (.tres)
├── terrain/        Terrain engine — heightmap, hydrology, destruction, clearing
├── tests/          Headless probe suite
├── tools/          Blender pipeline, probes, benches
└── production/     Design canon, ADRs, art logs, war-room records
```

## Documentation

Documents belong to exactly one class — **CANON**, **LOG**, or **DEAD** (ADR-014). Canon is
amended only by explicit decision, never by drift. If code and canon disagree, one of them is
wrong and gets resolved, not quietly reconciled.

| Document | Class | What it holds |
|---|---|---|
| [`production/GAME_GUIDE.md`](production/GAME_GUIDE.md) | CANON | The document of record. Wins against anything that contradicts it |
| [`production/adr/`](production/adr/) | CANON | The architecture decision records — every decision, with its evidence |
| [`production/bible/`](production/bible/) | CANON | Per-system canon detail |
| [`DESIGN.md`](DESIGN.md) | CANON | Founding vision — pitch, setting, tone, core fantasy |
| [`PLAYER_MANUAL.md`](PLAYER_MANUAL.md) | CANON | Field manual and the input map of record |
| [`production/PERF_LEDGER.md`](production/PERF_LEDGER.md) | LOG | Measured performance history |
| [`production/ART_Track_Log.md`](production/ART_Track_Log.md) | LOG | Art, weapons, animation and structure work list |
| [`CLAUDE.md`](CLAUDE.md) | — | Session law and coding patterns for AI-assisted development |

Decisions of record worth reading first: **ADR-016** (flat damage grammar), **ADR-023** (the fossil
law), **ADR-026** (PS2 graphics budget), **ADR-028** (one world-build path), **ADR-029** (the open
patrol simulator).

## Status

Pre-alpha, single developer, in active daily development. There are no tagged releases and no
public build. See [CHANGELOG.md](CHANGELOG.md) for the development history.

## License

All rights reserved. See [LICENSE](LICENSE). The source is public for visibility; it is not
licensed for reuse, redistribution, or derivative works.
