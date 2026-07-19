# DEVIL'S ADVOCATE — Playtest Polish Pass (2026-07-19)

Read the code, not the plan. Everything below is verified against source. Where the briefing's
"GROUNDED FACTS" are wrong, I say so.

---

## 0. THE BRIEFING IS WRONG ABOUT EXPLOSIVES. Civilians are invulnerable to EVERYTHING.

The brief was handed to me as fact: *"grenades/explosions already killed them but now bullets do too."*

**False.** `CombatManager.apply_explosion_damage()` (`scripts/autoload/combat_manager.gd:138-207`)
iterates exactly three cohorts: the player (`:149`), `AgentRegistry.allies` (`:168`), and
`AgentRegistry.enemies` (`:190`). **There is no civilian loop.** `grenade.gd:101` and
`claymore.gd:58` both route through that one function. Nothing else calls
`Civilian.take_damage()`.

`Civilian.take_damage()` (`civilian.gd:234`) has **zero callers in the entire project.** It is not
"unreachable by bullets" — it is unreachable, full stop. Dead code wearing the costume of a system.

Corroborating fossil: `AgentRegistry.register(civ, Kind.CIVILIAN)` (`civilian.gd:107`) is the ONLY
reference to the civilian registry in the codebase. `AgentRegistry.civilians` is written and never
read by anyone.

**Consequence for this council:** F1 is not "make bullets work too." F1 is "build the civilian
damage path, which does not exist." The scope is larger than the brief states, and the explosion
path needs the same decision as the bullet path or you ship a villager who eats an M26 at his feet
and keeps hoeing. That single image destroys Pillar 2 harder than a bullet passing through him,
because the grenade is *visible*.

---

## 1. THE INFORMER / STEALTH QUESTION — RULING

**The premise of the attack is backwards. Making the informer killable does not turn stealth into a
shooting gallery. It removes a stealth GATE that is live in the build right now, and that gate is a
standing ADR-005 / Pillar 3 violation.**

Read the informer clock, `civilian.gd:136-154`:

```
if is_informer and player and _inform_clock < 0.0 \
        and global_position.distance_to(player.global_position) < 15.0:
    _inform_clock = 0.0
```

Three things are true about that code:

1. **There is no line-of-sight check.** Proximity alone. An informer inside a hooch, behind a wall,
   at night, facing away, asleep — 14.9 m and the clock starts. ADR-005's whole doctrine is that
   only a man who *sees* you is proof of anything (`enemy_base.gd:740 _can_witness`, `:918
   _set_tier(tier, witnessed)`, `noise_bus.gd:11-14` — "Only a man who SEES you goes COMBAT"). The
   informer is the one perception system in the game that never learned the witness rule. **The
   informer is already the ADR-005 violation. He is not endangered by this change.**

2. **The clock never resets.** `_inform_clock` goes to `-1.0` in exactly one place: `:146`, on
   *firing*. There is no distance check, no LOS-break, no "he lost you." Once it starts, 25 seconds
   later `NoiseBus.emit_noise(GUNSHOT, _saw_player_at, 0, 120.0)` fires and the AO is up.

3. **You cannot stop it.** Not by breaking contact, not by hiding, not by leaving the village, not
   with a grenade (§0). The informer is bullet-transparent, blast-immune, and on an unstoppable
   timer.

That is the literal definition of the thing ADR-005 was written to kill: **escalation the player
cannot avoid.** Pillar 3 says stealth is an economy, never a gate. Today the informer is a coin flip
at village generation (`mission_generator.gd:633`, `rng.randf() < 0.5`) that, when it lands, hands
the player an unavoidable alarm. **50% of villages are currently a stealth fail-state with no
counterplay.**

### Is "shoot the informer" the dominant strategy?

Check the price, because the price is real and it is already built:

- The shot itself emits GUNSHOT at **150 m** (`noise_bus.gd:18`). The informer's own alarm only
  emits at **120 m** (`civilian.gd:150`). **Shooting him is LOUDER than letting him talk.** That is
  a correctly-shaped incentive and it already exists.
- Heard ≠ made. Per `noise_bus.gd:11-14` and `enemy_base._set_tier(tier, witnessed)`, a heard shot
  raises SUSPICIOUS/ALERT, not COMBAT. So the unsuppressed silencing costs you a woken, searching
  village and a 150 m alert bubble — it does not instantly stamp the beacon. That is an *economy*:
  you paid alert for time.
- `civilian.gd:116-121`: any GUNSHOT within 60 m flips **every** civilian in earshot to FLEE or
  COWER. Shoot one and the whole ville breaks and runs. In a village with a VC presence you have
  just generated a dozen running silhouettes and a lot of eyes.
- Suppressed is 3 m (`noise_bus.gd:19`) and genuinely silences him for free.

**RULING: implement it. F1 is required by Pillar 3, not a threat to it.** The suppressed-silencing
case is not a bug, it is the suppressor doing its job — that is exactly the ammo-economy trade
ADR-005 blessed ("Suppressed weapons and one-shot placement gain real meaning").

### What is SACRIFICED — say it plainly

1. **You are shipping the ability to execute a noncombatant on a timer as a legitimate, mechanically
   rewarded tactic, with no cost attached** (owner locked: no consequence system). ADR-019 §2 lists
   "Killing civilians" as the primary HOSTILE driver and ADR-019 §3 is explicit that the fast road
   must genuinely pay *now* and cost *later*. **This session ships the "pays now" half and none of
   the "costs later" half.** That is not neutral. It is a playable, tuned, satisfying incentive to
   murder witnesses, with the counterweight deliberately deferred. Every hour of playtest between
   now and the ledger teaches the player that it is free. Players do not un-learn that.
2. **The informer is currently the only civilian who matters mechanically.** Make him killable and
   the optimal read of a village becomes "which one of these ten is the informer" — and the game
   gives no tell. The player's rational move under uncertainty is to kill the one who runs. The one
   who runs is *any civilian who heard a gunshot* (`:116-121`). **You have accidentally built "the
   fleeing man is the guilty man," which is precisely the false heuristic that produced My Lai.**
   Thematically that is extraordinary. Mechanically, with no consequence layer, it is just a correct
   strategy. Know which one you are shipping.
3. **New: civilians become bullet BLOCKERS.** Whatever layer you pick, if it is in the shooter mask
   (`weapon_holder.gd:478`, `enemy_base.gd:2021`, `ally_base.gd:944`) then a villager between the
   player and a VC eats the round. That is correct and desirable — it is the single best
   fire-discipline mechanic you could get for free. But it *also* means the AI's rounds stop on
   villagers, and AI does not check its lane for noncombatants. Expect ally/enemy stray kills. Under
   F1(b) that is honest. Under F1(a) — civilian hitzones on layer 64 (enemy_hurtbox) — it is worse
   than dishonest: **it will make civilians targetable by anything that greps enemy_hurtbox, and it
   makes a villager a valid over-penetration target for `bullet_system.gd:163`.**

**F1 verdict: (b), a dedicated civilian layer, added to all three shooter masks.** (a) is a lie in
the map — exactly the fossil-law failure mode: a thing that reads as load-bearing under a name that
means something else. The 8-byte cost of doing it honestly is nothing next to the next agent who
greps `64` and finds villagers.

---

## 2. THE LYING TOAST — the consequence question

`civilian.gd:241-243`:

```gdscript
director.state.flags["civ_casualties"] = int(...get("civ_casualties", 0)) + 1
director.toast.emit("CIVILIAN DOWN. THAT FOLLOWS YOU HOME.")
```

`civ_casualties` is read by **nothing**. I grepped the tree. Nothing consumes it, no debrief line,
no ledger, no allegiance. Today that is harmless because the function is unreachable (§0). **The
moment you make it reachable, you ship a game that says "THAT FOLLOWS YOU HOME" and then nothing
follows you home.**

This matters more than it looks, because of ADR-019 §4: allegiance is **FELT, not read**, and the
ADR explicitly accepts an r4bk violation on the grounds that "the affordance is the world itself."
The system's entire defence is that the player will *feel* it. A toast that promises consequence and
delivers none does not fail neutrally — **it actively trains the player that the felt-consequence
channel is noise.** ADR-019 §Sacrificed already warns that delayed consequence is "easy to
experience as unfairness"; a false promise now is how you poison that well before the ledger is even
built.

Is shipping killable civilians with a lying toast worse than not shipping it? **No — but only
because not shipping it leaves the ADR-005 gate live (§1), which is worse.** Ship it. Fix the toast.

### THE HONEST MINIMUM

1. **Keep the counter.** `civ_casualties` is the flagged hook the owner asked for. It costs nothing
   and it is the ledger's future input. Keep the explosion path incrementing it too.
2. **Delete or rewrite the toast.** "THAT FOLLOWS YOU HOME" is a promise. The honest replacements,
   in order of preference:
   - **Nothing at all.** No toast. The most honest and the most in-line with ADR-019 §4 — the world
     should say it, not the UI. A dead villager in a rice paddy and a village that goes silent says
     more than any string.
   - If the owner wants feedback that the hit registered, a flat observation with no promise:
     `"CIVILIAN DOWN."` That is a report, not a threat.
3. **Do NOT** add a counter to the HUD or debrief this session. ADR-019 §4 forbids a live numeric
   meter, and the debrief sentiment language is not built.
4. **Comment discipline applies to the file header.** `civilian.gd:1-3` currently reads *"Killing
   civilians costs you at debrief and with the war."* It does not, and it will not after this
   session. That is a lying comment of exactly the ADR-005 §"Truth law" class — the kind that made
   two architects "verify" a fix that had never shipped. Rewrite it to describe shipped behavior.

**A promise the game does not keep is a fossil in prose. The toast IS the tombstone.**

---

## 3. THE ANIMATION FIX — honest, but it must be recorded as a debt

The proposal: give WORK / COOK / FISH / TALK / REST distinct poses drawn from `idle_unarmed_2..5`
and `sitting`, because the real clips do not exist.

**It is not a lie. It is a fix to a live, worse lie**, and the brief buries the lede on why.

The actual bug is `civilian.gd:217`: `play_first(["idle", "idle_unarmed_2", ...])`. `idle` **exists**
— it is the armed rifle idle — so `play_first` returns on the first entry and `idle_unarmed_*` is
never reached. Every idle villager in the game is standing in a rifle-holding pose. Same at `:209`:
COWER → `idle_crouching`, a rifleman's weapon crouch. **The village currently reads as an ambush
because every civilian in it is posed as a soldier.** Fixing that is not cosmetic; it is Pillar 2 and
it is a direct threat-read failure — the player's eye is being trained to shoot villagers by the
pose system.

Note also `:196`: `work`, `rest`, `cook`, `fish`, `sleep`, `sit`, `talk` **all map to the same
string `"idle"`**. Seven scheduled activities, one pose. The BT (`:421-475`) faithfully computes
seven distinct actions and then throws the distinction away one function later. The schedule system
is real and its output is discarded.

### The risk, named

**Differentiation from the wrong clips makes the missing art invisible, and invisible art debt is
permanent art debt.** Once every villager is *doing something plausible*, nobody on this project will
ever again look at a village and say "we need a harvest clip." The playtest complaint that
generated this bead disappears; the underlying gap does not. And `tools/make_civilian_anims.py`
already contains the *authored* clips (`civ_farm_harvest`, `civ_squat_idle`, `civ_cower`,
`civ_hands_up`, `civ_panic_run`, `civ_carry_pole_walk`) — the work is **done and unmerged.** You are
about to build a convincing decoy for art that already exists in a Blender workbench 20 metres away.

The second risk is subtler: `idle_unarmed_2..5` are *idles*. A farmer "working" who is standing
perfectly still with his arms at his sides reads as **a man watching you**, which is the exact
threat-read failure you are trying to fix. Swapping one wrong pose for a different wrong pose that
happens to be unarmed is an improvement of degree, not of kind. `sitting` for REST/TALK is genuinely
right. WORK/COOK/FISH from a standing idle is a placeholder and will look like one.

**RULING: ship it, with two conditions that cost nothing:**
- The fix is *removing `idle` from the head of the fallback chains*, first and foremost. That alone
  is most of the win and it is unambiguously correct.
- **File the merge of `tools/make_civilian_anims.py` into `anim_library.glb` as a bead in the same
  session, linked, before the placeholder ships.** The placeholder is only honest if the debt is
  written down where the machine can see it. Otherwise this is the third regression pattern (§ hat,
  F4) in a new costume.

---

## 4. THE DOUBLE HITZONE SET — measured, not theorised

`player.gd:446` builds static bands via `HitzoneBuilder._build_static(self, 32, 16, [...], true)`.
`player.gd:456` then calls `_setup_hitzones()` which hand-places 7 more (`:880-894`) on the same
layer 32, same mask 16, same groups.

I measured both sets. Note Godot clamps `CapsuleShape3D.height` to `>= 2 * radius`, which changes
the answer:

| Zone | Static (`hitzone_builder.gd:560-571`) | Hand-placed (`player.gd:882-894`) | Delta |
|---|---|---|---|
| HEAD | sphere r0.15 @ y1.65 → **1.50–1.80** | sphere r0.15 @ y1.65 → **1.50–1.80** | identical |
| TORSO | cap r0.30 h0.60 @ y1.30 → **1.00–1.60** | cap r0.30 h**0.35→clamped 0.60** @ y1.30 → **1.00–1.60** | identical |
| GUT | cap r0.28 h0.60 @ y0.85 → **0.55–1.15** | cap r0.28 h**0.30→clamped 0.56** @ y0.90 → **0.62–1.18** | 7 cm lower / 3 cm higher |
| ARM ×2 | cap r0.12 h0.50 @ x±0.35 y1.0 → **0.75–1.25** | same | identical |
| LEG ×2 | cap r0.12 h0.80 @ x±0.12 y0.4 → **0.00–0.80** | same | identical |

**The two sets are geometrically identical except for a ±0.05 m offset on GUT.** Deleting the
hand-placed set removes 3 cm of GUT coverage at the top (y 1.15–1.18), which is fully inside the
TORSO capsule (1.00–1.60) — no hole. The player does not become measurably more fragile or more
tanky. **Nothing playtested depends on the overlap.** The fear in F2 is unfounded; I checked it
specifically hoping to find a landmine and there isn't one.

**But there are three real consequences the fork did not name:**

1. **Delete the HAND-PLACED set, never the static bands.** `_build_static` sets
   `hz.set_meta("region", ...)` (`hitzone_builder.gd:576`). `_create_hitzone` **does not.**
   `bullet_system.gd:152` feeds `get_meta("region", "")` to `on_zone_hit()`, and
   `weapon_holder.gd:578/584` buckets shotgun pellets by region. **Right now it is a coin flip
   whether an incoming round resolves the player's region channel or hands it an empty string.** Two
   identical capsules, arbitrary tie-break. That is a live nondeterminism in the player's damage
   path and it is the strongest argument for doing this now rather than beading it — the bug is not
   "duplicate zones," it is "the player's gore/wound region resolution is random."
2. **`_self_exclusions()` survives the deletion.** `weapon_holder.gd:507-514` reads
   `controller.hitzones` and excludes every entry so the player does not headshot himself from the
   camera-height muzzle. `hitzones` is populated in both places (`:449` for the static bands,
   `:924` for the hand-placed), so it currently holds 14 entries. After deletion it holds 7 — all
   the surviving zones. **Safe, but this is the failure mode to probe:** if someone deletes the
   wrong block, or deletes `:447-449` while keeping `:456`, the exclusion list still covers
   everything by accident and nobody notices until a refactor. The probe must assert *count == 7 and
   every element is a child Hitzone*, not just "no self-hits."
3. **The tie-break is not "whichever the ray hits first" in the useful sense** — the two shapes are
   coincident, so `intersect_ray` returns whichever the broadphase happens to yield. It is
   nondeterministic across runs. **This is an ADR-010 determinism-contract concern**, not just tidiness.

**F2 verdict: delete `_setup_hitzones()` + `_create_hitzone()` now, this session.** Geometry cost is
3 cm of redundant GUT. The gain is a deterministic region channel. Bead the probe:
`get_children()` yields exactly 7 Hitzones, each with a non-empty `region` meta, before and after.

---

## 5. EDGE CASES NOBODY HAS CONSIDERED

### E1 — **CIVILIANS AT LOD_FAR NEVER COME BACK. THEY ARE FROZEN FOREVER.** (P0, live today)

`civilian.gd:361`:
```gdscript
set_physics_process(new_tier != LOD_FAR)
```
`_update_lod()` is called from `_physics_process()` (`:127`) and from nowhere else. So the instant a
civilian crosses 305 m, physics is disabled — **and `_update_lod` can therefore never run again.**
There is no other re-enable path in the file. The civilian is a statue permanently, no matter how
close the player walks.

The comment at `:129-132` claims *"State is still advanced by the SimClock.hour_advanced listener
below."* **There is no SimClock listener in this file.** I grepped every `hour_advanced` connection
in the project: `ambient_war.gd:17` and `camp_director.gd:49`. Civilian is not among them. The
comment is a tombstone for a system that was never built, and `civilian.gd:128-132` (the FAR
early-return inside `_physics_process`) is **dead code** — unreachable, because `:361` turned physics
off in the same frame the tier changed.

**Why this is the headline finding:** villages generate at mission time (`mission_generator.gd:638`)
while the player is at the firebase. Under ADR-029 (open patrol sim) locations are distance-gated
but the AO is 1280 m. **Any village generated more than 305 m from the player's spawn contains
civilians who freeze at LOD_FAR before the player ever sees them and never resume.** They are not
mid-pose statues — they are frozen in whatever WANDER/idle state they held, with `_animate()` never
called again.

This is very likely a *material* contributor to the playtest complaint the whole session is chasing.
Fixing the animation fallback chains (§3) **will not fix a civilian whose `_animate()` never runs.**
If the council ships B1 without this, the fix will appear not to work and someone will conclude the
clips are wrong.

**Interaction with F1:** hitzones are `Area3D` children. `set_physics_process(false)` does not remove
them from the physics world. So the frozen civilian is still shootable and still blocks bullets —
a solid, permanently motionless body in the fire lane, which is arguably worse than the invisible
one you have now.

### E2 — LOD desync: hitzones freeze, the mesh does not

`HitzoneBuilder.sync()` (`hitzone_builder.gd:175`) must be called every physics tick, and the
skeleton also drives it via `skeleton_updated` (`:164-166`). `AnimationPlayer` advances on the
**process** frame, not physics. At LOD_NEAR the civilian still runs physics, so this holds — but at
the FULL→FAR transition (or any state where physics is off and the AnimationPlayer is not), **the
zones stop while the visible model keeps playing its clip.** The player aims at a walking villager
and the round passes through empty space where the zones were left. Combined with E1 this is
permanent, not transient.

Mitigation is cheap: on entering LOD_FAR, also stop the AnimationPlayer, or take the static-band
path for civilians instead of skeleton-synced hulls. But it must be a *decision*, not an accident.

### E3 — The corpse hitzone fan: a 1.65 m floating head hurtbox

`civilian.gd:236-244` on death: `set_physics_process(false)`, then **`rotation_degrees.x = 90`**,
then free after 30 s.

That rotation is applied to the `CharacterBody3D` root. Hitzones are **children**, so they rotate
with it. Static bands are at fixed local offsets — HEAD at local `(0, 1.65, 0)`. Rotate the parent
90° about X and that sphere lands at world offset `(0, 0, ±1.65)`: **a head hurtbox floating 1.65
metres horizontally from the corpse, at roughly the chest height of a standing man, attached to
nothing visible.** The GUT/TORSO/LIMB capsules likewise splay into a horizontal fan across ~1.8 m of
ground.

For 30 seconds after every civilian death there is an invisible, HEAD-multiplier (`hitzone.gd:17`,
×4.0, `is_fatal_zone()` true) collision volume lying in the village that **eats rounds and reports a
headshot on a dead man.** If the civilian layer is in the shooter mask, the player's rounds and every
AI's rounds stop on it. `bullet_system.gd:158` will even emit `player_bullet_hit(killed, true)` on it.

And `rotation_degrees.x = 90` is not a corpse — it is a standing man tipped over about his feet, so
he is lying *through* the ground for half his height. It was invisible while civilians were
unkillable. It will not be invisible after this session.

**Minimum fix:** disable/free the hitzones in `take_damage()` at the moment of death, before the
rotation. One loop. Non-negotiable if F1 ships.

### E4 — Gib mid-flight through `_transform_to_vc()`

`:151-153`: on the informer's 25 s alarm the code calls `_transform_to_vc()`, then `visible = false`,
then `set_physics_process(false)`. `_transform_to_vc()` (`:257-261`) calls **`actor.setup(vc_pick)`**
— it rebuilds the model in place, swapping the civilian GLB for `vc_farmer_m`.

Now add F1. If a bullet lands on this civilian in the same frame the alarm fires:
- `take_damage()` sets `state = GONE` and unregisters, but `_physics_process` may already be past
  its `state == GONE` guard (`:125`) for this frame.
- If gib is wired to civilian death (the brief confirms all 10 civilian GLBs carry the full donor
  contract), `GibSystem` does **by-name node inspection at call time** (`gib_system.gd:103-338`, no
  registration). `_transform_to_vc()` has just replaced the node tree under `actor`. **The gib
  system will inspect the VC model's donors, or a half-built tree, and either pop the wrong meshes
  or find nothing.**
- Ordering hazard both directions: gib-then-swap leaves `actor.setup()` rebuilding a model that
  GibSystem just hid pieces of; swap-then-gib gibs a VC.

There is no guard. `_transform_to_vc()` does not check `state == GONE`, and `take_damage()` does not
check `_inform_clock >= 0.0`. Add the guard: **an informer who is dead does not transform.** One
line, and it is the difference between "silencing the informer works" and a 1-frame race that
produces a headless VC nobody can explain.

### E5 — The informer's alarm flags are read by NOBODY. The transformation never happens.

`:263-266` sets `director.state.flags["informer_transformed"]` and `["informer_last_pos"]`. The
comment above it (`:248-251`) states *"The actual `EnemyBase` is spawned by the mission director (it
owns the enemy roster); here we just make the visual hand-off."*

I grepped every `informer` reference in `scripts/`. There are exactly two files:
`civilian.gd` and `mission_generator.gd:633` (which only picks the index). **`FieldDirector` has no
informer handler.** No enemy is ever spawned. The flags are written into a dictionary nobody reads.

So the shipped behaviour is: the informer's model silently becomes a VC, he is set invisible, physics
off, and he stands there forever as an invisible frozen VC-skinned civilian while a 120 m GUNSHOT
noise event fires. **The "informer becomes a VC" feature does not exist.** The comment describing the
handler is an ADR-005 §"Truth law" violation of the same species the witness rule was written to
correct — a comment describing intent as if shipped.

This is directly load-bearing for F1: the council is about to rule on the informer's stealth economy
while half the informer system is a comment.

### E6 — Civilians spawned into an already-far LOD build zones they never use

Related to E1 but distinct: `Civilian.spawn()` (`:66-109`) builds the collision capsule
unconditionally at `:70-76` and would build hitzones under F1 the same way. LOD is not consulted at
spawn. So every civilian in every village in the AO carries a full hitzone set (7 static bands, or
11 skeleton-synced hulls if you use `HitzoneBuilder.build()`) from the moment of generation, whether
or not the player is within 1 km. At `mission_generator.gd:618-638` scale, across every village in a
1280 m AO, that is a large number of permanently-resident `Area3D`s in the physics broadphase — and
per E1 they never tier down, because the tier-down path is dead.

**Under ADR-026 (PS2 graphics budget) this is a physics cost, not a graphics cost, and it is
invisible to the `ps2_perf_probe` instrument.** If F1 uses `HitzoneBuilder.build()` (skeleton hulls,
11 zones + a `skeleton_updated` callback each) rather than `_build_static` (7 capsules, no
callback), the cost is roughly doubled and each carries a live signal connection.

**Recommendation: civilians get `_build_static`, not `build()`.** They are noncombatants; per-region
gore fidelity on a farmer is not worth the per-tick sync cost, and the static bands are the set that
carries `region` meta anyway (§4.1).

---

## 6. SUMMARY OF WHAT THIS SESSION ACTUALLY SACRIFICES

- **You are shipping the reward half of ADR-019 §3 without the cost half**, deliberately, and every
  playtest hour in between teaches the player that killing civilians is free. That lesson is sticky.
- **You are building a convincing placeholder over art that already exists unmerged**
  (`tools/make_civilian_anims.py`). If it is not beaded in the same breath, it is permanent.
- **You are deleting a duplicate hitzone set that costs nothing to delete** — this one is genuinely
  free, and I looked hard for the catch.
- **You are about to fix animation on civilians who, past 305 m, never animate at all** (E1). Fix
  E1 first or B1 will read as a failure.

## 7. ORDERED RECOMMENDATION

| # | Item | Why first |
|---|---|---|
| 1 | **E1 — LOD_FAR permanent freeze** | Blocks B1 from being observable. P0, live, one-line class of fix. Delete the dead `:128-132` branch and the lying `:129-131` comment with it. |
| 2 | **E3 — free/disable hitzones on civilian death** | Hard prerequisite for F1. Invisible fatal-zone fan otherwise. |
| 3 | **F1(b) — dedicated civilian layer, `_build_static` zones, all three shooter masks** | Closes the ADR-005 informer gate. Reject F1(a)/layer-64 outright. |
| 4 | **§0 — civilian loop in `apply_explosion_damage`** | Otherwise blast-immune villagers, which is a louder lie than the current one. |
| 5 | **§2 — kill the lying toast, keep `civ_casualties`, fix the file header** | Truth law. Costs nothing. |
| 6 | **E4/E5 — guard `_transform_to_vc()` on GONE; bead the missing director handler** | One-line guard now; the missing feature is beaded, not built this session. |
| 7 | **F2 — delete `_setup_hitzones()` + `_create_hitzone()`** | Determinism win, zero geometry risk. Probe asserts 7 zones, all with `region` meta. |
| 8 | **F3 — strip `idle`/`idle_crouching` from the head of the fallback chains; `sitting` for REST/TALK** | The real bug. Bead the `make_civilian_anims.py` merge in the same commit. |
| 9 | **F6 — traps: DEFER** | New geometry + a health path on a `Node3D` with no collision. Not a polish item. It is a feature, and this session is already carrying a new damage cohort. |
