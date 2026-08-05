# DEVIL'S ADVOCATE — Individual Sight

No free lunches. Here is what every proposal in this room costs.

## Against the two-camera rig (the council's favourite)

1. **Calibration friction on every single shoot.** A ChArUco print, a wave, and a solve — and
   FreeMoCap's own documentation admits calibration "can take some trial and error to get your
   set up right." The webcam loop he *likes* works because it is: position → "go" → record →
   verdict in minutes. Two cameras breaks that rhythm. If the rhythm breaks, he stops shooting,
   and the best pipeline in the world captures nothing.
2. **Sync.** Two independent devices, no genlock. A clap solves it, but it is another step, and
   a mis-synced pair produces *confidently wrong* 3D — worse than honest monocular error,
   because it looks fine.
3. **The one-process-holds-the-webcam problem gets worse.** We already know Windows lets exactly
   one process hold the Integrated Webcam. Now add a phone recording in parallel and a transfer
   step off the phone.
4. **The measured payoff is on joint angles (3–4°), from sports-science studies of walking,
   running and cycling.** Nobody has published what it does to a man kneeling behind sandbags
   working a bolt. I believe it helps. I do not accept that we know how much.

**Verdict:** worth doing, but pilot it on ONE take before it becomes doctrine. If it costs more
than ten extra minutes per session, it will not survive contact with a real shoot.

## Against the "just hand-key the weapons" doctrine

This is the council's most comfortable conclusion because it retroactively justifies the last
month. Notice what it actually says: **the thing he built the mocap toolkit for, it should not
be used for.** Before we ratify that, be honest that we are declaring a substantial investment
partly misdirected. The toolkit is not wasted — Lane B uses it constantly — but Lane A was the
original motivation, and we are now telling him to stop.

Also: "the industry hand-keys FPS arms" is true and is also the industry telling us what *they*
can afford. They have animators. He has one person and a council of ghosts. "Hand-key it" is
free advice that costs him every hour of it.

That is precisely why `beats.json` and the procedural layer matter more than they look — they
are the only two proposals that make hand-keying *cheaper*. If the answer is "hand-key," then
anything that does not reduce hand-keying cost is decoration.

## Against the licence finding

Play it out honestly, because the technical director's finding is doing enormous work here.

- The restriction is on the **model**, not on the numbers that come out of it. One could argue a
  bone rotation curve is not "incorporation of the Software in a commercial product." **I would
  not bet a shipped game on that argument**, MANO's explicit anti-military clause makes the
  argument worse, not better, and a Vietnam War title is the worst possible test case. The
  council is right to treat this as closed.
- But note the *legitimate* uses that remain: these models are perfectly usable as **study and
  reference** — run footage through WiLoR to *see* what the hand actually does, then hand-key it.
  That is the existing doctrine that reference models are studies, not ship assets. Closing the
  door entirely would lose a genuinely useful diagnostic.
- And commercial licences do exist. Not now, not at demo scope. But "closed forever" is wrong;
  "closed until someone writes a cheque" is right.

## Against the Leap Motion purchase

$140 and it may well sit in a drawer. It is a **desk sensor looking upward** — its field of view
suits hands over a keyboard, not a man shouldering a broom. Ultraleap's improvement claim is
"+22 % when holding objects," which is measured on objects like cups and controllers, not a
rifle-length prop that occludes the sensor's view of the far hand. And it captures **hands only**
— no body, no weapon cant, which the animator's own analysis names as the control that decides
whether a forearm twists 179° or 23.8°.

**Verdict:** do not buy it as part of this decree. If Lane A doctrine is "video supplies beats
and finger shape," the Leap buys us finger shape only — and we have not yet proved finger shape
from *any* source improves what the player sees at viewmodel framing.

## Against the gates and tests

None. The capability contract test and the installed-hash gate are unambiguously right, cheap,
and close entire defect classes. My only objection is a scheduling one: **do not let a pipeline
hardening week eat Demo Day.** These are hours, not weeks. Keep them hours.

## The thing nobody in this room said

Every proposal here is about making capture and authoring better. **Nobody asked whether we need
the clips at all.** We have 163 clips and an audit found 32 unwired. Before shooting anything
new, the highest-value animation work available may be wiring what already exists.
