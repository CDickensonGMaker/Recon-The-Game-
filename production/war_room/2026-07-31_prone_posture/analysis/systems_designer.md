# SYSTEMS DESIGNER — the posture economy of PRONE

**Session:** 2026-07-31 prone posture · **Lens:** economy (what prone costs, what it buys, who pays)
**Method:** read the code, not the plan. Every claim below carries `file:line` or says *no pointer found*.

---

## 0. What the code actually is right now (the baseline)

`CombatPosture` is 27 lines, two values, one function, three constants
(`scripts/ai/combat_posture.gd:9-26`):

| Symbol | Value | Line |
|---|---|---|
| `Posture.STAND / CROUCH` | 2 values | `combat_posture.gd:9` |
| `CROUCH_SUPPRESS` | 0.6 | `combat_posture.gd:11` |
| `SUPPRESS_PIN` | 0.7 | `combat_posture.gd:12` |
| `COVER_CROUCH_RANGE` | 3.0 m | `combat_posture.gd:13` |

It has exactly **two** callers, one per faction, and both do the identical thing — collapse the
posture to one bool:

- `scripts/enemies/enemy_base.gd:408-409` → `_is_low_posture()`
- `scripts/allies/ally_base.gd:377-378` → `_is_low_posture()`

That bool then does **three** things, and only three:

1. **Clip selection.** `_low_posture` is passed as the last arg of
   `SpriteStateMap.intent_for(...)` (`enemy_base.gd:457-459`, `ally_base.gd:446-451`), which
   remaps the standing intent through `_to_crouch()` — but only at
   `speed <= LOW_POSTURE_SPEED_MAX 2.6` (`sprite_state_map.gd:25,40-41`).
2. **A hard speed cap.** Planar velocity is clamped to `CROUCH_SPEED_CAP 1.9` m/s between
   `_execute` and `move_and_slide` (`enemy_base.gd:626-629`, `ally_base.gd:524-527`).
3. **Footstep volume** — `AudioManager.play_step_3d(pos, _low_posture)`
   (`enemy_base.gd:638`, `ally_base.gd:536`) — and the low-death clip
   (`enemy_base.gd:2596-2597`, `ally_base.gd:1451-1452`) and the flinch suppressor
   (`enemy_base.gd:2261-2263`).

**Crouch buys the AI NOTHING mechanical.** No accuracy term, no incoming-hit term, no
concealment term, no suppression-decay term reads `_low_posture`. It is a cosmetic + speed-cap
flag. That is the single most important fact in this analysis and it frames everything below:
**if prone is built the same way, prone will be a slower crouch and nothing else.**

The `firing` argument is dead: both `_is_low_posture(_firing)` signatures underscore-discard it
(`enemy_base.gd:408`, `ally_base.gd:377`) and `CombatPosture.decide()` never takes it
(`combat_posture.gd:15`). A third posture must not inherit that vestigial parameter.

### The art is real and it is loop-safe already

`prone_idle` and `prone_firing_rifle` are registered in `ModelActor._LOOP_NAMES`
(`scripts/visuals/model_actor.gd:341`) — someone already paid the "glTF carries no loop flag"
tax for them (`model_actor.gd:663-667`). `crouch_to_prone` / `prone_to_crouch` are correctly
*absent* from that list: they are one-shot transitions. Provenance:
`production/ANIM_WISHLIST.md:33-36` (Mixamo IDs 113000901 / 115750901 / 115820901 / 112990901),
status recorded at `ANIM_WISHLIST.md:64` — *"in the GLB, needs a prone posture the state map
can select — still engine work"* — and again at
`production/SESSION_HANDOFF_2026-07-30_MIXAMO.md:123-125`. Library file:
`assets/shared/anim_library.glb`.

There is **no** prone entry anywhere in `SpriteStateMap.MODEL_CLIP`
(`sprite_state_map.gd:127-147`) or `MODEL_ALIASES` (`:153-178`). The funnel literally cannot
name a prone clip today. Confirmed zero callers.

---

## 1. WHEN does a soldier commit to prone?

Prone is a **commitment**: it costs a transition on the way in *and* on the way out, and the
project already owns both clips. Design it around that, not around a bool flip.

The states and thresholds that already exist and can carry it:

### TRIGGER A (primary) — the heavy pin, but only after it PERSISTS

`Enums.AIState.SUPPRESSED` (`scripts/autoload/enums.gd:33`) is entered when an engaged man's
`suppression_level > SUPPRESS_PIN 0.7` — enemy at `enemy_base.gd:1358-1360`, ally at
`ally_base.gd:669-672`. Both re-check it every think outside the goal dwell, so it is a live
gate, not a latch.

The gate must NOT be "SUPPRESSED → PRONE" on the first think. Add **dwell**: a man goes prone
only after he has been above the pin for a continuous window (~1.2–1.5 s, i.e. 8–10 thinks at
`THINK_INTERVAL 0.15`). Rationale from the code itself: `_suppression_move_mult()` already
returns 0.05 at `suppression_level >= 0.85` (`enemy_base.gd:1803-1804`) — a man that pinned is
already nailed to the ground at 5% speed. Prone at 0.85 costs him almost no mobility he still
had. Prone at 0.70 costs him a lot. **Tie the entry to the top band (≥0.85), not the pin band
(0.7)**, and the mobility trade is real rather than free.

Proposed constant: `PRONE_SUPPRESS: float = 0.85` — chosen because it is the number
`_suppression_move_mult` already treats as "pinned: barely able to shift position"
(`enemy_base.gd:1803-1804`), so the two systems agree instead of inventing a third band.

### TRIGGER B — the prepared position, before contact

`AmbushPlanner` picks ambush sites and stages 4–6 men (`scripts/enemies/ambush_planner.gd:40-41`,
`SEARCH_RADIUS 200`, `:42`). Those men sit at `AlertTier.RELAXED`/`SUSPICIOUS`
(`enemy_base.gd:96-97`) waiting on a road. **This is the single best prone case in the game**:
it is a *chosen* posture with no reversal pressure, it reads instantly as Vietnam, and it costs
the AI nothing it wanted (an ambusher is not going anywhere). Wire: an ambush-staged man in
`IDLE` with `alert_tier <= SUSPICIOUS` and a set post plays `prone_idle`, and fires from
`prone_firing_rifle` when the ambush springs.

**Caveat, and it is a real one:** prone concealment does not exist for AI (see §5), and the
ambush's entire value is being unseen. Prone ambushers will read as *believable* but will not
be *harder to see* unless the sight-cap work in §5 ships with it.

### TRIGGER C — the MG / long-gun station

`prone_firing_rifle` is a rifle clip; the weapon-family suffix machinery
(`sprite_state_map.WEAPON_FAMILY:192-199`, `clip_for:204-211`) would ask for
`prone_firing_rifle__mg` and fall back. An RPD/M60 gunner going prone behind a felled trunk is
the picture-perfect use — and `FellableTree` already produces **prone-height hard cover**
(`scripts/world/fellable_tree.gd:116,136` — "~0.5m … prone height"; `tools/make_felled_tree.py:85`).
The cover geometry for prone already exists in the world. **No pointer found** for any code
that scores a cover point by *height class*, so the AI cannot currently tell prone cover from
standing cover — that is the finding, and it is the gap that makes Trigger C a Phase-2 item.

### TRIGGER D — DO NOT

- `SEEKING_COVER` must never go prone. It is a *movement* state; the crouch there is already
  gated to within `COVER_CROUCH_RANGE 3.0` (`combat_posture.gd:23-24`) precisely because men
  were committing posture 10 m out (`combat_posture.gd:4-6`). Prone would re-create that bug
  with a longer reversal.
- `ADVANCING` / `FLANKING` / `RETREATING` must never go prone. Those rows return `STAND`
  deliberately (`combat_posture.gd:19-20`) and the bible names the reason:
  *"Wiring caution too eagerly kills the aggression the Summoner liked"*
  (`production/bible/04_AI_LOCOMOTION.md:28-29`).
- Plain `COMBAT` must never go prone. `COMBAT` is the default engaged state
  (`enemy_base.gd:1360`, `ally_base.gd:755`) and is where most men spend most of a firefight.
  Prone here = §3's disaster.

### The recommended `decide()` shape

```
enum Posture { STAND, CROUCH, PRONE }
const PRONE_SUPPRESS: float = 0.85
```
- `suppression >= PRONE_SUPPRESS` AND state == SUPPRESSED AND the caller's dwell flag → PRONE
- everything else: unchanged table (`combat_posture.gd:16-26`)
- Ambush prone (Trigger B) does **not** go through `decide()` — it is a staged post pose, like
  the crew stations already are (`ally_base.gd:381-400`, `CREW_STATION_CLIPS`). Precedent exists;
  use it rather than bloating the combat table with a non-combat case.

The dwell timer belongs in the two bases (they own `THINK_INTERVAL`), not in `CombatPosture` —
the class is a pure static decider (`combat_posture.gd:7` `extends RefCounted`) and must stay
stateless or the "shared contract can never drift" guarantee in its own docstring
(`combat_posture.gd:2-3`) dies.

---

## 2. What prone COSTS him — concrete numbers this project already uses

| Cost | Existing number | Pointer |
|---|---|---|
| Crouch speed cap | 1.9 m/s | `enemy_base.gd:176`, `ally_base.gd:237` |
| Base enemy move speed | 4.0–4.4 m/s | `bible/04_AI_LOCOMOTION.md:26-27` |
| Clip-swap kinematic ceiling | 2.6 m/s | `sprite_state_map.gd:25` |
| Sprint floor | 4.6 m/s | `sprite_state_map.gd:14` |
| Player prone speed | 1.0 m/s | `scripts/player/player.gd:65` |
| Pinned move mult @0.85 supp | ×0.05 | `enemy_base.gd:1803-1804` |

**Recommended `PRONE_SPEED_CAP: float = 1.0`** — take the player's number
(`player.gd:65 PRONE_SPEED = 1.0`) rather than inventing a fourth. Symmetry between what the
player feels and what he watches the AI do is worth more than a tuned decimal, and it makes
the AI's crawl legible: he moves at the speed the player knows prone feels like.

Cost ledger, honestly:

- **Mobility: 4.0 → 1.0 m/s, a 4× loss.** Crouch is already a 2.1× loss (4.0→1.9). Prone
  roughly doubles the penalty again. That is the trade, and it is the right shape.
- **Time to reverse.** `prone_to_crouch` is a one-shot; a Mixamo stand-up runs ~1.5–2.5 s.
  **No pointer found** for the actual clip length — nobody has measured it, and it is the single
  number this decision most depends on. *Measure `prone_to_crouch` in the GLB before tuning
  anything.* During that window the man must be **locked**: `_cover_exit_until_ms`
  (`enemy_base.gd:426-430`) is the exact precedent — a self-clearing window with no
  `_anim_override`, explicitly so there is "no frozen crouch statue leak". Copy that pattern,
  do not invent a new latch.
- **Breaking contact.** A prone man cannot execute `RETREATING`, which routs at
  `> SPRINT_SPEED_MIN 4.6` (`sprite_state_map.gd:83`). He must pay `prone_to_crouch` first.
  Under fire that is a death sentence — which is *correct*, and is the whole reason prone is
  interesting. It also means prone must never be entered by a man whose courage is about to
  break; see §3.
- **Field of view over cover.** **No pointer found.** Nothing in the perception path
  (`enemy_base.gd:960-1015`) models the shooter's own eye height — `_sight_cap()` and the LOS
  rays both use a hardcoded `global_position + Vector3.UP * 1.5` as the eye origin
  (`enemy_base.gd:1375-1379`, `:1382-1385`). **A prone AI would still see over a 1.4 m wall.**
  That is the largest single honesty hole in shipping prone, and it is a one-line-per-site fix
  (a posture-derived eye height) that must ship in the same change or the feature is a lie.
- **Suppression decay.** The player is rewarded for getting down: `SUPPRESS_DECAY 0.55`
  standing vs `SUPPRESS_DECAY_LOW 1.3` prone/crouched (`player.gd:138-139`, applied at
  `player.gd:1901-1902`). **The AI has no equivalent** — no pointer found for any posture term
  in AI suppression decay. If prone ships without it, a prone AI stays pinned exactly as long as
  a standing one, and the posture is decoration. This is the *reward* half of the trade and it
  must ship with the *cost* half.

---

## 3. Where prone makes the firefight BETTER, and where it kills it

### Better (Pillar 1 — believable firefights)

- **It gives the pin a visual floor.** Right now the strongest thing heavy fire produces is a
  kneel that looks identical to a man taking a knee to shoot. `prone_idle` under a machine gun
  is the single most legible "this man is losing" read in the medium, and it costs the player
  nothing to understand.
- **It makes MG fire mean something.** MG base damage is 42 (`CLAUDE.md:185`, ADR-016) but MG
  *suppression* has no distinct body language. Prone is that body language.
- **It gives the ambush its picture.** Trigger B, above.
- **It legitimises an existing claim.** `bible/04_AI_LOCOMOTION.md:83-84` records that the
  suppression code *"already claims it pins men to a crawl … against a clip that does not
  exist — honor that later, do not fake it now."* Building prone discharges a known, dated,
  self-flagged lie in the canon. That is a genuine debt payment, not a new feature.

### Worse — the failure mode, named plainly

**A squad that goes prone and never gets up is a squad that has stopped fighting.** The
mechanism is concrete and already present:

1. Suppression drives a man prone.
2. Prone caps him at 1.0 m/s and locks him for the transition window.
3. `_execute_combat` refuses to fire above `suppression_level < 0.8` (`enemy_base.gd:1574`) —
   so a man at 0.85 is prone AND not shooting.
4. Not shooting means he generates no return fire, so the player's suppression on him never
   drops, so he never gets up.

That is a **latch**, and it is the exact bug shape my memory has a name for
(*silent freeze bugs: looks alive because something teleports or plays once*). Three
counter-measures, all of which must ship together:

- **Hysteresis, mandatory.** Enter at 0.85, exit at ≤0.60 (`CROUCH_SUPPRESS`, reusing an
  existing constant rather than a new one). The ally suppression band already uses exactly this
  pattern — enter 0.6 / exit 0.35 (`ally_base.gd:691`, docstring `:777-779`). Copy it.
- **A hard ceiling on prone dwell.** A man may not be prone for more than N seconds regardless
  of suppression. Precedent: `SEEKING_COVER`'s cover rush "COMPLETES (cap 4s)"
  (`ally_base.gd:684-685`). Suggest 6–8 s, then he must crouch and re-decide, even if that
  kills him. **A squad must be able to lose; it must never be able to stall.**
- **Never prone the whole squad.** If every man in a fireteam crosses 0.85 at once — which is
  exactly what one M60 burst does — the entire squad face-plants in unison. That is the same
  class of defect as the "unison ally-roll" already recorded at
  `bible/04_AI_LOCOMOTION.md:94` (Track B1). Rate-limit it: at most one man per squad may enter
  prone per ~2 s, or gate on a per-man randomised threshold. **No pointer found** for any
  existing squad-level posture arbiter — `EnemySquad` (`scripts/enemies/enemy_squad.gd`) exists
  but nothing in the posture path consults it. That is the finding, and it is the reason I rank
  the unison risk higher than the latch risk.

---

## 4. Does prone belong to the player? — HE ALREADY HAS IT, and it is the best posture economy in the project

**This contradicts the brief's framing.** The player controller has a complete, wired, tuned
prone system today:

| Element | Value | Pointer |
|---|---|---|
| State var | `is_prone: bool` | `scripts/player/player.gd:44` |
| Toggle input | `"prone"` action, just-pressed | `player.gd:1553-1554` |
| Capsule/eye height | `PRONE_HEIGHT 0.5` | `player.gd:64`, applied `:1694-1695` |
| Move speed | `PRONE_SPEED 1.0` | `player.gd:65`, applied `:1636-1637` |
| Sprint forbidden | `not is_prone` in `can_sprint` | `player.gd:1624` |
| Jump forbidden | `not is_crouching and not is_prone` | `player.gd:1671` |
| Crouch key cancels prone | `is_crouching = … and not is_prone` / `is_prone = false` | `player.gd:1690-1692` |
| Revive forces upright | `is_prone = false` | `player.gd:1683` |
| Faster suppression decay | 1.3 vs 0.55 /s | `player.gd:138-139`, `:1901-1902` |
| Weapon/viewmodel reads it | two sites | `scripts/player/weapon_holder.gd:457`, `:576` |

And crucially, **the enemy perception system already pays the player for it**:

- Sight cap `× 0.4` when prone, `× 0.6` when crouched-and-still (`enemy_base.gd:977-982`),
  against a `SIGHT_CAP_OPEN` of 140 m (`enemy_base.gd:104`).
- Awareness gain `× 0.35` prone, `× 0.5` crouched; then `× 1.5` if moving, `× 0.6` if still
  (`enemy_base.gd:1007-1013`).

So the player's prone is worth roughly a **2.5× cut in spotting range and a 3× cut in
awareness accrual** — a genuinely large, genuinely earned survival buy, paid for with a 4×
mobility loss and no sprint/jump. **This is the economy the AI's prone should be measured
against, and it already exists in this repo.** The design work is not "invent prone", it is
"give the AI the half the player already has".

The player's version does have two gaps worth naming, both cheap:
- **No transition cost.** `is_prone = not is_prone` is instant (`player.gd:1554`) and the height
  lerps. He pays no time to get up. The AI, if it pays `prone_to_crouch`, will be *strictly
  worse off than the player at the same posture* — an asymmetry the player will feel as the AI
  being dumb rather than as himself being skilled.
- **No transition animation** — irrelevant in first person, relevant the day a third-person or
  killcam view exists.

---

## 5. Is suppression the right trigger, or is that lazy?

**It is partly lazy, and here is the precise part.**

The honest case for suppression: it is the only signal in the codebase that already means
"volume of fire near this man", it is faction-shared, it is decayed, it is banded with
hysteresis on the ally side (`ally_base.gd:691`), and both bases already gate three separate
behaviours on it (`combat_posture.gd:16`, `enemy_base.gd:1358`, `ally_base.gd:669`). Using it
is not inventing a signal — it is reusing the one that exists. That is correct engineering.

The case that it is lazy, in three parts:

**(a) Suppression is a *reaction* signal; prone is also a *deliberate* posture.** A man in a
prepared ambush position is prone because he *chose* to be, hours before anyone shot at him.
Trigger B has nothing to do with suppression. If suppression is the only trigger, prone will
only ever appear in the worst moment of a fight and never in the quiet moment before one —
and the quiet moment is where Pillar 2 (atmosphere) lives. **A suppression-only prone is half
a feature.**

**(b) The bible already ruled against suppression as a locomotion key at the middle band.**
`bible/04_AI_LOCOMOTION.md:40-42`: *"Suppression is deliberately NOT a locomotion key at the
0.35–0.70 band — it spikes on a single hit mid-assault and would gut the aggression."*
That reasoning applies with **more** force to prone than to crouch, because prone's reversal
cost is higher. Any prone trigger sitting below 0.85 is re-litigating a decision the bible
already made, in the direction it already rejected.

**(c) The trigger is not the lazy part — the PAYOFF is.** Suppression tells you *when*. The
lazy version is shipping the when without the what-for: prone that costs 4× mobility and buys
nothing, because
- no AI concealment term reads AI posture (the `× 0.4` cap only fires for `candidate == player`,
  `enemy_base.gd:977`),
- no AI suppression-decay term reads posture (no pointer found; the player's
  `SUPPRESS_DECAY_LOW` has no AI counterpart),
- no incoming-accuracy term reads posture (no pointer found in the hit path).

**Verdict: keep suppression as the combat trigger, at 0.85 with hysteresis, add the ambush
trigger as a separate staged-pose path, and refuse to ship either without at least one
mechanical payoff.** The cheapest honest payoff is the AI-side mirror of
`SUPPRESS_DECAY_LOW` — a prone AI's suppression decays faster, so prone is how a pinned man
*gets un-pinned*. That single term converts the latch of §3 into a loop: pinned → prone →
recovers → gets up → fights. It is the difference between prone being a stall and prone being
a tactic.

---

## 6. What I recommend, and what it SACRIFICES

**Recommend:**
1. `Posture.PRONE` added to `combat_posture.gd:9`; `PRONE_SUPPRESS 0.85`; exit at
   `CROUCH_SUPPRESS 0.6` (hysteresis, reusing the existing constant).
2. Caller-side dwell (~1.2 s above threshold) and a hard prone-dwell ceiling (6–8 s), both in
   the two bases, `CombatPosture` stays stateless.
3. `PRONE_SPEED_CAP 1.0`, matching `player.gd:65`.
4. Transition lock via the `_cover_exit_until_ms` pattern (`enemy_base.gd:426-430`), driven by
   the **measured** length of `prone_to_crouch` — measure it first.
5. `MODEL_CLIP` entries `prone_idle` / `prone_aim` / `prone_fire` and a `_to_prone()` sibling of
   `_to_crouch()` (`sprite_state_map.gd:99-122`), with the same kinematic backstop: prone can
   only resolve at speed ≤ 1.0.
6. **The payoff, non-negotiable:** posture-aware AI suppression decay, and extend the sight-cap
   posture modifier at `enemy_base.gd:977-982` to any candidate, not just the player.
7. Ambush prone as a staged post pose (Trigger B), modelled on `CREW_STATION_CLIPS`
   (`ally_base.gd:381-400`) — **not** through `decide()`.

**Sacrificed — say it out loud:**

- **Aggression.** Every posture the AI gains is a posture it can hide in. The bible warned
  about this once already (`04_AI_LOCOMOTION.md:28-29`) and crouch survived only because it was
  gated hard. Prone has twice the hiding power. **Some firefights will get slower and less
  climactic, and that is not a bug we can tune away — it is the price.**
- **The shared-contract guarantee.** `combat_posture.gd:2-3` claims the contract "can never
  drift between factions". A third value with a dwell timer moves state into the callers, which
  is exactly where drift is born. The docstring's promise gets weaker the day this ships.
- **Every posture consumer must be re-audited.** The bool `_low_posture` is read by clip
  selection, speed cap, footsteps, flinch (`enemy_base.gd:2261-2263`) and death-clip choice
  (`enemy_base.gd:2596-2597`, `ally_base.gd:1451-1452`). Three values through a bool means
  either a lossy `!= STAND` collapse (cheap, and the death clip becomes wrong — a prone man
  plays `death_crouching_headshot_front`) or five call-site rewrites. There is no third option.
- **Test churn.** `tests/test_low_posture.gd:49-59` asserts the current 8-row table
  exhaustively; `tests/test_ally_states.gd:90,131-139` reads `SUPPRESS_PIN` directly. Both go
  red on this change and must be extended, not baselined
  (`CLAUDE.md:306-314` — regenerating a baseline to silence a failure is "the one forbidden move").
- **Player/AI asymmetry.** Giving the AI a transition cost the player does not pay
  (`player.gd:1554`) will read as AI stupidity. Either the player pays it too, or accept the
  asymmetry knowingly.

---

## 7. Two contradictions found in the supporting documents

**(a) `production/GHOST_CODE_AUDIT_2026-07-25.md:134` is STALE.** It asserts the
`ADVANCING/FLANKING/RETREATING → STAND` rows are "unreachable for allies", so an ally in COMBAT
is "always CROUCH … forever". That was true on 7/25. It is not true now: posture-merge Part B
shipped, and `AllyBase` routes through the shared `CombatGoals` scorer and `_apply_combat_goal`,
which reaches `ADVANCING` (`ally_base.gd:746-747`), `FLANKING` (`:748-749`) and `RETREATING`
(`:751`). The related fossil it flagged, `LOW_POSTURE_SUPPRESS` at `ally_base.gd:234`, has
**zero hits repo-wide** — it was deleted. Per the POINTER LAW (`CLAUDE.md:330-347`), that audit
line should be corrected or dated.

**(b) `production/bible/04_AI_LOCOMOTION.md:38-41` describes an `_is_low_posture()` that no
longer exists.** It says the enemy gate is *"SUPPRESSED OR (SEEKING_COVER/ADVANCING/FLANKING AND
`alert_tier <= SUSPICIOUS`)"* and the ally gate is *"`suppression_level >= 0.6` OR (SEEKING_COVER
AND no LOS)"* — two divergent per-faction rules. The live code is one shared table with no
`alert_tier` term at all (`combat_posture.gd:15-26`), and both factions call it identically
(`enemy_base.gd:409`, `ally_base.gd:378`). The 7/23 merge superseded that text and the bible was
never corrected. Anyone building prone off bible §04 as written will wire a faction-divergent
gate that the shared class was created to prevent.
