# Communist-Bloc Weapon Shape Reference — Vietnam War (VC / NVA)

**Purpose:** Visual shape reference for low-poly PS1-style modeling in Blender.
Focus: silhouette, proportions, readability at 96px sprite resolution, material/color hex breakdown, common modeling mistakes.

**Scale anchor:** VC/NVA fighter = **1.65 m** tall. All "vs fighter" ratios use this.
Rule of thumb: shoulder height ≈ 1.36 m, hip ≈ 0.85 m, arm span ≈ 1.65 m.

---

## Shared Material Palette (use these across all weapons)

| Material | Hex (base) | Hex (shadow) | Hex (highlight) | Notes |
|---|---|---|---|---|
| Blued steel (Soviet/Chinese) | `#2B2B30` | `#1A1A1E` | `#4A4E58` | Near-black with cold blue-gray sheen. NOT pure black — pure black kills silhouette detail at 96px. |
| Worn/parkerized metal | `#3F4245` | `#2A2C2E` | `#5C6066` | Field-worn guns; edges rub to bare steel `#8A8D91`. |
| Russian laminate wood (AK, RPD) | `#9C5A2E` | `#6B3A1C` | `#C47B42` | Orange-amber shellac over birch laminate. Distinctly ORANGE, not brown. |
| Chinese wood (Type 56, SKS) | `#6B4226` | `#472A17` | `#8A5C38` | Darker, redder-brown catalpa/beech. Chinese guns read "chocolate," Russian read "orange." |
| Mosin/PPSh shellac wood | `#7A452A` | `#523018` | `#9E6238` | Reddish-brown, often near-mahogany from decades of oil. |
| Bakelite (mags, grips) | `#A0622C` | `#6E4220` | `#C4813E` | Rusty orange plastic, slightly glossier than wood. On AKM-era mags only. |
| RPG olive paint | `#4A5540` | `#333B2C` | `#657257` | Soviet olive-drab on RPG tubes and warheads. |
| Warhead dark green/black | `#2E332B` | — | — | Some PG-7 warheads; also seen olive. |
| Canvas sling khaki | `#8A7A55` | `#5F5439` | `#A89468` | Web slings; leather slings use `#5C3A24`. |

**PS1 texture tip:** paint wood grain as 2–3 long horizontal streaks of the shadow hex on the base hex. Do not use noise — it shimmers at sprite scale.

---

## 1. AK-47 / Type 56 Assault Rifle

### Length & scale
- Overall: **870 mm** (Type 56: 874 mm) → **53% of fighter height**. Muzzle reaches roughly from hip to chin when stood on its buttplate.
- Barrel (visible portion past handguard): ~250 mm.
- Held at ready, it spans from the fighter's leading hand to just past the rear shoulder.

### Silhouette breakdown (front to back)
1. **Muzzle / front sight post** — tall post sitting ~40 mm above the barrel line, with protective "ears." AK-47: partially open ears (U-shaped from front). **Type 56: fully enclosed hooded ring** — reads as a small O on the sprite. This is the #1 Type 56 identifier.
2. **Cleaning rod** — thin rod running UNDER the barrel from front sight back to the handguard. At 96px: a single 1px light-gray line under the barrel. Cheap detail, big authenticity win.
3. **Gas block + gas tube** — the AK's signature: a **second tube ABOVE the barrel**, running from the gas block (about 2/3 down the barrel) back into the receiver. Side profile shows a distinct wedge/step where gas block rises off the barrel at ~45°.
4. **Handguard** — wooden, two parts: lower handguard (with palm-swell bulge at front — the sides flare outward slightly) and upper wooden cover over the gas tube. Wood-metal-wood sandwich when viewed from the side.
5. **Receiver** — flat-sided rectangular box, ~200 mm long, with the **rear sight block** rising at its front (a small ramped wedge on top). Prominent **charging handle** knob on the right side. Long **safety lever** — a big flat blade along the right receiver side (1px line at sprite scale, skippable).
6. **Magazine** — see below. Hangs just behind the balance point.
7. **Pistol grip** — short, steeply raked wooden grip (Bakelite on later AKM; Vietnam-era Type 56 = wood).
8. **Buttstock** — wooden, with a distinct **downward droop**: the comb line drops ~15° from the receiver top line to the buttplate. Buttplate is metal `#3F4245`. Stock is noticeably slimmer top-to-bottom than a hunting rifle's.

### The banana magazine (get this right)
- 30-round, ~240 mm along its outer curve.
- Curve: arc of roughly **a circle of ~300 mm radius**; total sweep ≈ **60–70°** from feed lips to floorplate. Practical Blender recipe: model straight box 240 × 70 (front-to-back) × 25 mm, add Simple Deform (Bend) 65°, pivot near the feed end.
- The mag exits the receiver angled slightly forward, then curves BACK — floorplate ends up almost directly below the pistol grip, tip pointing forward-down.
- Ribbed steel mags (Vietnam era) = metal hex, with 2 horizontal rib lines painted on. Bakelite orange mags exist but are post-1965 Soviet; VC mostly carried steel.

### Recognizability at 96px
The three-point read: **(1) banana mag, (2) gas tube hump above barrel, (3) drooped wooden stock.** If those three read, it's an AK. The tall front sight post at the muzzle end is the fourth.

### Type 56 vs AK-47 differences
- **Fully hooded front sight** (enclosed ring, not open ears).
- **Under-folding spike bayonet**: a cruciform spike ~330 mm long, hinged just behind the front sight, folding back UNDER the barrel/handguard. Folded: adds a thin second line under the barrel (like a thicker cleaning rod). Extended: dramatic silhouette — thin spike projecting past the muzzle, great for a "charging VC" sprite.
- Slightly darker wood (Chinese hex row).
- Everything else is silhouette-identical at sprite scale.

### Common proportion mistakes
- **Mag too curved** (video-game "super banana," 90°+ sweep) or curved from the wrong point — the curve starts ~1/3 down, not at the receiver.
- **Barrel too long** — AK is a stubby gun; the exposed barrel past the handguard is short. If it looks graceful, it's wrong. AKs look front-heavy and blunt.
- Stock in line with the barrel (that's an AR-15 trait) — the AK stock **droops**.
- Forgetting the gas tube — one tube instead of two above/below reads as a generic rifle.
- Making the receiver deep/chunky vertically — the AK receiver is a shallow flat box; the depth comes from mag + grip hanging below it.

---

## 2. RPG-2 (B-40) and RPG-7 (B-41)

### Who carried what
- **RPG-2 / "B-40"**: the classic VC weapon, dominant early–mid war (1964–1968, Tet). If your fighter is black-pajama VC, B-40 is period-perfect.
- **RPG-7 / "B-41"**: arrives ~1967, common with NVA regulars and late-war VC. More capable, more "modern" silhouette.

### RPG-2 (B-40)
- Tube length: **~950 mm** (58% of fighter). With PG-2 grenade loaded: **~1200 mm**, warhead protruding from the muzzle.
- Tube: plain straight steel pipe, **40 mm bore** (~45 mm outer) — pool-cue thin.
- **Wooden heat-guard**: the middle-rear ~350 mm of the tube is wrapped in wood (two clamped half-shells) — at sprite scale, paint the rear half of the tube wood-hex, front half metal/olive.
- **Single pistol grip** with trigger, under the tube at the wood section. One grip only — key RPG-2 vs RPG-7 tell.
- Simple flip-up iron sights (tiny nubs, skippable at 96px).
- **PG-2 warhead**: 82 mm diameter — nearly **2× the tube's width**. Shape: pointed cone nose → short cylindrical body → tapers back into the 40 mm tail boom that sits inside the tube. Reads as an "arrowhead on a stick."
- Rear of tube: plain open pipe, no flare.

### RPG-7 (B-41)
- Tube length: **~950 mm**; with PG-7V loaded ≈ **1340 mm** total (81% of fighter — nearly as long as the man when loaded).
- Same 40 mm tube, but with three unmistakable additions:
  1. **Rear venturi bell** — the tube flares into a funnel/trumpet at the back end. THE RPG-7 identifier from the side.
  2. **Bulged mid-section** — the tube swells around the middle (where the grenade's booster sits); with the wooden heat guard over it, the middle of the weapon is visibly fatter than the ends.
  3. **Two grips**: forward pistol grip with trigger + second rear grip behind it, both under the tube.
- **PG-7V warhead**: 85 mm diameter cone, longer and more elegant than PG-2's — long pointed ogive nose, cylindrical body, taper to boom. Often olive `#4A5540` with a black nose fuze tip.
- PGO-7 optical sight box on the left side (a small rectangle above/left of the grips) — nice extra polygon budget item; NVA often used irons only, so skippable.

### Recognizability at 96px
- Both: **thin pipe + oversized cone sticking out the front**. Warhead diameter ≈ 2× tube diameter — exaggerate to 2.2× at sprite scale so it reads.
- RPG-2 = straight pipe, one grip, wooden back half.
- RPG-7 = trumpet-flared rear + fat middle + two grips.

### Carry / firing
- **Carried:** slung diagonally across the back, tube roughly at 45°, warhead-end up past the shoulder (loaded, warhead peeks above the head silhouette — extremely readable). Sling attaches near muzzle and near rear.
- **Fired:** rested on the RIGHT shoulder, roughly level; gunner's head is left of the tube, front hand on forward grip. Half the tube hangs behind the shoulder (backblast end). Kneeling fire pose is the iconic one.

### Common mistakes
- Making the tube thick like a bazooka/LAW — RPG tubes are skinny (40 mm ≈ wrist-thin).
- Warhead too small — if the cone isn't obviously fatter than the tube, it reads as a musket.
- Putting the venturi bell on the RPG-2 (it has none).
- Centering the tube on the shoulder — the grip section sits at the shoulder, so ~60% of length is in front of the firer.

---

## 3. RPD Light Machine Gun

### Length & scale
- Overall: **1037 mm** (63% of fighter) — only ~17 cm longer than an AK, but reads much heavier because of the drum and bipod.
- Weight class: the gunner carries it two-handed at the hips or slung level across the front.

### Silhouette breakdown
1. **Muzzle** — plain barrel end, tall AK-style hooded front sight just behind it.
2. **Folding bipod** — attached near the muzzle; folded, the two legs lie back along the barrel's underside (paint as a slight thickening); deployed, an inverted V ~300 mm tall. For sprites, deployed bipod only for prone/support poses.
3. **Long barrel + gas tube** — like the AK, gas tube above the barrel, but the whole front end is longer and slimmer.
4. **Wooden handguard** — shorter proportionally than the AK's.
5. **Receiver** — deeper/taller box than an AK's, with a top cover.
6. **BELT DRUM** — the identifier: a **round sheet-metal can (~170 mm diameter, ~70 mm wide) clamped UNDER the receiver's center**. Holds a 100-rd belt. It is a smooth flat-faced cylinder — NOT a magazine; no feed tower, it hangs snug against the receiver bottom. Metal hex, often olive-painted.
7. **Pistol grip** — wooden, AK-like.
8. **Buttstock** — wooden, thicker and more clubbed than the AK's, with a slight rise then droop; buttplate sometimes has a hinged shoulder flap (skip at low poly).

### Recognizability at 96px
**Round can under the middle of the gun.** That single circle centered under the receiver, plus a longer barrel than the AK and no protruding magazine, is the whole read. Add bipod line under the muzzle for support-gunner sprites.

### Proportions vs AK
- ~1.2× AK length; barrel section (front of receiver to muzzle) is proportionally much longer — the RPD looks "stretched forward."
- No banana mag anywhere. If you model a curved mag on it, you've built an RPK.

### Common mistakes
- Drum too big (DP-28 pan syndrome) — the RPD drum is compact, smaller in diameter than the stock is long, and hangs UNDER, never on top.
- Placing the drum forward like a Bren mag — it's centered under the receiver, roughly below the rear sight.
- Reusing the AK barrel length — RPD's front half must be visibly longer and thinner.

---

## 4. Mosin-Nagant (M1891/30 rifle, M44 carbine)

### Length & scale
- **M1891/30**: **1232 mm** — **75% of fighter height**. With bayonet fixed: 1738 mm — TALLER than the man. Standing, the muzzle reaches his eyes.
- **M44 carbine**: **1016 mm** (62%), a full 20 cm shorter, with permanently attached side-folding bayonet.

### Silhouette breakdown
1. **Muzzle + front sight** — tall thin post inside a hooded ring (91/30) — tiny circle at the very tip of a very long line.
2. **Full-length wooden stock** — wood runs from the buttplate almost to the muzzle; only ~80 mm of bare barrel shows. The gun reads as **one long wooden line with a thin metal tip**. Upper handguard covers the barrel top too, so the front 2/3 is wood-over-wood.
3. **Barrel bands** — two thin metal rings clamping the handguard, spaced along the front half. At 96px: two 1px vertical metal lines breaking the wood — cheap and very "old rifle."
4. **Rear sight** — a small ramp on the barrel just ahead of the action.
5. **Bolt handle** — short, STRAIGHT, sticking out horizontally on the right side at the receiver — a little T-peg. In side view it's a small knob-ended stub above the trigger.
6. **Magazine** — single-stack protruding box, a shallow wedge under the stock ahead of the trigger guard — a slight belly bump, NOT a detachable mag. Metal hex.
7. **Trigger guard + straight wrist stock** — the buttstock is nearly straight, with a gentle drop, ending in a flat steel buttplate.
8. **Sling "swivels"** — Mosins use **slots cut through the stock** (one in the butt, one in the forend) with leather "dog collar" loops — at sprite scale, two tiny dark rectangles in the wood.

### M44 specifics
- **Side-folding cruciform spike bayonet**, hinged on the RIGHT side of the muzzle. Folded: lies back along the right side of the stock (from the front-right view, a thin metal line along the forend). Extended: spike projects ~310 mm past the muzzle. Always attached — a bayonet-forward M44 is the classic militia/VC image.
- Slightly stubbier proportions; more visible muzzle flash in fiction, shorter bare-barrel tip.

### Recognizability at 96px
**Sheer length + all-wood body.** It's the longest one-piece wooden silhouette in the game; the bolt-handle stub and the two barrel-band ticks confirm "bolt rifle." Distinguish from SKS by: no magazine hump forward + greater length + no bayonet lug bulk (91/30).

### Common mistakes
- Too much exposed barrel — Mosins are stocked nearly to the muzzle. If it looks like a sniper rifle with a free-floating barrel, wrong.
- Adding a pistol grip curve — the Mosin wrist is straight (English-style), no swell.
- Bolt handle too long/bent (that's the sniper variant) — infantry Mosins have a short straight handle.
- Making it as short as an AK — the 91/30 must tower over every other rifle in the sprite lineup. Its length IS the design.

---

## 5. PPSh-41 Submachine Gun

### Length & scale
- Overall: **843 mm** (51% of fighter) — carbine-sized, but massively front-heavy in appearance.
- Drum-loaded weight makes fighters carry it slung low across the chest or one-handed by the shroud.

### Silhouette breakdown
1. **Barrel shroud** — the signature: a metal jacket around the barrel, rectangular-ish in profile, with the front end cut at a **backward slant** (the slanted face is the muzzle brake — barrel muzzle visible inside the slant). Shroud has rows of **long oval cooling slots**.
2. **Front sight** — hooded post on top of the shroud near the muzzle.
3. **Receiver** — rounded-top box continuing the shroud's line backward; rear sight flip notch on top; bolt handle knob on the right.
4. **71-round DRUM magazine** — ~170 mm diameter flat tin drum, inserted under the receiver at the balance point, slightly forward of the trigger. Flat faces, shallow depth (~55 mm). At sprite scale: a full circle under the gun's midpoint, diameter roughly equal to the receiver depth × 2.5.
5. **Wooden stock** — full rifle-style wooden buttstock and wrist, NO pistol grip. The wood starts at the trigger area and sweeps back with a gentle classic rifle profile. Wood = Mosin shellac hex (many PPSh stocks were made on Mosin tooling).

### Faking the perforations at low poly — **texture, not geometry**
- Geometry slots would cost dozens of polys and alias into shimmer at 96px. Instead:
  - Model the shroud as a simple box/cylinder with the slanted front face (that slant SHOULD be geometry — it defines the muzzle silhouette).
  - Texture: 3 long horizontal ovals per side in near-black `#141416` on the metal hex, with a 1px highlight `#5C6066` on their top edge. At sprite distance this reads perfectly as vents.
  - If you have alpha budget, one alpha-cut slot on the top edge sells it in silhouette, but it's optional.

### Recognizability at 96px
**Drum circle + slotted shroud + wooden rifle stock.** No other weapon combines a full wooden buttstock with a drum. The slanted muzzle face is the tertiary read.

### Common mistakes
- Pistol grip added — the PPSh has none; hand grips the stock wrist.
- Drum too far forward (Thompson-style placement) — it sits at the trigger guard, not mid-barrel.
- Shroud too thin — the shroud is fatter than the receiver is deep; the gun looks like a blunt log with a drum.
- Slots as circles — they're long ovals/slots, 3 per side visible.

---

## 6. Bonus Weapons

### SKS / Type 56 Carbine
- Overall: **1021 mm** (62% of fighter) — between AK and Mosin. Think "3/4-scale Mosin with a bayonet."
- Silhouette: wooden stock to ~3/4 length, exposed barrel + gas tube above it at the front, hooded front sight, **fixed 10-round magazine** — a shallow angular wedge belly under the receiver (NOT detachable, NOT banana). Straightish stock with slight drop, sling slot in the butt.
- **Folding bayonet under the barrel**: Soviet/early = blade; **Chinese Type 56 carbine = cruciform SPIKE**, folding back into a channel under the forend. Folded: a ridge line under the barrel. Extended: spike past the muzzle — the "human wave" NVA image.
- Colors: Chinese wood hex `#6B4226`, blued steel.
- 96px read: mid-length wooden rifle + small mag bump + gas tube step at the front. Distinguish from AK by NO banana mag; from Mosin by shorter length + mag bump + exposed front barrel.
- Mistake: modeling a detachable AK mag on it — the SKS belly is a fixed 45° wedge only ~60 mm deep.

### K-50M (Vietnamese PPSh conversion)
- North Vietnamese rework of the Chinese Type 50 (PPSh clone): **571 mm stock-collapsed / 756 mm extended** — the shortest weapon in this set.
- Changes vs PPSh-41: wooden buttstock REMOVED → **French MAT-49-style sliding wire stock** (two thin rods + flat butt, telescopes alongside the receiver); shroud **shortened** with muzzle protruding bare; added **wooden pistol grip**; AK-style front sight moved onto the barrel; usually fed by the **35-rd curved stick mag**, not the drum.
- 96px read: stubby slotted shroud + bare muzzle sticking out + curved stick mag + wire stock = "chopped PPSh." Perfect VC tunnel/urban weapon, visually distinct from the full PPSh.
- Colors: metal-dominant; only the pistol grip is wood.
- Mistake: giving it the drum or full wooden stock — that makes it a PPSh again.

---

## 7. Slings, Straps, and Carry Poses

### Sling anatomy (all weapons)
- Canvas web sling `#8A7A55` or leather `#5C3A24`, ~30 mm wide → at 96px a 1px strap line.
- Attachment points: front swivel near front barrel band / gas block; rear on the left side of the stock or butt slot. Slings hang on the LEFT side of the weapon by convention.

### Standard carries (sprite-friendly)
| Pose | Description | Best for |
|---|---|---|
| **Chest slung (AK, K-50M)** | Sling around neck + one shoulder, weapon horizontal across the belly/chest, muzzle pointing down-left, both hands can rest on it or hang free. The iconic VC patrol look. | Idle/walk sprites |
| **Shoulder slung, muzzle up** | Sling over one shoulder, weapon vertical on the back-side of the shoulder, muzzle up past the head (Mosin/SKS — long rifles read great this way). | March/column sprites |
| **Shoulder slung, muzzle down ("African carry")** | Muzzle-down on the shoulder, hand on the sling — common for jungle rain. | Fatigue/relaxed poses |
| **RPG back-slung** | Diagonal across the back at ~45°, warhead cone up past the shoulder line. Gunner also carries 2–3 spare grenades in a canvas 3-cell backpack (rectangular pack with cone tips poking up — great extra silhouette). | RPG gunner walk |
| **RPD patrol carry** | Slung level at the right hip, both hands on grip/handguard, muzzle forward-down. | MG gunner |
| **Firing, shouldered** | Stock in shoulder pocket, support hand under handguard (AK/SKS/PPSh) or on drum-front (RPD). Elbows in — VC fired compact. | Attack sprites |
| **RPG kneeling fire** | Right knee down, tube level on right shoulder, ~60% of tube ahead of the firer, head tucked left of tube. | RPG attack |
| **Hip fire (PPSh/K-50M)** | SMG tucked at right hip, muzzle forward, off-hand on shroud/mag. | Charge sprites |

### Sprite lineup length check (silhouette sanity)
At 1.65 m fighter, relative weapon lengths standing muzzle-up beside him:

```
K-50M (571)  < PPSh (843) < AK/Type 56 (870) < Mosin M44 (1016) ≈ SKS (1021)
< RPD (1037) < RPG-7 loaded (1340) < Mosin 91/30 (1232; 1738 w/ bayonet)
```

If your models don't preserve this ordering side by side, fix lengths before detailing.
