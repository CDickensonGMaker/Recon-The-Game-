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

## STILL OPEN — ranked

### 1. Turn-in-place — `turn_90_left` · `turn_90_right` · `turn_left` · `turn_right` · `crouching_turn_90_left` · `crouching_turn_90_right`
**Six clips, zero callers.** A man changing facing while stationary currently slides his feet — the
state map has no turning intent at all (`_intent_core` reads speed, never angular rate). This is the
classic "the NPCs look robotic" gap and it is pure animation work. **Highest value remaining.**

### 2. Directional locomotion — `walk_backward*` · `run_forward_left/right` · `run_backward_right` · `sprint_*` diagonals · `walk_crouching_*` diagonals · `strafe_2`
`MODEL_CLIP`'s own comment says diagonals deliberately share the cardinal clips, *"the standing side
has no diagonal intents either, so this keeps parity."* Adding diagonal intents is a real read
improvement but it touches the funnel every man goes through — **War Room item, not a quiet edit.**

### 3. Cover craft — `cover_reposition` · `crouched_sneaking_left` · `crouched_sneaking_right`
Cover behaviour exists (`stand_to_cover`, `cover_to_stand`, `cover_wall_lean_idle` are wired) but a
man never shuffles along his cover. Needs a reposition-within-cover behaviour, which is AI work.

### 4. `jumping_jacks`
Wants a PT / morning-formation moment in the firebase. **No `work_pt` marker exists** in
`fsb_main_v3.glb` — needs one marker, which is his Blender work.

---

## BLOCKED — and on what

| Clip(s) | Blocked on |
|---|---|
| `litter_carry_front/rear`, `litter_load_front/rear` | **His art.** The stretchers and `prop_wounded` markers live in the new `medical_complex` (`firebase_v3.1.blend`), which is NOT exported into `fsb_main_v3.glb`. He ruled 7/31: *"I'll do the fire base stuff by hand later."* |
| `salute`, `signal_move_up` | **His ruling.** Both need a trigger EVENT that does not exist — an officer encounter, a fireteam leader ordering a bound. Inventing the caller means inventing the behaviour. |
| `briefing_group`, `standing_arguing`, `sitting_talking_b` | **His eye.** Modern American social body language (open-palm gesturing, casual weight shifts). On a VC camp or a village elder they may read as businessmen in costume. `sitting_talking` is already live in the camp `talk` role — watch it and rule. |
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
