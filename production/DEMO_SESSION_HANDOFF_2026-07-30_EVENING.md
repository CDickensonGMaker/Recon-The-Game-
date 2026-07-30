# DEMO — SESSION HANDOFF, 2026-07-30 EVENING

**Nothing below has been playtested.** A log line is a claim; the eyes are the authority
(ADR-015). Supersedes nothing — it ADDS to `DEMO_SESSION_HANDOFF_2026-07-30.md`.

**STEP ONE, BEFORE ANY JUDGEMENT: open the project in Godot 4.7 so it reimports.**
`WorldWeapon` and `MeleeVerb` are new `class_name`s. `--check-only` cannot see them until the
editor rescans, and `anim_library.glb` was re-exported (112 → 124 clips).
*(I hand-registered both classes in `.godot/global_script_class_cache.cfg` — gitignored, local
only — purely so I could type-check. The editor will rewrite that file; nothing depends on it.)*

---

## THE SUMMONER'S RULINGS THIS SESSION

1. **Huey/artillery staged scenes get HARVESTED into `anim_library.glb`**, not played as baked
   set-pieces.
2. **The knife gets the full melee verb + silent rear takedown.**
3. **Bodies give intel and NOTHING else.** The random weapon/mag/grenade loot is deleted.
4. **Skip the Huey load/unload clips** — *"i need to fix the loading and unloading huey
   animations more"*. `BOARD_CLIPS` stays empty. **The casualty carriers and box carriers were
   good.**
5. He is authoring the FP arm models for **radio phone, claymore, grenades, bandage, pistols and
   knife** in another window. **`fp_arms_rifle.blend` was NOT opened after he said so.**

---

## 1. SAPPERS NOW BREAK THE REAL FIREBASE

**No Blender work was needed and none was done.** `Destructible` (`scripts/world/destructible.gd`)
hides whatever child meshes it holds; `destroyed_mesh` is optional (`:21`). Every kind asked for
already ships inside `fsb_main_v3.glb`.

- **One shared lifter**, `FireSupportBench.lift_meshes()` + `.spawn_lifted()`
  (`scripts/levels/fire_support_bench.gd`), driven by `TARGET_KINDS`. Both benches use it.
- **`sapper_room` now stands all five kinds** in one rank: 4 parapet · 2 sandbag stack ·
  2 fighting bunker · 1 MG bunker · 1 watchtower · 4 wire.
- **The arena's three stand-in builders are DELETED** (ADR-023) — the grey `BoxMesh`,
  `barbwire_tangle.glb` and `structures/bunker.glb` are referenced by no code. This was the
  2026-07-29 complaint.
- **The world can be broken now too.** `site_planner._wire_structure_destructibles()` sweeps the
  GLB by mesh-name prefix and wires **23 more structures** (7 fighting bunkers, 3 MG bunkers,
  3 sleeping bunkers, 4 towers, 6 sandbag stacks) on top of the manifest's 80 parapet segments.
  Bunkers and towers had **never been destructible anywhere in the shipped game**.

**Three measured defects fixed on the way:**
- **The bench's wire was a 230-metre wall.** `WIRE_MESH_PREFIX = "bwire_card"` matched exactly one
  node — `bwire_card_ring`, a single merged mesh measuring **230.11 × 4.12 × 169.39 m** — and
  `_adopt()` built a `BoxShape3D` from that AABB on collision layer 1, 45 m in front of the player.
  It now lifts the single card from `assets/us/props/emplacements/barbwire_card.glb` (2.73 × 0.93 m).
- **Large structures were spared by blasts that engulfed them.** `combat_manager.gd:176-185`
  damages props on a pure radius test against `global_position` — no LOS, no bounds. A 9.6 m tower
  keyed off its foot survives. Both the lifter and the world wiring now seat the `Destructible` at
  the mesh's **AABB centre**.
- **`game_flow._dev_sapper_run()` (`[H]`) only ever aimed at `kind == "sandbag_wall"`** and used
  `is_instance_valid` as its liveness test — but `_do_destroy` never frees the node, so a blown
  wall stayed a valid target forever. Now any standing `Destructible`, tested with `is_destroyed()`.
  The bench readout and `[T]` had the same bug and are fixed.

**HP by kind** (satchel 250 at centre / 70 at the 14 m edge; parapet 140 is the datum):
sandbag_wall 140 · sandbag_stack 90 · wire 60 · bunker 260 · tower 180. **Tune by eye.**

**Still true and deliberate:** the wire is one merged ring and `nav_baker.gd:16-18` never re-bakes
on destroy, so the gate remains the assault lane (backlog C3b).

---

## 2. AI ANIMATIONS THAT FIT WHAT MEN ARE DOING

**VC camp men had no role animation at all.** `camp_role` (`enemy_base.gd:139`) is written by
`CampDirector` every sim-hour and was read by **nothing** but a debug print. The cook walked to the
fire and played the standing rifle idle. New `EnemyBase._play_camp_role()` mirrors the US side's
`Civilian._play_garrison`: cook → `idle_crouching`, rest → `sitting`, talk → `idle_unarmed_4`,
sleep → `laying_breathless`. Gated on being AT the station, still, unalerted, no target.
`guard` and `patrol` are deliberately absent — those men hold the armed poses.

**Nobody had ever manned a mortar.** `MortarPit.claim()` had **zero callers**. The second
`gun_crew` man — who previously fell back to standing in the open holding an M60 — now takes a
station (`GarrisonDefender._claim_mortar_station`), keeps his rifle, and has his HOLD order
re-issued onto the station marker. `stand_down()` releases it, or three nights fill every pit with
ghosts.

**Five staged cover clips were never synced.** `cover_wall_lean_idle`, `cover_peek`,
`cover_kneel_brace`, `cover_reposition`, `cover_slice_pie` sat in
`assets/shared/cover_clips_staging.blend`. Now in the library and at the head of
`COVER_HOLD_CLIPS` / `COVER_PEEK_CLIPS`. **You have not eye-passed these** — the art log asks for
that, and `play_first()` falls back to the old crouches if you want them out.

**The "crouch 10 m early" complaint is ALREADY FIXED and I did not touch it.**
`CombatPosture.COVER_CROUCH_RANGE` is 3.0 and the class docstring records the fix. Your report
predates it.

**Two silent lies made loud/correct:** `SpriteStateMap.model_clip_for()` defaulted to
`rifle_aiming_idle`, **a clip not in the library** (it survived only via `MODEL_ALIASES`) — now
`idle_aiming`. And `ModelActor` now warns ONCE per missing weapon family: `mg`, `bolt`, `launcher`
and `pistol` have **no clips at all**, so the RPD gunner and RPG man hold their weapons like rifles.
That is your authoring queue; the log now names it instead of substituting quietly.

**The quartermaster carries crates.** `cargo_carry` / `cargo_unload_stack` had zero callers.

---

## 3. THE KNIFE, PICK UP / DROP, AND WHAT A BODY GIVES

**`scripts/combat/melee_verb.gd`** — one verb, two outcomes. Reach 1.9 m, 60° arc, 0.75 s cooldown.
A stab from the front does **27** (the ADR-016 base round — the blade invents no number). A stab
from **behind an unalerted man** is expressed as the **HEAD** zone, which ADR-016 already rules
fatal — so this file states no lethality of its own (ADR-003, one grammar). "Unaware" is the
existing `AlertTier` ≤ SUSPICIOUS **and** no current target. **A stab emits nothing on the
NoiseBus; a rifle shot does — that is the whole mechanic.**

**Slot 5 exists.** `Enums.SlotType.MELEE`, `EquipmentManager.SLOT_COUNT = 5`, wheel cycles all
five, HUD names it. There is no number key free (5 is `throw_smoke`), so the knife is reached on
the wheel — and **`[K]` stabs from any slot**, because reaching for a slot is exactly the
half-second a silent takedown does not have. `[K] SILENT TAKEDOWN` appears on the prompt line when
it would land, using the same tests as the strike so the prompt cannot lie.

**Pick up and drop.** New `scripts/props/world_weapon.gd`. `[L]` drops your primary where you
stand; `[F] PICK UP <GUN>` takes one and drops what you were holding, so a trade is always
reversible. **A dead man now leaves his weapon on the ground** (`EnemyBase._drop_carried_weapon`,
600 s clock so the gun outlives the 45 s corpse). Empty hands are now a real state —
`_fire_shot()` gained a null guard, because everything below it dereferenced `current_weapon`.

**Bodies give intel and nothing else.** The `randf()` at `player.gd:776-804` — 20 % their weapon
(silently overwriting your primary, old gun destroyed), 40 % a magazine, 20 % a grenade — is
**deleted**. Searching a man is not a slot machine. *(The ALLY corpse branch still yields 2 mags +
a frag; that is deterministic, not a roll, so it is left alone — say the word if you want it gone.)*

**The intel piece already existed.** `CampaignState.add_intel` → `lifetime_intel` → a threshold
rolled at `randi_range(20, 30)` → `FieldDirector.try_intel_stash()`. **The only gap was that it
granted 2 marks and BOTH were real camps.** Now **3 marks, exactly 1 real, 2 decoys** at 260–620 m,
seeded from the real camp's position (ADR-010 — a reload cannot reroll which one was true) and
shuffled so the true one is not always drawn first. Toast:
`CAPTURED DOCUMENTS - 3 POSSIBLE POSITIONS MARKED (DATE UNKNOWN)`.

---

## 4. THE NEW ANIMATIONS — WHAT LANDED AND WHAT DID NOT

`anim_library.glb`: **112 → 124 clips, zero lost** (diffed against a pre-change copy).
New tool: `tools/sync_clips_into_library.py` (append named actions from any .blend; refuses to save
if it would lose one; `--bones-only` strips object curves).

**HARVESTED — mortar crew** (`mortar_gunner`, `mortar_dropper`, `mortar_runner`) and **howitzer
crew** (`gun_gunner`, `gun_agunner`, `gun_loader`, `gun_ammo_bearer`). Each carried 287 bone curves
— real body animation — plus **6 object curves that are the man's PLACEMENT in the staging scene**.
Those were stripped; keeping them would teleport every carrier of the clip to the staging spot.
The mortar clips are wired: `AllyBase._play_crew_station()` plays them when a crewman is at his
station.

**NOT HARVESTED — the Huey embark, per your ruling, and here is the measured reason:**
the six passengers in `huey_embark_staging.blend` carry **5 fcurves each, all object
location/rotation and a constraint — ZERO bone channels.** Their bodies come from NLA strips of
clips the library already has (`walk_crouching_forward` → `sitting`). **There was never a boarding
body animation to harvest**, which is exactly why it does not read right. `BOARD_CLIPS` stays
empty and extraction still teleports men into seats.

**Corrected on contact (the no-drift law):** `mortar_pit.gd`'s header cited a `mocap-toolkit/` path
**outside this repo** as its source of truth.

---

## 5. BASE NPCs AND ARRIVALS — ALREADY BUILT, NEEDS RUNNING

`HeliLift` is complete and deliberate: mission decided at dispatch, men spawned before the flight
and pulled out of `firebase_garrison` while airborne so `place_for_current_hour` cannot teleport
them mid-flight, added back and promoted on landing. Arrivals become ordinary garrison
**Civilians** — the header records why an `AllyBase` would be a second path against ADR-023.
**It has never been run.** Reimport, then read `[LIFT]` lines.

---

## VERIFY (one boot each, then your eyes)

| Run | What answers |
|---|---|
| `scenes/levels/sapper_room.tscn` | `[SAPPER-ROOM] targets on the bus: 4 sandbag_wall, 2 sandbag_stack, ...` then watch **each of the five kinds** swap to rubble. `[T]` blows one as a reference. |
| `scenes/levels/ai_stress_arena.tscn` | the fort line is firebase art now, not grey boxes; a watchtower stands behind it |
| the demo | satchel or arty a **bunker** and a **watchtower** — impossible in every build before this |
| observer (`O I \ [ ] - = 0`) | a VC camp across a day: does the cook cook, the sleeper sleep |
| kill a man | his rifle on the ground · `[F]` takes it · `[L]` drops yours · the body gives **only** intel |
| loot to the threshold | `[M]` shows **three** circles, one real |
| any firefight | `[MODEL] no '__mg' weapon-family clips...` naming the art gap |

**Suite:** `test_fossils`, `test_destructible`, `test_flat_damage`, `test_viewmodel_contract`,
`test_field_item_hud` must stay green. **Reimport before trusting any red.** I did not run the
suite — that is yours.

## OWED
- **The FP hand models are yours and in progress** (radio phone, claymore, grenades, bandage,
  pistols, knife). My side is done: `tools/viewmodel_manifest.json` has an **`items`** section for
  all five, and `validate_viewmodel_glb.py` now polices non-gun items (own root key, own markers,
  no timer sync). **The object names in those entries are PLACEHOLDERS — correct them to whatever
  your rigs ship.** The one thing that will bite you: **`weapon_holder.gd:929,937` ask for the
  literal strings `rifle_idle` and `charge_handle`**, so keep `rifle_idle` as the idle clip name
  even on a knife, or it plays nothing.
- **Pre-existing validator failures, untouched by this session** and matching the known dirty list:
  m60 markers severed at ruler coords, `ithaca`/`rpg2` stale 2026-07-11 exports with only
  `rifle_idle`, `m72_law`/`rpg7` never exported. **Mosin PASSES and was not touched.**
- `[K]` and `[L]` were the only letters free in the real game (J/O/I/U are `game_flow` debug keys).
  `[K]` also kills the wave in the arena/sapper benches — a bench-only overlap.
- Nothing is committed. `assets/shared/anim_library.{blend,glb}` are modified; a pre-change copy of
  both is in the session scratchpad if you want to A/B the export.
