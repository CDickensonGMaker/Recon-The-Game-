# US Grunt v2 Build Plan — 2000-2006 PC-era soldier (RTCW / MoHAA / CoD1 / Vietcong style)

File: `us_grunt_v2.blend` · Base: PSX_Human_Base (203 verts) on PSXRig (41-bone mixamorig, 1.80m)
Anim library: `anim_library.blend` (69 actions: 49 Pro Rifle Pack + 17 salvaged + 3 cockpit)

## The era technique (research summary)
- RTCW/MoHAA/CoD1 soldiers: **one welded skinned mesh, 800–2,000 tris**, skeletal anim.
- **The 256/512px hand-painted texture does 90% of the work**: every strap, pocket, fold,
  button, sweat stain, the face, and the SHADING (painted AO under webbing/collar/folds).
- **Geometry only where the silhouette changes**: helmet, ruck, canteens, pouches, towel.
  Belts/suspenders/chest pockets/blousing = TEXTURE, never floating boxes.
- Style coherence beats mesh smoothness — this is why the old blocky units "read" right.

## Reference anchors (from reference_us_soldier.md — the photo study)
- Body: LEAN (19-22yo, half-bodyweight load). Top-heavy silhouette comes from GEAR.
- Palette patchwork — nothing matches: jacket faded `#767863`(worn `#8A8C77`), trousers
  `#5A5F44`, webbing OD7 `#4A4E38`, boots black `#22211E` + OD canvas shaft `#4F5540`,
  Mitchell cover `#7D8A5E`, towel bleached `#9A9C85`, laterite dust `#8A5A3C`.
- Signatures: slanted chest pockets · rolled sleeves (bare forearms) · helmet band with
  CIGARETTE PACK · OD towel around neck · bandolier flat across chest · canteens at REAR
  hips · ammo pouches FRONT of belt w/ grenade lumps · low-slung ruck w/ exposed frame
  above · bloused cuffs over two-tone jungle boots.

## Gear placement (world coords, T-pose; body: head top 1.80, hips ±0.16, waist z≈1.02)
| piece | target | bone |
|---|---|---|
| m1 helmet set (dome/rim/band/cigpack) | scale 0.72, rim z≈1.725, dome caps crown | Head |
| towel set (back + 2 tails) | around neck z≈1.47, tails hang chest | Spine2 |
| ruck set (bag+rails+crossbar) | bag LOW back: center (0,+0.17,1.13), frame tops ~1.35 | Spine2 |
| belt | z 1.005 | Hips |
| pouch_l/r | front-outward (±0.075,-0.135,0.99) | Hips |
| canteen_l/r | REAR hips (±0.115,+0.115,0.985) | Hips |
| etool | flat on ruck face OR right rear hip | Spine2/Hips |
| bandolier+mags | chest diagonal, y≈-0.105, z 1.24 | Spine2 |

## Texture page (512², nearest, bake in BODY SPACE via loop-tri rasterization)
Painted: suspender H-straps + shoulder pads + field-dressing box (left strap) · slanted
chest pockets w/ flap AO + buttons · lower bellows pockets · thigh cargo pockets ·
bloused-cuff shading ring · boot leather/canvas split + laces · rolled-sleeve cuff line ·
collar shadow · sweat V (back) · name tapes (2 dark strips) · face (brows/eyes/nose
shadow/mouth, buzz sides) · fabric value noise ±4% · laterite dust below z 0.35.

## ENGINE EXPORT SPEC (from RECONgame - ModelActor.TARGET_HEIGHT_M)
- **1.7132 m** = top of helmet, feet at world origin, 1 BU = 1 m, facing **-Z**
- Head centered ~1.65, waistline ~0.9 (locational damage hitzones assume this)
- Mixamo rig + named anims + sockets: **MuzzlePoint / HandR / HandL / Head / Chest**
- Engine auto-rescales near-miss sizes, but exact authoring = zero rescale + hitzones align
- OUR base is ~1.86 m to helmet top -> export step scales rig+meshes x~0.921 AND
  multiplies all Hips location F-curves by the same factor (bone-local translation
  doesn't auto-scale - same fix as the anim-library port, in reverse)
- Past models came in too small - always verify final helmet-top z == 1.7132 post-export

## Roster pipeline after grunt approved
1 body + texture variants (skin tones, sweat, faces) + gear swaps = squad variety:
grunt / grunt_black / medic (no bandolier, aid bags) / RTO (PRC-25 + handset) /
boonie variant / flak-vest Marine set later. VC/NVA: same body, new textures + gear
(pith helmet exists in vc5 parts). All bind to PSXRig -> 69-action library. Gibs: body
regions map to bones; gear bone-parented so limbs separate clean (bead RECONgame-1xqs).
