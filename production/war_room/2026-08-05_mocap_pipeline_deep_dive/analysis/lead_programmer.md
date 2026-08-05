# LEAD PROGRAMMER — Individual Sight

## Where the hours actually went

I ranked the known incidents by cost, not by how interesting they were.

| Incident | Class | Cost |
|---|---|---|
| Stale installed addon copy — FPS preset unloadable, invisibly | **environment drift** | days of wrong conclusions |
| `rest_delta` declared, drawn, documented, implemented nowhere | **capability lie** | hands 17 m from the rifle |
| `feature.preview` advertised by the backend, draws nothing | **capability lie** | no visual QC at all |
| autoscale measuring finger bones → 3.99× | **wrong-chain measurement** | arms at 4× life size |
| `rest_mode`/`rest_frame` consumed by `build_source_armature`, not the retarget | **ordering trap** | silent no-op, drift number never moves |
| Game viewmodel footage → 1 % hand detection | **wrong input** | one wasted capture session |

**Four of six are software defects in our own toolkit, and none of them failed loudly.** Every
one presented as "the mocap is bad." That is the actual root cause of the frustration in this
question: *the pipeline's failure mode is a plausible-looking wrong answer.*

The 7/31 session already proved this: his complaint was *"those arms are not correct nor what my
motion capture video was showing"* — and the mocap was fine. Four tooling defects were stacked
on top of it.

## The three gates I want, in priority order

### 1. Capability contract test (highest ROI in the repo)
Walk every property declared in `props.py` and every capability string a backend advertises.
For each, assert a consumer exists somewhere outside the declaration and the UI row. `rest_delta`
would have failed this on day one. `feature.preview` would have failed it on day one. This is
maybe 60 lines and it closes a whole class permanently.

### 2. Installed-extension hash gate
`run_tests.ps1` computes a hash of `addon/` + `strategies/` + `contacts/` + `presets/` and
compares it against the installed copy in
`AppData\Roaming\Blender Foundation\Blender\5.0\extensions\user_default\mocap_toolkit`.
Mismatch = loud red failure with the sync command printed. Additionally: **stamp the version and
short hash into the addon's N-panel header**, so the answer to "is Blender running my code" is
visible without running anything.

### 3. Take triage gate at extract time
`depth_report.py` already computes what we need. Turn it into a PASS/FAIL that runs as the last
stage of `cli extract` and writes a verdict block into the take:

```
TAKE VERDICT: caleb_mosin_p2  ............................ FAIL
  core detection      0.884   (gate >= 0.95)   FAIL
  depth share         0.51    (gate <= 0.35)   FAIL   <- reshoot, or accept timing-only
  longest dropout     55 f    (gate <= 5)      FAIL
  hand->prop minimum  0.474 m (gate <= 0.15)   FAIL
  finger detection    0.757   (advisory)
  => USABLE FOR: nothing. Reshoot at full profile, camera on the working side.
```

The verdict names *what the take is usable for*, which is the real decision. A take at 48 %
depth is worthless for arcs and perfectly good for beats. Today we discover that in Blender.

## On the ordering trap specifically

`rest_mode` / `rest_frame` being consumed at source-build time rather than retarget time is not
a bug, but it is a trap that has already cost a session. Either move the consumption or make the
retarget operator **hard-error** when those props changed after the source armature was built.
Silent no-ops are how we got here.

## On the solver question

I defer to the technical director's licence finding. I'll only add the engineering angle: even
setting licences aside, WiLoR/HaMeR/GVHMR/NLF are all ViT-class transformer models. On a 4 GB
Pascal card they run, but slowly. That is *fine* — we process a 30-second clip once, offline,
not in real time. Performance was never the blocker. **The licence is.**
