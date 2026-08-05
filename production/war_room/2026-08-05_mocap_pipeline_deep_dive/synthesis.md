# THE DECREE — Mocap → Blender Pipeline

**2026-08-05 · for the Summoner's review · nothing here has been built**

> **READ `addendum_measured.md` WITH THIS.** The three gates below were proposed from reasoning;
> I then built and ran them against the real repo. The capability test **found two more dead
> promises on its first run**, one of which is a live animation defect. A separate alarm I raised
> about your existing footage being dimensionally wrong — **I measured it and I was wrong; the
> footage is sound.** Both results are in the addendum.

---

## THE SHORT ANSWER TO YOUR QUESTION

You are having trouble because **one instrument is being asked to do two opposite jobs, and it
is only right for one of them** — and because when it fails, it fails quietly and looks like bad
mocap.

**The gun work is failing for a structural reason that no amount of better footage or better
software will fix.** Monocular video has no depth. Measured on your own takes: **48–51 % of the
motion in a weapon clip rides an axis the camera never saw**, and a better camera angle barely
moves it (51 % → 48 %). Meanwhile the FP viewmodel needs *millimetre* accuracy in gun space. And
your fingers — the part that matters most for gun handling — came back **below the 80 % detection
threshold on all 40 joints**. The instrument is weakest exactly where the job is hardest.

**The industry does not do this either.** Shipped FPS games hand-key weapon handling — reload,
inspect, equip, charge — and use mocap for interaction motion (climbing, vaulting, melee) where
organic weight is the point. Where studios shoot weapon footage at all, it is **reference for
keyframe work, not final output.** You reached this yourself on 7/31; the research confirms it.

**The NPC work is not actually failing.** Your own verdict was *"came out well that way, it just
took some adjusting."* The adjusting is the tax, and it has one dominant cause — the same missing
depth, showing up as foot slide, floaty hips, and contacts you have to re-solve by hand.

**And a large share of your pain was never mocap at all.** On 7/31 there were four stacked
defects — a stale installed addon, a feature declared and implemented nowhere, autoscale
measuring the wrong bones, a preview that drew nothing. Every one presented as "the mocap is
bad." The pipeline's failure mode is a plausible-looking wrong answer. **That is the real
enemy.**

---

## THE FINDING THAT CLOSED THE OBVIOUS ANSWER

I went looking for "which solver replaces MediaPipe," and there are excellent candidates. WiLoR
detects hands in **86.9 %** of in-the-wild frames against MediaPipe's **66.5 %** — that is
precisely our finger problem. GVHMR is gravity-aware and world-grounded, which is precisely our
float-and-slide problem.

**Then I read the licences, and they close the door.**

| Model | Licence | Ships in RECONgame? |
|---|---|---|
| **MediaPipe** (what you have) | **Apache 2.0** — explicit commercial + patent grant | **YES** |
| WiLoR | CC-BY-**NC**-ND, built on **MANO** | No |
| HaMeR | built on **MANO** | No |
| GVHMR · TRAM · NLF · SMPLest-X | all built on **SMPL / SMPL-X** | No |

SMPL grants use "for the sole purpose of performing **non-commercial** scientific research,
non-commercial education, or non-commercial artistic projects" and prohibits "incorporation in a
commercial product." MANO is the same family and adds an **explicit prohibition on military
use** — which a Vietnam War game plainly is.

So: **the entire academic state of the art is closed to us for shipped animation.** Commercial
licences exist (Meshcapade for SMPL; MPI for MANO), but that is a contract and an unknown
four-or-five-figure cheque, not a weekend upgrade.

**Two consequences, and they are the backbone of this decree:**

1. Stop shopping for solvers. MediaPipe stays, not because it is best, but because it is the one
   that is legally ours. **The fix has to be optical and procedural, not a model swap.**
2. These models remain fair game as **study instruments** — run footage through WiLoR to *see*
   what a hand does, then hand-key from it. Same doctrine as your reference models: studies, not
   ship assets.

---

## THE DECREE — SPLIT THE PIPELINE IN TWO AND NAME THEM

They are different problems. They want opposite things. Stop tuning one dial for both.

### LANE A — THE WEAPON LANE · *"video is a metronome, not a mocap source"*

Ratifies what your 7/27 decree already established (the weapon owns named contact points; the
gun leads, hands follow — the same convention as CoD `tag_weapon`, Lyra `ik_hand_gun`, Arma
`slot_*`). What is new is naming, precisely, what footage is allowed to contribute:

**Exactly three things, and nothing else:**
1. **Beat timing** — when the mag leaves, when it seats, when the bolt goes back, when the slap
   lands. Timing is a 1-D signal; depth error does not touch it. This is the *expensive* part of
   hand-keying and the part footage answers perfectly.
2. **Finger curl shape** — not position. Which fingers wrap, which stay clear.
3. **Body English** — how far the weapon cants toward the working hand. You have already
   measured that cant decides whether a forearm twists 179° or 23.8°.

**Hand position comes from the contact markers. Always. Never from video.**

**Build for this lane:**
- **`beats.json` per take** — auto-derived frame numbers for `mag_out`, `mag_in`, `bolt_back`,
  `bolt_forward`, `slap`, from hand-velocity zero-crossings and hand-to-prop distance minima in
  the take you already have. Your doctrine is already *"measure handoff frames, never guess
  them"* — this makes measuring them a one-liner instead of a constraint-influence bisection
  done by hand, per clip, per gun. **This is the single change that makes hand-keying cheaper.**
- **Extend the procedural life layer in Godot** (the P4 you deferred on 7/27). Every source I
  read named runtime sway/bob/weapon-lag/breathing as *the* biggest anti-robotic lever, and it
  is cheaper than any capture. **It also improves every clip you have already shipped,
  retroactively — nothing else in this document does that.**
  **Precondition:** an explicit procedural-vs-baked register. Anything the layer drives must not
  also be baked or it doubles — this is already why the reference `Idle`/`Walk`/`Run` clips are
  static in weapon space.

**Stop doing:** chasing better weapon footage. Full-profile shooting only helps when the motion
*arc* must come from video, and under this doctrine it never does.

### LANE B — THE BODY LANE · *"stop inferring depth, start measuring it"*

The depth number is the whole story, and there is exactly one legal fix: **a second camera.**

Two ordinary cameras plus triangulation turns inferred depth into measured depth. Pose2Sim and
FreeMoCap both do this with a printed ChArUco board waved once. Pose2Sim's published two-camera
geometry: **one camera in front, one at 45° to the side, both at hip level.** Measured joint
angle error across walking/running/cycling: **3.0° / 4.1° / 4.0°.** Their 2D stage is a pose
detector you already own and already licence cleanly — **so this stays Apache-2.0 all the way
through.**

You already own both cameras: the Integrated Webcam and your phone. The cost is a printout.

**Build for this lane:**
- **Two-camera triangulation as a second backend behind `take.json`.** The architecture already
  anticipated this — solvers are pluggable, `take.json` is the only contract. Nothing downstream
  changes: the addon, the contact solver and the retarget presets all keep working.
- **Make `caleb_body_profile.json` a first-class input** rather than the convention it is today.
  Nothing currently consumes it automatically, so every retarget re-derives scale — and we have
  already been burned once by autoscale measuring the wrong chain and returning 3.99×.
- Keep the contact/plant solver as the last word regardless. **Measured contacts always beat
  solved ones.**

### CROSS-CUTTING — THE GATES · *"it must fail loudly"*

Four of your six most expensive incidents were defects in our own toolkit and **none of them
failed loudly.** Three cheap gates close those classes permanently:

1. **Capability contract test** — walk every property declared in `props.py` and every capability
   a backend advertises; assert a consumer exists outside the declaration and the UI row.
   `rest_delta` would have failed this on day one (it moved frame 0 by **17,243 mm**).
   `feature.preview` would have failed it on day one. ~60 lines. **Highest ROI in the repo.**
2. **Installed-extension hash gate** — `run_tests.ps1` fails loudly when the installed copy in
   `AppData\...\extensions\user_default\mocap_toolkit` differs from `addon/`, and the addon panel
   stamps its version + short hash. The stale copy made the FPS preset **unloadable in your
   Blender for days, invisibly.**
3. **Take triage gate at extract time** — promote `depth_report.py` from a report to a PASS/FAIL
   verdict that runs as the last stage of `cli extract` and says *what the take is usable for*:

```
TAKE VERDICT: caleb_mosin_p2 ......................... TIMING ONLY
  core detection      0.884   (gate >= 0.95)   FAIL
  depth share         0.51    (gate <= 0.35)   FAIL
  longest dropout     55 f    (gate <= 5)      FAIL
  hand->prop minimum  0.474 m (gate <= 0.15)   FAIL
  => beats: USABLE.  arcs: REJECT. Reshoot full profile, camera on the working side.
```

A take at 48 % depth is worthless for arcs and perfectly good for beats. **Today you find that
out three hours into a Blender session. This finds it while you are still standing in front of
the camera.**

---

## WHAT IS SACRIFICED — NAMED, PER THE SECOND LAW

- **Ratifying Lane A means admitting the toolkit's original motivation was misdirected.** You
  built it for weapon arms; the decree tells you to stop pointing it there. It is not wasted —
  Lane B uses it constantly — but that is the honest read.
- **"Hand-key it" is free advice that costs you every hour of it.** That is exactly why
  `beats.json` and the procedural layer are ranked where they are: they are the only two
  proposals that make hand-keying *cheaper*. Anything here that does not reduce hand-keying cost
  is decoration.
- **The second camera taxes the loop you actually like.** Position → "go" → record → verdict in
  minutes is why you shoot at all. Calibration, a second device, phone transfer and clap-sync
  break that rhythm, and a pipeline you stop using captures nothing. Also: the 3–4° figure comes
  from sports studies of walking and cycling — nobody has published what it does for a man
  kneeling behind sandbags working a bolt. **Hence: pilot, don't adopt.**
- **Sync is a real hazard.** Two devices with no genlock, mis-synced, produce *confidently wrong*
  3D — worse than honest monocular error, because it looks fine.
- **The Leap Motion Controller 2 was considered and rejected.** It is a desk sensor whose field
  of view suits hands over a keyboard, not a shouldered prop; it captures hands only, so it
  cannot give you weapon cant; and under Lane A doctrine it would buy finger shape alone. **No
  purchase recommended.**
- **The council never proved you need new footage at all.** You have 163 clips and 32 are
  unwired. Nothing in this decree requires shooting anything before Demo Day.

---

## ORDERED NEXT STEPS — ranked by player-visible value per hour

Demo Day is a 30-minute one-day arc and your playtest is the ship gate. These are **hours, not
weeks** — a pipeline-hardening sprint must not eat the demo.

| # | Work | Lane | Why it is here |
|---|---|---|---|
| 1 | **Procedural life layer extension** + procedural-vs-baked register | A | Improves every clip already shipped, retroactively. Zero of the four measured causes of "robotic" were mocap problems. |
| 2 | **Capability contract test** + installed-extension hash gate | X | ~60 lines each; closes the class that cost you the most. |
| 3 | **`beats.json` timing extraction** | A | The only thing that makes the correct (hand-keyed) weapon workflow cheaper. |
| 4 | **Take triage gate** with PASS/FAIL verdict | X | Stops wasted capture sessions at the camera instead of in Blender. |
| 5 | **Two-camera pilot — ONE take, measured** | B | Right long-term answer for NPC bodies. **Kill it if it costs more than ~10 extra minutes per session.** |
| 6 | `caleb_body_profile.json` as a first-class input | B | Removes a re-derivation that has already produced a 4× error once. |
| 7 | *(deferred, not rejected)* commercial SMPL/MANO licence | — | Reopens the SOTA solvers. Not at demo scope. |

---

## WHAT I NEED FROM YOU IN THE MORNING

Four rulings, and I will not proceed on any of them without your word:

1. **Ratify Lane A doctrine?** "Video supplies beats, finger shape and body English. Hand position
   comes from contact markers, always." This is the load-bearing decision — everything else
   follows from it.
2. **Approve the two-camera pilot** — one take, measured session cost, kill threshold ~10 minutes?
   Or leave the monocular loop alone because you like it and it works?
3. **Confirm the ordering above**, particularly the procedural life layer at #1 ahead of anything
   capture-related.
4. **Is 163 clips with 32 unwired the better use of the next animation hours than any of this?**
   The devil's advocate raised it and nobody in the room could return it.
