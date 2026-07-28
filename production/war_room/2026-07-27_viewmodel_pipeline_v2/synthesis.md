# SYNTHESIS — Viewmodel Pipeline v2 (2026-07-27)

**The Summoner's diagnosis is CONFIRMED.** The per-gun breaks are symptoms. The disease has two organs:

1. **An export contract with a hole in it.** The bleed bug (constant object channels dropped → clips
   that never reset parts → the M16 chandle hanging off the receiver) is a documented Blender→Godot
   failure class we simply never gated. It is latent in all four exported guns.
2. **An authoring workflow where hands are posed in free space.** Industry does the opposite
   everywhere: the WEAPON owns named contact targets and the hands are pinned to them ("the gun leads,
   hands follow" — CoD tag_weapon, Lyra ik_hand_gun, Kinemation WeaponBone, Arma Reforger slot_*/snap_*).
   His marker/rail instinct is the industry convention arrived at independently.

Where we are ALREADY right (validated by lanes 1-2 against convention): GLB-only, NLA_TRACKS (mandatory
on Blender 5), headless driver + validators (ahead of indie norm), per-weapon GLB, AnimationPlayer-direct,
marker empties, real-scale + lens shader, measured penetration probe (ahead of industry — nobody has
automated clip checkers).

## DECREE (pending Summoner ratification)

**P1 — Close the bleed hole (mechanical, mine, now).**
`export_optimize_animation_keep_anim_object=True` in `export_viewmodel_clips.py`; new validator law:
EVERY clip must carry a channel for EVERY manifest part (the current rule is ≥1 part, rifle_idle
exempt — both weakenings die); re-export m16/ak/m14/ppsh through the strict driver (timers re-sync
automatically per Amendment A); Summoner eyeballs the M16 in game (ADR-015).
*Sacrificed:* marginally larger GLBs. Nothing else.

**P2 — Contact-marker + rail contract v2 (his proposal, ratified and shaped).**
Per gun, the manifest declares:
- a named contact empty for every hand-touch: `grip_R_*`/`grip_L_*` (exist) + `contact_<part>_<GUN>`
  for every manipulated part (chandle grab, mag well, drum latch, bolt handle, pump).
- every sliding part = 1-DOF rail child with origin at home (already law on the M16 chandle; extended
  to AK bolt and the PPSh bolt when it gets split).
- authoring law: a hand that touches a part is posed TO its contact marker (captured pose snaps/pins
  there), never eyeballed in free space.
- probe teeth: `audit_viewmodel_rigs.py` asserts hand-bone-to-marker distance inside declared contact
  windows; the penetration check stays as the second net.
*Sacrificed:* marker-authoring cost on every gun that gets touched; manifest churn; the freedom to
"just grab it somewhere" while animating.

**P3 — The bookend law (industry pop rule, makes the P1 class structurally impossible).**
Every clip starts AND ends on the identical weapon rest pose — armature and all parts. Audit probe
asserts first/last frame == rest within epsilon; validator asserts it GLB-side.
*Sacrificed:* authoring freedom to end a clip displaced (nothing we ship wants this).

**P4 — Procedural life layer (Godot-side, biggest anti-robotic lever, council-gated build).**
Additive spring-based sway/bob/recoil-impulse/idle-breathing on WeaponHolder over the authored clips
(Rosen's 13-keyframe doctrine; Tarkov layering; Vlambeer camera work). Buys "alive" for all 15 guns at
once and lowers the polish bar every authored clip must clear. Must integrate with ADR-034 (feel-bumps
already divide by magnification) and ADR-004 (no third camera.fov writer).
*Sacrificed:* a new runtime system to tune; risk of masking genuinely broken clips (probes stay).

## ROADS NOT TAKEN (named, per the law)
- **Bone-skeleton migration** (parts as armature bones — the industry default): REJECTED under the
  standing "harden, don't replace" verdict. The bake provably produces correct GLBs when flags are
  right; migration would orphan 99 authored actions and re-break blessed guns for a purity win.
  Revisit ONLY if the bake class produces a new failure shape after P1+P3.
- **Runtime TwoBoneIK hand-pinning** (Godot 4.6 modifiers): DEFERRED. A second authority over hands
  fights the baked clips and the ruling that animation quality is authored by the Summoner's hands.
- **Sprite-rendered weapons** (the boomer-shooter norm): out — ADR-001 killed the sprite renderer.

## UNCHANGED — the Summoner's authoring queue
AK reload handoff pairing (his posing, my capture/lock), PPSh real clips (replace AK transplants),
frozen-hand de-robotise passes (P4 reduces the bar but does not erase the queue), M16 post-surgery
look verification in game.
