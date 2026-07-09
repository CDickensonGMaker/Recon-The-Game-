# FP Viewmodel Animation Timing — keyframe reference (30 fps)

Author everything on a **30 fps grid** (what GoldSrc/Source/CoD used). 1f=0.033s, 15f=0.5s, 30f=1.0s.

## The 7 craft rules (apply to every clip)
1. **Hand leads the weapon** — key wrist/root 1–2f AHEAD of the gun body; gun drags behind. Biggest pro-vs-amateur tell.
2. **Fast-in / slow-out** — fast attack (2–5f) into the pose, slow settle (6–15f) with a small overshoot. Every action is this asymmetric curve.
3. **Overshoot then settle** — go 10–20% past the target pose, ease back. Never stop hard on target.
4. **Start on frame 2, not 1** — motion on f1 so the button press throws you into the action. Free responsiveness.
5. **Weight = timing** — ~2× frame spread light→heavy. Recoil settle: SMG 6–8f, rifle 8–12f, MG 14–22f. MG handling +30–50% frames, more sag, bigger overshoot.
6. **Follow-through on soft parts** — sling/fingers lag main motion 1–3f, keep moving after the gun stops. Even a 2f hand drag after a mag slap sells impact.
7. **Hold key poses** — hold the strong pose 2–4f in the settle. Readability lives in the holds.

## Priority (author in this order — timing matters most → least)
1. **fire/recoil** (plays constantly, core gun feel) 2. **bolt_cycle** (Mosin identity) 3. **reload** 4. **jam/tap-rack** 5. **reload_empty** 6. **draw** 7. **sprint**

## Keyframe cheat-sheet (rifle = M14/M16/AK)

**fire** (rifle, 8f): kick f0→f2 (fast, muzzle rises AROUND the grip pivot, back+up), **1f hold at peak f2→f3**, settle f3→f8 (ease-in, ~10% overshoot low then micro-settle). Muzzle rise ~2–5° + 3–6cm back.
- ADS-fire variant: same curve, **50–60% amplitude** (hip recoil looks wrong down sights).
- Auto-fire: additive kick retriggered per shot (cleaner than a baked loop in Godot).
- Detail that reads: the **1f peak hold** + muzzle pivoting up around the grip, not straight back.

**reload tactical** (66f / 2.2s canonical):
| phase | frames | norm% | event |
|---|---|---|---|
| tilt gun inboard/down 20–35° | 0–8 | 0–12% | |
| support hand to mag | 8–14 | 12–22% | |
| strip old mag | 14–20 | ~25% | **mag-out event ~f16 (25%)** — detach mag prop, parent to hand |
| stow/drop | 20–28 | 30–42% | |
| retrieve fresh | 28–34 | 42–52% | swap prop to "full" offscreen |
| insert into well | 34–43 | ~60% | **mag-in event ~f40 (60%)** — attach mag prop to gun |
| **seat/slap** | 43–50 | 65–75% | **the money beat** — gun jolts up ~3°, settle, 1–2f drag |
| return to idle | 56–66 | 85–100% | ease-in, small overshoot |
- AK: rock-out on strip, hook-and-rock-in on insert. M16: straight insert + bolt-release paddle.

**SCALABLE reload (the key trick):** author at canonical length; put prop-swap + ammo events on **normalized percentages (25% out, 60% in), NOT absolute frames**, so they survive retiming. Let travel phases stretch, keep contact phases near-constant. **Clamp playback 0.85×–1.25×**; outside that, author a 2nd clip rather than stretch. This is how `reload_progress` drives it and mag-out/in still land on beat when Agility speeds it up.

**reload_empty** (~96f / 3.2s = tactical + 0.4–0.8s): same through slap, bolt held OPEN throughout, then add:
- M16/AR: **bolt-release paddle jab** ~f78–84 (4–6f, sharp button press).
- AK/SKS: full **charging-handle rack** — pull back 3–4f, snap forward 2–3f (~7–10f). Then return to f96.
- Branch: FSM checks `current_ammo==0` at reload-start → picks empty vs tactical clip.

**jam / tap-rack-bang** (30f / 1.0s — urgent, fast, no mag swap):
- TAP f0–7: support hand slaps mag base HARD, gun jolts.
- RACK f7–13 back (violent) / f13–17 forward (snap).
- return f22–30, quick, no leisurely settle.
- Near-linear fast curves, minimal easing — smoothness kills the panic. It's the back-third of a reload played angrily.

**bolt_cycle** (Mosin/K98/SKS, 30f / 1.0s — the weapon's identity):
- lift bolt f0–6 (rotate ~90° up), pull back f6–14 (**shell-eject event ~f13**), push forward f14–24 (ease-in resistance, chambers), lock down f24–30 (crisp 2f snap).
- Trigger hand works bolt; support hand ANCHORS forestock (tiny counter-motion, not frozen).
- **ADS-out during beats 1–3, ADS-in on beat 4** (hand blocks the sight otherwise).
- Detail: the lift-up and lock-down "clacks" — hold each end pose 1–2f.

**draw** (24f / 0.8s, rifle): raise f0–14 (fast, hands lead gun by 1–2f), overshoot f14–18 (10–20% past idle), settle f18–24 (small secondary bob). Settle matters more than the raise. Pistol ~14f, MG ~28f+ saggier. Optional "check" flourish only on first-draw/inspect, ~8–10f.

**sprint**: a POSE, not a loop — gun canted down/inboard 30–45°, muzzle low. Blend IN 5–6f, OUT 3–5f (**faster out** so raising to fire is responsive; out must be interruptible). Procedural bob on top (code already does sway).

## idle sway
Keep procedural sway in CODE over a near-still idle pose. Optionally bake a subtle 4–6s breathing loop (1–2cm vertical) UNDERNEATH, additive — don't bake mouse-lag sway (must follow input).

## Godot binding (from VIEWMODEL_ANIM_SPEC.md)
Method-track keys at normalized % drive the mag prop swap + ammo logic. Same clip names every weapon. Controller written once.

Refs: L4D2 viewmodel guide, GoldSrc `$sequence fps 30`, CoD "Active Idle"/visual-recoil, CGCookie FPS tips, Jonathan Cooper Game Anim, Slava Borovik FP tutorial.
