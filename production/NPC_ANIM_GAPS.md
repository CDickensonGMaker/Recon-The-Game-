# NPC ANIMATION GAPS — the ledger

**As of 2026-07-31.** Scope, in his words: *"all the animations we need for the NPCs to fill all
our gaps minus the gun animations."* Weapon-family holds (`__mg` / `__launcher` / `__bolt`) are
**OUT OF SCOPE by his ruling** — deferred 7/30, *"that's stuff we can do later."*

`anim_library.glb` carries **163 clips**. Method: for each clip name, grep every `.gd` outside
`.godot/` and outside `model_actor.gd` (whose `_LOOP_NAMES` list is a loop-mode register, **not a
caller** — the fossil probe learned that lesson the hard way). Note that `sprite_state_map.clip_for()`
BUILDS family names at runtime (`base + "__" + family`), so `__smg` variants are reachable without
appearing in any grep.

**NOTHING BELOW IS PLAYTESTED.** Parse scan clean is not the same as judged by eye.

**Name audit, 2026-07-31:** every string reaching `play()` / `play_first()` and every value in
`MODEL_CLIP` / `OCTANT_CLIPS` / `CAMP_ROLE_CLIPS` / `VILLAGE_ACTION_CLIPS` / `OFF_DUTY_CHAINS` was
checked against the 163 clips in the library. **No typos, no missing clips.** The one that looks
wrong is not: `MODEL_CLIP["death_forward"] = "death_forward"` names a clip the library does NOT
carry — it resolves through `MODEL_ALIASES` to `death_from_the_front`, and every chain that uses it
leads with a clip that exists. `rifle_idle` / `charge_handle` / `prop_spin` live on the viewmodel
and vehicle rigs, not this library.

---

## CLOSED THIS SESSION

| Clip(s) | What was wrong |
|---|---|
| `medic_treat_receive` | Zero callers. The aid station now seeds a medic **and** a man on the cot. |
| `cargo_carry`, `cargo_unload_stack` | Wired but **absent from `_LOOP_NAMES`** — `cargo_carry` stands in for a walk cycle, so every man moving crates finished his clip and froze holding it. |
| `digging`, `plant_seeds` (garrison) | Reachable only for villagers. Now the firebase `detail` occupation works. |
| `sentry_scan`, `crouch_scan`, `nervous_scan`, `kneeling_idle` | Wired 7/30, but the guard role could never fire — `_assign_guards` never set `work_pos`. |
| `prone_idle`, `prone_firing_rifle`, `crouch_to_prone`, `prone_to_crouch` | Zero callers. Now the prone latch, both factions. See `war_room/2026-07-31_prone_posture/`. |
| `death_from_the_back` | Zero callers — the death pick measured only the X axis, so **the whole rear hemisphere fell forward**. |
| `death_from_front_headshot`, `death_from_back_headshot` | Zero callers. Under the headshot law a head hit kills everyone, so this is the most common death in the game. |

Plus the **one-chain-one-pose** class: `play_first()` takes the chain HEAD, so every man handed the
same chain played the same clip. Fixed for the firebase off-duty men, VC camp roles, and villager
schedule actions — chains now rotate per man off his spawn hash.

---

## ALSO CLOSED — second pass, 2026-07-31

- **Turn-in-place.** `turn_left` / `turn_right` wired as a stationary turn intent (fires only for a
  man who is otherwise idle, so a soldier tracking a target still aims). **MEASURED first, and the
  measurement split the set:** those two are in-place (0.024 m hip travel, ~0° root yaw), but
  `turn_90_left` carries **−161.6° of ROOT rotation** and `crouching_turn_90_left` −143.7°. Looping
  either would spin the mesh off the body. **`turn_90_*` and `crouching_turn_90_*` remain unwired,
  deliberately** — they are one-shot pivots and want a different mechanism.
- **Eight-way locomotion.** 14 diagonal and backward clips had zero callers; a man moving at 45°
  played the straight-ahead clip and crabbed. Now an octant **suffix** on the intent (`run@fl`), so
  `_intent_core` is untouched. All 31 locomotion clips measured in-place before wiring.
  `crouch_l`/`crouch_r`/`crouch_back` are deliberately not refined — `_to_crouch` already resolved
  those and re-deciding them would rewrite the intents the faction-merge contract asserts.
- **The four social clips — HIS RULING, 2026-07-31: US only, never VC or villagers.** Pulled from
  the VC camp `talk` role and the villager `talk`/`sit` chains. `standing_arguing` and
  `briefing_group` wired to off-duty GIs — the last two clips with no caller anywhere.

---

## STILL OPEN — ranked

### 1. The 90° pivots — `turn_90_left/right` · `crouching_turn_90_left/right`
Four clips, root-rotating (up to −161.6°, measured). They cannot be looped and cannot be driven by
a continuous intent. They want a **one-shot pivot** mechanism: latch, play once, let the body's yaw
catch up, release — the same timed-window pattern prone uses. Real work, not wiring.

### 2. Cover craft — `cover_reposition` · `crouched_sneaking_left` · `crouched_sneaking_right`
Cover behaviour exists (`stand_to_cover`, `cover_to_stand`, `cover_wall_lean_idle` are wired) but a
man never shuffles along his cover. Needs a reposition-within-cover behaviour, which is AI work.

### 3. `jumping_jacks`
Wants a PT / morning-formation moment in the firebase. **No `work_pt` marker exists** in
`fsb_main_v3.glb` — needs one marker, which is his Blender work.

---

## BLOCKED — and on what

| Clip(s) | Blocked on |
|---|---|
| `litter_carry_front/rear`, `litter_load_front/rear` | **His art.** The stretchers and `prop_wounded` markers live in the new `medical_complex` (`firebase_v3.1.blend`), which is NOT exported into `fsb_main_v3.glb`. He ruled 7/31: *"I'll do the fire base stuff by hand later."* |
| `salute`, `signal_move_up` | **His ruling.** Both need a trigger EVENT that does not exist — an officer encounter, a fireteam leader ordering a bound. Inventing the caller means inventing the behaviour. |
| `sitting_talking_b` | Nothing — it is a 1,350-frame variant of `sitting_talking` and simply has no slot worth spending. The other three of the "four social clips" are RULED and wired (US only). |
| `swimming` | No water-traversal system for AI. Not an animation gap. |
| `jump_up/down/away`, `hard_landing`, `falling_to_roll` | No AI vaulting or falling system. Not an animation gap. |

## OUT OF SCOPE (his ruling)
`gun_gunner` · `gun_loader` · `gun_agunner` · `gun_ammo_bearer` · `mortar_gunner` · `mortar_dropper`
· `mortar_runner` · `rifle_turn` · `stop_walking_with_rifle` · `rifle_crouch_idle_to_walk` and the
whole weapon-family hold programme.

`cockpit_idle` · `cockpit_controls` · `cockpit_dead` · `pilot_flips_switches` are aircrew, not
foot NPCs — separate track.

---

## THE CONSTRAINT NOBODY CAN WIRE AROUND

**The firebase seats SEVEN work-post men.** `FSB_GARRISON_MAX_MEN` is 24 and the curated post table
spends 17, so `clampi(24 - 17, 0, FSB_WORK_POST_CAP)` = 7 — against **198 `work_*` markers across 20
types**. However many ambient clips get wired, only seven men are ever standing at them. Raising the
ceiling is a frame-cost decision and has not been taken.
