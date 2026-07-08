# Numeric Blueprint: US Support Weapons — M60 & M79
*Dimensional research for blueprint-accurate low-poly Blender modeling. RECONgame / Hell of Duty Vietnam.*

**Coordinate convention (both weapons):**
- **X** = distance from muzzle face along the bore axis, in mm. Muzzle = 0, increases toward the butt.
- **Y** = vertical offset from the bore line (center of the bore), in mm. Positive = above bore, negative = below.
- Dimensions given as **L × H × W** (length along bore × height × width) unless noted.
- Model at 1:1 real scale (1 Blender unit = 1 m), so M60 = 1.105 units long, M79 = 0.731 units.

Sources: TM 9-1005-224 / FM 23-67 spec sheets (M60), FM 23-31 (M79), Wikipedia, globalsecurity.org, Small Arms Survey M79 sheet, militaryfactory.com, plus photo-derived estimates. Published figures are marked; everything else is proportionally derived from photos against the known totals — good enough for low-poly, do not cite for gunsmithing.

---

# 1. M60 MACHINE GUN ("The Pig")

**Published master dims:** overall length **1105 mm**, barrel assembly **560 mm**, weight 10.5 kg, cartridge 7.62×51 NATO. Barrel proper spans X 0–560; the barrel socket/trunnion area 560–620 is inside the receiver front.

**Height envelope:** bore line sits ~+0; total silhouette from rear-sight-raised top (+130) to pistol grip bottom (−170); deployed bipod feet reach −360.

## 1.1 Parts table

| # | Part | L × H × W (mm) | X from muzzle (mm) | Y offset from bore (mm) | Shape / modeling notes |
|---|------|----------------|--------------------|--------------------------|------------------------|
| 1 | Flash suppressor | 140 × Ø30→Ø22 | 0 – 140 | 0 (on bore) | Long slotted taper, WIDE at rear (Ø30) narrowing to Ø22 at muzzle. 6-sided cone frustum. Don't model slots — paint 3 long dark lines. |
| 2 | Barrel (exposed) | 280 × Ø26 | 140 – 420 | 0 | Plain cylinder, Ø26 front thickening to Ø30 at rear. Rear 140 mm hidden inside fore-end/receiver socket (560–620). |
| 3 | Front sight | base 25 × 38 tall × 15 | 150 – 175 | +13 to +50 (blade top ≈ +50 above bore) | Blade on a low block clamped to barrel top. Fixed on Vietnam-era guns (folding only on later E3) — model as a fixed triangular blade. |
| 4 | Carrying handle | 130 × 90 × 25 | 470 – 600 (hinge at 480) | folded: lies right side ≈ 0; raised: loop top +95 | Folding wire/stamped loop hinged to the BARREL just ahead of the fore-end. In idle pose flop it to the right side — that's the classic Vietnam look. |
| 5 | Gas cylinder tube | 260 × Ø33 | 215 – 475 | center −36 (runs under barrel, ~5 mm gap) | Parallel cylinder under the barrel; front end has a slightly fatter collar (Ø38 × 25 long) at X 215. Second-strongest silhouette read after the belt. |
| 6 | Bipod (FOLDED) | legs 350 × 22 × 8 each | hinge at X 230; legs run rearward 230 – 580 | −40 to −60 (hugging gas cylinder sides) | Two stamped-channel legs clamped back along the gas cylinder. Reads as a lumpy sleeve around the front third. |
| 6b | Bipod (DEPLOYED) | same legs + feet 60 × 15 × 40 | hinge X 230; feet at X ≈ 300 (raked slightly rearward) | feet at −360 | Legs swing down, splayed ~22° each side (feet ~260 mm apart). Bore sits ~360 mm above ground when deployed. |
| 7 | Fore-end / lower shroud | 200 × 70 × 62 | 420 – 620 | top +12, bottom −58 | Sheet-metal clamshell hanging under/around the barrel rear. Rounded-bottom box; paint 2 rows of small vent slots on the sides. Barrel top stays exposed above it. |
| 8 | Receiver box | 260 × 100 × 56 | 620 – 880 | top +45, bottom −55 | Stamped-steel slab box — the fat core of the gun (~10 × 5.6 cm section vs a rifle's ~4 cm). Keep faces flat and hard-edged. |
| 9 | Top cover (feed cover) | 190 × 22 hump × 60 | 590 – 780 | top of hump +65 | Raised rounded hump sitting on the receiver top line — front edge overlaps the barrel socket. THE stepped-top silhouette. Hinge pin at front (X 595). |
| 10 | Feed tray / belt slot | slot 90 × 18 | 630 – 720 | slot centerline +5 (bolt level) | Opening in the LEFT side under the top cover lip where the belt enters. Model as a shallow inset; the belt plugs into it. |
| 11 | Rear sight (leaf) | leaf 60 tall × 40 wide × 4 | hinged at 775 | folded: flat at +68; raised: top +130 | Folding ladder leaf at the rear of the top cover. Even folded, leave a 5 mm raised tab. Raised = classic deployed-gun pose. |
| 12 | Trigger guard | 65 × 40 × 12 | 795 – 860 | bottom −95 | Big oval loop under receiver, ahead of the grip. Trigger blade at X ≈ 825. |
| 13 | Pistol grip | 40 deep × 115 tall × 34 | top joins receiver at 855 – 895 | −55 down to −170 | Black polymer, raked back ~15°. Hangs from the receiver bottom just ahead of the stock. |
| 14 | Buttstock | 225 × 105 × 48 | 880 – 1105 | top +45, bottom −60 | INLINE plastic/fiberglass stock — top line continues the receiver top dead straight (no drop). Slight taper in width toward the butt. |
| 15 | Buttplate + shoulder flap | plate 12 × 130 × 50; flap 70 × 45 × 8 | plate 1093 – 1105; flap hinged at 1095 | plate spans +45/−60; flap folded lies on stock top +50, raised sticks up to +115 | Hinged shoulder-rest flap on TOP of the buttplate. Folded flat for carry; flip up for bipod prone. Paint the seam if you don't model it. |
| 16 | Ammo belt (7.62 linked) | see 1.2 | enters feed slot at X ≈ 675 | +5 at slot, drooping to −250+ | See belt spec below. Never skip this — it IS the machine-gun read. |

## 1.2 Belt spec (M13 links, 7.62×51)

| Property | Value |
|---|---|
| Cartridge overall length | 71 mm (this is the belt "ribbon" width) |
| Cartridge diameter | Ø12 |
| Round-to-round pitch | 16 mm per round center-to-center |
| Belt thickness | ~14 mm (cartridge + link) |
| Rounds to model | 8–12 visible |
| Orientation | Bullets point FORWARD (muzzle direction), belt ribbon is perpendicular to bore |
| Hang path | Exits LEFT feed slot at (X 675, Y +5), runs level ~40 mm out, then droops in a smooth catenary curve down and slightly forward; tip of belt around Y −250 to −350 |

Low-poly: one bent strip (2 × 10 quads) with a painted cartridge texture; add 3–4 actual small cylinders on the top run near the feed slot if budget allows.

## 1.3 M60 sanity checks (proportions)

- Flash suppressor + exposed barrel = 420 mm ≈ 38% of total length.
- Receiver box = 260 mm ≈ 24%; stock = 225 mm ≈ 20%.
- Front sight, feed hump, rear sight and stock top form ONE nearly straight top line — only the top cover hump and sights break it.
- Everything hangs BELOW the bore: gas cylinder, bipod, fore-end, grip. The top is clean, the bottom is cluttered. That asymmetry is the M60.

## 1.4 M60 materials / colors

| Part | Material | Hex |
|---|---|---|
| Barrel, suppressor, gas cylinder, bipod | Parkerized steel, near-black | `#242428` |
| Receiver, top cover | Stamped steel, hint of gray | `#2A2A2E` |
| Fore-end shroud | Painted steel, slightly warmer/browner from heat | `#2E2A26` |
| Pistol grip, buttstock | Black polymer/fiberglass (very slight brown-black) | `#1E1C1A` |
| Shoulder flap, buttplate | Black rubber/steel | `#1A1A1A` |
| Belt: cases | Brass | `#8F7433` |
| Belt: bullet tips | Copper FMJ | `#7A4A2E` |
| Belt: M13 links | Gray steel | `#3A3A3A` |
| Wear accents (edges, top cover hinge, handle) | Worn silver metal | `#6E6E70` |

Tri budget: 150–250 (PS1) / 400–600 (PS2), belt included.

---

# 2. M79 GRENADE LAUNCHER ("Blooper" / "Thumper")

**Published master dims:** overall length **731 mm** (some sources 737), barrel **357 mm** (14"), bore 40 mm, weight 2.7 kg empty. **LOP (trigger → buttpad rear) = 355 mm**, which pins the trigger at X ≈ 376.

**Height envelope:** raised leaf sight top +155; toe of butt −95. Break-action single shot, hinge just ahead of the trigger guard.

## 2.1 Parts table

| # | Part | L × H × W (mm) | X from muzzle (mm) | Y offset from bore (mm) | Shape / modeling notes |
|---|------|----------------|--------------------|--------------------------|------------------------|
| 1 | Barrel | 357 × Ø45 | 0 – 357 | 0 (on bore) | Fat 40 mm-bore aluminum tube, outer Ø45. 6–8 sided cylinder. Make the muzzle opening BIG and dark (Ø40 inset disc) — the huge bore vs short length is the entire identity. |
| 2 | Front sight (blade) | 12 × 22 tall × 3 | 18 – 30 | +22 (barrel top) to +45 blade tip | Simple fixed blade on a small base at the muzzle end, protected fixed type. One thin box. |
| 3 | Rear leaf sight, FOLDED | 130 × 8 × 35 | hinge at 150, leaf lies rearward 150 – 280 | flat on barrel top, +23 to +32 | Ladder lies flat pointing REARWARD along the barrel. Even folded, model the raised base block (30 × 12 × 38 at X 150). |
| 3b | Rear leaf sight, RAISED | leaf 130 tall × 35 wide × 5 | standing at X 150 | +25 (base) to +155 (top) | Big rectangular ladder frame with sliding aperture bar. Graduated 75–375 m. Model as a picture-frame quad (hole optional); paint rungs + yellow numerals. |
| 4 | Fore-end (wood) | 207 × 45 × 55 | 150 – 357 | wraps barrel underside/sides: top edges ±0, bottom −48 | Walnut, U-channel hugging the bottom half of the barrel, ends flush at the hinge. One retaining screw boss mid-length (paint it). Front edge is squared with a slight step. |
| 5 | Break hinge | pin Ø10 × 45 wide | pin at X 360 | −28 (below bore, at barrel bottom edge) | Shotgun-style hinge where barrel meets receiver. Model the seam/step — in reload anim the barrel tips down around this pin. |
| 6 | Barrel latch | lever 40 × 10 × 15 | 365 – 405 | +32 (on receiver top tang) | Thumb latch on the receiver top behind the barrel; pushes sideways to break open. A small ridge box is enough. |
| 7 | Receiver / action block | 113 × 90 × 40 | 357 – 470 | top +35, bottom −55 | Compact rectangular block joining barrel to stock — visibly SLIMMER than the fat barrel (40 vs 45 wide, and hard-edged vs round). Holds firing mechanism. |
| 8 | Trigger guard | 80 × 35 × 12 | 355 – 435 | bottom of loop −88 | Generous oval loop (glove-sized). Trigger blade at X 376 (this sets LOP = 355 to the pad). |
| 9 | Stock (wood) | 233 × 130 × 42→48 | 470 – 703 | comb top +32 at wrist, scoops to +18 mid, back to +32 at heel; toe −95 | Walnut. **Straight comb, NOT shotgun drop** — top line runs nearly parallel to bore with a slight concave scoop dished into the comb mid-length (collector-verified profile). Underside sweeps down/back to a deep toe. Butt flares from 42 to 48 wide. |
| 10 | Buttpad (rubber) | 28 × 130 × 45 | 703 – 731 | +32 to −95 (matches butt profile) | Thick black rubber recoil pad, 25–30 mm — visibly chunky, slightly convex rear face. Give it its own darker material; the wood/rubber seam is a strong tell. |
| 11 | Sling swivel, front | loop Ø22 × 4 wire | 140 | −50 (under fore-end front edge) | Small wire loop on a stud/band under the barrel at the fore-end front. Paint at PS1 budget. |
| 12 | Sling swivel, rear | loop Ø22 × 4 wire | 640 | −80 (stock underside) | Wire loop on the stock belly ahead of the toe. |

## 2.2 M79 sanity checks (proportions)

- Barrel = 357/731 ≈ 49% of total length — front half is ALL fat tube.
- Receiver is only ~15% of length; stock + pad ≈ 36%.
- Barrel OD (45) ≈ 3–4× a rifle barrel; keep it exaggerated at low poly.
- Whole weapon reaches mid-thigh on a 1.8 m soldier; reads like a sawn-off shotgun with a drainpipe barrel.
- Folded leaf sight + its base is the only thing breaking the barrel's top line.

## 2.3 M79 materials / colors

| Part | Material | Hex |
|---|---|---|
| Barrel | Hard-anodized aluminum, black with faint green-gray sheen | `#2B2E2B` |
| Receiver, hinge, latch, trigger guard | Parkerized steel/alloy | `#26282A` |
| Fore-end + stock | Black walnut, oiled | `#5C4326` (highlight `#7A5A35`, shadow `#3E2D19`) |
| Buttpad | Black rubber | `#1C1C1C` |
| Leaf sight frame | Parkerized steel | `#26282A` with yellow numerals `#C9A94E` |
| Sling swivels | Worn steel | `#55555A` |
| Optional 40 mm round (reload) | Brass case + OD projectile | case `#8F7433`, nose `#4A5D3A`, gold band `#B08D3C` |

Tri budget: 50–100 (PS1) / 200–300 (PS2).

---

# 3. Quick side-view keylines (mm from muzzle)

```
M60  (bore = 0 line)
     0    140       230      420  480   590 620      775 880        1105
     |suppr|  barrel  |bipod   |fore-|hndl|cover hump|sight|  stock  |butt
     gas cylinder: 215 ——————— 475  (Y −36)
     grip: 855–895 down to −170 · belt exits LEFT at 675, droops to −300

M79  (bore = 0 line)
     0   30      150            357 360  470            703   731
     |fsight| barrel  |leaf@150| hinge|receiver| stock   |pad|
     fore-end: 150 ——— 357 (under barrel) · trigger at 376 (LOP 355)
```

*Numbers marked "published" are hard spec; the rest are photo-scaled estimates locked to the published totals. If a part looks off against your reference photo, trust the photo — but keep the totals (1105 / 560, 731 / 357 / 355) exact.*
