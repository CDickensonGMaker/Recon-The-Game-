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

---

## ADDENDUM — overnight build wave (Summoner away, 2026-07-27 late)

**Transplant executed** (`tools/transplant_armory_parts.py`): all 11 fused single-mesh gun copies in
`fp_arms_rifle.blend` replaced by their finished armory assemblies with split moving parts and correct
origins. Mappings used per gun: fused-matrix (m70/colt45/ithaca/m60/thompson — the 7/19 join baked
armory coords), sight-trio (rpd/rpg2/rpg7/mosin — re-racked armories), center-translate+marker-reseat
(m72_law/m79 — their arms markers were stranded at armory coords; armory is now their truth).
LAW + Ithaca re-staged onto their arms (fixed-point vs a healthy reference rig). Rails clamped where
travel is recorded (Ithaca pump 45mm, LAW inner tube 230mm). 15 new contact markers seated on grasp
geometry; manifest `staged_contacts` holds the map until each gun joins the export contract.
Lesson re-learned and encoded: appended-but-unlinked objects AND viewport-hidden objects (LAW rearcap)
read identity matrices — link before measuring, exclude hidden from staging math.

**M70 scope shipped (code-complete, awaiting Summoner playtest per ADR-015):**
- `WeaponData.scope_overlay: Texture2D` (null = irons). M70 gets Caleb's scope art, recentred to
  `assets/ui/scope_overlay_m70.png` (source image untouched on his Desktop; hole was 8-15px off-center).
- `ScopeOverlay` control in hud.tscn: draws the frame texture square-covering the viewport and a
  code-drawn reticle (color/width/gap/arm exports — the "no middle cross" gap he named, tunable
  without art edits). Shows at ads_transition >= 0.9; green hip crosshair yields; DeathScreen stays above.
- weapon_holder hides the gun viewmodel under the scope at the same threshold. Zoom rides the
  EXISTING ADR-004 path — m70.tres ads_fov 40 -> 12 (~6.4x); no new camera.fov writer.
*Sacrificed:* scoped view replaces the modeled scope picture-in-picture (a lens-shader PiP was not
attempted — fullscreen overlay is the genre norm and the PSX-honest choice).
