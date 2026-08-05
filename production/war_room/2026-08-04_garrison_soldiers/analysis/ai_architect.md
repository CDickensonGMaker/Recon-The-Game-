# AI ARCHITECT — Garrison men are soldiers (2026-08-04)

Independent analysis. Every claim read from code this session; pointers per the Pointer Law.

## 1. What the code actually does today

### 1.1 The garrison man is a schedule brain with a combat hand-off

- `scripts/world/civilian.gd:8-9` — `class_name Civilian extends CharacterBody3D`.
  `is_garrison` at `:94`; garrison spawn path `mission_generator.gd:966-978` (posts) and
  `:936-940` (litter team), both `Civilian.spawn(..., GARRISON_MEN, true)`.
- The camp-life brain: BT built at `civilian.gd:601-634`, dispatched by schedule
  (`_bt_tick` `:652-671`, `civilian_schedules.gd:28` `action_for(occupation, hour, name)`),
  one shared settle leaf (`_bt_settle` `:867-883`), group walk (`:684-704`), 3-tier LOD with
  a hard skip at 300m (`:122-133`, `:284-287`), and off-screen teleport placement
  (`place_for_current_hour` `:777-789`).
- The combat hand-off: `scripts/allies/garrison_defender.gd:26-89` `promote()` tears the
  Civilian down synchronously and stands an `AllyBase` on his post (HOLD + `post_anchor`,
  leash 8m, `ally_base.gd:151-156`); `stand_down()` `:98-126` reverses it at dawn. One
  authority, no third combat brain — this is ADR-023 compliant and is the same 1:1 swap
  pattern as `_transform_to_vc`.

### 1.2 WHEN stand-to fires — the reaction gap, verified

`_garrison_stand_to()` (`field_director.gd:1394-1410`, latch `_garrison_stood_to` `:985`,
re-armed at dawn `:1492-1500`) has exactly THREE callers:

1. **Siege start** — `_on_siege_began` `:1441-1442`.
2. **Threat poll** — `_poll_firebase_threat` `:1348-1361`, run every 0.5s (`:221-224`),
   requires **≥ 2** live tracked enemies (`FSB_THREAT_MEN = 2`, `:972`) within **90m** XZ of
   `fsb_center` (`FSB_THREAT_M`, `:971`). Counts only `_live_enemies` — LazyGroup wakes do
   route through `spawn_tracked_enemy` (`lazy_group.gd:88` → `field_director.gd:53`), so
   awake VC count.
3. **Heli delivery into an already-standing fight** — `heli_lift.gd:249-250` (gated on
   `_garrison_stood_to` already true).

**Paths where enemies attack and the garrison never reacts (all verified):**

- **Noise is discarded by class.** `civilian.gd:250-251` hard-returns `if is_garrison` in
  `_on_noise`. A firefight 30m outside the wire moves no garrison man at all — villagers
  60m away flee (`:252-257`), soldiers keep sweeping floors.
- **A lone enemy never trips the poll.** One sapper or one scout inside the wire is
  `near == 1 < FSB_THREAT_MEN` (`:1358`). He can walk the compound and shoot men down and
  the stand-to never fires unless a second man joins him.
- **Fire from beyond 90m never trips it.** A treeline rifleman at 120m sniping into the
  base is outside `FSB_THREAT_M`; nothing else listens.
- **A garrison man who is HIT panics as a civilian.** `take_damage` (`civilian.gd:523-534`)
  sets FLEE/COWER on a survivor with no garrison branch and notifies nobody — a uniformed
  soldier takes a round and runs unarmed. This is the ruling's violation ON SCREEN, worse
  than the label: it happens in front of the player during any off-siege contact.

So the promote/demote ARCHITECTURE is sound; the TRIGGER SURFACE is three narrow doors,
and the ruling's substance ("they can fight and react to enemies") fails between them.

### 1.3 What 40 heads cost on each brain — measured from the code

- **Civilian**: static hitzone bands, built once (`civilian.gd:214-218`,
  `HitzoneBuilder._build_static`). The comment at `:215-216` records WHY: "16-40 civilians
  and 11 bone-synced convex hulls each is ~6.4ms/frame of hitzone sync." No per-frame
  raycasts; nav routing only at LOD_FULL (`:508-509`); full body skip past 300m (`:285-287`).
- **AllyBase**: bone-synced zones (`ally_base.gd:548`), re-synced EVERY frame while
  `_body_hot` (`:554-565`) — and allies are "pinned HOT" by design (`:40-44`). `_think` at
  6.7Hz (`THINK_INTERVAL 0.15`, `:21`) scans `AgentRegistry.enemies` with LOS work
  (`:642-647`, `:677`), morale loops are O(allies×enemies) at `:818-833`. **AllyBase has no
  LOD tier at all** — grep shows no tiering in the file.

A standing 40-man AllyBase garrison therefore re-buys, permanently, the exact ~6.4ms/frame
the Civilian class was engineered to refuse, plus 40 think loops that also inflate every
OTHER ally's and enemy's registry scans. The promote path pays that cost only during a
siege, when the frame budget is already being spent on the fight the player is watching —
that is the right time to pay it.

### 1.4 W-9 — the boarding teleport

`seat_system.gd:321-338` `board_squad()`: `var ally := body as AllyBase` (`:332`) — null for
a Civilian, so no MOVE_TO order is issued (`:333-334`); the stagger timer (`:336-337`) then
`seat()`s the man from wherever he stands — the glue-teleport. Civilian has no order verb:
`_wander_target` is rewritten by the BT every tick (`:652-671`), so nothing external can
walk him anywhere today.

### 1.5 VC-side audit — is any armed VC a Civilian?

**No.** Every `Civilian.spawn` caller in `scripts/` (repo grep):
- `mission_generator.gd:1021` — true villagers (ADR-019 population, correct).
- `mission_generator.gd:936, 966` — US garrison.
- `heli_lift.gd:191` — US garrison pax.
- `garrison_defender.gd:122` — dawn demote (US).
- `tests/test_actor_damage_contract.gd:271` — suite.

VC camp life is already staged on the soldier class: `camp_director.gd:29`
(`garrison: Array ## Array[EnemyBase]`), roles rotated on `SimClock.hour_advanced`
(`:107-132`), and `enemy_base.gd:584-596` `CAMP_ROLE_CLIPS` — whose own docstring at
`:577-581` says it mirrors `Civilian._play_garrison`. The VC side is the PROOF that
"soldier class carrying camp-life poses" works and is the existing precedent for the US
fix being about triggers/labels, not about porting a brain.

**The informer** (`civilian.gd:582-593` `_transform_to_vc`): swaps the MODEL to
`vc_farmer_m`, but only after `state = GONE`, `visible = false`, physics off
(`:307-314`); `take_damage` returns 0 at GONE (`:525-526`); the actual combatant is an
`EnemyBase` the director spawns via `on_informer_escaped` (`:593`). He never fights as a
Civilian — compliant with the ruling. One pre-existing footnote: a GONE informer keeps his
hitzones (`_teardown_hitzones` only runs in `_die`, `:544`), so an invisible body holds
live layer-512 zones at his vanish point. No damage falsification, but a round can report
an impact on an invisible man. Note for the record, not this decree's scope.

## 2. Options weighed

### (a) Migrate garrison to AllyBase/subclass + port the schedule BT — REJECT
- Perf: §1.3 — re-buys ~6.4ms/frame hitzone sync (`civilian.gd:215-216`) plus 40 HOT think
  loops with no LOD, on a call-bound project, for men who spend 90% of the day sweeping.
- One-brain law: porting the BT + schedules + group walk + LOD + placement (~900 lines of
  `civilian.gd`) into a 1700+ line combat class builds two brains in one body — the exact
  third-brain shape ADR-023 exists to prevent, just relocated.
- Fossil law: the Civilian garrison path must die in the same change — a multi-day rebuild
  during demo week, touching `mission_generator`, `heli_lift`, `garrison_defender`,
  `litter_team`, and the extraction flow (`heli_lift.gd:257-269` lifts Civilians).

### (b) Shared "person" base class — REJECT (for now)
Right in the abstract, wrong on the clock. Extracting a move verb + combat hooks from two
divergent locomotion stacks (`_step_toward` velocity-lerp `civilian.gd:504-517` vs the
slot/file/cover footwork of `ally_base.gd:127-158, 210+`) is a weeks-scale refactor with a
red-baselined suite and no headless testing while coding. It also does not by itself close
the reaction gap — you would still need the trigger work of (c) afterward.

### (c) Minimal bridge: widen the promote triggers + a real MOVE_TO verb — **CHOSEN**, with (d)'s naming rider

React = open the EXISTING door more often. No new brain anywhere.

1. **Noise stands the base to.** Replace the hard-return at `civilian.gd:250-251`: a
   garrison man hearing ENEMY-team gunfire or any explosion within earshot calls
   `director._garrison_stand_to()` (idempotent, `field_director.gd:1395-1396`; same
   underscore-call precedent as `heli_lift.gd:250`). `_on_noise` already receives `_team`
   (`:247`) — filter on it, or the player test-firing his M16 inside his own wire stands
   the whole base to.
2. **Being shot IS contact.** In `take_damage`, `if is_garrison and director: 
   director._garrison_stand_to()` before the FLEE/COWER roll — the survivor is promoted by
   the sweep in the same frame and fights back instead of fleeing unarmed. ~3 lines.
3. **Close the lone-man hole where it is cheap.** The noise path above already covers any
   lone enemy who FIRES or blows a charge. A lone silent sneaker who is SEEN is out of
   scope for a day (garrison men have no perception system and should not grow one — that
   would be a third brain); a silent unseen man defeating a camp is acceptable fiction.
4. **W-9 verb.** Give Civilian `order_move_to(pos, hold_s)` — writes an override target +
   expiry checked at the TOP of `_bt_tick` (`civilian.gd:652`) before dispatch; the leafs
   already communicate by writing `_wander_target`, so the verb is a privileged leaf, not
   a second brain. `board_squad` (`seat_system.gd:332-334`) duck-types
   `has_method("order_move_to")` beside the AllyBase cast. ~30 lines total; men walk to
   the bird, `_board_one` seats them as today.

What (c) does NOT do: it leaves the class of a rifle-carrying sentry named `Civilian`.

### (d) Rider — honest naming, post-demo
The 2026-07-30 heli ruling (`heli_lift.gd:177-181`) survives in MECHANISM and is refined,
not superseded: garrison men keep the schedule brain and the promote path stays the one
door into combat; the 8/4 ruling widens WHEN that door opens and fixes the LABEL. The
label fix: `class_name GarrisonMan extends Civilian` (overriding `_on_noise`/`take_damage`
garrison branches into the subclass and deleting `is_garrison` flag-checks per the fossil
law), or a rename of the base to split soldier-from-villager. Mechanical, ~5 call sites
(`mission_generator.gd:936,966`, `heli_lift.gd:191`, `garrison_defender.gd:122`, the
suite) — but it is a repo-wide type touch and does not belong in demo week. It should be
DECREED now and scheduled, so the ruling's letter is satisfied on the record, not
forgotten.

## 3. Demo-safe slice (one day)

- `civilian.gd`: garrison `_on_noise` branch (team-filtered) + `take_damage` stand-to
  call + `order_move_to` override in `_bt_tick`. (~45 lines, one file's brain untouched.)
- `seat_system.gd:332-338`: duck-typed order beside the AllyBase cast. (~5 lines.)
- Verify in the live game via godot-mcp run+debug: fire an AK near the wire off-siege →
  `[FSB] stand to: promoted N` prints (`field_director.gd:1408` already logs it,
  including the zero); board a lift → men walk, then seat.
- No suite additions while coding (owner runs the suite); no scene edits; ADR-010 clean —
  triggers are event-driven, no new unseeded rolls.

## 4. What is sacrificed (named)

- The `Civilian` class keeps soldiers in it until the post-demo rename — the ruling's
  letter is deferred, its substance (soldiers REACT) ships now. The Arbiter should record
  the rename as decreed work, not an option.
- Stand-to remains all-or-nothing (`:1399` promotes the whole group) — one shot near the
  wire stands 40 men to. Militarily that is what stand-to means, and the dawn stand-down
  (`:1492`) resets it; but a false alarm costs the camp-life tableau for the night.
  A per-man or per-sector promote is deliberately NOT proposed — it would need a new
  escalation brain.
- A lone SILENT infiltrator still beats the garrison's awareness. Accepted; the siege and
  noise paths cover every loud case.
- 0.5s poll + 2-man/90m gate stay as-is; the noise path supersedes their narrowness
  rather than retuning them (retuning `FSB_THREAT_MEN` to 1 would make every wandering
  scout trip a full stand-to with no shot fired).
