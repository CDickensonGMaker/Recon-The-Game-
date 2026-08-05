# Making a Huey crew look like they are flying it

Reference pack, 2026-08-05. Research + writing only — no Blender was opened and no asset
was touched for this document. `assets/us/vehicles/huey_v3.blend` was under construction
by another agent while this was written and was deliberately left alone.

Companion document: `production/research/huey_loading/NOTES.md` (the boarding half, and the
hard-won rules about what footage is and is not usable). Read it first if you have not.

**The single most important thing in this document is the honesty split.** I could not watch
video. Every line below is tagged so the animation agent knows what it is standing on:

- **[TEXT]** — stated in a written source I actually fetched and read. Cited.
- **[DERIVED]** — arithmetic off a [TEXT] number or off standard anthropometry. Shown.
- **[UNVERIFIED]** — plausible, commonly believed, *not* confirmed by anything I read.
  **Do not author to an [UNVERIFIED] line without Caleb's eye on it first.**

---

## 0. The constraint that reframes the whole job — read before the footage

The pilot clips **already exist, are already named, and are already wired in shipped code.**
This is not a greenfield spec. `scripts/vehicles/seat_system.gd:55-61`:

```
const PILOT_CLIP        := "cockpit_idle"          # ground hold
const PILOT_CLIP_PANEL  := "pilot_flips_switches"  # one-shot on touchdown
const PILOT_CLIP_FLYING := "cockpit_controls"      # airborne
const PILOT_PANEL_S: float = 4.03                  # measured off anim_library.glb
const SITTING_CLIP      := "sitting"               # every pax AND both gunners
```

`_pilot_clip()` (`seat_system.gd:122-130`) can express exactly **three** pilot states:

| Helicopter state | clip played |
|---|---|
| `LANDED`, within 4.03 s of touchdown | `pilot_flips_switches` (one-shot) |
| `LANDED`, after that | `cockpit_idle` (hold) |
| `CRASHING` / `DESTROYED` | `cockpit_idle` |
| **everything else — the entire flight envelope** | `cockpit_controls` (hold) |

Three findings fall straight out of that, before any footage:

**F-1. There is no takeoff, cruise, approach, flare or touchdown state in the code.**
Lift, 90-knot cruise and a hot-LZ flare all play the same looping `cockpit_controls`. Every
per-state clip in this document beyond the four existing names costs a `_pilot_clip()` change.
They are listed separately in §7 for exactly that reason. Do not assume they can be added.

**F-2. Both pilots get the SAME clip.** `seat_system.gd:153-154` loops
`[&"seat_pilot_l", &"seat_pilot_r"]` and dresses both with one `_pilot_clip()` string. The
footage-and-doctrine answer (§3) is that the two men are doing visibly *different* things —
one is flying, the other is on the radio, the map, or guarding the controls. **A copilot
variant needs a code change.** Surfacing this rather than papering over it; a mirrored
identical pair reads as a bug at any distance where the greenhouse is legible.

**F-3. Both door gunners play `sitting`.** That is the same clip a passenger plays. A gunner
on a perch with both hands on an M60 is the most-seen crew member on a flyby — he is on the
outside of the airframe, at eye level, unoccluded — and he is currently doing nothing.
**This is the highest-value single clip in the whole pack** (§6, §7 Tier C).

`cockpit_dead` also exists in `anim_library.glb` (0.30 s, 7.2 f) and is deliberately **not**
wired (`seat_system.gd:53-54`, ADR-023 — no pilot damage model in the ADR-029 slice). Leave it
alone; do not "restore" it, do not propose work against it.

### The measured library — all four clips exist

Measured **2026-08-05 straight out of `assets/shared/anim_library.glb`** by parsing the glTF
animation-sampler input accessors (min/max keyframe time). No Blender involved, so this is
repeatable while someone else is driving a Blender session. 183 actions total.

| Clip | Keyframe span | **Duration** | @24 fps | Role |
|---|---|---|---|---|
| `cockpit_idle` | 0.033 → 4.033 | **4.000 s** | 96.0 f | ground hold, LOOP |
| `cockpit_controls` | 0.033 → 1.633 | **1.600 s** | 38.4 f | **entire airborne envelope**, LOOP |
| `pilot_flips_switches` | 0.033 → 4.033 | **4.000 s** | 96.0 f | touchdown one-shot |
| `cockpit_dead` | 0.033 → 0.333 | **0.300 s** | 7.2 f | unwired, ADR-023 |
| `sitting` | 0.033 → 4.767 | **4.733 s** | 113.6 f | pax **and both gunners** |
| `board_heli` | 0.000 → 1.333 | **1.333 s** | 32.0 f | boarding, shipped 2026-08-04 |

**This is not a case of code pointing at missing clips.** All four names resolve. The problem is
what the clips *are*, not whether they exist.

**F-4 — `PILOT_PANEL_S` is off by one frame, and here is exactly why.** The constant is **4.03**
(`seat_system.gd:60`) and the clip's **duration is 4.000 s** — its *last keyframe timestamp* is
4.033. Whoever set the constant read the end time, not the span. **The error is 0.033 s (one
frame at 24 fps) and it is harmless** — it makes the pilot hold the panel pose one frame longer
before falling through to `cockpit_idle`. Recording it because the comment at
`seat_system.gd:58-59` says "measured off anim_library.glb," which reads as verified, and the
next person to re-derive it will get 4.000 and think something drifted. **Do not "fix" this
without a reason; do not cite 4.03 as the clip length.** The clip is 4.000 s. The constant is a
timeout, and 4.03 is a fine timeout.

**F-5 — `cockpit_controls` is 1.6 s long and it plays for the ENTIRE airborne portion of every
flight.** This is the most consequential measurement in the pack and it is dealt with in §3.3.

**Loop status is already asserted in code.** `scripts/visuals/model_actor.gd:337-339` lists
`sitting`, `cockpit_idle` and `cockpit_controls` as looping, with a comment saying
`pilot_flips_switches` and `cockpit_dead` are held out because one is a one-shot panel run and
the other a slump. So the three holds are **contractually seamless loops**, and
`pilot_flips_switches` is a **one-shot on a hard 4.03 s budget** — the code times the
fall-through off that exact number. Replace it at a different length and `PILOT_PANEL_S` must
change in the same edit.

**Seat convention.** `FALLBACK_LAYOUT` (`seat_system.gd:36-41`) documents `Door_Left side = +X`,
nose = −Z. So `seat_pilot_l` at x **+0.55** is the left seat and `seat_pilot_r` at x **−0.55**
is the right. **The pilot-in-command flies the RIGHT seat** (`seat_pilot_r`, x = −0.55); the
copilot is LEFT (`seat_pilot_l`, x = +0.55). US helicopter convention, and the reason is
mechanical: the collective is a left-hand control, so the right-seater's left hand can stay on
the collective while his right hand reaches the centre console. **[TEXT]** — collective is
"to the left of the pilot's seat" is stated generally for small helicopters; see §2 for what I
could *not* pin down about the Huey specifically.

---

## 1. Sources

I could not watch a single frame. This is the same wall the `huey_loading` notes hit: YouTube
serves the fetcher a footer and a copyright notice, nothing else — no description, no
duration, no transcript. **So I am not going to invent timecodes.** The video list below is a
*watch queue* with what the title and search metadata claim, flagged as unwatched. Everything
substantive in §2–§6 comes from the text sources, which are real and were read.

### Text sources — read, quoted, load-bearing

| Source | What it gave me |
|---|---|
| **[TM 55-1520-210-10, Operator's Manual, Army Model UH-1H/V](https://milviz.com/Online_products/Manuals/UH-1H_Flight_Manual.pdf)** — **the primary source, and it outranks everything below it** | *"Complete controls are provided for both pilot and copilot."* Hydraulic assist *"minimizes the force required by the pilot to move the cyclic, collective and pedal controls."* **Force trim**: force centering devices in the cyclic and directional pedal controls, fitted between the stick/pedals and the hydraulic servo cylinders, that *"furnish a force gradient or 'feel'"*; zeroed by the **push-button switch on the cyclic grip** or the FORCE TRIM switch on the miscellaneous control panel. **Collective breakaway force 8–10 lb up from neutral, boost ON.** **Synchronized elevator** on the tail boom, linked to fore-and-aft cyclic. **Stabilizer bar** on the rotor hub trunnion, 90° to the blades |
| [AOPA — The Bell UH-1B Huey: A Flying Symbol](https://www.aopa.org/news-and-media/all-news/2014/march/pilot/1403p_huey) | Twist-grip throttle on the collective; 6,600 engine / 324 rotor rpm; **governor holds rpm after start**; 60 kt climb, 85–95 kt cruise, 120 kt Vne buffet; synchronized elevator linked to cyclic |
| [FAA Helicopter Flying Handbook, hovering excerpt](https://data.ntsb.gov/Docket/Document/docBLOB?ID=40406932&FileExtension=.PDF&FileName=Excerpts+From+FAA+Helicopter+Flying+Handbook-Master.PDF) | Cyclic holds position, collective holds altitude, pedals hold heading; corrections are **pressure, not movement**; "a number of small corrections to avoid overcontrolling" |
| [Flight-Study — Vertical Takeoff to a Hover](https://www.flight-study.com/2020/01/vertical-takeoff-to-hover-helicopter.html) | Order of inputs on lift; "**remain focused outside the aircraft**"; ground reference point; cyclic drift correction bleeds vertical thrust → more collective → more pedal |
| [avstop — Basic Helicopter Handbook ch.11](http://avstop.com/ac/basichelicopterhandbook/ch11.html) | Approach: aft cyclic for speed, collective for descent; flare: up collective + **coordinated left pedal**; after touchdown cyclic **slightly forward of neutral** to tilt the disc off the tailboom |
| [copters.com — Hovering](https://www.copters.com/pilot/hovering.html) | The **quarter-inch** cyclic figure; cyclic is an acceleration control; "constant control inputs and corrections" |
| [Centaurs in Vietnam — Door Gunners](https://www.centaursinvietnam.org/WarStories/WarDiscussions/D_DoorGunners.html) | First-hand: monkey harness ~10 ft strap to the cabin floor; bungee vs pintle vs free-held; "shoot up, down, behind and way in front, and underneath"; **fire back under the tailboom going into or out of an LZ**; crew chief LEFT door, gunner RIGHT; crew chief out on the **skid** to direct the pilots on a LRRP extraction |
| [American Rifleman — When Pigs Fly: the heliborne M60](https://www.americanrifleman.org/content/when-pigs-fly-the-heliborne-m60-machine-gun-in-vietnam/) | Bungee suspension became common as the war went on; increased firing angles |
| [Warbird-photos — Huey door gunner threads](https://www.warbird-photos.com/gpxd/viewtopic.php?t=1657) | **Slick vs gunship split**: slicks = pintle mount + a gunner's **seat** + a large ammo bin; gunships = M60 hung from the ceiling on a bungee. Pintle is less mobile, more stable |
| [Wikipedia — Door gunner](https://en.wikipedia.org/wiki/Door_gunner) | Gunner also loads/unloads the aircraft and assists the crew chief; in-flight observer duties |
| [VHPA — LRRP, Charlie Ostick](https://www.vhpa.org/stories/lrrp.pdf) | **"Clear my tail rotor"** — on approach the pilot calls it and *both* crew chief and gunner put their heads out the door to watch tail clearance |
| [Wikimedia Commons — Cockpit of the UH-1 family](https://commons.wikimedia.org/wiki/Category:Cockpit_of_Bell_UH-1_Iroquois_family) | Photo set: individually captioned **collective lever**, **cyclic stick**, **control pedestal**, three cockpit-console views, two overhead-panel views (ROKAF UH-1B, Jeju Aerospace Museum, 2014). This is the geometry reference — stills, not motion |
| [DCS UH-1H Flight Manual (PDF)](https://www.digitalcombatsimulator.com/upload/iblock/7c7/DCS%20UH-1H%20Flight%20Manual_EN.pdf) | **Not readable** — the fetcher returned binary. Listed so nobody burns a second pass on it |

**Fetch note on the -10, so the next person does not repeat the attempts.** The milviz PDF is
the real manual but **exceeds the fetcher's 10 MB limit** and cannot be pulled whole. The
pdfcoffee, scribd, manualzz and ED-forum mirrors all return **HTTP 403**. Everything quoted from
the -10 above was recovered through **search-result extraction**, which returns the manual's
sentences but **not their page or paragraph numbers**. The quotes are verbatim and consistently
corroborated across independent mirrors, so I am treating them as reliable — but **if a number
is ever going to be argued over, open the PDF locally and cite the paragraph.** The 8–10 lb
collective breakaway figure in particular deserves that treatment before anyone tunes to it.

### Video watch queue — NOT WATCHED, no timecodes claimed

Everything here is title-and-metadata only. **Whoever watches these should append real
timecode windows to this table.** That is the single most valuable follow-up to this document.

| URL | Claimed content | What it would be good for |
|---|---|---|
| [youtube.com/watch?v=mRUFRebsBzU](https://www.youtube.com/watch?v=mRUFRebsBzU) — "Original Bell UH-1 Huey: helicopter flight controls, cyclic stick, collective, anti-torque pedals" | Real airframe, controls demonstrated | **Highest priority.** Control geometry + how far each control actually travels. This is the amplitude source |
| [youtube.com/watch?v=cPJqvM0cWp4](https://www.youtube.com/watch?v=cPJqvM0cWp4) — Huey UH-1H walkaround, Gary Gingrich, Mid America Flight Museum | Restored airframe walkaround | Cockpit layout, seat, door gun station, skid height. Geometry, not motion |
| [youtube.com/watch?v=ugu_D3yKM_E](https://www.youtube.com/watch?v=ugu_D3yKM_E) — UH-1H cockpit familiarization (DCS) | Sim cockpit tour | Panel/console naming so `pilot_flips_switches` reaches the *right* switches. Sim geometry is faithful; sim *hands* are not a motion source |
| `scratchpad/huey_footage.mp4` | Already in the repo. 712 s Vietnam colour compilation, dense-sampled 2026-08-04 (`ART_Track_Log.md:314-331`). Usable segments logged: ~22–42 s, ~202–218 s, ~326–358 s, ~415–440 s, **~645–660 s** | The 645–660 s window is the in-flight open-door material (men with feet out the door). **Re-sample that window for the door gunner**, it was mined for passengers and not for the gun station |

**Do not propose film footage as a source.** `We Were Soldiers` is settled: the cleanest
continuous take in it (82 % presence, 3 % contested) still retargeted onto PSXRig as a
collapsed splayed heap, because 360p + dark uniforms against a dark cabin gives the detector
enough to assert a confident 2D skeleton over garbage depth. See `huey_loading/NOTES.md:42-66`.
Cockpit interiors are *the same lighting problem, worse* — a dark cabin, a bright greenhouse
behind the subject, and the hands are the thing you care about.

---

## 2. The cockpit the hands must actually touch

The controls are being modelled right now as real geometry. Hands must **contact** it, so this
section is about where the geometry is. Numbers here are **[DERIVED]** unless marked — they are
starting values to *check against* `huey_v3.blend`, not values to trust.

**Man height 1.674 m** (project standard). Standard anthropometric fractions off stature:

| Segment | Fraction | At 1.674 m |
|---|---|---|
| Sitting height (seat pan → top of head) | 0.520 | **0.870 m** |
| Shoulder height, seated (above pan) | 0.360 | **0.603 m** |
| Upper arm (shoulder → elbow) | 0.186 | **0.311 m** |
| Forearm (elbow → wrist) | 0.146 | **0.244 m** |
| Hand length | 0.108 | 0.181 m |
| Knee height, seated (floor → knee top) | 0.285 | **0.477 m** |
| Buttock → knee | 0.245 | **0.410 m** |

**Comfortable reach, shoulder → grip centre ≈ 0.311 + 0.244 + 0.09 = 0.645 m fully extended,
≈ 0.50–0.55 m at a working elbow angle.** That is the honest envelope. Anything the spec asks
a hand to touch must fall inside it from a seated shoulder 0.603 m above the seat pan.

### Cyclic — right hand, between the knees **[TEXT: layout] [DERIVED: numbers]**
Rises from the floor between the knees, canted aft so the grip meets the hand naturally.
Grip centre lands around **knee height ± 0.06 m**, i.e. ~**0.45–0.55 m above the cabin floor**,
and roughly **0.30–0.40 m forward of the seat back** **[DERIVED]**. The grip is a pistol grip;
the hand wraps it with the **forearm resting on or near the right thigh** — this is why the
motion can be so small: the thigh is the fulcrum, not the shoulder.

**The system is hydraulically assisted**, which the -10 says *"minimizes the force required by
the pilot to move the cyclic, collective and pedal controls"* **[TEXT]**. Low force is what
permits the continuous fingertip-scale correction described in §3.3.

**The FORCE TRIM system, and the thumb beat it gives you [TEXT].** The -10 describes **force
centering devices incorporated in the cyclic controls and the directional pedal controls**,
fitted *between the cyclic stick and the hydraulic servo cylinders, and between the anti-torque
pedals and the hydraulic servo cylinder*, which *"furnish a force gradient or 'feel'"* to the
cyclic stick and the pedals. Forces can be reduced to zero by **pressing and holding the force
trim push-button switch on the cyclic grip** (or by moving the FORCE TRIM switch on the
miscellaneous control panel to OFF).

Two things fall out of that, and both are authorable:

1. **The stick and the pedals are always loaded.** There is a spring gradient pulling toward the
   trimmed position at all times. The pilot is not waving a free-floating stick around — he is
   working *against* a force, continuously. This is the mechanical basis for §3's core finding
   and it is a far stronger citation than a general handbook remark about "pressure."
2. **There is a button under the right thumb, and it gets pressed.** Re-trimming means
   **thumb down on the force-trim switch on the cyclic grip, reposition, release.** That is a
   small, specific, repeating, *period-correct* hand detail that costs almost nothing to
   animate and that nobody would invent. **Put it in `cockpit_controls`.** It is the single
   best small beat available for the flying pilot, whose hand is otherwise pinned to the grip.

**[UNVERIFIED]** — I did not confirm what *else* is on the Huey cyclic grip (trigger, ICS/radio
switch, hat). The force-trim button is confirmed; do not model the rest from imagination.

### Collective — LEFT hand, LEFT of the seat **[TEXT — RESOLVED]**

**Settled.** Collective is to the **LEFT of each pilot's seat and worked by the LEFT hand**;
cyclic is between the knees in the **RIGHT** hand. Universal helicopter layout, and the -10
confirms *"Complete controls are provided for both pilot and copilot"* — a full cyclic,
collective and pedal set at each seat. An earlier draft of this document flagged the
outboard/inboard question as unverified; it is now closed, and the answer carries a consequence
that changes the animation.

> **THE TWO COLLECTIVES ARE NOT MIRRORED. This is the most important geometric fact in the
> document.**
>
> Both are left-of-seat and left-handed, but the seats face the same way on opposite sides of a
> centre console. So:
>
> | Seat | Occupant | Collective sits | Left arm reaches |
> |---|---|---|---|
> | RIGHT (`seat_pilot_r`, x = −0.55) | **pilot** | **INBOARD** — toward the centre console | across the body, *toward* the other man |
> | LEFT (`seat_pilot_l`, x = +0.55) | **copilot** | **OUTBOARD** — toward the door | away from the body, *toward* the door |
>
> The two men's left arms reach in **opposite directions relative to their own bodies**. A
> cockpit is not left-right symmetric and **a clip authored for one seat cannot be mirrored onto
> the other** — mirroring puts the copilot's left hand where the pilot's centre console is. This
> is not a polish issue; it is a hand floating in empty air.

This is the geometric argument that makes **B-1 `copilot_controls` structural rather than
cosmetic** (see §3.7). Even a hypothetical "both men flying identically" case still needs two
different clips, because the collective is in a different place relative to each body.

**Mechanically** it is a lever pivoting near the floor, swept up and back, gripped **left hand,
palm down**, with a **motorcycle-style twist-grip throttle** at its far end **[TEXT — AOPA]**.
Grip vertical travel from full-down to a cruise setting is **[DERIVED] ~0.10–0.15 m** at the hand.

**Control force — and this one directly shapes the motion [TEXT]:** the collective has a built-in
**breakaway (friction) force of 8–10 lb to move it UP from neutral, with hydraulic boost ON.**
That is a real, deliberate, two-fingers-won't-do-it push. Contrast it with the hydraulically
assisted cyclic (below), which the -10 describes as taking minimal force. **This is the physical
reason the two arms move completely differently and it should be visible in the animation:**

- **Left arm / collective: slow, committed, effortful.** Few movements, each one meant. Shoulder
  and back engaged, not just the wrist. It stays put between changes because moving it costs 8–10 lb.
- **Right arm / cyclic: constant, tiny, near-effortless.** Forearm resting on the thigh, wrist and
  fingers doing the work.

An animation where both arms fidget at the same rate is wrong, and now there is a number saying why.

### Anti-torque pedals — both feet **[TEXT]**
Floor-mounted, forward of the seat, ~**0.55–0.70 m** forward of the seat back **[DERIVED]** for a
1.674 m man with a slightly-bent knee. **Both feet stay on the pedals at all times** in every
flight state. They move differentially — one forward is the other back — on a common linkage.
Hydraulically assisted, and **force-centred like the cyclic** (§ above) — so the pedals also have
a spring "feel" and a home position they are always being worked against **[TEXT]**.

### Centre console and overhead **[TEXT — Wikimedia captions confirm both exist]**
Console (radio pedestal) between the seats, forward of the pilots' inboard thighs. Overhead
console above and slightly forward of the pilots' heads. **These are the two destinations for
the "hand leaves the controls" beats**, and the overhead one is the more readable of the two
on a flyby because the arm rises through the greenhouse glass. The **FORCE TRIM ON/OFF switch is
on the miscellaneous control panel** **[TEXT]** — a legitimate, named destination for
`pilot_flips_switches` rather than a generic reach.

### Two moving parts on the OUTSIDE — for whoever builds the airframe

Not animation, but they belong in the record because they are visible external geometry driven by
the pilot's hands, and both are named in the -10 **[TEXT]**:

- **Synchronized elevator** — on the **tail boom**, *"connected by control tubes and mechanical
  linkage to the fore-and-aft cyclic system."* **It moves with fore/aft cyclic.** So the flare
  (§3.5), which is the biggest cyclic input in the pack, should visibly deflect the elevator on
  the tail boom. A free external tell that the pilot is doing something, readable at a distance
  where the hands are not.
- **Stabilizer bar** — *"mounted on the main rotor hub trunnion assembly in a parallel plane,
  above and at 90 degrees to the main rotor blades."* Its gyroscopic and inertial effect damps
  the rotor. It is the distinctive weighted bar across the top of the Huey's rotor head and it
  spins with the mast. **Silhouette-defining — if it is missing from the rotor head the ship does
  not read as a Huey.**

Flagging both to the airframe build; they are out of scope for this animation pack.

---

## 3. Pilot and copilot, per flight state

**The governing fact, and it is the one that makes this animation work: the right hand is never
still and it never moves far.** Both halves matter — an animator who makes it still gets a
mannequin, an animator who makes it move gets a man fighting a broken hydraulic.

**The mechanical basis is in the -10, not in general airmanship advice.** The cyclic and the
pedals carry **force centering devices that "furnish a force gradient or 'feel'"** **[TEXT]**.
The stick is *always spring-loaded toward its trimmed position* and the pilot is *always working
against that load*. That is why the hand cannot leave and why the motion is continuous. The
FAA's "**pressure rather than abrupt movements**" and "a number of small corrections to avoid
overcontrolling" **[TEXT]** describe the *technique*; the force gradient is the *reason*.

Amplitude anchor: copters.com puts the deliberate hover input at about a **quarter of an inch**
of cyclic **[TEXT]** = **6.35 mm**.

**One honest correction to an earlier draft of this document.** It said "a Huey is never trimmed
hands-off." That overstated it. Force trim exists and *does* let the pilot set a trimmed stick
position and reduce sustained effort — that is its entire purpose. What remains true, and is what
the animation needs, is that **the slick has no autopilot, the ship still requires continuous
correction, and the flying pilot's hand stays on the stick.** Trim reduces the *force*, not the
*attention*. **[The absence of an autopilot in the -10 slick is [UNVERIFIED] — I did not find a
sentence stating it. Everything else in this paragraph is [TEXT].]**

**Quarter inch = 6.35 mm.** That is the *deliberate* input for a commanded drift. The
involuntary chatter riding on top of it is smaller. Working amplitudes below are **[DERIVED]**
from that anchor and must be sanity-checked against the mRUFRebsBzU video when someone watches it.

### 3.1 Idle on the ground, rotor turning — `cockpit_idle` (LOOP, exists)

| | |
|---|---|
| Collective | **Full down**, hard against the stop. Left hand rests on it, wrist relaxed, **no vertical travel at all**. This is the single clearest ground-vs-air read: on the ground the left arm is LOW **[TEXT]** |
| Twist grip | **Static.** The governor holds 6,600/324 rpm after start; there is no throttle management in flight **[TEXT — AOPA]**. The twist grip moves during **start and shutdown only.** Do not animate a throttle roll in any flying clip |
| Cyclic | Right hand on the grip, **near-neutral**, drift ≤ ±3 mm, very slow. The ship is on its skids; nothing is being corrected |
| Pedals | Both feet on, **neutral, static** |
| Head / gaze | Slow, wide, unhurried scan **outside** — out the chin bubble, across the panel, out the side. Longest dwell of any state. This is where the "waiting" reads |
| Hand off controls | **Yes, and this is where the human beats belong.** Ground hold is the only state with slack in it. Right hand off the cyclic to the centre console, a glance down, back. Occasional overhead reach |

**Loop:** seamless. This is a hold that can run for minutes.

### 3.2 Lift to a hover / takeoff — **no state in code** (§7 Tier B)

The FAA/Flight-Study sequence, in order **[TEXT]**:
1. Cyclic set neutral or slightly into wind.
2. **Collective raised very slowly** until the ship is light on the skids — the left hand
   rises **[DERIVED] 0.10–0.14 m** over ~2–4 s, slow and even.
3. **Pedal pressure and counter-pressure to hold heading throughout.** Increasing collective
   increases torque; a US main rotor turns counter-clockwise from above, so the fuselage wants
   to yaw right and the pilot answers with **LEFT pedal** **[TEXT — avstop states the
   collective/left-pedal coordination explicitly for the flare]**. **[DERIVED] left pedal
   forward ~15–30 mm, held.**
4. Cyclic coordinated for the vertical ascent, then continuous small corrections as the ship
   breaks ground effect and starts to wander.
5. Eyes **outside**, locked on a ground reference point **[TEXT]**.

**The interlock is the whole beat, and it is what sells it:** correcting a drift with cyclic
diverts vertical thrust, so the pilot loses altitude, so he adds collective, so he needs more
pedal **[TEXT]**. All three limbs move together on lift. If the animation has the collective
arm rising and the feet frozen, it is wrong.

**One-shot.** Lift is a transition, not a hold.

### 3.3 Cruise — `cockpit_controls` (LOOP, exists)

85–95 kt in a slick, 85 with guns and the doors off **[TEXT]**. Forward flight is the most
stable regime the Huey has, and the AOPA pilot calls it "honest, stable and relatively easy"
**[TEXT]** — so cruise is the *calmest* airborne state, but still never still.

| | |
|---|---|
| Cyclic | Continuous micro-correction, **[DERIVED] ±3–6 mm at the grip**, irregular, no fixed beat. Do not build it on a sine wave — a periodic wobble reads as a machine. Layer two or three incommensurate low-frequency drifts, roughly **0.3–1.5 Hz**, so the loop never obviously repeats. Cyclic is slightly **forward** of the hover position |
| **Right thumb** | **Press-and-hold the force-trim button on the grip, reposition, release** — once or twice per loop **[TEXT — the button is confirmed]**. The one small human beat available to a hand that cannot leave the stick. **Author it** |
| Collective | Set and largely still, **[DERIVED] ±5–10 mm** for power trim. Left arm is **raised** relative to the ground state — the key silhouette difference. Moves are **slow and committed**, never fidgety: 8–10 lb breakaway **[TEXT]** |
| Twist grip | Static (governor) |
| Pedals | Small, held trim inputs. **[DERIVED] ±5–10 mm.** Feet do not leave the pedals |
| Head / gaze | Mostly forward and outside, with periodic sweeps left/right and down through the chin bubble. **[DERIVED] ±20–30° yaw, one sweep every 4–8 s.** In-cockpit glances at the panel are short — under a second |
| Hand off controls | This is where the copilot beats live (§3.7) |

**Loop:** seamless, and this one carries most of the runtime.

#### F-5 — the 1.6 second problem, stated plainly

**`cockpit_controls` is 1.600 s long** (measured, §0). It is the only thing the pilot plays from
liftoff to touchdown. So on a thirty-second flyby the viewer sees the same 1.6 s of arm motion
**nineteen times**.

**That will read as a mechanical tic, and it will read as one for a specific reason.** A 1.6 s
loop sits at **0.625 Hz** — right in the middle of the 0.3–1.5 Hz band where a real pilot's
corrections live. So the repeat frequency is *indistinguishable from the motion frequency*: the
eye cannot separate "the pilot is correcting" from "the clip restarted." Every correction lands
on the same beat, at the same amplitude, in the same direction. That is a metronome, and a
metronome is the one thing a hand on a cyclic is not. §4 rule 3 says "no periodic cyclic wobble" —
**a 1.6 s loop makes the whole clip the wobble**, regardless of how the interior is animated.

**Recommendation: re-author `cockpit_controls` at 10–14 s.** Reasoning, not taste:
- The slowest correction drift worth showing is ~0.3 Hz ≈ 3.3 s. A loop needs to contain several
  cycles of its slowest component or the seam falls inside a stroke.
- Three or four incommensurate drifts (say 0.35, 0.6 and 1.1 Hz) only stop looking periodic once
  the window is long enough to show their beat pattern — **roughly 8 s minimum, 12 s comfortable.**
- The head sweep in §3.3 is one full pass every 4–8 s. **A 1.6 s clip cannot contain even one
  head sweep.** That alone forces the length up. This is why the current clip almost certainly has
  a static head, and why the pilot reads as a mannequin at exactly the distance where the
  greenhouse becomes legible.
- 12 s at 24 fps = 288 frames. Compare `sitting_talking` at 1,058 frames, already in the library.
  **This is not an expensive clip by this project's standards.**

**Cost: zero code.** `cockpit_controls` is a Tier A name — length is not referenced by any
constant (unlike `pilot_flips_switches`/`PILOT_PANEL_S`). Making it longer is a pure asset change.
**This is the highest value-per-effort item in the cockpit half of the pack.**

`cockpit_idle` at 4.000 s has the same disease more mildly — it is a *ground* hold that can run
for minutes, and 4 s of it is 0.25 Hz repeat. It should also grow, to **12–20 s**, and it has more
room to earn the length because §3.1 says the ground hold is the one state with slack for the
human beats. Lower priority than `cockpit_controls` only because a parked ship is less watched.

### 3.4 Approach — **no state in code** (§7 Tier B)

The most *visibly different* state in the whole envelope, and the best value per clip after
the gunner:

| | |
|---|---|
| Cyclic | **Aft** to bleed airspeed **[TEXT]**, and the amplitude comes UP. As the ship slows below effective translational lift it becomes progressively less stable — corrections grow from cruise's ±3–6 mm toward hover-scale **[DERIVED] ±6–12 mm**, and get faster |
| Collective | Lowered to establish the descent (~500 fpm at ~50 mph in the handbook's normal approach **[TEXT]**), then progressively worked. Left arm comes **down** through the approach |
| Pedals | Working continuously. Every collective change wants a pedal answer **[TEXT]** |
| Head / gaze | **Locked on the intended touchdown point.** This is the strongest single gaze read in the pack — cruise's wandering scan collapses to a fixed downward-forward stare. It also happens to be a cheap, extremely legible change |
| Crew | The pilot **calls "Clear my tail rotor"** and the crew chief and gunner put their heads out **[TEXT — VHPA]**. See §6 |

**Loop** while the approach lasts, but it must be authorable as a blend target from cruise.

### 3.5 Flare — **no state in code** (§7 Tier B)

Short, violent, and the most dramatic pose in the set:
- **Nose pitches up** — a decisive **aft cyclic** pull, far larger than anything else in this
  document. **[DERIVED] 40–80 mm of aft grip travel**, i.e. an order of magnitude above cruise.
- **Up collective** to check the descent **[TEXT]**, left arm rising sharply.
- **Coordinated LEFT pedal with that collective increase, to hold heading** **[TEXT — this is
  stated explicitly in the handbook and is the one pedal input I can cite by direction].**

All three limbs move hard, together, in under two seconds. **One-shot.** If only one clip from
Tier B ever gets authored, this is the one — it is the only moment in the flight envelope where
a viewer can see the pilot *doing* something.

### 3.6 Touchdown and ground contact — partly covered by `pilot_flips_switches`

**[TEXT]** After surface contact: cyclic goes **slightly forward of neutral** to tilt the rotor
disc **away from the tailboom**; pedals hold heading; collective comes down to the stop.

That forward-of-neutral cyclic is a real, specific, checkable pose and it should be the
**terminal pose of any touchdown clip and the resting pose of `cockpit_idle`.** It is not
neutral. A cyclic parked dead-centre on the ground is subtly wrong.

The existing `pilot_flips_switches` (4.03 s one-shot) fires here. **It is well placed** — a
crew that has just put the ship down does run the panel. Do not move it. If it gets re-authored,
the lead-in should start from the forward-of-neutral cyclic pose so it stitches cleanly to
`cockpit_idle` on fall-through.

### 3.7 Copilot — the finding, now with a geometric proof

**The code dresses both seats with the same clip (F-2).** When this document was first drafted
that was a *behavioural* argument — the two men do different things. **The -10 upgrades it to a
geometric one, and geometry is not arguable.**

> **A single shared clip is not merely a missed opportunity. It is broken by construction.**
>
> Both collectives are left-of-seat and left-handed, but the right-seater's is **inboard** and the
> left-seater's is **outboard** (§2). The two left arms therefore reach in **opposite directions
> relative to their own bodies.** One clip cannot satisfy both. Mirroring makes it worse, not
> better — it swaps the hands. **Whichever seat the clip was authored for, the other man's left
> hand is holding air**, and §8's G-2 hand-contact gate fails it outright at whichever seat it
> was not authored for.

The -10's *"Complete controls are provided for both pilot and copilot"* **[TEXT]** means there is
no dodge available: the copilot's controls are really there, so his hands really have to be on
them, and they are not where the pilot's are.

The behavioural layer sits on top of that:
- **Only one man flies at a time.** The other's hands are free, or *lightly guarding* the
  controls — resting near but not gripping, which is a distinct and readable pose.
- The non-flying pilot works the **radios on the centre console**, holds a **map or kneeboard**,
  reads the panel, and points **[UNVERIFIED as a per-state pattern — standard crew practice and
  the console geometry is confirmed, but I found no Huey-specific first-hand account of the
  division of labour, and I did not watch footage].**
- On approach, the non-flying pilot's gaze goes **outside and around** while the flying pilot's
  locks on the touchdown point.

**This needs a code change to express** — a `COPILOT_*` clip family and a branch at
`seat_system.gd:153-154` so `seat_pilot_l` and `seat_pilot_r` draw from different constants.
**B-1 should be re-read as a correctness fix, not a polish item, and it should rank above every
other Tier B entry except B-0.**

**Withdrawing the mitigation the first draft offered.** It suggested authoring `cockpit_controls`
"without strong left/right asymmetry" so the doubled copy is less obviously a mirror. **That is
not available.** The asymmetry is in the airframe, not in the performance — a clip whose left hand
sits on the inboard collective has its hand in the console when copied to the left seat, no matter
how neutrally it is performed. The only honest interim options are: author for the **right seat**
(the pilot, and the one a viewer reads first) and accept a visibly wrong copilot until B-1 lands;
or seat **one** man until B-1 lands. Both are compromises. Neither is a fix. Logged as such.

### 3.8 The small human beats — which hand leaves, and when

| Beat | Which hand | Where it goes | Which state |
|---|---|---|---|
| Radio / freq change | **Right** off the cyclic *(only when the other pilot is flying)*, or **left** off the collective | Centre console | Ground hold, cruise |
| Overhead switch / light | Left | Up and forward, overhead console | Ground hold, post-touchdown |
| Map / kneeboard | Left | Thigh, head drops | Cruise only |
| Point at something outside | Right | Through the windscreen | Cruise, approach |
| Visor / helmet adjust | Either | Face | Any hold |

**Hard rule, and it is a physics rule not a style rule: in flight the flying pilot's right hand
NEVER leaves the cyclic.** A Huey is not trimmed hands-off **[TEXT — FAA: constant correction]**.
It can leave on the ground with the collective down. Everything else in this table belongs to
the copilot, which is the practical argument for F-2: **all the interesting human motion is
currently unauthorable because the copilot has no clip of his own.**

---

## 4. What the pilot animation must NOT do

Collected because each of these is a mistake that looks right:

1. **No throttle roll in flight.** Governor holds rpm **[TEXT]**. Twist grip moves at start and
   shutdown only.
2. **No hands off the controls in flight** for the flying pilot.
3. **No periodic cyclic wobble.** A clean sine reads as a machine. Irregular or nothing.
4. **No large cruise inputs.** Cruise is *calm*. Save the amplitude for the flare — the
   contrast is the point, and spending it early flattens the whole set.
5. **No feet off the pedals, ever, in any state.**
6. **No dead-centre cyclic on the ground.** Slightly forward of neutral **[TEXT]**.
7. **Left arm height is the ground/air tell.** Collective full down on the ground, raised in
   flight. Get this wrong and no amount of hand detail rescues it.

---

## 5. Door gunner

**The most valuable clip work in this document**, because he is currently playing `sitting`
(F-3), he is unoccluded on the outside of the airframe, and he is at eye level on a flyby.

### The mount decides the posture — pick one and commit **[TEXT]**

| | Slick (troop carrier) | Gunship |
|---|---|---|
| M60 mount | **Pintle** — a post | **Bungee from the cabin ceiling** |
| Gunner | Has a **seat**, plus a large belt-ammo bin | Free, weapon "hung by the rear sight ring" |
| Movement | Less gun mobility, more stable firing platform | "shoot up, down, behind and way in front, and underneath" |

**RECONgame's Huey is a slick** (`seat_pax_1..7`, troop insertion). So the shipping default is
**seated at a pintle mount with an ammo bin**, not the standing bungee gunner. That is the
less cinematic of the two and it is the correct one. It also means `seat_gunner_l/r` at
`y = 1.30` in `FALLBACK_LAYOUT` (0.05 m *below* the pax seats at 1.30 — same height, actually)
is at least plausible as a seat, which the pax markers were not until the `huey_loading` fix.
**Check the gunner markers against the modelled gun and floor before authoring** — the
`huey_loading` notes record seat markers sitting 0.42 m too low in a shipped file
(`huey_loading/NOTES.md:89-94`), and that class of defect is silent.

### Posture and motion

| State | What he does |
|---|---|
| **Cruise** | Seated/half-braced at the pintle, **both hands on the M60** — right on the grip, left on the feed cover or the barrel/foregrip area. Slow sector scan, gun following the eyes. Weapon trained slightly **down and aft of abeam** — he covers the ground, not the horizon |
| **Approach** | Everything speeds up. Scan widens and quickens; he **leans out** past the doorframe. This is where **"Clear my tail rotor"** lands **[TEXT — VHPA]** — head out, look **AFT** along the tailboom. Distinct, readable, and it is the single best approach-state beat in the pack |
| **Firing** | Braced hard into the gun, shoulders forward, muzzle rise, brass and links out. Traverse is driven from the torso, not the arms |
| **Under the tailboom** | **[TEXT]** — leaning out on the strap to "fire back under the tailboom while coming out or going into an LZ." The most extreme pose he holds |
| **Foot on the skid** | **[TEXT]** — gunners "often put one foot on the skid and fire underneath." Real, documented, and a strong silhouette. **But it belongs to the bungee/free-gun gunner, not the seated pintle gunner** — do not put a seated slick gunner's foot on the skid without ruling on the mount first |

### The monkey harness **[TEXT]**

Five-point harness with about **10 feet of strap** running from the back of it to the **cabin
floor**. That length is the whole point: it is what permits the lean-out and the skid step. It
was **not universally worn** — one crew chief called it "a little too restricting at times" and
unhooked frequently for cargo work.

**Animation consequence:** the strap is a floor-anchored trailing line, not a taut tether. If
it is modelled, it needs slack and it should never go straight. If it is not modelled, the
lean-out still reads — the harness explains the pose, it does not create it.

---

## 6. Crew chief

**[TEXT]** Crew chief works the **LEFT** door, door gunner the **RIGHT**. That maps to
`seat_gunner_l` (x **+0.55**... in `FALLBACK_LAYOUT`, `seat_gunner_l` is at x **+1.15**, the
left/`Door_Left` side) = **crew chief**, `seat_gunner_r` at x **−1.15** = **door gunner**.

He is a second gun most of the time and can share the gunner clips. What is *his*:
- **Watching the aircraft**, not just the ground — he owns the airframe.
- **Tail rotor clearance in tight LZs** — heads out with the gunner on the pilot's call **[TEXT]**.
- **[TEXT]** On a LRRP extraction, out **on the skid**, on his monkey strap, **directing the
  pilots** with hand signals. Spectacular, specific, documented, and completely out of scope
  for the demo — logged so it is not lost.
- Loading and unloading; hauling men in. This ties to the `huey_loading` gap: *"No crew chief
  reaching down to haul men in"* (`huey_loading/NOTES.md:39`). **Still open. Still the best
  single beat nobody has authored.**

---

## 6.5 REUSE BEFORE YOU REBUILD — what the library already has

Standing project law is reuse, never rebuild, and there is a known problem of **~32 of the 183
clips sitting unwired** (`recon-orphan-clip-audit`). Before anyone authors a new idle, this is
the shelf. All durations measured 2026-08-05 from the GLB.

| Existing clip | Duration | Verdict |
|---|---|---|
| `sitting` | 4.733 s | **Currently on pax AND both gunners.** Fine for pax. Wrong for a man holding an M60 |
| `sitting_idle_b` | 4.300 s | **WIRE THIS.** Pax variety, free |
| `sitting_idle_c` | 10.267 s | **WIRE THIS.** 10 s is long enough not to read as a loop — better than `sitting` itself for a pax who is on screen a while |
| `sitting_talking` | 44.067 s | **WIRE THIS for troops in the back on the ride out.** 44 s of non-repeating motion, already authored, already gated. Two men talking on the way to an LZ is exactly the beat this needs and it costs *nothing* |
| `sitting_talking_b` | 44.967 s | As above. Pair them so two pax are talking to each other |
| `sitting_drinking` | 15.200 s | Ground/parked only |
| `sleeping_sitting` | 17.600 s | Ground/parked, or a long ride. Period-correct and free |
| `smoking`, `nervous_scan`, `praying`, `praying_b` | — | Candidates for pax on the ride *in*. `nervous_scan` in particular |

**The pax cabin is a solved problem the code has not picked up.** `SITTING_CLIP` is a single
hardcoded string at `seat_system.gd:61` used for all seven pax seats, so seven men play the same
4.7 s loop in lockstep — the exact "not lockstep, staggered" failure the `huey_loading` notes
called out for the approach run (`huey_loading/NOTES.md:17-19`). **Randomising `SITTING_CLIP`
across the six variants above, per seat, with a per-seat random time offset, is a few lines and
fixes the most visible thing in the cabin.** No new art at all. Logged as **B-10** below.

**What is NOT on the shelf.** I checked all 183 names. There is **no** gunner clip, **no** weapon-
handling-while-seated clip, and **nothing** that would pass for two hands on a pintle-mounted
M60 — `gun_gunner` / `gun_agunner` / `gun_loader` are a ground crew-served weapon and
`prone_firing_rifle` / `firing_rifle` are the wrong posture entirely. **`doorgun_idle` genuinely
has to be authored.** That is the one place in this pack where "reuse" has no answer, and it is
also the highest-value clip in it. Splicing candidate: the upper body of `sentry_scan` or
`crouch_scan` over a seated lower body from `sitting`, per the crew-choreography method —
body from clips, contacts solved.

---

## 7. The clip list

Naming follows the library's existing families — `cockpit_*` and `pilot_*` for the cockpit,
and a prefix-family for the crew station in the manner of `mortar_gunner` / `gun_loader` /
`chow_*` / `litter_*`. Verified against all 183 names in `assets/shared/anim_library.glb`.

### Tier A — re-author under an existing name. **Zero code change. Do these first.**

All three already exist and are already wired. Nothing here needs a line of GDScript. **A-1 is
the single highest-value item in the cockpit half of the pack** — it is currently a 1.6 s tic
playing over the whole flight envelope, and lengthening it is pure asset work.

| # | Clip | Loop | Now | Target | Description |
|---|---|---|---|---|---|
| **A-1** | **`cockpit_controls`** | **LOOP** | **1.600 s** | **10–14 s** | Airborne hold. Cyclic ±3–6 mm irregular across 0.3–1.5 Hz, collective raised and near-still, feet trimming, head sweeping ±20–30° every 4–8 s. **Length is the defect** (F-5) — 1.6 s is a metronome at the same frequency as the motion it depicts. Zero code cost |
| **A-2** | **`cockpit_idle`** | **LOOP** | 4.000 s | 12–20 s | Ground hold, rotor turning. Collective **full down**, cyclic slightly **forward of neutral**, feet neutral, slow wide outside scan. The one state with slack for the human beats (§3.1). Left-arm-low is the ground read |
| **A-3** | **`pilot_flips_switches`** | **ONE-SHOT** | **4.000 s** | 4.000 s | Post-touchdown panel run. **Hold the length** — `PILOT_PANEL_S` = 4.03 is a timeout keyed to it (F-4). Re-author longer/shorter and that constant changes in the same edit. Start from the forward-of-neutral cyclic pose so it stitches to `cockpit_idle` on fall-through. **Also: verify it reaches switches that actually exist in the new geometry** (§9 item 8) |

### Tier B — needs a `seat_system.gd` change. Each one costs code.

Listed in **priority order, not numeric order**. B-0 and B-0b are the two cheap ones and they sit
at the top because they buy the most visible change per line of code in the whole pack. **B-1 sits
third because it is the only Tier B item that is a correctness defect rather than an addition** —
see §3.7.

| # | Clip | Loop | Description | Code cost |
|---|---|---|---|---|
| **B-0** | **`doorgun_idle`** | **LOOP** | **The most valuable single clip in this document.** Gunner at the pintle, both hands on the M60, slow sector scan, muzzle down and aft of abeam. Target **8–12 s**. Nothing in the 183-clip library covers this (§6.5) — it must be authored. Splice candidate: `sentry_scan` upper body over `sitting` lower body | `seat_system.gd:281` — one branch on `begins_with("seat_gunner")` so gunners stop playing `SITTING_CLIP`. **Cheapest code change with the biggest visual return in the pack** |
| **B-0b** | *(no new art)* | — | **Randomise `SITTING_CLIP` per pax seat** across `sitting`, `sitting_idle_b`, `sitting_idle_c`, `sitting_talking`, `sitting_talking_b`, `nervous_scan`, plus a per-seat random start offset. Seven men currently loop the same 4.7 s clip in lockstep | `seat_system.gd:61` + `:281`. **Zero art cost, kills the most visible defect in the cabin.** Wires 4–5 orphan clips as a side effect |
| **B-1** | `copilot_controls` | LOOP | **Correctness fix, not polish.** Left-seat man: left hand on the **OUTBOARD** collective (the pilot's is inboard — the two cannot share a clip, §2/§3.7), hands guarding rather than flying, gaze scanning wide. **Any shared clip fails G-2 hand-contact at one of the two seats** | Split `seat_pilot_l` / `seat_pilot_r` at `seat_system.gd:153-154`. Kills F-2. **Ranks above everything below it** |
| **B-2** | `cockpit_flare` | ONE-SHOT | Hard aft cyclic 40–80 mm + up collective + coordinated **left pedal**, ~1.5 s | New `_pilot_clip()` state. **Best-looking single clip available** |
| **B-3** | `doorgun_clear_tail` | ONE-SHOT | Head and shoulders out the door, look **aft** along the tailboom | Approach state must exist |
| **B-4** | `cockpit_approach` | LOOP | Aft cyclic, collective coming down, amplitude up to ±6–12 mm, **gaze locked on the touchdown point** | New state |
| **B-5** | `doorgun_lean_out` | LOOP | Leaning out on the strap, gun depressed, covering under the tailboom into/out of the LZ | Approach state |
| **B-6** | `cockpit_lift` | ONE-SHOT | Slow collective rise 0.10–0.14 m + left pedal 15–30 mm + coordinated cyclic, ~3 s. All three limbs together | New state |
| **B-7** | `doorgun_fire` | LOOP | Braced into the gun, muzzle rise, torso-driven traverse | Needs a firing hook, which does not exist for gunners |
| **B-8** | `copilot_radio` | ONE-SHOT | Right hand off to the centre console, glance down, back | On top of B-1 |
| **B-9** | `cockpit_touchdown` | ONE-SHOT | Settle onto the skids, cyclic to forward-of-neutral, collective to the stop | Could be folded into the `pilot_flips_switches` lead-in for free instead |

### Tier C — logged, out of demo scope

| Clip | Loop | Description |
|---|---|---|
| `crewchief_haul_in` | ONE-SHOT | Reaching down to haul a man aboard. **The open gap from `huey_loading/NOTES.md:39`** |
| `crewchief_on_skid` | LOOP | Out on the skid on the monkey strap, hand-signalling the pilots. LRRP extraction |
| `copilot_map` | LOOP | Kneeboard on the thigh, head down |
| `cockpit_pedal_turn` | LOOP | Hovering pedal turn — one pedal held forward, cyclic holding position |

---

## 8. Numeric gates

Every clip must pass all applicable gates before it is shown to anyone. Verify against the
**exported `.glb`**, not the source `.blend` — `tools/export_anim_library.py:62-64` strips
`mixamorig:Hips` location array_index 0 and 2 at export, and that stripping is invisible in the
source. This exact trap cost a session on 2026-08-04 (`ART_Track_Log.md:333-345`).

### G-1 — Elbow intersection. **PERMANENT LAW. Elbows must NEVER intersect.**
Gate every frame, not keyframes. Reference values from shipped work: `board_heli` = **0.0191**,
the accepted `disembark_heli` family = **0.056–0.099**.
- Cockpit clips (seated, arms inboard, both hands working near the body — the **highest-risk
  geometry in the project**): **max ≤ 0.04**. Tighter than the shipped precedent on purpose.
- Gunner clips: **max ≤ 0.06**.
- **Anything > 0.10 is an automatic red, no exceptions, no discussion.**

### G-2 — Hand contact **(and the seat it was authored for)**
**Run this gate at BOTH seats.** A cockpit clip passes only if it maintains contact at the seat it
is authored for *and* is never played at the other one — the collectives are on opposite sides of
the two bodies (§2), so a clip that passes at the right seat fails at the left by ~0.6 m. **State
the intended seat in the clip's name or its record.** This is the gate that catches F-2.

Hand-bone origin to the control's grip marker, **every frame**:
- Cyclic ↔ right hand: **≤ 0.03 m**, and the offset vector must be near-constant — a hand that
  keeps contact while sliding around the grip is a fail.
- Collective ↔ left hand: **≤ 0.03 m**.
- Both M60 grips ↔ gunner hands: **≤ 0.03 m**.
- Contact must hold for **100 %** of frames in every flying clip. Ground clips may release,
  and must release **cleanly** — no hand passing through the grip on the way out.

### G-3 — Feet on pedals
Toe/ball marker to pedal face **≤ 0.02 m**, **100 % of frames, every state**. Pedal-axis travel
**≤ ±0.035 m**; anything larger is a stomp.

### G-4 — Control amplitude envelopes (grip-centre displacement, per clip)

| Clip | Cyclic | Collective (vertical) | Pedals |
|---|---|---|---|
| `cockpit_idle` | ≤ ±0.003 m | **0.000 m — hard down, no travel** | ≤ ±0.005 m |
| `cockpit_controls` | ±0.003–0.006 m | ±0.005–0.010 m | ±0.005–0.010 m |
| `cockpit_approach` | ±0.006–0.012 m | net **down** 0.03–0.06 m | ±0.010–0.020 m |
| `cockpit_flare` | **0.040–0.080 m aft** | **+0.05 m up** | **left +0.015–0.030 m** |
| `cockpit_lift` | ±0.006–0.012 m | **+0.10–0.14 m** | **left +0.015–0.030 m** |

Below-minimum is as much a fail as above-maximum. A frozen cyclic in `cockpit_controls` fails.

### G-5 — No periodicity
FFT the cyclic grip position in `cockpit_controls`. **No single frequency bin may hold > 40 %
of the total spectral energy.** A clean sine fails. This catches the single most likely way
this animation goes wrong.

### G-6 — Loop seam (LOOP clips only)
Frame 0 vs frame N: **per-bone rotation delta ≤ 0.5°**, **per-bone position delta ≤ 0.002 m**,
and first-derivative continuity — velocity across the seam within **20 %** of the local mean.
A pose-matched loop with a velocity discontinuity still visibly hitches.

### G-7 — Clip length
- `pilot_flips_switches`: **4.000 s ± 0.02 s** (measured), or `PILOT_PANEL_S`
  (`seat_system.gd:60`, currently 4.03) changes in the same edit. No third option.
- `cockpit_controls`: **≥ 8.0 s**, target 10–14 s. **A clip under 8 s fails this gate** — see F-5.
- `cockpit_idle`: **≥ 10.0 s**, target 12–20 s.
- `doorgun_idle`: **≥ 8.0 s**.

Measure the **exported GLB**, not the Blender action, and measure the *span* (max − min keyframe
time across all samplers), not the last timestamp. Reading the last timestamp instead of the span
is exactly how `PILOT_PANEL_S` picked up its one-frame error (F-4). The parse is a dozen lines of
Python against the glTF sampler input accessors and **needs no Blender**, which matters when
another agent is holding the Blender session.

### G-8 — Seated collapse
Root/hip height must be **non-zero and stable** across the clip. The `chow_hall` sessions logged
the failure mode: a clip that keys location only on the Hips depends on unkeyed pose state and
collapses in a clean file, knees and toes above the man's own head
(`ART_Track_Log.md:309-312`). **Height is the collapse tell.** Compare like poses.

### G-9 — Twist grip static
In every airborne clip, the collective twist-grip bone's rotation delta over the whole clip must
be **< 1°**. The governor holds rpm; a rolling throttle in cruise is wrong **[TEXT]**.

### G-10 — Gaze
Head yaw amplitude, measured on the head bone:
- `cockpit_idle`: **±30–50°**, slow.
- `cockpit_controls`: **±20–30°**, one full sweep every 4–8 s.
- `cockpit_approach`: **≤ ±10°** and biased **down-forward** — the gaze must *lock*. This gate
  is inverted from the others on purpose; a wandering head on final is the fail.

---

## 9. What I could not verify

**Closed since the first draft, recorded so nobody re-opens them:**
- ~~Which side the collective is on.~~ **RESOLVED** — left of each seat, left hand, and the two
  are **not mirrored** (right-seat inboard, left-seat outboard). Moved into the spec at §2, and it
  turned out to carry the strongest argument in the document (§3.7).
- ~~Whether both seats have real controls.~~ **RESOLVED** — the -10: *"Complete controls are
  provided for both pilot and copilot."*
- ~~Whether the stick is loaded or free.~~ **RESOLVED** — force centering devices *"furnish a
  force gradient or 'feel'"* to the cyclic and pedals. Primary-source basis for §3's core finding.
- ~~The lengths of the four existing clips.~~ **MEASURED** off the GLB (§0).

**Still open. Listed in descending order of how much damage it would do to guess.**

1. **I did not watch a single frame of video.** YouTube returns the fetcher a footer and a
   copyright notice — no description, no duration, no transcript. Same wall the `huey_loading`
   notes hit. **Every amplitude, frequency and timing number in this document is [DERIVED], not
   measured off footage.** They are honest starting values with their arithmetic shown. They are
   not observations. Anyone who watches mRUFRebsBzU should correct §3 and §8's G-4 table in place
   and delete this paragraph. *The -10 pass improved the document's grasp of the machine; it did
   nothing for its grasp of the man. Every mechanical fact is now primary-sourced and every
   motion amplitude is still an inference.*

2. **Paragraph citations for the -10 quotes.** The manual is real and the quotes are verbatim and
   cross-corroborated across independent mirrors, but they were recovered via search extraction —
   the milviz PDF exceeds the fetcher's 10 MB limit and every text mirror returns 403. **So I have
   the manual's sentences without their page numbers.** Highest-risk item: the **8–10 lb collective
   breakaway** figure, which §2 leans on to justify the slow-committed-left-arm read. It is a
   quoted number from a real manual; it is not a number I read on a page I opened. **Open the PDF
   locally before anyone tunes to it.**

3. **Cyclic correction frequency.** I have the amplitude (quarter inch, [TEXT]) and the
   qualitative claim (constant, [TEXT]). **I have no source for a rate.** The 0.3–1.5 Hz band
   in §3.3 is a guess that I chose because it is slow enough to read at distance and
   incommensurate enough to hide a loop. It is not from a source. Treat G-5 (no single dominant
   frequency) as the real gate and the band as a suggestion.

4. **Pedal displacement in metres.** Every source describes pedals in terms of *pressure* and
   *direction*, never distance. The ±0.035 m in G-3 and the 15–30 mm in G-4 are [DERIVED] from
   plausible pedal geometry, not read anywhere.

5. **The copilot's actual division of labour in a Vietnam slick.** §3.7's radio/map/nav
   description is standard multi-crew practice and the console geometry is confirmed, but I
   found **no Huey-specific first-hand account** of what the left-seater's hands do minute to
   minute. Marked [UNVERIFIED] and it should stay marked until someone reads a memoir or
   watches over-the-shoulder footage.

6. **Whether RECONgame's gunner is seated or standing.** The slick/gunship split is [TEXT] and
   clear, and a slick points to **seated at a pintle**. But I did not see `huey_v3.blend` and I
   do not know what gun mount is being modelled. **The foot-on-the-skid pose is documented and
   real but belongs to the free-gun/bungee gunner** — do not put it on a seated pintle gunner
   without ruling on the mount first.

7. **Gunner seat marker heights in `huey_v3.blend`.** `FALLBACK_LAYOUT` puts
   `seat_gunner_l/r` at y = 1.30, identical to the pax seats. The `huey_loading` notes record
   seat markers shipping 0.42 m too low in a different file and warn that the shipped
   `huey.glb` the game reads is a *different file again* and probably carries the same defect
   (`huey_loading/NOTES.md:89-94`). **Measure before authoring.** This defect is silent.

8. **What is INSIDE any of the four existing clips.** I measured their **lengths** and nothing
   else — durations came from parsing the GLB's animation-sampler accessors, which tells you how
   long a clip is and *nothing* about what it depicts. **I do not know whether `cockpit_controls`
   has a moving cyclic, a moving head, or feet on the pedals at all.** I do not know which
   switches `pilot_flips_switches` reaches for, or whether they line up with the overhead and
   centre consoles being modelled right now — if the new geometry moved anything, that 4 s clip
   may be waving at empty air. **Every §8 gate must be run against the existing clips before any
   of them is called good or bad.** My F-5 recommendation stands on the *length* alone, which is a
   real measurement; the guess that the head is static inside it is a guess.

9. **Anthropometric fractions.** §2's segment table uses standard stature fractions, not
   measurements off PSXRig. If PSXRig's proportions differ — and rigs do — the reach envelope
   moves. **Measure the actual rig before trusting the 0.50–0.55 m working-reach figure.**

10. **What else is on the cyclic grip.** The **force-trim push-button is confirmed [TEXT]** and is
    the thumb beat §3.3 asks for. A trigger, an ICS/radio switch and a hat are all *typical* — I
    did not confirm any of them for the UH-1H and **did not write them into the spec.** If the
    grip is being modelled with extra switches, they came from somewhere other than this document.

11. **How often a real pilot actually re-trims, and whether he flies with the trim button held
    down.** Both are known techniques. The -10 tells me the button exists and what it does; it
    does not tell me the habit. §3.3 asks for "once or twice per loop," which is a **guess chosen
    to be visible without being busy.** If someone watches cockpit footage, this is cheap to
    settle and it directly sets how often the thumb moves.

12. **Whether the ship can be flown hands-off at all.** §3.3 asserts it cannot. Force trim
    reduces *force*, not *attention*, and I found no reference to an autopilot or stability
    augmentation in the UH-1H slick — **but I did not find a sentence ruling one out either.**
    The claim is load-bearing for "the hand never leaves the cyclic," so it is flagged rather than
    quietly assumed.

13. **Whether the demo Huey ever flies close enough for any of this to be seen.** Nobody
    established the closest approach or the dwell time. If the ship is only ever a silhouette at
    100 m, Tier B is wasted work and Tier A + B-0 is the whole job. **Worth asking Caleb before
    anyone spends a day on `cockpit_flare`.**
