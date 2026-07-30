# DEVIL'S ADVOCATE — what this session is about to get wrong

## 1. The Summoner said "tighten up collision on all the models". That is the wrong fix, and agreeing with him would cost a week

He inferred a cause from a symptom, reasonably. But the colliders are not loose. Men jam
against them because **nothing routes them around**, and he stands on one because there are
**two floors**. Spend a week shrinking hulls and he will play the exact same build again.
Say this to him plainly rather than quietly doing the right thing instead.

The one place he is literally right: the parapet box hull (level_designer L2) IS a loose
collider. One item out of six.

## 2. "Fix nav first, re-judge, then tune" is correct and will be uncomfortable

Systems Designer's ordering is right, and it means the next playtest may STILL show a poor
fight — because S2 and S3 are unverified hypotheses, not findings. Do not let the ordering
become a promise that nav fixes combat. It buys the ability to SEE combat. Name that now, so
the second playtest is not read as a failure of the first fix.

## 3. Nobody has run this build

Every claim in this session is read off source. Under the Summoner's own law — a log line is
a CLAIM, and so is a source read — none of it is confirmed until the world is booted and
looked at. Two specific claims are most likely to be wrong:

- **That the plate is above the terrain over "most" of the compound.** The 0.5–2.4 m figure is
  arithmetic from `MOUND_H` and `FSB_MOUND_TOP`. It has not been sampled in-engine.
- **That the garrison stood to at all.** Nobody has read `[STAND TO]` in a debug log from the
  session he describes.

Both are cheap to measure. Measure them before writing the fix, not after.

## 4. The one-ground fix duplicates an authoring formula into a second language

Reproducing `platform_z` in GDScript means `MOUND_H`, `R0`, `RIDGE_STRETCH`, the three
harmonics and `MOUND_FALL` exist in Python AND in GDScript. The next time anyone edits the
mound in Blender, the terrain silently disagrees again — a NEW divergent-systems seed, in a
project whose scar tissue is entirely divergent systems.

The mitigation is not "be careful". Either:
- **(a)** have `gen_firebase_v3.py` write the mound constants into a small JSON beside the
  GLB, and have `site_planner` read them (single source, authored in Blender); or
- **(b)** sample the mound from the exported GLB at load and drive the terrain off that.

(a) is cheaper and matches the temple/village manifest pattern already in `site_planner`.
Whichever is chosen, a bare hardcoded copy of `MOUND_H = 3.4` in GDScript should be refused.

## 5. What is being sacrificed

- **Craters stop being holes.** Under one ground, `crater_delta` is decoration. The Summoner
  has not been told this. He should be, before it ships.
- **Firebase nav bake costs load time.** Unmeasured. On the Intel UHD floor a multi-second
  hitch at world build is a real cost on the demo's first impression.
- **Trimesh parapets cost physics.** ~50 box hulls becoming trimeshes, on a project whose
  ledger says it is call-bound. Measure it, and put the number in PERF_LEDGER.
