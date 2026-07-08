# Numeric Blueprints — Soviet/VC Support Weapons (RECONgame)

Low-poly modeling reference for Blender. All dimensions in **millimeters**.

**Coordinate convention (per weapon):**
- **X** = distance from muzzle tip, measured rearward along the bore axis. Muzzle tip = 0. Negative X = protrudes forward of muzzle.
- **Y** = vertical offset from bore centerline. Positive = up, negative = down. Value given is the part's reference point (stated per row).
- All widths are symmetric about the bore's vertical plane unless noted.
- Sources: Wikipedia (RPG-2, RPG-7, RPD), modernfirearms.net, bulletpicker/CAT-UXO (PG-2), weaponsystems.net. Positions marked **(est.)** are derived from scaled photo/diagram proportions against the verified overall lengths — accurate to roughly +/-15 mm, fine for low-poly work.

---

## 1. RPG-2 (B-40 / B-50)

**Verified totals:** launch tube 950 mm long, 40 mm bore; overall length loaded with PG-2 = ~1200 mm (grenade protrudes 250 mm past muzzle). Weight 2.83 kg empty / 4.67 kg loaded.

Layout summary: plain steel tube, wooden heat-guard over the middle-rear, one pistol grip under the middle, flip-up irons forward of the wood, PG-2 nose hanging out the front. Rear of tube is open (recoilless), very slight reinforcing ring at each end.

### RPG-2 parts table

| # | Part | L x W x H (mm) | X from muzzle (mm) | Y from bore (mm) | Shape notes | Material / color |
|---|------|----------------|--------------------|------------------|-------------|------------------|
| 1 | Launch tube | 950 long, OD 44 (bore 40) | 0 to 950 | 0 (centered) | Uniform cylinder, open both ends. 8-12 sided is enough | Blued steel, near-black `#2A2A2E`, slight sheen |
| 2 | Muzzle reinforcing ring | 20 long, OD 48 | 0 to 20 | 0 | Simple thicker collar at muzzle lip | Same steel |
| 3 | Breech reinforcing ring | 25 long, OD 48 | 925 to 950 | 0 | Matching collar at rear lip (est.) | Same steel |
| 4 | Front sight (flip-up post) | base 20 x 12; post 3 dia | base 60-80 | base sits on tube top at +22; post tip +75 when raised | Hinged post, folds forward flat on tube. Raised = vertical | Steel, black |
| 5 | Rear sight (flip-up leaf) | base 25 x 14; leaf 30 wide x 65 tall | base 395-420 (est., just fwd of wood) | base +22; leaf top +90 raised | Rectangular leaf with aperture notch, hinges up. Folds rearward flat | Steel, black |
| 6 | Wooden heat-guard | 360 long, OD 62 | 450 to 810 (est.) | 0 (wraps tube) | Two half-shells clamped around tube; gentle barrel-shaped swell at middle (OD 62 mid, 58 at ends) | Lacquered birch, mid-brown `#6B4A2B`; VN-era often darker `#54381F` |
| 7 | Heat-guard clamp bands (x2) | 12 wide, OD 66 | 452 and 796 | 0 | Thin steel strap rings at each end of the wood | Steel, black |
| 8 | Trigger housing | 100 x 22 x 35 | 480 to 580 | -22 to -55 (hangs under tube) | Flat stamped box under tube, forward of/merging into grip | Stamped steel, black |
| 9 | Pistol grip (single) | 110 long, 30 x 42 section | top of grip at 530 | top -35, bottom tip -140 | Raked back ~15 deg from vertical (bottom sits ~30 further rearward than top). Slight palm swell | Bakelite or wood, dark red-brown `#4A2C1A` |
| 10 | Trigger | 35 tall x 8 wide | 505 | -35 to -62 | Curved blade inside small guard loop (guard: 60 x 30 oval) | Steel, black |
| 11 | Hammer spur | 30 x 12 x 25 | 585-605 | -22 to -45 | External hammer at rear of trigger housing, thumb spur curls back/down. One small box + curl is enough | Steel, black |
| 12 | Sling swivels (x2) | 25 dia loops | front 120, rear 870 (est.) | -24 (under tube) | Simple flat D-loops brazed to tube bottom | Steel, black |

### PG-2 grenade (loaded state)

Warhead caliber 80-82 mm (sources vary; **use 82** for silhouette punch). Nose sits 250 mm ahead of muzzle.

| # | Part | Dims (mm) | X from muzzle (mm) | Y from bore | Shape notes | Material / color |
|---|------|-----------|--------------------|-------------|-------------|------------------|
| G1 | Fuze tip | 15 long, dia 12->20 | -250 to -235 | 0 | Small blunt nose cap | Steel, black or bare metal |
| G2 | Ogive (nose cone) | 145 long, dia 20 -> 82 | -235 to -90 | 0 | Smooth convex ogive swelling to max diameter. 3-4 loft rings | Sheet steel, olive drab `#4A5D3A`; VC B-40 often black |
| G3 | Warhead max-diameter band | 60 long, dia 82 | -90 to -30 | 0 | Short cylindrical section at full 82 dia | Olive drab; thin yellow stencil band optional |
| G4 | Boat-tail (taper to boom) | 50 long, dia 82 -> 40 | -30 to +20 | 0 | Straight cone down to tail tube; crosses the muzzle plane | Olive drab |
| G5 | Tail boom (inside tube) | ~230 long, dia 40 | +20 to +250 | 0 | Slides into bore — only model the ~20 mm visible at the joint; rest can be deleted | Steel, black |

**RPG-2 quick proportions:** grip at 56% of tube length from muzzle; wood covers 47%-85%; warhead protrusion = 26% of tube length; warhead max dia = 1.86x tube OD.

---

## 2. RPD Light Machine Gun

**Verified totals:** overall 1037 mm, barrel 520 mm, weight 7.4 kg, 100-rd non-disintegrating belt in a sheet-metal drum clipped under the receiver. Long-stroke gas piston under the barrel. **No carrying handle** on the standard RPD/Type 56 (do not add one — that's the RPD's distinctive clean top line).

Layout summary (muzzle to butt): bare barrel with front sight + folded bipod -> gas tube underneath -> wooden clamshell handguard -> boxy receiver with feed-cover hump and drum hanging below -> tangent rear sight -> pistol grip -> club-shaped wooden stock.

### RPD parts table

| # | Part | L x W x H (mm) | X from muzzle (mm) | Y from bore (mm) | Shape notes | Material / color |
|---|------|----------------|--------------------|------------------|-------------|------------------|
| 1 | Barrel (exposed) | 330 exposed, dia 15 at muzzle -> 20 at rear (est.) | 0 to 330 | 0 | Plain cylinder, tiny step at gas block. (Full barrel is 520 but the rear 190 is hidden in handguard/receiver) | Blued steel, near-black `#26262A` |
| 2 | Front sight assembly | 35 long x 22 wide x 50 tall | 20 to 55 | base wraps barrel; post tip +48 | Cylindrical post between two protective ears (ears = 2 angled plates or a C-hood). Drum-shaped base clamps barrel | Steel, black |
| 3 | Bipod hinge collar | 25 long, dia 26 | 35 to 60 (under front sight base) | -8 | Clamp collar under barrel, hinge lugs both sides | Steel, black |
| 4 | Bipod legs folded (x2) | each 300 long, 8 dia, feet 40 x 15 | 60 to 360 (folded rearward along barrel) | -15, splayed ~12 deg out each side | Two tapered rods with stamped skid feet; folded they hug the barrel/gas tube and the feet reach the handguard | Steel, black |
| 5 | Gas block | 35 x 22 x 25 | 130 to 165 | -12 (under barrel) | Small wedge block bridging barrel to gas tube | Steel, black |
| 6 | Gas tube / piston tube | 170 long, dia 13 | 165 to 335 (disappears into handguard) | -26 | Straight tube parallel under barrel | Steel, black |
| 7 | Handguard (clamshell) | 150 x 55 x 78 | 330 to 480 | +20 top, -58 bottom | Two wooden half-shells enclosing barrel + gas tube; oval cross-section, slight belly. Ends capped by steel band at front | Laminated wood, red-brown `#7A4B26`, satin |
| 8 | Receiver box | 310 x 38 x 85 | 480 to 790 | +30 top, -55 bottom | Rectangular box, slightly taller than wide. Right side: charging handle slot; left side: belt feed opening | Stamped/milled steel, black `#232326` |
| 9 | Top cover / feed hump | 150 x 40 x 18 hump | 490 to 640 | rises to +48 at peak (~X 560) | Rounded ridge on top of receiver over the feed tray — THE recognisable RPD hump | Steel, black |
| 10 | Rear sight (tangent leaf) | 60 x 25 base; leaf 55 long | 745 to 805 | base +30; leaf ramps to +52 | Classic AK-style tangent: sliding notch on a ramped leaf | Steel, black |
| 11 | Charging handle | 70 x 12 x 20 | 690 to 760, right side | -10 | Reciprocating handle on right rail; folds forward. One flat L-bar | Steel, black |
| 12 | Belt drum | dia 170, thickness 75 | center at 575 (under feed hump); spans 490 to 660 | top -55 (flush to receiver bottom), center -140, bottom -225 | Squat cylinder hung on a dovetail bracket; flat faces, raised rib ring on each face, small hinged lid catch at front. 12-16 sides | Stamped steel, olive drab `#4C5844` or black; VC examples often bare dented metal |
| 13 | Drum bracket | 90 x 30 x 20 | 530 to 620 | -55 to -75 | Sheet-metal saddle joining drum to receiver bottom | Steel, black |
| 14 | Trigger guard + trigger | guard 65 x 12 x 30; trigger 30 tall | guard 755 to 820; trigger at 775 | -55 to -88 | Oval loop under rear receiver | Steel, black |
| 15 | Pistol grip | 105 long, 32 x 45 section | top at 805 | top -55, bottom tip -155 | Raked ~20 deg back; oval section with flare at base | Wood `#7A4B26` (Bakelite on some Type 56: `#5A3320`) |
| 16 | Buttstock (club) | 230 x 42 x 110 at butt | 807 to 1037 | wrist on bore line; butt plate spans +35 to -75 | Wrist starts slim (40 x 55) behind receiver, swells downward into fat rounded club; underside has a sharp belly curve. Steel butt plate 4 thick | Laminated wood `#7A4B26`; butt plate steel black |
| 17 | Sling swivels (x2) | 30 dia D-loops | front: 400, left side of handguard band; rear: 950 under stock belly | front -35 (side-mounted); rear -70 | Flat loops | Steel, black |

**RPD quick proportions:** exposed barrel = 32% of overall; receiver = 30%; stock = 22%; drum diameter (170) = 2x receiver height; drum bottom hangs 225 below bore — lowest point of the gun.

---

## 3. RPG-7 (bonus)

**Verified totals:** tube 950 mm, bore 40 mm; weight 6.3 kg with PGO-7 optic; PG-7V grenade caliber 85 mm, grenade length ~925 mm; loaded overall ~1340 mm (nose protrudes ~390 mm).

Key visual differences from RPG-2: **two** grips (front trigger grip + rear support grip), bulged mid-rear expansion chamber, flared bell venturi at the rear, optic rail on left side, larger deeper warhead.

### RPG-7 parts table

| # | Part | L x W x H (mm) | X from muzzle (mm) | Y from bore (mm) | Shape notes | Material / color |
|---|------|----------------|--------------------|------------------|-------------|------------------|
| 1 | Forward tube | 560 long, OD 44 (bore 40) | 0 to 560 | 0 | Uniform cylinder | Blued steel `#2A2A2E` |
| 2 | Muzzle ring | 18 long, OD 48 | 0 to 18 | 0 | Reinforcing collar | Steel |
| 3 | Front sight (flip-up) | post tip +78 raised | base 80-100 | base +22 | Hinged post w/ small guard ears | Steel, black |
| 4 | Rear sight (leaf) | leaf 60 tall | base 360-385 | base +22, tip +95 | Flip-up graduated leaf | Steel, black |
| 5 | Optic rail (side) | 90 x 15 x 25 | 430 to 520, LEFT side | +10 to +30 | Dovetail bar for PGO-7 scope (omit scope for low-poly VC version) | Steel, black |
| 6 | Trigger grip (front) | 110 long, 30 x 42 | top at 500 | top -35, tip -145 | Raked ~15 deg; hammer spur behind it at X 560, Y -30 | Bakelite `#4A2C1A` |
| 7 | Trigger + guard | guard 60 x 30 | trigger at 478 | -35 to -60 | Curved blade | Steel, black |
| 8 | Rear support grip | 100 long, 28 x 38 | top at 650 | top -35, tip -135 | Slightly less rake (~10 deg) | Bakelite `#4A2C1A` |
| 9 | Expansion chamber (bulge) | 240 long, OD 44 -> 72 -> 44 | 560 to 800 | 0 | Smooth spindle bulge: swells from 44 to ~72 OD at X 680, back down by 800 | Steel under wood (see #10) |
| 10 | Wooden heat-guard | 250 long, follows bulge, wood adds ~8 OD | 555 to 805 | 0 (wraps chamber) | Two half-shells over the bulged chamber — reads as one fat wooden spindle. Steel band each end | Wood `#6B4A2B` |
| 11 | Venturi bell | 150 long, dia 44 -> 34 throat -> 74 exit | 800 to 950 | 0 | Narrows to throat (~X 850) then flares to open bell at rear. 3 loft rings | Steel, heat-stained dark `#1F1F22` |
| 12 | Sling swivels (x2) | 25 dia | 130 and 900 | -24 | D-loops under tube | Steel |

### PG-7V grenade (loaded)

| # | Part | Dims (mm) | X from muzzle (mm) | Y from bore | Shape notes | Material / color |
|---|------|-----------|--------------------|-------------|-------------|------------------|
| G1 | Fuze tip | 20 long, dia 10 -> 22 | -390 to -370 | 0 | Pointed cap | Steel |
| G2 | Ogive | 180 long, dia 22 -> 85 | -370 to -190 | 0 | Longer, sleeker ogive than PG-2 | Olive drab `#4A5D3A` |
| G3 | Max-dia section | 70 long, dia 85 | -190 to -120 | 0 | Cylindrical band | Olive drab |
| G4 | Boat-tail | 90 long, dia 85 -> 40 | -120 to -30 | 0 | Cone to sustainer tube; visible nozzle ring detail optional | Olive drab / steel |
| G5 | Sustainer/booster tube | dia 40 | -30 into bore | 0 | Only ~30 mm visible ahead of muzzle | Steel, black |

---

## Shared material palette (game-ready)

| Material | Base color | Rough | Metal | Used on |
|----------|-----------|-------|-------|---------|
| Blued steel | `#26262A` | 0.55 | 0.9 | Tubes, barrels, receivers, sights |
| Heat-stained steel | `#1F1F22` | 0.7 | 0.8 | RPG venturis, RPD gas tube |
| Lacquered birch | `#6B4A2B` | 0.45 | 0.0 | RPG heat-guards |
| Laminated red-brown wood | `#7A4B26` | 0.4 | 0.0 | RPD stock/grip/handguard |
| Bakelite | `#4A2C1A` | 0.35 | 0.0 | RPG-7 grips, some RPD grips |
| Warhead olive drab | `#4A5D3A` | 0.6 | 0.1 | PG-2 / PG-7V warheads |
| Drum olive | `#4C5844` | 0.65 | 0.3 | RPD belt drum |

**Low-poly budget suggestion:** RPG-2 ~450 tris, RPD ~700 tris (drum 12-sided), RPG-7 ~550 tris. Tubes 8-10 sides; drum faces need the rib ring, everything else can be silhouette-only.

*Sources: [RPG-2 Wikipedia](https://en.wikipedia.org/wiki/RPG-2), [RPD Wikipedia](https://en.wikipedia.org/wiki/RPD_machine_gun), [modernfirearms.net RPG-2](https://modernfirearms.net/en/grenade-launchers/russia-grenade-launchers/rpg-2-eng/), [modernfirearms.net RPD](https://modernfirearms.net/en/machineguns/russia-machineguns/rpd-eng/), [bulletpicker PG-2](https://www.bulletpicker.com/projectile_-heat_-pg-2.html), [RPG-7 Wikipedia](https://en.wikipedia.org/wiki/RPG-7). Positions marked (est.) scaled from reference photos against verified totals.*
