# US Army Helicopter Aircrew Reference Dossier (Huey pilots/crew, ~1967-69)

Research-only. No Blender work performed. Compiled for PSX low-poly modelling of
US Army helicopter aircrew for RECONgame. All dimensions are best-available
approximations from surplus/collector listings and technical excerpts — flag
anything load-bearing for a second check before committing to a mesh budget.

---

## 1. SPH-4 flight helmet (and APH-5 predecessor)

**Timeline.** APH-5 (Navy-developed) and AFH-1 (Army-developed) were the
Army's helicopter helmets through the mid-1960s. **SPH-4 was introduced in
late 1969**, derived from the Navy SPH-3, and replaced both. This means: for
a "1967-69" cast, **APH-5 is actually the more period-correct helmet for
the bulk of the war**; SPH-4 only becomes correct for the tail end of 1969.
Mid-1967 also saw an APH-5 upgrade with a thicker (~0.5") energy-absorbing
front panel that tapers thinner over the crown — worth reflecting in a
blocky low-poly shell if we want the mid-war look right.
[vietnamgear.com/kit.aspx?kit=3](https://www.vietnamgear.com/kit.aspx?kit=3),
[militaryimages.net thread](https://www.militaryimages.net/threads/huey-cobra-pilot-crew-uniform.6700/)

**Shell.** Fiberglass cloth layers bonded with epoxy resin ("Epoxy One"
construction on SPH-4, giving it a thicker/stiffer shell than APH-5).
Rounded motorcycle-helmet-like dome, closed at the crown, cut low at the
nape, with pronounced bulges over each ear for the earcups (see below) —
the silhouette is NOT a smooth sphere, it reads as dome + two ear pods +
a chin/jaw cutout.
[Vietnam War era SPH-4 listing](https://www.ima-usa.com/products/original-u-s-vietnam-war-era-named-gentex-sph-4-helmet-helicopter-pilot-with-helmet-bag-and-flight-gloves-size-extra-large)

**Visor housing.** External housing on the brow, holding a retractable
visor pair. SPH-4 is single-visor (grey/smoke, or clear night visor);
earlier configurations offered dual visor (clear + tinted) via a small
**twist/rotate knob on the side of the housing** used to swap or stow the
visor. The visor track sits proud of the shell as a raised brow ridge —
this is a key silhouette read at a distance and worth 1-2 extra polys to
sell.

**Boom mic.** Flexible gooseneck boom mounted low on the left (usually)
side of the shell near jaw level, running forward to a small mic capsule
that sits just off the corner of the mouth. Reads as a thin stalk + small
bulb — cheap to fake with 2 edge loops and a tapered cylinder.

**Earcups.** Big functional readable bulge on each side, 6 mm thick molded
plastic housing, integrated into the shell rather than bolted external —
model as part of the base mesh, not a separate prop.

**Chin/nape strap.** Nylon webbing chin strap (150 lb rated originally,
later 250-300 lb), nape strap with single snap each side into studs on a
retention harness. Straps hang loose and visible when helmet is off/set
aside — relevant to the brief's "helmet off" poses (see section 7).

**Colour.** Standard Army issue: **olive drab/olive green shell** with grey
visor, black earcups/liner. White shells existed (more common Navy/other
use, and some later Army issue) but OD green is the correct default for
Army Huey pilots in this period. Some later helmets got name/callsign
stencils and nose-art-style paint on the front, common by late war and
particularly among gunship/Cobra pilots — optional variant, not baseline.

**Dimensions.** No manufacturer spec sheet found giving external shell
measurements directly; derived from helmet sizing charts (motorcycle/flight
helmet convention, head circumference to shell size):
- Size Small head circumference ~54.5-55.5 cm; Regular/Large heads run
  ~57-60 cm. [Flying-jacket.com helmet size guide](https://flying-jacket.com/pages/helmet-size-guide)
- From that, estimate external shell: roughly **22-24 cm wide, 24-26 cm
  deep (front-to-back including visor housing bump), 22-24 cm tall**
  (crown to base of earcups), for a Regular/Large size. Treat as an
  estimate, not a cited spec — good enough for blockout, re-measure
  against a real motorcycle helmet reference if precision matters later.
- Liner: 9.7 mm (0.38") polystyrene originally, thickened to 12.7 mm
  (0.50") in 1974 (post-period, not relevant to '67-69 build).
- Weight (Regular): 1.54 kg (3.4 lb).
[SPH-4 spec excerpts via web search](https://www.ima-usa.com/products/original-u-s-vietnam-war-era-named-gentex-sph-4-helmet-helicopter-pilot-with-helmet-bag-and-size-11-flight-gloves)

**Image references (multi-angle):**
1. https://www.ima-usa.com/products/original-u-s-vietnam-war-era-named-gentex-sph-4-helmet-helicopter-pilot-with-helmet-bag-and-flight-gloves-size-extra-large (full photo set, front/side/back/visor-up/visor-down — best single source, 15+ images)
2. https://www.ima-usa.com/products/u-s-vietnam-war-helicopter-pilot-gentex-sph-4-helmet-with-felt-bag
3. https://www.ima-usa.com/products/original-u-s-vietnam-war-named-helicopter-pilot-gentex-sph-4-helmet-major-anglin
4. https://www.ima-usa.com/products/original-u-s-navy-vietnam-war-helicopter-pilot-gentex-sph-4-helmet-with-night-vision-goggle-mount (NVG mount variant, shows boom mic and earcup detail well)
5. https://www.ima-usa.com/products/original-u-s-vietnam-war-era-1965-dated-aph-5-helicopter-pilot-flying-helmet-by-gentex-corporation-size-medium (APH-5, the more period-correct shape for mid-war)
6. https://www.militarytour.com/u-s-helicopter-pilot-gentex-sph-4-helmet-with-dual-lenses.html (dual-visor detail)

---

## 2. Nomex flight suit / K-2B coveralls

**Correction to brief's assumption.** Multiple period-pilot accounts say
Huey/Cobra **crews mostly did NOT wear flight suits day to day** — standard
jungle fatigues (poplin, then ripstop from ~1967-69) were the norm, with
Nomex/K-2B worn by pilots who could get it or who prioritized fire
protection, described by one pilot as an exception ("wear the Nomex flight
suit & carry a six-gun low slung, it doesn't get any cooler than that").
Nomex didn't reliably reach flight-fire-retardant status until later in the
war; the K-2B (cotton twill, sage green, MIL-S-6265) was the common
"flight suit" item and was **not** inherently fire retardant — some units
field-treated it with Borax. **Recommendation: give pilots a K-2B/Nomex
option AND keep jungle-fatigue-wearing pilot variants for variety/period
accuracy**, don't force 100% flight-suit population.
[militaryimages.net thread](https://www.militaryimages.net/threads/huey-cobra-pilot-crew-uniform.6700/),
[Arkansas Air & Military Museum](https://www.arkansasairandmilitary.com/post/artifact-friday-k2b-flight-suit),
[vietnamgear.com/kit.aspx?kit=61](https://www.vietnamgear.com/kit.aspx?kit=61)

**Cut.** One-piece coverall, zip front, notched/open collar (worn open at
the throat, not a tight band), banded cuffs, banded waist (some
adjustment tabs at the sides).

**Pockets.** Six main pockets: two chest pockets (angled, flap-covered,
roughly breast-pocket height, large enough for a notebook/plates), and
**four on the legs/thighs** (large cargo-style thigh pockets, positioned
outer-thigh, bellows or flap closure). Plus a pencil/pen slot and one
sleeve pocket (typically left forearm) — useful small silhouette breaks
for a low-poly texture bake.

**Colour.** Sage green (K-2B baseline). Note distinction from "olive drab"
(OD-107 fatigue green) — sage green runs slightly lighter/greyer; texture
palette should differentiate flight suit from jungle fatigue OD if both
are in the same scene.

**Silhouette vs jungle fatigues.** Flight suit is a smooth one-piece with
no waist break (no separate jacket/trouser blousing at the boot), banded
ankle cuffs tucked into boots rather than bloused fatigue trousers, and no
external cargo pockets on the lower leg (jungle fatigues have the iconic
lower-leg cargo pockets; K-2B does not) — this is the fastest way to read
"aircrew" vs "grunt" from silhouette alone at low poly.

**Image references:**
1. https://www.ebay.com/itm/116595551499 (K-2B, ML, laid flat — good silhouette read)
2. https://www.armynavywarehouse.com/product-page/us-military-sage-green-flying-coveralls-flight-suit-type-k-2b
3. https://www.armynavywarehouse.com/product-page/us-military-vietnam-sage-green-flying-coveralls-flight-suit-type-k-2b
4. https://www.arkansasairandmilitary.com/post/artifact-friday-k2b-flight-suit (article w/ photos + pocket detail)
5. https://www.vietnamgear.com/kit.aspx?kit=61 (labeled reference, spec number)
6. https://www.cgflightsuits.com/products/3.html (modern reproduction CWU-27/P Nomex — useful for the later-style cut if we want post-'69 accuracy)

---

## 3. SRU-21/P survival vest ("Y" harness)

**Adoption.** Assigned 1966-09-04 — correctly period for '67-69.
[gear-illustration.com](https://www.gear-illustration.com/2023/04/20/air-force-sru-21-p-mesh-net-survival-vest-1980s/)

**Shape.** Mesh/net or twill vest worn over the flight suit, cut like a
fishing vest with a **"Y"-shaped strap arrangement** connecting front
panels over the shoulders to a rear yoke — NOT a full vest back panel on
early nylon-mesh versions, more a harness with pocketed front panels front
and shoulder straps. Sits at chest/upper-torso height, over the survival
vest goes the chicken plate armor and/or web gear.

**Contents/pockets** (front, mixed zipper-main / velcro-minor closures):
- Compass pocket
- Distress marker light pocket
- Signal kit pocket
- Emergency signal mirror pocket
- Survival radio pocket (large, holds a hand-held survivor radio —
  reads as the biggest/boxiest pocket, good silhouette anchor)
- Survival kit pocket
- Pocket knife pocket
- Fishing net / survival fishing kit pocket
- Lighter pocket
- Water bag pocket
- **Leather holster, sewn/integrated (not belt-mounted) for a .38 revolver**
  — flapped, sewn in place with a leather strap and redundant nylon strap,
  positioned front-center-low or front-side on the vest.
[IWM object 30110039](https://www.iwm.org.uk/collections/item/object/30110039),
[worthpoint SRU-21/P listing](https://www.worthpoint.com/worthopedia/usaf-sru-21-pilot-survival-vest-440053440),
[m1militaria.co.uk](https://www.m1militaria.co.uk/Vietnam-War-US-SRU-21P-Survival-Vest-Holster)

**Modelling note.** At PS1 poly budgets this is best handled as a painted
texture over a simplified vest silhouette with 2-3 pocket bumps (radio
pocket + holster being the two that read from a distance), not individually
modelled pocket geometry.

**Image references:**
1. https://www.iwm.org.uk/collections/item/object/30110039
2. https://www.worthpoint.com/worthopedia/air-force-survival-vest-sru-21-38-1833015172
3. https://www.worthpoint.com/worthopedia/usaf-sru-21-pilot-survival-vest-440053440
4. https://www.ebay.com/p/1231506381 (holster detail, sew-on leather .38 holster isolated)
5. https://www.m1militaria.co.uk/Vietnam-War-US-SRU-21P-Survival-Vest-Holster
6. https://sandiegoairandspace.org/collection/item/sru-21-p-survival-vest

---

## 4. Gloves, boots, shoulder holster, chicken plate armor

**Gloves.** Leather B-3A gloves were standard through most of the war.
OD Nomex/leather combo gloves (GS/FRP-1) started reaching Navy aviators
~1969 and were trialed by the Army's Concept Team in Vietnam in late 1967
as a B-3A replacement — gauntlet-style, Nomex cloth on gauntlet back/thumb
back/finger sides, washable sheepskin leather on palm/fingers/thumb.
**For '67-69, plain leather B-3A-style gloves are the safer baseline**,
with Nomex-gauntlet gloves as a late-war variant.
[search summary](https://www.vietnamgear.com/kit.aspx?kit=645)

**Boots.** **All-leather stateside-style combat boots**, not the
nylon-sided jungle boot — aircrew avoided jungle boots because the nylon
mesh sides could melt onto skin in a post-crash fire. This is a real
distinguishing silhouette point vs infantry (who wear jungle boots) —
pilot boots should read as solid leather, no visible mesh panel.
[militaryimages.net thread](https://www.militaryimages.net/threads/huey-cobra-pilot-crew-uniform.6700/)

**Shoulder holster / sidearm.** Pilots most commonly carried a
**Smith & Wesson Model 10 .38 revolver** (Colt 1911 was also offered but
M10 was the more common pilot choice) in a standard leather belt holster,
NOT typically a shoulder rig by these accounts — "low-slung" gun belt is
the more attested look, worn so the holster rotates between the legs when
seated in the cockpit. Some pilots bought aftermarket Buscadero
quick-draw belt rigs. Note: brief asked specifically about "shoulder
holster" — direct sourcing found belt/hip holsters as the dominant
period-attested carry, not shoulder rigs; flag this as a correction rather
than confirming a shoulder holster as standard.

**Chicken plate (aircrew body armor).** Ceramic monolithic plate, molded
to torso contours, in a nylon carrier vest.
- **Pilots/copilots**: front plate only (they sit in armored seats, so
  back coverage is redundant).
- **Other crew (no armored seat)**: front AND back plates.
- Army used aluminum oxide ceramic (heavier); Navy/AF/USMC used
  silicon carbide or boron carbide (lighter). All rated to stop .30 cal
  at 100 yards.
- Carrier: front map pocket, elastic webbing sides, quick-release
  shoulder snap buckles, elastic/snap loop on the waistband to stop it
  flapping open in rotor wash.
- Sizes Short/Regular/Long; a Long front+back Aluminum Oxide vest weighs
  ~30 lb.
- **Slick (troop transport) pilots frequently removed the chicken plate
  and sat on it instead** (extra under-seat protection, more comfort) —
  a legitimate "armor absent, on the seat" pose/prop option.
- **Gunship crews often preferred the older M1958/M1969 flak jacket**
  instead of chicken plate for freedom of movement while reloading.
[vietnamgear.com/kit.aspx?kit=310](https://www.vietnamgear.com/kit.aspx?kit=310),
[flighthelmet.com/info/armor.htm](https://www.flighthelmet.com/info/armor.htm)

**Image references:**
1. https://www.ima-usa.com/products/original-u-s-vietnam-war-helicopter-air-crew-ballistic-armored-vest (11+ images, front/back/plate removed)
2. https://www.worthpoint.com/worthopedia/aircrew-body-armor-vietnam-war-1916725980
3. https://www.catalystsurplus.com/product-page/long-aircrew-body-armor-chicken-plate-vest (modern repro, clean unworn shape reference)
4. https://www.gear-illustration.com/2015/12/22/aircrew-body-armor/ (technical line-art illustration — very good for low-poly silhouette planning)
5. https://www.vietnamgear.com/kit.aspx?kit=645 (GS/FRP-1 gloves)
6. https://www.vietnamgear.com/kit.aspx?kit=310 (chicken plate, period photos)

---

## 5. Crew chief / door gunner differences from pilots

These matter later for a distinct silhouette/loadout when we build them:

- **Weapons.** Door gunner's primary weapon is a pintle- or bungee-mounted
  **M60 machine gun** in the doorway (not carried, mounted to the aircraft).
  Crew chiefs and gunners also typically carry a **secondary M-16** —
  pilots historically were NOT issued M-16s and had to improvise/acquire
  personal weapons, so a pilot should not default-spawn with a rifle.
- **Body armor.** Gunners more often wear flak jackets (M1958/M1969) rather
  than chicken plates — bulkier, more visible torso silhouette than a
  pilot's slimmer front-plate-only carrier, and with a full front+back
  plate if chicken plate is used at all (no armored seat to rely on).
- **Extra gear.** Colored smoke grenades carried for marking LZs/receiving
  fire — a beltline prop worth having for gunner variants.
- **Role/pose implications.** Crew chief is also the aircraft's mechanic —
  reasonable to show a crew-chief variant with a rag/tool prop or sleeves
  rolled, doing maintenance poses, vs. pilot idle-in-seat poses.
- **Seating/restraint.** Gunners work from an open door on a monkey-strap/
  gunner's belt rather than the pilot's 4/5-point harness — different rig
  visible at the waist if we ever show them working the gun.
[Military Wiki door gunner overview](https://military-history.fandom.com/wiki/Door_gunner),
[Survival World article](https://www.survivalworld.com/history/vietnams-door-gunners-open-air-heavy-fire-and-pure-guts/),
[themilitarymark.com Army Helicopter Crewmen pt.3](https://www.themilitarymark.com/us-army-in-vietnam-war/blog-post-title-four-gb4nf-8c7c5-pc5d6)

---

## 6. Correction flags for the design/build team

1. **Flight suits are not the default** — most Huey/Cobra crews wore
   jungle fatigues day to day per direct pilot testimony; treat Nomex/K-2B
   as one variant among several, not the baseline uniform.
2. **SPH-4 is late-period (introduced late 1969)** — for a '67-69 cast,
   APH-5 (with the mid-'67 thickened-front upgrade) is more period-accurate
   for most of the war; SPH-4 is fine as one variant, not the sole helmet.
3. **Shoulder holster is not well attested** — belt/hip holster,
   "low-slung," is the sourced norm for pilot sidearms. Recommend correcting
   to belt holster unless a specific reference photo turns up.
4. **Boots are all-leather, not jungle boots** — a clean silhouette
   differentiator from infantry models already in the game; do not reuse
   the infantry boot mesh/texture for aircrew.

---

## 7. Helmet-off reference (helmet resting off the head)

Direct photographic search for "helmet on the seat" candid shots did not
surface a clean hit, but the following give solid grounds for posing the
SPH-4/APH-5 off the head — hooked on the collective, set on the seat, or
held by the chin strap:

- Every IMA/collector product listing (refs 1-6 in section 1) photographs
  the helmet **unworn**, sitting on a stand or flat, from front/back/¾/side
  — these ARE the "off the head" multi-angle set; use them directly for
  modelling the resting pose since the shape is identical worn or not, only
  the strap drape differs (straps hang down/dangle when off-head, cinched
  flat against the jaw when worn).
- Chin strap and nape strap hardware (snap studs, webbing) is clearly
  visible in the IMA photo sets and is the detail that needs to read
  correctly in an "off-head, straps dangling" pose — see especially
  https://www.ima-usa.com/products/original-u-s-vietnam-war-era-named-gentex-sph-4-helmet-helicopter-pilot-with-helmet-bag-and-flight-gloves-size-extra-large
  which includes strap-extended shots.
- Recommend: when the model is actually posed off-head in Blender later,
  treat the helmet as its own rigid prop object (parented to seat or belt
  clip bone), with the chin strap as a simple 2-3 bone hanging chain or a
  baked static drape — cheap and reads fine at PSX fidelity.

---

## Sources consulted (full list)

- https://www.ima-usa.com/ (multiple SPH-4, APH-5, and chicken-plate listings — best image coverage, cited inline above)
- https://www.vietnamgear.com/ (kit.aspx?kit=3 SPH-4, kit=61 K-2B, kit=310 chicken plate, kit=645 gloves — spec numbers, FSNs, dates)
- https://www.gear-illustration.com/ (SRU-21/P, chicken plate technical illustrations)
- https://www.iwm.org.uk/collections/item/object/30110039 (SRU-21/P, Imperial War Museum catalog)
- https://www.worthpoint.com/ (SRU-21/P and chicken plate collector listings/photos)
- https://www.militaryimages.net/threads/huey-cobra-pilot-crew-uniform.6700/ (period pilot/crew first-hand accounts — most valuable single source for correcting assumptions)
- https://www.flighthelmet.com/info/armor.htm (chicken plate technical detail)
- https://www.arkansasairandmilitary.com/post/artifact-friday-k2b-flight-suit
- https://www.armynavywarehouse.com/ (K-2B listings)
- https://military-history.fandom.com/wiki/Door_gunner, https://www.survivalworld.com/history/vietnams-door-gunners-open-air-heavy-fire-and-pure-guts/, https://www.themilitarymark.com/us-army-in-vietnam-war/blog-post-title-four-gb4nf-8c7c5-pc5d6 (crew chief/door gunner role and gear)
- https://flying-jacket.com/pages/helmet-size-guide (helmet sizing convention used to estimate SPH-4 shell dimensions)
