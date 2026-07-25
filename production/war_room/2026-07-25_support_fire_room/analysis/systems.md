# SYSTEMS-DESIGNER — Support Fire Test Room (audit + shell design)

**Convened 2026-07-25. Verified against code, not the brief. Pointers are file:line as of today.**

The brief inherits its picture from `DESTRUCTIBLE_JUNGLE_PLAN.md` + `war_room/analysis/dj_*`
(dated ~2026-07-2x). **Three of its load-bearing claims are now STALE.** Corrected below.

---

## 1. THE FIRE-SUPPORT ROSTER ACTUALLY CALLABLE TODAY

Source: `field_director.gd:249` (`fire_support` dict) + `:418-449` (the `request_fire_support` match).

| Key | Delivery | Airframe / gun | Code |
|-----|----------|----------------|------|
| `bombs` | Snake Eye dive-bomb | A-1 Skyraider (`SKYRAIDER_SCENE`, `field_director.gd:139`) | `_launch_cas` `:457`; `CASAirplane.Ordnance.BOMB`; blast `cas_airplane.gd:189` (220/60/`BOMB_BLAST_M`) |
| `napalm` | Napalm strip flyby | F-4 Phantom (`F4_SCENE`, `:140`) | `_launch_flyby` `:464`; `_drop_napalm_strip` `cas_airplane.gd:193`; per-drop 90/30 + `FireHazard` |
| `arty` | 105mm, 6-round sheaf | off-map gun (`ARTY_SHELL` `:257`) | `field_director.gd:427-439`; `_arty_impact` `:566` → 200/60/`ARTY_BLAST_M`, 2-of-6 craters |
| `mortar` | 81mm spot + 3-4 sheaf | off-map (`MORTAR_SHELL` `:256`) | `_run_mortar_mission` `:578`; `_mortar_impact` `:674` → 140×intensity |
| `spectre` | AC-47 gunship, 30s | `SpectreGunship.call_in` `:443` | `spectre_gunship.gd:106` Vulcan (`SPECTRE_VULCAN_KILL_M`), `:118` Bofors |
| `cbu` | Cluster flyby | F-4 (`CASAirplane.Ordnance.CBU`) | `_drop_cluster` `cas_airplane.gd:213`; bomblets 55/15 `:239` |

Ancillary RTO service: **supply drop** (`request_supply_drop` `:620`, pops on your smoke).

**Player-carried (not RTO-gated), verified live:**
- **M79 HE** — `m79.tres` fires `m79_he.tres` (150 dmg, `aoe_radius=6.0`, real crater). See §4 — the "hitscan bug" is FIXED.
- **M72 LAW** — rocket via `projectile_base` AOE (`_apply_aoe_damage` `:368`), ADR-016 250 dmg.
- **M26 frag** — `grenade.gd:99` (190 centre, 0.13 rim, 10m).
- **Claymore** — `claymore.gd:58` directional (160, 8m).
- **Satchel** — `player.gd:542` `_satchel_the_mouth`; `SapperCharge` blast (`sapper_charge.gd:53`).
- **Smoke** (key throw), **illum flare** (key 7, `player.gd:1149`).
- Enemy side: **RPG-2 / RPG-7** (`nva_rpg.tres`) — the incoming-blast case.

**Missing that RECON intends:**
- **White Phosphorus / Willy Pete** — no WP round anywhere. It is both the historical CAS/arty
  MARKING round ("mark your smoke, over") and an area incendiary. The kit has HAND smoke for the
  supply mark, but no WP marking-round fire mission and no WP shell. This is the one true content gap.
- CAS ordnance enum (`cas_airplane.gd:8`) is only BOMB/NAPALM/CBU — no general-purpose HE (Mk82),
  no rocket-pod strafe (the `LAU61/LAU68` pods sit in `collision_table.gd:49-50` unused as ordnance).
- No DUSTOFF/medevac (out of scope for a destruction bench, noted for completeness).

---

## 2. THE TEST-ROOM SHELL — and the big finding: **most of it already exists**

**`ai_stress_arena.gd` is ALREADY a fire-support test room.** `_wire_fire_support()` (`:1418-1462`)
stands up:
- `ArenaFireWorld` (`:58`) — inert `GameWorld` (no terrain build), + `ArenaFlatTerrain` (`:67`,
  `get_height_at → 0`). FieldDirector only reads `.terrain_manager/.player/.map_size/.add_child`.
- A `SquadSystem` frozen to a radio-roster holder, seeded with the `radioman`-group RTO
  (`:1444-1447`) so `_radio_check`'s 10m leash is real and the net is always up.
- A live `FieldDirector` with **all six tiers stocked to 9** (`:1457`) — the unlimited-budget debug
  grant already exists, bypassing `_grant_fire_support`. `_hunter_pool=0` so it never spawns NVA.
- A `_toast_label` (`:1465`) surfacing the RTO net's calls.
- Controls inherited from FieldDirector: **T** opens the net, **1** bombs / **2** napalm / **3** arty /
  **4** mortar / **5** spectre / **6** CBU, **Y** mortar shortcut, LMB send / RMB back-out.
- **A destructible target already blows up today**: `DestructibleFortification` (`:85-104`) registers
  as an `AgentRegistry.PROP` (`:1322/1348/1373`) and is torn out by the existing blast loop — see §3.

**What "the destruction/fire-support benchmark" wants that the arena doesn't cleanly give:** the arena
is welded to an 18v18 squad stress test. For a controlled destruction bench you want a QUIET field —
player + RTO + a grid of target trees/buildings, no firefight stealing frames or the eye.

### The minimal safe scaffolding buildable TONIGHT (low-risk commit candidate)

A thin new level that **reuses the arena's proven rig verbatim** and touches **zero destruction code**:

- `scripts/levels/support_fire_range.gd` (new, ~150 lines) — `extends Node3D`:
  - `_build_floor()` + `_build_walls()` (lift from arena `:696`/`:727`).
  - Spawn **player** + **one `AllyBase` RTO** ~5m away, added to group `radioman` (so the net is up).
  - Copy `_wire_fire_support()` **verbatim** — `ArenaFireWorld` + `ArenaFlatTerrain` + frozen
    `SquadSystem`(RTO) + `FieldDirector` stocked `{all: 9}`, `_hunter_pool=0`, toast label.
  - **Debug budget panel** = re-stamp `fire_support` to 9 each every few seconds (or on a key), so it
    never runs dry. This IS the "unlimited budget, fire at will, bypass the campaign grant."
  - **Target field**: rows of existing tree GLBs (`assets/world/vegetation/*.glb`, arena `_tree_clump`
    pattern) + a cluster of buildings via `DestructibleVehicle.create` (already sizes from
    `CollisionTable` and carves navmesh) + a line of `DestructibleFortification` segments (which
    **already get destroyed** by fire support today — the live proof the pipe works).
- `scenes/levels/support_fire_range.tscn` — root instances the script.
- `run_fire_range.bat` — Godot 4.7 headed launch of that scene (copy an existing arena `.bat`).

**Why this is safe tonight:** it instantiates only existing, tested nodes and calls the existing blast
bus. Trees and static buildings won't *break* yet — that's Phase 2 (registering them as props /
adding `take_damage`, or the spatial approach in §3). But the room BOOTS, the net works, every tier
fires, craters dig (`DamageSystem`), fortifications blow, and the fireballs/FireHazard read. It is the
scaffold every later destruction wave gets tested inside. Nothing it adds can regress the game.

**Sacrificed:** a second scene duplicating the arena's fire rig is mild fossil-law tension (two places
that stand up a FieldDirector-on-inert-world). Mitigate by extracting the ~40-line rig into a shared
static helper both call, OR by accepting the arena as the one home and instead shipping a **preset**:
boot `AIStressArena` with `us_squads_active=0, vc_squads_active=0, spawn_cover=true,
spawn_vegetation=true` — zero new destruction code, but you inherit 2220 lines of stress-test baggage.
Recommend the thin new script for a CLEAN bench; name it and the shared helper so neither reads as the
other.

---

## 3. THE EXPLOSION→WORLD ROUTING GAP — **the brief is STALE; the bus already exists**

**Claim in brief:** "`apply_explosion_damage()` walks only player/allies/enemies — STRUCTURALLY CANNOT
see world objects; a `damage_area()` must be added at every explosion site."

**FALSE as of today.** `combat_manager.gd:178-185` iterates **`AgentRegistry.props.duplicate()`** and
calls `prop.take_damage(...)` on each in radius. There is **already a single shared world blast bus**,
and it is exercised and tested — `DestructibleFortification` rides it (`ai_stress_arena.gd:85`,
registered `:1322`), and `test_sapper_assault.gd:123/133` asserts prop destruction through it. The dj
audit that the brief quotes (`dj_godot_specialist.md` citing `:133`) predates the props loop — it was
added in the 2026-07-20 sapper work.

**So the real gap is NOT the call sites — it's REGISTRATION.** Every explosion already routes through
the props loop. To make a tree/building destructible you (a) give it `take_damage` and (b) register it
as `AgentRegistry.Kind.PROP`. **No new `damage_area()` at N sites. One bus, already wired.**

The N explosion sites (for reference / to confirm none bypasses the bus): all call
`CombatManager.apply_explosion_damage`, which contains the props loop — so **all of them already hit
world props for free**:
- `grenade.gd:99` · `projectile_base.gd:376` (LAW/RPG/shell AOE) · `claymore.gd:58` ·
  `sapper_charge.gd:53` · `player.gd:547` (satchel) ·
  `cas_airplane.gd:189/203/239` (bomb/napalm/CBU) · `field_director.gd:571/679` (arty/mortar) ·
  `spectre_gunship.gd:106/118` · `helicopter.gd:168` · `squad_system.gd:374`.

**Single shared bus vs N call-sites — verdict: the bus already won.** It is strictly cleaner and it is
already the shipped design. The ONE caveat, which is a real design fork for Phase 2:
- **Discrete objects (buildings, fortifications, vehicles, MG nests):** register as props. Clean,
  cheap (dozens per AO), works with the existing radius loop TODAY.
- **Trees at MultiMesh scale (hundreds–thousands):** registering each as a Node prop is too costly and
  defeats the MultiMesh. These need a **spatial** answer (a per-cell tree registry the blast queries
  by radius — `tree_registry.gd`, designed-not-built per the brief), NOT the props array. So the bus is
  the answer for structures; trees get a parallel spatial hook the blast also calls. Keep it to those
  two, not a third router.

---

## 4. THE m79 "HITSCAN BUG" — **FIXED; the brief is stale**

`m79.tres:27` → `projectile_data_path = "res://data/projectiles/m79_he.tres"` (NOT `""`).
`m79_he.tres` exists (verified on disk, `:16` `aoe_radius=6.0`, `:12` `base_damage=150`, `:18`
`arming_distance=20.0`). The M79 fires a real arcing HE grenade with AOE + crater today. The
`model_path=""` at `m79.tres:37` is the *viewmodel* field and is irrelevant to the projectile.
**No fix needed. Do not "restore" the bug.** (Fixed 2026-07-12 per file mtime.)

### The collision_table filename footgun — **still present, but defanged**

`_SOFT_NAME_HINTS` still exists (`collision_table.gd:226`), still consumed by `_filename_guess`
(`:230`) via `is_soft` (`:216-222`). BUT it is now a **loud fallback only**: known models read from
the authored `MATERIALS` dict, and an unknown model `push_warning`s before guessing (`:220`). The
brief's specific example — a "hut"-named bunker shootable through — no longer bites: `quonset_hut` is
authored METAL/hard (`:201`), `barbwire_tangle` is authored (`:170`). The landmine is disarmed for the
current asset set; the hint list survives as a warned fallback for un-authored models. **Fossil-law
note:** it is dead-for-known-models but kept intentionally as the loud gap-catcher — that is
`UNFINISHED/guard`, not a fossil to delete. Leave it; every new destructible model must be added to
`MATERIALS` (and, Phase 2, a HP/destroy-state column).

---

## 5. THE UNCOMMITTED FILES

- **`scripts/world/mg_emplacement.gd`** (untracked, `?? mg_emplacement.gd(.uid)`): a complete
  **mannable M60 emplacement** — pintle + sandbag cover, a gunner stand, a 45° traverse arc, and an
  occupancy flag that ONE intent holds (player via `man_by_player`/`man_mg`, or a promoted AI crew via
  `man_by_ai`, `:135/:152`). It is `collision_layer=1` world cover + `nav_source`. This is the
  realization of the "top deferred feature" (mannable MG) and matches the arena's placeholder comment
  about a "placed (unmanned, DEFERRED) MG nest" (`ai_stress_arena.gd:113`). **It is NOT a fire-support
  or destruction system** — it is orthogonal. Verdict: it can sit in the test room as static cover /
  a place to man the gun, but it is NOT on the critical path for the destruction bench. Do not couple
  its review to this room. (Its own commit + probe is a separate item.)
- **`assets/us/aircraft/ac47_spooky.glb` (+ .import, +_planecamo.png, + `spooky_gunship*_wip.blend`)**:
  new **AC-47 "Spooky"** gunship art for the ALREADY-CODED `SpectreGunship` (`spectre_gunship.gd`, the
  `spectre` tier). It is a model swap for a live system, not new code. It DOES belong to the test room
  implicitly — tier 5 (`spectre`) is one of the six the room must fire — but the room works today
  regardless of which model draws. Verdict: commit the art with the room (it's the visual for the tier
  you're benching), but it introduces no risk.

---

## VERDICT

Build the thin bench tonight; leave destruction alone. The room is 90% pre-built inside
`ai_stress_arena._wire_fire_support()`.

Biggest surprise: **the "explosion cannot see world objects" gap the brief is built around no longer
exists** — `combat_manager.gd:178-185` already routes every blast through a shared `AgentRegistry.props`
bus, and fortifications blow up on it TODAY. The work is REGISTRATION (give structures `take_damage` +
register as PROP), not new call-sites. And the m79 hitscan bug is already fixed.
</content>
</invoke>
