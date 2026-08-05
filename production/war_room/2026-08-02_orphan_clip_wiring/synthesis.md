# THE DECREE — Orphan clip wiring, 2026-08-02

The Summoner ruled: stretcher, cockpit and jump/landing into the routines; MG crew held for a
visual check. The Council does not overturn a ruling — it reports what the ruling costs and where
it cannot be carried out as worded. One item cannot.

---

## I. THE STRETCHER — BUILD. This is the item of record.

**Ruling on the budget conflict (Debate §1):** the litter team is **seeded, not spawned, and not
unconditional.** `site_planner.gd:961-975` already special-cases the aid station — it seeds
medic + patient ahead of the round-robin, on his 7/30 ruling. The litter pair joins that same
seeding block, gated on `CampaignState.ward_wounded`. When the ward is above the floor, two of the
seven work posts become a litter team; when it is not, those two slots fall back to the round-robin
and the working party keeps its men.

This resolves both halves of the disagreement. Game Designer gets his signal — **a stretcher team
crossing the compound means someone got hurt** — without an unconditional loop that spends the
signal on wallpaper. Devil's Advocate gets no new spawn path: `site_planner` already owns post
generation, so nothing is added to the fourteen.

**Ruling on where the code lives (Debate §3):** NOT in `civilian.gd:_play_garrison`. That function
is a clip chain for one man and the litter is a driver for three. It goes in a new
`scripts/world/litter_team.gd` following the **`HeliLift.attach()` idiom** (`heli_lift.gd:65`) —
the project's established pattern for a node that sequences several bodies through a scripted
performance. Reusing an existing idiom is not a fifteenth system.

**Binding implementation constraints:**
- One driver owns all three bodies, per the `enemy_base.gd:2563-2565` precedent. The front man sets
  his own clip and calls `play(..., true)` on the rear man and the casualty so all three land on
  frame 0 together. Both carry clips are 2.40s, both load clips 1.07s — one restart per phase
  change holds the lock with no per-frame correction.
- The clips are **in-place** (measured: ≤0.006m drift). The driver owns translation, exactly as
  every locomotion clip in the game already works.
- **The casualty must be LATCHED.** Devil's Advocate #2 is binding: `carry_wounded` only works
  because `is_downed` makes `_update_sprite` return early. A live `Civilian` will re-issue
  `play_first(...)` on its own schedule and sit up on the stretcher. The carried body needs an
  equivalent latch or this fails intermittently — the worst mode, because it looks fine for the
  first ten seconds.

## II. THE COCKPIT — BUILD, narrow.

`seat_system.gd:51`'s single `PILOT_CLIP` becomes a three-state map:
- **parked / on the ground** → `cockpit_idle` (unchanged, already looped)
- **spooling up** → `pilot_flips_switches`, one-shot, 4.03s, then falls through to flight
- **in flight** → `cockpit_controls`, looped

**Binding:** `cockpit_controls` MUST be added to `model_actor.gd:_LOOP_NAMES` in the same change.
Devil's Advocate #4 is upheld — `_LOOP_PREFIXES` matches neither `cockpit` nor `pilot`, and a
one-shot ambient clip freezes the man the instant it ends. That bug class is already documented in
the code at `model_actor.gd:350`. `pilot_flips_switches` stays one-shot by design (it is a startup,
not a hold). `cockpit_dead` stays out.

**`cockpit_dead` remains orphaned, by decree.** Unanimous across the council. There is no pilot
damage model and helicopters are not damageable in the ADR-029 slice. Wiring it means inventing a
death state to justify a 0.33s clip, and ADR-023 forbids leaving the hook. Recorded here so the
next audit finds the reason instead of the gap.

## III. JUMP / LANDING — CANNOT BE CARRIED OUT AS RULED. Escalated to the Summoner.

This is the one item the Council must hand back.

**"Routines" is the station system** — a man walking to a `work_*` marker and playing a role chain
there. Systems Designer's framing went unchallenged: *a station is a man standing still doing a job,
and a station never involves a jump.* There is no routine in the game where a jump is the correct
pose. Jumping is **traversal**, and the traversal system does not exist:

- **`NavigationLink3D` appears zero times** in `scripts/` and `scenes/`. No vault, mantle or ledge
  code anywhere.
- Godot navmesh agents never leave the mesh, so **no NPC in this game is ever airborne.** There is
  no moment at which `jump_up`, `jump_down` or `hard_landing` could fire.
- `player.gd:1671` jumps, but the player is first-person — a viewmodel, not a third-person body. A
  player jump has no body clip to play regardless.

**The heli-skid slice is REFUSED.** Systems Designer proposed stepping off the skid as the one live
hook needing no navigation work. Two of three architects opposed and the measurement did not clear
it: `disembark_heli_*` carries 0.2–0.53m of authored step-off motion — the lone root-motion
exception in the entire library — which means those clips were authored as **complete** step-downs.
Appending `jump_down` or `hard_landing` risks a man who lands twice, and `hard_landing` at 2.03s is
too long for a man at the door of a Huey in an LZ. Taking it blind trades an orphaned clip for a
regression. It is not taken.

**What jump/landing actually requires:** nav links at the berm, trench lips and foxholes; an
airborne NPC state; gravity and ground detection; and an impact-speed test to choose `hard_landing`
over a soft resume. That is a feature epic, and the PLAYTEST R4 gate (ADR-015) applies to it.

`jump_away` is a dive with no grenade-flee behaviour to hang on. `jumping_jacks` is PT with no PT
routine. Both stay orphaned.

## IV. THE MG CREW — HOLD UPHELD, and the check is made cheap.

His instinct to eyeball these first was correct, and the measurement made it cheaper to act on:

**All four `gun_*` clips are IN PLACE — 0.000 to 0.024m of drift over 27.3 seconds.** The
ensemble-drift fear is void. Four men will not walk apart, because none of them move. They are four
static role poses at fixed positions, exactly what [[recon-station-architecture]] asked for when it
ruled per-role clips over baked ensembles. **The wiring is mechanically safe.** What is unproven is
whether the four read as one crew — a question for eyes.

So the deliverable is not a wiring; it is the check. `anim_review.gd` already carries a clip wall
and driver banks. It gains a **synchronized four-man MG crew bank** — the four roles started on the
same frame at their relative pit positions — so the Summoner judges the crew as a crew, at speed,
rather than paging four 27-second clips one at a time.

**The cost he is deciding about, stated plainly:** the firebase work budget is **seven men**
([[recon-firebase-work-markers]]). A four-man gun crew is **more than half the living firebase spent
on one position**, and `site_planner` carries 20 `gun` markers. This is not a free addition and the
visual check is the right gate on it.

---

## Tradeoffs named (Law 2)

- The litter team costs **two of seven** work posts whenever the ward is above the floor. On those
  patrols the firebase visibly loses two of {dig, wash, water, burn, latrine}. That is the price of
  making the butcher's bill visible, and it is paid only when there is a bill to show.
- Gating the litter on `ward_wounded` means a fresh tour with a light ward shows **no** stretcher
  team. The signal is preserved at the cost of the first-impression moment.
- Refusing the heli-skid slice leaves `jump_down` and `hard_landing` orphaned for longer. Accepted:
  an orphaned clip costs nothing, a double-landing costs a playtest.
- The MG crew stays orphaned until he looks. Four real, drift-free, correctly-split clips sit idle
  in the meantime.

## Next steps

1. Build the litter team — `scripts/world/litter_team.gd` + the `site_planner` seeding gate + the
   casualty latch.
2. Build the cockpit state map — `seat_system.gd` + the `_LOOP_NAMES` entry, same change.
3. Build the MG crew bank in `anim_review.gd`. **Then the Summoner looks.**
4. Jump/landing returns to him as a decision: open a traversal epic, or leave the family orphaned.
