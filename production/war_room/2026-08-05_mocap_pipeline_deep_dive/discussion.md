# THE DEBATE

## Agreement reached quickly

**All five architects agree the two lanes are different problems and must stop sharing doctrine.**
The game designer put it sharpest: weapon clips are read at one framing forever and justify
per-frame care; NPC clips are read at many distances in groups and want library-splicing plus
contact solving. Tuning one instrument for the average of the two has served neither.

**All five agree the frustration is not "the mocap is bad."** The record is unambiguous — on
7/31, four stacked tooling defects presented as bad mocap and the mocap was fine. The lead
programmer's ranking stands unchallenged: four of the six most expensive incidents were defects
in our own toolkit, and **none of them failed loudly.**

## The licence finding — tested, and it held

The technical director's finding closed the most obvious answer in the room, so the council
tested it hard.

The devil's advocate made the strongest available counter-argument: the restriction binds the
*model*, and a baked bone-rotation curve is arguably not "incorporation of the Software in a
commercial product." The council did not accept it as a basis for shipping. Two reasons carried:
MANO's licence contains an **explicit prohibition on military use**, and a Vietnam War title is
the worst imaginable test case for a novel reading of a research licence.

But the devil's advocate won a real concession, and the Arbiter accepted it: **these models
remain legitimate as study instruments.** Running footage through WiLoR to *see* what a hand
does, then hand-keying from that, is exactly the existing doctrine that reference models are
studies and not ship assets. "Closed for shipped animation, open as a diagnostic" is the ruling.

## The sharpest disagreement: does the second camera survive a real shoot?

**Technical director:** it is the only legal fix for the 48 % depth number, it costs a printout,
and Pose2Sim publishes the exact two-camera geometry — front plus 45°, both at hip level.

**Devil's advocate:** the webcam loop he *likes* works because it is position → "go" → record →
verdict in minutes. Adding calibration, a second device, phone transfer, and clap-sync breaks
that rhythm — and a pipeline he stops using captures nothing. Further: the 3–4° accuracy figure
comes from sports-science studies of walking and cycling, not from a man kneeling behind sandbags
working a bolt.

**Resolution reached in the room:** both are right about different things. The technique is
sound; the *adoption risk* is real and un-measured. The council converged on **pilot it once,
measure the session cost, and only then make it doctrine** — with an explicit kill threshold.
The devil's advocate proposed ten extra minutes per session; nobody argued for more.

## The game designer's intervention, which changed the ranking

The engineers had ordered the work by defect severity. The game designer re-ordered it by
player-visible value per hour and made one point nobody could answer:

> The procedural life layer improves *every clip already shipped*, retroactively. Nothing else in
> this document has that property.

The animator confirmed from the measured record that **zero of the four known causes of "robotic"
were mocap problems** — they were curve handles, full-sync frames, a frozen weapon, and
zero-velocity plateaus. The council accepted the re-ordering.

The animator then attached a hard condition: anything the procedural layer drives must not also
be baked, or it doubles. This is already why the reference `Idle`/`Walk`/`Run` clips are static
in weapon space. **An explicit procedural-vs-baked register is a precondition, not a nicety.**

## Where the devil's advocate landed a hit nobody could return

> Every proposal here is about making capture and authoring better. Nobody asked whether we need
> the clips at all. We have 163 clips and 32 of them are unwired.

The Arbiter recorded this and it is reflected in the decree's ordering. No new footage is
required by anything in this decree before Demo Day.

## The Leap Motion purchase — rejected in the room

The animator raised it; the devil's advocate killed it on three grounds the animator conceded:
it is a desk sensor whose field of view suits hands over a keyboard rather than a shouldered
prop; it captures hands only, so it cannot supply weapon cant, which is the control that decides
whether a forearm twists 179° or 23.8°; and under the ratified Lane A doctrine we would be buying
finger shape alone — which has not been shown to change what the player sees at viewmodel
framing. **No purchase.**

## The uncomfortable thing the council said out loud

Ratifying Lane A doctrine means saying plainly: **the job the mocap toolkit was originally built
for is the job it should not be used for.** The toolkit is not wasted — Lane B uses it constantly
and successfully — but the original motivation was weapon arms, and the council is telling him to
stop pointing it there.

The devil's advocate's follow-on is the reason the decree is shaped the way it is: *"hand-key it"
is free advice that costs him every hour of it.* Therefore anything in this decree that does not
reduce hand-keying cost is decoration.
