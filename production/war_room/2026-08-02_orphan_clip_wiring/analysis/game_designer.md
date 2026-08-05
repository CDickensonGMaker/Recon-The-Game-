# GAME DESIGNER — independent sight

## What the player actually gets from each of these

**The stretcher is the highest-value clip in the whole orphan list**, and it is not close.

His 7/30 ruling already established the doctrine: *the aid station fills from REAL casualties, and
an empty aid station in a war is the fresh-player failure.* `campaign_state.gd:50-70` implements the
number. `site_planner.gd:961-966` seeds the station so the medic is never miming surgery on dirt.

But right now the ward is **static**. A man walks past the aid station and sees a medic kneeling and
a man on a cot, in the same poses, every time. `ward_wounded` goes up after a bad patrol and the
station looks identical. **The litter team is the thing that makes the butcher's bill VISIBLE**
without a single line of UI — which is exactly the shape of ruling he keeps making (real casualties
fill the tent, no UI; hidden rep; XP never shown). Two men carrying a body into the tent after a bad
night IS the debrief.

That also means the litter team should be **driven by `ward_wounded`**, not run as unconditional
ambience. A stretcher team crossing the compound should mean *someone got hurt.* If it loops
regardless, it becomes wallpaper and the signal is spent.

**The cockpit is small but it is Pillar 2 done cheaply.** A landed Huey with a pilot frozen in one
pose is the kind of thing that reads as "game" instead of "place." A man flipping switches before
the ship spools is period, specific, and costs nothing.

**Jump/landing is the weakest of the three by player value.** Not because it is wrong — a man going
over the berm instead of walking to the gate would be great — but because the version of it that is
cheap (heli skid step-off) is a detail almost nobody will look at, and the version that matters
(NPCs traversing firebase terrain) is a real feature. It should not be bundled with two items that
are ready to ship.

## On the MG crew hold

His instinct to eyeball those first is correct and I want to reinforce why. `gun_gunner`,
`gun_loader`, `gun_agunner` and `gun_ammo_bearer` are 27.3–27.4 seconds each. That is not an ambient
pose — that is a **27-second choreographed performance** split four ways. If the split is off, or if
the four were cut from an ensemble whose relative positions are baked into root motion, then wiring
them puts four men in a pit doing a synchronized dance that drifts apart over half a minute.

`site_planner.gd` carries **20 `gun` markers** and the work budget is seven men total. Four of those
seven going to one gun pit is more than half the living firebase spent on a single position. That is
a real cost and it deserves the visual check before anyone pays it.
