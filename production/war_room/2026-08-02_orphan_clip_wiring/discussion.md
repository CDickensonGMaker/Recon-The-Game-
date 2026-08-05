# THE DEBATE

## Measurement called during debate (ADR-015)

Devil's Advocate #3 and Game Designer's ensemble-drift worry both turned on the same unknown:
**does any of this carry baked root motion?** Measured off the glTF Hips translation channel:

| clip family | horizontal drift over full clip | vertical |
|---|---|---|
| `gun_gunner` / `gun_loader` / `gun_agunner` / `gun_ammo_bearer` | 0.000 / 0.024 / 0.001 / 0.009 m over **27.3–27.4s** | 0 |
| `litter_carry_front` / `_rear` | 0.000 / 0.006 m | 0 |
| `litter_load_front` / `_rear` | 0.002 / 0.012 m | 0 |
| `cockpit_*`, `pilot_flips_switches` | 0.000 m | 0 |
| `jump_up` / `jump_down` / `jump_up_2` | 0.013 / 0.013 / 0.016 m | 0 |
| `walk_forward` (control) | 0.000 m | 0 |
| `disembark_heli` a–f | **0.200 – 0.534 m** | 0 |

**Root motion is stripped project-wide.** Every clip is in-place and the engine owns translation —
`walk_forward` at 0.000m is the control that proves it. The `disembark_heli` set is the lone
exception, carrying 0.2–0.53m of authored step-off.

### What this settles

**Game Designer's ensemble-drift fear is void.** Four men playing 27-second `gun_*` clips will not
drift apart, because none of them move at all. They are four static role poses. The MG crew is
*mechanically* safe to wire; what remains unproven is whether it **looks** right — which is a
question for eyes, not for a probe, and is exactly the hold the Summoner placed.

**Programmer's litter design is confirmed and simplified.** Both carry clips are in-place march
cycles, so the driver translating the team is not a workaround — it is the same contract every
locomotion clip in the game already uses. No fighting baked motion.

**Devil's Advocate #3 survives, narrowed.** The measurement cannot say what `disembark_heli_*` ends
*on*. It can say the clips already carry 0.2–0.5m of step-off motion, which means they were authored
as complete step-downs, not as torso-only fragments. That makes a bolted-on `jump_down` tail more
likely to double up, not less. **The objection stands and the heli-skid slice is not safe to build
blind.**

## Where the architects agreed

- **Stretcher first.** Systems, Game Designer and Programmer all rank it top, for different reasons
  (it needs no new architecture / it makes the butcher's bill visible with no UI / it has an exact
  code precedent). No dissent.
- **`cockpit_dead` stays orphaned.** Unanimous. No pilot damage model exists; wiring it means
  inventing a state to justify a 0.33s clip, and ADR-023 forbids leaving the hook.
- **The `_LOOP_NAMES` hazard is real and must ship in the same change.** Programmer raised it,
  Devil's Advocate escalated it to a known previously-shipped bug class
  (`model_actor.gd:350` documents it in the code already). Two names in, one deliberately out.
- **Jump does not belong to routines.** Systems Designer's framing — *a station is a man standing
  still doing a job, and a station never involves a jump* — went unchallenged.

## Where they disagreed

**1. Does the litter team spend from the seven-man work budget?**

Devil's Advocate: it is a straight trade — two of {dig, wash, water, burn, latrine} go dark.
Game Designer: it should be `ward_wounded`-driven and *transient*, which takes it out of the
standing-post budget entirely.
Devil's Advocate's counter: a transient spawn path is a **new** world-build path, and
[[recongame-divergent-systems-blindspot]] is the recurring failure this project already has.

*Unresolved by the architects. Escalated to the Arbiter.*

**2. Is the heli-skid slice worth taking at all?**

Systems Designer proposed it as the one live hook for `jump_down`/`hard_landing` that needs no
navigation work. Game Designer called it "a detail almost nobody will look at." Devil's Advocate
argued it risks a double-landing regression and that `hard_landing` at 2.03s is too long for a man
at the door of a Huey in an LZ.

*Two of three against. Escalated to the Arbiter.*

**3. Where does the litter code LIVE?**

Devil's Advocate's closing point: `civilian.gd:_play_garrison` is already ~70 lines of
`occupation ==` special cases, and bolting three unrelated systems into it is how the divergent-
systems problem reached fourteen. Programmer's design does not naturally live there — it is a
driver that owns three bodies, not a clip chain for one.

*Agreed in principle by all three; the Arbiter must say where it goes.*
