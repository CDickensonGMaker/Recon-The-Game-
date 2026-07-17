# LEAD PROGRAMMER — v3 grunt usage, random spawner, ModelActor animation wiring

## 1. Is `us_grunt_v3` already the default allied model? Where is it hardcoded vs. overridden by MOS variants?

Yes and no.

- **Default hardcode:** `AllyBase` ships with `sprite_unit = "us_grunt_v3"` (`ally_base.gd:154`). When `AllyBase.spawn_ally()` runs, `_ready()` fires before `SquadSystem` has assigned an MOS, so the very first visual build (`ally_base.gd:169` → `_setup_visual()`) uses `us_grunt_v3`.
- **MOS override:** `SquadSystem.setup()` (`squad_system.gd:27`) builds the squad from the persistent roster and then, for each member, looks up `MOS_BODY` (`squad_system.gd:59-67`). It calls `ally.set_sprite(str(body.unit), str(body.weapon))` (`squad_system.gd:46`), which tears down the v3 actor and rebuilds it with the MOS-specific body (`ally_base.gd:211-223`).

So `us_grunt_v3` is the *fallback* default, but in normal squad play every one of the five men is immediately replaced by a deterministic MOS body (`us_grunt_pointman`, `us_grunt_rto`, `us_medic`, `us_grunt_mg`, `us_grunt_grenadier`, `us_grunt_marksman`, or `us_grunt_rifleman`). Only a roster entry whose MOS is not in `MOS_BODY` would stay on `us_grunt_v3`.

## 2. How does `SquadSystem` currently spawn allies? Is it random or deterministic?

Deterministic by role.

- The roster is generated from a seeded RNG (`squad_system.gd:30`: `SquadRoster.ensure_roster(int(director.state.seed_value) + 12345)`). Names, attributes, and skills are random *per seed* but fixed for the campaign.
- The five spawn positions are a deterministic circle (`squad_system.gd:33-34`).
- The body is chosen from `MOS_BODY` by `member.mos` (`squad_system.gd:39-46`). There is no random selection of body variant.
- The only randomness at spawn is internal to `AllyBase`: the follow-slot offset and the courage/skill personality spectrum (`ally_base.gd:161-165`).

Therefore the current spawner produces the same five role-shaped bodies every time for the same roster seed. It is not a "grunt random spawner" yet.

## 3. What is the "character manager" in this codebase? Does it already link the shared `anim_library.glb`?

There is **no class literally named `CharacterManager`**. The Summoner is almost certainly referring to the combination of `ModelActor` (the rigged-character loader/playback manager) and `SpriteStateMap` (the intent-to-clip resolver). Together they are what tie every model to real animations.

`ModelActor` already links the shared `anim_library.glb` automatically:

- `ANIM_LIBRARY_PATH` is hardcoded to `res://assets/shared/anim_library.glb` (`model_actor.gd:160`).
- `ModelActor.setup()` calls `_merge_shared_library()` (`model_actor.gd:102`, `187-218`).
- `_merge_shared_library()` loads the library once, then iterates every clip in it and adds any clip the character GLB does not already have (`model_actor.gd:212-215`).
- For mesh-only exports that have a `PSXRig/Skeleton3D` but no `AnimationPlayer`, it creates one and points `root_node = NodePath("..")` so the library tracks resolve correctly (`model_actor.gd:201-204`).

In short, **any unit that goes through `ModelActor.setup()` gets the shared animation bank merged in**, provided the GLB follows the `PSXRig` naming contract. `SpriteStateMap` then maps AI intent to a clip name (`model_clip_for`) and `ModelActor.play()` resolves aliases if a specific clip is missing.

## 4. Minimal code changes to make a random grunt variant spawner that still respects MOS gear/weapons

The cleanest minimal change is to keep MOS as the authority for **weapon and kit**, but randomize the **grunt body** within the set of GLBs that carry that weapon.

Recommended steps (no new class needed):

1. **In `SquadSystem`, replace the single `body.unit` mapping with a body pool keyed by weapon.** For example, every MOS whose weapon is `m16a1` (RIFLEMAN, POINTMAN, RTO, MEDIC) would draw from a pool that includes `us_grunt_v3` plus the existing M16 bodies (`us_grunt_rifleman`, `us_grunt_pointman`, `us_grunt_rto`, `us_medic`). Weapon-specific roles would keep a one-element pool: MG → `us_grunt_mg` (`m60`), GRENADIER → `us_grunt_grenadier` (`m79`), MARKSMAN → `us_grunt_marksman` (`m70`). This preserves the visual weapon in the model.
2. **In `SquadSystem.setup()`,** after resolving the MOS weapon, pick a random body from the pool instead of taking `body.unit` directly, then call `ally.set_sprite(random_body, mos_weapon)` exactly as today (`squad_system.gd:46`).
3. **Keep the MG fire-rate bonus** (`squad_system.gd:42-43`) — it is keyed on MOS, not body, so it stays correct.
4. **For the RTO specifically,** either leave him locked to `us_grunt_rto` so the PRC-25 is always visible (the radio is a gameplay-critical visual per `ModelActor.CARRIES_RADIO`, `model_actor.gd:279`), or wire the already-built `GruntDresser` (`scripts/visuals/grunt_dresser.gd`) to toggle radio gear on after random body selection. `GruntDresser` is currently complete but has **zero callers**; using it would also unlock face/helmet variety. However, because MG, grenadier, and marksman bodies carry visibly different weapons, a pure "any body for any MOS" randomizer would produce men holding the wrong gun. Weapon-pooled randomness avoids that.
5. **Keep `AllyBase.sprite_unit = "us_grunt_v3"`** as the fallback (`ally_base.gd:154`) so any non-squad ally spawn still defaults to v3.
6. **Optional consistency:** `scripts/levels/gore_dummy.gd:15` also hardcodes `unit_id = "us_grunt_v3"`. If the Summoner wants "v3 grunts are the US allies" to be universal, that export could be left alone (it is a dev/test prop) or repointed to the new rifleman default.

This approach requires editing only `SquadSystem` and possibly invoking `GruntDresser` from `AllyBase._setup_visual()`; it does not touch `ModelActor`, `SpriteStateMap`, or the GLB export pipeline.

## 5. Gaps where models would T-pose or fail to load animations

Even though `ModelActor` is designed to link the shared library, several failure modes remain:

- **Missing `anim_library.glb`:** `_load_shared_library()` warns and returns `null` (`model_actor.gd:169-171`). Mesh-only characters then have no clips and will T-pose.
- **Broken `PSXRig` contract:** `_merge_shared_library()` checks for `PSXRig/Skeleton3D` and silently skips the merge if it is not found (`model_actor.gd:194-195`). The model will instantiate but no library tracks resolve, producing a frozen T-pose. Any new grunt GLB that exports with a different armature name will hit this.
- **No skeleton at all:** If the GLB has no `Skeleton3D`, `_merge_shared_library()` returns early (`model_actor.gd:197-198`) and no `AnimationPlayer` is created. `_setup_visual()` will still play a clip (`ally_base.gd:183`), `play()` returns `false`, and the model stands frozen.
- **Missing or mismatched clips with no alias:** `ModelActor.play()` returns `false` when neither the requested clip nor any `SpriteStateMap.MODEL_ALIASES` entry exists (`model_actor.gd:548-563`). In `AllyBase._update_sprite()` the previous clip is held, so the man does not T-pose instantly but may freeze in a stale pose.
- **SpriteActor fallback:** If a unit GLB is missing, `AllyBase` falls back to `SpriteActor` (`ally_base.gd:186-191`). SpriteActor uses sprite-sheet animation, not the shared `anim_library.glb`, so "real animations" do not apply to that unit.
- **Capsule fallback:** If even the sprite fails, a plain capsule is spawned (`ally_base.gd:195-206`). It has no animation at all.
- **Enemy fallback body mismatch:** `nva_regular` and `nva_rpg` name models (`nva_regular`, `nva_rpg`) that do not exist on disk. They rely on `sprite_unit_fallback` to `vc_guerilla_ppsh` / `vc_guerilla_rpg` (`data/enemies/nva_regular.tres`, `data/enemies/nva_rpg.tres`). If those fallbacks were removed, those enemies would fall through to SpriteActor or capsule.
- **Civilian unarmed clips:** Civilians expect clips such as `running_unarmed`, `walking_unarmed`, `hands_up` (`civilian.gd:200-214`). If those clips are absent from `anim_library.glb`, `play_first()` degrades to `idle`/`rifle_aiming_idle`. The civilian still animates, but an unarmed villager may stand in a rifle-aiming pose.

**Bottom line:** the shared-library wiring is live and correct for any contract-compliant GLB, but the T-pose risk is not in the code — it is in the export contract (`PSXRig` naming, mesh-only exports, and the presence of `anim_library.glb`) and in missing fallback coverage for any new MOS body that is added.
