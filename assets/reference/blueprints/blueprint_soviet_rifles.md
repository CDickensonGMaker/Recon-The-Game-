# Numeric Blueprints — Soviet/Communist Rifles (Vietnam Era)
## AK-47 / Type 56 · Mosin-Nagant 91/30 · PPSh-41

**Coordinate convention (all weapons, same as blueprint_us_rifles.md):**
- **X** = distance in mm from muzzle tip (X=0 at the very front of the weapon), increasing toward the butt.
- **Y** = vertical offset in mm from the **bore centerline** (positive = above bore, negative = below bore). Values are part centers unless noted "top"/"bottom"/"tip".
- **Z** = width (left–right), symmetric about bore unless noted.
- Dims given as **L × H × W** (length along bore × height × width).
- Build lying along +X in Blender; bore line = X axis.
- Anchor dims (OAL, barrel length, sight radius, LOP) are published figures; intermediate part positions are derived and internally consistent to **±10 mm** — well inside low-poly tolerance.

**Shared material palette:**

| Material | Hex | Used on |
|----------|-----|---------|
| Blued steel (dark) | `#2B2B30` | Barrels, receivers, sights, mags, small parts |
| Worn blue / edge highlight | `#4A4A52` | Edge wear, bolt handles, high-touch metal |
| Bright steel (bolt body) | `#8E8E96` | Mosin bolt body, AK carrier top edge |
| Chinese chu-wood (Type 56) | `#6E3A20` | Type 56 furniture — dark oxblood brown |
| Soviet birch laminate | `#8A4A26` | AK-47 furniture — amber-red shellac |
| Birch shellac (Mosin/PPSh) | `#9C5A28` | 91/30 + PPSh-41 stocks — honey-amber |
| Wartime dark shellac variant | `#7A4520` | Optional grimier stock tone |
| Steel buttplate / bands | `#3A3A40` | Buttplates, barrel bands, swivels |
| Gas-tube heat tint | `#5A5248` | AK gas tube (subtle brown-gray) |

---

## 1. AK-47 (Type 3 milled) / CHINESE TYPE 56

**Totals: OAL 870 mm · Barrel 415 mm · Sightline ~48 mm above bore · Sight radius 378 mm**

Anchors: muzzle nut tip X=0. Breech face X=415 (chamber sits inside receiver). Receiver front X=353, receiver rear X=618. Buttplate X=870.
AK-47 vs Type 56 differences flagged inline: **[T56]** = fully hooded front sight + underfolding spike bayonet; AK-47 = open sight ears, no bayonet fitted.

| # | Part | L × H × W (mm) | X position | Y offset | Material / Notes |
|---|------|----------------|-----------|----------|------------------|
| 1 | Muzzle nut (thread protector) | 14 × Ø17 | 0 – 14 | 0 | Blued `#2B2B30`. Plain cylinder — **no slant brake** (that's AKM); tiny detent notch optional |
| 2 | Barrel stub (nut → FSB) | 10 × Ø15 | 14 – 24 | 0 | Blued |
| 3 | Front sight assembly | base 38 × 48 × 24 | 24 – 62 | base spans Y −12 to +36; **post tip Y +48** | Post Ø2.5 × 12 in threaded drum. AK-47: two open ears; **[T56]: full hoop hood Ø16 enclosing post** — instantly reads "Type 56" |
| 4 | Exposed barrel (FSB → gas block) | 58 × Ø15→16 | 62 – 120 | 0 | Blued; slight rear taper-up |
| 5 | Gas block | 38 × 46 × 22 | 120 – 158 | spans Y −10 to +36 | 45° front slope up to gas-tube socket; bayonet hinge boss under **[T56]** |
| 6 | Gas tube | Ø18 | 158 – 330 (exposed only 158–175) | centerline **Y +27** | Heat-tinted `#5A5248`; mostly hidden by upper handguard |
| 7 | Handguard retainer cap | 15 × 50 × 34 | 158 – 173 | spans Y +36 to −34 | Steel band; **front sling swivel** hangs below-left at X 165, Y −28 |
| 8 | Upper handguard | 150 × 22 × 30 | 175 – 325 | center Y +27 | Wood over gas tube; half-round section |
| 9 | Lower handguard | 178 × 36 × 40 | 175 – 353 | spans Y +2 to −34 | Wood; slight belly/palm swell at bottom; ends flush at receiver front |
| 10 | Rear sight block + tangent leaf | base 40 × 30 × 34; leaf 80 × 4 × 12 | base 325 – 365; leaf 333 – 413 | base top Y +34; **notch Y +46** | Base is a ramped wedge on the barrel bridging receiver front; leaf lies rearward on ramp w/ sliding elevator. Notch at X≈411 → sight radius 378 ✓ |
| 11 | Receiver (milled, Type 3) | **265 × 62 × 32** | **353 – 618** | top Y +24, bottom Y −38 | Milled slab; **signature oval lightening-cut dish** each side 80 × 20 at X 380–460, Y −8 (the #1 milled-AK identifier) |
| 12 | Dust cover | 253 × 12 × 32 | 365 – 618 | rounded top to Y +28 | Smooth (milled guns have un-ribbed covers) |
| 13 | Charging handle | knob 25 × 15 | at rest X ≈ 440 | Y +8, right side (Z +22) | Part of bolt carrier; reciprocates in slot |
| 14 | Selector lever | 90 × 12 blade | 460 – 550 | Y +5 to −15, right side | Long stamped blade, pivot at rear |
| 15 | Magazine well opening | 80 × — × 26 | 395 – 475 | at receiver bottom Y −38 | Front edge of well/mag top = **X 395 from muzzle** |
| 16 | Magazine, 30-rd banana | opening 78 (f-b) × 24 W; **chord 185, bulge 38** | feed lips center (X 435, Y −45) → floorplate center (X 450, Y −215) | see arc | Blued steel w/ ribs. Curve: mid-body pushed **rearward** ~38 mm off the chord (arc radius ≈ 160), concave side faces front. Tangent at top ~10° from vertical; floorplate 85 × 26 tilted ~35° nose-down-forward |
| 17 | Mag release paddle | 25 × 15 × 12 | 475 – 500 | Y −40 | Behind mag, inside guard root |
| 18 | Trigger guard + trigger | guard 78 × 22 × 12 | 495 – 573 | guard bottom Y −62 | Trigger blade at X 515, tip Y −52 |
| 19 | Pistol grip | 95 along axis × 42 (f-b) × 32 | top 560 – 608 at Y −38 | bottom center X 640, **Y −128** | Raked back ~30° from vertical. AK-47/T56: wood `#6E3A20` |
| 20 | Buttstock | 252 exposed | 618 – 870 | see profile table | Wood; noticeable downward slope (more drop than M16) |
| 21 | Buttplate | 10 × 125 × 38 | 860 – 870 | heel Y −28 → toe Y −150 | Steel `#3A3A40`, trapdoor for cleaning kit |
| 22 | Rear sling swivel | loop Ø20 | X 720 | Y −15, **left side** of butt | Flat side-mounted loop (AK signature — sling rides the left flank) |
| 23 | Cleaning rod | Ø4.5 × ~340 | visible 10 – 120 | Y −15 | Bright/gray steel under barrel; disappears into gas block hole, hidden under handguard beyond |
| 24 | **[T56] Folding spike bayonet (folded)** | spike Ø9 cruciform × 310; hinge block 30 × 25 × 22 | hinge 60 – 95 under barrel; **folded spike 95 – 400 pointing rearward** | spike line Y −30 | Blued. Folded tip stops just short of the mag well — nests along cleaning rod / handguard belly. (Extended: swings 180° to point forward, tip at X −215) |

**Stock/grip profile (Y from bore):**

| Station | X (mm) | Top of wood Y | Bottom of wood Y |
|---------|--------|---------------|------------------|
| Receiver rear / wrist start | 625 | +5 | −45 |
| Wrist (narrowest, oval 38 W × 50 H) | 660 | 0 | −48 |
| Comb mid | 760 | −14 | −60 |
| Heel | 866 | −28 | — |
| Toe | 866 | — | −150 |

**Proportional gut-checks:** receiver = 30.5% of OAL; everything forward of the receiver (muzzle hardware, barrel, gas system, handguards) = the front 41%; stock = rear 29%. Gas tube sits one barrel-diameter above the barrel (bore→tube centers = 27 mm). Mag front edge at 45% of OAL.

---

## 2. MOSIN-NAGANT 91/30

**Totals: OAL 1232 mm · Barrel 730 mm · LOP 343 mm (13.5") · Sight radius ≈622 mm · Sightline only ~25–29 mm above bore (very low)**

Anchors: muzzle X=0. Breech face X=730. Receiver ring front X=705 (barrel shank threads in). Receiver tang rear X=930. Buttplate X=1232. Wood covers almost the whole gun — only 70 mm of barrel shows at the muzzle.

| # | Part | L × H × W (mm) | X position | Y offset | Material / Notes |
|---|------|----------------|-----------|----------|------------------|
| 1 | Front sight (hooded post) | hood Ø18 × 22; base band 20 × Ø16.5 | 5 – 27 | **post tip Y +25**; hood top Y +32 | Blued. 91/30 = globe hood (cylinder open front/back) around thin post — key silhouette vs. open-blade M91 |
| 2 | Barrel | stepped taper Ø14.5 → Ø17 → Ø22 → Ø28 | 0 – 705 (exposed 0–70, plus slot at rear sight) | 0 | Blued; chamber reinforce Ø28 over X 650–705 |
| 3 | Fore-end nose cap | 15 × 34 × 42 | 70 – 85 | spans Y +5 to −40 | Steel `#3A3A40`; wood tip starts here |
| 4 | Cleaning rod (head only visible) | rod Ø5; head knob Ø9 × 12 | head 40 – 52, protruding ahead of nose cap | Y −22 | Bright steel; rest hidden in stock channel |
| 5 | Front barrel band | 12 × 48 × 46 | 180 – 192 | wraps stock+barrel | Spring-retained flat band, steel |
| 6 | Rear barrel band | 12 × 52 × 48 | 495 – 507 | wraps stock+barrel | Same pattern, slightly larger |
| 7 | Handguard (upper wood) | 365 × 20 × 40 | 195 – 560 | arch top ≈ Y +21 | Birch `#9C5A28`; half-round cap over barrel between the bands, ends at rear-sight base |
| 8 | Rear sight (tangent leaf) | base 75 × 15 × 25; leaf 70 × 4 × 14 | base 565 – 640 | **notch Y +29** at X ≈ 640 | Blued; curved ramp base, leaf lies rearward w/ slider (arshin/meter graduations = texture). Front post 18 → notch 640 = 622 mm radius ✓ |
| 9 | Fore-end / full stock (lower wood) | continuous 70 – 1232 | — | see profile | One-piece birch; slab-sided, deep barrel channel; finger groove along each side X 250–550 at Y −5 (shallow scallop) |
| 10 | Receiver | Ø30 cylinder × 225 | 705 – 930 | co-axial, 0 | Blued. Ring 705–775, open top over port 775–850, rear bridge + tang 850–930. Round receiver (hex only on pre-war — optional) |
| 11 | Bolt body | Ø18 × 120 | 750 – 870 | 0 | **Bright steel `#8E8E96`** — polished, not blued |
| 12 | Bolt handle | root Ø12 × 35; ball knob Ø20 | root at **X 790** | Y −3; sticks straight out **right, knob center Z +58** | Bright steel. Straight horizontal stick — 95 mm AHEAD of the trigger (signature awkward Mosin reach) |
| 13 | Cocking piece | Ø22 × 25 | 930 – 955 | 0 | Blued knurled knob poking out the back of the bolt |
| 14 | Magazine (protruding single-stack) | 90 × — × 24 | 740 – 830 | stock line Y −52 down to **Y −92** | Blued; flat sides, slanted front edge, hinged floorplate w/ latch button at rear-bottom. Sticks ~40 below the stock belly |
| 15 | Trigger guard + trigger | loop 70 × 25 × 12 | 850 – 920 | bottom Y −70 | Milled steel; trigger blade X 885, tip Y −58 (butt 1232 − 885 ≈ 343 LOP ✓) |
| 16 | Stock wrist | 80, oval 42 W × 55 H | 930 – 1010 | top Y 0 → −8 | Straight wrist (no pistol grip at all — WWI-profile stock) |
| 17 | Buttstock | 222 | 1010 – 1232 | see profile | Long straight comb, modest drop |
| 18 | Buttplate | 10 × 128 × 40 | 1222 – 1232 | heel Y −35 → toe Y −162 | Steel `#3A3A40`, gently curved, screw top + bottom |
| 19 | Sling slots (NO swivels) | slots 45 × 12 w/ oval steel escutcheons | front slot X 545 – 590 (through fore-end); rear slot X 1075 – 1120 (through butt) | front Y −35; rear Y −70 | **Mosin uses pass-through slots + leather "dog collars", not swivels** — model as recessed oval holes |
| 20 | Socket bayonet (optional, mounted) | socket Ø24 × 70; cruciform spike Ø11 × 430 | socket 0 – 70 over muzzle; spike X −430 → 0 | spike offset **Z +20 (right of bore)**, Y 0 | Bright/in-the-white steel. Cranked neck kicks blade right so it clears the sight line; flat screwdriver tip. Mounted OAL ≈ 1660 |

**Stock profile (Y from bore):**

| Station | X (mm) | Top of wood Y | Bottom of wood Y |
|---------|--------|---------------|------------------|
| Fore-end tip | 85 | −4 (barrel exposed above) | −40 |
| Mid fore-end | 400 | −4 | −45 |
| Action / mag area | 800 | −14 (wood shoulder beside receiver) | −52 |
| Wrist | 970 | 0 | −55 |
| Comb start | 1020 | −8 | −62 |
| Heel | 1227 | −35 | — |
| Toe | 1227 | — | −162 |

**Proportional gut-checks:** receiver ring front sits 57% of the way back. Barrel = 59% of OAL. Wood runs 94% of the gun's length (X 70→1232). Sight radius 622 = just over half the weapon. Bolt handle X 790 = 64% back, well ahead of the trigger.

---

## 3. PPSh-41

**Totals: OAL 843 mm · Barrel 269 mm (muzzle recessed ~12 mm inside shroud) · Sightline ~40 mm above bore**

Anchors: **X=0 at shroud front tip** (foremost point of gun). Barrel muzzle crown X≈12 inside. Breech X≈281. **Shroud + receiver are ONE continuous stamped upper line, X 0 → 585** — model them as a single silhouette with a small width step at 272. Buttplate X=843.

| # | Part | L × H × W (mm) | X position | Y offset | Material / Notes |
|---|------|----------------|-----------|----------|------------------|
| 1 | Barrel shroud | 272 × 43 × 36 | 0 – 272 | top **Y +25**, bottom Y −18 | Blued/rough-blued stamped steel `#2B2B30`. Rounded-rectangle section (flat sides, radiused top+bottom) |
| 2 | Muzzle brake front (shroud face) | slanted plate | 0 – 22 | face rakes back ~20° (top overhangs bottom) | Signature slanted snout; central bullet hole Ø11 at Y 0; open scallop each side X 0–28 |
| 3 | Vent slots | 3 per side, each **48 × 12** | 60–108, 122–170, 184–232 | slot centers Y +6 | Long rounded-end rectangles punched through both flanks — the PPSh identifier; barrel Ø14 glimpsed inside (skippable at low poly) |
| 4 | Barrel | Ø14 × 269 | 12 – 281 | 0 | Hidden inside shroud; chrome-lined bore irrelevant at this scale |
| 5 | Front sight | post + ears; base 18 × 12 × 18 | 22 – 40 on shroud top | **post tip Y +40** | Blued; thin post between two protective ear blades (some late guns full hood — ears are the common look) |
| 6 | Receiver | 313 × 57 × 42 | **272 – 585** | top **Y +27**, bottom Y −30 | Continues the shroud line — same rounded top, 3 mm wider each side at the 272 step. Rear end rounded, hinge under X 278 (barrel unit tips forward to open — no visible seam needed), latch bump top rear X 572 |
| 7 | Ejection port | 40 × 14 | 295 – 335 | on TOP, Y +27 | PPSh ejects straight up |
| 8 | Charging handle | knob Ø12 × 35 long | slot 330 – 470 right side; handle at rest **X ≈ 345** (bolt forward) | Y +5, protrudes Z +26 | Blued; sliding safety catch on the handle itself (tiny — texture) |
| 9 | Rear sight | flip "L" 2-notch; base 28 × 22 × 24 | 425 – 453 | **notch Y +38** | Wartime standard = flip L (early guns: tangent leaf). Sight radius ≈ 395 |
| 10 | Drum magazine, 71-rd | disc **Ø152 × 34 thick** | front edge X 282, rear edge X 434; **center X 358, Y −108**; bottom Y −184 | centered on bore (Z 0) | Blued steel. Flat rear face; front face carries central button Ø20 + top latch tab; faint circumferential crease ring at Ø120 (texture). Feed tower 70 (f-b) × 30 tall × 26 W rises from drum top into well |
| 11 | Magazine well | opening 70 × 26 | 325 – 395 | at stock line Y −32 | In the stock/receiver junction; **drum front edge tucks right under the shroud step** |
| 12 | Mag release lever | 30 × 12 | 400 – 430 | Y −40, behind tower | Flat spring lever |
| 13 | Trigger guard + trigger | stamped loop 75 × 28 × 12 | 480 – 555 | bottom **Y −80** | Trigger blade X 505, tip Y −65 |
| 14 | Fire selector | sliding button 15 × 8 | X 488, inside front of guard | Y −55 | Push-through slider ahead of trigger: full/semi |
| 15 | Stock (one-piece birch) | runs 285 – 843 | — | see profile | `#9C5A28`. Fore portion is a deep wooden chin under the receiver; angled nose starts under the shroud/receiver step |
| 16 | Stock wrist | oval 40 W × 55 H | 585 – 660 | top Y −5 | Semi-pistol-grip curve under the wrist (gentle hook, not a separate grip) |
| 17 | Buttstock | 660 – 843 | — | heel Y −55, toe Y −175 | Classic dropped rifle butt — much more drop than the AK |
| 18 | Buttplate | 10 × 125 × 42 | 833 – 843 | heel Y −52 → toe Y −172 | Steel `#3A3A40`, curved |
| 19 | Sling fittings | front loop Ø18; rear slot 45 × 10 | front X 315, left side of stock nose, Y −45; rear slot X 745 – 790 through butt, Y −85 | left-side carry | Steel loop + slotted escutcheon |

**Stock profile (Y from bore):**

| Station | X (mm) | Top of wood Y | Bottom of wood Y |
|---------|--------|---------------|------------------|
| Stock nose (under receiver) | 300 | −30 (meets receiver bottom) | −58 |
| Beside mag well | 380 | −30 | −62 (well cut out between) |
| Wrist | 620 | −5 | −60 |
| Comb start | 665 | −8 | −70 |
| Heel | 838 | −55 | — |
| Toe | 838 | — | −175 |

**Proportional gut-checks:** the continuous shroud+receiver steel line = the front **69%** of the gun; wood butt = the rest. Barrel is only 32% of OAL — it's all shroud. Drum center at 42% of OAL, diameter 152 ≈ 18% of the gun's length (reads BIG); drum bottom hangs 184 below bore, deeper than the trigger guard. Muzzle face is slanted, never flat.

---

## Cross-weapon sanity table

| | AK-47/T56 | Mosin 91/30 | PPSh-41 |
|---|---|---|---|
| OAL | 870 | 1232 | 843 |
| Barrel | 415 (48%) | 730 (59%) | 269 (32%) |
| Receiver span (X) | 353–618 | 705–930 | 272–585 |
| Sightline above bore | 48 | 25 | 40 |
| Sight radius | 378 | 622 | ~395 |
| Mag front edge (X) | 395 | 740 | 325 (well) / 282 (drum) |
| Mag lowest point (Y) | −215 | −92 | −184 |
| Drop at heel (Y) | −28 | −35 | −55 |
| LOP (trigger→butt) | ~355 | 343 | ~338 |
| Wood tone | `#8A4A26` (Sov.) / `#6E3A20` (T56) | `#9C5A28` | `#9C5A28` |

Sources for anchors: [AK-47 — Wikipedia](https://en.wikipedia.org/wiki/AK-47) (OAL/barrel/378 mm sight radius), [Mosin-Nagant specs — 7.62x54r.net mirror](https://thinlineweapons.com/7.62x54r/7.62x54r.net/MosinID/MosinSpec.html) (LOP 13.5", buttplate), [Mosin–Nagant — Wikipedia](https://en.wikipedia.org/wiki/Mosin%E2%80%93Nagant), [PPSh-41 — Wikipedia](https://en.wikipedia.org/wiki/PPSh-41). Part-level positions derived from these anchors + armory reference photos; treat as ±10 mm.
