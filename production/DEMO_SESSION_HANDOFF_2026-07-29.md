# DEMO — SESSION HANDOFF, 2026-07-29

**Read first:** `production/DEMO_SHIP_BACKLOG.md` (the 24-item A–F list, still the master
tracker). This file records what changed on 7/29, what is UNVERIFIED, and the exact next moves.

**Nothing below has been playtested by the Summoner.** Every item marked *(unverified)* is a
claim about code, not about the game. A log line is a claim; the eyes are the authority.

---

## THE SHIP GATE (his words, standing)

> "More Hueys and jets in the scenes flying around. I need at least a few Huey landings and
> troops disembarking or unloading supplies. That constant movement of the choppers will really
> sell this scene. And then I need the base attack to have parts of the base blow up and for the
> VC to attempt to overrun the firebase."

Demo's job: **scope and spectacle immediately.**

| Gate clause | State |
|---|---|
| Hueys and jets constantly moving | **built, unverified** — 6-beat opening + 42s cadence, `demo_game.gd:67-80` |
| Huey landings, troops disembarking / unloading | **partial** — `lz_cycle` launches at 14s and 95s; disembark behaviour NOT confirmed |
| Parts of the base blow up | **built, unverified** — 80 parapet segments + 16 claymores are Destructibles |
| VC attempt to overrun | **OPEN** — backlog C3. Siege reaches the wire; the overrun push is not written |

---

## WHAT LANDED 7/29 (with pointers)

**Ordnance and real bullets**
- `MAX_BULLETS` 128 → **500**, plus peak/cap instrumentation that prints loudly when the budget
  actually bites — `scripts/combat/bullet_system.gd:32,42-65`. It reports the measured peak so
  the next raise is a measurement, not a guess.
- `data/weapons/aircraft_20mm.tres` — new. Never carried; exists so aircraft fire through
  `BulletSystem` instead of painting tracers at a chosen impact point.
- `Ordnance` enum gains **GUNS** and **GUNS_NAPALM** — `scripts/vehicles/cas_airplane.gd:11`.
- The strafing run — `cas_airplane.gd:55-66` (constants), `:194-206` (gun window inside the
  flyby), `:238+` (`_fire_strafe_burst`). Rounds are aimed `STRAFE_LEAD_M` (160m) **ahead of the
  aircraft**, not at the target, so the beaten path WALKS as the plane closes. That is what makes
  a strafe read as a strafe instead of a stationary explosion.
- Demo napalm beats — `demo_game.gd:100-136`. EARLY at 2:40 on a bearing away from the base
  (somebody else's war, pure spectacle); LATE at siege+60s down the throat of the assault sector,
  as `GUNS_NAPALM`. 210m out: past the ~149m authored treeline, clear of the garrison.
- `FieldDirector.authored_strike(at, ordnance, run)` — `field_director.gd:532`.

**Firebase as a real scene**
- `scenes/world/firebase_main.tscn` — inherited scene, root IS `fsb_main_v3.glb`. The site
  planner now instances the SCENE, not the raw GLB (`site_planner.gd:657`), so anything he places
  in the editor survives a rebuild.
- His two spawn markers (`spawn_bunk_01/02`) are used **exactly as placed** — no raycast, no
  code guessing. That was the root cause of the three spawn regressions
  (`game_flow.gd:137-191`).
- Destructibles wired: parapet segments `site_planner.gd:1266`, claymores `:1329`.

**Dev keys** (debug builds) — `game_flow.gd:55-64`
`[J]` siege · `[H]` three sappers at the nearest real parapet segment · **`[G]` gun-and-napalm
pass 210m out on your current bearing** · `[O]` +1h · `[I]` next period · `[U]` clock speed.
`[G]` exists because feel is tuning work and tuning work needs repetition.

**Removed:** the X hitmarker (audio tick kept) — his call.

---

## VERIFY THESE FIRST (one boot, then read the console)

These probes print every boot. They are the cheapest way to find out what actually happened.

| Print | What a bad reading means |
|---|---|
| `[NAV] ally ... no path` **count** | Was 8. Clamp raised to 12m. If it is still >0, the cause is navmesh ISLANDS, not clamping — backlog A2. **Do not raise the number again.** |
| `[FSB] one ground` | Terrain has come up through the model. Two-grounds is back. |
| `[FSB] N collider(s) floating` | Collision detached from what it guards |
| `[MODEL] N surface(s) left on DEFAULT WHITE` | The white-weapon / white-helmet class of bug |
| `[BULLETS] round budget FULL` | 500 was not enough — the message carries the measured peak |
| `[TOPO] sheet fits`, `[DRESSER]` warnings | Map and garrison dressing |

**Then look with your eyes at:** does the sky read as busy from second three · does the gun run
walk (press `[G]` facing open ground) · do the parapet segments actually come apart under sapper
charges (`[H]`) · can you walk up the dirt mound and see over the sandbags.

---

## OPEN — ranked

1. **C3 · VC overrun push.** The largest remaining gate clause. The siege reaches the wire; there
   is no written behaviour for pressing through a blown segment into the compound.
2. **Spooky's vulcan is still fake** — `spectre_gunship.gd:156-165` paints `BulletTracer` at a
   chosen impact and applies explosion damage there. It is the last aircraft gun that does not
   fire real rounds. `_fire_strafe_burst` is the pattern to copy. *(I was mid-edit here and
   stopped on his word — the file is UNTOUCHED.)*
3. **Barbwire cannot be destroyed segment-by-segment.** His requirement is both: stopped BY the
   wire, and able to destroy it. Blocked on the generator — the wire is one merged
   `bwire_card_ring` mesh, so there is nothing to adopt as a Destructible. Needs a
   `tools/gen_firebase_v3.py` change and a re-export, i.e. it is partly [B].
4. **C4** siege trigger timing · **D1** convoys set `global_position` directly, no collision, so
   none has ever moved properly · **D3** ambient war audio volleys · **A4** off-duty jobs.
5. **F2** map left-click does nothing (right-click places) · **F3** research how Arma does the
   map — he asked for this explicitly and asked that it wait.

**His Blender queue (unblocks several of the above):** 10 white materials · fire slits shootable
through the sandbags · the fighting step, now MODELLED rather than faked in terrain · `Base_Human`
removal · firebase re-export. Contract and gotchas: `production/blender/FIREBASE_BLENDER_HANDOFF.md`
(§00 export contract is the one to obey).

---

## STANDING CONSTRAINTS FOR THE NEXT SESSION

- **Do not launch the game.** He drives testing. "Stop opening the MCP." Parse-check and hand over.
- Parse-checking: `--check-only --script` **cannot judge any file that touches an autoload** —
  singletons are not registered on that path, so `combat_manager.gd` fails on `GameManager` and
  every file downstream of it fails on `CombatManager`. Both are false. Use
  `godot --headless --path . --editor --quit` and count `SCRIPT ERROR|Parse Error|Compile Error`.
  **That scan was 0 at the end of this session.**
- Open the session with his decision queue, not with building.
- ADR-023: when you replace a system, delete the old one in the same change.
