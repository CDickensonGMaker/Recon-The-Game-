# SYSTEMS-DESIGNER — The Firebase Defense (2026-07-20)

Verdict: **ACCEPT-WITH-CHANGES.** The bones are sound and there is a live precedent for the riskiest
move, but three as-built facts contradict the plan's own prose, and the encounter's core tension
(believable defense vs. turret farm vs. perf) is unresolved in the code as written.

Read the code, not the plan. Pointers below.

---

## 1. GARRISON PROMOTION-IN-PLACE (Civilian → AllyBase, squad_member=false, HOLD, member={})

### Is AllyBase safe to run outside the squad? YES — there is already a shipped precedent.
`friendly_patrol_group.gd` already spawns bare `AllyBase.spawn_ally()`, sets `squad_member=false`
(`:42`), never adds them to `SquadSystem.members`, and orders them `HOLD`/`MOVE_TO` (`:55-59`). It runs
the full combat brain outside the roster today. So the pattern is proven. I checked every reader:

- `member_by_mos` (`squad_system.gd:125-129`) iterates `members`, **not** the `allies` group → a promoted
  garrison man with `member={}` cannot shadow the real RTO. Safe.
- `mission_hud.gd:218` (squad strip) and `:297` (markers) iterate `squad.members` → promoted garrison
  get **no** HUD rows and no floating markers. Safe, and correct.
- `_fire_at_target` reads `member` behind `if not member.is_empty()` (`ally_base.gd:1009`). `{}` is
  guarded → skill contributes 0, no crash. Safe.
- `terrain_watchdog.gd:39` casts and checks `.squad_member` before acting → a `false` man is excluded.
  Safe.

**So `member={}` does not crash anything.** But it is the wrong call, and it *diverges from the
precedent for a reason the precedent spells out:*

### CHANGE 1a — give them a real (lightweight) member dict, not `{}`.
`friendly_patrol_group.gd:43-46` gives ambient allies a `generate_member` dict **specifically** so the
nameplate can name them and the blue-on-blue affordance (r4bk) works. `squad_nameplate.gd:59-62` reads
`member` on **any** looked-at AllyBase regardless of group, calling `SquadRoster.rank_for(m)` and
`m.get("name")`. A garrison man with `member={}` is a **blank nameplate in US green at 5m** — the exact
friendly-fire hazard that council already solved. Give the promoted garrison a stub member
(`{nick:"GARRISON", mos:"RIFLEMAN", body:<a us_grunt id>}`) so `head_anchor` (`:91`) and the nameplate
resolve. Cheap, and it closes a known ROE hole.

### CHANGE 1b — HOLD is a LIE the moment they fight. This is the load-bearing defect.
`order_mode` is consulted **only in `AIState.IDLE`** (`_execute_idle`, `:656-704`). The instant
`_evaluate_goals` (`:610-617`) sees a target with contact it flips the man to `COMBAT`, and
`_execute_combat` (`:732-818`) **ignores `order_mode` entirely**: it maneuvers by range band —
advances if `dist > preferred_range * advance_band` (preferred_range **12m**, `:9`,`:759-761`),
strafes, and cover-seeks (`_evaluate_goals:604-607, 611`). Sappers/assault spawn **300–500m out**
(`SAPPER_RING_MIN/MAX`, `field_director.gd:532-533`) and close. When one enters the garrison man's
(darkness-shrunk) sight cap, the man acquires and — being far past 12m — `may_close_distance()` sends
him **charging off his post into the dark toward a high-stealth sapper.**

The plan's "they hold posts, face+fire the threat, hold post" is **false as-built.** A HOLD order does
not survive contact. You will get a firebase that empties itself into the treeline the moment the
attack lands. Fix: when `order_mode==HOLD`, clamp `may_close_distance()` to false and leash cover-seek
to a radius around `order_pos` (fire freely, fall to *adjacent* cover, never cross the wire). Without
this you cannot get a believable defense at all — see §4.

### CHANGE 1c — reversion must not resurrect the dead.
A promoted man who is killed runs `AllyBase._die` → `ally_corpses` group, 45s `queue_free`
(`:1153-1154`). "Revert to Civilians at dawn/clear" must track which **posts lost their man** and leave
them empty — do not re-stamp a Civilian onto a post whose defender is a corpse. Not addressed in the
plan.

### PERF — the sharpest sacrifice. ~17 hot AllyBase FSMs, off-screen, on an AI-bound frame.
`AllyBase` has **no distance-LOD hard-return** like `civilian.gd`'s `LOD_FAR` (`:208-211`, which the
promoted men *were* benefiting from — the player is 300-500m away out on patrol, which is *required* for
the assault to launch at all: `_poll_firebase_threat` needs `patrol_out`, `:673`). The body gate
`_body_gate_open` (`:481-496`) returns HOT whenever `target != null` (`:482`) — and during the assault
**every** promoted man has a target. So the gate is defeated: all 17 run full `_think`, per-frame
`HitzoneBuilder.sync` (`:428-429` — the ~6.4ms/frame class of cost the civilian header calls out),
`_update_sprite`, and `move_and_slide`, **while the player cannot see the fight** — plausibly on the
same frame he is in his OWN contact at the patrol site (the loud assault element + a VC squad are
spawning too). You are paying two firefights of AI for one the player watches.

The 1:1 swap framing hides this: the men you replace were **near-free** (LOD_FAR hard-return); the men
you create are **maximally hot.** Net cost is not neutral — it is a spike concentrated on the worst
frame.

**Mitigation (CHANGE 2):** gate promoted-garrison fidelity by `CombatManager.perceivable(self)` /
player distance to the firebase (the `target != null` short-circuit currently defeats the gate); run a
cheap **abstract attrition** (coin-flip trade of garrison vs. sappers per tick) while the player is
away, and only stand up the real FSMs when he closes to ~150m — which is exactly the fantasy (he
*rushes back* to a firebase in contact). Also **stagger** the 17 promotions (each `AllyBase._ready`
rebuilds a hitzone rig, `_setup_hurtbox:415-417`) — 17 in one frame at stand-to is a hitch at the
dramatic beat.

**SACRIFICE named:** promote-all-at-launch buys a "real" simulated garrison battle you mostly don't see,
at full cost. Perceivability-gating buys the frame back at the price of the off-screen fight being
*abstract* until watched — which is the honest trade for a single-CPU AI budget.

---

## 2. STEALTH stat as a per-unit cap multiplier

**ACCEPT the lever, ACCEPT-WITH-CHANGES the claims.** A caller-side multiplier is correct and stays
symmetric:

- `SightCap.at` (`sight_cap.gd:32-39`) is the **shared both-sides contract** and must stay pure — it
  does not know *whose* `look_pos` it is handed, so a `stealth` field cannot live inside it. The `*0.6`
  belongs in the caller, `AllyBase._find_target` (`:545`), reading `enemy.enemy_data.stealth`, clamped
  `≤1.0`. Non-sappers at 1.0 are untouched; the cap is only ever lowered. Symmetric and fair.
- It stays fair because it only shrinks the **garrison's acquisition radius** of sappers. The player's
  own stealth is already a *separate* model — stance/motion multipliers on the enemy sight cap
  (`enemy_base.gd:836-841, 864-869`). No mirror is owed on the ally→enemy path; enemies don't need a
  stealth-vs-player number because player concealment is posture, not a unit stat.

**PROBE TRAP (flag as required):** `AllyBase._find_target` is **instant** acquisition — no awareness
ramp, no FOV (contrast `enemy_base._update_perception:810-878`, which ramps `awareness`). Stealth here
only shrinks a **hard radius**; it does not model sneaking. And it is a *thin* band on top of the NIGHT
darkness cap already in play: `DARKNESS_BY_PERIOD[NIGHT]=0.4` (`sight_cap.gd:12`) takes
`SIGHT_CAP_OPEN 140 → 56m` and `SIGHT_CAP_JUNGLE 45 → 18m` (`enemy_base.gd:78-79`); a further `*0.6`
gives `~34m / ~11m`. Darkness already hides the sappers, and the assault-override sapper **never fires**
(`enemy_base.gd:1303-1305` early-returns to movement-only `_execute_assault`), so it never reveals
itself. Therefore an **end-to-end probe** ("sapper reached the bench") **passes with OR without the
stealth stat** — it proves nothing. Only a **narrow-band unit probe** — place a sapper between the
reduced and full cap and assert the garrison does *not* acquire — discriminates the fix from its
absence. Write *that* probe. Do not let "the sapper got in" stand as proof stealth works.

**Also flag:** the flare lever *does* work through the shared cap — `SightCap.at:34` floors `mult` to
0.9 when `IllumFlare.is_lit(look_pos)`, roughly doubling the garrison's detection of a lit sapper
(`11m→24m` jungle). Good. But the flare's effect on the **player** is illumination (lit models his eyes
can see), not a code cap — the player has no `SightCap` gate. So "the player's counter is the flare"
is true for two *different* reasons (garrison cap floor + actual light); the stealth **stat** never
touches the player's vision. Name this so nobody builds a player-side stealth probe expecting the stat
to move.

---

## 3. FORK B ECONOMY — live dock + persistent depot penalty

**ACCEPT-WITH-CHANGES.** The shape is right and it does **not** double-dock `_grant_fire_support`
(`field_director.gd:613-631`) **if** built as a consumed one-shot:

- Two different allotments. The **live dock** reduces the *current* `fire_support` dict. The
  **persistent penalty** reduces the *next* `_grant_fire_support` build (which rebuilds `fire_support`
  from scratch on every walk-out, `:618`). Different objects, no double-count — **provided** the
  persistent penalty is decremented into the mortar line and then **cleared** (persistent ≠ permanent;
  an uncleared penalty double-dips every future patrol from one breach).
- Apply it as `maxi(0, 3 + fo_bonus - penalty)` on the **mortar** line (`:620`) so it can't go negative,
  and hit mortar (the base tube) **not** the tier-released napalm/cbu/spooky (`:622-626`) — losing the
  depot should cost your bread-and-butter steel, not the escalation air. The plan targets mortar; keep
  it there.
- Persistence pattern fits cleanly: `begin_mission()` (`campaign_state.gd:127-129`) sets
  `_defer_saves=true` on the **walk-out** (`_poll_wire_gate:584`), *before* `_grant_fire_support`
  (`:595`). Detonation is mid-excursion, so a `CampaignState.depot_penalty` write correctly **defers**
  to `commit_mission`/`on_mission_end` — matching the all-or-nothing mission model. Add the var to
  `save_campaign`/`load_campaign`/`to_dict`/`from_dict`/`reset_campaign` (the six-point pattern, `:140`,
  `:162`, `:208`, `:224`, `:240`).

**SACRIFICE named:** the **live dock is nearly cosmetic.** `_grant_fire_support` wipes and rebuilds
`fire_support` every walk-out, so a breach late in an excursion docks a dict the player is about to
have overwritten on his next sortie anyway. Only the **persistent penalty** actually carries the sting
to the next allotment. So the "you lost your mortars *tonight*" feeling only lands if the player keeps
patrolling *this* excursion — make the persistent penalty the real teeth and treat the live dock as
flavor for the current sortie, not the mechanism.

---

## 4. PILLAR 1 — believable firefight vs. turret farm (the sharpest DESIGN sacrifice)

As the code stands you are forced into a **binary, and both ends fail Pillar 1:**

- **Honor HOLD (pin them to posts):** 17 static men firing at everything that crosses the sight cap =
  the **turret farm** the charge explicitly warns against. Not soldiers — automated gun-emplacements.
- **Honor the COMBAT code (§1b):** they **maneuver** — advance past 12m, strafe, hunt cover — and
  **sally off their posts** 300-500m into the dark chasing high-stealth sappers. Un-soldierly,
  post-abandoning, and it's the perf spike of §1 with the men scattered where the player can't see them.

A believable night defense is **neither.** It is a **post-leash**: men fire freely from cover, hold
within a few metres of their post, fall back to *adjacent* cover under pin, and **never cross the
wire.** No current AllyBase branch implements this — `_execute_combat` has one maneuver policy and it is
"close and strafe." **Build the leash (CHANGE 1b) or you ship one of the two failure modes.** This is
the design work the encounter actually requires; the promotion mechanic is the easy half.

---

## SUMMARY OF CHANGES
1. **HOLD post-leash** in AllyBase combat (suppress advance + clamp cover to `order_pos` radius when
   `order_mode==HOLD`). Without it "hold posts" is false and Pillar 1 is unreachable.
2. **Perf-gate the promotion**: fidelity by perceivability/player distance (the `target!=null`
   short-circuit defeats the existing body gate); abstract attrition while unwatched; stagger the 17
   rebuilds; give them a real stub `member` dict (not `{}`) so the nameplate/blue-on-blue affordance
   survives; handle KIA-post reversion.
3. **Fork B**: consumed one-shot `depot_penalty`, `maxi(0,…)` on the mortar line, cleared after use;
   the live dock is flavor. And **write the narrow-band stealth probe**, not an end-to-end one.
