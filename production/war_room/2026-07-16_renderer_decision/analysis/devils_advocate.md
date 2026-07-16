# Devil's Advocate — Renderer Decision (Forward+ → Mobile)

*No free lunches. Naming what the +40% costs us.*

## The recommendation, stated fairly

Mobile clears the 30 gate at native 1.0 (40.9 vs 29.2 FPS), the frame is fill/pipeline-bound not
primitive-bound, and the A/B screenshots look clean and on-aesthetic. On the numbers, Mobile is the
right call. My job is not to pretend otherwise — it is to name the bill.

---

## SACRIFICE 1 — Volumetric fog is the signature Vietnam-jungle image, and Mobile forbids it (Pillar 2 ceiling)

The single most iconic frame this game is reaching for — **god-rays punching through triple canopy,
morning mist lying over the paddies, light-shafts in the tunnel mouth** — is *volumetric* fog. Mobile
cannot do it. Ever. It is a hard renderer capability, not a tuning knob.

Right now the game ships only **exponential** fog (`mission_weather.gd:43-44`, `fog_density` per
weather; briefing confirms `0.004` baseline). Exponential fog works fine on Mobile. So **today nothing
breaks.** The sacrifice is the *upgrade path*: build order #6 is an explicit "Jungle feel pass"
(`GAME_GUIDE §4.9`: *"needs wind-sway shader, undergrowth layers, wilder composition"*), and the
obvious Pillar-2 move in that pass — turning flat exponential haze into volumetric god-rays through the
canopy — is the one door Mobile nails shut. Wind-sway (a shader) and undergrowth (geometry/instancing)
are fine on Mobile; god-rays are not.

**This is not a launch-blocker. It is a ceiling.** We are choosing, now, that the atmosphere pillar
tops out at exponential fog until/unless we revert. That deserves to be written into the ADR in ink, so
the jungle-feel council in a month doesn't "discover" it as a surprise and blame the renderer.

## SACRIFICE 2 — Dynamic lights already exist, night ops are in scope, and Mobile caps ~8 omni/spot per mesh

This is the one I want the Arbiter to actually weigh, because the briefing's "no dynamic point/spot
lights placed" is true of the *static spawn scene* and **false of the game.** The codebase already
spawns runtime `OmniLight3D`s in five systems:

| System | File | Energy / range | When |
|---|---|---|---|
| Illumination flare | `illum_flare.gd:30-34` | 3.5 / ~42m, **drifting** | **Night ops** — strips concealment in a circle |
| Muzzle flash | `gun_fx.gd:248-252` | 3.0 / 7m, capped `MAX_FLASHES` | Every shot fired |
| Explosion flash | `gun_fx.gd:116-120` | 8.0 / 16m, capped `MAX_EXPLOSIONS` | Every grenade/rocket |
| Village / camp fire | `mission_generator.gd:805-824` | 1.8 / flickering | Placed set-dressing |
| Tunnel mouth | `tunnel_room.gd:55-60` | 0.7 | Tunnel sections (in-scope: mouths) |

And **night is a real mission state** (`mission_weather.gd:55` `is_night`, a `NIGHT` time entry that
dims the sun and ambient). So picture the actual worst case the measurement never touched: **a night
firefight near a burning ville** — sun energy near zero, one or two drifting illum flares (30m radius
each), three or four muzzle flashes from the squad, a fire or two, maybe an explosion. Cluster half a
dozen of those omnis around the same hut mesh or the same knot of soldiers and you are **at or over
Mobile's ~8-omni/spot-per-mesh cap** — at which point Mobile silently drops lights: a muzzle flash that
doesn't light the wall, a flare that doesn't illuminate the man standing under it. On a game whose
whole night-combat readability *depends* on "muzzle flash always telegraphs" (the Fairness Law,
`GAME_GUIDE §1`), lights popping out is not just an atmosphere bug — it can nick **Pillar 1 clarity.**

Two honest mitigations before anyone panics: the flashes and explosions are **already count-capped**,
and the omni ranges are small (7-16m), so overlap-per-mesh is rarer than the raw list suggests. This is
a **risk to verify, not a proven breaker.** But it is exactly the scenario Forward+ is *built* to
handle — clustered lighting eats many small lights cheaply; Mobile's per-object forward light loop does
not. Which leads to the measurement complaint:

## SACRIFICE 3 (the methodological one) — we measured Mobile in the exact scene that flatters it

One stationary, open-ground, AO-center spawn. Almost certainly daytime (sun up, no flares, no
firefight, no fires lit). That is a **fill-rate** scene, and fill-rate is precisely where Mobile wins.
It is **not** a many-dynamic-lights scene, which is precisely where Forward+'s clustered lighting was
supposed to earn its cost. **We benchmarked Mobile on its home turf and Forward+ on foreign soil.**

- **Night firefight / arena with many characters + many omnis:** untested. Mobile's +40% could shrink,
  vanish, or — in a light-dense cluster — *invert*. The per-system attribution (cutting 100k
  primitives moved FPS ~0) tells us characters-as-geometry are cheap, which is reassuring for the
  arena's *primitive* load — but it says nothing about the arena's *light* and *draw-call* load, which
  is the axis where Mobile is structurally weaker.
- **Verdict is being drawn from n=1 pose.** That is thin evidence for a project-level, hard-to-reverse
  setting on a game with a named perf gate.

## What is NOT actually sacrificed (killing two strawmen)

- **SSAO / SSIL / SDFGI / SSR:** the game uses *none* of them today (briefing + code). Directional
  shadows are OFF (`game_world.gd:48`). So the sacrifice here is, again, a *future* grounding pass
  (SSAO would give foliage/characters contact shadows the game currently lacks) — a ceiling, not a
  loss. Worth naming, but it is not something Mobile is taking away from us right now.
- **ADR-024 cinematics are NOT affected.** The cinematic direction (AO on, subtle bloom, Eevee) is
  **Blender/Eevee prerendered FMV** rendered offline (`ADR-024` render settings, 640×480 @ 24fps). It
  never touches the Godot runtime renderer. Mobile forecloses nothing in the cutscene pipeline. Anyone
  who cites the cinematic ADR against Mobile is confusing offline render with runtime.

## The real trap: not the switch, the *lock-in that accretes*

The renderer is a one-line project setting — trivially reversible in isolation. The trap is second
order: **once we author materials, shaders, and a lighting look against Mobile's simpler tonemap and
its no-screen-space-effects world, every one of those assets silently assumes Mobile.** A revert to
Forward+ in a year to unlock god-rays then means re-validating the whole material library under a
different tonemap and HDR/glow path. **The cost of reversal is ~zero today and grows every week we
build on Mobile.** That is the thing to be clear-eyed about: we are not making a reversible decision,
we are making a decision whose reversibility decays.

Against that: **the thing we're throwing away is genuinely worth throwing away.** The shipped
`scale=0.77` FSR1 hack on Forward+ is a soft, upscaled native image papering over a renderer that still
can't clear 30. Mobile at native 1.0 is *sharper* (the A/B agrees) and clears the gate honestly. Good
riddance to the 0.77 crutch. Keeping Forward+ to preserve a volumetric-fog option we have not built,
may never build, and currently can't even run at framerate, is paying a certain cost now for an
uncertain option later. That is a bad trade.

## Config sub-question

- **Mobile + native 1.0** — recommended. Clears the gate, sharpest image, drops the FSR1 crutch.
- **Mobile + 0.77 bilinear** — no. FSR1 is Forward+-only, so 0.77 on Mobile is plain bilinear = mush
  for no reason (we don't need the headroom).
- **Stay Forward+ 0.77** — only defensible if a re-measure proves Mobile inverts in the night-firefight
  case. Absent that, it's the worse image *and* under the gate.

---

## Bottom line

Switch — but not on n=1. The measurement was taken in the one scene where Mobile is strongest and
Forward+ is pointless (day, open ground, zero dynamic lights), and the game's hardest renderer scene —
a **night firefight with flares, muzzle flashes, and fires**, which already exists in code — is exactly
where Mobile's ~8-lights-per-mesh cap and per-object light loop are weakest and Forward+'s clustered
lighting was supposed to pay off. That scene was never benchmarked. Lock Mobile, but only after one
adversarial re-measure of it, and write volumetric-fog + SSAO into the ADR as the **named Pillar-2
ceiling** Mobile imposes so the jungle-feel pass doesn't rediscover it as a betrayal.
