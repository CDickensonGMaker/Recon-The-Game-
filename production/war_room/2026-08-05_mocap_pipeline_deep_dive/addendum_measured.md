# ADDENDUM — the audit, actually run

**2026-08-05, second pass.** The decree proposed three gates from reasoning. I then built and ran
them against the real repo so you get measured numbers instead of estimates. One hypothesis I
chased was **wrong**, and that is recorded here too.

---

## 1. Installed-addon drift gate — RUN. Currently CLEAN.

Hashed all 27 `.py`/`.json` files in `addon/` against the installed extension at
`AppData\Roaming\Blender Foundation\Blender\5.0\extensions\user_default\mocap_toolkit`.

```
repo files: 27   installed: 27   DRIFT: 0
```

**Clean — but only because the 7/31 session synced it by hand, and nothing enforces it.** Every
installed file is stamped 7/31 16:56–17:04. The repo has not moved since. The moment you edit
`addon/` and don't re-sync, you are back in the failure that made `psx_fp_arms.json` unloadable
for days without a single error message. The gate is still worth building; it is currently
passing by luck, not by construction.

## 2. Capability contract test — BUILT AND RUN. Found two more dead promises.

45 properties declared in `MOCAP_Settings`. 43 have a real consumer. **Two do not:**

### `max_correction_step_mm` — the one with animation consequences
Declared, defaulted to **32.0 mm**, described as *"How fast a contact correction may be walked
in, so a big reach does not read as a teleport."* **Referenced nowhere outside its own
declaration.**

The ramp itself does exist — `contacts/feet.py:149` ramps each stance correction to zero at its
edges — but it ramps over `blend_frames`, a **frame count**, not a **mm-per-frame rate**. So a
60 mm correction and a 6 mm correction are both walked in over the same 3 frames. The large one
moves 10× faster. **That is precisely the "reads as a teleport" artifact the property was written
to prevent, and the guard against it was never built.**

This is the exact same class as `rest_delta` (declared, drawn, documented, implemented nowhere)
and `rest_drift_abort_mm` (a guard for a fix that did not exist). **Three instances now. It is a
pattern, not an accident.**

### `grip_state_path` — a documented path that goes nowhere
Declared as a `FILE_PATH`. `contacts/prop.py:16` documents the intended behaviour — *"never
authors a `grip_states/*.json`. Pointed at one, it adopts the contract"* — and nothing consumes
the property. The feature is described in the source and absent from it.

### `feature.preview` is still advertised
`mocap_toolkit/backends/mediapipe/__init__.py:121` still adds `feature.preview` to its capability
set. The working implementation lives in `tools/preview_overlay.py`, outside the backend. **The
backend still lies about what it can do** — the 7/31 fix routed around the lie instead of
removing it.

## 3. The `grip_states` fossil — real, and NOT the culprit. I was wrong.

`RECONgame/assets/player/arms/grip_states/*.json` — 16 files, untouched since 7/24 — is stale for
**8 of 15 weapons**, worst case the Mosin at **0.500 m against the live rig's 0.294 m (+70 %)**.
It is referenced nowhere in RECONgame except a ghost-code audit document. It is a fossil.

`docs/FILMING.md` was built from that table and **corrected on 7/31 at 16:44**. Every weapon take
you shot was extracted on **7/29** — two days *before* the correction. So the hypothesis was
obvious and alarming: you taped your dowel to a Mosin span 206 mm too wide and captured, in the
doc's own words, *"a flawless performance of the wrong weapon."*

**I measured it, and it did not happen.** Wrist separation per take, normalised by your own
forearm so MediaPipe's self-declared "approximate" metric scale cannot carry the verdict:

| take | frames | usable | wrist span | forearm | shoulders | **span/forearm** |
|---|---|---|---|---|---|---|
| caleb_mosin_m60_shotgun | 1697 | 1575 | 0.393 | 0.226 | 0.326 | 1.74 |
| mosin_bolt | 478 | 362 | 0.390 | 0.216 | 0.320 | 1.81 |
| m60_handling | 807 | 807 | 0.386 | 0.230 | 0.330 | 1.68 |
| shotgun_pump | 412 | 406 | 0.408 | 0.231 | 0.319 | 1.77 |
| mosin_bolt_v2 | 840 | 832 | 0.440 | 0.239 | 0.322 | 1.84 |
| mosin_p1_fire_bolt | 448 | 448 | 0.472 | 0.237 | 0.324 | **1.99** |
| **mosin_p2_reload_single** | 180 | 180 | 0.331 | 0.244 | 0.318 | **1.36** |
| mosin_p3_bolt | 212 | 205 | 0.427 | 0.236 | 0.319 | 1.81 |
| preview_mosin | 359 | 243 | 0.353 | 0.195 | 0.314 | 1.81 |
| mosin_clean | 358 | 357 | 0.406 | 0.220 | 0.330 | 1.85 |

The Mosin's live-rig wrist separation is **0.418 m**; your median forearm across these takes is
**0.230 m**. So the rig demands **1.81 forearm-units** — and your Mosin takes land at
**1.81, 1.84, 1.81, 1.81, 1.85**. You performed the Mosin's real hand span almost exactly, two
days before anyone wrote down what it was.

Your shoulder width also holds at **0.314–0.330 m across every take**, which is what makes the
normalisation trustworthy — the solver is measuring you consistently.

**So: the fossil is a live landmine for the next person who reads it, but it did not damage a
single existing take. Delete it under fossil law; do not re-shoot anything because of it.**

### Two takes that *are* off, and are worth knowing about

- **`mosin_p2_reload_single` — 1.36 against a demanded 1.81. Hands ~25 % too close.** This is the
  one take in the set that genuinely captured the wrong hold. If reload arms have looked wrong,
  this take is a real suspect.
- **`mosin_p1_fire_bolt` — 1.99, ~10 % wide.** Marginal, worth an eye.

Also confirmed from the take's own quality block: `mosin_bolt` reports
`overall_detection_rate 0.783` against `threshold 0.8` — the head-on take, matching the camera
angle law exactly.

---

## What this changes in the decree

**Nothing is downgraded; two things are sharpened.**

1. **The capability contract test moves up.** It was proposed on the strength of two known
   instances. It has now found **two more on its first run**, one of which (`max_correction_step_mm`)
   is a live animation defect that plausibly contributes to the pop-and-teleport artifacts you
   have been fighting in contact-solved clips. ~60 lines, already prototyped, already returning
   findings.
2. **Add one item: kill the `grip_states` fossil.** 16 files, 8 wrong, consumed by nothing,
   already responsible for one incorrect doc that was caught only by re-measuring. Fossil law
   says delete on replace — the live rigs replaced it on 7/31 and it was never deleted.

**And one worry is closed:** your existing weapon footage is dimensionally sound. Whatever is
wrong with the FP arms, it is not that you performed the wrong weapon.

Prototype scripts (read-only, scratchpad, nothing installed):
`capability_audit.py` and `measure_span.py`.
