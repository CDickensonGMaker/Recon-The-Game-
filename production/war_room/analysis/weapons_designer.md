# WEAPONS DESIGNER — Per-Gun ADS Sight Geometry
**War Room 2026-07-14 · FP Weapons ADS (Blender)**
**Lens:** the rear aperture, the front post, the sight line, and the geometric consequences
for ADS FOV and viewmodel transform. No code changes proposed — only what the stager must build
and what the stager must NOT build. I read blueprints, the .tres files, ADR-004, the workflow doc,
the viewmodel .tscn files, and the export pipeline. I did not open the .blend or .glb binaries.

---

## 0. THE FINDING THE BRIEFING GOT WRONG (a mark for the Adversary)

The briefing states: *"Three empties planted: `sight_rear_<gun>`, `sight_front_<gun>`, `muzzle_<gun>`
(already done for M14 only)."* **This is false.** Verified three ways:

1. `m14_arms_viewmodel.tscn` (`scenes/weapons/`) is **a bare instantiation** of `m14_fp.glb` with
   a single `Model` child — no empties, no Markers, no MuzzlePoint node at all.
2. `grep -r "sight_rear\|sight_front\|muzzle_" scenes/` returns **zero matches** across all 14
   viewmodel .tscn files (and across the entire `scripts/`, `data/`, and `assets/player/viewmodels/`
   trees).
3. `VIEWMODEL_ANIM_SPEC.md:29` says *"M14 viewmodel already has one"* (a MuzzlePoint) — same drift
   pattern, same fossilised optimism. The MuzzlePoint contract is **wired on the consumer side**
   (`weapon_holder.gd:862` calls `find_child("MuzzlePoint", true, false)`) but the producer side
   has never delivered it. The .tres fields `hip_position` / `ads_position` / `ads_rotation` exist
   and are the ONLY data the camera-relative transform uses (`weapon_holder.gd:753-754`,
   `:795-796`), so the rig is *working today by hand-tuned vectors* — not by markers.

**Practical implication for this analysis:** "markers present" = **NO** for every gun, including
the M14. The status column in §1 starts from zero. The "M14 is the reference" claim in the
workflow doc is aspirational, not factual. **The M14 has the hand-tuned transform** in its .tres
(`m14.tres:32-34` carries non-stub `ads_position` / `ads_rotation` vectors) but no markers,
no sight line, no analytic basis. It is the most-tuned, not the most-built.

**A second finding the briefing did not name:** there is **no `weapons_soviet.blend` (or
equivalently-named file) anywhere in `assets/`.** The two weapon blend files are
`weapons_us.blend` and `weapons_v1.blend`, both in `assets/us/characters/`. The Soviet FP
viewmodels (ak_fp.glb, mosin_fp.glb, ppsh_fp.glb, rpd_fp.glb, rpg2_fp.glb) exist as exported
GLBs in `assets/player/viewmodels/`, but I cannot find a source `.blend` for them. **Either
the Soviet weapons are sitting inside one of the US blends** (a smell — the workflow says
`weapons_v1.blend` is the FP-arms compound file with the gun slot), **or the source was lost
in a prior restructuring and the GLBs are orphans.** The stager must resolve this before any
sight-line work begins on Soviet guns.

---

## 1. PER-GUN STATUS, GEOMETRY, AND READ

Common abbreviations used below:
- **SLH** = sight-line height (mm above bore), the Y of the rear aperture / front post tips.
- **SR** = sight radius (mm), the X distance from rear aperture to front post.
- **AP** = analytic ADS FOV (degrees) implied by SLH + SR, derived in §2.
- **Marker set** = whether the three empties (`sight_rear_*`, `sight_front_*`, `muzzle_*`) exist.
- **Mesh state** = whether the existing FP GLB has a real rear aperture + front post geometry
  authored (not just a stuck-on post). Inferred from blueprint fidelity; not measured inside GLB.
- **Transform state** = whether the .tres `ads_position` / `ads_rotation` are hand-tuned to a real
  value or are the placeholder stub `Vector3(0, 0.05, 0.08)` + `Vector3(4, 0, 0)` flagged in
  the briefing.

### US RIFLES

#### 1.1 M14 — REFERENCE GUN (the "most tuned")
- **Marker set:** NONE. The .tscn is a bare GLB instance; no empties.
- **Mesh state:** assumed-authoritative (workflow says M14 went through the full pipeline on
  2026-07-11, but I have only the GLB, not the .blend). Sight rebuild reported complete in
  `WEAPON_ADS_WORKFLOW.md:63`. **Verify in .blend before assuming.**
- **Transform state:** GOOD. `m14.tres:32-34` carries hand-tuned `ads_position = (-0.25, 0.175,
  -0.021)` and `ads_rotation = (-6.6, -9.97, 2.79)`. **The only gun in the roster with a
  non-stub ADS transform.** These numbers must be replaced by analytic ones from markers,
  not preserved as-is.
- **Blueprint sightline:** SLH **+26 mm** (aperture center Y +26, post tip Y +27 — §1 row 2/9
  of `blueprint_us_rifles.md`). **SR ≈ 827 mm** (rear aperture X 857, post X 8 → muzzle; use
  muzzle as front post: 857 − 8 = 849, or use the sight-radius from §1.4: post is ~15 mm
  forward of muzzle, so post→aperture = 842 mm. Use **842 mm** as the published radius.)
- **Rear aperture style (real):** M14 rear aperture is a **drum-type flip aperture** with
  two aperture diameters (small "battle" and larger "zero") selectable by lifting and rotating
  the drum. Both apertures are very small — Ø2 mm per blueprint. **For the PSX read, the
  aperture should be a single Ø2–3 mm hole, ring thickness ~0.5 mm** — the same game-style
  thin ring the workflow demands.
- **Front post style (real):** **clamped to the flash suppressor, dovetailed**, 16 mm tall
  blade 2 mm wide between two angled steel protective wings (dovetail ramps to the suppressor
  body). Wings protect the post and provide the iconic silhouette. **For the PSX read: blade
  ~8 mm tall (half the wing height) reads best through the ring** (workflow §3).
- **Blockers:** (a) marker set is missing — must be built from scratch despite the workflow
  claim. (b) `m14_fp.glb` ships through `fp_arms_rifle.blend` — the source blend and the gun
  the M14 corresponds to (`M14_Rifle`) is referenced by `tools/export_viewmodel.py:15` as
  the default arg. The gun object lives in `weapons_v1.blend` per the workflow (`step 6`).
  **Verify `M14_Rifle` is still there before any re-export.** (c) Hand-tuned
  `ads_rotation = (-6.6, -9.97, 2.79)` is non-zero on all three axes — confirms the M14 was
  posed with the workflow's analytic approach at some point, then the marker contract was
  never wired to it.
- **Difficulty:** 3/10 (geometry almost certainly already in the .blend; markers + verify
  + analytic rewrite of the .tres values is the work).
- **Needs modelling:** NO. Just markers + verify-by-raycast.

#### 1.2 M16A1 — THE SECOND-MOST-BUILT (per the briefing)
- **Marker set:** NONE (verified by .tscn inspection + grep).
- **Mesh state:** sight rebuild "complete" per `WEAPON_ADS_WORKFLOW.md:69` addendum. Adopted
  from a downloaded low-poly M16A1.fbx (`WEAPON_ADS_WORKFLOW.md:80` — **licensing/attribution
  bead is still OPEN**). The geometry should be present; verify.
- **Transform state:** PLACEHOLDER. `m16a1.tres:33-35` carries the briefing-flagged stub
  `ads_position = Vector3(0, 0.05, 0.08)` and `ads_rotation = Vector3(4, 0, 0)`. **This is
  exactly the "two-frame" smoking gun the briefing names** — the .tres is the place where
  the editor and the game can disagree.
- **Blueprint sightline:** SLH **+66 mm** (carry handle top; the sight line runs through
  the carry handle, *not* on top of it — `blueprint_us_rifles.md:67` row 8: "carry handle
  underside Y +52; gap under handle ≈ 24 mm tall × 150 long"; "rear aperture sight INSIDE
  rear leg, flip aperture at X 715, Y +66"). **SR ≈ 548 mm** (rear aperture X 715, front
  post X 167 → post 18 mm tall, top at Y 66; post→aperture = 548 mm).
- **Rear aperture style (real):** **integral to the carry handle's rear leg** (the iconic
  A1 look). Flip-up aperture with windage drum. The aperture hole is ~Ø2 mm. **For PSX:**
  single Ø2 mm hole, ring 0.5 mm thick, the rear leg of the carry handle is the rear sight
  housing. **This is the gun whose sight picture the player will see most often** — it
  deserves the most attention.
- **Front post style (real):** **round post Ø4 × 18 mm** on top of the FSB (Front Sight
  Base) between two protective ears, blade tip Y +66. **For PSX:** the triangular FSB
  silhouette with a small post between ears is the look; do not simplify to a single blade.
- **Blockers:** (a) placeholder .tres values (the briefing's smoking gun). (b) The
  **sight line is INSIDE the carry handle, not on top of it** — the rear aperture is
  *inside* the rear leg of the handle. The 24 mm gap under the handle is the player's
  unobstructed look-down window. Anything between the rear leg and the post (e.g. the
  front leg of the carry handle, charging handle, forward assist) is **dead center of
  the sight picture** and must be modeled to *not* intersect the sight line.
  (c) The download-source licence is still unverified.
- **Difficulty:** 4/10 (geometry probably present; markers + sight-line-collision-avoidance
  + the placeholder transform rewrite is the work).
- **Needs modelling:** UNLIKELY — verify the rebuilt geometry is actually in the .blend.

#### 1.3 WINCHESTER MODEL 70 (M70) — THE SNIPER
- **Marker set:** NONE.
- **Mesh state:** **unknown.** The blueprint offers two scope options: (A) the 8× Unertl
  Marine target scope (the one the briefing tells us to build) and (B) the Redfield 3-9×40.
  **The 8× Unertl changes the ADS read completely** — the sight line is *through a real
  scope tube*, not through iron apertures. There are **no iron sights** on a Marine
  Unertl'd M70 ("Marine armorers usually removed the front sight" — `blueprint_us_rifles.md:83`).
- **Transform state:** PLACEHOLDER. `m70.tres:34-36` — `ads_position = Vector3(0, 0.05, 0.08)`,
  `ads_rotation` is **absent** (script defaults to zero; .tres has only `hip_rotation`). The
  scoping position is the same stub the four placeholder guns share.
- **Blueprint sightline:** **No iron sight line.** The 8× Unertl scope tube is at
  Y +48 mm (Ø19 mm tube centerline), 610 mm long, suspended above the barrel by two
  mount blocks at X 455 and X 640. The eyepiece sits above the wrist at X 800–860.
  The **eye relief is ~70–80 mm behind the eyepiece** (Unertl's published spec).
- **Rear aperture / "iron" solution:** **N/A for ADS — it is a scope.** The PSX read
  is the **scope's eyepiece ring** as seen from the rear, then a circular scope
  vignette around the front post. **For PSX:** model the eyepiece as a thin black ring
  ~Ø30 mm; the tube interior (Ø19) is the sight window; the front post becomes a
  reticle cross OR (simpler, and honest) the post silhouette at the far end of the
  tube. **Aiming is "post covers target" through the scope.**
- **Front "post" (real):** **The reticle is the front sight now.** The Unertl's post
  reticle is a fine cross-hair; in PSX style, model as a thin black + or a simple post
  silhouette at the FAR end of the tube (X 250, Y +48 — the objective end, focused
  at infinity so it appears as a fixed-distance post).
- **Blockers:** (a) the whole scope assembly is a separate sub-assembly. It needs its
  own markers (`sight_rear_m70` = eyepiece center, X ~860, Y +48; `sight_front_m70` =
  reticle plane, X ~250, Y +48 — the "front post" is the reticle cross, conceptually
  600+ mm in front of the eye). (b) `m70.tres:33` carries `viewmodel_scale = 1.1` —
  the only gun with a non-default scale. The scope tube at 1.1× scale reads larger
  than the irons, which is correct (a 610 mm tube should dominate the sight picture),
  but the **auto-align tool must be scale-aware** or it will write a bad transform.
  (c) **The M70 is the most different ADS solution in the roster** — it is the only
  gun in the US half whose ADS is a scope, not irons. A workflow that assumes
  rear-aperture → front-post for all guns will mishandle the M70. **Per ADR-004's
  "per-weapon data" rule, the M70's `ads_fov = 40.0` is the scope's effective
  magnification**; the analytic ADS must compute against scope tube geometry, not
  iron-sight geometry.
- **Difficulty:** 7/10 (subassembly; the only US scoped rifle; scale-aware tool required;
  reticle modelling is a separate design call — cross or post or dot).
- **Needs modelling:** **MAYBE** — if the scope is currently absent from the M70 GLB.
  Workflow §3 says "designs but no constructed sight lines" for "all other roster guns" —
  the M70 was not in the M14/M16A1 "fully built" list. **Verify in the .blend before
  scheduling the scope work.**

#### 1.4 ITHACA 37 (shotgun.tres) — THE OUTLIER IRON-SIGHT GUN
- **Marker set:** NONE.
- **Mesh state:** bead sight on a post. **No rear sight at all** (Ithaca riot/trench
  configuration is a "bead-only" sight — `blueprint_us_rifles.md:144` row 1: "Single
  brass dot — only sight"). This is a major design choice.
- **Transform state:** PLACEHOLDER. `shotgun.tres:40-42` — `ads_position = Vector3(0,
  0.05, 0.08)`, `ads_rotation = Vector3(4, 0, 0)`.
- **Blueprint sightline:** **No defined sight line.** The bead is at X 6, Y +11 (post
  top); the eye looks down the barrel with the bead floating in space at the muzzle
  end. There is no rear reference. SLH is technically +11 mm (bead height above bore),
  but **there is no "sight" to be aligned to in the usual sense** — the player aligns
  "bead to target" with both eyes open.
- **Rear aperture style:** **NONE.** This is the gun the workflow's "thin ring" rule
  does not fit. The PSX read must be a **rib on top of the barrel** (the Ithaca's
  vent-rib is iconic but only on the trap/skeet models; the riot/trench 37 has a plain
  barrel). For a riot 37 the bead *is* the sight.
- **Front "post" style:** brass bead Ø3 mm on a Ø2 mm post (`blueprint_us_rifles.md:144`).
  The bead is a small bright dot that sits 11 mm above the bore. **For PSX: one
  emissive-ish yellow/brass dot, ~Ø3 mm on a 2 mm post.**
- **Blockers:** (a) the workflow is built around rear-aperture + front-post. The
  Ithaca has no rear aperture. **This gun needs a different ADS contract** — the
  "sight" is the bead, the "rear reference" is the player's own eye-relief-to-bead
  line, and the analytic ADS is "line up bead with target along the bore." A pure
  `ads_position` / `ads_rotation` lerp will still work (the gun just centers in the
  screen) but the bead needs to be **at the center of the screen** when ADS, not
  obscured by the receiver or stock. The bead IS the front post; treat the camera
  position as the rear aperture.
  (b) `shotgun.tres:39` `hip_position = Vector3(0.022, 0, -0.198)` — the hand-tuned
  hip is offset to the right of bore center, which suggests the gun was posed with
  a left-handed shoulder hold or off-center eye. **The bead must be on the screen
  vertical centerline when ADS.** (c) The Ithaca drop profile is severe (comb
  Y -38, heel Y -63, per `blueprint_us_rifles.md:160-163`); the stock pushes the
  player's head down to the bead, which means the ADS transform must RISE the gun
  in the view to compensate, not lower it.
- **Difficulty:** 4/10 (geometry is one bead; no rear sight to build; the work is
  the analytic ADS transform that centers the bead on screen and accounts for the
  stock drop).
- **Needs modelling:** NO (bead already in the .blend; verify). But the ADS solution
  is a *contract change* — the workflow assumes rear aperture; the Ithaca has none.

#### 1.5 M1911 (colt45_arms_viewmodel.tscn) — THE PISTOL
- **Marker set:** NONE.
- **Mesh state:** the M1911 has a **rear sight notch** (the classic 1911 "serrated
  rear slide") and a **front blade** on the front of the slide. This is the standard
  pistol sight pair: rear notch + front blade, NOT a peep-and-post.
- **Transform state:** PLACEHOLDER. `m1911.tres:36-38` — `ads_position = Vector3(0,
  0.05, 0.08)`, `ads_rotation = Vector3(4, 0, 0)`.
- **Blueprint sightline:** SLH **~+15 mm** (typical 1911 sight height above bore —
  blueprint does not cover M1911; derive from common 1911 specs: rear sight ~Y +12,
  front blade ~Y +18, line ~+15). **SR ≈ 130–150 mm** (rear sight at X ~190 from
  muzzle, front blade at X ~30–50; radius 140–160). The 1911 has the **shortest sight
  radius of any gun in the roster** — this is why pistol marksmanship is hard.
- **Rear aperture style:** **U-notch** (rear sight is a U-shape with serrations).
  This is **categorically different** from the peep apertures on the rifles. For
  PSX: a square notch ~3 mm wide, 2 mm deep, in the rear slide.
- **Front post style:** **blade ~3 mm tall, 1.5 mm wide**, sitting on the front
  of the slide. The blade tip is on the sight line.
- **Blockers:** (a) the PSX read for a pistol is "blade in the notch" — this is
  visually a different problem from "post in a ring" and the workflow does not
  address it. The analytic ADS must center the U-notch around the blade. (b) The
  1911 has the most sensitive sight radius in the game (a 1 mm misalignment is
  catastrophic at 25 m). The auto-align tool must be tight. (c) Pistols recoil
  vertically (recoil_vertical = 5.0, `m1911.tres:17`) — the slide reciprocates
  in the firing anim and the front blade moves with it. **The static sight picture
  is the slide-forward rest position; the firing anim blurs it for ~50 ms.**
- **Difficulty:** 5/10 (geometry exists; the analytic is a notch-around-blade
  solve, not a post-in-ring solve; recoil-anim interaction is a separate concern
  owned by the animator, not me).
- **Needs modelling:** NO. The 1911 is a documented pistol.

#### 1.6 M60 — THE "PIG" (HIP-FIRE, NOT IRON-SIGHT ADS)
- **Marker set:** NONE.
- **Mesh state:** real iron sights exist on the M60 (front blade, rear ladder leaf),
  but per ADR-004 the M60 is **hip-fire only** — the player does not "ADS" the
  M60. `m60.tres:18-20` carries `viewmodel_fov = 66.0` and `ads_fov = 60.0` — the
  ADS zoom is set but per the briefing and ADR-004 it should not be in the play
  loop. The .tres field exists, the code path is wired (`weapon_holder.gd:208-210`),
  but the design intent is "don't press the aim button on the M60."
- **Transform state:** PLACEHOLDER. `m60.tres:36-38` — `ads_position = Vector3(0,
  0.05, 0.08)`, `ads_rotation = Vector3(4, 0, 0)`.
- **Blueprint sightline:** SLH front blade Y +50 above bore, rear leaf raised to
  Y +130. **SR ≈ 625 mm** (front sight X 150–175, rear leaf hinge X 775; sight
  radius 600–625).
- **Rear aperture style:** **folding ladder leaf** with a small aperture on a
  sliding ramp. PSX read: a notched block (the leaf) standing up from the receiver,
  a tiny slot cut into the top.
- **Front post style:** triangular blade on a low block (the blueprint says
  "triangular blade, fixed on Vietnam-era guns"). PSX read: a single fixed blade.
- **Blockers:** (a) the M60 is **hip-fire by design** — the workflow's ADS
  front-post / rear-aperture contract does not apply. The stager should still
  author the markers (for the muzzle-zero contract; for tracer spawn; for
  potential future "sight-raise" if the player ever mounts the gun). The
  analytic ADS transform **should NOT be authored** — the M60 .tres
  `ads_position` and `ads_rotation` should be left at the placeholder (which
  the code lerps to during ADS even if ADS is disabled by gameplay), OR the
  ADS path should be gated by `firing_mode` or a per-weapon
  `allows_ads: bool` flag (which ADR-004 implicitly assumes exists but I cannot
  find in `WeaponData`). **This is an architect-level decision, not a
  weapons-designer decision — defer to the Arbiter.** (b) The M60 carries a
  feeding belt (`blueprint_us_support.md:42-52`); the belt droops from the
  feed slot at X 675, Y +5 down to Y −300. **The belt is part of the M60's
  silhouette and the stager must ensure the belt does not collide with the
  front post or sight line.** (c) The M60's bipod is folded for carry; the
  legs run rearward along the gas cylinder. **Verify the bipod does not
  rise above the bore in folded carry pose** (it should not — legs sit at
  Y −40 to −60, well below bore).
- **Difficulty:** 3/10 (geometry present, but the work is a deferred "author
  markers but do not author ADS transform").
- **Needs modelling:** NO. The M60 is a real gun with well-documented sights.

#### 1.7 M79 — THE BLOOPER (IRON-SIGHT ADS, BUT WITH A SPECIAL CAVEAT)
- **Marker set:** NONE. (M79 has no viewmodel .tscn currently — `m79.tres:37`
  `model_path = ""`.)
- **Mesh state:** real iron sights (front blade, rear ladder leaf), but the
  leaf is a **flip-up ladder graduated 75–375 m** and the **front sight is
  a fixed blade on a small base**. The combination is a notched leaf + blade,
  not a peep-and-post.
- **Transform state:** **NON-STUB.** `m79.tres:39-42` — `hip_position = (0.469,
  -0.627, -0.849)`, `ads_position = (0, -0.508, -0.755)`, `hip_rotation = (-4.7,
  80.6, 0)`, `ads_rotation = (0, 90, 0)`. **These are real, hand-tuned numbers —
  someone did the work.** The rotation `Vector3(0, 90, 0)` is the gun rotated
  90° around Y, which is consistent with a side-mounted hold of a short,
  heavy weapon. The ADS drops the gun slightly in Y and brings it forward
  in Z (`-0.849 → -0.755`) — a sensible "sight-raise" for a gun you shoulder
  and look over. **Keep these numbers; replace with marker-derived ones
  only if the analytic differs.**
- **Blueprint sightline:** SLH **+45 mm** (front blade tip, `blueprint_us_support.md:92`)
  with rear leaf raised to Y +155. **SR varies with leaf setting** (the ladder
  sight is range-adjustable). For a 100 m zero the rear notch is at ~+95 mm.
- **Rear aperture style:** **folding ladder leaf with graduated rungs** —
  a picture-frame quad. PSX read: a ladder frame, rungs as a texture, with
  yellow numerals painted on. The aperture is a small slot on the sliding
  bar.
- **Front post style:** fixed blade, simple, one box.
- **Blockers:** (a) **no viewmodel .tscn exists** for the M79. The .tres
  references `model_path = ""` — this gun has NO model. The M79 is broken
  on the FP side. (b) Even if a viewmodel .tscn is created, the M79 has
  the **same gun-rotation trick** (`ads_rotation = Vector3(0, 90, 0)`)
  that the existing hand-tune used — the gun is held **sideways** at the
  shoulder. **The auto-align tool must understand this rotation** (it is
  not a "tilt the camera 4°" rotation; it is a 90° Y-rotation of the gun
  relative to the camera). The tool's assumption of "rear aperture behind
  front post on the same X axis" **breaks for the M79** — the ladder leaf
  rotates with the gun, so the "behind" is now "+X in world but +X in
  gun-local is rightward."
  (c) The M79 fires HE grenades (40 mm, `m79.tres:14 base_damage = 150`,
  per ADR-016 amendment) — the sight picture at 100 m is a small slot
  on a ladder, the target is at most 150 m away. A 60° ADS FOV (the
  current .tres value) is *too generous* — the player will see a wide
  swath of jungle, not the ladder. The sniper-rifle FOV (~40°) is too
  tight. **My recommendation: 50–55°**, and verify against the rendered
  sight picture.
- **Difficulty:** 5/10 (geometry exists in the .blend if anyone built it;
  the viewmodel .tscn is missing entirely; the gun's 90° Y-rotation breaks
  the auto-align tool's axis assumption).
- **Needs modelling:** **MAYBE** — verify the M79 GLB has a sight assembly
  in the .blend; the viewmodel .tscn definitely needs to be created.

#### 1.8 M26 GRENADE — NO IRON SIGHTS, NO ADS
- **Marker set:** N/A.
- **Mesh state:** a fragmentation grenade; no sights.
- **Transform state:** HAND-TUNED IDENTITY. `m26_grenade.tres:39-42` —
  `hip_position = (0.2, -0.15, -0.3)`, `ads_position = (0.2, -0.15, -0.3)`,
  `hip_rotation = (0, 0, 0)`, `ads_rotation = (0, 0, 0)`. **The ADS transform
  is the same as hip — there is no ADS for a grenade.** Correct.
- **Blueprint:** N/A (grenade, not a firearm).
- **ADS solution:** **There is no ADS.** The grenade is cook-thrown from
  the hip. Per ADR-004, `ads_fov <= 10.0` means "no zoom" (the .tres
  carries `ads_fov = 75.0`, which is the base FOV — effectively no zoom,
  but a valid value). **The marker set is not needed for the M26.** The
  viewmodel .tscn exists (`m26_grenade_viewmodel.tscn`) with a scale of
  0.1 (not the typical 0.03 viewmodel scale — grenades are small, this
  is correct).
- **Blockers:** (a) `model_path = ""` in the .tres (line 27). The viewmodel
  is loaded via `ExtResource` to `res://assets/weapons/m26_grenade_low-poly/scene.gltf`
  — different from the rifle viewmodels. The pipeline is inconsistent.
  (b) `damage_type = 1` is set but `projectile_data_path = ""` (line 27)
  — the grenade has no projectile data, which is correct for a thrown
  explosive, but the empty string is a code smell (no validation guard).
- **Difficulty:** 1/10. No work needed beyond verification.
- **Needs modelling:** NO.

#### 1.9 M72 LAW — DISPOSABLE, NO IRON SIGHTS
- **Marker set:** N/A.
- **Mesh state:** the M72 LAW is a **disposable tube rocket launcher** with
  **no iron sights** in its standard form (some models had a simple wire
  sight, but Vietnam-era LAWs were fired from the shoulder using the
  tube's simple alignment cues — the launcher is essentially a 660 mm
  tube you point).
- **Transform state:** HAND-TUNED. `m72_law.tres:39-42` — `hip_position =
  (0.3, -0.25, -0.5)`, `ads_position = (0, -0.1, -0.4)`, both rotations
  zero. **The ADS position raises the gun slightly (Y -0.25 → -0.1) and
  pulls it back (Z -0.5 → -0.4)** — a "sight-raise" pose.
- **Blueprint:** N/A in the blueprints (the LAW is not in either US
  blueprint). The LAW is 665 mm long, 66 mm bore, 84 mm tube OD, with
  a pop-out grip/trigger assembly at the rear. There is no published
  sight height because there is no published sight.
- **ADS solution:** **The M72 is "sight-raise"** (per the briefing's
  `RPG-2 sight-raise` rule and ADR-004's hip-fire language for M60/RPD).
  The current `ads_position = (0, -0.1, -0.4)` is a reasonable approximation
  of "raise the back of the tube so the bore axis points roughly down
  the player's line of sight." **Keep these numbers; the analytic for
  a "sight-raise" without markers is "center the tube on screen, raise
  it so the bore is approximately level with the camera ray."**
- **Front / rear aperture:** N/A.
- **Blockers:** (a) **no viewmodel .tscn exists** — `model_path = ""`.
  The LAW is the worst-modeled gun in the roster. (b) The shared
  `rpg2_rocket.tres` `projectile_data_path` is wrong — the LAW fires
  a 66 mm rocket, the RPG-2 fires a 40 mm grenade. The projectile
  is wrong; this is a known drift per `briefing.md` adjacent items.
  (c) `ads_fov = 60.0` — ADR-004 implies this should be BASE_FOV
  (no zoom) for a hip-fire weapon, or close to it. 60° is fine for
  a "raise to shoot" pose.
- **Difficulty:** 2/10 (the gun has no sights; the analytic is "center
  and raise"; the .tres values are already in the right ballpark).
- **Needs modelling:** **YES — viewmodel .tscn is missing entirely.**
  The LAW has no FP model. **Highest priority among the "no-sight"
  weapons** because the player is supposed to fire it.

### SOVIET RIFLES

#### 1.10 AK-47 / TYPE 56
- **Marker set:** NONE.
- **Mesh state:** real iron sights present (front post, rear tangent leaf).
  PSX read: classic AK silhouette.
- **Transform state:** PLACEHOLDER. `ak47.tres:30-31` — `ads_position =
  Vector3(0, 0.05, 0.08)`, `ads_rotation` absent (script defaults to zero).
- **Blueprint sightline:** SLH **+48 mm** (post tip Y +48, notch Y +46,
  sightline ~+47). **SR = 378 mm** (post X 24 + 12 post height = ~36;
  rear notch X 411; sight radius 411 − 33 = **378 mm** per `blueprint_soviet_rifles.md:30`).
  This is the **shortest sight radius in the Soviet rifle set** —
  the AK is forgiving to aim but tight to align.
- **Rear aperture style:** **classic AK tangent leaf** with a sliding
  notch on a ramped base. The leaf is a stamped ramp 80 mm long with
  a slot the notch slides along. PSX read: the ramped leaf with a
  small rectangular notch is the entire rear sight.
- **Front post style:** **Ø2.5 mm post × 12 mm tall in a threaded
  drum** between two open ears (AK-47) or a fully hooded Ø16 hoop
  (Type 56). The hood is the visual identity of the Type 56.
- **Blockers:** (a) placeholder .tres (the same stub the briefing flags
  on AK-47 specifically — the owner's complaint about the AK is
  exactly this). (b) **The Soviet weapons blend does not exist**
  (per §0 finding) — the stager must either find the source .blend
  or author the AK in the US blend (a smell but a viable fallback).
  (c) The Type 56 variant has a **folding spike bayonet** that, when
  folded, runs along the cleaning rod / handguard belly at Y -30
  (`blueprint_soviet_rifles.md:60` row 24). The folded spike is
  310 mm long and runs from X 95 to X 400, **right along the sight
  line** (which is at Y +48 above bore at X 36–411). The spike is
  at Y -30, well below the sight line — **no collision risk** —
  but the stager must verify the spike is parented to the gun
  correctly so it does not clip the handguard in the firing anim.
- **Difficulty:** 4/10 (geometry presumably present in the FP GLB;
  markers + verify + replace placeholder transform is the work).
- **Needs modelling:** UNLIKELY — verify the Soviet GLB has a real
  rear tangent leaf (not a placeholder block).

#### 1.11 MOSIN-NAGANT 91/30 — THE TIGHTEST SIGHTLINE
- **Marker set:** NONE.
- **Mesh state:** hooded post front sight, tangent rear leaf. The
  Mosin is the **bolt-action rifle with the iconic straight bolt
  handle** (the bolt handle is "95 mm AHEAD of the trigger" —
  `blueprint_soviet_rifles.md:95` row 12).
- **Transform state:** PLACEHOLDER. `mosin.tres:37-38` — `ads_position
  = Vector3(0, 0.05, 0.08)`, `ads_rotation` absent.
- **Blueprint sightline:** SLH **+25 to +29 mm** (post tip Y +25, hood
  top Y +32, notch Y +29, line ~+27). **SR = 622 mm** (front post X
  16, rear notch X 640, sight radius 622 — verified per `blueprint_soviet_rifles.md:78`).
  This is **the longest sight radius in the Soviet rifle set and one
  of the longest in the roster** — the Mosin is a precision rifle
  by design.
- **Rear aperture style:** tangent leaf, slider on a curved ramp,
  arshin/meter graduations. The leaf is wider than the AK's (75 mm
  base) and the ramp is curved, not straight.
- **Front post style:** **globe hood** — a Ø18 mm cylinder (open
  front and back) around a thin post. The globe hood is the
  signature Mosin silhouette; it is **NOT** an open-blade sight.
- **Adversarial finding (named per the prompt):** **The Mosin
  sightline at +27 mm is the tightest in the roster.** A real
  Mosin's iron sight picture is *physically tight* — the rear
  notch is small, the post is thin, and the line is only ~27 mm
  above the bore. Combined with the long 622 mm sight radius
  and the iconic straight bolt handle protruding to the right
  (Z +58, well clear of the sight line), the Mosin's iron sight
  picture is **legible but unforgiving**. **At 40° ADS FOV**
  (the .tres value) the sight should be readable. **Verify
  with a render**, not with math: at 40° FOV, the rear notch
  + front post need to be large enough in pixels to be useful.
  A 2 mm aperture at 40° FOV and 622 mm radius is **a sub-pixel
  problem** in screen space — the math works, the eye cannot.
  **Recommendation: a PSX-style exaggerated rear aperture** of
  Ø4–5 mm (vs the real ~Ø2 mm) so the notch reads at low FOV.
  The workflow's "thin ring, big hole — game style" is the
  right answer here; the **real Mosin is too small for the
  game's pixel grid**.
- **Blockers:** (a) placeholder .tres. (b) **The .blend source
  for the Mosin FP viewmodel does not exist** (per §0 finding).
  (c) The Mosin is the only gun in the roster where the **bolt
  handle is a sight-line-clearance concern** — the bolt handle
  is on the right (Z +58), the sight line is centered (Z 0),
  and the handle swings through a 90° arc during reload. The
  stager must verify the bolt handle is parented to the bolt
  and that the bolt handle's "down" position does not intersect
  the sight line. **It does not** (handle at Y -3, sight line
  at Y +27 — 30 mm clear), but the firing anim is the
  animator's concern, not mine. (d) `mosin.tres:35`
  `viewmodel_scale = 1.1` — same scale anomaly as the M70.
  Scale-aware tool required.
- **Difficulty:** 5/10 (geometry present in GLB; the *real*
  sight is too small for the PSX pixel grid and the auto-align
  tool will not know that — the stager must apply a
  game-style exaggeration that the analytic cannot derive).
- **Needs modelling:** NO. But the **PSX sight exaggeration
  is a design call** that the workflow does not cover.

#### 1.12 PPSh-41 — THE BURP GUN
- **Marker set:** NONE.
- **Mesh state:** front post between two ears, flip L-shaped rear
  sight with two notches (100 m and 200 m). The PPSh sight picture
  is the **flattest, lowest-profile in the Soviet SMG set**.
- **Transform state:** PLACEHOLDER. `ppsh41.tres:36-38` —
  `ads_position = Vector3(0, 0.05, 0.08)`, `ads_rotation = (4, 0, 0)`.
- **Blueprint sightline:** SLH **+40 mm** (post tip Y +40, notch
  Y +38). **SR ≈ 395 mm** (front post X 31, rear notch X 425 —
  `blueprint_soviet_rifles.md:137` row 9).
- **Rear aperture style:** **flip L** with two notches on a small
  base. The flip L is the wartime-standard cheap sight; the
  two notches give 100 m and 200 m zeros. PSX read: a small
  block with a flipped-up L-arm and a notch.
- **Front post style:** **post between two ears** — same as the
  AK, but on a much shorter sight radius. The PPSh front
  sight is the iconic burp-gun look.
- **Blockers:** (a) placeholder .tres. (b) PPSh viewmodel
  `ppsh_arms_viewmodel.tscn` exists, but per the .tres the
  model is loaded from `assets/player/viewmodels/ppsh_fp.glb`
  — verify the GLB has the flip L. (c) The PPSh carries a
  **71-round drum magazine** (`blueprint_soviet_rifles.md:138`
  row 10) — drum center at X 358, Y -108, drum diameter
  Ø152 mm. The drum is **the dominant mass of the gun's
  silhouette** and is well below the sight line (Y -184
  bottom vs Y +40 sight line — 224 mm clear). **No
  sight-line collision risk**, but the drum occupies a
  large amount of screen real estate at the bottom of
  the viewmodel and the player will see it constantly.
  (d) The PPSh shroud has **three vent slots per side**
  (`blueprint_soviet_rifles.md:131` row 3) — long rounded
  rectangles in the shroud flanks. The vents are at Y +6
  (well below the sight line at Y +40) — **no sight-line
  collision risk**, but the stager must ensure the vents
  do not visually "leak" sight-line illusion. (e) The
  PPSh charges via a knob on the right side of the receiver
  (X ~345, Y +5) — the knob reciprocates with firing
  and **its vertical movement could appear to be recoil
  through the sight picture** if the player notices it.
  This is an animator concern; I flag it for completeness.
- **Difficulty:** 4/10 (geometry present; the flip L is a
  simple stamped part; the analytic is straightforward).
- **Needs modelling:** NO. Verify the flip L is in the GLB.

### SOVIET SUPPORT

#### 1.13 RPD — THE RUSSIAN M60 (HIP-FIRE, NOT IRON-SIGHT ADS)
- **Marker set:** NONE.
- **Mesh state:** real iron sights (front post between ears, AK-style
  tangent leaf). Like the M60, the RPD is **hip-fire** per ADR-004.
- **Transform state:** PLACEHOLDER. `rpd.tres:35-37` — `ads_position =
  Vector3(0, 0.05, 0.08)`, `ads_rotation = (4, 0, 0)`.
- **Blueprint sightline:** SLH **+48 mm** (post tip Y +48, tangent
  leaf notch ramps to Y +52). **SR ≈ 725 mm** (front post X 20–55,
  rear tangent leaf X 745–805; use 750).
- **Rear aperture style:** AK-style tangent leaf (the RPD
  uses AK-pattern sights — `blueprint_soviet_support.md:71`
  row 10: "Classic AK-style tangent: sliding notch on a
  ramped leaf"). The RPD is "AK sights on a bigger gun."
- **Front post style:** cylindrical post between two protective
  ears (`blueprint_soviet_support.md:62` row 2: "Cylindrical
  post between two protective ears (ears = 2 angled plates
  or a C-hood). Drum-shaped base clamps barrel").
- **Blockers:** (a) **hip-fire by design** — same as the M60,
  the ADS transform should not be authored; markers should
  be authored (muzzle-zero, tracer spawn) but the ADS
  path is unused in normal play. (b) The RPD has a
  **100-round belt drum** (`blueprint_soviet_support.md:73`
  row 12) — drum center at X 575, Y -140, drum diameter
  Ø170 mm. **The drum is the heaviest visual mass of the
  gun** (drum bottom at Y -225 — the lowest point of the
  entire RPD silhouette). The drum is **far below the
  sight line** and does not collide. (c) The RPD's bipod
  is folded along the barrel/gas tube (Y -15, well below
  sight line) — no collision. (d) The RPD has **no
  carrying handle** (`blueprint_soviet_support.md:54`:
  "**No carrying handle** on the standard RPD/Type 56 (do
  not add one — that's the RPD's distinctive clean top
  line)") — this is a design rule the stager must respect.
  The M60 has a carrying handle; the RPD does not. The
  top of the RPD is **clean from muzzle to rear sight**.
- **Difficulty:** 3/10 (geometry present; deferred ADS; markers
  only).
- **Needs modelling:** NO.

#### 1.14 RPG-2 — THE SIGHT-RAISE TUBE
- **Marker set:** NONE.
- **Mesh state:** real iron sights (front flip-up post, rear
  flip-up leaf) but the RPG-2 is **sight-raise**, not
  iron-sight ADS, per ADR-004. The flip-up post is at
  Y +75 raised (Y +22 base), the leaf top is at Y +90
  raised. The post and leaf are tiny stamped parts; the
  RPG-2's primary aiming method is the tube itself.
- **Transform state:** PLACEHOLDER. `rpg2.tres:37-39` —
  `ads_position = Vector3(0, 0.05, 0.08)`, `ads_rotation =
  (4, 0, 0)`. **The placeholder is wrong for the RPG-2.**
  The .tres fields should be a "sight-raise" pose (raise
  the back of the tube so the bore is roughly level with
  the camera ray), not the standard stub.
- **Blueprint sightline:** **NOT MEANINGFUL FOR THE RPG-2.**
  The iron sights exist but are not the primary aiming
  method. The bore axis is the sight line; the player's
  eye is the rear aperture; the PG-2 grenade (loaded
  state) is what the player aims. The PG-2 nose sits
  250 mm ahead of the muzzle, 82 mm caliber, ogive
  profile (`blueprint_soviet_support.md:38-46`).
- **Front / rear aperture (real):** front flip-up post
  (~Ø3 mm, raised to Y +75), rear flip-up leaf with
  aperture notch (raised to Y +90). PSX read: the post
  is a small bump on top of the tube; the leaf is a
  small ramp. **Neither is the primary aim.**
- **ADS solution:** **"Sight-raise" per ADR-004** — the
  stager authors the muzzle marker (the bore exit at
  Y 0, X 0) and the rear-sight *and* the front-sight
  markers, but the analytic ADS transform is **"center
  the tube on screen, raise it so the bore is roughly
  level with the camera ray, ignore the iron sight
  picture."** A `sight_rear_rpg2` / `sight_front_rpg2`
  pair is technically present but the analytic for ADS
  uses the muzzle + bore axis, not the iron-sight
  geometry.
- **Blockers:** (a) placeholder .tres. (b) The RPG-2
  carries a **PG-2 grenade** that protrudes **250 mm
  past the muzzle** at all times. The grenade is the
  most distinctive visual element and **must be parented
  to the gun** so the grenade moves with the viewmodel.
  (c) The wooden heat-guard (X 450–810, Y 0, OD 62)
  is **a large mass centered on the bore** — the
  stager must ensure the heat-guard is symmetric and
  does not occlude the bore visually. (d) The pistol
  grip is single, no rear support grip (that's the
  RPG-7) — the stager must not double-grip.
- **Difficulty:** 4/10 (no iron-sight analytic; "sight-raise"
  is a separate formula; grenade is a separate object).
- **Needs modelling:** **MAYBE** — verify the PG-2 grenade
  is parented correctly and follows the gun in the
  viewmodel .tscn.

#### 1.15 RPG-7 — THE SIGHT-RAISE WITH OPTIC RAIL
- **Marker set:** N/A in viewmodel (no .tscn exists; `rpg7.tres:37`
  `model_path = ""`).
- **Mesh state:** **No FP viewmodel.** The RPG-7 is broken on
  the FP side the same way the M79 and M72 LAW are.
- **Transform state:** HAND-TUNED. `rpg7.tres:39-42` —
  `hip_position = (0.3, -0.25, -0.5)`, `ads_position = (0, -0.1,
  -0.4)`. **These are the same values as the M72 LAW** — copy-paste
  from one .tres to the other. Both are "sight-raise" weapons
  with no real ADS, so the duplicate values are reasonable,
  but the **.tres-level duplication is a code smell**.
- **Blueprint sightline:** **NOT MEANINGFUL.** Same as the
  RPG-2. The RPG-7 has a **PGO-7 optic rail** on the left
  side (X 430–520, Y +10 to +30, dovetail bar for the PGO-7
  scope — `blueprint_soviet_support.md:98` row 5). The
  briefing says "VC version omits scope" so for RECONgame
  the RPG-7 is "sight-raise" like the RPG-2.
- **ADS solution:** **"Sight-raise" same as RPG-2.** The
  bore axis is the sight line; the player aims with the
  tube, not the irons. The PGO-7 optic rail is modeled
  (per blueprint) but the optic itself is omitted (VC
  look).
- **Front / rear aperture:** N/A (sight-raise).
- **Blockers:** (a) **no viewmodel .tscn** — same as LAW/M79.
  (b) The RPG-7 has **two grips** (front trigger grip +
  rear support grip) — `blueprint_soviet_support.md:100-101`
  rows 6+8. The stager must model both grips. (c) The
  RPG-7 has a **bulged mid-rear expansion chamber** (OD
  44 → 72 → 44, X 560–800) — the iconic RPG-7 silhouette
  is **the bulge**. (d) The venturi bell at the rear
  (X 800–950, OD flares to 74 at exit) is the other
  iconic RPG-7 feature. (e) The PG-7V grenade is
  **larger than the PG-2** (caliber 85 mm vs 82 mm, length
  925 mm vs ~700 mm) and protrudes **390 mm past the
  muzzle**. (f) The shared `rpg2_rocket.tres`
  `projectile_data_path` is **wrong for the RPG-7** —
  the RPG-2 fires a 40 mm rocket, the RPG-7 fires a
  PG-7V grenade. Same drift as the M72 LAW.
- **Difficulty:** 6/10 (no viewmodel, complex geometry —
  two grips, bulged chamber, venturi bell, large grenade
  protrusion; sight-raise analytic; wrong projectile
  data).
- **Needs modelling:** **YES — viewmodel .tscn is missing
  entirely, and the model itself must include the bulged
  chamber + venturi + dual grips + PG-7V grenade.** Highest
  modelling priority among the no-sight weapons.

---

## 2. PER-WEAPON ADS FOV (vs. ADR-004)

ADR-004 establishes: **base 75°, per-weapon `ads_fov`, binoculars 18°**. Each .tres carries
a value. The question for this council: **does the value match the sight geometry?**

I cannot measure against the geometry (the markers do not exist), so the only check I can
do is: **does the FOV make the sight picture legible at the gun's sight radius and
sight-line height?** The math is: at distance SR, the front post subtends an angle of
`2 * atan(post_half_width / SR)`. The screen-pixel width is `screen_w * angle / FOV_rad`.
For a 1080-wide screen, a post 1 mm wide at SR 600 mm subtends 1.7 milliradians; at
60° FOV (1.047 rad) that is 0.16% of screen width = ~1.7 pixels. **Sub-pixel, illegible.**

**The 1.7-pixel problem:** every gun in the roster has a sight geometry that, at realistic
SR, produces a sub-pixel front post at 60° FOV. **This is the fundamental tension** between
"real sight geometry" and "PSX-style legibility." The workflow resolves this by
**exaggerating the aperture / post sizes in the game model** — "thin ring, big hole — game
style." The .tres `ads_fov` does not need to change to fix the pixel problem; **the
geometry does.** So:

| Gun | .tres `ads_fov` | My verdict | Why |
|-----|-----------------|-----------|-----|
| M14 | 58.0 | **KEEP.** | 58° + exaggerated Ø3 mm aperture at 842 mm SR is legible; tighter (50°) would feel sniper-rifle without the precision, looser (65°) would lose the iron-sight intimacy. |
| M16A1 | 60.0 | **KEEP.** | 60° + the carry-handle-integral aperture at 548 mm SR is the iconic A1 read. The brief was 60° for a reason. |
| M70 | 40.0 | **KEEP.** | 40° is the scope's effective magnification at the Unertl's 8× — this is the **only gun in the roster where the `ads_fov` is a derived value** (8× of 75° base ≈ 9.4°, but the Unertl's practical field of view is closer to 40° due to eye relief). **Verify by rendering the Unertl tube and measuring the visible field at the eyepiece.** |
| Ithaca 37 | 65.0 | **RAISE TO 70.** | The bead is the sight and there is no rear aperture; the player aims by bead-on-bore. A wider FOV (70°) keeps the barrel and bead both visible. 65° is acceptable but 70° is more honest. **This is a feel call, not a math call.** |
| M1911 | 65.0 | **KEEP.** | The 1911 is held high; the U-notch + blade is the tight sight picture. 65° at 140 mm SR is legibility-tight but the 1911 is a "deliberate aim" gun by design. |
| M60 | 60.0 | **SHOULD BE 75.0 (NO ZOOM).** | Hip-fire weapon. Per ADR-004 the M60 stays at hip. **The .tres value should match the gameplay rule; `ads_fov = BASE_FOV` (75.0) is the no-zoom value.** Alternatively the ADS path should be disabled for the M60 — that is an architect-level call. |
| M79 | 65.0 | **LOWER TO 55.** | The M79 ladder sight is the rear aperture, the front blade is the front post; at 100 m zero the SR is tight and the player needs to see the ladder. 65° is too generous. **55° is more honest to the ladder-sight read.** |
| M26 | 75.0 | **KEEP.** | Grenade, no ADS, no zoom. Correct. |
| M72 LAW | 60.0 | **SHOULD BE 75.0 (NO ZOOM).** | Sight-raise weapon. The .tres value is meaningless during gameplay (the gun is fired from the shoulder, not aimed through sights) but ADR-004 says no-zoom weapons get `BASE_FOV`. **75.0 is the honest value.** |
| AK-47 | 62.0 | **KEEP.** | 62° at 378 mm SR is the AK's sweet spot — tight enough to feel the short sight radius, loose enough to see the leaf. |
| Mosin | 40.0 | **KEEP BUT VERIFY.** | 40° at 622 mm SR is the precision-rifle read. The PSX exaggeration of the rear aperture (Ø4–5 mm vs real Ø2 mm) is what makes this legible. **If the stager does not exaggerate, 40° is too tight and the post is a single pixel.** |
| PPSh-41 | 58.0 | **KEEP.** | 58° at 395 mm SR is a SMG-appropriate tightness. |
| RPD | 60.0 | **SHOULD BE 75.0 (NO ZOOM).** | Hip-fire weapon. Same call as M60. |
| RPG-2 | 60.0 | **KEEP BUT CONSIDER 65.** | Sight-raise weapon. The tube dominates the screen; 60° is fine but 65° keeps the PG-2 grenade nose visible at the top of the frame. **Feel call.** |
| RPG-7 | 60.0 | **KEEP.** | Same as RPG-2 but with the larger PG-7V grenade. 60° is fine. |

**Summary:** **8 KEEP, 4 SHOULD-CHANGE (M60/M72 LAW/RPD → 75; M79 → 55; Ithaca → 70).**
None of these are math violations; they are gameplay-rule applications. **The architect (Arbiter)
decides whether the M60/RPD/LAW ADS path is enabled at all** — if it is, the FOV is 75
(no zoom); if it is not, the FOV is moot but should be honest.

---

## 3. PER-WEAPON SIGHT-RAISE / OPTIC DECISIONS (per ADR-004)

ADR-004 establishes three ADS categories:

**(A) Iron-sight ADS:** real rear aperture + front post, both modelled, analytic `ads_position`
derived from the sight-line geometry. The marker trio (`sight_rear_*`, `sight_front_*`,
`muzzle_*`) is the contract. **Guns:** M14, M16A1, M70 (scope — sub-variant), Ithaca 37
(bead only — sub-variant), M1911, AK-47, Mosin, PPSh-41.

**(B) Hip-fire:** no ADS path in normal play. The marker trio is still authored (for muzzle-zero
and tracer spawn), but `ads_position` and `ads_rotation` are not used. The .tres values
should be `BASE_FOV` (75.0) so the FOV lerp is a no-op. **Guns:** M60, RPD. **The M72 LAW
and RPG-2/RPG-7 are NOT in this category** — they are sight-raise.

**(C) Sight-raise:** the gun's bore axis is the sight line; the player's eye is the rear
aperture. The marker trio is authored (rear and front "sight" markers are vestigial; the
muzzle marker is the load-bearing one), and the analytic `ads_position` is "center the tube
on screen, raise it so the bore is roughly level with the camera ray." **Guns:** M79 (sort
of — the M79 has real irons but the launcher's short length and heavy stock make sight-raise
the practical ADS), M72 LAW, RPG-2, RPG-7.

**Note on the M79:** the M79 has real iron sights (front blade, rear ladder leaf) and at
100 m the iron sight picture is usable. The hand-tuned `ads_rotation = (0, 90, 0)` is
the gun rotated 90° around Y — this is a side-hold pose, not a sight-raise pose. **The
M79 sits on the boundary between (A) and (C).** The current hand-tune is closer to (A)
with a side-mounted hold. I defer to the Arbiter: is the M79 a side-hold iron-sight gun
or a sight-raise gun?

**Note on the M26 grenade:** no ADS, no sights, hand-thrown. Category N/A.

**Per-weapon assignment (my recommendation):**

| Gun | Category | Markers needed? | `ads_position` source |
|-----|----------|-----------------|---------------------|
| M14 | A (iron) | YES (3) | analytic from sight line |
| M16A1 | A (iron) | YES (3) | analytic from sight line |
| M70 | A (scope sub) | YES (2 — no muzzle-zero, scope zeroes the bore) | analytic from scope geometry |
| Ithaca 37 | A (bead sub) | NO rear sight; 1 front + 1 muzzle | analytic from bore + bead |
| M1911 | A (iron) | YES (3) | analytic from sight line |
| M60 | B (hip) | YES (muzzle only; front/rear for tracer completeness) | not used; .tres = (0,0,0) or BASE_FOV |
| M79 | A↔C (boundary) | YES (3) | analytic, but the 90° Y-rotation must be preserved |
| M26 | N/A | NO | identity |
| M72 LAW | C (sight-raise) | YES (muzzle only) | sight-raise analytic |
| AK-47 | A (iron) | YES (3) | analytic from sight line |
| Mosin | A (iron) | YES (3) | analytic from sight line; **PSX-exaggerated aperture** |
| PPSh-41 | A (iron) | YES (3) | analytic from sight line |
| RPD | B (hip) | YES (muzzle only; front/rear for tracer completeness) | not used; .tres = (0,0,0) or BASE_FOV |
| RPG-2 | C (sight-raise) | YES (muzzle only) | sight-raise analytic |
| RPG-7 | C (sight-raise) | YES (muzzle only) | sight-raise analytic |

---

## 4. ORDER OF OPERATIONS (which 3-4 guns ship first, in what order)

The briefing and the workflow both name the **M14** as the reference. But the M14 is also
the gun with the most-tuned .tres values (hand-set) and the workflow says its sight rebuild
is complete. **The M14's bottleneck is the markers, not the geometry.** The geometry is
presumed-done. The work is: (1) verify the sight rebuild in the .blend, (2) plant the three
empties, (3) re-export the .glb with the marker renamed to MuzzlePoint, (4) measure by
raycast per the addendum, (5) write the analytic `ads_position` / `ads_rotation` from
the markers.

**My recommended order** (tuned for the dependency graph, not the prestige):

1. **M14** (iron, US, has the hand-tuned .tres to validate the analytic). Verifies the
   pipeline end-to-end. **Difficulty 3, highest payoff** because the analytic replaces a
   hand-tune that has been the de-facto reference.
2. **M16A1** (iron, US, has the placeholder .tres and the carry-handle-integral aperture
   that breaks the "behind" assumption). Verifies the analytic handles a gun whose rear
   sight is INSIDE another part. **Difficulty 4, second-highest payoff** because the
   placeholder .tres is the briefing's "two-frame smoking gun."
3. **AK-47** (iron, Soviet, has the placeholder .tres AND the missing source .blend).
   Verifies the analytic handles a Soviet gun AND forces the stager to find or author
   the Soviet weapons source blend. **Difficulty 4, critical** because every other Soviet
   gun's work depends on resolving the missing .blend question.
4. **M60** (hip-fire, US, has the placeholder .tres but the design says no ADS).
   Verifies the "markers yes, ADS no" path. **Difficulty 3, important** because the
   M60/RPD/muzzle-marker pattern is the same and the stager needs the muzzle-marker
   contract nailed before doing the 5+ guns that depend on it.

**Optional fifth if the owner is hot on Soviet coverage: PPSh-41** (iron, Soviet, has the
placeholder .tres and the iconic drum that breaks the screen real estate). **Difficulty 4.**

**Deferred (do NOT ship first):**
- **M70** — scoped, sub-variant, requires the sub-assembly modelling decision.
- **RPG-2 / RPG-7 / M72 LAW / M79** — missing viewmodel .tscn, the work is *first* model
  the gun, *then* author the markers. Modelling precedes markers.
- **Mosin** — the PSX aperture-exaggeration call is a separate design decision the
  workflow does not cover. Do this after the M14/M16A1/AK-47 are done and the analytic
  is trusted.
- **Ithaca 37, M1911, RPD** — niche (bead-only, pistol, hip-fire) and depend on the
  pipeline being proven.

---

## 5. WHAT THE BLENDER WORK DEMANDS OF THE STAGER (named contract)

For each of the 15 guns in the roster, the stager must do ONE of the following:

### Tier 1 — Author markers on existing geometry (the M14-class work)
**For:** M14, M16A1, AK-47, Mosin, PPSh-41, M1911, Ithaca 37, M60, RPD.
**Required actions:**
- Open the source .blend (M14/M16A1/M60 = `weapons_v1.blend` or `weapons_us.blend`;
  AK-47/Mosin/PPSh-41 = **UNKNOWN — see §0**; the source .blend for Soviet FP viewmodels
  does not exist as a separate file).
- Verify the gun's sight geometry (rear aperture + front post) is present in the model
  per the blueprint.
- Plant THREE empties, parented to the gun object, with `matrix_parent_inverse = identity`:
  - `sight_rear_<gun>` at the rear aperture center (X = blueprint rear-sight X, Y = SLH,
    Z = 0). **For the M16A1 this is INSIDE the carry handle's rear leg, not on top of it.**
  - `sight_front_<gun>` at the front post tip (X = blueprint front-sight X, Y = SLH,
    Z = 0). **For the M16A1 this is the post on the FSB between the two ears.**
  - `muzzle_<gun>` at the exact bore exit (X = 0 at the muzzle face, Y = 0 on the bore,
    Z = 0). **Rotated so its forward axis converges with the sight line at 50 m**
    (workflow §4 — `tilt = atan(sight_height / 50)`).
- Verify by **fresh-depsgraph raycast** per the M16 addendum
  (`WEAPON_ADS_WORKFLOW.md:71-75`): cast rays from a realistic ADS eye position
  (~20 cm behind the aperture, ±2-3 mm pupil offsets) toward the front post. **Majority
  must run clear / hit the post.** A render taken exactly on the ideal line will hide
  blockers.
- Re-export the gun with the markers via `tools/export_viewmodel.py`. The script
  auto-renames `muzzle_<gun>` to `MuzzlePoint` (line 57-60).
- **Do NOT modify** the `tools/export_viewmodel.py` defaults — the GUN arg, the
  IDLE arg, and the OUT path are the script's contract.
- **Do NOT touch** the .tscn wrapper — the `M14ArmsViewmodel.tscn` is a 7-line
  instantiation; the new markers are inside the GLB, not the .tscn.

### Tier 2 — Build geometry + markers (the LAW-class work)
**For:** M79, M72 LAW, RPG-7. (RPG-2 may be Tier 1 if the GLB has a gun object already.)
**Required actions:**
- Author the gun mesh in the source .blend per the blueprint (or verify the GLB
  has the gun if a GLB exists and the source was lost).
- Plant the markers per Tier 1.
- **For sight-raise weapons (LAW, RPG-2, RPG-7):** the muzzle marker IS the analytic
  anchor. The rear and front "sight" markers are vestigial (the iron sights exist but
  the player does not aim through them).
- Create the viewmodel .tscn (currently missing for all three) with the GLB
  instance and identity transform on the Model child.
- Re-export per `tools/export_viewmodel.py`.

### Tier 3 — Build scope sub-assembly + markers (the M70-class work)
**For:** M70.
**Required actions:**
- Author the 8× Unertl scope as a sub-assembly in the source .blend. The tube is
  610 mm long, Ø19 mm, suspended above the barrel by two mount blocks at X 455 and
  X 640. The eyepiece is at X 800–860. The objective bell is at X 250–340.
- Plant THREE markers, with the rear-sight marker at the **eyepiece** (X ~860, Y +48,
  Z 0) and the front-sight marker at the **reticle plane** (X ~250, Y +48, Z 0). The
  muzzle marker is at the bore exit as usual.
- The `viewmodel_scale = 1.1` on `m70.tres:33` must be respected — the scope
  tube is large in the viewmodel.
- The reticle is a separate design call (cross / post / dot) — defer to the
  Arbiter or the owner.
- Re-export per `tools/export_viewmodel.py`.

### Naming contract (binding for all 15 guns)
- Empty names: `sight_rear_<gun>`, `sight_front_<gun>`, `muzzle_<gun>`. The `<gun>`
  token is the object name in the .blend (e.g. `M14_Rifle` → `sight_rear_m14_rifle`?
  or `sight_rear_M14_Rifle`?). **The `tools/export_viewmodel.py:57` script uses
  `muzzle_{GUN}` (uppercase) so the naming is `muzzle_M14_Rifle`** — the empty
  name is UPPERCASE matching the gun object. **Verify this matches the lowercased
  ID in the .tres (`m14`, `ak47`) and the workflow's
  `sight_rear_<gun>` placeholders — the case mismatch is a bug waiting to ship.**
  Recommendation: **lowercase the empty names** (`muzzle_m14_rifle`) and amend the
  export script accordingly. **The Arbiter must rule on this naming before any
  work begins** — if the script reads `muzzle_M14_Rifle` but the empty is
  `muzzle_m14_rifle`, the script's `muz = bpy.data.objects.get(f'muzzle_{GUN}')`
  returns None and prints "WARNING: no muzzle_M14_Rifle empty found" without
  failing the export. The exported GLB will have no MuzzlePoint and the
  viewmodel will silently fail to spawn muzzle flashes. **This is a critical
  contract — name the empties the script expects, or fix the script.**
- `matrix_parent_inverse` MUST be identity on each empty (workflow §4). The
  export script does not check this; a non-identity `matrix_parent_inverse`
  will bake the wrong world transform into the GLB.
- Empties MUST be parented to the gun object, not the world, not the rig.
  The export script selects the gun + the muzzle; if the muzzle is parented
  to a different object, the GLB will not contain it.

### Verification contract (binding for all 15 guns)
- Per `WEAPON_ADS_WORKFLOW.md:69-81` (the M16 addendum): the stager MUST verify
  by fresh-depsgraph raycast, NOT by render. A render hides blockers; a raycast
  does not.
- Per the briefing §1: **"Nothing ahead of the aperture may rise above the sight
  line."** The stager must verify the M16A1 carry handle front leg, the M60
  feed cover hump, the M70 scope mount blocks, the Mosin bolt handle, the
  AK-47 gas tube, and the PPSh-41 vent slots do not intersect the sight line.
- Per the briefing: **majority of rays must run clear / hit the post.** 7-9
  rays from a realistic eye position, ±2-3 mm pupil offsets, all should hit
  the post. If 2 or more miss, the sight line is blocked and the geometry
  must be remediated.

---

## 6. WHAT IS SACRIFICED (per the War Room law)

By the law, the tradeoffs must be named. I name four:

1. **The real Mosin aperture is too small to read at 40° ADS FOV.** The Mosin
   at 622 mm sight radius and ~Ø2 mm real aperture gives a 1.7-pixel front
   post at 1080p — illegible. **The PSX fix is to exaggerate the aperture
   to Ø4–5 mm in the game model** (workflow §3's "thin ring, big hole"
   license). The cost: a player who knows the Mosin will see the aperture
   is bigger than it should be, by 2.5×. **The cost is honesty, paid in
   service of legibility — the same tradeoff every PSX-era game made
   (MGS3, CoD 4, Far Cry 2).** The honest disclosure: the Mosin in
   RECONgame is a *PSX-stylized* Mosin, not a museum-replica Mosin. The
   workflow did not document this; the disclosure is the sacrifice.

2. **The "M14 has markers" claim is false** (per §0). The workflow doc
   and the briefing both state it as fact. **A workflow doc that
   overstates completion is a drift generator** — the next agent will
   skip the marker work on the M14 because the doc says it's done, and
   the analytic tool will fail. **The cost: a week of confusion when
   the analytic tool reads the M14 and finds no empties.** The honest
   fix: amend the workflow doc and the briefing to say "M14 has the
   hand-tuned .tres; the marker triplet is NOT yet built."

3. **The Soviet weapons source .blend does not exist as a separate
   file** (per §0). The Soviet FP viewmodels exist as GLBs but I cannot
   find a source .blend for them. **Either the source was lost in a
   prior restructuring, or the Soviet weapons are sitting inside one of
   the US blends (a smell), or the stager must author them from
   scratch.** The cost: a full re-authoring pass for 5 Soviet guns
   (AK-47, Mosin, PPSh-41, RPD, RPG-2) and possibly a recovery effort
   for the GLBs that already exist. **The Arbiter must rule on the
   Soviet blend question** before any Soviet work is scheduled.

4. **MuzzlePoint / muzzle_<gun> naming case mismatch** (per §5). The
   export script reads `f'muzzle_{GUN}'` (UPPERCASE) but the workflow
   doc writes `muzzle_<gun>` (lowercase). **If the empty is named
   `muzzle_m14` and the script reads `muzzle_M14_Rifle`, the script
   silently fails and the GLB ships without MuzzlePoint.** The cost:
   every shipped weapon will need to be re-verified that its GLB
   contains a MuzzlePoint. **The honest fix: pick a case (I recommend
   lowercase matching the .tres `id` field) and amend the export
   script to match.** This is one line of code but it must be done
   before any export is run, or every gun re-exports silently broken.

These four are the tradeoffs I name. The Arbiter binds them too.

---

## 7. WHAT I CANNOT ANSWER (boundary of my domain)

- I cannot measure the sight-line geometry in the .blend — I read the
  blueprints and the .tres values; I did not open the binaries.
- I cannot verify the M14 sight rebuild in the .blend (workflow says it's
  done, I have no evidence either way).
- I cannot measure the front-post pixel size at runtime — that is the
  animator / viewmodel-programmer's measurement to take, not mine.
- I cannot decide whether the M60/RPD/LAW ADS path is enabled at all —
  that is a gameplay-rule call for the Arbiter.
- I cannot author the analytic `ads_position` / `ads_rotation` values
  for any gun — that is the viewmodel-programmer's job, derived from
  the markers I have specified.
- I cannot author the sight-line collisions — the stager verifies with
  raycast, the animator ensures the firing anim does not break the
  sight line, the viewmodel-programmer reads the markers and writes
  the .tres.
- I cannot decide the M70 reticle design (cross / post / dot) — the
  owner should pick; my recommendation is **post** (most honest to the
  PSX era and the workflow's "real aperture" license).

---

## 8. ONE-LINE VERDICT

**Every gun in the roster has no markers, no analytic ADS, and a placeholder
or hand-tuned .tres; the workflow's "M14 is the reference" is false; the
Soviet weapons source .blend does not exist; the export script's muzzle
naming case is a silent-failure bug; the Mosin needs a PSX aperture
exaggeration the workflow does not cover; the M60/RPD/LAW ADS-path rule
is a gameplay call for the Arbiter; and the first 3-4 guns to ship are
M14, M16A1, AK-47, M60 — in that order.**
