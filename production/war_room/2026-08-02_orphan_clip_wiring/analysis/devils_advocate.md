# DEVIL'S ADVOCATE — what this costs, and what breaks

## 1. The stretcher team spends from a budget of SEVEN

[[recon-firebase-work-markers]] measured it: `FSB_GARRISON_MAX_MEN` is 24, the curated post table
spends 17, and the work-post budget is `clampi(24 - 17, 0, FSB_WORK_POST_CAP)` = **7 men**. Today
those seven are medic · patient · dig · wash · water · burn · latrine.

A litter team is **two more men plus a casualty body**. If they come out of the seven, then two of
{dig, wash, water, burn, latrine} go dark to pay for it — the firebase gets a stretcher team and
loses its working party. That is a straight trade and nobody should pretend it is free.

**Name the sacrifice or take the men from outside the budget.** The honest option is the second:
the litter team is a *transient event* driven by `ward_wounded`, not a standing post. It spawns,
runs, and despawns. But then it is a new spawn path, and that is the thing
[[recongame-divergent-systems-blindspot]] warns about — ~14 parallel world-build systems already.

## 2. The stretcher is a three-body puppet, and puppets desync in exactly one place

The `carry_wounded` precedent works because the casualty is `is_downed` — `_update_sprite` has
already returned early on his latched pose (`enemy_base.gd:2561-2562` comment says so explicitly),
so nothing fights the driver for his clip. **A live ambient body has no such latch.** If the man on
the litter is a `Civilian`, then `civilian.gd:_play_garrison` will keep running its own schedule and
re-issue `play_first(...)` over the driver's clip every time the schedule ticks. The result is a
casualty who sits up on the stretcher.

Whatever gets built must **latch the carried body** the way `is_downed` latches an enemy, or it will
fight the schedule and lose intermittently — the worst failure mode, because it will look fine in
the first ten seconds of a check.

## 3. `hard_landing` on the heli skid may be actively wrong

Six men are already stepping off with six authored disembark clips
(`heli_lift.gd:38-41`) — those clips presumably already land the man. Appending `jump_down` or
`hard_landing` to a clip that already ends with both feet on the ground gives a man who lands
**twice**. Before this goes in, someone has to look at what `disembark_heli_*` actually ends on. If
it ends standing, the jump clips are redundant and the "cheap win" is a regression.

I will go further: **`hard_landing` at 2.03s is a long clip.** Two seconds of a man recovering from a
fall, at the door of a Huey, in a hot LZ, with the ship burning fuel, is a man who should have been
moving. It may read as broken even if it plays correctly.

## 4. The cockpit change has a silent freeze waiting in it

The programmer named it and it deserves repeating as a hazard, not a note. `model_actor.gd:337`
lists `cockpit_idle` in `_LOOP_NAMES`. `cockpit_controls` and `pilot_flips_switches` are not there,
and `_LOOP_PREFIXES` (`idle`/`run`/`walk`/`sprint`/`strafe`/`swim`/`firing`) matches neither. A
one-shot ambient clip **freezes the man the instant it ends** — that exact sentence is already in the
comment at `model_actor.gd:350`. This is a known, documented, previously-shipped bug class. Wiring
these two without touching `_LOOP_NAMES` reintroduces it.

And note the asymmetry: `cockpit_dead` must NOT be looped. So this is not "add three names to the
list," it is two in and one deliberately out, which is precisely the kind of half-applied fix that
rots.

## 5. `cockpit_dead` has no state to fire from — do not wire it "for later"

There is no pilot damage model. Helicopters are not damageable in the current slice. Wiring
`cockpit_dead` means inventing a pilot-death state to justify a 0.33s clip. **Fossil law
(ADR-023):** do not leave a dead hook for a future system to trip over. Leave it orphaned and say
so in the record.

## 6. The real question nobody asked

He said "should be part of the routines." **Routines are the station system.** None of these three
are stations. The stretcher is an event, the cockpit is a vehicle state, and the jump is traversal.
If they get bolted into `civilian.gd:_play_garrison` as three more `occupation ==` branches, that
function — already 70 lines of special cases — becomes the dumping ground for everything that does
not fit anywhere else. That is how the divergent-systems problem got to fourteen.
