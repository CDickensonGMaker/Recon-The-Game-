# Devil's Advocate Analysis — Hidden Costs and False Fixes

## Terrain: the attractive wrong answer

The Summoner said "open to changing the terrain engine." The obvious move is to grab Terrain3D or HTerrain. That would be a **project-killing detour**:

- **Canon collision:** `production/TERRAIN_WORKFLOW.md` §1–2 forbids hand-sculpted/plugin terrain because the province must regenerate deterministically from seed. A plugin introduces editor-authored state that cannot be replayed from `generate(seed)`.
- **Cratering:** grenades/mortars currently deform the heightmap in `modify_terrain`. A GPU clipmap plugin would need a deformation API; most do not expose it cleanly.
- **Performance unknown:** the project has no gating FPS number (`OVERSEER_CHARTER.md` §5). Swapping renderers before measuring the current one repeats the 0.77-render-scale lie.
- **Schedule:** a terrain plugin swap is a multi-week migration. The standing decree puts perf measurement and stealth restoration ahead of it.

**The right fix is boring:** stop normalizing to full scale and compress outliers. Boring is cheaper and canon-safe.

## Grunt v3 / random spawner: scope creep trap

- `AllyBase.sprite_unit` already defaults to `us_grunt_v3` (line 154). The Summoner may not realize the default is already correct.
- The actual issue is `SquadSystem.MOS_BODY` mapping every MOS to a **different** GLB (`us_grunt_pointman`, `us_grunt_mg`, etc.). Making the spawner "random grunt" sounds simple, but:
  - MOS visibility matters: the player must identify the RTO (PRC-25), medic, MG, grenadier. Random bodies make ADR-011 (RTO-gated fire support) unreadable.
  - Gear contracts: `ModelActor.RADIO_FORBIDDEN` exists because some meshes have no PRC-25. A random spawner must respect this or the RTO role becomes cosmetic.
  - The v3 base (`us_grunt_v3.glb`) exists, but do all MOS variants share its rig and take `anim_library.glb`? If not, randomizing them spreads T-poses.

**Recommendation:** keep MOS-specific bodies, but make the **rifleman pool** random among v3-based variants. Do not randomize RTO/medic/MG/grenadier — their silhouettes are gameplay information.

## Animation: "character manager" may already exist

`ModelActor` is the character manager. It already:
- loads the shared `anim_library.glb` (`_merge_shared_library`, lines 153–217)
- normalizes height (lines 114–149)
- applies loop modes (lines 246–263)
- resolves aliases (`MODEL_ALIASES` in `SpriteStateMap`)

If animations are not playing, the bug is likely in **exports** (wrong armature name, mesh-only GLB without PSXRig/Skeleton3D), not in `ModelActor`. A "new character manager" is a false fix.

## The real audit finding

The codebase is not missing systems; it is missing **verification that the systems work together**. Proposed fixes:

1. `probe_terrain_relief`: generate N seeds per preset, measure peak-to-valley and slope histogram.
2. `probe_squad_visuals`: spawn every MOS, assert ModelActor reports clips from `anim_library.glb`.
3. `probe_anim_playback`: for every unit in `assets/us/characters/`, assert idle/run/fire/death clips resolve and play.

## Sacrifices if we do everything the Summoner asked

- Replacing terrain engine: 2–4 weeks, breaks determinism, blocks THE_PLAN.md Steps 2–5.
- Fully random grunt bodies: breaks MOS readability and fire-support gating.
- New character manager: duplicates `ModelActor` and fragments the rig contract.

**Smaller, targeted fixes give 90% of the value with none of the canon damage.**
