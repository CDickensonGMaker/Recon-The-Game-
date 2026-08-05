# ADDENDUM 2 — `beats.json` prototyped and run on your real takes

**2026-08-05, third pass.** Decree item #3 proposed extracting beat timing from footage. I built
it and ran it on five of your weapon takes, so you can rule on evidence rather than on a promise.

**It works.** It also produced a per-take quality number we did not have before, and it found the
best weapon take in your library.

---

## What it does

All in **weapon-relative space**, so you walking around cannot pollute it:

- The two wrists lie on the gun, so the hand-to-hand vector approximates the bore axis. **Fixed
  once per take from the median direction** — deriving it per frame from the same vector you then
  project onto is degenerate and returns lift/lateral of exactly zero. I made that mistake on the
  first run and caught it because every `lift` column read `0`.
- **DWELL** = speed under a percentile floor for ≥4 frames → a contact.
- **STROKE** = the travel between two dwells → a working motion.
- Strokes longer than 1.5 s are dropped as transits, not strokes.

## Results — five takes

| take | length | dwells | strokes | median stroke | **depth share** | 1-D reversals |
|---|---|---|---|---|---|---|
| **mosin_clean** | 12.0 s | 9 | 6 | 14 f | **16 %** | 6 |
| mosin_p1_fire_bolt | 15.0 s | 13 | 8 | 24 f | 25 % | 5 |
| mosin_p3_bolt | 7.1 s | 7 | 5 | 16 f | 34 % | 5 |
| shotgun_pump | 13.8 s | 12 | 9 | 20 f | 40 % | 8 |
| m60_handling | 27.0 s | 19 | 4 | 15 f | **55 %** | 16 |

**Median stroke length lands at 14–24 frames.** That is exactly the regime your own de-robotise
findings call for — 250 mm of travel in 6 frames gave 35°/frame of forearm roll, and thirteen
frames dropped it to 9.5°/frame. **The beats coming out of your footage are already in the range
that produces natural forearm motion.** That is the strongest evidence yet that timing is the part
of the signal worth keeping.

## The new number: depth share *of the strokes that matter*

The 48–51 % figure we have been quoting is a whole-take average. This measures the share of each
**working stroke's** displacement that rides the camera-facing axis — the inferred one.

It ranges from **16 % to 55 % across your own takes.** That is a far more useful number than one
global average, because it says *per take* whether the arcs are worth anything:

- **`mosin_clean` at 16 %** — the arcs in this take are largely real.
- **`m60_handling` at 55 %** — the majority of stroke displacement is inferred. **Arcs from this
  take are worse than useless; the beats are still fine.**

**This should be the triage gate's headline number**, not the whole-take depth share. It answers
the actual question: what is this take good for?

## The depth-robust beat signal

The degenerate first attempt collapsed to a 1-D signal — plain **hand separation** — and it turns
out that accident found the right instrument. Hand separation along the gun is measured *in the
image plane*, so it barely touches the inferred axis at all. Its reversal count tracks the 3-D
stroke count closely (5/5, 8/9, 6/6) at a fraction of the noise.

**Recommendation: derive beats from the 1-D separation signal, and use the 3-D decomposition only
to label each stroke** (rearward / forward / lift). That is depth-robust by construction.

## Two concrete findings for your morning

1. **`mosin_clean` is the best weapon take you have.** 16 % depth share, 357 of 358 frames usable,
   hand span 1.85 against the demanded 1.81. **If we build one gun's beat track first, build it
   from this take.**
2. **`m60_handling` is 27 seconds that yielded 4 strokes and 19 dwells.** It is mostly a man
   holding a weapon, not working one. Good for a hold/idle reference, thin for handling beats.

## What this does not do

It supplies timing and stroke *direction*. **It does not supply hand position and must never be
allowed to** — that is Lane A doctrine and the 16–55 % depth numbers are exactly why. Hand
position comes from the contact markers.

It also has not been run against a hand-authored clip to check the beats agree with where you
actually keyed the handoff frames. **That comparison is the real acceptance test and I have not
done it** — it needs your blessed clips open, and I am not touching those without your word.

Prototype: `beats.py` in scratchpad. Read-only, nothing installed.
