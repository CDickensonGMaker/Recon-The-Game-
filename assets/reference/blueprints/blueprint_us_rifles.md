# Numeric Blueprints — US Rifles (Vietnam Era)
## M14 · M16A1 · Winchester Model 70 Sniper · Ithaca 37

**Coordinate convention (all weapons):**
- **X** = distance in mm from muzzle tip (X=0 at the very front of the weapon, including flash hider), increasing toward the butt.
- **Y** = vertical offset in mm from the **bore centerline** (positive = above bore, negative = below bore). Y values given for part centers unless noted "top"/"bottom".
- **Z** = width (left–right), symmetric about bore unless noted.
- Dims given as **L × H × W** (length along bore × height × width).
- Build each weapon lying along +X axis in Blender; bore line = X axis.

---

## 1. M14 RIFLE

**Totals: OAL 1118 mm · Barrel 559 mm (22") · Bore-to-sightline ~26 mm**

Layout anchors: flash suppressor tip X=0. Barrel muzzle (crown, hidden inside suppressor) at X≈70. Barrel breech / receiver front at X≈635. Buttplate face at X=1118.

| # | Part | L × H × W (mm) | X position (from muzzle) | Y offset (bore line) | Notes |
|---|------|----------------|--------------------------|----------------------|-------|
| 1 | Flash suppressor (slotted) | 89 × 22 × 22 (Ø22 tube) | 0 – 89 | 0 (co-axial) | 6 long slots ~55 mm, cut radially; open front; bayonet lug small block on bottom rear (~15×10×10 at X 70–85, Y −14) |
| 2 | Front sight | blade 16 tall × 2 wide; base 25 × 10 × 18 | X 8 – 33 (sits on suppressor) | blade top at Y +27 | Protected by 2 angled steel wings, dovetailed onto suppressor |
| 3 | Barrel (exposed section) | 250 × Ø16 tapering to Ø15 | X 89 – 340 | 0 | Exposed between suppressor and gas cylinder front band; parkerized |
| 4 | Gas cylinder | 150 × Ø26 | X 190 – 340 | center Y −24 (hangs under barrel) | Cylinder under barrel, connected by short vertical web; front cap Ø28; gas plug visible at front face |
| 5 | Front band / ferrule | 12 × 55 × 40 | X 335 – 347 | spans Y +10 to −45 | Steel band joining barrel, gas cylinder, stock tip |
| 6 | Ventilated upper handguard | 290 × 12 × 38 | X 345 – 635 | top at Y +18 | Brown fiberglass; shallow arch over barrel; model 4–6 oval vent slots (real one is solid-ish; slots optional for style) |
| 7 | Stock fore-end | 300 × 55 × 42 | X 340 – 640 | bottom at Y −48 | Walnut; wraps barrel sides from below; flat-ish bottom, rounded tip; cleaning-rod groove ignore |
| 8 | Receiver | 222 × 42 × 40 | X 635 – 857 | Y +21 top, −21 bottom | Milled steel; op-rod hump on right side (add 8 mm bulge); charging handle rod along right at Y 0 |
| 9 | Rear aperture sight | 22 × 18 × 24 | X 835 – 857 (rear of receiver) | aperture at Y +26 | Drum knobs both sides (Ø14 × 8); aperture Ø2 |
| 10 | Magazine, 20-rd 7.62 | 90 (f-b) × 185 (tall) × 25 | X 690 – 780 | bottom at Y −160 | Nearly straight box, gentle rear curve: bottom displaced ~12 mm rearward vs top; steel gray-green |
| 11 | Trigger guard + trigger | guard 85 × 25 × 12 | X 795 – 880 | bottom at Y −72 | Stamped loop; trigger blade at X 830, Y −55; guard doubles as action lock (ignore detail) |
| 12 | Stock wrist (small of stock) | ~90 long | X 860 – 950 | see profile below | Oval section ~ 35 W × 48 H |
| 13 | Buttstock | 260 long | X 858 – 1118 | see profile below | Straight comb; slight downward toe line |
| 14 | Buttplate w/ shoulder rest | 12 × 130 × 42 | X 1106 – 1118 | Y +5 (top/heel) to −125 (toe) | Steel, checkered; hinged flap on top edge (model as thin plate 60 × 35 × 4, folded flat against top of plate) |
| 15 | Front sling swivel / rear swivel | Ø small loops | X 350 / X 1060 | Y −50 / Y −95 | Optional at low poly |

**Stock profile heights (top of wood, Y from bore):**

| Station | X (mm) | Top of stock Y | Bottom of stock Y |
|---------|--------|----------------|-------------------|
| Fore-end tip | 345 | −5 (meets band) | −48 |
| Mid fore-end | 500 | −8 | −48 |
| Receiver front | 640 | −18 (wood shoulder) | −50 |
| Wrist (narrowest) | 900 | +2 (comb start) | −46 |
| Comb | 950 | −14 | — |
| Heel (top of buttplate) | 1115 | −20 | — |
| Toe (bottom of buttplate) | 1115 | — | −125 |

---

## 2. M16A1

**Totals: OAL 986 mm · Barrel 508 mm (20") · Sightline 66 mm above bore**

Anchors: flash hider tip X=0. Barrel muzzle at X≈25 (inside hider). Chamber/upper receiver front at X≈500. Buffer tube stock joins receiver at X≈720. Buttplate X=986.

> **REAR SECTION RE-SEATED 2026-07-28 against the reference photo**
> (`assets/reference/weapons/ref_ak_car15_m16a1.jpg`, bottom rifle). The previous table put the
> magwell at X 620–698, the pistol grip at X 755–810 and the magazine bottom at Y −195. Measurement
> says X 547–620, X 662–712 and Y −127. The old numbers were also self-contradictory: a pistol grip
> at X 755–810 sits *behind* the upper receiver's rear face (X 723), i.e. buried inside the
> buttstock. **The photo is source of truth (Summoner's ruling).** Front half was confirmed, not
> changed — the front sight post measured **+66.0 mm at X 160**, which the old table already had.
> Method: connected-run silhouette walk seeded on the bore row, luma threshold 200 (extents identical
> from 170–240); scale keyed on this rifle at 986 mm = 1060 px → 0.930189 mm/px.

| # | Part | L × H × W (mm) | X position | Y offset | Notes |
|---|------|----------------|-----------|----------|-------|
| 1 | Birdcage flash hider (A1) | 40 × Ø21 | 0 – 40 | 0 | 6 slots spaced evenly incl. bottom (A1 = fully open cage); closed ring at front face. Photo resolves the hider/barrel step at 33–40; real A1 cages run 51 — the photo wins |
| 2 | Barrel (exposed, pencil) | 115 × Ø13 | X 40 – 155 | 0 | Thin "pencil" profile between hider and FSB |
| 3 | Front sight base (FSB) | 22 (f-b) × 89 (tall) × 20 | X 150 – 172 | triangle apex at Y +48; **post tip Y +66** | Distinct TRIANGLE from side; round sight post Ø4 between 2 protective ears; bayonet lug + sling swivel below, down to Y −23 |
| 4 | Barrel under handguard | 330 × Ø13 | X 172 – 500 | 0 | Hidden; gas tube Ø6 above barrel Y +12 (skip at low poly) |
| 5 | Delta ring / front cap | 15 × Ø38 | X 193 – 208 | 0 | Ridge reads at Y +37 |
| 6 | Triangular handguards | 296 long | X 204 – 500 | front top +27 / bottom −17; rear top +32 / bottom −29 | Rounded-triangle cross-section, point DOWN; tapers toward the front; 5 oval vent holes each side bottom edge; black fiberglass |
| 7 | Upper receiver | 220 × 72 × 32 | X 500 – 720 | **top Y +43**, bottom Y −29 | Flat-top sides; ejection port door right side (35 × 15) at X 560, Y +2 |
| 8 | Carry handle | front leg X 500–540, rear leg X 655–700 | top Y +70 | underside Y +52 → **gap under handle ≈ 24 mm tall** | Rear aperture sight inside the rear leg, flip aperture Y +66 (on the measured sight line); windage drum right side Ø14. Photo reads the handle top at +78, but the walk climbs the leg rather than the web there — +70 is kept because it is consistent with the cleanly measured +66 aperture |
| 9 | Charging handle | 90 × 12 × 30 | X 700 – 740 (T at rear) | Y +36 | T-handle protrudes at the rear of the receiver top |
| 10 | Forward assist bump | Ø16 × 18 deep | X 640 | Y +10, **right side only** (Z +18) | Round teat-shaped plunger, angled back ~15°; A1 signature |
| 11 | Magwell (slab-sided) | 73 (f-b) × 51 × 24 | X 547 – 620 | Y −29 to −80 | Clean flat slabs, slight forward rake matching the mag angle; fencing ridge around the mag release, right side |
| 12 | Magazine, 20-rd straight | 64 (f-b) × 176 total (**≈100 exposed**) × 23 | X 547 – 620 | exposed Y −80 down to **Y −127** | STRAIGHT aluminum box, canted FORWARD ~8° from vertical (bottom ~15 mm ahead of top); gray anodized |
| 13 | Trigger guard + trigger | 40 × 22 × 10 | X 620 – 660 | bottom Y −45 to −60 | Trigger blade at X 640, Y −45 |
| 14 | Pistol grip (A1) | 50 (f-b) × 100 (tall) × 30 | X 662 – 712 | Y −78 down to **Y −127** | Raked back ~35° from vertical (bottom ~50 mm behind top); black polymer, no finger grooves |
| 15 | Lower receiver rear / buffer tower | 60 × 45 × 32 | X 700 – 760 | Y −40 to +20 | Contains the stock screw boss |
| 16 | Buttstock (fixed, A1) | 266 long | X 720 – 986 | **TOP EDGE straight at Y +30**; bottom slopes Y −29 at front → **Y −96** at the butt | Straight-line stock, triangle-ish side profile; black polymer w/ trapdoor buttplate; sling swivel bottom rear |
| 17 | Buttplate | 8 × 126 × 40 | X 978 – 986 | Y +29 to −96 | Checkered black, hinged trapdoor (skip detail) |

---

## 2b. CAR-15 CARBINE

**Totals: OAL 753 mm · Sightline 65 mm above bore**

Measured from the reference photo's **top** rifle by the same method as §2. This is the carbine as
pictured — long tubular flash moderator, short round ribbed handguard, collapsible stock — not the
XM177E2 (Summoner's ruling 2026-07-28: match the photo exactly).

**The receiver group is the M16A1's, shifted 138 mm forward.** Upper receiver, carry handle, magwell,
magazine, trigger group and pistol grip are the same parts at the same bore offsets; only the front
end (short barrel + moderator + round handguard) and the rear (collapsible stock on a buffer tube)
differ. Cross-check that this is real and not a measurement artefact: the barrel is ~218 mm shorter
than the M16A1's and the moderator ~67 mm longer, so the receiver *should* sit ~151 mm forward — the
photo says 138 mm, inside the parallax error for a rifle off the frame centre.

| # | Part | L × H × W (mm) | X position | Y offset | Notes |
|---|------|----------------|-----------|----------|-------|
| 1 | Flash moderator | 100 × Ø24 | 0 – 100 | 0 | Long tube, noticeably fatter than the barrel; closed ring at the front face |
| 2 | Barrel (exposed) | 55 × Ø13 | X 100 – 155 | 0 | Short stub between moderator and FSB |
| 3 | Front sight base (FSB) | 22 (f-b) × 88 (tall) × 20 | X 165 – 187 | apex +48; **post tip Y +65** | Same triangular FSB as the M16A1; sight plane matches within 1 mm |
| 4 | Delta ring / front cap | 15 × Ø38 | X 190 – 205 | 0 | |
| 5 | Round handguard | 176 long × Ø55 | X 204 – 380 | top +28 / bottom −25 (centre +1.5) | ROUND ribbed carbine handguard, not triangular — the clearest visual difference from the M16A1 |
| 6 | Upper receiver | 220 × 72 × 32 | X 380 – 600 | top Y +43, bottom Y −29 | Identical to §2 item 7 |
| 7 | Carry handle | front leg X 380–420, rear leg X 520–565 | top Y +70 | gap under handle ≈ 24 | Identical to §2 item 8 |
| 8 | Magwell | 73 × 51 × 24 | X 409 – 482 | Y −29 to −80 | Identical to §2 item 11 |
| 9 | Magazine, 20-rd straight | 64 × 176 (≈100 exposed) × 23 | X 409 – 482 | exposed Y −80 to **Y −119** | Identical to §2 item 12 |
| 10 | Trigger guard + trigger | 40 × 22 × 10 | X 482 – 522 | bottom Y −45 to −60 | |
| 11 | Pistol grip (A1) | 50 × 100 × 30 | X 524 – 574 | Y −78 down to **Y −136** | Identical to §2 item 14 |
| 12 | Buffer tube | 175 × Ø32 | X 590 – 765 | centre Y −2 | Round tube the stock slides on; exposed between receiver and stock body |
| 13 | Collapsible stock | 160 long | X 593 – 753 | **top Y +14**; bottom slopes Y −28 front → **Y −80** at the butt | Slim aluminium/polymer slider — sits far lower than the M16A1's fixed stock (top +14 vs +30), which is what makes the carbine read squat |
| 14 | Buttplate | 6 × 94 × 38 | X 747 – 753 | Y +14 to −80 | Flat, no trapdoor |

---

## 3. WINCHESTER MODEL 70 (pre-64) — USMC VIETNAM SNIPER

**Totals: OAL ~1140 mm · Barrel 610 mm (24") · .30-06**

Anchors: muzzle X=0 (bare crown — **Marine armorers usually removed the front sight**; both options below). Receiver front ring X=610. Buttplate X=1140.

| # | Part | L × H × W (mm) | X position | Y offset | Notes |
|---|------|----------------|-----------|----------|-------|
| 1 | Muzzle (bare) | crown Ø17 | X 0 | 0 | Clean crowned muzzle = iconic sniper look. **Option B:** front sight ramp 30 × 14 × 12 at X 15–45, blade top Y +16 (sweeping ramped base, blued) |
| 2 | Barrel, sporter taper | 610 long; Ø30 at receiver → Ø17 at muzzle | X 0 – 610 | 0 | Smooth continuous cone; blued steel (not parkerized) |
| 3 | Fore-end (stock front) | 255 × 55 × 45 | X 355 – 610 | bottom Y −52 | Sporter walnut; **rounded tip** (half-dome), oval cross-section; barrel floats in top groove |
| 4 | Receiver (pre-64 M70) | 222 × 38 × 34 | X 610 – 832 | Y +19 top | Cylindrical flat-bottom action; loading/ejection port cut on top right X 660–740; blued |
| 5 | Bolt + bolt handle | bolt Ø18; handle root at X 770 | handle: 25 root then knob | knob center X 785, Y −35, Z +45 (right side) | **Bent/swept-back handle** angled down ~60° and back ~20°; round knob Ø19; clears scope eyepiece |
| 6 | Trigger guard + floorplate | 150 × 20 × 22 | X 700 – 850 | bottom Y −68 | Milled steel; hinged floorplate ahead of guard; trigger X 790, Y −55 |
| 7 | Stock wrist | 90 | X 850 – 940 | see profile | Oval 36 W × 50 H; fine checkering (texture only) |
| 8 | Buttstock w/ cheekpiece | 290 | X 850 – 1140 | see profile | **Rising Monte-Carlo-ish comb + raised cheekpiece** on LEFT side: shelf 130 × 12 proud, X 930–1060, Y +5 to −15 |
| 9 | Buttplate | 10 × 128 × 42 | X 1130 – 1140 | heel Y −10, toe Y −118 | Checkered steel or red rubber pad |
| 10 | Sling swivels | — | X 400 / X 1080 | Y −55 / Y −100 | M1907 leather sling optional |

**Stock profile (top of wood, Y from bore):**

| Station | X | Top Y | Bottom Y |
|---------|---|-------|----------|
| Fore-end tip (round) | 360 | −10 | −52 |
| Receiver front | 610 | −16 | −60 |
| Wrist | 900 | −4 | −54 |
| Comb (rises!) | 980 | +2 | — |
| Heel | 1135 | −8 | — |
| Toe | 1135 | — | −118 |

### Scope option A — 8x Unertl target scope (THE Marine look — build this one)

| Part | Dims | X position | Y offset | Notes |
|------|------|-----------|----------|-------|
| Main tube | **610 long × Ø19** (¾") | X 250 – 860 | tube centerline **Y +48** | Absurdly long thin steel tube — nearly as long as the barrel; overhangs far forward over the barrel and back over the wrist |
| Objective bell | 90 × Ø41 | X 250 – 340 (front) | Y +48 | Gentle cone up from tube |
| Eyepiece | 60 × Ø36 | X 800 – 860 | Y +48 | Sits above the wrist; ~90 mm ahead of buttplate comb area |
| Front mount block+ring | 25 × 30 tall × 22 | X 455 (on BARREL) | posts from barrel top Y +9 up to ring at Y +48 | Tall block screwed to barrel |
| Rear mount + micrometer turrets | 30 × 35 × 22 | X 640 (on receiver front ring) | Y +19 up to +48 | Twin large adjustment drums Ø22 ON THE MOUNT (not the tube) — stacked vertical + horizontal knobs, very visible |
| Recoil spring | coil Ø22 × 50 | X 400 – 450 around tube | Y +48 | Coil spring around tube ahead of front mount — distinctive Unertl detail |

Mount spacing ~185 mm (blocks far apart); scope slides in rings under recoil.

### Scope option B — Redfield 3-9x40 Accu-Range (Army M40-adjacent look)

| Part | Dims | X position | Y offset |
|------|------|-----------|----------|
| Main tube | 330 long × Ø25.4 (1") | X 590 – 920 | centerline Y +42 |
| Objective bell | 80 × Ø48 | X 590 – 670 | Y +42 |
| Eyepiece | 70 × Ø38 | X 850 – 920 | Y +42 |
| Turret saddle | 40 × Ø32 + 2 caps Ø16 | X 745 | Y +42 (+16 top cap) |
| Two low rings on receiver bases | 20 × 25 | X 640 / X 810 | Y +19 → +42 |

Green-gray anodized, matte.

---

## 4. ITHACA 37 (12 ga, riot/trench length)

**Totals: OAL ~1016 mm · Barrel 508 mm (20")**

Anchors: muzzle X=0. Receiver front X=508. Receiver rear/stock joint X=673. Buttplate X=1016.

| # | Part | L × H × W (mm) | X position | Y offset | Notes |
|---|------|----------------|-----------|----------|-------|
| 1 | Bead sight | Ø3 brass bead on Ø2 post | X 6 | Y +11 (on barrel top) | Single brass dot — only sight |
| 2 | Barrel | 508 × Ø20 (near-cylindrical, slight taper from Ø23 at rear) | X 0 – 508 | 0 | Blued; smoothbore |
| 3 | Magazine tube | 330 × Ø22 | X 178 – 508 | center **Y −29** (co-axial under barrel) | 4-shot tube; reaches to ~65% of barrel length, stops 178 mm short of muzzle; end cap Ø24 with sling stud |
| 4 | Barrel/mag ring | 10 × 55 × 26 | X 180 – 190 | spans barrel→tube | Small connecting band at tube front |
| 5 | Pump handle (plain cylindrical corncob) | **200 × Ø34** | closed (rest): X 265 – 465 · full rearward: X 350 – 550 (**travel ≈ 85 mm**) | center Y −29 (rides ON mag tube) | Plain ring-grooved walnut cylinder — no flare; twin thin action bars (4 × 8 section) run rearward into receiver at Y −29, Z ±14 |
| 6 | Receiver | 165 × 55 × 32 | X 508 – 673 | Y +14 top, −41 bottom | **BOTTOM-EJECT: sides are completely smooth/featureless** — no ejection port on either flank; single loading/ejection slot on the belly (60 × 22 opening at X 560–620, Y −41); milled steel, blued/parkerized |
| 7 | Trigger guard + trigger | 70 × 22 × 12 | X 615 – 685 | bottom Y −60 | Trigger X 645, Y −48; guard partly under receiver rear |
| 8 | Stock wrist (slim!) | 85 | X 673 – 758 | see profile | Notably slender: oval 32 W × 44 H — thinnest wrist of the four weapons |
| 9 | Buttstock | 343 | X 673 – 1016 | see profile | Plain walnut, no cheekpiece; oil finish |
| 10 | Buttplate | 10 × 125 × 40 | X 1006 – 1016 | heel Y −18, toe Y −128 | Plastic or steel, checkered "Ithaca" |

**Stock drop profile (top of wood, Y from bore):**

| Station | X | Top Y | Bottom Y |
|---------|---|-------|----------|
| Receiver rear | 673 | +5 | −45 |
| Wrist | 720 | −2 | −44 |
| Comb | 790 | **−38** (drop at comb 1.5") | — |
| Heel | 1010 | **−63** (drop at heel 2.5") | — |
| Toe | 1010 | — | −128 |

Shotgun stocks drop much more than rifle stocks — the sighting eye must drop to the bead. Keep the comb-to-heel line visibly sloping down.

---

## 5. MATERIALS / COLOR TABLE

| Material | Hex | Roughness | Metallic | Used on |
|----------|-----|-----------|----------|---------|
| Parkerized steel (gray-green phosphate) | **#4A4E46** | 0.85 | 0.3 | M14 all metal, M16A1 barrel/FSB/hider, Ithaca receiver option |
| Blued steel (near-black, slight blue) | #23262B | 0.45 | 0.8 | M70 barrel/receiver/bolt, Ithaca barrel/mag tube, Unertl tube |
| American walnut (mid brown) | #5C4033 (base) / #6B4A2F (highlight grain) | 0.55 | 0 | M14 stock, M70 stock, Ithaca stock + pump |
| Fiberglass handguard brown (M14) | #4E3B2A | 0.6 | 0 | M14 upper handguard |
| Anodized aluminum (gray-black) | #2B2D2B | 0.6 | 0.5 | M16A1 upper/lower receiver, mag (slightly lighter #3A3D3A) |
| Black polymer/fiberglass | #1C1C1A | 0.5 | 0 | M16A1 stock, pistol grip, handguards |
| Brass bead | #B5933E | 0.35 | 1.0 | Ithaca bead sight |
| Rubber recoil pad (optional M70) | #6E2F2A | 0.9 | 0 | M70 buttplate option |
| Bright steel (worn edges accent) | #8A8D8A | 0.35 | 1.0 | Bolt handle wear, mag edges — edge-wear only |

**Low-poly notes:** bore-line construction keeps all four weapons interchangeable in hands/rigs; keep sightline heights honest (M16A1 sits 66 mm high — its silhouette depends on it). Cylinders: 8 sides for barrels/tubes, 6 for the Unertl tube reads fine at distance. Triangles read: M16A1 = triangles (FSB, handguard), M14 = long wood + hanging mag, M70 = enormous thin scope, Ithaca = clean slab receiver + corncob pump.
