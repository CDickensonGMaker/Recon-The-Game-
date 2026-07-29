# DEMO BUILD — "Firebase Night" · plan of record

**As of 2026-07-28.** Owner's first shipping goal: a shareable build that shows the
firebase assault and the combat feel. Not a vertical slice of the campaign — one
authored night, start to finish.

---

## §0. The shape, locked

Boot → mock RECON title screen → **new firebase, night, ~2 minutes before contact** →
full enemy assault → **"Thanks for playing the demo"**, win or lose.

- World is **~1/10th** the generated terrain.
- Runs ~10–15 minutes. No patrol contract, no campaign, no save.
- **Same end screen on victory and defeat.** A demo ends either way; that is what lets
  it dodge ADR-036 entirely (see §2).

---

## §1. Owner's gate — nothing below §1 starts until these pass

Owner's condition, verbatim intent: *"I can only make this demo after I confirm all the
elements of the firebase are there including losing and the AI pathfinding is good."*

1. **Firebase inventory.** Walk `fsb_main` and confirm every element the assault needs is
   present and reachable: wire, gate, bunkers, MG posts, TOC, depot, garrison spawns.
2. **Ally pathfinding in the WORLD.** `scripts/ai/nav_router.gd` was written 2026-07-28 and
   is **arena-verified only**. Allies previously had no `NavigationAgent3D` at all. Confirm
   the squad moves through the firebase without jamming.
3. **Losing resolves.** See §2 — demo-scoped, not ADR-036.
4. **The assault is legible at night.** The 80 m materialize ring is derived from the night
   sight cap; judge the pop-in in the dark, never in daylight.

## §2. "Losing" — demo-scoped, and why ADR-036 does not block it

`ADR-036 The Fall of the Firebase` is **DRAFT — BLOCKED**, its own status line: *"not
buildable today. Nine of its dependencies do not exist."* Its §6 build order needs the 80
authored sandbag destructibles wired, 3–5 installations promoted to damageable entities
(Blender re-export), and a respawn concept.

**None of that is needed here.** ADR-036 is expensive because the *campaign* must survive
losing — respawn stakes, successor state, the next tour. The demo has no campaign to
protect. Demo-losing is: *the assault overruns the position, or the player dies* → end
screen. This does not violate ADR-036; it never invokes it. **Do not let a blocked
campaign ADR hold the demo hostage — and do not quietly implement ADR-036 under its name.**

## §3. Build items

| # | Item | Notes |
|---|---|---|
| 1 | Boot to the title | `MainMenuScreen` already exists (`game_flow.gd:221`). Boot calls `start_default_operation()` instead of `show_menu()`. Roughly a one-line change. |
| 2 | Demo flow | Menu → demo scene → end screen. Reuse `DebriefScreen`'s construction pattern for the outro. |
| 3 | Small world | `WorldConfig.MAP_SIZE` is `1280.0` (`world_config.gd:9`). A demo value near 400 is one constant, and fewer chunks is also the cheapest perf win available. |
| 4 | Night start | `MissionWeather` NIGHT preset + `SimClock`; open near 19:30 so the period is already NIGHT at spawn. |
| 5 | **Release-safe assault trigger** | **Blocking.** `[J]` is behind `OS.is_debug_build()` and **will not exist in an exported build**. The demo must fire the siege off a timer at ~T+2:00, never a key and never the threat roll. |
| 6 | End screen | "Thanks for playing the demo." Same screen both outcomes. |
| 7 | Export preset | `export_presets.cfg` already targets Windows Desktop → `build/RECONgame.exe`. Add a demo entry rather than editing that one. |

## §4. Perf — the gate before it ships

`PERF_LEDGER.md` records ~34 FPS at the firebase pose on the Intel UHD floor, and its
binding rule: **no FPS delta is accepted unless the draw-call/primitive delta is measured
with it.** The ledger's finding is that this project is **call-bound, not tri-bound.**

- Measure the demo scene's draw calls first, then cut. Do not start with tri budgets.
- **Regression introduced 2026-07-28:** the MG emplacement went 8 → 16 materials (third-party
  M60 mesh), i.e. 16 draw calls per nest, two nests per firebase. Consolidating that mesh's
  8 flat-colour materials into one palette strip returns it to 9.
- The smaller `MAP_SIZE` (§3.3) is the single biggest lever and costs nothing.

## §5. Open risks that specifically threaten this demo

1. **`HOT_CAP = 12`** (`enemy_squad.gd`) is a global, **enemies-only** budget — `request_hot`
   is called from one site, `enemy_base.gd:605`, and allies never tier. In a 50-man assault
   only twelve attackers run the full combat brain; the rest can only pick `ENGAGE_TARGET`
   or `HOLD_POSITION`. **The showcase moment is exactly where the AI budget is tightest.**
   Measure before shipping; this is the top risk to "the combat feel" landing.
2. **`LIVE_CAP = 50`** (`siege_director.gd`) — raised from 18 by ruling, unmeasured.
3. **Ragdoll cap effectively removed** (`model_actor.gd`, 8 → 256) — unmeasured. Fixes
   standing corpses; frame cost unknown, and a demo's climax is mass casualties.
4. **M60 first-person viewmodel is broken** — uncancelled armory-ruler offset, rounds spawn
   ~50 m from the camera (`--mg-probe`). If the M60 is in the demo loadout it must be
   benched first. RPD/Mosin/M70/M1911 share its near-zero `hip_position` profile, unverified.
5. **`fire_*_dist.wav` are still synthesized** for every weapon. A night firefight is heard
   at range more than up close, so the distant layer carries more of the demo than usual.

## §6. Order of work — risk retired first, not easiest first

1. §1 gate: firebase inventory + ally pathfinding in the world + night legibility.
2. Measure `HOT_CAP`, `LIVE_CAP` and the ragdoll cap in a real 50-man night assault.
3. Demo-losing (§2), then the timed release-safe trigger (§3.5).
4. Demo shell: title → scene → end screen. Small `MAP_SIZE`.
5. Perf pass against draw calls, ledger rules binding.
6. Bench the M60 if it is in the loadout. Export, run from a clean checkout, ship.

## §7. Explicitly OUT of the demo

Patrol contract · campaign/save · rank progression · operations (see
[[recon-operations-decree]]) · city fighting · ADR-036's respawn stake and successor state.
